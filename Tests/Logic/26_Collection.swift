import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model(at date: Date = Date()) -> GameModel {
    let g = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics26"))
    g.now = { date }
    return g
}
func utc(_ y: Int, _ m: Int, _ d: Int) -> Date {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
    return c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}
/// A Pebble Quarry save at area 20 with the given blocks (1M HP stone by default) and Strength.
func save(blocks: [Block]? = nil, strength: Int = 20, extra: [String: Any] = [:]) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    let b = blocks ?? (0..<30).map { Block(id: $0, material: .stone, maxHP: 1e6, hp: 1e6, armor: 0, reward: 100) }
    var runs = dict["runs"] as! [String: Any]
    var run = runs["quarry"] as! [String: Any]
    run["area"] = 20; run["maxCleared"] = 19; run["levels"] = ["strength": strength]
    run["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(b))
    runs["quarry"] = run; dict["runs"] = runs
    var recs = dict["records"] as! [String: Any]
    var rec = recs["quarry"] as! [String: Any]
    rec["bestArea"] = 20; rec["bestCleared"] = 19
    recs["quarry"] = rec; dict["records"] = recs
    for (k, v) in extra { dict[k] = v }
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func run(_ g: GameModel, _ seconds: Double) { for _ in 0..<Int((seconds * 20).rounded()) { g.advance(by: 0.05) } }
let outside = utc(2027, 6, 1), inEvent = utc(2026, 12, 20)

@main struct Main {
    static func main() {
        // Rewards: one grant pays everything, and repeats become levels or Scrap
        save()
        var g = model(at: outside)
        g.grant(Reward(chests: [.iron: 1], scrap: 10, perkCoins: 5, consumables: [.snowball: 2], items: ["icicleCharm"],
                       pets: ["owl"], cosmetics: ["fist.frost", "icon.frost"]))
        check(g.chestCount(.iron) == 1 && g.scrap == 10 && g.perkCoins == 5 && g.consumableCount(.snowball) == 2, "chests, Scrap, PC and consumables")
        check(g.itemLevel("icicleCharm") == 1 && g.equippedItem(.charm)?.id == "icicleCharm", "a set piece arrives and is worn in an empty slot")
        check(g.petLevel("owl") == 1 && g.activePet == "owl", "a first pet follows you")
        check(g.equippedCosmetic(.fist)?.id == "fist.frost" && g.equippedCosmetic(.icon) == nil && g.owns(cosmetic: "icon.frost"),
              "a fist skin is worn at once; an app icon waits to be picked")
        g.grant(Reward(items: ["icicleCharm"], pets: ["owl"]))
        check(g.itemLevel("icicleCharm") == 1 + Seasons.repeatRelicLevels && g.petLevel("owl") == 2, "repeats level up")
        // Items can roll a treasure affix too, so compare with and without the pet.
        let withPet = g.itemBonus(.treasureChance)
        g.setActivePet(nil)
        check(abs(withPet - g.itemBonus(.treasureChance) - PetDef.find("owl")!.value(level: 2)) < 1e-9 && g.petBonus(.treasureChance) == 0,
              "the pet's bonus counts, and stops when it is sent away")

        // Consumables
        save()
        g = model(at: outside)
        g.grant(Reward(consumables: [.snowball: 1, .goldenPick: 1, .coinRush: 1, .feverStarter: 1, .timeBell: 1, .shiftDoubler: 1, .eventRush: 1]))
        g.punch(0)
        let plain = 1e6 - g.run.blocks[0].hp
        g.use(.snowball)
        g.punch(1)
        check(abs((1e6 - g.run.blocks[1].hp) / plain - ConsumableRules.snowballFactor) < 0.01, "Snowball: ×\(Int(ConsumableRules.snowballFactor)) punches")
        run(g, ConsumableRules.snowballSeconds + 0.1)
        g.punch(2)
        check(abs((1e6 - g.run.blocks[2].hp) / plain - 1) < 0.01, "and it wears off")
        g.use(.coinRush)
        check(g.coinRushRemaining >= ConsumableRules.coinRushSeconds - 1 && g.consumableCount(.coinRush) == 0, "a Coin Rush token runs Coin Rush")
        g.use(.feverStarter)
        check(g.feverActive, "Fever Starter starts Fever")
        check(g.activeEvent != nil && g.canUse(.eventRush), "Event Rush works whenever an event or encore runs")
        g.use(.shiftDoubler)
        check(g.shiftDoubled && !g.canUse(.shiftDoubler), "Double Shift waits for the next offline claim")

        // Golden Pickaxe pays ×5 on breaks
        save(blocks: (0..<30).map { Block(id: $0, material: .stone, maxHP: 1, hp: 1, armor: 0, reward: 100) })
        g = model(at: outside)
        g.grant(Reward(consumables: [.goldenPick: 1, .firework: 1, .magnet: 1]))
        var before = g.run.lifetimeCoins
        g.punch(0)
        let normal = g.run.lifetimeCoins - before
        g.use(.goldenPick)
        before = g.run.lifetimeCoins
        g.punch(1)
        check(abs((g.run.lifetimeCoins - before) / normal - ConsumableRules.goldenFactor) < 0.01, "Golden Pickaxe: breaks pay ×\(Int(ConsumableRules.goldenFactor))")
        let brokenBefore = g.run.blocks.filter(\.isBroken).count
        g.use(.firework)
        check(g.run.blocks.filter(\.isBroken).count - brokenBefore >= 6, "Firework breaks a row and a column")

        // Magnet
        var blocks = (0..<30).map { Block(id: $0, material: .stone, maxHP: 1e6, hp: 1e6, armor: 0, reward: 1) }
        blocks[4] = Block(id: 4, material: .treasure, maxHP: 1e9, hp: 1e9, armor: 0, reward: 1_000)
        save(blocks: blocks)
        g = model(at: outside)
        g.grant(Reward(consumables: [.magnet: 1]))
        g.use(.magnet)
        check(g.run.blocks[4].isBroken, "Magnet pulls in treasure")

        // Forge
        save(extra: ["shards": ["0": 3, "2": 2], "scrap": 1_000])
        g = model(at: outside)
        check(g.canForge(.common) && !g.canForge(.epic) && !g.canForge(.legendary), "3 shards forge; 2 don't; Legendary is the top")
        let owned = g.items.count
        g.forge(.common)
        let forged = g.chestReveal.flatMap { ItemDef.find($0.item) }
        check(forged?.rarity == .rare && g.items.count == owned + 1 && g.shardCount(.common) == 0 && g.scrap == 1_000 - Forge.scrapCost(.common),
              "Common shards forge a new Rare item")
        save(extra: ["shards": ["2": 3], "scrap": 1_000])
        g = model(at: outside)
        g.forge(.epic)
        check(g.owns(cosmetic: "title.smith"), "forging a Legendary earns Master Smith")
        save()
        g = model(at: outside)
        let dupes = (1...400).map { _ -> Int in g.grant(Reward(chests: [.wooden: 1])); g.openChest(.wooden); return 0 }.count
        check(dupes == 400 && Rarity.allCases.map(g.shardCount).reduce(0, +) > 0, "duplicates from chests leave shards")

        // Event boss
        save(strength: 20)
        g = model(at: inEvent)
        g.startBossFight()
        let maxHP = g.season.bossMaxHP
        check(g.bossFight != nil && abs(maxHP - (g.weeklyPunch * Seasons.bossHits).rounded()) < 1, "the boss has \(Int(Seasons.bossHits)) of your punches of health")
        for _ in 0..<50 { g.punchBoss(); g.advance(by: 0.1) }
        let dealt = g.season.bossDamage
        g.finishBossFightEarly()
        check(dealt > 0 && g.bossResult != nil, "an attack deals damage")
        g = model(at: inEvent)
        check(g.season.bossDamage == dealt && g.bossTriesLeft == Seasons.bossFreeTriesPerDay - 1, "damage and tries are saved")
        var s = g.season; s.bossDamage = maxHP * 0.999
        var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
        dict["season"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(s))
        UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
        g = model(at: inEvent)
        g.startBossFight()
        for _ in 0..<20 { g.punchBoss(); g.advance(by: 0.1) }
        check(g.bossFight == nil && g.bossResult?.defeated == true && g.bossResult?.phases == [1, 2, 3], "the kill pays all three phases")
        check(g.owns(cosmetic: "title.frost") && g.owns(cosmetic: "fist.heart") && g.petLevel("owl") == 1, "Frostfall boss: title, Heartbreaker and the Snow Owl")
        g.startBossFight()
        check(g.bossFight == nil, "a defeated boss can't be fought again")
        g.adsAvailable = true
        check(!g.canWatch(.eventBoss), "and offers no ad")

        // Mini-mine
        save()
        g = model(at: inEvent)
        let first = g.miniBlocks
        check(first.count == 30 && first.allSatisfy { $0.material == .frostShard && $0.maxHP == Seasons.miniHP(depth: 1) }, "the mini-mine starts at level 1")
        // Taps are limited to 12 a second, so let time pass between them.
        for i in 0..<30 { while !(g.season.miniBlocks.indices.contains(i) && g.season.miniBlocks[i].isBroken) && g.season.miniDepth == 1 { g.punchMini(i); g.advance(by: 0.1) } }
        check(g.season.miniDepth == 2 && g.season.points == Seasons.miniClearPoints(depth: 1), "clearing a level moves on and fills the track")
        check(g.season.wallet >= 29, "every block pays wallet coins (\(g.season.wallet))")
        let pick = g.season.miniPick
        g.buyMiniPick()
        check(g.season.miniPick == pick + 1, "the wallet buys a better pick")
        var st = g.season; st.wallet = 10_000
        dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
        dict["season"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(st))
        UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
        g = model(at: inEvent)
        g.buyMiniHelper()
        let hpBefore = g.miniBlocks.map(\.hp).reduce(0, +)
        g.tickMini(5)
        check(g.season.miniHelpers == 1 && g.miniBlocks.map(\.hp).reduce(0, +) < hpBefore, "helpers dig on their own")

        // Shop
        let gold = Seasons.shop.first { $0.reward.cosmetics == ["burst.gold"] }!
        let wallet = g.season.wallet
        g.buy(gold)
        check(g.owns(cosmetic: "burst.gold") && g.season.wallet == wallet - gold.price && !g.canBuy(gold), "the shop sells Gold Rain once")
        g.buy(Seasons.shop[0])
        check(g.consumableCount(.snowball) == 1, "and consumables any number of times")

        // Boss fights use your strongest zone
        save(strength: 50)
        g = model(at: outside)
        check(g.weeklyZone == .quarry && g.weeklyStrengthLevel == 50, "the only zone is the strongest")

        // Everything saves
        save()
        g = model(at: outside)
        g.grant(Reward(consumables: [.magnet: 2], pets: ["cat"], cosmetics: ["title.champion"]))
        g.equipCosmetic("title.champion", kind: .title)
        g = model(at: outside)
        check(g.consumableCount(.magnet) == 2 && g.petLevel("cat") == 1 && g.equippedCosmetic(.title)?.id == "title.champion",
              "stash, pets and cosmetics survive a reload")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
