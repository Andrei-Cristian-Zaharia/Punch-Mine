import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics7")) }
func grind(_ g: GameModel, to area: Int, buy: Bool = true) {
    var n = 0
    while g.run.maxCleared < area && n < 400000 {
        for i in 0..<30 { g.punch(i) }
        if buy {
            for t in g.zone.tools where g.toolState(t) == .affordable { g.buyTool(t) }
            for k in [UpgradeKind.strength, .speed, .critChance] where g.canBuy(k) { g.buy(k) }
        }
        n += 1
    }
}
func earn(_ g: GameModel, _ a: Double) { while g.run.coins < a { for i in 0..<30 { g.punch(i) } } }
func live(_ g: GameModel, _ s: Double) { g.start(); RunLoop.main.run(until: Date().addingTimeInterval(s)); g.stop() }
@main struct Main {
    static func main() {
        UserDefaults.standard.removeObject(forKey: key)
        let g = model()
        check(ZoneID.allCases.count == 5 && ZoneID.magma.tools.count == 9, "5 zones; Magma has 9 tools")
        check(!g.unlockAreaMet(.magma), "Magma needs Crystal Caverns first")
        grind(g, to: 30, buy: true); earn(g, ZoneID.caverns.unlock!.costs[0].amount); g.unlockZone(.caverns)
        check(g.zone == .caverns, "in Zone 2")
        let lime = g.run.blocks.first { $0.material == .limestone }!
        check(lime.reward == 2, "Zone 2 pays ×2 per block (limestone \(lime.reward))")
        let magma = ZoneID.magma.unlock!
        let shardCost = magma.costs[0].amount, copperCost = magma.costs[1].amount
        grind(g, to: magma.clearArea)
        check(g.unlockAreaMet(.magma), "Zone 2 area \(magma.clearArea) meets the Magma area requirement")
        let costs = g.unlockCosts(.magma)
        check(costs.count == 2 && costs[0].zone == .caverns && costs[0].amount == shardCost && costs[1].zone == .quarry && costs[1].amount == copperCost, "Magma costs Shards + Copper")
        earn(g, shardCost)
        let copper = g.run(for: .quarry)!.coins
        check(g.canUnlock(.magma) == (copper >= copperCost), "both currencies are required (Copper held \(copper))")
        if copper < copperCost {
            g.switchZone(to: .quarry); earn(g, copperCost); g.switchZone(to: .caverns)
        }
        let shards = g.run.coins, copper2 = g.run(for: .quarry)!.coins
        check(g.canUnlock(.magma), "can unlock with both")
        g.unlockZone(.magma)
        check(g.zone == .magma && g.run(for: .caverns)!.coins == shards - shardCost && g.run(for: .quarry)!.coins == copper2 - copperCost, "unlock pays from both wallets")
        let basalt = g.run.blocks.first { $0.material == .basalt }!
        check(basalt.maxHP == 25 && basalt.reward == 4, "basalt: 5 × 5 HP, pays 4 Embers")
        check(g.run.blocks.contains { $0.material == .vent }, "area 1 has a vent")
        // Regrowth: damage an obsidian into its second crack stage, wait, check it heals only to the stage top
        let ob = g.run.blocks.first { $0.material == .obsidian && !$0.isBroken }!.id
        let maxHP = g.run.blocks[ob].maxHP
        while g.run.blocks[ob].hpFraction > 0.6 { g.punch(ob) }
        let frac = g.run.blocks[ob].hpFraction
        let cap = (frac * 4).rounded(.up) / 4
        live(g, 6)
        let after = g.run.blocks[ob]
        check(after.isBroken || (after.hpFraction > frac && after.hpFraction <= cap + 1e-9), "obsidian regrew from \(frac) to \(after.hpFraction), cap \(cap) of \(maxHP) HP")
        // Vent: after 25 s, neighbours sit at or below 75%
        let vent = g.run.blocks.first { $0.material == .vent && !$0.isBroken }?.id
        if let vent {
            let c = vent % 5, r = vent / 5
            var ns: [Int] = []
            for dr in -1...1 { for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nr = r + dr, nc = c + dc
                if nr >= 0, nr < 6, nc >= 0, nc < 5 { ns.append(nr * 5 + nc) }
            } }
            let area = g.run.area
            live(g, 26.5)
            let hit = ns.filter { !g.run.blocks[$0].isTreasure && !g.run.blocks[$0].isBroken }
            check(g.run.area != area || (!hit.isEmpty && hit.allSatisfy { g.run.blocks[$0].hpFraction <= 0.75 + 1e-9 }), "vent eruption left neighbours at ≤75% after regrowth (\(hit.map { g.run.blocks[$0].hpFraction }))")
        } else { check(false, "vent present") }
        // Frost Knuckles stop regrowth
        grind(g, to: 8)
        if g.run.toolIndex < 0 { earn(g, g.toolCost(g.zone.tools[0])); g.buyTool(g.zone.tools[0]) }
        earn(g, g.toolCost(g.zone.tools[1])); g.buyTool(g.zone.tools[1])
        check(g.tool.freezeSeconds == 10, "Frost Knuckles equipped")
        let t = g.run.blocks.first { !$0.isBroken && !$0.isTreasure && $0.material != .vent && $0.maxHP > 200 }!.id
        g.punch(t)
        let hp0 = g.run.blocks[t].hp
        live(g, 5)
        check(g.run.blocks[t].isBroken || g.run.blocks[t].hp <= hp0 + 1e-9, "frozen block did not regrow (\(hp0) → \(g.run.blocks[t].hp))")
        // Save roundtrip with 3 zones
        g.save()
        let g2 = model()
        check(g2.unlockedZones == [.quarry, .caverns, .magma] && g2.zone == .magma, "3-zone save roundtrip")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
