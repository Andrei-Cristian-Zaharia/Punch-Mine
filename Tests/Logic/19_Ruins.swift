import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics19")) }
/// A save in Sunken Ruins at `area` with the given blocks (generated if nil), every zone unlocked.
func ruinsSave(area: Int, blocks: [Block]? = nil, strength: Int = 0, heartHP: Double? = nil) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var b = blocks ?? AreaGenerator.blocks(zone: .ruins, area: area, seed: 3, treasureChance: 0)
    if let heartHP {
        let h = b[Conquest.heartIndex]
        b[Conquest.heartIndex] = Block(id: h.id, material: h.material, maxHP: h.maxHP, hp: heartHP, armor: 0, reward: h.reward)
    }
    var runs = dict["runs"] as! [String: Any]
    var run = runs["quarry"] as! [String: Any]
    run["area"] = area; run["maxCleared"] = area - 1; run["levels"] = ["strength": strength]
    run["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(b))
    runs["ruins"] = run; dict["runs"] = runs
    dict["seeds"] = ["quarry": 3, "ruins": 3]
    var recs = dict["records"] as! [String: Any]
    var rec = recs["quarry"] as! [String: Any]
    rec["bestArea"] = area; rec["bestCleared"] = area - 1; rec["seenIntro"] = true
    recs["ruins"] = rec; dict["records"] = recs
    dict["unlockedZones"] = ["quarry", "caverns", "magma", "ruins"]
    dict["activeZone"] = "ruins"
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
/// 30 plain blocks with the given HP, plus overrides.
func grid(hp: Double = 1_000, reward: Double = 100, _ overrides: [Int: Ore] = [:]) -> [Block] {
    (0..<30).map { i in Block(id: i, material: overrides[i] ?? .ruinStone, maxHP: hp, hp: hp, armor: 0, reward: reward) }
}
func run(_ g: GameModel, _ seconds: Double) { for _ in 0..<Int(seconds * 20) { g.advance(by: 0.05) } }

@main struct Main {
    static func main() {
        // Zone data
        let z = ZoneID.ruins
        check(ZoneID.allCases.count >= 4 && z.number == 4 && z.tools.count == 9 && z.prestigeMultiplier == 4, "Zone 4: 9 tools, ×4 Perk Coins")
        check(z.unlock?.previous == .magma && z.unlock?.clearArea == 25
              && z.unlock?.costs.map(\.amount) == [600_000, 2_000_000], "unlock: Magma area 25, 600K Embers + 2M Shards")
        check((1...100).allSatisfy { a in z.mix(area: a).map(\.1).reduce(0, +) == 30 }, "every area mix fills 30 cells")
        check((1...100).allSatisfy { a in z.mix(area: a).contains { $0.0 == .runestone } }, "every area has runestones")
        check(z.tools.map(\.cost) == z.tools.map(\.cost).sorted() && zip(z.tools, z.tools.dropFirst()).allSatisfy { $0.damage < $1.damage },
              "tools get pricier and stronger in order")
        check(Config.hp(.ruinStone, area: 10, zone: .ruins) > Config.hp(.magmaCore, area: 10, zone: .magma), "Ruins blocks are tougher than Magma's")
        check(Ore.pearlClam.isTreasure && z.treasureOre == .pearlClam, "the Giant Clam is the treasure")
        check(ItemDef.relic(for: .ruins)?.slot == .helmet, "the Ruins relic is a helmet")

        // Tide cycle
        ruinsSave(area: 5, blocks: grid())
        var g = model()
        check(!g.highTide && g.tideCharge == 0, "tide starts out")
        run(g, Tide.interval - 1)
        check(!g.highTide && g.tideCharge > 0.9, "the tide meter fills over \(Int(Tide.interval)) s")
        run(g, 1.5)
        check(g.highTide && abs(g.tideRemaining - (Tide.duration - 0.5)) < 0.11, "then high tide for \(Int(Tide.duration)) s")
        run(g, Tide.duration)
        check(!g.highTide, "and out again")

        // High tide: punches 25% weaker, blocks pay ×2.5
        ruinsSave(area: 5, blocks: grid(), strength: 20)
        g = model()
        g.punch(0)
        let dryHit = 1_000 - g.run.blocks[0].hp
        run(g, Tide.interval + 0.5)
        check(g.highTide, "tide in")
        g.punch(1)
        let wetHit = 1_000 - g.run.blocks[1].hp
        check(abs(wetHit / dryHit - Tide.damageFactor) < 0.02 || dryHit == 0, "high tide: hits ×\(Tide.damageFactor) (\(wetHit) vs \(dryHit))")
        ruinsSave(area: 5, blocks: grid(hp: 1, reward: 100), strength: 5)
        g = model()
        var c0 = g.run.coins
        g.punch(0)
        let dryPay = g.run.coins - c0
        run(g, Tide.interval + 0.5)
        c0 = g.run.coins
        g.punch(1)
        check(abs((g.run.coins - c0) / dryPay - Tide.rewardFactor) < 1e-6, "high tide: blocks pay ×\(Tide.rewardFactor) (\(g.run.coins - c0) vs \(dryPay))")

        // Runestones hit their row
        ruinsSave(area: 5, blocks: grid(hp: 1_000, [7: .runestone]))
        g = model()
        var b = g.run.blocks
        b[7] = Block(id: 7, material: .runestone, maxHP: 1, hp: 1, armor: 0, reward: 10)
        ruinsSave(area: 5, blocks: b)
        g = model()
        g.punch(7)
        let rowHit = [5, 6, 8, 9].allSatisfy { abs(g.run.blocks[$0].hp - 1_000 * (1 - Rune.share)) < 1e-6 }
        let othersUntouched = (0..<30).filter { $0 / 5 != 1 }.allSatisfy { g.run.blocks[$0].hp == 1_000 }
        check(g.run.blocks[7].isBroken && rowHit, "a broken runestone hits its row for \(Int(Rune.share * 100))% of their max HP")
        check(othersUntouched, "other rows are untouched")
        b = grid(hp: 1_000)
        b[5] = Block(id: 5, material: .runestone, maxHP: 1, hp: 1, armor: 0, reward: 10)
        b[6] = Block(id: 6, material: .runestone, maxHP: 200, hp: 200, armor: 0, reward: 10)
        ruinsSave(area: 5, blocks: b)
        g = model()
        g.punch(5)
        check(g.run.blocks[6].hp == 200 * (1 - Rune.share) && abs(g.run.blocks[9].hp - 750) < 1e-6, "runestones don't need to touch: the pulse crosses the row")
        b = grid(hp: 4)
        b[0] = Block(id: 0, material: .runestone, maxHP: 1, hp: 1, armor: 0, reward: 10)
        b[1] = Block(id: 1, material: .runestone, maxHP: 10, hp: 2, armor: 0, reward: 10)
        b[10] = Block(id: 10, material: .ruinStone, maxHP: 1_000, hp: 1_000, armor: 0, reward: 10)
        ruinsSave(area: 5, blocks: b)
        g = model()
        g.punch(0)
        check(g.run.blocks[1].isBroken, "a pulse can break another runestone, which pulses too")

        // Heart of the Ruins: double damage at high tide
        ruinsSave(area: 100, strength: 60)
        g = model()
        let hp0 = g.heartBlock!.hp
        g.punch(Conquest.heartIndex)
        let dryHeart = hp0 - g.heartBlock!.hp
        run(g, Tide.interval + 0.5)
        let hp1 = g.heartBlock!.hp
        g.punch(Conquest.heartIndex)
        let wetHeart = hp1 - g.heartBlock!.hp
        check(dryHeart > 0 && abs(wetHeart / dryHeart - Tide.heartFactor) < 0.35, "the Heart takes about ×\(Tide.heartFactor) at high tide (\(wetHeart) vs \(dryHeart))")
        ruinsSave(area: 100, strength: 60, heartHP: 1)
        g = model()
        g.punch(Conquest.heartIndex)
        check(g.record(for: .ruins).heartsDefeated == 1 && g.itemLevel("tidecallerHelm") == 1 && g.conquest?.perkCoins == 400,
              "Ruins Crown: 400 PC and the Tidecaller's Helm")

        // Offline: average tide over a cycle
        check(Tide.averageRewardFactor > 1 && Tide.averageDamageFactor < 1, "offline earnings average the tide")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
