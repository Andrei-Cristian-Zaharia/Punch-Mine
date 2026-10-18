import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics5")) }
func grind(_ g: GameModel, to area: Int, buy: Bool = true) {
    var n = 0
    while g.run.maxCleared < area && n < 400000 {
        for i in 0..<30 { g.punch(i) }
        if buy {
            for t in g.zone.tools where g.toolState(t) == .affordable { g.buyTool(t) }
            for k in [UpgradeKind.strength, .speed, .critChance, .training] where g.canBuy(k) { g.buy(k) }
        }
        n += 1
    }
}
func earnUntil(_ g: GameModel, _ amount: Double) { while g.run.coins < amount { for i in 0..<30 { g.punch(i) } } }
func live(_ g: GameModel, seconds: Double) { g.start(); RunLoop.main.run(until: Date().addingTimeInterval(seconds)); g.stop() }
@main struct Main {
    static func main() {
        UserDefaults.standard.removeObject(forKey: key)
        let g = model()
        check(UpgradeKind.allCases.count == 17 && g.zone.tools.count == 10 && ZoneID.caverns.tools.count == 5, "17 upgrades, 10 + 5 tools")
        grind(g, to: 7)
        earnUntil(g, g.cost(.focus)); g.buy(.focus)
        check(g.focusMaxStacks == 2, "Focus 1 allows 2 stacks")
        let target = g.run.blocks.firstIndex { !$0.isBroken && $0.maxHP > 100 } ?? g.run.blocks.firstIndex { !$0.isBroken }!
        for _ in 0..<3 where !g.run.blocks[target].isBroken { g.punch(target) }
        check(g.focusStacks == min(2, g.focusStacks) && abs(g.focusMultiplier - (1 + 0.04 * Double(g.focusStacks))) < 1e-9, "Focus stacks cap and multiply (\(g.focusStacks) → ×\(g.focusMultiplier))")
        let other = g.run.blocks.firstIndex { !$0.isBroken && $0.id != target }!
        g.punch(other)
        check(g.focusStacks == 0, "switching blocks resets Focus")
        earnUntil(g, g.cost(.feverStamina)); g.buy(.feverStamina)
        check(abs(g.feverDuration - 8.5) < 1e-9, "Fever Stamina 1 = 8.5 s")
        // Driller
        grind(g, to: 8)
        earnUntil(g, g.cost(.hireDriller)); g.buy(.hireDriller)
        check(g.minerCount(.driller) == 1, "Driller hired at area 8")
        let armored = g.run.blocks.filter { !$0.isBroken && !$0.isTreasure }.max { ($0.armor, $0.hp) < ($1.armor, $1.hp) }!
        live(g, seconds: 3.5)
        let after = g.run.blocks[armored.id]
        check(after.hp < armored.hp || after.isBroken || g.run.area > 8, "Driller hit the most armored block (\(armored.material))")
        // Tools in order with crit bonus
        grind(g, to: 12)
        check(g.toolState(g.zone.tools[3]) == .locked, "Shockwave locked until Spiked Gloves is owned")
        let critBefore = g.critChance
        if g.run.toolIndex < 0 { earnUntil(g, g.toolCost(g.zone.tools[0])); g.buyTool(g.zone.tools[0]) }
        if g.run.toolIndex < 1 { earnUntil(g, g.toolCost(g.zone.tools[1])); g.buyTool(g.zone.tools[1]) }
        earnUntil(g, g.toolCost(g.zone.tools[2])); g.buyTool(g.zone.tools[2])
        check(g.tool.name == "Spiked Gloves" && abs(g.critChance - critBefore - 0.05) < 1e-9, "Spiked Gloves adds 5% crit")
        // Contracts
        earnUntil(g, g.cost(.contracts)); g.buy(.contracts)
        check(abs(g.clearBonusShare - 0.30) < 1e-9, "Contracts 1 = 30% clear bonus")
        // Blaster
        grind(g, to: 14)
        earnUntil(g, g.cost(.hireBlaster))
        let cpsBefore = g.minerCoinsPerSecond
        g.buy(.hireBlaster)
        check(g.minerCount(.blaster) == 1 && g.minerCoinsPerSecond > cpsBefore, "Blaster raises background income (\(cpsBefore) → \(g.minerCoinsPerSecond))")
        let hpBefore = g.run.blocks.map(\.hp)
        live(g, seconds: 6.5)
        let hitCount = zip(hpBefore, g.run.blocks.map(\.hp)).filter { $0.1 < $0.0 }.count
        check(hitCount >= 3 || g.run.area > 14, "Blaster damages several blocks at once (\(hitCount) blocks lost HP)")
        // Shift Pace
        earnUntil(g, g.cost(.shiftPace)); g.buy(.shiftPace)
        check(abs(g.minerInterval(.driller, run: g.run) - 2.88) < 1e-9, "Shift Pace 1 makes Driller swing every 2.88 s")
        // Version 3 save with old tool positions
        var json = String(data: UserDefaults.standard.data(forKey: key)!, encoding: .utf8)!
        json = json.replacingOccurrences(of: "\"version\":4", with: "\"version\":3")
        g.save()
        var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
        _ = json
        dict["version"] = 3
        var runs = dict["runs"] as! [String: Any]
        var q = runs["quarry"] as! [String: Any]; q["toolIndex"] = 2; runs["quarry"] = q
        dict["runs"] = runs
        dict["seeds"] = ["quarry": 7]
        UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
        let g2 = model()
        check(g2.run.toolIndex == 3 && g2.tool.name == "Shockwave Glove", "v3 save: old Shockwave index 2 migrates to 3")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
