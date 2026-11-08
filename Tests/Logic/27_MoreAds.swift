import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics27")) }
func save(area: Int = 20, extra: [String: Any] = [:]) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var recs = dict["records"] as! [String: Any]
    var rec = recs["quarry"] as! [String: Any]
    rec["bestArea"] = area; rec["bestCleared"] = area - 1
    recs["quarry"] = rec; dict["records"] = recs
    for (k, v) in extra { dict[k] = v }
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func watch(_ g: GameModel, _ p: AdPlacement) { g.adWillShow(p); g.adDidFinish(p, rewarded: true) }

@main struct Main {
    static func main() {
        // Daily double: only after today's claim, once a day
        save()
        var g = model()
        g.adsAvailable = true
        check(!g.canWatch(.dailyDouble), "no daily double before claiming")
        g.claimDaily()
        let wooden = g.chestCount(.wooden)
        check(g.canWatch(.dailyDouble), "offered after claiming")
        watch(g, .dailyDouble)
        check(g.chestCount(.wooden) == wooden + 1 && !g.canWatch(.dailyDouble), "day 1 again (a Wooden Chest), once a day")

        // Free gadget
        let before = g.stashCount
        watch(g, .freeGadget)
        check(g.stashCount == before + 1 && Consumable.allCases.filter(\.isGadget).contains { g.consumableCount($0) > 0 }, "a free gadget lands in the stash")
        watch(g, .freeGadget)
        check(!g.canWatch(.freeGadget), "two a day")

        // Event Rush: only with an event, and not while one is running
        check(g.activeEvent != nil && g.canWatch(.eventRush), "Event Rush offered during an event")
        watch(g, .eventRush)
        check(abs(g.eventRushRemaining - AdRules.eventRushSeconds) < 1e-9 && !g.canWatch(.eventRush), "5 minutes, not stacked")

        // Chest upgrade: lowest chest first
        save(extra: ["chests": ["wooden": 1, "iron": 1]])
        g = model()
        g.adsAvailable = true
        check(g.upgradableChest == .wooden, "the Wooden Chest goes first")
        watch(g, .chestUpgrade)
        check(g.chestCount(.wooden) == 0 && g.chestCount(.iron) == 2, "Wooden → Iron")
        watch(g, .chestUpgrade); watch(g, .chestUpgrade)
        check(g.chestCount(.iron) == 0 && g.chestCount(.golden) == 2 && !g.canWatch(.chestUpgrade), "Iron → Golden, and nothing left to upgrade")

        // Daily cap still holds across every placement
        check(AdRules.dailyCap == 20 && AdPlacement.allCases.allSatisfy { $0.dailyLimit <= AdRules.dailyCap }, "one daily cap over all rewarded ads")

        // Behind a menu the game steps less often but keeps time
        save()
        g = model()
        g.mineCovered = true
        g.advance(by: 0.25)
        check(g.clock == 0.25, "a covered tick still advances the full time")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
