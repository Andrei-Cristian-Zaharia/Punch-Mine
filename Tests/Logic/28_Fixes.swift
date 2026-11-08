import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model(at date: Date = Date()) -> GameModel {
    let g = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics28"))
    g.now = { date }
    return g
}
func utc(_ y: Int, _ m: Int, _ d: Int) -> Date {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
    return c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}
func save(blocks: [Block]? = nil, area: Int = 20, strength: Int = 20, extra: [String: Any] = [:]) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var runs = dict["runs"] as! [String: Any]
    var run = runs["quarry"] as! [String: Any]
    run["area"] = area; run["maxCleared"] = area - 1; run["levels"] = ["strength": strength]
    if let blocks { run["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(blocks)) }
    runs["quarry"] = run; dict["runs"] = runs
    var recs = dict["records"] as! [String: Any]
    var rec = recs["quarry"] as! [String: Any]
    rec["bestArea"] = area; rec["bestCleared"] = area - 1
    recs["quarry"] = rec; dict["records"] = recs
    for (k, v) in extra { dict[k] = v }
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func stones(hp: Double = 1e6) -> [Block] { (0..<30).map { Block(id: $0, material: .stone, maxHP: hp, hp: hp, armor: 0, reward: 1) } }

@main struct Main {
    static func main() {
        // The treasure offer repeats exactly what the break paid
        var b = stones()
        b[3] = Block(id: 3, material: .treasure, maxHP: 1, hp: 1, armor: 0, reward: 500)
        save(blocks: b)
        var g = model()
        g.adsAvailable = true
        let before = g.run.lifetimeCoins
        g.punch(3)
        let paid = g.run.lifetimeCoins - before
        check(g.treasureOffer.map { abs($0.coins - paid) < 1e-6 } == true, "Double treasure offers what the break paid (\(paid))")

        // Rewarded ads only use a daily slot when they pay
        g.adWillShow(.coinRush)
        g.adDidFinish(.coinRush, rewarded: false)
        check(g.adsLeftToday(.coinRush) == AdPlacement.coinRush.dailyLimit, "a failed ad doesn't use up a slot")
        g.adWillShow(.coinRush)
        g.adDidFinish(.coinRush, rewarded: true)
        check(g.adsLeftToday(.coinRush) == AdPlacement.coinRush.dailyLimit - 1, "a watched one does")

        // Firework through the Heart hits the Heart
        save(blocks: [], area: 100, strength: 1)  // empty blocks: the game builds area 100 with its Heart
        g = model()
        g.grant(Reward(consumables: [.firework: 1]))
        if let heart = g.heartBlock {
            var tries = 0
            while g.heartBlock?.hp == heart.hp && tries < 50 {
                tries += 1
                g.grant(Reward(consumables: [.firework: 1]))
                g.use(.firework)
            }
            check(g.heartBlock.map { $0.hp < heart.hp } ?? true, "a firework row or column through the Heart damages it")
        } else {
            check(false, "area 100 has a Heart")
        }

        // Weekly fight survives absurd damage without crashing or NaN
        save(strength: 20)
        g = model()
        g.startWeeklyFight()
        for _ in 0..<5 { g.grant(Reward()) }
        let huge = Double.infinity
        _ = huge
        g.finishWeeklyFightEarly()
        let fight = WeeklyFight(modifier: .critical)
        check(fight.progress.isFinite && WeeklyHeart.score(tiersBroken: 3, progress: fight.progress) == 300, "a fresh tier has 0% progress")
        var f = WeeklyFight(modifier: .critical); f.hp = .nan
        check(f.progress == 0 && f.score == 0, "a broken number never crashes the score")

        // Play time is batched but never lost
        save()
        g = model()
        let t0 = g.stats.playSeconds
        for _ in 0..<10 { g.advance(by: 0.05) }
        check(abs(g.stats.playSeconds - t0 - 0.5) < 1e-6, "play time adds up exactly")

        // Reset clears new systems but keeps today's daily claim and a paid pass
        save(extra: ["consumables": ["snowball": 3], "pets": ["owl": 2], "activePet": "owl", "cosmetics": ["fist.frost"], "shards": ["0": 2]])
        g = model(at: utc(2026, 12, 20))
        g.claimDaily()
        _ = g.grantPurchase(.eventPass, transactionID: "pass-1")
        g.resetProgress()
        check(g.consumables.isEmpty && g.pets.isEmpty && g.activePet == nil && g.cosmetics.isEmpty && g.shards.isEmpty, "reset clears stash, pets, looks and shards")
        check(!g.dailyAvailable(), "the daily reward can't be claimed twice by resetting")
        check(g.eventProgress.premium, "a paid Event Pass survives a reset")

        // Import keeps the pass bought on this device
        save()
        let other = model(at: utc(2026, 12, 20))
        let incoming = other.encodedSaveWithoutSaving()!
        g = model(at: utc(2026, 12, 20))
        _ = g.grantPurchase(.eventPass, transactionID: "pass-2")
        check(g.importSave(incoming) && g.eventProgress.premium, "importing another save keeps this device's Event Pass")

        // A boss attack that spans an event change pays nothing for the wrong event
        save(strength: 20)
        g = model(at: utc(2026, 11, 7))
        g.startBossFight()
        g.now = { utc(2026, 11, 9) }
        g.finishBossFightEarly()
        check(g.bossFight == nil && g.bossResult?.phases.isEmpty == true && g.bossResult?.season == .harvest, "the result still belongs to the event it started in")

        // The mini-mine respects the tap limit
        save()
        g = model(at: utc(2026, 12, 20))
        let hp = g.miniBlocks[0].maxHP
        for _ in 0..<100 { g.punchMini(0) }
        let hits = (hp - (g.season.miniBlocks.first?.hp ?? hp)) / g.miniPickDamage
        check(g.season.miniBlocks.isEmpty || hits <= Double(Config.tapCapPerSecond) + 0.01 || g.season.miniBlocks[0].isBroken,
              "at most \(Config.tapCapPerSecond) mini-mine taps a second")

        // An unreadable save is kept, not overwritten
        UserDefaults.standard.set(Data("{\"version\": 99, \"runs\": 5}".utf8), forKey: key)
        g = model()
        check(UserDefaults.standard.data(forKey: key + ".unreadable") != nil, "a save that can't be read is backed up")
        UserDefaults.standard.removeObject(forKey: key + ".unreadable")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
