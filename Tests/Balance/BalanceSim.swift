import Foundation

// Headless balance simulation: a bot plays Pebble Quarry like an engaged active player and reports pacing
// against the design doc's targets. Run with Tests/run-balance-sim.sh [hours] [taps per second].
// MULTI=1: start fresh, open every zone as soon as it's affordable, and move to the next zone whenever one stalls.

let args = CommandLine.arguments
let hours = args.count > 1 ? Double(args[1]) ?? 12 : 12
let tapsPerSecond = args.count > 2 ? Double(args[2]) ?? 6 : 6
let dt = 1.0 / 20
let key = "punchmine.save.v1"

let simZone = ZoneID(rawValue: ProcessInfo.processInfo.environment["ZONE"] ?? "quarry") ?? .quarry
let multi = ProcessInfo.processInfo.environment["MULTI"] != nil
UserDefaults.standard.removeObject(forKey: key)
if simZone != .quarry {
    // Start with the zone already open, as if the player had just unlocked it.
    let seed = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "balance.analytics"))
    seed.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    dict["unlockedZones"] = ZoneID.allCases.map(\.rawValue)
    dict["activeZone"] = simZone.rawValue
    var recs = dict["records"] as! [String: Any]
    recs[simZone.rawValue] = ["seenIntro": true]
    // VETERAN=1: arrive the way a real player does, with the perk tree maxed and the Quarry Crown.
    if ProcessInfo.processInfo.environment["VETERAN"] != nil {
        dict["perks"] = Dictionary(uniqueKeysWithValues: Perk.allCases.map { ($0.rawValue, $0.maxLevel) })
        var quarry = recs["quarry"] as! [String: Any]
        quarry["heartsDefeated"] = 1; quarry["deepestHeart"] = 100
        recs["quarry"] = quarry
    }
    dict["records"] = recs
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
let g = GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "balance.analytics"))

var time = 0.0
func clock(_ t: Double) -> String {
    let s = Int(t)
    return s >= 3600 ? String(format: "%dh%02dm", s / 3600, s / 60 % 60) : String(format: "%dm%02ds", s / 60, s % 60)
}

// MARK: Milestones

var marks: [(String, Double, String)] = []
var seen: Set<String> = []
func mark(_ name: String, target: String = "") {
    guard seen.insert(name).inserted else { return }
    marks.append((name, time, target))
}

// MARK: Bot

/// Relative appeal of each upgrade; the bot buys the lowest cost × weight it can afford.
let weights: [UpgradeKind: Double] = [
    .strength: 1, .hireMiner: 0.8, .hireDriller: 0.8, .hireBlaster: 0.8, .training: 1, .critChance: 1.6,
    .critDamage: 1.8, .speed: 2.5, .focus: 2, .rhythm: 2.5, .shiftPace: 1.5, .feverStamina: 4, .contracts: 2.5,
    .deepPockets: 2, .overcharge: 4, .treasureHunter: 3, .lockpick: 4,
]

func target() -> Int? {
    let open = g.run.blocks.filter { !$0.isBroken && $0.material != .heartPart }
    if g.run.treasureCollapse != nil, let t = open.first(where: { $0.isTreasure }) { return t.id }
    let normal = open.filter { !$0.isTreasure }
    return (normal.isEmpty ? open : normal).min { $0.hp < $1.hp }?.id
}

func shop() {
    // Saving for a zone that's ready to open: keep this zone's share of the price.
    // Only on a mature run: saving right after a prestige would stall it.
    let saving = ZoneID.allCases.first { multi && !g.isUnlocked($0) && g.unlockAreaMet($0) && g.run.area >= max(30, g.record.bestArea - 15) }
    let reserve = saving.flatMap { z in g.unlockCosts(z).first { $0.zone == g.zone }?.amount } ?? 0
    let spendable = g.run.coins - reserve
    let tools = g.zone.tools
    if let next = tools.first(where: { g.toolState($0) != .owned }), g.toolState(next) == .affordable, g.toolCost(next) <= spendable {
        g.buyTool(next)
    }
    // Save up for the next tool once it's reachable.
    let reachable = tools.first { g.toolState($0) == .tooExpensive }
    let budget = min(reachable.map { g.toolCost($0) * 0.35 } ?? .infinity, g.run.coins - reserve)
    for gadget in [Gadget.dynamite, .horn] where g.gadgetState(gadget) == .affordable && gadget.cost <= min(budget, g.run.coins - reserve) {
        g.buyGadget(gadget)
    }
    for _ in 0..<20 {
        let options = UpgradeKind.allCases.filter { g.isUnlocked($0) && !g.isMaxed($0) }
        guard let pick = options.min(by: { g.cost($0) * weights[$0, default: 3] < g.cost($1) * weights[$1, default: 3] }),
              g.canBuy(pick), g.cost(pick) <= min(budget, g.run.coins - reserve) else { break }
        g.buy(pick)
    }
}

