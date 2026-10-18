import Foundation
UserDefaults.standard.removeObject(forKey: "punchmine.save.v1")
let g = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics"))
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
check(g.run.area == 1 && g.run.blocks.count == 30, "fresh area 1 with 30 blocks")
// Punch every block of area 1 to death with taps (bypass tap cap by using punch)
var guardN = 0
while g.run.area == 1 && guardN < 5000 { for i in 0..<30 { g.punch(i) }; guardN += 1 }
check(g.run.area == 2, "area 1 clears into area 2 (punches: \(g.punchCount))")
check(g.run.coins > 0, "earned coins: \(g.run.coins)")
check(g.holdUnlocked, "hold unlocked at area 2")
let before = g.run.coins
g.buy(.strength)
check(g.run.level(.strength) == 1 && g.run.coins == before - UpgradeKind.strength.cost(level: 0), "bought strength for its price (\(UpgradeKind.strength.cost(level: 0)))")
check(!g.canBuy(.hireMiner), "miner locked before area 4")
// Grind to area 10 buying cheapest affordable upgrade
var n = 0
while g.run.area < 10 && n < 200000 {
    for i in 0..<30 { g.punch(i) }
    for k in UpgradeKind.allCases where g.canBuy(k) { g.buy(k) }
    for t in g.zone.tools where g.toolState(t) == .affordable { g.buyTool(t) }
    n += 1
}
check(g.run.area >= 10, "reached area \(g.run.area); strength Lv \(g.run.level(.strength)), tool \(g.tool.name), miners \(g.minerCount)")
// Tap cap
let pc = g.punchCount
let idx = g.run.blocks.firstIndex { !$0.isBroken }!
for _ in 0..<20 { g.tap(idx) }
check(g.punchCount - pc <= 12, "tap cap limits to 12/s (got \(g.punchCount - pc))")
// Save roundtrip
g.save()
let g2 = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics"))
check(g2.run.area == g.run.area && g2.run.coins == g.run.coins, "save/load roundtrip")
// Treasure generation rate
var t = 0; for a in 1...2000 { if AreaGenerator.blocks(zone: .quarry, area: (a % 30) + 1, seed: UInt64(a)).contains(where: { $0.isTreasure }) { t += 1 } }
check(t > 200 && t < 400, "treasure rate ~15%: \(Double(t)/20)%")
let b20 = AreaGenerator.blocks(zone: .quarry, area: 20, seed: 7)
check(b20.filter{!$0.isTreasure}.count >= 29, "area 20 composition ok")
print(NumberText.format(12400), NumberText.format(1_234_567), NumberText.format(999))
UserDefaults.standard.removeObject(forKey: "punchmine.save.v1")
