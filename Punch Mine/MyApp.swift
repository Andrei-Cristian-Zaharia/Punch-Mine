import SwiftUI

@main struct MyApp: App {
    @StateObject private var game: GameModel
    @StateObject private var ads = AdCoordinator()
    @StateObject private var feedback = GameFeedback()
    @StateObject private var store = StoreService()
    @StateObject private var gameCenter = GameCenter()
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
        // Director mode (`-scenario <name>`): a throwaway profile with no analytics log (Director/DirectorMode.swift).
        if Director.shared.isActive {
            _game = StateObject(wrappedValue: GameModel(analytics: Analytics(sinks: [], stateKey: "punchmine.director.analytics")))
            return
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
                .environmentObject(gameCenter)
                .onAppear {
                    #if DEBUG
                    // Director mode: no store, iCloud, consent form, ads or Game Center; the game only.
                    if Director.shared.isActive {
                        feedback.attach(to: game)
                        game.start()
                        return
                    }
                    #endif
                    store.attach(to: game)
                    // Debug launches with a made-up save never touch the real iCloud backup.
                    if !Self.debugSaveLaunch { cloud.attach(to: game) }
                    ads.prepare(game: game)
                    feedback.attach(to: game)
                    gameCenter.attach(to: game)
                    game.start()
                }
                .onChange(of: scenePhase) { phase in
                    #if DEBUG
                    if Director.shared.isActive {
                        if phase == .active { game.start() } else { game.stop() }
                        return
                    }
                    #endif
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
    static var debugSaveLaunch: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "debugSave") != nil
        #else
        false
        #endif
    }

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
