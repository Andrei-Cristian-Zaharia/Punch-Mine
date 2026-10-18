import SwiftUI
import Combine
#if canImport(GoogleMobileAds) && os(iOS)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform) && os(iOS)
import UserMessagingPlatform
#endif

/// Shows a rewarded ad and reports whether the player earned the reward.
protocol RewardedAdProvider: AnyObject {
    var isAvailable: Bool { get }
    func preload()
    func show(_ placement: AdPlacement) async -> Bool
}

/// Shows an interstitial and reports whether one was on screen.
protocol InterstitialAdProvider: AnyObject {
    var isLoaded: Bool { get }
    func preload()
    func show() async -> Bool
}

/// AdMob unit IDs. Debug builds always use Google's test units: tapping your own live ads breaks AdMob policy.
enum AdUnits {
    #if DEBUG
    static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let rewarded = "ca-app-pub-8505602361918016/7232159078"
    static let interstitial = "ca-app-pub-8505602361918016/5428122817"
    #endif
}

/// Runs the ad flow: consent → SDK start → load; then check limits → pause the game → show → grant the reward.
@MainActor
final class AdCoordinator: ObservableObject {
    let provider: RewardedAdProvider
    let interstitial: InterstitialAdProvider?
    /// Set while the simulated test ad is on screen.
    @Published var simulated: AdPlacement?
    private var simulatedContinuation: CheckedContinuation<Bool, Never>?
    @Published private(set) var isShowing = false
    /// True once the player has answered (or doesn't need) the consent form and the SDK has started.
    @Published private(set) var isReady = false
    /// EU/UK players can reopen the consent form from Settings.
    @Published private(set) var privacyOptionsRequired = false
    private var preparing = false

    init() {
        #if canImport(GoogleMobileAds) && os(iOS)
        provider = AdMobRewardedProvider()
        interstitial = AdMobInterstitialProvider()
        #elseif DEBUG
        provider = SimulatedAdProvider()
        interstitial = nil
        #else
        provider = UnavailableAdProvider()
        interstitial = nil
        #endif
        (provider as? SimulatedAdProvider)?.coordinator = self
    }

    /// Call once the UI is up: the consent form needs a screen to present on.
    func prepare(game: GameModel) {
        guard !preparing else { return }
        preparing = true
        Task {
            let allowed = await AdConsent.gather()
            privacyOptionsRequired = AdConsent.privacyOptionsRequired
            guard allowed else {
                game.adsAvailable = false
                game.breakAdsAvailable = false
                return
            }
            AdConsent.startSDK()
            provider.preload()
            interstitial?.preload()
            isReady = true
            game.adsAvailable = provider.isAvailable
            game.breakAdsAvailable = interstitial != nil
        }
    }

    func showPrivacyOptions() {
        Task { await AdConsent.presentPrivacyOptions() }
    }

    func watch(_ placement: AdPlacement, game: GameModel) {
        guard !isShowing, game.canWatch(placement) else { return }
        isShowing = true
        game.adWillShow(placement)
        Task {
            let rewarded = await provider.show(placement)
            game.adDidFinish(placement, rewarded: rewarded)
            isShowing = false
            provider.preload()
        }
    }

    /// An interstitial at a natural break. Waits a moment so a closing sheet is gone first.
    func showBreak(game: GameModel) {
        guard let interstitial, interstitial.isLoaded, !isShowing else {
            interstitial?.preload()
            return
        }
        isShowing = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard game.canShowBreakAd(), interstitial.isLoaded else {
                isShowing = false
                return
            }
            game.breakAdWillShow()
            let shown = await interstitial.show()
            game.breakAdDidFinish(shown: shown)
            isShowing = false
            interstitial.preload()
        }
    }

    #if DEBUG
    /// Screenshot helper: shows an interstitial as soon as one loads, ignoring the frequency rules.
    func debugShowBreak(game: GameModel) {
        guard let interstitial else { return }
        Task {
            for _ in 0..<40 where !interstitial.isLoaded {
                interstitial.preload()
                try? await Task.sleep(for: .milliseconds(500))
            }
            game.breakAdWillShow()
            let shown = await interstitial.show()
            game.breakAdDidFinish(shown: shown)
            interstitial.preload()
        }
    }
    #endif

    // MARK: Simulated ad support

    func presentSimulated(_ placement: AdPlacement) async -> Bool {
        await withCheckedContinuation { continuation in
            simulatedContinuation = continuation
            simulated = placement
        }
    }

    /// A presentation binding that is active only where `condition` holds.
    func simulatedBinding(when condition: Bool) -> Binding<AdPlacement?> {
        Binding(
            get: { condition ? self.simulated : nil },
            set: { if $0 == nil, condition, self.simulated != nil { self.finishSimulated(rewarded: false) } }
        )
    }

    func finishSimulated(rewarded: Bool) {
        guard simulated != nil else { return }
        simulated = nil
        simulatedContinuation?.resume(returning: rewarded)
        simulatedContinuation = nil
    }
}

