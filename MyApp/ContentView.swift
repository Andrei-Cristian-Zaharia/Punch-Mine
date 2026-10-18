import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var ads: AdCoordinator

    var body: some View {
        MineView()
            .preferredColorScheme(.dark)
            // The welcome-back sheet presents its own test ad, so the root only does it when no sheet is up.
            .adCover(item: ads.simulatedBinding(when: game.offlineReport == nil), ads: ads)
    }
}

#Preview {
    ContentView()
        .environmentObject(GameModel())
        .environmentObject(AdCoordinator())
}
