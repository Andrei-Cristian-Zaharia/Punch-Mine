import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics10")) }
func saveAt(area: Int, weak: Bool = false, treasure: Bool = false, levels: [String: Int] = [:], items: [String: Int] = [:],
            equipped: [String: String] = [:], chests: [String: Int] = [:], scrap: Int = 0, coins: Double = 0) {
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
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func clearWeak(_ g: GameModel) { var n = 0; let a = g.run.area; while g.run.area == a && n < 100 { for i in 0..<30 { g.punch(i) }; n += 1 } }
@main struct Main {
    static func main() {
        saveAt(area: 24, levels: ["strength": 30], items: ["toolBelt": 6, "seersVisor": 2], equipped: ["belt": "toolBelt", "helmet": "seersVisor"],
               chests: ["iron": 2], scrap: 300, coins: 9000)
        var g = model()
        g.resetProgress(keepItems: true)
        check(g.run.area == 1 && g.run.coins == 0 && g.run.levels.isEmpty && g.perkCoins == 0, "keep-items reset: mine, coins and upgrades start over")
        check(g.itemLevel("toolBelt") == 6 && g.equipped["helmet"] == "seersVisor" && g.chestCount(.iron) == 2 && g.scrap == 300, "items, levels, slots, chests and Scrap are kept")
        check(abs(g.punchDamage - 1.23) < 1e-9, "kept Tool Belt Lv6 still boosts damage (1 × 1.23)")
        g = model()
        check(g.itemLevel("toolBelt") == 6 && g.scrap == 300, "kept items are in the save after relaunch")
        g.resetProgress(keepItems: false)
        check(g.items.isEmpty && g.equipped.isEmpty && g.chestCount == 0 && g.scrap == 0, "reset everything clears items too")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
