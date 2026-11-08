import Foundation
import Combine

/// The bits of iCloud's key-value store the sync uses; tests swap in `MemoryCloudStore`.
protocol CloudKeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Data?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudKeyValueStore {}

final class MemoryCloudStore: CloudKeyValueStore {
    var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Data?, forKey key: String) { values[key] = value }
    func synchronize() -> Bool { true }
}

/// What a save adds up to, to compare two saves at a glance.
struct SaveSummary: Codable, Equatable {
    var playSeconds: Double
    var hearts: Int
    var prestiges: Int
    var zones: Int
    /// Zone id → best area.
    var bestAreas: [String: Int]

    init(_ save: SaveData) {
        playSeconds = save.stats?.playSeconds ?? save.runs.values.map(\.playSeconds).reduce(0, +)
        hearts = save.records.values.map(\.heartsDefeated).reduce(0, +)
        prestiges = save.records.values.map(\.prestigeCount).reduce(0, +)
        zones = save.unlockedZones.count
        bestAreas = save.records.mapValues(\.bestArea)
    }

    init?(data: Data) {
        guard let save = try? JSONDecoder().decode(SaveData.self, from: data) else { return nil }
        self.init(save)
    }

    /// A game that has barely started: replaced by an iCloud save without asking.
    var isFresh: Bool { playSeconds < CloudSync.freshPlaySeconds && prestiges == 0 && hearts == 0 }

    var deepest: Int { bestAreas.values.max() ?? 1 }
}

/// One save as stored in iCloud.
struct CloudEnvelope: Codable {
    var version = 1
    var savedAt: Date
    var device: String
    var deviceName: String
    var summary: SaveSummary
    var save: Data
}

/// Both this device and iCloud have real progress: the player chooses.
struct CloudConflict: Identifiable, Equatable {
    let id = UUID()
    let local: SaveSummary
    let cloud: SaveSummary
    let cloudSavedAt: Date
    let cloudDeviceName: String
}

/// Keeps one copy of the save in iCloud. This device's save stays the one the game plays from; iCloud is a backup
/// that a new or reinstalled device restores from, and that two devices with progress never overwrite silently.
@MainActor
final class CloudSync: ObservableObject {
    enum Status: Equatable { case off, unavailable, checking, synced(Date), waiting }

    static let key = "punchmine.cloud.v1"
    /// Minimum seconds between two uploads while playing; leaving the app always uploads.
    static let uploadInterval = 20.0
    /// Below this much play (and no prestige or Heart) a game counts as new.
    static let freshPlaySeconds = 300.0
    private static let knownKey = "punchmine.cloud.known"
    private static let deviceKey = "punchmine.cloud.device"

    @Published private(set) var status: Status = .checking
    @Published var conflict: CloudConflict?

    private let store: CloudKeyValueStore
    private let defaults: UserDefaults
    private let now: () -> Date
    private let available: () -> Bool
    private let deviceName: String
    let deviceID: String
    private weak var game: GameModel?
    /// Uploads wait until the first check has run, so a fresh install can't overwrite a real iCloud save.
    private var checked = false
    private var lastUpload: Date?
    private var pending: CloudEnvelope?
    /// A fresh game found iCloud empty; uploads wait until there is real progress.
    private var awaitingCloud = false
    /// iCloud holds a save this version can't read; never overwrite it.
    private var cloudUnreadable = false
    private var observer: NSObjectProtocol?

    init(store: CloudKeyValueStore, defaults: UserDefaults = .standard, deviceName: String = "another device",
         now: @escaping () -> Date = Date.init, available: @escaping () -> Bool = { true }) {
        self.store = store
        self.defaults = defaults
        self.now = now
        self.available = available
        self.deviceName = deviceName
        if let id = defaults.string(forKey: Self.deviceKey) {
            deviceID = id
        } else {
            deviceID = UUID().uuidString
            defaults.set(deviceID, forKey: Self.deviceKey)
        }
    }

    private var enabled: Bool { game?.settings.iCloudSync ?? false }