/// Google's consent form (UMP), required by AdMob for players in the EEA, UK and Switzerland.
/// Elsewhere it finishes at once without showing anything.
@MainActor
enum AdConsent {
    static func gather() async -> Bool {
        #if canImport(UserMessagingPlatform) && os(iOS)
        let info = ConsentInformation.shared
        do {
            try await info.requestConsentInfoUpdate(with: RequestParameters())
            if let root = rootViewController() {
                try await ConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // Offline or a form error: fall back to the consent from the last session, if any.
        }
        return info.canRequestAds
        #else
        return true
        #endif
    }

    static var privacyOptionsRequired: Bool {
        #if canImport(UserMessagingPlatform) && os(iOS)
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #else
        false
        #endif
    }

    static func presentPrivacyOptions() async {
        #if canImport(UserMessagingPlatform) && os(iOS)
        guard let root = rootViewController() else { return }
        try? await ConsentForm.presentPrivacyOptionsForm(from: root)
        #endif
    }

    static func startSDK() {
        #if canImport(GoogleMobileAds) && os(iOS)
        MobileAds.shared.start(completionHandler: nil)
        #endif
    }

    #if os(iOS)
    static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #endif
}

/// Release builds without an ad SDK: every ad button stays hidden.
final class UnavailableAdProvider: RewardedAdProvider {
    var isAvailable: Bool { false }
    func preload() {}
    func show(_ placement: AdPlacement) async -> Bool { false }
}

/// Debug builds without an ad SDK (macOS): a 5-second in-app test ad, so the whole flow can be played.
final class SimulatedAdProvider: RewardedAdProvider {
    weak var coordinator: AdCoordinator?
    var isAvailable: Bool { true }
    func preload() {}
    @MainActor func show(_ placement: AdPlacement) async -> Bool {
        await coordinator?.presentSimulated(placement) ?? false
    }
}

extension View {
    /// Full-screen on iOS; a sheet on macOS, which has no full-screen cover.
    func adCover(item: Binding<AdPlacement?>, ads: AdCoordinator) -> some View {
        #if os(macOS)
        sheet(item: item) { placement in
            SimulatedAdView(placement: placement) { ads.finishSimulated(rewarded: $0) }
                .frame(minWidth: 420, minHeight: 520)
        }
        #else
        fullScreenCover(item: item) { placement in
            SimulatedAdView(placement: placement) { ads.finishSimulated(rewarded: $0) }
        }
        #endif
    }
}

struct SimulatedAdView: View {
    let placement: AdPlacement
    let onClose: (Bool) -> Void
    @State private var remaining = 5

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("TEST AD").font(Theme.body(13, .black)).tracking(2).foregroundStyle(.yellow)
                Text(placement.title).font(Theme.display(28)).foregroundStyle(.white)
                Text("A real rewarded ad plays here on iPhone and iPad.")
                    .font(Theme.body(14)).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                if remaining > 0 {
                    Text("Reward in \(remaining) s").font(Theme.body(17, .heavy)).foregroundStyle(.white).monospacedDigit()
                } else {
                    Button("Claim reward") { onClose(true) }
                        .font(Theme.body(17, .black))
                        .padding(.horizontal, 24).frame(minHeight: 50)
                        .background(Color.green, in: Capsule())
                        .foregroundStyle(.black)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button {
                onClose(false)
            } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15), in: Circle())
                    .foregroundStyle(.white)
            }
            .padding(16)
            .accessibilityLabel(remaining > 0 ? "Close ad without reward" : "Close ad")
        }
        .task {
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
            }
        }
    }
}

#if canImport(GoogleMobileAds) && os(iOS)
/// Waits for a full-screen ad to close.
final class AdDismissal: NSObject, FullScreenContentDelegate {
    private var continuation: CheckedContinuation<Bool, Never>?

    func wait(_ present: () -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            present()
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { finish(true) }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) { finish(false) }

    private func finish(_ shown: Bool) {
        continuation?.resume(returning: shown)
        continuation = nil
    }
}

/// AdMob rewarded ads (unit "Rewarded").
final class AdMobRewardedProvider: RewardedAdProvider {
    private var ad: RewardedAd?
    private var loading = false
    private let dismissal = AdDismissal()

    var isAvailable: Bool { true }

    func preload() {
        guard ad == nil, !loading else { return }
        loading = true
        Task { @MainActor in
            ad = try? await RewardedAd.load(with: AdUnits.rewarded, request: Request())
            loading = false
        }
    }

    @MainActor func show(_ placement: AdPlacement) async -> Bool {
        if ad == nil { ad = try? await RewardedAd.load(with: AdUnits.rewarded, request: Request()) }
        guard let ad, let root = AdConsent.rootViewController() else { return false }
        self.ad = nil
        ad.fullScreenContentDelegate = dismissal
        var rewarded = false
        _ = await dismissal.wait { ad.present(from: root) { rewarded = true } }
        return rewarded
    }
}

/// AdMob interstitials (unit "Break"). Only shown when one is already loaded, so a break never waits on the network.
final class AdMobInterstitialProvider: InterstitialAdProvider {
    private var ad: InterstitialAd?
    private var loading = false
    private let dismissal = AdDismissal()

    var isLoaded: Bool { ad != nil }

    func preload() {
        guard ad == nil, !loading else { return }
        loading = true
        Task { @MainActor in
            ad = try? await InterstitialAd.load(with: AdUnits.interstitial, request: Request())
            loading = false
        }
    }

    @MainActor func show() async -> Bool {
        guard let ad, let root = AdConsent.rootViewController() else { return false }
        self.ad = nil
        ad.fullScreenContentDelegate = dismissal
        return await dismissal.wait { ad.present(from: root) }
    }
}
#endif
