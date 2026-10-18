import SwiftUI
import Combine
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Shows a rewarded ad and reports whether the player earned the reward.
protocol RewardedAdProvider: AnyObject {
    var isAvailable: Bool { get }
    func preload()
    func show(_ placement: AdPlacement) async -> Bool
}

/// Runs the ad flow: check limits → pause the game → show → grant the reward.
@MainActor
final class AdCoordinator: ObservableObject {
    let provider: RewardedAdProvider
    /// Set while the simulated test ad is on screen.
    @Published var simulated: AdPlacement?
    private var simulatedContinuation: CheckedContinuation<Bool, Never>?
    @Published private(set) var isShowing = false

    init() {
        #if canImport(GoogleMobileAds)
        provider = AdMobRewardedProvider()
        #elseif DEBUG
        provider = SimulatedAdProvider()
        #else
        provider = UnavailableAdProvider()
        #endif
        (provider as? SimulatedAdProvider)?.coordinator = self
        provider.preload()
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

/// Release builds without an ad SDK: every ad button stays hidden.
final class UnavailableAdProvider: RewardedAdProvider {
    var isAvailable: Bool { false }
    func preload() {}
    func show(_ placement: AdPlacement) async -> Bool { false }
}

/// Debug builds without an ad SDK: a 5-second in-app test ad, so the whole flow can be played.
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
                Text("A real rewarded ad plays here once an ad SDK is added.")
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

#if canImport(GoogleMobileAds)
/// Google AdMob rewarded ads. Add the Google Mobile Ads package and set `GADApplicationIdentifier` and
/// `PunchMineRewardedAdUnitID` in Info.plist. Without a unit ID, Google's public test unit is used.
final class AdMobRewardedProvider: NSObject, RewardedAdProvider, FullScreenContentDelegate {
    private static let testUnitID = "ca-app-pub-3940256099942544/1712485313"
    private var ad: RewardedAd?
    private var loading = false
    private var dismissal: CheckedContinuation<Void, Never>?

    private var unitID: String {
        (Bundle.main.object(forInfoDictionaryKey: "PunchMineRewardedAdUnitID") as? String) ?? Self.testUnitID
    }

    override init() {
        super.init()
        MobileAds.shared.start(completionHandler: nil)
    }

    var isAvailable: Bool { true }

    func preload() {
        guard ad == nil, !loading else { return }
        loading = true
        Task { @MainActor in
            ad = try? await RewardedAd.load(with: unitID, request: Request())
            ad?.fullScreenContentDelegate = self
            loading = false
        }
    }

    @MainActor func show(_ placement: AdPlacement) async -> Bool {
        if ad == nil { ad = try? await RewardedAd.load(with: unitID, request: Request()) }
        guard let ad, let root = Self.rootViewController() else { return false }
        ad.fullScreenContentDelegate = self
        var rewarded = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dismissal = continuation
            ad.present(from: root) { rewarded = true }
        }
        self.ad = nil
        return rewarded
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        dismissal?.resume()
        dismissal = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        dismissal?.resume()
        dismissal = nil
    }

    @MainActor private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
#endif