    func attach(to game: GameModel) {
        guard self.game !== game else { return }
        self.game = game
        game.onSaved = { [weak self] in self?.didSave() }
        // A backup that finishes downloading after launch gets checked again.
        if let kv = store as? NSUbiquitousKeyValueStore {
            observer = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                              object: kv, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.externalChange() }
            }
        }
        check()
    }

    // MARK: Upload

    /// Called after every local save. Throttled while playing.
    func didSave(force: Bool = false) {
        guard enabled, checked, conflict == nil, !cloudUnreadable else { return }
        // A brand-new game never replaces a backup that may still be downloading; it uploads once there is real progress.
        if awaitingCloud {
            guard let data = game?.encodedSaveWithoutSaving(), let local = SaveSummary(data: data), !local.isFresh else { return }
            awaitingCloud = false
        }
        if !force, let last = lastUpload, now().timeIntervalSince(last) < Self.uploadInterval { return }
        upload()
    }

    private func upload() {
        guard let game, available() else { status = available() ? status : .unavailable; return }
        guard !cloudUnreadable else { return }
        guard let data = game.encodedSaveWithoutSaving(), let summary = SaveSummary(data: data) else { return }
        let stamp = now()
        let envelope = CloudEnvelope(savedAt: stamp, device: deviceID, deviceName: deviceName, summary: summary, save: data)
        guard let encoded = try? JSONEncoder().encode(envelope) else { return }
        store.set(encoded, forKey: Self.key)
        store.synchronize()
        lastUpload = stamp
        defaults.set(stamp.timeIntervalSince1970, forKey: Self.knownKey)
        status = .synced(stamp)
    }

    // MARK: Check (launch and returning to the app)

    /// Compares iCloud with this device: restores a new game, uploads when iCloud has nothing newer,
    /// and asks when both have real progress.
    func check() {
        guard let game else { return }
        guard enabled else { status = .off; checked = true; return }
        guard available() else { status = .unavailable; checked = true; return }
        status = .checking
        store.synchronize()
        guard let raw = store.data(forKey: Self.key) else {
            checked = true
            if let data = game.encodedSaveWithoutSaving(), let local = SaveSummary(data: data), local.isFresh {
                // Nothing in iCloud yet, possibly still downloading after a reinstall: wait for real progress
                // (or the backup arriving) before uploading anything.
                awaitingCloud = true
                status = .synced(now())
            } else {
                upload()
            }
            return
        }
        guard let cloud = try? JSONDecoder().decode(CloudEnvelope.self, from: raw) else {
            // Written by a newer version: never overwrite it.
            cloudUnreadable = true
            checked = true
            status = .unavailable
            return
        }
        let known = defaults.double(forKey: Self.knownKey)
        // Our own upload, or one we already adopted or answered.
        if cloud.device == deviceID || (known > 0 && abs(cloud.savedAt.timeIntervalSince1970 - known) < 0.001) {
            checked = true
            status = .synced(Date(timeIntervalSince1970: max(known, cloud.savedAt.timeIntervalSince1970)))
            return
        }
        guard let localData = game.encodedSaveWithoutSaving(), let local = SaveSummary(data: localData) else { return }
        if cloud.summary.isFresh {
            checked = true
            upload()
        } else if local.isFresh {
            adopt(cloud)
            game.showToast("Progress restored from iCloud")
        } else {
            pending = cloud
            conflict = CloudConflict(local: local, cloud: cloud.summary, cloudSavedAt: cloud.savedAt, cloudDeviceName: cloud.deviceName)
            status = .waiting
        }
    }

    /// The player's answer to a conflict.
    func resolve(useCloud: Bool) {
        guard let cloud = pending else { conflict = nil; return }
        pending = nil
        conflict = nil
        if useCloud {
            adopt(cloud)
        } else {
            checked = true
            upload()
        }
    }

    private func adopt(_ cloud: CloudEnvelope) {
        guard game?.importSave(cloud.save) == true else {
            // This version can't read that save: keep it in iCloud and ask the player to update.
            cloudUnreadable = true
            checked = true
            status = .unavailable
            game?.showToast("Update Punch Mine to restore your iCloud progress")
            return
        }
        defaults.set(cloud.savedAt.timeIntervalSince1970, forKey: Self.knownKey)
        checked = true
        status = .synced(cloud.savedAt)
        // The merged save (purchases from both) becomes the new iCloud copy.
        upload()
    }

    private func externalChange() {
        guard conflict == nil else { return }
        checked = false
        awaitingCloud = false
        check()
    }

    /// Settings toggle changed.
    func settingChanged() {
        if enabled { checked = false; check() } else { status = .off }
    }
}
