import SwiftUI

@main struct MyApp: App {
    @StateObject private var game: GameModel
    @StateObject private var ads = AdCoordinator()
    @StateObject private var feedback = GameFeedback()
    @StateObject private var store = StoreService()

    init() {
        #if DEBUG
        // Test helper: `-debugSave fresh` starts a new game, `-debugSave /path/save.json` loads that save.
        if let path = UserDefaults.standard.string(forKey: "debugSave") {
            if path == "fresh" {
                UserDefaults.standard.removeObject(forKey: "punchmine.save.v1")
            } else if let data = FileManager.default.contents(atPath: path) {
                UserDefaults.standard.set(data, forKey: "punchmine.save.v1")
            }
        }
        #endif
        _game = StateObject(wrappedValue: GameModel())
    }
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .environmentObject(ads)
                .environmentObject(feedback)
                .environmentObject(store)
                .onAppear {
                    store.attach(to: game)
                    ads.prepare(game: game)
                    feedback.attach(to: game)
                    game.start()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        game.start()
                        feedback.sound.appBecameActive()
                    } else {
                        game.stop()
                        feedback.sound.appWentInactive()
                    }
                }
        }
    }
}
