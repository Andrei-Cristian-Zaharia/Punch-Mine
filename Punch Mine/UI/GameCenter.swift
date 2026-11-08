import SwiftUI
import Combine
#if os(iOS)
import GameKit
#endif

/// Game Center sign-in and the Weekly Heart leaderboard. The Weekly Heart works without Game Center;
/// only the ranking and its rewards need it.
///
/// App Store Connect setup: a *recurring* leaderboard with ID `WeeklyHeart.leaderboardID`, score format
/// "Fixed point, 2 decimals" (suffix " tiers"), sorted high to low, starting on a Monday at 00:00 UTC and
/// repeating every 1 week, so its weeks line up with `WeeklyHeart.week(of:)`.
@MainActor
final class GameCenter: ObservableObject {
    struct Entry: Identifiable, Equatable {
        let rank: Int
        let name: String
        let score: Int
        let isMe: Bool
        var id: Int { rank }
    }

    @Published private(set) var isAuthenticated = false
    /// Game Center has a sign-in screen ready to show.
    @Published private(set) var canSignIn = false
    /// This week's top 3, your entry and how many players took part.
    @Published private(set) var top: [Entry] = []
    @Published private(set) var me: Entry?
    @Published private(set) var players = 0
    private weak var game: GameModel?

    #if os(iOS)
    private var signInController: UIViewController?
    private let dismisser = Dismisser()
    #endif

    func attach(to game: GameModel) {
        guard self.game == nil else { return }
        self.game = game
        game.onWeeklyBest = { [weak self] week, score in self?.submit(score, week: week) }
        #if os(iOS)
        // Debug launches with a made-up save never post scores.
        guard !MyApp.debugSaveLaunch else { return }
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, _ in
            Task { @MainActor in self?.authenticationChanged(controller) }
        }
        #endif
    }

    /// Shows Game Center's own sign-in screen. Kept until the player asks, so launch never opens with it.
    func signIn() {
        #if os(iOS)
        guard let signInController, let root = AdConsent.rootViewController() else { return }
        root.present(signInController, animated: true)
        #endif
    }

    func showLeaderboard() {
        #if os(iOS)
        guard isAuthenticated, let root = AdConsent.rootViewController() else { return }
        let controller = GKGameCenterViewController(leaderboardID: WeeklyHeart.leaderboardID, playerScope: .global, timeScope: .allTime)
        controller.gameCenterDelegate = dismisser
        root.present(controller, animated: true)
        #endif
    }

    func refresh() {
        #if os(iOS)
        Task { await loadStandings() }
        #endif
    }

    private func submit(_ score: Int, week: Int) {
        #if os(iOS)
        // A fight that ran past Monday 00:00 UTC belongs to a week the leaderboard has already closed.
        guard isAuthenticated, week == WeeklyHeart.week(of: Date()) else { return }
        Task {
            await post(score)
            await loadStandings()
        }
        #endif
    }

    #if os(iOS)
    private func authenticationChanged(_ controller: UIViewController?) {
        signInController = controller
        canSignIn = controller != nil
        isAuthenticated = GKLocalPlayer.local.isAuthenticated
        guard isAuthenticated, let game else { return }
        Task {
            // A best set while signed out or offline still counts.
            let best = game.weeklyState().best
            if best > 0 { await post(best) }
            await claimLastWeek()
            await loadStandings()
        }
    }

    private func post(_ score: Int) async {
        try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                             leaderboardIDs: [WeeklyHeart.leaderboardID])
    }

    private func leaderboard() async -> GKLeaderboard? {
        (try? await GKLeaderboard.loadLeaderboards(IDs: [WeeklyHeart.leaderboardID]))?.first
    }

    /// Pays last week's placement, once (the model remembers claimed weeks).
    private func claimLastWeek() async {
        guard let board = await leaderboard(), board.type == .recurring else { return }
        let previous: GKLeaderboard? = try? await board.loadPreviousOccurrence()
        guard let previous, let start = previous.startDate,
              let result = try? await previous.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 1)),
              let mine = result.0 else { return }
        // An hour in, so clock drift at the boundary can't land it in the week before.
        game?.claimWeeklyRank(week: WeeklyHeart.week(of: start.addingTimeInterval(3_600)), rank: mine.rank, total: result.2)
    }

    private func loadStandings() async {
        guard isAuthenticated, let board = await leaderboard(),
              let result = try? await board.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 3)) else { return }
        let myID = GKLocalPlayer.local.gamePlayerID
        top = result.1.map { Entry(rank: $0.rank, name: $0.player.displayName, score: $0.score, isMe: $0.player.gamePlayerID == myID) }
        me = result.0.map { Entry(rank: $0.rank, name: $0.player.displayName, score: $0.score, isMe: true) }
        players = result.2
    }

    private final class Dismisser: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            controller.dismiss(animated: true)
        }
    }
    #endif
}
