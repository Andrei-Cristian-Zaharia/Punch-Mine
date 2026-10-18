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
        let all = ItemDef.all
        check(all.count == 42 && Set(all.map(\.id)).count == 42, "42 unique items (\(all.count))")
        check(ItemSlot.allCases.allSatisfy { s in all.filter { $0.slot == s }.count >= 6 }, "every slot has at least 6 items")
        check(Rarity.allCases.allSatisfy { r in all.contains { $0.rarity == r } } && Set(all.map(\.effect)).count >= 20, "all 4 rarities, 20+ distinct effects (\(Set(all.map(\.effect)).count))")
        check(ChestTier.allCases.allSatisfy { abs($0.odds.reduce(0, +) - 1) < 1e-9 }, "chest odds add up to 100%")
        check(all.allSatisfy { $0.upgradeCost(level: 2) > $0.upgradeCost(level: 1) }, "upgrade costs rise per level")

        // Starter chest at area 5, Iron at record area 10, Wooden from treasure
        saveAt(area: 5, weak: true); var g = model(); clearWeak(g)
        check(g.chestCount(.wooden) == 1, "first clear of area 5 gives a starter Wooden Chest")
        saveAt(area: 10, weak: true); g = model(); clearWeak(g)
        check(g.chestCount(.iron) == 1, "record area 10 gives an Iron Chest")
        var dropped = 0
        for _ in 0..<60 {
            saveAt(area: 13, weak: true, treasure: true); g = model()
            g.punch(g.run.blocks.firstIndex { $0.isTreasure }!)
            dropped += g.chestCount
        }
        check(dropped >= 8 && dropped <= 36, "about a third of treasure breaks drop a chest (\(dropped) of 60)")

        // Opening: new item auto-equips, duplicates give scrap
        saveAt(area: 3, chests: ["golden": 40])
        g = model()
        g.openChest(.golden)
        let first = g.chestReveal!
        check(first.isNew && g.itemLevel(first.item) == 1 && g.equipped[ItemDef.find(first.item)!.slot.rawValue] == first.item, "first item is new and fills its empty slot")
        for _ in 0..<39 { g.openChest(.golden) }
        check(g.chestCount(.golden) == 0 && !g.items.isEmpty && g.scrap > 40 * 50, "40 Golden Chests open; duplicates add Scrap (\(g.items.count) items, \(g.scrap) Scrap)")
        check(!g.items.keys.contains { ItemDef.find($0)!.rarity == .common }, "Golden Chests never give Commons")
        // Upgrading
        let id = first.item, lvl = g.itemLevel(id), cost = ItemDef.find(id)!.upgradeCost(level: lvl), sc = g.scrap
        g.upgradeItem(id)
        check(g.itemLevel(id) == lvl + 1 && g.scrap == sc - cost, "upgrade costs Scrap and adds a level")

        // Effects
        saveAt(area: 3, items: ["toolBelt": 1], equipped: [:])
        g = model(); let base = g.punchDamage
        g.equip("toolBelt")
        check(abs(g.punchDamage / base - 1.08) < 1e-9, "Tool Belt Lv1: +8% punch damage")
        saveAt(area: 3, items: ["toolBelt": 5], equipped: ["belt": "toolBelt"])
        check(abs(model().punchDamage / base - 1.20) < 1e-9, "Tool Belt Lv5: +20% (8% + 4 × 3%)")
        saveAt(area: 3, weak: true, items: ["coinPouch": 1], equipped: ["belt": "coinPouch"])
        g = model(); let c0 = g.run.coins, r0 = g.run.blocks[0].reward
        g.punch(0)
        check(abs((g.run.coins - c0) - r0 * 1.08) < 0.01, "Coin Pouch: +8% block coins")
        saveAt(area: 40, items: ["quakeBoots": 1], equipped: ["boots": "quakeBoots"])
        g = model(); let hp = g.run.blocks.map(\.hp)
        for _ in 0..<20 { g.punch(0) }
        let shaken = zip(hp, g.run.blocks.map(\.hp)).enumerated().filter { $0.offset != 0 && $0.element.1 < $0.element.0 }.count
        check(shaken >= 25, "Quake Boots: the 20th punch hits every block (\(shaken) others)")
        saveAt(area: 8, levels: ["focus": 2], items: ["windwalkers": 1], equipped: ["boots": "windwalkers"])
        check(model().focusMaxStacks == 8, "Windwalkers: Focus 2 (4 stacks) + 4")
        saveAt(area: 20, items: ["bandolier": 1, "hourglass": 1, "crownOfEmbers": 1],
               equipped: ["belt": "bandolier", "charm": "hourglass", "helmet": "crownOfEmbers"])
        g = model()
        check(abs(g.gadgetCooldown(.dynamite) - 45 * 0.85) < 1e-9 && abs(g.offlineEfficiency - 0.30) < 1e-9 && abs(g.feverMultiplier - 2.3) < 1e-9,
              "Bandolier −15% cooldown, Hourglass 30% offline, Crown of Embers Fever ×2.3")

        // New upgrades
        saveAt(area: 40, levels: ["rhythm": 9])
        g = model()
        for _ in 0..<12 { g.punch(0) }
        check(g.floaters.filter { $0.kind == .crit }.count >= 4, "Rhythm 9: every 3rd punch is a crit")
        saveAt(area: 3, weak: true, levels: ["deepPockets": 4])
        g = model(); let d0 = g.run.coins, dr = g.run.blocks[0].reward
        g.punch(0)
        check(abs((g.run.coins - d0) - dr * 1.2) < 0.01, "Deep Pockets 4: +20% block coins")
        saveAt(area: 8, levels: ["overcharge": 5, "treasureHunter": 3])
        g = model()
        check(abs(g.feverMultiplier - 2.5) < 1e-9 && abs(g.treasureChance - 0.18) < 1e-9, "Overcharge 5: ×2.5 Fever; Treasure Hunter 3: 18%")
        saveAt(area: 13, weak: true, treasure: true, levels: ["lockpick": 10])
        var total = 0
        for _ in 0..<150 {
            saveAt(area: 13, weak: true, treasure: true, levels: ["lockpick": 10])
            g = model(); g.punch(g.run.blocks.firstIndex { $0.isTreasure }!)
            total += g.chestCount
        }
        // 35% drop, half of those doubled ≈ 0.525 chests per treasure: 79 expected, ±4 standard deviations.
        check(total >= 41 && total <= 117, "Lockpick 10: half of treasure chests come in pairs (\(total) chests from 150)")

        // Items survive prestige and saving
        saveAt(area: 20, items: ["toolBelt": 3], equipped: ["belt": "toolBelt"], scrap: 77)
        g = model(); g.prestige()
        check(g.itemLevel("toolBelt") == 3 && g.equipped["belt"] == "toolBelt" && g.scrap == 77, "items, slots and Scrap survive prestige")
        g.save(); let g2 = model()
        check(g2.itemLevel("toolBelt") == 3 && g2.scrap == 77, "items persist across launches")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
