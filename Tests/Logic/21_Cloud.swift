import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics21")) }
/// A device's own sync settings (its id and what it last saw), separate from the shared game save.
func deviceDefaults(_ name: String) -> UserDefaults {
    let d = UserDefaults(suiteName: "test.cloud.\(name)")!
    d.removePersistentDomain(forName: "test.cloud.\(name)")
    return d
}
/// Writes a save with `played` seconds and Quarry best `area` as this device's save.
func progressSave(played: Double, area: Int, prestiges: Int = 0, products: [String] = [], transactions: [String] = []) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    dict["stats"] = ["playSeconds": played]
    var recs = dict["records"] as! [String: Any]; var r = recs["quarry"] as! [String: Any]
    r["bestArea"] = area; r["prestigeCount"] = prestiges; recs["quarry"] = r; dict["records"] = recs
    dict["ownedProducts"] = products; dict["processedTransactions"] = transactions
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func bestArea(_ g: GameModel) -> Int { g.record(for: .quarry).bestArea }

@main struct Main {
    static func main() {
        let cloud = MemoryCloudStore()
        var clock = Date(timeIntervalSince1970: 1_800_000_000)

        // Device A: real progress, uploads on first check
        progressSave(played: 7_200, area: 60, prestiges: 5, products: ["punchmine.removeads"], transactions: ["a1"])
        var g = model()
        var sync = CloudSync(store: cloud, defaults: deviceDefaults("A"), deviceName: "iPhone A", now: { clock })
        sync.attach(to: g)
        check(cloud.data(forKey: CloudSync.key) != nil, "first check uploads when iCloud is empty")
        if case .synced = sync.status { check(true, "status: synced") } else { check(false, "status: synced (\(sync.status))") }

        // Throttled while playing, forced when leaving
        let first = cloud.data(forKey: CloudSync.key)
        clock = clock.addingTimeInterval(5)
        g.save()
        check(cloud.data(forKey: CloudSync.key) == first, "saves within \(Int(CloudSync.uploadInterval)) s don't re-upload")
        clock = clock.addingTimeInterval(CloudSync.uploadInterval)
        g.save()
        check(cloud.data(forKey: CloudSync.key) != first, "a later save uploads again")
        let second = cloud.data(forKey: CloudSync.key)
        clock = clock.addingTimeInterval(1)
        sync.didSave(force: true)
        check(cloud.data(forKey: CloudSync.key) != second, "leaving the app always uploads")

        // Device B: a fresh install restores silently
        UserDefaults.standard.removeObject(forKey: key)
        g = model()
        check(bestArea(g) == 1, "device B starts fresh")
        clock = clock.addingTimeInterval(60)
        sync = CloudSync(store: cloud, defaults: deviceDefaults("B"), deviceName: "iPad B", now: { clock })
        sync.attach(to: g)
        check(bestArea(g) == 60 && g.adsRemoved && sync.conflict == nil, "a new game restores from iCloud without asking, purchases included")
        let reloaded = model()
        check(bestArea(reloaded) == 60, "the restored progress is saved on the device")

        // Same device reopening: no prompt
        sync = CloudSync(store: cloud, defaults: { let d = UserDefaults(suiteName: "test.cloud.B")!; return d }(), deviceName: "iPad B", now: { clock })
        sync.attach(to: reloaded)
        check(sync.conflict == nil, "reopening the device that uploaded last asks nothing")

        // Device C: has its own progress → the player chooses
        progressSave(played: 3_000, area: 35, prestiges: 2, products: ["punchmine.starterpack"], transactions: ["c1"])
        g = model()
        clock = clock.addingTimeInterval(60)
        sync = CloudSync(store: cloud, defaults: deviceDefaults("C"), deviceName: "iPhone C", now: { clock })
        sync.attach(to: g)
        check(sync.conflict != nil && sync.conflict?.cloud.deepest == 60 && sync.conflict?.local.deepest == 35 && bestArea(g) == 35,
              "both have progress: a conflict, nothing overwritten yet")
        let before = cloud.data(forKey: CloudSync.key)
        g.save()
        check(cloud.data(forKey: CloudSync.key) == before, "no uploads while the choice is open")
        sync.resolve(useCloud: true)
        check(bestArea(g) == 60 && g.owns(.starterPack) && g.adsRemoved, "use iCloud: progress replaced, purchases from both kept")
        check(!g.grantPurchase(.starterPack, transactionID: "c1"), "a transaction credited on this device still can't pay twice")

        // Device D keeps its own save
        progressSave(played: 9_000, area: 80, prestiges: 9)
        g = model()
        clock = clock.addingTimeInterval(60)
        sync = CloudSync(store: cloud, defaults: deviceDefaults("D"), deviceName: "iPhone D", now: { clock })
        sync.attach(to: g)
        sync.resolve(useCloud: false)
        let env = try! JSONDecoder().decode(CloudEnvelope.self, from: cloud.data(forKey: CloudSync.key)!)
        check(bestArea(g) == 80 && env.summary.deepest == 80 && env.device == sync.deviceID, "keep this device: its save becomes the iCloud copy")

        // A fresh iCloud save never replaces real progress
        UserDefaults.standard.removeObject(forKey: key)
        let fresh = model()
        let freshCloud = MemoryCloudStore()
        _ = CloudSync(store: freshCloud, defaults: deviceDefaults("E"), now: { clock })
        let e = CloudSync(store: freshCloud, defaults: deviceDefaults("E2"), now: { clock })
        e.attach(to: fresh)
        progressSave(played: 9_000, area: 70, prestiges: 3)
        g = model()
        let f = CloudSync(store: freshCloud, defaults: deviceDefaults("F"), now: { clock })
        f.attach(to: g)
        check(f.conflict == nil && bestArea(g) == 70, "a barely-started iCloud save is simply replaced")

        // Off switch
        progressSave(played: 100, area: 3)
        g = model()
        g.settings.iCloudSync = false
        let off = MemoryCloudStore()
        let s = CloudSync(store: off, defaults: deviceDefaults("G"), now: { clock })
        s.attach(to: g)
        g.save()
        check(off.data(forKey: CloudSync.key) == nil && s.status == .off, "sync off: nothing goes to iCloud")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
