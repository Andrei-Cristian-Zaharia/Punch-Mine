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
func live(_ g: GameModel, _ s: Double) { g.start(); RunLoop.main.run(until: Date().addingTimeInterval(s)); g.stop() }
@main struct Main {
    static func main() {
        // Miners now scale with your punch
        saveAt(area: 22, levels: ["strength": 40, "hireMiner": 3, "training": 10], tool: 3)
        var g = model()
        let punch = g.punchDamage
        check(abs(g.minerHit - punch * 0.60) < 1e-6 && g.minerHit > Config.minerHit(trainingLevel: 10), "Training 10: a miner hits 60% of your punch (\(Int(g.minerHit)) vs punch \(Int(punch)), old flat 35)")
        let iron = g.run.blocks.firstIndex { $0.material == .iron }!
        let hp0 = g.run.blocks[iron].maxHP
        let perSecond = Double(g.minerCount(.digger)) * Config.hitDamage(raw: g.minerHit, armor: g.run.blocks[iron].armor * 0.5, penetration: 0)
        check(hp0 / perSecond < 30, "3 diggers break an area-22 Iron Ore in about \(Int(hp0 / perSecond)) s (was ~\(Int(hp0 / (3 * (35 - g.run.blocks[iron].armor * 0.5)))) s)")
        saveAt(area: 3, levels: ["hireMiner": 1])
        check(model().minerHit == Config.minerHit(trainingLevel: 0), "early game keeps the flat minimum (5 per hit)")

        // Perk tree shape
        check(Perk.allCases.count == 25, "25 perks")
        let order = Perk.allCases
        check(order.allSatisfy { p in p.requirement.map { order.firstIndex(of: $0.perk)! < order.firstIndex(of: p)! && $0.perk.branch == p.branch } ?? true },
              "every perk comes after its prerequisite, in the same branch")
        saveAt(area: 3, perks: ["heavyFists": 5, "piercer": 5, "keenEye": 5, "brutalCrits": 2])
        g = model()
        check(g.perkState(.titanPunch) == .locked, "Titan Punch needs Brutal Crits 3 as well as Piercer 5")
        saveAt(area: 3, perks: ["heavyFists": 5, "piercer": 5, "keenEye": 5, "brutalCrits": 3])
        check(model().perkState(.titanPunch) != .locked, "both requirements met: Titan Punch unlocks")

        // Effects
        saveAt(area: 3, perks: ["brutalCrits": 3, "overtime": 2, "gadgeteer": 4, "toolsmith": 5, "doubleShift": 2, "expressElevator": 3])
        g = model()
        check(abs(g.critMultiplier - 2.6) < 1e-9, "Brutal Crits 3: crit ×2.6")
        check(abs(g.offlineEfficiency - 0.35) < 1e-9, "Overtime 2: 35% offline rate")
        check(abs(g.gadgetCooldown(.dynamite) - 45 * 0.8) < 1e-9, "Gadgeteer 4: −20% gadget cooldown")
        check(g.toolCost(g.zone.tools[1]) == 3_600, "Toolsmith 5: Pickaxe Gauntlet 6,000 → 3,600")
        check(abs(g.minerInterval(.digger, run: g.run) - 0.8) < 1e-9, "Double Shift 2: diggers swing every 0.8 s")
        check(g.freshRun(for: .quarry).area == 7, "Express Elevator 3: new runs start at area 7")
        // Titan Punch
        saveAt(area: 40, levels: ["strength": 30], perks: ["titanPunch": 1])
        g = model()
        for _ in 0..<19 { g.punch(0) }
        let before = g.run.blocks[0].hp
        g.punch(0)
        let titanHit = before - g.run.blocks[0].hp
        check(g.floaters.contains { $0.text.hasPrefix("TITAN") } && titanHit >= g.punchDamage * 10 - 1, "20th punch is a Titan Punch: ×10, armor ignored (\(Int(titanHit)))")
        // Lucky Haul on treasure
        saveAt(area: 13, weak: true, treasure: true, perks: ["luckyHaul": 5])
        g = model(); let t = g.run.blocks.firstIndex { $0.isTreasure }!; let rw = g.run.blocks[t].reward, c0 = g.run.coins
        g.punch(t)
        check(abs((g.run.coins - c0) - rw * 2) < 0.01, "Lucky Haul 5: treasure pays double")
        // Scrapper
        saveAt(area: 3, chests: ["golden": 1], perks: ["scrapper": 5])
        g = model(); g.openChest(.golden)
        check(g.scrap >= 75, "Scrapper 5: +50% Scrap from chests (\(g.scrap))")
        // Shared Drills
        saveAt(area: 40, levels: ["strength": 30, "hireMiner": 1], perks: ["sharedDrills": 1], tool: 5)
        g = model()
        check(g.level(.sharedDrills) == 1, "Shared Drills owned")
        // Perk costs
        let total = Perk.allCases.map(\.totalCost).reduce(0, +)
        check(total > 10_000 && total < 20_000, "maxing the tree costs about \(total) PC")
        check(Perk.allCases.allSatisfy { p in (1..<p.maxLevel).allSatisfy { p.cost(level: $0) >= p.cost(level: $0 - 1) } }, "perk costs never fall between levels")
        // Treasure Crew: miners mine treasure
        saveAt(area: 13, treasure: true, levels: ["strength": 20, "hireMiner": 3, "training": 10], perks: ["treasureCrew": 3])
        g = model()
        let tIndex = g.run.blocks.firstIndex { $0.isTreasure }!
        // Leave only the treasure so the diggers have to go for it
        for i in 0..<30 where i != tIndex { while !g.run.blocks[i].isBroken && g.run.area == 13 { g.punch(i) } }
        let tHP = g.run.blocks[tIndex].hp
        live(g, 3)
        check(g.run.area != 13 || g.run.blocks[tIndex].hp < tHP, "with Treasure Crew, miners damage the treasure")
        saveAt(area: 13, treasure: true, levels: ["strength": 20, "hireMiner": 3, "training": 10])
        g = model()
        let t2 = g.run.blocks.firstIndex { $0.isTreasure }!
        for i in 0..<30 where i != t2 { while !g.run.blocks[i].isBroken && g.run.area == 13 { g.punch(i) } }
        let t2HP = g.run.blocks[t2].hp
        live(g, 3)
        check(g.run.blocks[t2].hp == t2HP, "without it, miners leave treasure alone")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
