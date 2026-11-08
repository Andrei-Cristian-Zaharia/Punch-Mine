import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics24")) }
/// A Pebble Quarry save at `area` with the given Strength level.
func quarrySave(area: Int, strength: Int = 0) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var runs = dict["runs"] as! [String: Any]
    var run = runs["quarry"] as! [String: Any]
    run["area"] = area; run["maxCleared"] = area - 1; run["levels"] = ["strength": strength]
    runs["quarry"] = run; dict["runs"] = runs
    var recs = dict["records"] as! [String: Any]
    var rec = recs["quarry"] as! [String: Any]
    rec["bestArea"] = area; rec["bestCleared"] = area - 1
    recs["quarry"] = rec; dict["records"] = recs
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
/// A moment inside week `w` whose modifier is `m`.
func day(in w: Int) -> Date { WeeklyHeart.start(of: w).addingTimeInterval(86_400) }
func week(with m: WeeklyModifier) -> Int { (0..<4).first { WeeklyHeart.modifier(week: $0) == m }! }
func run(_ g: GameModel, _ seconds: Double) { for _ in 0..<Int((seconds * 20).rounded()) { g.advance(by: 0.05) } }

@main struct Main {
    static func main() {
        // Calendar
        check(WeeklyHeart.week(of: WeeklyHeart.epoch) == 0 && WeeklyHeart.week(of: WeeklyHeart.epoch.addingTimeInterval(-1)) == -1,
              "week 0 starts at the epoch")
        let monday = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: WeeklyHeart.epoch)
        check(monday.weekday == 2 && monday.hour == 0, "weeks start on Monday 00:00 UTC")
        check(WeeklyHeart.end(of: 3).timeIntervalSince(WeeklyHeart.start(of: 3)) == 7 * 86_400, "a week is 7 days")
        check(Set((10..<14).map(WeeklyHeart.modifier)).count == WeeklyModifier.allCases.count, "every modifier comes round in 4 weeks")

        // Score and bands
        check(WeeklyHeart.score(tiersBroken: 12, progress: 0.475) == 1247 && WeeklyHeart.scoreText(1247) == "12.47", "12.47 tiers scores 1247")
        check(WeeklyHeart.score(tiersBroken: 3, progress: 0.9999) == 399, "the fraction never rounds up to a whole tier")
        check(WeeklyHeart.band(rank: 1, total: 1).name == "1st place" && WeeklyHeart.band(rank: 3, total: 3).name == "3rd place",
              "places 1–3 win by rank, even in a small field")
        check(WeeklyHeart.band(rank: 10, total: 100).name == "Top 10%" && WeeklyHeart.band(rank: 25, total: 100).name == "Top 25%"
              && WeeklyHeart.band(rank: 50, total: 100).name == "Top 50%" && WeeklyHeart.band(rank: 51, total: 100).name == "Took part",
              "everyone else by share of the field")
        let pays = WeeklyHeart.rankBands.map { $0.reward.chests[.golden, default: 0] * 1000 + $0.reward.scrap }
        check(pays == pays.sorted(by: >), "better places always pay more")

        // Locked early on
        quarrySave(area: 5)
        var g = model()
        g.startWeeklyFight()
        check(!g.weeklyUnlocked && g.weeklyFight == nil, "locked before area \(WeeklyHeart.unlockArea)")

        // A fight: armoured week, no penetration, no crits
        quarrySave(area: 20, strength: 20)
        g = model()
        var reported: (Int, Int)?
        g.onWeeklyBest = { reported = ($0, $1) }
        let armouredWeek = week(with: .armoured)
        g.startWeeklyFight(now: day(in: armouredWeek))
        check(g.weeklyFight?.modifier == .armoured && g.weekly.attemptsUsed == 1, "starting uses a try")
        g.punchWeekly()
        let hit = g.weeklyFight!.damage
        check(abs(hit - g.weeklyPunch * WeeklyHeart.armourFloor) < 0.001, "armour cuts a hit to \(WeeklyHeart.armourFloor) with no penetration")
        for _ in 0..<40 { g.punchWeekly(); g.advance(by: 0.1) }
        let mid = g.weeklyFight!
        check(mid.tier > 2 && mid.hp < mid.maxHP + 0.001, "tiers break and the next one spawns (tier \(mid.tier))")
        run(g, WeeklyHeart.fightSeconds)
        check(g.weeklyFight == nil && g.weeklyResult?.score == g.weekly.best && g.weekly.best > 0, "the fight ends after \(Int(WeeklyHeart.fightSeconds)) s")
        check(reported?.0 == armouredWeek && reported?.1 == g.weekly.best, "a new best goes to the leaderboard")
        check(g.weeklyResult?.isBest == true, "first score is a best")

