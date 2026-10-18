import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics16")) }
/// A fresh save at `area` with the given gear. `extra` is merged into the top-level save dictionary.
func gearSave(area: Int = 3, items: [String: Int] = [:], equipped: [String: String] = [:], chests: [String: Int] = [:],
              quarryHearts: Int = 0, extra: [String: Any] = [:]) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var recs = dict["records"] as! [String: Any]; var r = recs["quarry"] as! [String: Any]
    r["bestArea"] = area; r["bestCleared"] = area - 1
    r["heartsDefeated"] = quarryHearts; r["deepestHeart"] = quarryHearts > 0 ? 100 : 0
    recs["quarry"] = r; dict["records"] = recs
    dict["items"] = items; dict["equipped"] = equipped; dict["chests"] = chests
    for (k, v) in extra { dict[k] = v }
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func day(_ s: String) -> Date {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; f.timeZone = .current
    return f.date(from: s)!
}

@main struct Main {
    static func main() {
        // Catalogue
        let all = ItemDef.all
        check(ItemSlot.allCases.allSatisfy { s in ItemDef.chestPool.filter { $0.slot == s }.count >= 6 },
              "every slot has 6+ items that chests can give")
        check(all.filter { $0.nod != nil }.count >= 15, "15+ items nod to other games")
        check(ItemSet.allCases.allSatisfy { set in Set(set.pieces.map(\.slot)).count == 4 }, "each set has one piece per slot")
        check(ZoneID.allCases.allSatisfy { ItemDef.relic(for: $0)?.rarity == .mythic } && !ItemDef.chestPool.contains { $0.rarity == .mythic },
              "one Mythic relic per zone, never in chests")

        check((1...2).allSatisfy { a in !AreaGenerator.blocks(zone: .quarry, area: a, seed: 9, treasureChance: 1).contains { $0.isTreasure } }
              && AreaGenerator.blocks(zone: .quarry, area: 3, seed: 9, treasureChance: 1).contains { $0.isTreasure },
              "no treasure in areas 1–2, treasure from area 3")

        // Odds: rarer than before, still 100%
        check(ChestTier.allCases.allSatisfy { abs($0.odds.reduce(0, +) - 1) < 1e-9 && abs($0.odds(luck: 0.5).reduce(0, +) - 1) < 1e-9 },
              "odds add up to 100%, with and without chest luck")
        check(ChestTier.wooden.odds[3] <= 0.001 && ChestTier.wooden.odds[2] <= 0.01, "Wooden: Legendary 0.1%, Epic 1%")
        let lucky = ChestTier.iron.odds(luck: 0.25)
        check(abs(lucky[3] - 0.00625) < 1e-9 && abs(lucky[2] - 0.0625) < 1e-9 && lucky[0] < ChestTier.iron.odds[0],
              "+25% chest luck: Iron Epic 5% → 6.25%, Legendary 0.5% → 0.625%, taken from Common")
        check(ChestTier.golden.odds(luck: 1)[0] == 0 && ChestTier.golden.odds(luck: 1)[1] < ChestTier.golden.odds[1],
              "Golden luck comes out of Rare when there's no Common")
        // Monte Carlo on Wooden
        var counts = [0, 0, 0, 0]
        for _ in 0..<200_000 { counts[ChestTier.wooden.rollRarity(Double.random(in: 0..<1)).rawValue] += 1 }
        check(counts[3] < 400 && counts[2] < 2_500, "200K Wooden rolls: \(counts[2]) Epic, \(counts[3]) Legendary")

        // Bad-luck protection: Wooden chests always give Epic+ by the 40th, Legendary by the 150th
        gearSave(chests: ["wooden": 300])
        var g = model()
        var sinceEpic = 0, worstEpic = 0, sinceLeg = 0, worstLeg = 0, guaranteed = 0
        for _ in 0..<300 {
            g.openChest(.wooden)
            let r = ItemDef.find(g.chestReveal!.item)!.rarity
            if g.chestReveal!.guaranteed { guaranteed += 1 }
            sinceEpic = r >= .epic ? 0 : sinceEpic + 1; worstEpic = max(worstEpic, sinceEpic)
            sinceLeg = r >= .legendary ? 0 : sinceLeg + 1; worstLeg = max(worstLeg, sinceLeg)
        }
        check(worstEpic < ItemRules.epicPity && worstLeg < ItemRules.legendaryPity && guaranteed > 0,
              "pity: longest run without Epic \(worstEpic), without Legendary \(worstLeg) (\(guaranteed) guaranteed)")
        check(g.stats.chestsOpened == 300, "stats count opened chests")
        let before = g.chestsSinceLegendary
        g.save(); g = model()
        check(g.chestsSinceLegendary == before, "pity counters survive a reload")

        // Set bonuses
        gearSave(items: ["plumbersCap": 1, "plumbersOveralls": 1, "powerStar": 1, "groundPoundBoots": 1, "toolBelt": 1])
        g = model()
        let coinBase = g.itemBonus(.coins)
        g.equip("plumbersCap")
        check(abs(g.itemBonus(.coins) - coinBase - 0.06) < 1e-9 && g.activeSetBonuses.isEmpty, "1 piece: no set bonus")
        g.equip("plumbersOveralls")
        check(abs(g.itemBonus(.coins) - 0.21) < 1e-9, "2 pieces: +15% coins on top of the cap's 6%")
        g.equip("powerStar"); g.equip("groundPoundBoots")
        check(abs(g.itemBonus(.lucky) - 0.08) < 1e-9 && g.activeSetBonuses.count == 2, "4 pieces: +8% lucky too")
        check(abs(g.feverDuration - (Config.feverDuration + 3)) < 1e-9, "Power Star: Fever lasts +3 s")
        g.equip("toolBelt")
        check(g.setPieces(.plumber) == 3 && abs(g.itemBonus(.lucky)) < 1e-9, "swapping a piece out drops the 4-piece bonus")

        // Chest luck item
        gearSave(items: ["goblinSack": 1], equipped: ["belt": "goblinSack"])
        check(abs(model().chestLuck - 0.25) < 1e-9, "Treasure Goblin's Sack: +25% chest luck")

        // Heart relics: granted with the Crown, and to saves that already have it
        gearSave(quarryHearts: 1)
        g = model()
        check(g.itemLevel("heartstoneBuckle") == 1 && g.equipped["belt"] == "heartstoneBuckle", "existing Quarry Crown gets the Heartstone Buckle")
        check(g.itemLevel("prismHeart") == 0, "no Caverns relic without the Caverns Crown")

        // Daily rewards
        gearSave(area: 3)
        g = model()
        check(!g.dailyAvailable(now: day("2026-10-01 10:00")), "daily track locked before area \(Daily.unlockArea)")
        gearSave(area: 10)
        g = model()
        let w = g.chestCount(.wooden)
        check(g.dailyAvailable(now: day("2026-10-01 10:00")) && g.nextDailyDay(now: day("2026-10-01 10:00")) == 1, "day 1 available")
        g.claimDaily(now: day("2026-10-01 10:00"))
        check(g.chestCount(.wooden) == w + 1 && !g.dailyAvailable(now: day("2026-10-01 23:59")), "claimed once per day")
        g.claimDaily(now: day("2026-10-01 23:59"))
        check(g.chestCount(.wooden) == w + 1, "a second claim the same day does nothing")
        g.claimDaily(now: day("2026-10-02 00:05"))
        check(g.daily.streak == 2 && g.dailyClaimedThisWeek(now: day("2026-10-02 08:00")) == 2, "next day continues the streak")
        for d in 3...7 { g.claimDaily(now: day("2026-10-0\(d) 09:00")) }
        check(g.daily.streak == 7 && g.chestCount(.golden) == 1, "day 7 gives a Golden Chest")
        check(g.nextDailyDay(now: day("2026-10-08 09:00")) == 1, "after day 7 the track starts over")
        g.claimDaily(now: day("2026-10-08 09:00"))
        g.claimDaily(now: day("2026-10-09 09:00"))
        check(g.nextDailyDay(now: day("2026-10-11 09:00")) == 1 && g.dailyClaimedThisWeek(now: day("2026-10-11 09:00")) == 0,
              "missing a day resets the streak")
        g.save(); g = model()
        check(g.daily.lastClaimDay == "2026-10-09" && g.stats.dailyClaims == 9, "daily state and claims saved")

        // Lifetime stats
        gearSave(area: 3)
        g = model()
        let start = g.stats
        for _ in 0..<200 { g.punch(g.run.blocks.firstIndex { !$0.isBroken }!) }
        check(g.stats.punches == start.punches + 200 && g.stats.blocksBroken > start.blocksBroken
              && (g.stats.coins["quarry"] ?? 0) > (start.coins["quarry"] ?? 0), "stats count punches, breaks and coins")
        g.prestige()
        check(g.stats.punches >= 200, "stats survive prestige")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
