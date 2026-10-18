import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics10")) }
/// A save sitting in `zone` at `area`, every zone unlocked. `weak` sets every non-Heart block to 1 HP.
func zoneSave(_ zone: ZoneID, area: Int, weak: Bool = false, quarryHearts: Int = 0, legacyHearts: Int? = nil,
              strength: Int = 60, heartHP: Double? = nil) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var blocks = AreaGenerator.blocks(zone: zone, area: area, seed: 5, treasureChance: 0)
    if weak {
        blocks = blocks.map { $0.material == .heart || $0.material == .heartPart ? $0
            : Block(id: $0.id, material: $0.material, maxHP: $0.maxHP, hp: 1, armor: 0, reward: $0.reward) }
    }
    if let heartHP {
        let h = blocks[Conquest.heartIndex]
        blocks[Conquest.heartIndex] = Block(id: h.id, material: h.material, maxHP: h.maxHP, hp: heartHP, armor: 0, reward: h.reward)
    }
    var runs = dict["runs"] as! [String: Any]
    var run = runs["quarry"] as! [String: Any]
    run["area"] = area; run["maxCleared"] = area - 1; run["levels"] = ["strength": strength]
    run["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(blocks))
    runs[zone.rawValue] = run
    dict["runs"] = runs
    dict["seeds"] = ["quarry": 5, "caverns": 5, "magma": 5]
    var recs = dict["records"] as! [String: Any]
    var rec = recs["quarry"] as! [String: Any]
    rec["bestArea"] = area; rec["bestCleared"] = area - 1; rec["seenIntro"] = true
    var quarry = rec; quarry["heartsDefeated"] = quarryHearts; quarry["deepestHeart"] = quarryHearts > 0 ? 100 : 0
    recs["quarry"] = quarry
    if zone != .quarry { recs[zone.rawValue] = rec }
    dict["records"] = recs
    dict["unlockedZones"] = ["quarry", "caverns", "magma"]
    dict["activeZone"] = zone.rawValue
    if let legacy = legacyHearts { dict["heartsDefeated"] = legacy; dict["deepestHeart"] = 100 }
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func run(_ g: GameModel, _ seconds: Double) { for _ in 0..<Int(seconds * 20) { g.advance(by: 0.05) } }

@main struct Main {
    static func main() {
        // Every zone has a Heart at area 100
        for zone in ZoneID.allCases {
            let blocks = AreaGenerator.blocks(zone: zone, area: 100, seed: 3, treasureChance: 1)
            check(blocks[Conquest.heartIndex].material == .heart && !blocks.contains { $0.isTreasure },
                  "\(zone.name): area 100 holds the \(zone.heartName)")
        }
        check(ZoneID.caverns.mix(area: 90).contains { $0.0 == .starstone } && ZoneID.magma.mix(area: 90).contains { $0.0 == .dragonglass },
              "deep Caverns and Magma areas use the new ores")
        check(Ore.sapphire.isCrystal && Ore.brimstone.feverFuel > 0, "Sapphire chains, Brimstone fuels Fever")

        // Caverns Heart: its own crown, ×1.6 Perk Coins, its own Endless Depths
        zoneSave(.caverns, area: 100, quarryHearts: 1, heartHP: 50)
        var g = model()
        check(g.heartBlock != nil && !g.isEndless && abs(g.crownMultiplier - 1.25) < 1e-9, "Quarry Crown only: ×1.25, Caverns not endless yet")
        let pc = g.perkCoins
        var guardN = 0
        while g.heartBlock?.isBroken == false && guardN < 200_000 { g.punch(Conquest.heartIndex); guardN += 1 }
        check(g.record(for: .caverns).heartsDefeated == 1 && g.conquest?.zone == .caverns && g.conquest?.isCrown == true,
              "the Caverns Heart falls and gives the Caverns Crown")
        check(g.perkCoins - pc == 160, "Caverns Crown pays 100 × 1.6 = 160 PC (\(g.perkCoins - pc))")
        check(abs(g.crownMultiplier - 1.5) < 1e-9 && g.crowns == 2, "two Crowns: coins ×1.5 in every zone")
        check(g.isEndless && g.maxArea(for: .caverns) == Int.max, "Caverns goes Endless")
        check(g.hasCrown(.quarry) && !g.hasCrown(.magma) && g.maxArea(for: .magma) == 100, "Magma still ends at 100")

        // Caverns twist: a crystal chain that touches the Heart hits it
        zoneSave(.caverns, area: 100, weak: true)
        g = model()
        let around = Set(Conquest.heartCells.flatMap { c in [c - 1, c + 1, c - 5, c + 5] }).subtracting(Conquest.heartCells)
        if let crystal = around.sorted().first(where: { g.run.blocks[$0].material.isCrystal }) {
            let hp = g.heartBlock!.hp
            g.punch(crystal)
            check(g.heartBlock!.hp < hp && g.floaters.contains { $0.text.hasPrefix("CHAIN") && $0.blockIndex == Conquest.heartIndex },
                  "breaking a crystal next to the Heart chains into it")
        } else { check(false, "a crystal touches the Heart") }
        zoneSave(.quarry, area: 100, weak: true)
        g = model()
        let hpQ = g.heartBlock!.hp
        for i in around.sorted() { g.punch(i) }
        check(g.heartBlock!.hp == hpQ, "no chains into the Quarry Heart")

        // Magma twist: vents feed the Heart
        zoneSave(.magma, area: 100, strength: 200)
        g = model()
        if g.run.blocks.contains(where: { $0.material == .vent && !$0.isBroken }) {
            for _ in 0..<3 { g.punch(Conquest.heartIndex) }
            run(g, Magma.ventInterval + 0.5)
            check(g.floaters.contains { $0.text == "+HEAL" } || g.heartBlock!.hp >= g.heartBlock!.maxHP * 0.999,
                  "a vent eruption heals the Heart of the Depths")
        } else { check(false, "area 100 in Magma has vents") }
        let heart = g.heartBlock!
        for _ in 0..<40 { g.punch(Conquest.heartIndex) }
        let low = g.heartBlock!.hp
        run(g, 3)
        check(g.heartBlock!.hp > low && g.heartBlock!.hp <= heart.maxHP, "left alone, it heals toward its last crack")

        // Old saves kept Pebble Quarry's Heart at the top level
        zoneSave(.quarry, area: 110, legacyHearts: 1)
        g = model()
        check(g.record(for: .quarry).heartsDefeated == 1 && g.deepestHeart == 100 && g.isEndless, "old Heart progress moves into Pebble Quarry")
        g.save()
        check(model().record(for: .quarry).heartsDefeated == 1, "and isn't counted twice after saving again")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
