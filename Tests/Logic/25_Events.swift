import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model(at date: Date) -> GameModel {
    let g = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics25"))
    g.now = { date }
    return g
}
func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
    return c.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}
/// A Pebble Quarry save at `area`, with 30 one-HP blocks; `event` marks which cells hold the event block.
func quarrySave(area: Int, cells: [Int: Ore] = [:]) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(at: Date()); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    let blocks = (0..<30).map { i in Block(id: i, material: cells[i] ?? .stone, maxHP: 1, hp: 1, armor: 0, reward: 1) }
    var runs = dict["runs"] as! [String: Any]
    var run = runs["quarry"] as! [String: Any]
    run["area"] = area; run["maxCleared"] = area - 1
    run["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(blocks))
    runs["quarry"] = run; dict["runs"] = runs
    var recs = dict["records"] as! [String: Any]
    var rec = recs["quarry"] as! [String: Any]
    rec["bestArea"] = area; rec["bestCleared"] = area - 1
    recs["quarry"] = rec; dict["records"] = recs
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}

@main struct Main {
    static func main() {
        // Calendar
        check(Seasons.active(at: utc(2026, 10, 31))?.season == .harvest, "Halloween is Haunted Harvest")
        check(Seasons.active(at: utc(2026, 11, 8, 0))?.season != .harvest && Seasons.active(at: utc(2026, 11, 7, 23))?.season == .harvest, "Harvest ends 8 Nov 00:00 UTC")
        check(Seasons.active(at: utc(2026, 12, 25))?.id == "frostfall-2026" && Seasons.active(at: utc(2027, 1, 3))?.id == "frostfall-2026",
              "Frostfall 2026 runs into January")
        check(Seasons.active(at: utc(2027, 2, 10))?.season == .lantern && Seasons.active(at: utc(2028, 1, 22))?.season == .lantern,
              "Lantern Festival follows Lunar New Year")
        check(Seasons.active(at: utc(2027, 3, 25))?.season == .bloom && Seasons.active(at: utc(2027, 6, 20))?.season == .splash
              && Seasons.active(at: utc(2027, 9, 1))?.season == .goldrush, "Spring Bloom, Sunny Splash and Gold Rush")
        // Encores fill the gaps.
        let gapDay = utc(2027, 5, 15)
        let encore = Seasons.active(at: gapDay)
        check(encore?.encore == true && encore!.season != .bloom && encore!.season != .splash && encore!.name.hasSuffix("Encore"),
              "a gap reruns another event as an Encore (\(encore?.name ?? "none"))")
        check(encore?.window.start == SeasonID.bloom.window(year: 2027)!.end && encore?.window.end == SeasonID.splash.window(year: 2027)!.start,
              "the encore runs the whole gap")
        check(encore?.id != Seasons.active(at: utc(2027, 8, 1))?.id, "each gap is its own encore")
        var uncovered = 0
        var d = utc(2027, 1, 1)
        while d < utc(2029, 1, 1) { if Seasons.active(at: d) == nil { uncovered += 1 }; d = d.addingTimeInterval(86_400) }
        check(uncovered <= 14, "almost every day of the year has an event (\(uncovered) days without, in two years)")
        check(Seasons.next(after: utc(2026, 11, 20))?.id == "frostfall-2026", "next after Harvest is Frostfall")
        var overlaps = false
        for y in 2026...2031 {
            let ws = SeasonID.allCases.compactMap { $0.window(year: y) }
            for a in ws { for b in ws where a != b && a.intersects(b) && a.end != b.start && b.end != a.start { overlaps = true } }
        }
        check(!overlaps, "events never overlap")

        // Track
        let t = Seasons.track(for: .frostfall)
        check(t.count == 20 && zip(t, t.dropFirst()).allSatisfy { $0.points < $1.points }, "20 steps, each needing more")
        check(t.flatMap(\.free.items) == SeasonID.frostfall.setPieces, "the free track hands out the 3-piece set, last piece at the end")
        check(t.flatMap(\.premium.cosmetics).count == 3 && t.flatMap(\.premium.pets) == ["owl"], "the pass track has a fist skin, break effect, icon and pet")
        check(SeasonID.allCases.allSatisfy { s in Seasons.track(for: s).allSatisfy { !$0.free.text.isEmpty && !$0.premium.text.isEmpty } },
              "every event's track pays on every step")
        let golden = t.map { $0.premium.chests[.golden, default: 0] }.reduce(0, +)
        check(golden == 9, "the pass track holds 9 Golden Chests (\(golden))")
        check(t.allSatisfy { !$0.free.text.isEmpty && !$0.premium.text.isEmpty }, "every step pays on both tracks")
        check(ItemDef.chestPool.allSatisfy { $0.season == nil } && SeasonID.allCases.allSatisfy { s in s.setPieces.allSatisfy { ItemDef.find($0)?.season == s } },
              "event set pieces never come from chests")

        // Points
        check(Seasons.points(area: 10, coinRush: false, pass: false) == 1 && Seasons.points(area: 80, coinRush: false, pass: false) == 3,
              "deeper areas pay more")
        check(Seasons.points(area: 10, coinRush: true, pass: false) == 2 && Seasons.points(area: 10, coinRush: false, pass: true) == 2
              && Seasons.points(area: 80, coinRush: true, pass: true) == 9, "Coin Rush ×2, the pass +50%")

        // Spawning
        let blocks = AreaGenerator.blocks(zone: .quarry, area: 30, seed: 9, treasureChance: 0.5)
        let sprinkled = Seasons.sprinkle(.frostfall, into: blocks, seed: 42)
        let changed = zip(blocks, sprinkled).filter { $0.material != $1.material }
        check(changed.count == Seasons.blocksPerArea && changed.allSatisfy { $1.material == .frostShard && $0.maxHP == $1.maxHP && $0.reward == $1.reward },
              "\(Seasons.blocksPerArea) ordinary blocks become event blocks, same HP and reward")
        check(changed.allSatisfy { !$0.0.isTreasure }, "treasure is never replaced")
        check(Seasons.sprinkle(.frostfall, into: blocks, seed: 42) == sprinkled, "the same seed picks the same cells")

        let inEvent = utc(2026, 12, 20), outside = utc(2027, 6, 1)
        quarrySave(area: 20)
        var g = model(at: inEvent)
        let fresh = g.newBlocks(area: 21)
        check(fresh.filter { $0.material == .frostShard }.count == Seasons.blocksPerArea, "new areas get event blocks during an event")
        check(!g.newBlocks(area: 100).contains { $0.material == .frostShard }, "but never a Heart area")
        g = model(at: utc(2027, 5, 15))
        check(g.newBlocks(area: 21).filter { $0.material == g.activeEvent!.season.ore }.count == Seasons.blocksPerArea,
              "encores spawn their event block too")
        quarrySave(area: 3)
        g = model(at: inEvent)
        check(!g.seasonUnlocked && !g.newBlocks(area: 4).contains { $0.material.season != nil }, "new players see events from area \(Seasons.unlockArea)")

        // Earning and claiming
        quarrySave(area: 20, cells: [0: .frostShard, 1: .frostShard, 2: .pumpkin])
        g = model(at: inEvent)
        g.punch(0); g.punch(1)
        check(g.season.event == "frostfall-2026" && g.season.points == 2, "breaking event blocks earns currency")
        g.punch(2)
        check(g.season.points == 2, "an old event's block left in the mine pays nothing")
        let wooden = g.chestCount(.wooden)
        check(!g.canClaimEventStep(t[0], premium: false), "step 1 needs \(t[0].points)")
        quarrySave(area: 20, cells: Dictionary(uniqueKeysWithValues: (0..<30).map { ($0, Ore.frostShard) }))
        g = model(at: inEvent)
        for i in 0..<12 { g.punch(i) }
        check(g.readyEventSteps == 1 && g.canClaimEventStep(t[0], premium: false) && !g.canClaimEventStep(t[0], premium: true),
              "step 1 ready on the free track only")
        g.claimEventStep(t[0], premium: false)
        check(g.chestCount(.wooden) == wooden + 1 && !g.canClaimEventStep(t[0], premium: false), "claimed once")

        // Event Pass
        check(g.grantPurchase(.eventPass, transactionID: "p1") && g.season.premium, "the pass unlocks the gold track")
        check(g.canClaimEventStep(t[0], premium: true), "and earlier steps can be claimed on it")
        let golden0 = g.chestCount(.golden)
        check(g.grantPurchase(.eventPass, transactionID: "p2") && g.season.premium && g.chestCount(.golden) == golden0 + 3,
              "a second pass in the same event pays 3 Golden Chests instead")
        let before = g.season.points
        g.punch(20)
        check(g.season.points - before == 2, "pass holders earn +50% (rounded up)")

        // The full track, and a new event starting over
        // A save with the whole track filled.
        quarrySave(area: 20)
        var s = SeasonState(); s.event = "frostfall-2026"; s.points = 1_300
        var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
        dict["season"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(s))
        UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
        g = model(at: inEvent)
        g.claimAllEventSteps()
        check(g.itemLevel("frostfallBoots") == 1 && g.season.claimed.count == 20 && g.readyEventSteps == 0, "the full free track ends with Frostfall Boots")
        check(!g.canSalvage("frostfallBoots"), "event set pieces can't be salvaged")
        check(g.setPieces(.frostborn) == 3 && g.itemBonus(.critDamage) >= 0.5 + 0.5, "the full Frostborn set is worn, with its 3-piece bonus")
        check(g.consumableCount(.snowball) == 2 && g.consumableCount(.eventRush) == 1, "track consumables land in the stash")
        g.now = { utc(2027, 12, 20) }
        check(g.eventProgress.points == 0 && g.activeEvent?.id == "frostfall-2027", "next year's Frostfall starts from zero")
        g.save()
        UserDefaults.standard.removeObject(forKey: key)
    }
}
