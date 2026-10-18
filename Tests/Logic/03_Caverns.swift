import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
func grind(_ g: GameModel, to area: Int, buy: Bool = true) {
    var n = 0
    while g.run.maxCleared < area && n < 400000 {
        for i in 0..<30 { g.punch(i) }
        if buy {
            for t in g.zone.tools where g.toolState(t) == .affordable { g.buyTool(t) }
            for k in UpgradeKind.allCases where g.canBuy(k) { g.buy(k) }
        }
        n += 1
    }
}
@main struct Main {
    static func main() {
        let key = "punchmine.save.v1"
        UserDefaults.standard.removeObject(forKey: key)
        let g = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics"))
        check(g.zone == .quarry && g.unlockedZones == [.quarry], "fresh game is Zone 1 only")
        let need = ZoneID.caverns.unlock!.clearArea, price = ZoneID.caverns.unlock!.costs[0].amount
        grind(g, to: need - 1)
        check(!g.unlockAreaMet(.caverns), "Zone 2 requirement not met at area \(need - 1)")
        grind(g, to: need)
        check(g.unlockAreaMet(.caverns), "Zone 2 requirement met after clearing area \(need)")
        grind(g, to: 30, buy: false)
        while g.run.coins < price { for i in 0..<30 { g.punch(i) } }
        let copperBefore = g.run.coins, quarryArea = g.run.area
        check(g.canUnlock(.caverns) && g.unlockCost(.caverns) == price, "can unlock for \(Int(price)) Copper")
        g.unlockZone(.caverns)
        check(g.zone == .caverns && g.isUnlocked(.caverns) && g.zoneIntro == .caverns, "unlocked, moved into Zone 2, intro shown")
        check(g.run(for: .quarry)!.coins == copperBefore - price && g.run(for: .quarry)!.area == quarryArea, "Copper paid, Zone 1 progress kept")
        check(g.run.area == 1 && g.run.coins == 0 && g.run.levels.isEmpty, "Zone 2 starts fresh")
        let mats = Set(g.run.blocks.map(\.material))
        check(mats.isSubset(of: [.limestone, .quartz, .geode]), "Zone 2 area 1 uses Zone 2 materials: \(mats)")
        let lime = g.run.blocks.first { $0.material == .limestone }!
        check(lime.maxHP == 13, "limestone HP = 5 × 2.5 rounded (got \(lime.maxHP))")
        // Chain: break a quartz that touches another quartz
        var tested = false
        for b in g.run.blocks where b.material == .quartz && !tested {
            let i = b.id, c = i % 5, r = i / 5
            let ns = [c > 0 ? i - 1 : nil, c < 4 ? i + 1 : nil, r > 0 ? i - 5 : nil, r < 5 ? i + 5 : nil].compactMap { $0 }
            guard let n = ns.first(where: { g.run.blocks[$0].material == .quartz }) else { continue }
            let nHP = g.run.blocks[n].maxHP
            while !g.run.blocks[i].isBroken { g.punch(i) }
            let after = g.run.blocks[n]
            check(after.isBroken || abs(after.hp - nHP * 0.6) < 0.01, "chain hits touching quartz for 40% (\(after.hp) of \(nHP))")
            tested = true
        }
        check(tested, "found adjacent quartz to test chain")
        grind(g, to: 5)
        check(g.isUnlocked(.hireMiner), "Hire Miner unlocked in Zone 2 at area 4")
        while g.run.coins < g.cost(.hireMiner) { for i in 0..<30 { g.punch(i) } }
        g.buy(.hireMiner)
        check(g.minerCount > 0, "Zone 2 miner hired (\(g.minerCount))")
        // Switch back: Zone 2 leftAt set, Zone 1 resumes
        g.switchZone(to: .quarry)
        check(g.zone == .quarry && g.run.area == quarryArea && g.run(for: .caverns)!.leftAt != nil, "switch back to Zone 1 keeps both runs")
        let report = g.offlineEarnings(now: Date().addingTimeInterval(3 * 3600))
        let z2 = report?.entries.first { $0.zone == .caverns }
        check(z2 != nil && z2!.cappedSeconds == 7200, "Zone 2 earns in background, capped at 2 h (\(z2?.coins ?? -1))")
        // Prestige Zone 1 leaves Zone 2 untouched
        let z2Area = g.run(for: .caverns)!.area
        g.prestige()
        check(g.run.area == 1 && g.run(for: .caverns)!.area == z2Area && g.isUnlocked(.caverns), "Zone 1 prestige does not touch Zone 2")
        check(g.record(for: .quarry).prestigeCount == 1 && g.record(for: .caverns).prestigeCount == 0, "prestige counts are per zone")
        check(Prestige.depthReward(area: 20, multiplier: 1.6) == 54, "Zone 2 pays ×1.6: area 20 → 54")
        // Surveyor
        let pc = g.perkCoins
        g.buyPerk(.seedMoney); g.buyPerk(.prospector); g.buyPerk(.prospector); g.buyPerk(.surveyor)
        check(g.level(.surveyor) == 1 && g.unlockCost(.caverns) == (ZoneID.caverns.unlock!.costs[0].amount * 0.95).rounded(), "Surveyor 1 = −5% (PC \(pc))")
        // Save roundtrip
        g.save()
        let g2 = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics"))
        check(g2.unlockedZones == g.unlockedZones && g2.run(for: .caverns)!.area == z2Area && g2.zone == .quarry, "multi-zone save roundtrip")
        // Version 2 save migrates
        let runJSON = String(data: try! JSONEncoder().encode(g.run), encoding: .utf8)!
        let v2 = "{\"version\":2,\"run\":\(runJSON),\"bestArea\":7,\"holdUnlocked\":true,\"seed\":123,\"perks\":{\"heavyFists\":2},\"perkCoins\":5,\"bestPrestigeArea\":20,\"prestigeCount\":1}"
        UserDefaults.standard.set(v2.data(using: .utf8)!, forKey: key)
        let g3 = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics"))
        check(g3.zone == .quarry && g3.unlockedZones == [.quarry] && g3.record(for: .quarry).bestPrestigeArea == 20 && g3.level(.heavyFists) == 2 && g3.perkCoins == 5 && g3.holdUnlocked, "v2 save migrates into Zone 1")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
