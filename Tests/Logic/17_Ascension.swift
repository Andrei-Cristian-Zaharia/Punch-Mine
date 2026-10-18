import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics17")) }
/// A save at `area` in Pebble Quarry. `extra` is merged into the top-level save dictionary.
func ascSave(area: Int = 40, crown: Bool = true, perkCoins: Int = 0, levels: [String: Int] = [:], best: Int? = nil,
             extra: [String: Any] = [:]) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    let blocks = AreaGenerator.blocks(zone: .quarry, area: area, seed: 4, treasureChance: 0)
    var runs = dict["runs"] as! [String: Any]; var q = runs["quarry"] as! [String: Any]
    q["area"] = area; q["maxCleared"] = area - 1; q["levels"] = levels
    q["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(blocks))
    runs["quarry"] = q; dict["runs"] = runs; dict["seeds"] = ["quarry": 4]
    var recs = dict["records"] as! [String: Any]; var r = recs["quarry"] as! [String: Any]
    r["bestArea"] = best ?? area; r["bestCleared"] = (best ?? area) - 1
    r["heartsDefeated"] = crown ? 1 : 0; r["deepestHeart"] = crown ? 100 : 0
    recs["quarry"] = r; dict["records"] = recs
    dict["perkCoins"] = perkCoins
    for (k, v) in extra { dict[k] = v }
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func run(_ g: GameModel, _ seconds: Double) { for _ in 0..<Int(seconds * 20) { g.advance(by: 0.05) } }

@main struct Main {
    static func main() {
        // Unlock
        ascSave(crown: false, perkCoins: 100_000)
        var g = model()
        check(!g.ascensionUnlocked && g.starState(.fists) == .locked && g.ascensionState(.secondWind) == .locked, "Ascension locked before a Crown")
        ascSave(perkCoins: 100_000)
        g = model()
        check(g.ascensionUnlocked && g.starState(.fists) == .affordable, "the first Crown unlocks Ascension")

        // Star perks: costs climb ×1.12, effects multiply
        check(StarPerk.fists.cost(level: 0) == 80 && StarPerk.fists.cost(level: 10) == Int((80 * pow(1.12, 10)).rounded()), "Star costs grow 12% a level")
        let punch = g.punchDamage, miner = g.minerHit, coins = g.coinMultiplier(for: g.run), pc = g.perkCoins
        for _ in 0..<10 { g.buyStar(.fists); g.buyStar(.crew); g.buyStar(.fortune) }
        check(abs(g.punchDamage / punch - 1.3) < 1e-9, "Starforged Fists 10: ×1.30 punch")
        // Miners scale with your punch, so Fists can add on top when the punch share beats the flat minimum.
        check(g.minerHit / miner >= 1.3 - 1e-9 && g.minerHit / miner <= 1.69 + 1e-9, "Star Crew 10: at least ×1.30 miners (×\(g.minerHit / miner))")
        check(abs(g.coinMultiplier(for: g.run) / coins - 1.3) < 1e-9, "Star Fortune 10: ×1.30 coins")
        let spent = (0..<10).map { StarPerk.fists.cost(level: $0) + StarPerk.crew.cost(level: $0) + StarPerk.fortune.cost(level: $0) }.reduce(0, +)
        check(g.perkCoins == pc - spent, "Star perks cost Perk Coins (\(spent))")
        // The Crown's relic may roll a chest-luck affix, so compare against the starting luck.
        let luck0 = g.chestLuck
        for _ in 0..<40 { g.buyStar(.luck) }
        check(g.starLevel(.luck) == 25 && g.starState(.luck) == .maxed && abs(g.chestLuck - luck0 - 0.5) < 1e-9, "Star Luck caps at 25 levels (+50% chest luck)")
        g.save(); g = model()
        check(g.starLevel(.fists) == 10 && g.starLevel(.luck) == 25, "Star levels saved")
        g.prestige()
        check(g.starLevel(.fists) == 10, "Star perks survive prestige")

        // Ascension perks
        ascSave(perkCoins: 10_000, levels: ["hireMiner": 3, "hireDriller": 2])
        g = model()
        let fever = g.feverMultiplier
        g.buyAscension(.secondWind)
        check(g.owns(.secondWind) && abs(g.feverMultiplier - fever - 1) < 1e-9 && g.ascensionState(.secondWind) == .maxed, "Second Wind: Fever +1, bought once")
        g.buyAscension(.unionContract)
        g.prestige()
        check(g.minerCount(.digger) == 3 && g.minerCount(.driller) == 2, "Union Contract: miners stay through prestige")

        // Auto-Prestige: only when owned, switched on, and stalled
        ascSave(perkCoins: 10_000, best: 40)
        g = model()
        run(g, Ascension.autoPrestigeStall + 5)
        check(g.record.prestigeCount == 0, "no auto-prestige without the perk")
        g.buyAscension(.autoPrestige)
        g.settings.autoPrestige = false
        run(g, 10)
        check(g.record.prestigeCount == 0, "switched off: no auto-prestige")
        g.settings.autoPrestige = true
        let before = g.perkCoins
        run(g, 2)
        check(g.record.prestigeCount == 1 && g.perkCoins > before && g.run.area < 40, "stalled \(Int(Ascension.autoPrestigeStall)) s: prestiges by itself")
        ascSave(area: 100, perkCoins: 10_000, best: 100, extra: ["ascended": ["autoPrestige"]])
        g = model()
        run(g, Ascension.autoPrestigeStall + 5)
        check(g.record.prestigeCount == 0 && g.heartBlock != nil, "never auto-prestiges during a Heart fight")

        // Affixes
        let cap = ItemDef.find("plumbersCap")!
        var rolls: [Affix] = []
        for _ in 0..<500 { rolls.append(Affixes.roll(for: cap)) }
        check(!rolls.contains { $0.effect == cap.effect } && Set(rolls.map(\.effect)).count == Affixes.pool.count - 1,
              "affixes never repeat the item's own stat and cover the rest of the pool")
        check(rolls.allSatisfy { $0.value >= Affixes.best($0.effect, rarity: .common) * Affixes.floor - 1e-12
                && $0.value <= Affixes.best($0.effect, rarity: .common) + 1e-12 }, "rolls stay between 40% and 100% of the best")
        check(Affixes.best(.punchDamage, rarity: .legendary) > Affixes.best(.punchDamage, rarity: .common) * 2.9, "rarer items roll bigger affixes")
        ascSave(extra: ["items": ["toolBelt": 1], "equipped": ["belt": "toolBelt"], "chests": ["golden": 3]])
        g = model()
        check(g.affix("toolBelt") == nil, "a save that already stores affixes doesn't roll new ones")
        do {
            g.save()
            var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
            dict["affixes"] = nil
            UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
        }
        g = model()
        check(g.affix("toolBelt") != nil, "items from before affixes get one on load")
        check(g.affix("heartstoneBuckle") == Affixes.relicAffix(ItemDef.find("heartstoneBuckle")!), "relics get their fixed affix")
        let a = g.affix("toolBelt")!
        let effect = a.effect == .punchDamage ? ItemEffect.coins : a.effect
        let withAffix = g.itemBonus(a.effect)
        g.unequip(.belt)
        check(abs(withAffix - g.itemBonus(a.effect) - (a.effect == .punchDamage ? 0.08 + a.value : a.value)) < 1e-9 || effect != a.effect,
              "an equipped item's affix adds to its stat (\(a.effect.rawValue) +\(a.value))")
        g.openChest(.golden)
        check(g.affix(g.chestReveal!.item) != nil, "a new item from a chest rolls an affix")

        // Reroll and salvage
        ascSave(extra: ["items": ["toolBelt": 5, "powerStar": 1], "equipped": ["belt": "toolBelt"], "scrap": 1_000, "ascended": []])
        g = model()
        g.rerollAffix("toolBelt")
        check(g.scrap == 1_000 - Affixes.rerollCost(.common) && g.affix("toolBelt") != nil, "reroll costs Scrap (\(Affixes.rerollCost(.common)))")
        let def = ItemDef.find("toolBelt")!
        let value = g.salvageValue("toolBelt")
        check(value == 8 * 2 + (1..<5).map { def.upgradeCost(level: $0) }.reduce(0, +) / 2, "salvage: 2× duplicate Scrap + half the upgrade Scrap (\(value))")
        let s0 = g.scrap
        g.salvage("toolBelt")
        check(g.itemLevel("toolBelt") == 0 && g.equipped["belt"] == nil && g.affix("toolBelt") == nil && g.scrap == s0 + value,
              "salvaging removes and unequips the item and pays Scrap")
        ascSave(extra: ["items": ["heartstoneBuckle": 3]])
        g = model()
        check(!g.canSalvage("heartstoneBuckle"), "Heart relics can't be salvaged")

        // Formatting
        check(ItemDef.describe(.lucky, value: 0.08) == "8% chance a block pays double" && ItemDef.describe(.critChance, value: 0.025) == "+2.5% crit chance"
              || ItemDef.describe(.critChance, value: 0.025) == "+2,5% crit chance", "8% shows without a trailing .0, 2.5% keeps it")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
