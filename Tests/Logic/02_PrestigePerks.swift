import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
func grind(_ g: GameModel, to area: Int) {
    var n = 0
    while g.run.maxCleared < area && n < 400000 {
        for i in 0..<30 { g.punch(i) }
        for t in g.zone.tools where g.toolState(t) == .affordable { g.buyTool(t) }
        for k in UpgradeKind.allCases where g.canBuy(k) { g.buy(k) }
        n += 1
    }
}
@main struct Main {
    static func main() {
        UserDefaults.standard.removeObject(forKey: "punchmine.save.v1")
        let g = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics"))
        // Formula table from the design doc
        check([12, 15, 18, 20, 22, 25, 28, 30].map { Prestige.depthReward(area: $0) } == [7, 15, 25, 33, 43, 60, 79, 93], "PC table matches doc")
        check([31, 50, 100].map { Prestige.depthReward(area: $0) } == [97, 168, 356], "past area 30 PC grows 3.75 per area (31 → 97, 100 → 356)")
        grind(g, to: 11)
        check(!g.canPrestige, "no prestige at area 11 cleared")
        grind(g, to: 12)
        check(g.canPrestige && g.prestigeReward == 7, "prestige available at 12 for 7 PC (got \(g.prestigeReward))")
        check(g.prestigeRecordBonus == 0, "no record bonus on first prestige")
        grind(g, to: 20)
        let reward = g.prestigeReward
        check(reward == 33, "area 20 pays 33 (got \(reward), maxCleared \(g.run.maxCleared))")
        let best = g.bestArea
        g.prestige()
        check(g.perkCoins == reward && g.run.area == 1 && g.run.coins == 0 && g.run.levels.isEmpty && g.run.toolIndex == -1, "prestige resets run and pays PC")
        check(g.bestArea == best && g.holdUnlocked && g.bestPrestigeArea == 20, "records and hold kept")
        check(g.prestigeRequiredArea == 12, "next prestige floor = max(12, 20-8) = 12")
        // Perks
        check(g.perkState(.keenEye) == .locked, "Keen Eye locked before Heavy Fists 3")
        let hfCost = Perk.heavyFists.cost(level: 0) + Perk.heavyFists.cost(level: 1) + Perk.heavyFists.cost(level: 2)
        for _ in 0..<3 { g.buyPerk(.heavyFists) }
        check(g.level(.heavyFists) == 3 && g.perkCoins == reward - hfCost, "Heavy Fists 1-3 cost \(hfCost) PC")
        check(g.perkState(.keenEye) != .locked, "Keen Eye unlocked")
        check(abs(g.perkDamageMultiplier - 1.3) < 1e-9, "Heavy Fists 3 = +30% damage")
        // Second prestige with the record bonus, then spend on starting perks
        grind(g, to: 22)
        check(g.prestigeRecordBonus == 4, "record bonus 2 per area past 20 (got \(g.prestigeRecordBonus))")
        g.prestige()
        check(g.run.coins == 0 && g.minerCount == 0, "no starting perks yet")
        check(g.prestigeRequiredArea == 14, "floor = 22-8 = 14")
        g.buyPerk(.seedMoney)
        for _ in 0..<2 { g.buyPerk(.foreman) }
        g.buyPerk(.dayOneCrew)
        check(g.level(.seedMoney) == 1 && g.level(.dayOneCrew) == 1, "Seed Money and Day-One Crew bought (PC left \(g.perkCoins))")
        grind(g, to: 14)
        g.prestige()
        check(g.minerCount == 1 && g.run.coins == 200, "new run starts with Seed Money 200 and 1 Day-One miner")
        // Offline
        grind(g, to: 5)
        let cps = g.minerCoinsPerSecond
        let r = g.earnings(for: .quarry, elapsed: 3 * 3600)
        check(cps > 0 && r != nil && abs(r!.coins - (cps * 0.25 * 7200).rounded(.down)) < 1, "offline caps at 2h: \(r?.coins ?? -1) at \(cps)/s")
        check(g.earnings(for: .quarry, elapsed: 30) == nil && g.earnings(for: .quarry, elapsed: -500) == nil, "no offline under 60 s or backwards clock")
        // Persistence incl. new fields
        g.save()
        let g2 = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics"))
        check(g2.perkCoins == g.perkCoins && g2.level(.heavyFists) == 3 && g2.prestigeCount == 3 && g2.bestPrestigeArea == 22, "perks and prestige saved")
        UserDefaults.standard.removeObject(forKey: "punchmine.save.v1")
    }
}
