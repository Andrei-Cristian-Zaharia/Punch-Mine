import SwiftUI

@main struct MyApp: App {
    @StateObject private var game: GameModel
    @StateObject private var ads = AdCoordinator()
    @StateObject private var feedback = GameFeedback()
    @StateObject private var store = StoreService()
    @StateObject private var cloud = CloudSync(store: NSUbiquitousKeyValueStore.default, deviceName: MyApp.deviceName,
                                              available: { MyApp.iCloudAvailable })

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
                .environmentObject(cloud)
                .onAppear {
                    store.attach(to: game)
                    // Debug launches with a made-up save never touch the real iCloud backup.
                    if UserDefaults.standard.string(forKey: "debugSave") == nil { cloud.attach(to: game) }
                    ads.prepare(game: game)
                    feedback.attach(to: game)
                    game.start()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        game.start()
                        cloud.check()
                        feedback.sound.appBecameActive()
                    } else {
                        game.stop()
                        cloud.didSave(force: true)
                        feedback.sound.appWentInactive()
                    }
                }
        }
    }
}

extension MyApp {
    /// The iCloud entitlement is iPhone/iPad only until the app has a real bundle ID (see the build settings).
    static var iCloudAvailable: Bool {
        #if os(iOS)
        FileManager.default.ubiquityIdentityToken != nil
        #else
        false
        #endif
    }

    /// Shown on the other device when choosing between saves.
    static var deviceName: String {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? "an iPad" : "an iPhone"
        #else
        Host.current().localizedName ?? "a Mac"
        #endif
    }
}
