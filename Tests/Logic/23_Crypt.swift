import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics23")) }
/// A save in Haunted Crypt at `area` with the given blocks (generated if nil), every zone unlocked.
func cryptSave(area: Int, blocks: [Block]? = nil, strength: Int = 0, toolIndex: Int = -1, heartHP: Double? = nil) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var b = blocks ?? AreaGenerator.blocks(zone: .crypt, area: area, seed: 3, treasureChance: 0)
    if let heartHP {
        let h = b[Conquest.heartIndex]
        b[Conquest.heartIndex] = Block(id: h.id, material: h.material, maxHP: h.maxHP, hp: heartHP, armor: 0, reward: h.reward)
    }
    var runs = dict["runs"] as! [String: Any]
    var run = runs["quarry"] as! [String: Any]
    run["area"] = area; run["maxCleared"] = area - 1; run["levels"] = ["strength": strength]; run["toolIndex"] = toolIndex
    run["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(b))
    runs["crypt"] = run; dict["runs"] = runs
    dict["seeds"] = ["quarry": 3, "crypt": 3]
    var recs = dict["records"] as! [String: Any]
    var rec = recs["quarry"] as! [String: Any]
    rec["bestArea"] = area; rec["bestCleared"] = area - 1; rec["seenIntro"] = true
    recs["crypt"] = rec; dict["records"] = recs
    dict["unlockedZones"] = ["quarry", "caverns", "magma", "ruins", "crypt"]
    dict["activeZone"] = "crypt"
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
/// 30 plain blocks with the given HP, plus overrides.
func grid(hp: Double = 1_000, reward: Double = 100, _ overrides: [Int: Ore] = [:]) -> [Block] {
    (0..<30).map { i in Block(id: i, material: overrides[i] ?? .tombstone, maxHP: hp, hp: hp, armor: 0, reward: reward) }
}
func run(_ g: GameModel, _ seconds: Double) { for _ in 0..<Int(seconds * 20) { g.advance(by: 0.05) } }

@main struct Main {
    static func main() {
        // Zone data
        let z = ZoneID.crypt
        check(ZoneID.allCases.count == 5 && z.number == 5 && z.tools.count == 9 && z.prestigeMultiplier == 6, "Zone 5: 9 tools, ×6 Perk Coins")
        check(z.unlock?.previous == .ruins && z.unlock?.clearArea == 40
              && z.unlock?.costs.map(\.amount) == [40_000_000, 80_000_000], "unlock: Ruins area 40, 40M Pearls + 80M Embers")
        check((1...100).allSatisfy { a in z.mix(area: a).map(\.1).reduce(0, +) == 30 }, "every area mix fills 30 cells")
        check((1...100).allSatisfy { a in z.mix(area: a).contains { $0.0.isGhost } }, "every area has ghosts")
        check((6...100).allSatisfy { a in z.mix(area: a).contains { $0.0 == .cursedUrn } }, "cursed urns from area 6")
        check(z.tools.map(\.cost) == z.tools.map(\.cost).sorted() && zip(z.tools, z.tools.dropFirst()).allSatisfy { $0.damage < $1.damage },
              "tools get pricier and stronger in order")
        check(zip(z.tools, z.tools.dropFirst()).allSatisfy { $0.spectral <= $1.spectral } && z.tools.last?.spectral == 1,
              "spectral reach only grows, up to 100%")
        check(Config.hp(.tombstone, area: 10, zone: .crypt) > Config.hp(.ruinStone, area: 10, zone: .ruins), "Crypt blocks are tougher than the Ruins'")
        check(Ore.reliquary.isTreasure && z.treasureOre == .reliquary, "the Reliquary is the treasure")
        check(Ore.cursedUrn.baseReward == Ore.tombstone.baseReward * Curse.rewardFactor, "cursed urns pay ×\(Int(Curse.rewardFactor))")
        check(ItemDef.relic(for: .crypt)?.slot == .charm, "the Crypt relic is a charm")

        // Haunt cycle
        cryptSave(area: 5, blocks: grid())
        var g = model()
        check(!g.ghostsFaded && g.hauntRemaining == Haunt.solidSeconds, "ghosts start solid")
        run(g, Haunt.solidSeconds + 0.5)
        check(g.ghostsFaded && abs(g.hauntRemaining - (Haunt.fadedSeconds - 0.5)) < 0.11, "then fade for \(Int(Haunt.fadedSeconds)) s")
        run(g, Haunt.fadedSeconds)
        check(!g.ghostsFaded, "and return")

        // Faded ghosts can't be hit; solid ones can, and other blocks always can
        cryptSave(area: 5, blocks: grid([0: .wraithstone, 1: .wraithstone]), strength: 20)
        g = model()
        g.punch(0)
        let solidHit = 1_000 - g.run.blocks[0].hp
        run(g, Haunt.solidSeconds + 0.5)
        check(g.ghostsFaded, "ghosts faded")
        g.punch(1); g.punch(2)
        check(solidHit > 0 && g.run.blocks[1].hp == 1_000, "a faded ghost takes nothing (solid: \(solidHit))")
        check(g.run.blocks[2].hp < 1_000, "other blocks can still be hit while ghosts are faded")
        check(!g.isGhostly(2) && g.isGhostly(1), "only ghosts fade")

        // Spectral tools reach faded ghosts for a share of the hit (ghosts far apart, so splash can't touch the second)
        cryptSave(area: 20, blocks: grid([0: .wraithstone, 22: .wraithstone]), strength: 20, toolIndex: 2)
        g = model()
        let spectral = ZoneID.crypt.tools[2].spectral
        // The smallest of a few hits, so a lucky crit can't skew the ratio.
        func smallestHit(_ cell: Int) -> Double {
            (0..<4).map { _ in let before = g.run.blocks[cell].hp; g.punch(cell); return before - g.run.blocks[cell].hp }.min()!
        }
        let fullHit = smallestHit(0)
        run(g, Haunt.solidSeconds + 0.5)
        let reachHit = smallestHit(22)
        check(fullHit > 0 && abs(reachHit / fullHit - spectral) < 0.02, "Lantern Fist hits faded ghosts for \(Int(spectral * 100))% (\(reachHit) vs \(fullHit))")

        // Cursed urns: punches weaker for a few seconds
        var b = grid(hp: 1_000_000)
        b[0] = Block(id: 0, material: .cursedUrn, maxHP: 1, hp: 1, armor: 0, reward: 30)
        cryptSave(area: 5, blocks: b, strength: 20)
        g = model()
        g.punch(5)
        let cleanHit = 1_000_000 - g.run.blocks[5].hp
        g.punch(0)
        check(g.run.blocks[0].isBroken && g.cursed && g.curseRemaining == Curse.seconds, "breaking a cursed urn curses you for \(Int(Curse.seconds)) s")
        g.punch(6)
        let cursedHit = 1_000_000 - g.run.blocks[6].hp
        check(abs(cursedHit / cleanHit - Curse.damageFactor) < 0.02, "cursed punches deal ×\(Curse.damageFactor) (\(cursedHit) vs \(cleanHit))")
        run(g, Curse.seconds + 0.1)
        check(!g.cursed, "the curse wears off")

        // Heart of the Crypt: fades with the ghosts, and crits right after it returns
        cryptSave(area: 100, strength: 60)
        g = model()
        run(g, Haunt.solidSeconds + 0.5)
        let hpFaded = g.heartBlock!.hp
        g.punch(Conquest.heartIndex)
        check(g.ghostsFaded && g.heartBlock!.hp == hpFaded, "the faded Heart takes nothing")
        run(g, Haunt.fadedSeconds)
        check(!g.ghostsFaded, "the Heart is back")
        let crits = g.stats.crits
        g.punch(Conquest.heartIndex); g.punch(Conquest.heartIndex)
        check(g.stats.crits - crits == 2, "punches in the first second after it returns always crit")
        cryptSave(area: 100, strength: 60, heartHP: 1)
        g = model()
        g.punch(Conquest.heartIndex)
        check(g.record(for: .crypt).heartsDefeated == 1 && g.itemLevel("lichLantern") == 1 && g.conquest?.perkCoins == 600,
              "Crypt Crown: 600 PC and the Lich's Lantern")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