func gear() {
    for tier in ChestTier.allCases { while g.chestCount(tier) > 0 { g.openChest(tier) } }
    for slot in ItemSlot.allCases {
        let owned = ItemDef.all.filter { $0.slot == slot && g.itemLevel($0.id) > 0 }
        if let best = owned.max(by: { ($0.rarity.rawValue, g.itemLevel($0.id)) < ($1.rarity.rawValue, g.itemLevel($1.id)) }) {
            g.equip(best.id)
            while g.canUpgradeItem(best.id) { g.upgradeItem(best.id) }
        }
    }
}

func gadgets() {
    if g.canUseGadget(.horn) { g.useGadget(.horn) }
    if g.canUseGadget(.dynamite), let tough = g.run.blocks.filter({ !$0.isBroken }).max(by: { $0.hp < $1.hp }) {
        g.useGadget(.dynamite)
        g.beginPress(at: tough.id)
        g.endPress()
    }
}

func spendPerks() {
    var bought = true
    while bought {
        bought = false
        let options = Perk.allCases.filter { g.perkState($0) == .affordable }
        if let pick = options.min(by: { $0.cost(level: g.level($0)) < $1.cost(level: g.level($1)) }) {
            g.buyPerk(pick)
            bought = true
        } else if Perk.allCases.allSatisfy({ g.level($0) >= $0.maxLevel }) {
            // Tree done: one-time Ascension perks first, then the cheapest Star perk.
            if let once = AscensionPerk.allCases.first(where: { g.ascensionState($0) == .affordable }) {
                g.buyAscension(once); bought = true
            } else if let star = StarPerk.allCases.filter({ g.starState($0) == .affordable })
                        .min(by: { $0.cost(level: g.starLevel($0)) < $1.cost(level: g.starLevel($1)) }) {
                g.buyStar(star); bought = true
            }
        }
    }
}

// MARK: Run

struct RunLog { let number: Int; let start: Double; let end: Double; let area: Int; let pc: Int }
var runs: [RunLog] = []
var runStart = 0.0
var bestArea = 1
var lastProgress = 0.0
var runAreaHigh = 0
var reachTimes: [Int: Double] = [:]
var tapDebt = 0.0
var tipLog: [(Tip, Double)] = []
var nextShop = 0.0

let limit = hours * 3600
while time < limit {
    // Punch at the bot's tap rate (the game caps taps at 12/s).
    tapDebt += tapsPerSecond * dt
    while tapDebt >= 1 {
        tapDebt -= 1
        if let t = target() { g.tap(t) }
    }
    g.advance(by: dt)
    time += dt
    if let tip = g.activeTip, tipLog.last?.0 != tip { tipLog.append((tip, time)) }

    if time >= nextShop {
        nextShop = time + 0.5
        shop()
        gear()
        gadgets()
        if simZone == .quarry, g.canUnlock(.caverns) {
            mark("Zone 2 affordable", target: "30–40 min"); g.unlockZone(.caverns); g.zoneIntro = nil
            if multi { runAreaHigh = g.run.area; lastProgress = time } else { g.switchZone(to: .quarry) }
        }
        for z in [ZoneID.magma, .ruins] where multi && g.canUnlock(z) {
            mark("Zone \(z.number) affordable"); g.unlockZone(z); g.zoneIntro = nil
            runAreaHigh = g.run.area; lastProgress = time
        }
    }

    if g.run.levels.values.contains(where: { $0 > 0 }) { mark("First upgrade", target: "≤ 30 s") }
    if g.run.toolIndex >= 0 { mark("First tool", target: "≤ 3 min") }
    if g.minerCount(.digger) > 0 { mark("First miner", target: "3–6 min") }
    if g.run.area >= 10 { mark("Area 10", target: "≤ 6 min") }
    if g.canPrestige { mark("Prestige available") }

    if g.run.area > bestArea {
        bestArea = g.run.area
        if ProcessInfo.processInfo.environment["TRACE"] != nil && (bestArea % 5 == 0 || bestArea < 12) {
            let stone = Config.hp(g.zone.mix(area: bestArea)[0].0, area: bestArea, zone: g.zone)
            print(String(format: "  trace area %3d at %@  punch %.3g  stoneHP %.3g  hits %.1f  coins/s~%.3g  tool %d  str %d  miners %d/%d/%d train %d",
                         bestArea, clock(time) as NSString, g.punchDamage, stone, stone / max(g.punchDamage, 1e-9),
                         g.minerCoinsPerSecond(for: .quarry), g.run.toolIndex + 1, g.run.level(.strength),
                         g.minerCount(.digger), g.minerCount(.driller), g.minerCount(.blaster), g.run.level(.training)))
        }
        for milestone in [25, 50, 75, 100] where bestArea >= milestone && reachTimes[milestone] == nil {
            reachTimes[milestone] = time
        }
    }
    if g.run.area > runAreaHigh { runAreaHigh = g.run.area; lastProgress = time }
    if !multi, g.record(for: simZone).heartsDefeated > 0 { mark("Heart defeated (area 100)") }
    for z in ZoneID.allCases where multi && g.record(for: z).heartsDefeated > 0 { mark("\(z.name) Heart") }

    // Prestige when a run has stalled for 90 s, unless Perk Coins have nothing left to buy: then keep grinding.
    // With Ascension open there's always something to buy, so only a tree without Ascension counts as "maxed".
    let perksMaxed = Perk.allCases.allSatisfy { g.level($0) >= $0.maxLevel } && !g.ascensionUnlocked
    if multi && time - lastProgress > 90 {
        // Stalled: cash in this zone if it's worth it, then go dig somewhere else.
        // While saving for a zone, keep the coins: prestige would wipe them.
        let savingHere = ZoneID.allCases.contains { z in !g.isUnlocked(z) && g.unlockAreaMet(z) && g.unlockCosts(z).contains { $0.zone == g.zone } }
        if g.canPrestige && !perksMaxed && !savingHere {
            runs.append(RunLog(number: runs.count + 1, start: runStart, end: time, area: g.prestigeArea, pc: g.prestigeReward))
            if runs.count == 1 { mark("First prestige", target: "35–50 min") }
            g.prestige()
            spendPerks()
            runStart = time
        }
        let open = ZoneID.allCases.filter(g.isUnlocked)
        if open.count > 1 {
            g.switchZone(to: open[(open.firstIndex(of: g.zone)! + 1) % open.count])
            g.zoneIntro = nil
        }
        runAreaHigh = g.run.area
        lastProgress = time
    } else if !multi && g.canPrestige && !perksMaxed && time - lastProgress > 90 {
        let pc = g.prestigeReward
        runs.append(RunLog(number: runs.count + 1, start: runStart, end: time, area: g.prestigeArea, pc: pc))
        if runs.count == 1 { mark("First prestige", target: "35–50 min") }
        g.prestige()
        spendPerks()
        runStart = time
        runAreaHigh = 0
        lastProgress = time
    }
}

