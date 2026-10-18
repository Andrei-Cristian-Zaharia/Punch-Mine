import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics8")) }
func mats(_ a: Int) -> Set<Ore> { Set(AreaGenerator.blocks(zone: .quarry, area: a, seed: 3, treasureChance: 0).map(\.material)) }
/// Writes a save that is already at `area`, with the Heart (if any) set to `heartHP`.
func saveAt(area: Int, heartHP: Double, hearts: Int, deepest: Int, weakBlocks: Bool = false) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var blocks = AreaGenerator.blocks(zone: .quarry, area: area, seed: 7, treasureChance: 0)
    if weakBlocks {
        blocks = blocks.map { $0.isBroken || $0.material == .heart ? $0 : Block(id: $0.id, material: $0.material, maxHP: $0.maxHP, hp: 1, armor: 0, reward: $0.reward) }
    }
    if let i = blocks.firstIndex(where: { $0.material == .heart }) {
        let b = blocks[i]; blocks[i] = Block(id: b.id, material: .heart, maxHP: b.maxHP, hp: heartHP, armor: 0, reward: b.reward)
    }
    let blockJSON = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(blocks))
    var runs = dict["runs"] as! [String: Any]; var q = runs["quarry"] as! [String: Any]
    q["area"] = area; q["maxCleared"] = area - 1; q["blocks"] = blockJSON
    runs["quarry"] = q; dict["runs"] = runs; dict["seeds"] = ["quarry": 7]
    dict["heartsDefeated"] = hearts; dict["deepestHeart"] = deepest
    var recs = dict["records"] as! [String: Any]; var r = recs["quarry"] as! [String: Any]
    r["bestArea"] = area; r["bestCleared"] = area - 1; recs["quarry"] = r; dict["records"] = recs
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
@main struct Main {
    static func main() {
        check(ZoneID.quarry.maxArea == 100 && ZoneID.caverns.maxArea == 30, "Pebble Quarry goes to 100; others stay at 30")
        check(mats(8).contains(.copperOre) && mats(13).contains(.coal), "Copper Ore from area 6, Coal from area 11")
        check(mats(28).contains(.silver) && mats(45).contains(.diamond) && mats(65).contains(.mithril) && mats(95).contains(.adamantite), "Silver, Diamond, Mithril, Adamantite appear at depth")
        for a in [1, 7, 12, 18, 23, 27, 35, 45, 55, 65, 75, 85, 95] {
            if AreaGenerator.blocks(zone: .quarry, area: a, seed: 1, treasureChance: 0).count != 30 { check(false, "area \(a) has 30 blocks") }
        }
        check(abs(Config.hp(.granite, area: 31, zone: .quarry) / Config.hp(.granite, area: 30, zone: .quarry) - 1.04) < 0.001, "past area 30 HP grows 4% per area")
        let heartArea = AreaGenerator.blocks(zone: .quarry, area: 100, seed: 5, treasureChance: 1)
        check(heartArea[12].material == .heart && heartArea.filter { $0.material == .heartPart }.count == 8 && !heartArea.contains { $0.isTreasure }, "area 100: Heart covers the centre 3×3, no treasure")
        check(Conquest.isHeartArea(125) && !Conquest.isHeartArea(110) && Conquest.heartRank(150) == 2, "endless Hearts every 25 areas")

        // Coal adds Fever charge
        saveAt(area: 13, heartHP: 0, hearts: 0, deepest: 0)
        let c = model()
        if let coal = c.run.blocks.firstIndex(where: { $0.material == .coal }) {
            let before = c.feverCharge
            while !c.run.blocks[coal].isBroken { c.punch(coal) }
            check(c.feverCharge >= before + 5 || c.feverActive, "breaking Coal adds 5 Fever charge (\(before) → \(c.feverCharge))")
        } else { check(false, "coal present at area 13") }

        // The Heart
        saveAt(area: 100, heartHP: 1, hearts: 0, deepest: 0, weakBlocks: true)
        let g = model()
        check(g.heartBlock != nil && g.run.area == 100 && !g.isEndless, "loaded at area 100 with the Heart")
        let pc = g.perkCoins
        g.punch(7)   // a cell of the Heart, not its centre
        check(g.heartBlock?.isBroken == true || g.heartBlock == nil, "punching any Heart cell hits the Heart")
        check(g.heartsDefeated == 1 && g.deepestHeart == 100 && g.perkCoins == pc + 100 && g.conquest?.isCrown == true, "first Heart: Crown + 100 Perk Coins")
        check(abs(g.crownMultiplier - 1.25) < 1e-9 && g.isEndless && g.maxArea(for: .quarry) == Int.max, "Crown: ×1.25 coins, Endless Depths open")
        let i = g.run.blocks.firstIndex { !$0.isBroken }!
        let reward = g.run.blocks[i].reward, coins = g.run.coins
        while !g.run.blocks[i].isBroken { g.punch(i) }
        check(abs((g.run.coins - coins) - reward * 1.25) < 0.01, "block rewards ×1.25 with the Crown")
        var n = 0
        while g.run.area == 100 && n < 200000 { for j in 0..<30 { g.punch(j) }; n += 1 }
        check(g.run.area == 101, "clearing area 100 continues to area 101")
        check(g.minerCoinsPerSecond(for: .quarry) >= 0, "background income still computes past 100")
        // Same depth again pays nothing (no farming via prestige)
        saveAt(area: 100, heartHP: 1, hearts: 1, deepest: 100)
        let h = model(); let pc2 = h.perkCoins
        h.punch(12)
        check(h.heartsDefeated == 1 && h.perkCoins == pc2 && h.conquest == nil, "a Heart at an old depth gives no new reward")
        // Area 125 gives a Crown Star
        saveAt(area: 125, heartHP: 1, hearts: 1, deepest: 100)
        let k = model(); let pc3 = k.perkCoins
        k.punch(12)
        check(k.heartsDefeated == 2 && k.perkCoins == pc3 + 50 && k.conquest?.isCrown == false && abs(k.crownMultiplier - 1.30) < 1e-9, "area 125 Heart: Crown Star, +50 PC, ×1.30")
        // Saves keep hearts
        k.save(); let k2 = model()
        check(k2.heartsDefeated == 2 && k2.deepestHeart == 125, "Crown progress persists")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
