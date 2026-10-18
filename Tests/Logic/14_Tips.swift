import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics10")) }
func saveAt(area: Int, weak: Bool = false, treasure: Bool = false, levels: [String: Int] = [:], items: [String: Int] = [:],
            equipped: [String: String] = [:], chests: [String: Int] = [:], scrap: Int = 0, coins: Double = 0,
            perks: [String: Int] = [:], tool: Int = -1) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var blocks = AreaGenerator.blocks(zone: .quarry, area: area, seed: 21, treasureChance: treasure ? 1 : 0)
    if weak { blocks = blocks.map { Block(id: $0.id, material: $0.material, maxHP: $0.maxHP, hp: 1, armor: 0, reward: $0.reward) } }
    var runs = dict["runs"] as! [String: Any]; var q = runs["quarry"] as! [String: Any]
    q["area"] = area; q["maxCleared"] = area - 1; q["levels"] = levels; q["coins"] = coins
    q["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(blocks))
    runs["quarry"] = q; dict["runs"] = runs; dict["seeds"] = ["quarry": 21]
    var recs = dict["records"] as! [String: Any]; var r = recs["quarry"] as! [String: Any]
    r["bestArea"] = area; r["bestCleared"] = area - 1; recs["quarry"] = r; dict["records"] = recs
    dict["items"] = items; dict["equipped"] = equipped; dict["chests"] = chests; dict["scrap"] = scrap
    dict["perks"] = perks
    var runs2 = dict["runs"] as! [String: Any]; var q2 = runs2["quarry"] as! [String: Any]; q2["toolIndex"] = tool; runs2["quarry"] = q2; dict["runs"] = runs2
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func clearWeak(_ g: GameModel) { var n = 0; let a = g.run.area; while g.run.area == a && n < 100 { for i in 0..<30 { g.punch(i) }; n += 1 } }
func run(_ g: GameModel, _ seconds: Double) { for _ in 0..<Int(seconds * 20) { g.advance(by: 0.05) } }
func punchCheapest(_ g: GameModel) {
    if let t = g.run.blocks.filter({ !$0.isBroken }).min(by: { $0.hp < $1.hp }) { g.punch(t.id) }
}
@main struct Main {
    static func main() {
        UserDefaults.standard.removeObject(forKey: key)
        var g = model()
        run(g, 3)
        check(g.activeTip == nil, "no tip before there's anything to say")
        while !g.canBuy(.strength) { punchCheapest(g) }
        run(g, 1)
        check(g.activeTip == .upgrade, "can afford Strength: the upgrade tip appears (\(String(describing: g.activeTip)))")
        g.buy(.strength)
        run(g, 1)
        check(g.activeTip == nil && g.seenTips.contains("upgrade"), "buying an upgrade dismisses it and marks it seen")
        // Never twice
        UserDefaults.standard.removeObject(forKey: key)
        g = model(); g.seenTips = ["upgrade"]
        while !g.canBuy(.strength) { punchCheapest(g) }
        run(g, 8)
        check(g.activeTip != .upgrade, "a seen tip doesn't come back")
        // Got it, and the gap between tips
        UserDefaults.standard.removeObject(forKey: key)
        g = model()
        while !g.canBuy(.strength) { punchCheapest(g) }
        run(g, 3)
        g.dismissTip()
        check(g.activeTip == nil && g.seenTips.contains("upgrade"), "Got it dismisses and marks seen")
        // Only the armor tip is left to show, so other state (like a treasure block on screen) can't take its place.
        g.seenTips = Set(Tip.allCases.map(\.rawValue)).subtracting(["armor"])
        g.noteTipEvent(.armor)
        run(g, 1)
        check(g.activeTip == nil, "the next tip waits for the gap")
        g.noteTipEvent(.armor); run(g, GameModel.tipGap); g.noteTipEvent(.armor); run(g, 0.6)
        check(g.activeTip == .armor, "an armor deflect raises the armor tip after the gap (\(String(describing: g.activeTip)), seen \(g.seenTips.sorted()))")
        run(g, Tip.armor.duration + 1)
        check(g.activeTip == nil && g.seenTips.contains("armor"), "unanswered tips time out and count as seen")
        // Seen tips are saved
        g.save()
        let reloaded = model()
        check(reloaded.seenTips.isSuperset(of: ["upgrade", "armor"]), "seen tips survive a relaunch")
        reloaded.resetProgress(keepItems: false)
        check(reloaded.seenTips.contains("upgrade"), "resetting progress keeps tips seen")
        reloaded.resetTips()
        check(reloaded.seenTips.isEmpty, "Show all tips again clears them")
        // Doing it first skips the tip
        UserDefaults.standard.removeObject(forKey: key)
        g = model()
        while !g.canBuy(.strength) { punchCheapest(g) }
        g.buy(.strength)
        run(g, 1)
        check(g.seenTips.contains("upgrade") && g.activeTip != .upgrade, "buying before the tip shows skips it for good")
        // Settings off
        UserDefaults.standard.removeObject(forKey: key)
        g = model(); g.settings.showTips = false
        while !g.canBuy(.strength) { punchCheapest(g) }
        run(g, 5)
        check(g.activeTip == nil, "no tips when Show tips is off")
        // Saves from before tips existed
        saveAt(area: 40)
        var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
        dict.removeValue(forKey: "seenTips")
        UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
        check(model().seenTips.count == Tip.allCases.count, "an older save past area 20 skips the tips")
        saveAt(area: 5)
        dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
        dict.removeValue(forKey: "seenTips")
        UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
        check(model().seenTips.isEmpty, "an older early save still gets tips")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