// MARK: Report

print("Balance sim: \(multi ? "all zones" : simZone.name), \(clock(limit)) of active play at \(tapsPerSecond) taps/s\n")
print("Milestone                    Time      Target")
for (name, t, target) in marks {
    print(name.padding(toLength: 28, withPad: " ", startingAt: 0), clock(t).padding(toLength: 9, withPad: " ", startingAt: 0), target)
}
print("\nTips shown")
print("  " + tipLog.map { "\($0.0.rawValue) \(clock($0.1))" }.joined(separator: " · "))
print("\nDeepest area reached")
for a in [25, 50, 75, 100] { print("  area \(a): \(reachTimes[a].map(clock) ?? "not reached")") }
print("\nPrestige runs")
print("  #   length    area    PC     total time")
for r in runs.prefix(12) + (runs.count > 12 ? [runs.last!] : []) {
    print(String(format: "  %-3d %-9@ %-7d %-6d %@", r.number, clock(r.end - r.start) as NSString, r.area, r.pc, clock(r.end) as NSString))
}
let spent = Perk.allCases.map { p in (0..<g.level(p)).map { p.cost(level: $0) }.reduce(0, +) }.reduce(0, +)
let total = Perk.allCases.map(\.totalCost).reduce(0, +)
print("\nAscension: " + StarPerk.allCases.map { "\($0.name) \(g.starLevel($0))" }.joined(separator: ", ")
      + " · " + AscensionPerk.allCases.filter(g.owns).map(\.name).joined(separator: ", "))
print("Perks: \(spent) of \(total) PC spent (\(Int(Double(spent) / Double(total) * 100))%), \(g.perkCoins) unspent")
print("Final run: area \(g.run.area), tool \(g.run.toolIndex + 1)/\(g.zone.tools.count), \(g.minerCount(.digger)) diggers, \(g.minerCount(.driller)) drillers, \(g.minerCount(.blaster)) blasters")
if multi {
    print("Zones: " + ZoneID.allCases.filter(g.isUnlocked).map { "\($0.name) best \(g.record(for: $0).bestArea), \(g.record(for: $0).prestigeCount) prestiges" }.joined(separator: " · "))
}
let found = Rarity.allCases.map { r in "\(g.items.keys.filter { ItemDef.find($0)?.rarity == r }.count) \(r.name)" }
print("Items: \(g.items.count) of \(ItemDef.all.count) found (\(found.joined(separator: ", "))), \(g.stats.chestsOpened) chests opened")
print("Miner share of damage in the current area: \(Int(g.minerDamageShare * 100))%")
UserDefaults.standard.removeObject(forKey: key)