        // Damage carries over, so a strong punch races through many tiers at once
        quarrySave(area: 20, strength: 400)
        g = model()
        g.startWeeklyFight(now: day(in: armouredWeek))
        g.punchWeekly()
        let tiers = g.weeklyFight!.tiersBroken
        let needed = (1...tiers).map { WeeklyHeart.hp(tier: $0) }.reduce(0, +)
        check(tiers > 10 && needed <= g.weeklyFight!.damage, "one big punch breaks \(tiers) tiers")
        let chestsBefore = g.chestCount, scrapBefore = g.scrap
        g.finishWeeklyFightEarly()
        let earned = WeeklyHeart.milestones.filter { $0.tiers <= tiers }
        check(g.weeklyResult?.milestones.map(\.tiers) == earned.map(\.tiers), "milestones pay on the spot (\(earned.map(\.tiers)))")
        let expectChests = earned.flatMap { $0.reward.chests.values }.reduce(0, +)
        check(g.chestCount - chestsBefore == expectChests && g.scrap - scrapBefore == earned.map(\.reward.scrap).reduce(0, +),
              "milestone chests and Scrap added")
        g.startWeeklyFight(now: day(in: armouredWeek))
        g.punchWeekly()
        g.finishWeeklyFightEarly()
        check(g.weeklyResult?.milestones.isEmpty == true && g.chestCount - chestsBefore == expectChests, "milestones pay once a week")
        check(g.weeklyState(now: day(in: armouredWeek + 1)).best == 0 && g.weeklyState(now: day(in: armouredWeek + 1)).milestones.isEmpty,
              "a new week starts from zero")

        // Tries: 3 free a day, then rewarded ads
        quarrySave(area: 20, strength: 20)
        g = model()
        for _ in 0..<WeeklyHeart.freeAttemptsPerDay { g.startWeeklyFight(); g.finishWeeklyFightEarly() }
        g.startWeeklyFight()
        check(g.weeklyFight == nil && g.weeklyAttemptsLeft() == 0, "no fourth free try")
        g.adsAvailable = true
        check(g.canWatch(.weeklyHeart), "an ad offers another try")
        g.adWillShow(.weeklyHeart)
        g.adDidFinish(.weeklyHeart, rewarded: true)
        check(g.weeklyAttemptsLeft() == 1, "the ad adds a try")
        g.startWeeklyFight()
        check(g.weeklyFight != nil && !g.canWatch(.weeklyHeart), "and it can be used; no ad offer mid-fight")
        g.finishWeeklyFightEarly()
        let tomorrow = Date().addingTimeInterval(86_400)
        check(g.freeWeeklyAttemptsLeft(now: tomorrow) == WeeklyHeart.freeAttemptsPerDay, "tries refill the next day")

        // Regenerating Heart heals
        quarrySave(area: 20, strength: 20)
        g = model()
        g.startWeeklyFight(now: day(in: week(with: .regenerating)))
        g.punchWeekly()
        let hurt = g.weeklyFight!.hp
        run(g, 1)
        let healed = g.weeklyFight!.hp - hurt
        check(abs(healed - g.weeklyFight!.maxHP * WeeklyHeart.regenPerSecond) < 0.01 * g.weeklyFight!.maxHP, "regenerates \(Int(WeeklyHeart.regenPerSecond * 100))% a second")
        g.finishWeeklyFightEarly()

        // Phantom Heart fades, then every punch crits for a second after it returns
        g.startWeeklyFight(now: day(in: week(with: .phasing)))
        run(g, WeeklyHeart.phaseSolidSeconds + 0.2)
        let before = g.weeklyFight!.damage
        g.punchWeekly()
        check(g.weeklyFight!.faded && g.weeklyFight!.damage == before, "a faded Heart takes nothing")
        run(g, WeeklyHeart.phaseFadedSeconds)
        g.punchWeekly()
        check(!g.weeklyFight!.faded && g.weeklyFight!.lastCrit, "the first punch after it returns crits")
        g.finishWeeklyFightEarly()

        // Brittle Heart: crits happen even with no crit upgrades
        g = model()
        g.startWeeklyFight(now: day(in: week(with: .critical)))
        var crits = 0
        for _ in 0..<250 { g.punchWeekly(); if g.weeklyFight?.lastCrit == true { crits += 1 }; g.advance(by: 0.1) }
        check(crits > 0 && g.critChance == 0, "Brittle Heart adds crit chance (\(crits) crits)")

        // The crew helps, but never more than a few punches a second
        quarrySave(area: 20, strength: 20)
        g = model()
        check(g.weeklyCrewDPS <= g.weeklyPunch * WeeklyHeart.crewCapPunchesPerSecond + 1e-9, "the crew is capped at \(Int(WeeklyHeart.crewCapPunchesPerSecond)) punches a second")

        // Leaderboard rewards
        quarrySave(area: 20)
        g = model()
        let golden = g.chestCount(.golden), pc = g.perkCoins
        check(!g.claimWeeklyRank(week: 5, rank: 1, total: 10, now: day(in: 5)), "a week still running pays nothing")
        check(g.claimWeeklyRank(week: 5, rank: 2, total: 10, now: day(in: 6)), "a finished week pays")
        check(g.chestCount(.golden) - golden == 2 && g.perkCoins - pc == 200 && g.weekly.lastRank?.band == "2nd place", "2nd place: 2 Golden Chests, 200 PC")
        check(!g.claimWeeklyRank(week: 5, rank: 1, total: 10, now: day(in: 6)), "each week pays once")
        g = model()
        check(g.weekly.rankClaimedWeeks == [5] && g.weekly.lastRank?.rank == 2 && !g.claimWeeklyRank(week: 5, rank: 2, total: 10, now: day(in: 6)),
              "claims survive a reload")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
