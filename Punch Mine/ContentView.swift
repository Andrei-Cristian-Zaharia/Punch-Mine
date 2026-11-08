import SwiftUI

struct ContentView: View {
    /// Debug screenshot launches skip the splash.
    private static let showSplash = !MineView.screenshotLaunch

    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var ads: AdCoordinator

    var body: some View {
        #if DEBUG
        // Director mode (`-scenario <name>`): straight into the scenario, see Director/DirectorMode.swift.
        if Director.shared.isActive {
            DirectorRoot()
        } else {
            mine
        }
        #else
        mine
        #endif
    }

    private var mine: some View {
        MineView()
            .overlay { if Self.showSplash { LaunchSplash() } }
            .preferredColorScheme(.dark)
            // The welcome-back sheet presents its own test ad, so the root only does it when no sheet is up.
            .adCover(item: ads.simulatedBinding(when: game.offlineReport == nil && !ads.simulatingInSheet), ads: ads)
    }
}

#Preview {
    ContentView()
        .environmentObject(GameModel())
        .environmentObject(AdCoordinator())
        .environmentObject(GameFeedback())
        .environmentObject(StoreService())
        .environmentObject(CloudSync(store: MemoryCloudStore()))
        .environmentObject(GameCenter())
}
