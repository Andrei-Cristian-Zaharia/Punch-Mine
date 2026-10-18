import Foundation
import Combine

struct Floater: Identifiable {
    enum Kind { case hit, crit, weak, miner, coins, chain }
    let id = UUID()
    let blockIndex: Int
    let text: String
    let kind: Kind
    let born: Double
    let jitter: Double
}

/// Moments the UI turns into sound, screen shake and debris. Purely presentational: game state never reads them.
enum GameEvent {
    case punch(index: Int, crit: Bool, weak: Bool, titan: Bool)
    case minerHit(index: Int)
    case blockBreak(index: Int, ore: Ore, treasure: Bool, lucky: Bool)
    case chain, zap, boom(index: Int), erupt
    case areaClear, fever, heartDefeated
    /// Sunken Ruins: high tide comes in (true) or goes out (false).
    case tide(rising: Bool)
    case rune(index: Int)
    case chest(Rarity)
    case purchase
}

/// Where a miner is working, for the badge on the grid.
struct MinerMark: Equatable, Hashable {
    let index: Int
    let kind: MinerKind
}

struct AreaBanner: Equatable {
    let area: Int
    let bonus: Double
    let id: Int
}

struct Toast: Equatable, Identifiable {
    let id = UUID()
    let text: String
}

final class GameModel: ObservableObject {
    // Per-zone state
    @Published private(set) var runs: [String: ZoneRun]
    @Published private(set) var records: [String: ZoneRecord]
    @Published private(set) var activeZone: ZoneID
    @Published private(set) var unlockedZones: [ZoneID]

    // Account-level, survives prestige
    @Published private(set) var holdUnlocked: Bool
    @Published private(set) var perks: [String: Int] = [:]
    @Published private(set) var perkCoins = 0
    @Published var settings: Settings {
        didSet { if settings != oldValue { save() } }
    }

    // Transient presentation state
    @Published private(set) var floaters: [Floater] = []
    @Published private(set) var hitPulses: [Int: Int] = [:]
    @Published private(set) var punchCount = 0
    @Published private(set) var breakCount = 0
    @Published private(set) var feverRemaining: Double = 0 {
        didSet { if oldValue <= 0 && feverRemaining > 0 { emit(.fever); noteTipEvent(.fever) } }
    }
    /// Set by the UI to receive `GameEvent`s.
    var onEvent: ((GameEvent) -> Void)?
    private func emit(_ event: GameEvent) { onEvent?(event) }
    @Published private(set) var banner: AreaBanner?
    @Published private(set) var minerTargets: [MinerMark] = []
    /// Consecutive punches on the same block, for the Focus upgrade.
    @Published private(set) var focusStacks = 0
    @Published private(set) var toast: Toast?
    @Published var offlineReport: OfflineReport?
    /// A zone being entered for the first time, so the UI can explain its currency.
    @Published var zoneIntro: ZoneID?

    // Rewarded ads
    /// Set by the UI once it knows whether an ad provider can show ads.
    @Published var adsAvailable = false
    /// Set by the UI once an interstitial provider is ready.
    @Published var breakAdsAvailable = false
    /// Goes up by one each time the game asks for an interstitial; the UI shows one.
    @Published private(set) var breakAdRequest = 0
    /// Play time (`stats.playSeconds`) at the last ad of any kind, or at launch.
    private var lastAdPlaySeconds = 0.0
    @Published private(set) var coinRushRemaining: Double = 0
    @Published private(set) var treasureOffer: TreasureOffer?
    @Published private(set) var adLedger = AdLedger()
    /// True while an ad is on screen; the game clock stops.
    @Published private(set) var isPaused = false
    private var pendingTreasureCoins: Double = 0

    // Gadgets
    /// Seconds left before each gadget can be used again.
    @Published private(set) var gadgetCooldowns: [Gadget: Double] = [:]
    /// Dynamite waiting for the player to pick a block.
    @Published private(set) var armedGadget: Gadget?
    private var toolPunches = 0

    // Items (account-wide, survive prestige)
    @Published private(set) var items: [String: Int] = [:]
    @Published private(set) var equipped: [String: String] = [:]
    @Published private(set) var chests: [String: Int] = [:]
    @Published private(set) var scrap = 0
    @Published var chestReveal: ChestReveal?
    /// Bad-luck protection counters (see `ItemRules.epicPity`).
    @Published private(set) var chestsSinceEpic = 0
    @Published private(set) var chestsSinceLegendary = 0
    /// Lifetime totals for the Stats screen.
    @Published private(set) var stats = LifetimeStats()
    @Published private(set) var daily = DailyState()
    @Published var dailyReveal: DailyReward?
    /// Item id → its bonus stat.
    @Published private(set) var affixes: [String: Affix] = [:]
    // Ascension (see Ascension.swift)
    @Published private(set) var stars: [String: Int] = [:]
    @Published private(set) var ascended: Set<String> = []
    // Store (see Store.swift)
    /// One-time products the player owns.
    @Published private(set) var ownedProducts: Set<String> = []
    /// App Store transactions already credited, so none pays out twice.
    private var processedTransactions: Set<String> = []
    private var effectPunches = 0
    private var rhythmCounter = 0
    private var titanCounter = 0

    // Heart of the Quarry
    @Published var conquest: ConquestEvent?

    // Sunken Ruins
    /// 0 → 1 as the next high tide approaches; 0 while the tide is in.
    @Published private(set) var tideCharge: Double = 0
    /// Seconds of high tide left; 0 while the tide is out.
    @Published private(set) var tideRemaining: Double = 0
    private var tideTimer: Double = 0
    var highTide: Bool { zone == .ruins && tideRemaining > 0 }

    // Magma Depths
    /// 0 → 1 as the next vent eruption approaches.
    @Published private(set) var ventCharge: Double = 0
    private var ventTimer: Double = 0
    /// Clock time after which a block may start regrowing.
    private var regrowAfter: [Int: Double] = [:]
    /// Highest HP fraction a block may regrow to: the top of the crack stage it was in.
    private var regrowCap: [Int: Double] = [:]

    private var seeds: [String: UInt64]
    private(set) var clock: Double = 0

    // Tips (see Tips.swift)
    @Published var activeTip: Tip?
    var seenTips: Set<String> = []
    var pendingTipEvents: Set<Tip> = []
    var tipShownAt = 0.0
    var lastTipEnded = -100.0
    private var sinceTipCheck = 0.0
    private var areaGeneration = 0
    private var recentPunches: [Double] = []
    private var recentTaps: [Double] = []
    private var pressIndex: Int?
    private var pressStart: Double = 0
    private var holdAccumulator: Double = 0
    private var autoTarget: Int?
    private var minerTimers: [MinerKind: [Double]] = [:]
    /// The block Focus stacks are building on.
    @Published private(set) var focusIndex: Int?
    private var sinceSave: Double = 0
    private var loop: Task<Void, Never>?
    private var lastActive: Date?
    private var playerDamage: Double = 0
    private var minerDamage: Double = 0
    /// Share of this area's damage dealt by miners so far.
    var minerDamageShare: Double { playerDamage + minerDamage > 0 ? minerDamage / (playerDamage + minerDamage) : 0 }
    let analytics: Analytics

    private static let saveKey = "punchmine.save.v1"

    init(analytics: Analytics = .makeDefault()) {
        self.analytics = analytics
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let save = try? JSONDecoder().decode(SaveData.self, from: data) {
            runs = save.runs
            records = save.records
            seeds = save.seeds
            activeZone = save.activeZone
            unlockedZones = save.unlockedZones
            holdUnlocked = save.holdUnlocked
            settings = save.settings
            perks = save.perks
            perkCoins = save.perkCoins
            lastActive = save.lastActive
            coinRushRemaining = save.coinRushRemaining
            adLedger = save.adLedger
            // Before Hearts were per zone, the save held Pebble Quarry's Heart record at the top level.
            if save.heartsDefeated > 0, var quarry = records[ZoneID.quarry.rawValue], quarry.heartsDefeated == 0 {
                quarry.heartsDefeated = save.heartsDefeated
                quarry.deepestHeart = save.deepestHeart
                records[ZoneID.quarry.rawValue] = quarry
            }
            items = save.items
            equipped = save.equipped
            chests = save.chests
            scrap = save.scrap
            chestsSinceEpic = save.chestsSinceEpic
            chestsSinceLegendary = save.chestsSinceLegendary
            stats = save.stats ?? LifetimeStats(legacyFrom: save)
            daily = save.daily
            affixes = save.affixes ?? [:]
            // Items found before affixes existed get one now.
            if save.affixes == nil {
                for id in save.items.keys {
                    if let def = ItemDef.find(id) { affixes[id] = def.heartZone != nil ? Affixes.relicAffix(def) : Affixes.roll(for: def) }
                }
            }
            stars = save.stars
            ascended = Set(save.ascended)
            ownedProducts = Set(save.ownedProducts)
            processedTransactions = Set(save.processedTransactions)
            // Saves from before tips existed: a player who is already past the basics doesn't need them.
            if let tips = save.seenTips {
                seenTips = Set(tips)
            } else if (save.records[ZoneID.quarry.rawValue]?.bestArea ?? 1) >= 20 {
                seenTips = Set(Tip.allCases.map(\.rawValue))
            }
        } else {
            var record = ZoneRecord()
            record.seenIntro = true
            runs = [ZoneID.quarry.rawValue: ZoneRun()]
            records = [ZoneID.quarry.rawValue: record]
            seeds = [ZoneID.quarry.rawValue: UInt64.random(in: 1...UInt64.max)]
            activeZone = .quarry
            unlockedZones = [.quarry]
            holdUnlocked = false
            settings = Settings()
        }
        if runs[activeZone.rawValue] == nil { runs[activeZone.rawValue] = ZoneRun() }
        if seeds[activeZone.rawValue] == nil { seeds[activeZone.rawValue] = UInt64.random(in: 1...UInt64.max) }
        if run.blocks.isEmpty { run.blocks = newBlocks(area: run.area) }
        lastAdPlaySeconds = stats.playSeconds
        // Saves from before Heart relics: hand over the relic of every Heart already defeated.
        for zone in ZoneID.allCases where hasCrown(zone) { grantRelic(for: zone) }
    }

    // MARK: - Active zone access

    var zone: ZoneID { activeZone }

    private(set) var run: ZoneRun {
        get { runs[activeZone.rawValue] ?? ZoneRun() }
        set { runs[activeZone.rawValue] = newValue }
    }

    private(set) var record: ZoneRecord {
        get { records[activeZone.rawValue] ?? ZoneRecord() }
        set { records[activeZone.rawValue] = newValue }
    }

    func run(for zone: ZoneID) -> ZoneRun? { runs[zone.rawValue] }
    func record(for zone: ZoneID) -> ZoneRecord { records[zone.rawValue] ?? ZoneRecord() }
    func isUnlocked(_ zone: ZoneID) -> Bool { unlockedZones.contains(zone) }

    var bestArea: Int { record.bestArea }
    var tool: Tool { tool(for: zone, run: run) }

    private func tool(for zone: ZoneID, run: ZoneRun) -> Tool {
        zone.tools.indices.contains(run.toolIndex) ? zone.tools[run.toolIndex] : Config.bareFists
    }

    // MARK: - Loop

    func start() {
        guard loop == nil else { return }
        analytics.sessionStarted()
        collectOfflineReport()
        loop = Task { [weak self] in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                let now = ContinuousClock.now
                let elapsed = now - last
                let dt = min(Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18, 0.25)
                last = now
                self?.tick(dt)
            }
        }
    }

    func stop() {
        if loop != nil { analytics.sessionEnded() }
        loop?.cancel()
        loop = nil
        save()
    }

    /// Steps the game without the real-time loop, for headless balance simulations and tests.
    func advance(by dt: Double) { tick(dt) }

    private func tick(_ dt: Double) {
        guard !isPaused else { return }
        clock += dt
        if coinRushRemaining > 0 { coinRushRemaining = max(0, coinRushRemaining - dt) }
        if !gadgetCooldowns.isEmpty {
            var next = gadgetCooldowns
            for (g, left) in next { next[g] = left - dt > 0 ? left - dt : nil }
            gadgetCooldowns = next
        }
        if let offer = treasureOffer, clock > offer.expires { treasureOffer = nil }
        analytics.addPlayTime(dt)
        run.playSeconds += dt
        stats.playSeconds += dt
        run.areaSeconds += dt

        // Fever meter and timer
        recentPunches.removeAll { clock - $0 > Config.feverWindow }
        if feverRemaining > 0 { feverRemaining = max(0, feverRemaining - dt) }

        // Hold-to-punch and tap-to-auto-punch
        if let target = activeRepeatTarget {
            holdAccumulator += dt
            let interval = 1 / holdRate
            while holdAccumulator >= interval {
                holdAccumulator -= interval
                punch(target)
                if !run.blocks.indices.contains(target) || run.blocks[target].isBroken {
                    if autoTarget == target { autoTarget = nil }
                    break
                }
            }
        } else {
            holdAccumulator = 0
        }

        tickMiners(dt)
        sinceTipCheck += dt
        if sinceTipCheck >= 0.5 { sinceTipCheck = 0; updateTips(); checkAutoPrestige() }
        if zone == .magma { tickMagma(dt) }
        if zone == .ruins { tickTide(dt) }

        if let remaining = run.treasureCollapse {
            let next = remaining - dt
            if next <= 0 {
                analytics.log("treasure_lost", ["zone": .string(zone.rawValue), "area": .int(run.area)])
                clearArea()
            } else {
                run.treasureCollapse = next
            }
        }

        if floaters.contains(where: { clock - $0.born > 0.9 }) {
            floaters.removeAll { clock - $0.born > 0.9 }
        }

        sinceSave += dt
        if sinceSave >= Config.autosaveInterval { save() }
    }

    private var activeRepeatTarget: Int? {
        if let auto = autoTarget, run.blocks.indices.contains(auto), !run.blocks[auto].isBroken { return auto }
        if holdUnlocked, let held = pressIndex, clock - pressStart >= Config.holdDelay { return held }
        return nil
    }

    // MARK: - Input

    func beginPress(at index: Int?) {
        pressIndex = index
        pressStart = clock
        holdAccumulator = 0
        guard let index else { return }
        if armedGadget == .dynamite {
            detonate(at: redirectToHeart(index))
            pressIndex = nil
            return
        }
        tap(index)
        if settings.tapToAutoPunch { autoTarget = index }
    }

    func movePress(to index: Int?) {
        guard index != pressIndex else { return }
        pressIndex = index
    }

    func endPress() {
        pressIndex = nil
    }

    /// A single tap, limited to 12 per second.
    func tap(_ index: Int) {
        recentTaps.removeAll { clock - $0 > 1 }
        guard recentTaps.count < Config.tapCapPerSecond else { return }
        recentTaps.append(clock)
        punch(index)
    }

    // MARK: - Derived stats

    var strengthDamage: Double { Config.strength(level: run.level(.strength)) * (1 + itemBonus(.strengthBonus)) }
    var punchDamage: Double {
        strengthDamage * tool.damage * perkDamageMultiplier * (1 + itemBonus(.punchDamage)) * starMultiplier(.fists)
            * (feverActive ? feverMultiplier : 1)
    }
    /// ×2 by default; Overcharge and Crown of Embers raise it.
    var feverMultiplier: Double {
        Config.feverMultiplier + Config.overchargePerLevel * Double(run.level(.overcharge)) + itemBonus(.feverMultiplier)
            + (owns(.secondWind) ? 1 : 0)
    }
    var perkDamageMultiplier: Double {
        1 + 0.10 * Double(level(.heavyFists)) + (zone == .quarry ? 0.25 * Double(level(.quarryBrawler)) : 0)
    }
    var critChance: Double {
        min(ItemRules.critCap, Config.critChance(level: run.level(.critChance)) + 0.01 * Double(level(.keenEye))
            + tool.critBonus + itemBonus(.critChance))
    }
    var focusMaxStacks: Int { Config.focusStacksPerLevel * run.level(.focus) + Int(itemBonus(.focus)) }
    var focusMultiplier: Double { 1 + Config.focusPerStack * Double(focusStacks) }
    var feverDuration: Double {
        Config.feverDuration + Config.feverSecondsPerLevel * Double(run.level(.feverStamina)) + itemBonus(.feverDuration)
    }
    var clearBonusShare: Double { clearBonusShare(for: run) }
    func clearBonusShare(for run: ZoneRun) -> Double {
        Config.clearBonusShare + Config.contractsPerLevel * Double(run.level(.contracts)) + itemBonus(.clearBonus)
    }
    /// Shift Pace shortens every miner's swing.
    func minerInterval(_ kind: MinerKind, run: ZoneRun) -> Double {
        kind.interval * (1 - min(ItemRules.minerSpeedCap,
                                 Config.shiftPacePerLevel * Double(run.level(.shiftPace)) + itemBonus(.minerSpeed)
                                    + 0.10 * Double(level(.doubleShift))))
    }
    func minerCount(_ kind: MinerKind) -> Int { run.level(kind.hire) }
    var penetration: Double {
        min(Config.penetrationCap, tool.penetration + 0.03 * Double(level(.piercer)) + itemBonus(.penetration))
    }
    var treasureChance: Double {
        Config.treasureChance + 0.03 * Double(level(.prospector))
            + Config.treasureHunterPerLevel * Double(run.level(.treasureHunter)) + itemBonus(.treasureChance)
    }
    var critMultiplier: Double {
        Config.critMultiplier(level: run.level(.critDamage)) + itemBonus(.critDamage) + 0.2 * Double(level(.brutalCrits))
    }
    var holdRate: Double { Config.holdRate(speedLevel: run.level(.speed)) + itemBonus(.holdRate) }
    var luckyChance: Double { tool.lucky + itemBonus(.lucky) }
    /// Every Nth punch is a guaranteed crit; 0 when Rhythm is not bought.
    var rhythmEvery: Int { run.level(.rhythm) > 0 ? Config.rhythmBase - run.level(.rhythm) : 0 }
    /// Deep Pockets and Coin Pouch.
    func coinMultiplier(for run: ZoneRun) -> Double {
        (1 + Config.deepPocketsPerLevel * Double(run.level(.deepPockets)) + itemBonus(.coins)) * starMultiplier(.fortune)
    }
    var minerCount: Int { MinerKind.allCases.map { run.level($0.hire) }.reduce(0, +) }
    var minerHit: Double { minerHit(for: run, in: zone) }
    var chainShare: Double {
        Chain.share + tool.chainBonus + (zone == .caverns ? 0.08 * Double(level(.resonantKnuckles)) : 0)
    }
    var feverActive: Bool { feverRemaining > 0 }
    var feverCharge: Int { min(recentPunches.count, Config.feverPunches) }
    var blocksLeft: Int { run.blocks.filter { !$0.isBroken && !$0.isTreasure }.count }

    /// Your punch before Fever, Focus and crits, for a given run (miners and offline income use it).
    private func basePunch(for run: ZoneRun, in target: ZoneID) -> Double {
        let quarryBonus = target == .quarry ? 0.25 * Double(level(.quarryBrawler)) : 0
        return Config.strength(level: run.level(.strength)) * (1 + itemBonus(.strengthBonus)) * tool(for: target, run: run).damage
            * (1 + 0.10 * Double(level(.heavyFists)) + quarryBonus) * (1 + itemBonus(.punchDamage)) * starMultiplier(.fists)
    }

    /// A miner hit scales with your punch: 30% + 3% per Training level, never below the old flat
    /// 5 + 3 × Training. Foreman and Miner's Helmet multiply it.
    private func minerHit(for run: ZoneRun, in target: ZoneID) -> Double {
        let training = run.level(.training)
        let share = Config.minerPunchShare + Config.minerPunchSharePerTraining * Double(training)
        let hit = max(Config.minerHit(trainingLevel: training), basePunch(for: run, in: target) * share)
        return hit * (1 + 0.15 * Double(level(.foreman)) + itemBonus(.minerDamage)) * starMultiplier(.crew)
    }
    var minerPunchShare: Double { Config.minerPunchShare + Config.minerPunchSharePerTraining * Double(run.level(.training)) }

    // MARK: - Punching

    func punch(_ index: Int) {
        let index = redirectToHeart(index)
        guard run.blocks.indices.contains(index), !run.blocks[index].isBroken else { return }

        if focusIndex == index {
            if focusStacks < focusMaxStacks { focusStacks += 1 }
        } else {
            focusIndex = index
            if focusStacks != 0 { focusStacks = 0 }
        }

        var raw = punchDamage * focusMultiplier
        var isCrit = Double.random(in: 0..<1) < critChance
        if rhythmEvery > 0 {
            rhythmCounter += 1
            if rhythmCounter >= rhythmEvery { rhythmCounter = 0; isCrit = true }
        }
        if isCrit { raw *= critMultiplier; stats.crits += 1 }
        stats.punches += 1
        // Titan Punch: every 20th punch hits ×10 and ignores armor.
        var titan = false
        if level(.titanPunch) > 0 {
            titanCounter += 1
            if titanCounter >= 20 { titanCounter = 0; titan = true; raw *= 10 }
        }

        let currentTool = tool
        let block = run.blocks[index]
        // Titan Punch skips armor entirely (the normal penetration cap is 90%).
        let hit = titan ? raw : Config.hitDamage(raw: raw, armor: block.armor, penetration: penetration)
        let weak = hit <= raw * Config.damageFloor + 0.0001 && block.armor > 0
        let generation = areaGeneration
        let shown = hit * tideFactor(at: index)
        addFloater(index, text: titan ? "TITAN " + NumberText.hit(shown) : (weak ? "DEFLECT" : NumberText.hit(shown)),
                   kind: isCrit || titan ? .crit : (weak ? .weak : .hit))
        emit(.punch(index: index, crit: isCrit, weak: weak, titan: titan))
        if weak { noteTipEvent(.armor) }
        applyDamage(hit, to: index)
        let freeze = max(currentTool.freezeSeconds, itemBonus(.freeze))
        if freeze > 0, generation == areaGeneration {
            regrowAfter[index] = max(regrowAfter[index] ?? 0, clock + freeze)
        }

        // Splash only lands on this area, never on the next one if the hit cleared it.
        if currentTool.splash > 0 && generation == areaGeneration {
            for neighbor in neighbors(of: index) where generation == areaGeneration && !run.blocks[neighbor].isBroken {
                let splash = Config.hitDamage(raw: raw * currentTool.splash, armor: run.blocks[neighbor].armor,
                                              penetration: penetration)
                applyDamage(splash, to: neighbor)
            }
        }

        // Pierce: the block directly below takes part of the punch.
        if currentTool.pierce > 0, generation == areaGeneration, index + Config.columns < run.blocks.count {
            let below = redirectToHeart(index + Config.columns)
            if !run.blocks[below].isBroken && below != index {
                let pierce = Config.hitDamage(raw: raw * currentTool.pierce, armor: run.blocks[below].armor, penetration: penetration)
                applyDamage(pierce, to: below)
            }
        }

        // Lightning: every Nth punch zaps random blocks for a full punch.
        if currentTool.lightningEvery > 0 {
            toolPunches += 1
            if toolPunches >= currentTool.lightningEvery && generation == areaGeneration {
                toolPunches = 0
                zap(count: currentTool.lightningTargets, raw: raw)
            }
        }

        if generation == areaGeneration { applyItemPunchEffects(at: index, raw: raw) }

        punchCount += 1
        if generation == areaGeneration {
            hitPulses[index, default: 0] += 1
            run.areaPunches += 1
        }
        recentPunches.append(clock)
        if !feverActive && recentPunches.count >= Config.feverPunches {
            feverRemaining = feverDuration
            recentPunches.removeAll()
            analytics.log("fever", ["zone": .string(zone.rawValue), "area": .int(run.area)])
        }
    }

    /// High tide in Sunken Ruins, after armor: hits ×0.75, except on the Heart, which takes ×2.
    func tideFactor(at index: Int) -> Double {
        guard highTide else { return 1 }
        return index == Conquest.heartIndex && heartBlock != nil ? Tide.heartFactor : Tide.damageFactor
    }

    /// `tide: false` for damage the tide doesn't touch (runestone pulses).
    private func applyDamage(_ amount: Double, to index: Int, chainStep: Int = 0, byMiner: Bool = false, tide: Bool = true) {
        guard run.blocks.indices.contains(index), !run.blocks[index].isBroken else { return }
        let amount = tide ? amount * tideFactor(at: index) : amount
        let dealt = min(amount, run.blocks[index].hp)
        if byMiner { minerDamage += dealt } else { playerDamage += dealt }
        if byMiner && zone == .magma && level(.coldCrew) > 0 {
            regrowAfter[index] = max(regrowAfter[index] ?? 0, clock + 3)
        }
        run.blocks[index].hp -= amount
        if zone == .magma && !run.blocks[index].isBroken {
            let block = run.blocks[index]
            regrowAfter[index] = max(regrowAfter[index] ?? 0, clock + Magma.regrowDelay)
            regrowCap[index] = min(1, (block.hpFraction * 4).rounded(.up) / 4)
        }
        if run.blocks[index].isBroken { handleBreak(index, chainStep: chainStep) }
    }

    private func handleBreak(_ index: Int, chainStep: Int) {
        let block = run.blocks[index]
        let generation = areaGeneration
        run.blocks[index].hp = 0
        let lucky = luckyChance > 0 && Double.random(in: 0..<1) < luckyChance
        var payout = lucky ? block.reward * 2 : block.reward
        if highTide { payout *= Tide.rewardFactor }
        if block.isTreasure {
            payout *= 1 + itemBonus(.treasureReward) + 0.2 * Double(level(.luckyHaul))
                + (zone == .caverns && level(.geodeSense) > 0 ? 0.5 : 0)
        }
        earn(payout)
        addFloater(index, text: (lucky ? "LUCKY +" : "+") + NumberText.format(boosted(payout), short: settings.shortNumbers), kind: .coins)
        breakCount += 1
        stats.blocksBroken += 1
        if block.isTreasure { stats.treasuresBroken += 1 }
        emit(.blockBreak(index: index, ore: block.material, treasure: block.isTreasure, lucky: lucky))
        analytics.milestone(.firstBlockBreak)
        if block.material.feverFuel > 0 { addFever(block.material.feverFuel, at: index) }
        if block.material == .heart { defeatHeart() }
        if block.isTreasure {
            analytics.log("treasure_broken", ["zone": .string(zone.rawValue), "area": .int(run.area), "reward": .double(block.reward)])
            if Double.random(in: 0..<1) < ItemRules.treasureChestChance {
                awardChest(Double.random(in: 0..<1) < ItemRules.treasureIronChance ? .iron : .wooden, reason: "treasure")
                // Lockpick and Chest Hunter can add a second chest to a drop, never one from nothing.
                if Double.random(in: 0..<1) < Config.lockpickPerLevel * Double(run.level(.lockpick)) + 0.05 * Double(level(.chestHunter)) {
                    awardChest(.wooden, reason: "lockpick")
                }
            }
            if canWatch(.treasureDouble, ignoringOffer: true) {
                treasureOffer = TreasureOffer(coins: boosted(block.reward), expires: clock + AdRules.treasureOfferSeconds)
            }
        }

        if block.material == .runestone {
            runePulse(from: index)
            guard generation == areaGeneration else { return }
        }

        if block.material.isCrystal && chainStep < Chain.maxSteps {
            chainBreak(from: index, material: block.material, maxHP: block.maxHP, step: chainStep + 1)
            guard generation == areaGeneration else { return }
        }

        if block.isTreasure, run.treasureCollapse != nil {
            clearArea()
            return
        }
        if blocksLeft == 0 {
            let treasureLeft = run.blocks.contains { $0.isTreasure && !$0.isBroken }
            if treasureLeft {
                if run.treasureCollapse == nil { run.treasureCollapse = Config.treasureCollapseSeconds }
            } else {
                clearArea()
            }
        }
    }

    /// A broken crystal hits each touching crystal of the same type: 40% of its max HP, then 16%, then 6.4%.
    private func chainBreak(from index: Int, material: Ore, maxHP: Double, step: Int) {
        let generation = areaGeneration
        let damage = maxHP * pow(chainShare, Double(step))
        if step == 1 { emit(.chain) }
        var hitHeart = false
        for neighbor in neighbors(of: index) {
            guard generation == areaGeneration else { return }
            // Heart of the Caverns: a chain that touches the Heart hits it too, once per broken crystal.
            if zone == .caverns, !hitHeart, Conquest.heartCells.contains(neighbor), let heart = heartBlock, !heart.isBroken {
                hitHeart = true
                let hit = Config.hitDamage(raw: damage, armor: heart.armor, penetration: penetration)
                addFloater(Conquest.heartIndex, text: "CHAIN " + NumberText.hit(hit), kind: .chain)
                hitPulses[Conquest.heartIndex, default: 0] += 1
                applyDamage(hit, to: Conquest.heartIndex, chainStep: Chain.maxSteps)
                continue
            }
            let target = run.blocks[neighbor]
            guard !target.isBroken, target.material == material else { continue }
            let hit = Config.hitDamage(raw: damage, armor: target.armor, penetration: penetration)
            addFloater(neighbor, text: "CHAIN " + NumberText.hit(hit), kind: .chain)
            applyDamage(hit, to: neighbor, chainStep: step)
        }
    }

    private func clearArea() {
        logAreaCleared()
        stats.areasCleared += 1
        emit(.areaClear)
        run.maxCleared = max(run.maxCleared, run.area)
        if run.area > record.bestCleared {
            if run.area % ItemRules.ironChestEvery == 0 { awardChest(.iron, reason: "record_area") }
            if zone == .quarry && run.area == ItemRules.starterChestArea { awardChest(.wooden, reason: "starter") }
        }
        record.bestCleared = max(record.bestCleared, run.area)
        let bonus = (run.blocks.filter { !$0.isTreasure }.map(\.reward).reduce(0, +) * clearBonusShare).rounded()
        earn(bonus)
        banner = AreaBanner(area: run.area, bonus: bonus, id: (banner?.id ?? 0) + 1)

        if run.area < maxArea(for: zone) { run.area += 1 }
        record.bestArea = max(record.bestArea, run.area)
        if run.area >= Config.holdUnlockArea { holdUnlocked = true }
        run.treasureCollapse = nil
        run.blocks = newBlocks(area: run.area, salt: UInt64(clock * 1000))
        areaGeneration += 1
        regrowAfter = [:]
        regrowCap = [:]
        autoTarget = nil
        hitPulses.removeAll()
        minerTargets = []
        checkProgressMilestones()
        save()
    }

    private func logAreaCleared() {
        let total = playerDamage + minerDamage
        analytics.log("area_cleared", [
            "zone": .string(zone.rawValue),
            "area": .int(run.area),
            "seconds": .double(run.areaSeconds),
            "punches": .int(run.areaPunches),
            "miner_share": .double(total > 0 ? minerDamage / total : 0),
            "run_seconds": .double(run.playSeconds),
        ])
        analytics.recordArea(zone: zone, area: run.area, seconds: run.areaSeconds)
        run.areaSeconds = 0
        run.areaPunches = 0
        playerDamage = 0
        minerDamage = 0
    }

    private func checkProgressMilestones() {
        if zone == .quarry && run.maxCleared >= 10 && !isUnlocked(.caverns) { analytics.milestone(.zone2Preview) }
        if canPrestige { analytics.milestone(.prestigeAvailable, ["zone": .string(zone.rawValue)]) }
        // How quickly a run after a prestige gets back to the depth the last run reached.
        if record.prestigeCount > 0, !run.returnLogged, record.lastPrestigeDepth > 0,
           run.maxCleared >= record.lastPrestigeDepth {
            run.returnLogged = true
            analytics.log("returned_to_depth", [
                "zone": .string(zone.rawValue),
                "depth": .int(record.lastPrestigeDepth),
                "run_seconds": .double(run.playSeconds),
                "previous_run_seconds": .double(record.lastRunSeconds),
                "ratio": .double(record.lastRunSeconds > 0 ? run.playSeconds / record.lastRunSeconds : 0),
            ])
        }
    }

    /// All zone coins pass through here; Coin Rush doubles them.
    private func earn(_ amount: Double) {
        let total = boosted(amount)
        run.coins += total
        run.lifetimeCoins += total
        stats.coins[zone.rawValue, default: 0] += total
    }

    private func earnUnboosted(_ amount: Double) {
        run.coins += amount
        run.lifetimeCoins += amount
        stats.coins[zone.rawValue, default: 0] += amount
    }

    private func boosted(_ amount: Double) -> Double {
        let crowned = amount * crownMultiplier * coinMultiplier(for: run)
        return coinRushRemaining > 0 ? crowned * AdRules.coinRushMultiplier : crowned
    }

    // MARK: - Tool effects and gadgets

    private func zap(count: Int, raw: Double) {
        let generation = areaGeneration
        var open = run.blocks.filter { !$0.isBroken && !$0.isTreasure && $0.material != .heartPart }.map(\.id)
        open.shuffle()
        if !open.isEmpty { emit(.zap) }
        for index in open.prefix(count) where generation == areaGeneration {
            let hit = Config.hitDamage(raw: raw, armor: run.blocks[index].armor, penetration: penetration)
            addFloater(index, text: "ZAP " + NumberText.hit(hit), kind: .crit)
            hitPulses[index, default: 0] += 1
            applyDamage(hit, to: index)
        }
    }

    func ownsGadget(_ g: Gadget) -> Bool { run.levels[g.levelKey, default: 0] > 0 }

    func gadgetState(_ g: Gadget) -> ToolState {
        if ownsGadget(g) { return .owned }
        if bestArea < g.unlockArea { return .locked }
        return run.coins >= g.cost ? .affordable : .tooExpensive
    }

    func buyGadget(_ g: Gadget) {
        guard gadgetState(g) == .affordable else { return }
        run.coins -= g.cost
        run.levels[g.levelKey] = 1
        emit(.purchase)
        analytics.log("gadget_bought", ["gadget": .string(g.rawValue), "zone": .string(zone.rawValue), "area": .int(run.area)])
    }

    func cooldownLeft(_ g: Gadget) -> Double { gadgetCooldowns[g] ?? 0 }

    func canUseGadget(_ g: Gadget) -> Bool {
        guard ownsGadget(g), cooldownLeft(g) <= 0, !isPaused else { return false }
        if g == .horn { return !feverActive }
        return true
    }

    /// Fever Horn fires at once; Dynamite arms and waits for a block tap (tap the gadget again to cancel).
    func useGadget(_ g: Gadget) {
        switch g {
        case .horn:
            guard canUseGadget(.horn) else { return }
            feverRemaining = feverDuration
            recentPunches.removeAll()
            gadgetCooldowns[.horn] = gadgetCooldown(.horn)
            analytics.log("gadget_used", ["gadget": .string(g.rawValue), "zone": .string(zone.rawValue)])
        case .dynamite:
            if armedGadget == .dynamite {
                armedGadget = nil
            } else if canUseGadget(.dynamite) {
                armedGadget = .dynamite
            }
        }
    }

    /// 3×3 blast for 8× the punch, armor applies; it can crack treasure too.
    private func detonate(at index: Int) {
        armedGadget = nil
        gadgetCooldowns[.dynamite] = gadgetCooldown(.dynamite)
        let raw = punchDamage * Gadget.dynamiteMultiplier
        let generation = areaGeneration
        addFloater(index, text: "BOOM", kind: .crit)
        emit(.boom(index: index))
        analytics.log("gadget_used", ["gadget": .string("dynamite"), "zone": .string(zone.rawValue), "area": .int(run.area)])
        punchCount += 1
        for cell in blastArea(around: index) where generation == areaGeneration {
            let target = redirectToHeart(cell)
            guard !run.blocks[target].isBroken else { continue }
            let hit = Config.hitDamage(raw: raw, armor: run.blocks[target].armor, penetration: penetration)
            hitPulses[target, default: 0] += 1
            applyDamage(hit, to: target)
        }
    }

    // MARK: - Items

    /// Sum of an effect over equipped items and active set bonuses.
    func itemBonus(_ effect: ItemEffect) -> Double {
        let fromItems = equipped.values.reduce(0) { total, id in
            guard let def = ItemDef.find(id), let level = items[id] else { return total }
            let own = def.effect == effect ? def.value(level: level) : 0
            let affix = affixes[id].map { $0.effect == effect ? $0.value : 0 } ?? 0
            return total + own + affix
        }
        return fromItems + activeSetBonuses.filter { $0.effect == effect }.map(\.value).reduce(0, +)
    }

    /// Equipped pieces of a set.
    func setPieces(_ set: ItemSet) -> Int {
        equipped.values.filter { ItemDef.find($0)?.set == set }.count
    }

    var activeSetBonuses: [(set: ItemSet, effect: ItemEffect, value: Double)] {
        ItemSet.allCases.flatMap { set in
            set.bonuses.filter { setPieces(set) >= $0.pieces }.map { (set, $0.effect, $0.value) }
        }
    }

    var chestLuck: Double {
        min(ItemRules.chestLuckCap, itemBonus(.chestLuck) + StarPerk.luck.perLevel * Double(starLevel(.luck)))
    }

    var offlineEfficiency: Double {
        min(0.75, Offline.baseEfficiency + itemBonus(.offlineEfficiency) + 0.05 * Double(level(.overtime)))
    }

    func gadgetCooldown(_ g: Gadget) -> Double {
        g.cooldown * (1 - min(ItemRules.gadgetCooldownCap, itemBonus(.gadgetCooldown) + 0.05 * Double(level(.gadgeteer))))
    }

    var chestCount: Int { chests.values.reduce(0, +) }
    func chestCount(_ tier: ChestTier) -> Int { chests[tier.rawValue, default: 0] }
    func itemLevel(_ id: String) -> Int { items[id, default: 0] }
    func equippedItem(_ slot: ItemSlot) -> ItemDef? { equipped[slot.rawValue].flatMap { ItemDef.find($0) } }

    private func awardChest(_ tier: ChestTier, reason: String) {
        chests[tier.rawValue, default: 0] += 1
        toast = Toast(text: "\(tier.name) found!")
        analytics.log("chest_earned", ["tier": .string(tier.rawValue), "reason": .string(reason)])
    }

    /// Opens one chest: a new item at level 1, or Scrap for a duplicate.
    func openChest(_ tier: ChestTier) {
        guard chestCount(tier) > 0 else { return }
        chests[tier.rawValue, default: 0] -= 1
        var rarity = tier.rollRarity(Double.random(in: 0..<1), luck: chestLuck)
        // Bad-luck protection, counted over every chest opened.
        var guaranteed = false
        if rarity < .legendary && chestsSinceLegendary + 1 >= ItemRules.legendaryPity {
            rarity = .legendary; guaranteed = true
        } else if rarity < .epic && chestsSinceEpic + 1 >= ItemRules.epicPity {
            rarity = .epic; guaranteed = true
        }
        chestsSinceEpic = rarity >= .epic ? 0 : chestsSinceEpic + 1
        chestsSinceLegendary = rarity >= .legendary ? 0 : chestsSinceLegendary + 1
        stats.chestsOpened += 1
        let pool = ItemDef.chestPool.filter { $0.rarity == rarity }
        guard let item = pool.randomElement() else { return }
        let isNew = items[item.id] == nil
        var gained = tier.bonusScrap
        if isNew {
            items[item.id] = 1
            affixes[item.id] = Affixes.roll(for: item)
            // Fill an empty slot right away so a first item is felt immediately.
            if equipped[item.slot.rawValue] == nil { equipped[item.slot.rawValue] = item.id }
        } else {
            gained += item.rarity.scrapValue
        }
        gained = Int((Double(gained) * (1 + 0.1 * Double(level(.scrapper)) + StarPerk.salvage.perLevel * Double(starLevel(.salvage)))).rounded())
        scrap += gained
        chestReveal = ChestReveal(tier: tier, item: item.id, isNew: isNew, scrap: gained, guaranteed: guaranteed)
        emit(.chest(item.rarity))
        analytics.log("chest_opened", ["tier": .string(tier.rawValue), "item": .string(item.id),
                                       "rarity": .string(item.rarity.name), "new": .bool(isNew)])
        save()
    }

    func canUpgradeItem(_ id: String) -> Bool {
        guard let def = ItemDef.find(id), let level = items[id], level < def.rarity.maxLevel else { return false }
        return scrap >= def.upgradeCost(level: level)
    }

    func upgradeItem(_ id: String) {
        guard canUpgradeItem(id), let def = ItemDef.find(id), let level = items[id] else { return }
        scrap -= def.upgradeCost(level: level)
        items[id] = level + 1
        emit(.purchase)
        analytics.log("item_upgraded", ["item": .string(id), "level": .int(level + 1)])
        save()
    }

    func equip(_ id: String) {
        guard let def = ItemDef.find(id), items[id] != nil else { return }
        equipped[def.slot.rawValue] = id
        analytics.log("item_equipped", ["item": .string(id), "slot": .string(def.slot.rawValue)])
        save()
    }

    func unequip(_ slot: ItemSlot) {
        equipped[slot.rawValue] = nil
        save()
    }

    /// Gives the zone's Mythic relic if the player doesn't have it yet.
    private func grantRelic(for target: ZoneID) {
        guard let relic = ItemDef.relic(for: target), items[relic.id] == nil else { return }
        items[relic.id] = 1
        affixes[relic.id] = Affixes.relicAffix(relic)
        if equipped[relic.slot.rawValue] == nil { equipped[relic.slot.rawValue] = relic.id }
        analytics.log("relic_earned", ["item": .string(relic.id), "zone": .string(target.rawValue)])
    }

    /// Echo Shard, Stomp Boots, Quake Boots and Storm Charm.
    private func applyItemPunchEffects(at index: Int, raw: Double) {
        let generation = areaGeneration
        let echo = itemBonus(.doubleHit)
        if echo > 0, Double.random(in: 0..<1) < echo, !run.blocks[index].isBroken {
            let hit = Config.hitDamage(raw: raw, armor: run.blocks[index].armor, penetration: penetration)
            addFloater(index, text: "ECHO " + NumberText.hit(hit), kind: .hit)
            applyDamage(hit, to: index)
        }
        let stomp = itemBonus(.stomp)
        if stomp > 0, generation == areaGeneration, Double.random(in: 0..<1) < stomp {
            for n in neighbors(of: index) where generation == areaGeneration && !run.blocks[n].isBroken {
                applyDamage(Config.hitDamage(raw: raw * 0.5, armor: run.blocks[n].armor, penetration: penetration), to: n)
            }
        }
        effectPunches += 1
        let quake = itemBonus(.quake)
        if quake > 0, effectPunches % 20 == 0, generation == areaGeneration {
            addFloater(index, text: "QUAKE", kind: .crit)
            for i in run.blocks.indices where generation == areaGeneration && !run.blocks[i].isBroken && !run.blocks[i].isTreasure {
                applyDamage(Config.hitDamage(raw: raw * quake, armor: run.blocks[i].armor, penetration: penetration), to: i)
            }
        }
        let storm = Int(itemBonus(.storm))
        if storm > 0, effectPunches % 15 == 0, generation == areaGeneration {
            zap(count: storm, raw: raw)
        }
    }

    // MARK: - Hearts

    /// Hearts defeated at record depths, across every zone.
    var heartsDefeated: Int { records.values.map(\.heartsDefeated).reduce(0, +) }
    /// Zones whose Heart has fallen at least once.
    var crowns: Int { records.values.filter { $0.heartsDefeated > 0 }.count }
    /// Deepest Heart defeated in the active zone.
    var deepestHeart: Int { record.deepestHeart }
    /// Coins in every zone: +25% per zone Crown, +5% per Crown Star.
    var crownMultiplier: Double { Conquest.coinMultiplier(crowns: crowns, hearts: heartsDefeated) }
    func hasCrown(_ target: ZoneID) -> Bool { record(for: target).heartsDefeated > 0 }
    var hasCrown: Bool { hasCrown(zone) }

    /// A zone stops at area 100 until its Heart falls; after that it goes on forever (Endless Depths).
    func maxArea(for target: ZoneID) -> Int {
        hasCrown(target) ? Int.max : target.maxArea
    }

    var isEndless: Bool { hasCrown }

    /// Any of the Heart's nine cells punches the Heart.
    private func redirectToHeart(_ index: Int) -> Int {
        guard run.blocks.indices.contains(index), run.blocks[index].material == .heartPart else { return index }
        return Conquest.heartIndex
    }

    var heartBlock: Block? {
        guard run.blocks.indices.contains(Conquest.heartIndex) else { return nil }
        let b = run.blocks[Conquest.heartIndex]
        return b.material == .heart ? b : nil
    }

    private func defeatHeart() {
        let area = run.area
        emit(.heartDefeated)
        analytics.log("heart_defeated", ["zone": .string(zone.rawValue), "area": .int(area), "record": .bool(area > deepestHeart)])
        // Rewards only for a new record depth, so prestige runs cannot farm the same Heart.
        guard area > deepestHeart else {
            toast = Toast(text: "\(zone.heartName) destroyed again")
            return
        }
        var r = record
        r.deepestHeart = area
        r.heartsDefeated += 1
        record = r
        let isCrown = r.heartsDefeated == 1
        let pc = Int((Double(isCrown ? Conquest.crownPerkCoins : Conquest.starPerkCoins) * zone.prestigeMultiplier).rounded())
        perkCoins += pc
        awardChest(.golden, reason: "heart")
        if isCrown { grantRelic(for: zone) }
        conquest = ConquestEvent(zone: zone, area: area, isCrown: isCrown, perkCoins: pc, coinMultiplier: crownMultiplier)
        save()
    }

    /// Coal: counts as extra punches toward Fever.
    private func addFever(_ punches: Int, at index: Int) {
        guard !feverActive else { return }
        recentPunches.append(contentsOf: Array(repeating: clock, count: punches))
        addFloater(index, text: "+FEVER", kind: .crit)
        if recentPunches.count >= Config.feverPunches {
            feverRemaining = feverDuration
            recentPunches.removeAll()
            analytics.log("fever", ["zone": .string(zone.rawValue), "area": .int(run.area), "from": .string("coal")])
        }
    }

    var coinRushActive: Bool { coinRushRemaining > 0 }

    // MARK: - Rewarded ads

    /// Whether a rewarded ad may be offered for this placement now (daily limits, context).
    func canWatch(_ placement: AdPlacement, ignoringOffer: Bool = false) -> Bool {
        guard adsAvailable else { return false }
        var ledger = adLedger
        ledger.rollOver()
        guard ledger.total < AdRules.dailyCap, ledger.count(placement) < placement.dailyLimit else { return false }
        switch placement {
        case .coinRush:
            return true
        case .offlineDouble:
            guard let report = offlineReport else { return false }
            return report.seconds >= AdRules.offlineDoubleMinimumSeconds
        case .treasureDouble:
            return ignoringOffer || treasureOffer != nil
        }
    }

    func adsLeftToday(_ placement: AdPlacement) -> Int {
        var ledger = adLedger
        ledger.rollOver()
        return max(0, min(placement.dailyLimit - ledger.count(placement), AdRules.dailyCap - ledger.total))
    }

    /// Call right before showing an ad. Pauses the game and counts the view.
    func adWillShow(_ placement: AdPlacement) {
        if placement == .treasureDouble {
            pendingTreasureCoins = treasureOffer?.coins ?? 0
            treasureOffer = nil
        }
        adLedger.rollOver()
        adLedger.record(placement)
        lastAdPlaySeconds = stats.playSeconds
        isPaused = true
        resetTransientInput()
        analytics.log("ad_started", ["placement": .string(placement.rawValue), "today": .int(adLedger.total)])
    }

    /// Call when the ad closes. Grants the reward only if the player watched to the end.
    func adDidFinish(_ placement: AdPlacement, rewarded: Bool) {
        isPaused = false
        analytics.log(rewarded ? "ad_rewarded" : "ad_skipped", ["placement": .string(placement.rawValue)])
        guard rewarded else {
            pendingTreasureCoins = 0
            save()
            return
        }
        switch placement {
        case .coinRush:
            coinRushRemaining += AdRules.coinRushSeconds
        case .offlineDouble:
            claimOffline(multiplier: 2)
        case .treasureDouble:
            // Adds the same amount again; Coin Rush was already applied to it.
            earnUnboosted(pendingTreasureCoins)
            toast = Toast(text: "Treasure doubled: +\(NumberText.format(pendingTreasureCoins, short: settings.shortNumbers)) \(zone.currencyShort)")
            pendingTreasureCoins = 0
        }
        save()
    }

    // MARK: - Store

    /// Credits a verified purchase. Each transaction is credited once, and a one-time product only once ever,
    /// so restoring or a repeated App Store update never pays out twice. Returns whether anything was granted.
    @discardableResult
    func grantPurchase(_ product: StoreProduct, transactionID: String) -> Bool {
        guard !processedTransactions.contains(transactionID) else { return false }
        processedTransactions.insert(transactionID)
        if product.isOneTime {
            guard !ownedProducts.contains(product.rawValue) else { save(); return false }
            ownedProducts.insert(product.rawValue)
        }
        let grant = product.grant
        for (tier, count) in grant.chests { chests[tier.rawValue, default: 0] += count }
        scrap += grant.scrap
        perkCoins += grant.perkCoins
        toast = Toast(text: "\(product.title): thank you!")
        emit(.chest(grant.chests[.golden] != nil ? .legendary : .rare))
        analytics.log("purchase_granted", ["product": .string(product.rawValue)])
        save()
        return true
    }

    // MARK: - Break ads (interstitials)

    func canShowBreakAd() -> Bool {
        // Never on top of a card the player should read first.
        guard breakAdsAvailable, !adsRemoved, !isPaused, zoneIntro == nil, conquest == nil, offlineReport == nil,
              stats.playSeconds >= BreakAdRules.minimumPlaySeconds,
              stats.playSeconds - lastAdPlaySeconds >= BreakAdRules.spacingSeconds else { return false }
        var ledger = adLedger
        ledger.rollOver()
        return ledger.breaks < BreakAdRules.dailyCap
    }

    /// Called at a natural break the player chose. Asks the UI for an interstitial if the rules allow one.
    func requestBreakAd(_ reason: String) {
        guard canShowBreakAd() else { return }
        breakAdRequest += 1
        analytics.log("break_ad_requested", ["reason": .string(reason)])
    }

    func breakAdWillShow() {
        adLedger.rollOver()
        adLedger.recordBreak()
        lastAdPlaySeconds = stats.playSeconds
        isPaused = true
        resetTransientInput()
        analytics.log("break_ad_started", ["today": .int(adLedger.breaks)])
    }

    func breakAdDidFinish(shown: Bool) {
        isPaused = false
        if !shown { analytics.log("break_ad_failed", [:]) }
        save()
    }

    private func neighbors(of index: Int) -> [Int] {
        let c = index % Config.columns, r = index / Config.columns
        var result: [Int] = []
        if c > 0 { result.append(index - 1) }
        if c < Config.columns - 1 { result.append(index + 1) }
        if r > 0 { result.append(index - Config.columns) }
        if r < Config.rows - 1 { result.append(index + Config.columns) }
        return result
    }

    private func addFloater(_ index: Int, text: String, kind: Floater.Kind) {
        switch settings.damageNumbers {
        case .off where kind != .coins: return
        case .critsOnly where kind == .hit || kind == .miner || kind == .weak: return
        default: break
        }
        floaters.append(Floater(blockIndex: index, text: text, kind: kind, born: clock,
                                jitter: Double.random(in: -10...10)))
        if floaters.count > 40 { floaters.removeFirst(floaters.count - 40) }
    }

    // MARK: - Miners

    private func tickMiners(_ dt: Double) {
        guard minerCount > 0 else {
            if !minerTargets.isEmpty { minerTargets = [] }
            return
        }
        let generation = areaGeneration
        var marks: [MinerMark] = []
        for kind in MinerKind.allCases {
            let count = minerCount(kind)
            let interval = minerInterval(kind, run: run)
            var timers = minerTimers[kind] ?? []
            if timers.count != count {
                // Stagger swings so a crew does not hit in lockstep.
                timers = (0..<count).map { Double($0) / Double(max(count, 1)) * interval }
            }
            for i in 0..<count {
                guard generation == areaGeneration, let target = minerTarget(kind) else { break }
                marks.append(MinerMark(index: target, kind: kind))
                timers[i] += dt
                if timers[i] >= interval {
                    timers[i] -= interval
                    minerSwing(kind, at: target)
                }
            }
            minerTimers[kind] = timers
        }
        if generation != areaGeneration { marks = [] }
        if marks != minerTargets { minerTargets = marks }
    }

    private func minerSwing(_ kind: MinerKind, at target: Int) {
        let raw = minerHit * kind.damageFactor
        let pen = level(.sharedDrills) > 0 ? tool.penetration * 0.5 : 0
        switch kind {
        case .digger, .driller:
            var hit = Config.hitDamage(raw: raw, armor: run.blocks[target].armor * kind.armorShare, penetration: pen)
            if run.blocks[target].isTreasure { hit *= Perk.treasureCrewShare(level: level(.treasureCrew)) }
            addFloater(target, text: NumberText.hit(hit * tideFactor(at: target)), kind: .miner)
            emit(.minerHit(index: target))
            applyDamage(hit, to: target, byMiner: true)
        case .blaster:
            let generation = areaGeneration
            addFloater(target, text: "BLAST", kind: .miner)
            emit(.minerHit(index: target))
            for index in blastArea(around: target) where generation == areaGeneration {
                let b = run.blocks[index]
                guard !b.isBroken, b.material != .heartPart, !b.isTreasure || level(.treasureCrew) > 0 else { continue }
                var hit = Config.hitDamage(raw: raw, armor: b.armor * kind.armorShare, penetration: pen)
                if b.isTreasure { hit *= Perk.treasureCrewShare(level: level(.treasureCrew)) }
                applyDamage(hit, to: index, byMiner: true)
            }
        }
    }

    /// Diggers take the weakest block, Drillers the most armored, Blasters the toughest cluster.
    /// Miners skip treasure unless Treasure Crew is owned.
    private func minerTarget(_ kind: MinerKind) -> Int? {
        let canMineTreasure = level(.treasureCrew) > 0
        let open = run.blocks.filter { !$0.isBroken && (canMineTreasure || !$0.isTreasure) && $0.material != .heartPart }
        switch kind {
        case .digger:
            return open.min { $0.hp < $1.hp }?.id
        case .driller:
            return open.max { ($0.armor, $0.hp) < ($1.armor, $1.hp) }?.id
        case .blaster:
            return open.max { clusterHP(around: $0.id) < clusterHP(around: $1.id) }?.id
        }
    }

    private func blastArea(around index: Int) -> [Int] {
        let c = index % Config.columns, r = index / Config.columns
        var result: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 {
                let nr = r + dr, nc = c + dc
                if nr >= 0, nr < Config.rows, nc >= 0, nc < Config.columns { result.append(nr * Config.columns + nc) }
            }
        }
        return result
    }

    private func clusterHP(around index: Int) -> Double {
        blastArea(around: index).reduce(0) { total, i in
            let b = run.blocks[i]
            return total + (b.isBroken || b.isTreasure ? 0 : b.hp)
        }
    }

    // MARK: - Magma Depths

    /// One shared tide timer: out for `Tide.interval`, then in for `Tide.duration`.
    private func tickTide(_ dt: Double) {
        if tideRemaining > 0 {
            tideRemaining = max(0, tideRemaining - dt)
            if tideRemaining == 0 { emit(.tide(rising: false)) }
            return
        }
        tideTimer += dt
        tideCharge = min(1, tideTimer / Tide.interval)
        if tideTimer >= Tide.interval {
            tideTimer = 0
            tideCharge = 0
            tideRemaining = Tide.duration
            emit(.tide(rising: true))
            analytics.log("high_tide", ["area": .int(run.area)])
        }
    }

    /// A broken runestone hits every other block in its row (see `Rune`). The Heart is hit once, for less.
    private func runePulse(from index: Int) {
        let generation = areaGeneration
        let row = index / Config.columns
        emit(.rune(index: index))
        addFloater(index, text: "RUNE", kind: .chain)
        var hitHeart = false
        for col in 0..<Config.columns {
            if generation != areaGeneration { return }
            let cell = row * Config.columns + col
            guard cell != index else { continue }
            let target = redirectToHeart(cell)
            let b = run.blocks[target]
            guard !b.isBroken, !b.isTreasure else { continue }
            if b.material == .heart {
                guard !hitHeart else { continue }
                hitHeart = true
                addFloater(target, text: "RUNE " + NumberText.hit(b.maxHP * Rune.heartShare), kind: .chain)
                hitPulses[target, default: 0] += 1
                applyDamage(b.maxHP * Rune.heartShare, to: target, tide: false)
                continue
            }
            hitPulses[target, default: 0] += 1
            applyDamage(b.maxHP * Rune.share, to: target, tide: false)
        }
    }

    private func tickMagma(_ dt: Double) {
        // Regrowth: a damaged block left alone heals, but never past the top of its crack stage.
        var blocks = run.blocks
        var healed = false
        for i in blocks.indices {
            let b = blocks[i]
            guard !b.isBroken, !b.isTreasure, b.hp < b.maxHP, clock >= (regrowAfter[i] ?? 0) else { continue }
            let cap = (regrowCap[i] ?? 1) * b.maxHP
            guard b.hp < cap else { continue }
            blocks[i].hp = min(cap, b.hp + b.maxHP * Magma.regrowPerSecond * dt)
            healed = true
        }
        if healed { run.blocks = blocks }

        // Vents erupt together on one timer.
        let vents = run.blocks.filter { $0.material == .vent && !$0.isBroken }
        guard !vents.isEmpty else {
            if ventCharge != 0 { ventCharge = 0 }
            return
        }
        ventTimer += dt
        ventCharge = min(1, ventTimer / Magma.ventInterval)
        if ventTimer >= Magma.ventInterval {
            ventTimer = 0
            ventCharge = 0
            erupt(vents.map(\.id))
        }
    }

    /// Each vent deals 25% of max HP to its 8 neighbours, ignoring armor. Treasure is spared.
    private func erupt(_ vents: [Int]) {
        let generation = areaGeneration
        analytics.log("vent_eruption", ["area": .int(run.area), "vents": .int(vents.count)])
        emit(.erupt)
        // Heart of the Depths: every eruption feeds it, up to the top of its current crack.
        if let heart = heartBlock, !heart.isBroken, heart.hp < heart.maxHP {
            let i = Conquest.heartIndex
            let cap = (regrowCap[i] ?? 1) * heart.maxHP
            run.blocks[i].hp = min(max(cap, heart.hp), heart.hp + heart.maxHP * Conquest.ventHeartHeal * Double(vents.count))
            addFloater(i, text: "+HEAL", kind: .weak)
        }
        for vent in vents {
            guard generation == areaGeneration else { return }
            addFloater(vent, text: "ERUPT", kind: .crit)
            hitPulses[vent, default: 0] += 1
            for index in blastArea(around: vent) where index != vent && generation == areaGeneration {
                let b = run.blocks[index]
                guard !b.isBroken, !b.isTreasure else { continue }
                applyDamage(b.maxHP * Magma.ventShare, to: index, byMiner: true)
            }
        }
    }

    // MARK: - Shop

    func isUnlocked(_ kind: UpgradeKind) -> Bool {
        if kind == .training || kind == .shiftPace { return minerCount > 0 }
        return bestArea >= kind.unlockArea
    }

    func isMaxed(_ kind: UpgradeKind) -> Bool { run.level(kind) >= kind.maxLevel }

    func cost(_ kind: UpgradeKind) -> Double { kind.cost(level: run.level(kind)) }

    func canBuy(_ kind: UpgradeKind) -> Bool {
        isUnlocked(kind) && !isMaxed(kind) && run.coins >= cost(kind)
    }

    func buy(_ kind: UpgradeKind) {
        guard canBuy(kind) else { return }
        let price = cost(kind)
        run.coins -= price
        run.setLevel(kind, run.level(kind) + 1)
        emit(.purchase)
        analytics.log("upgrade_bought", [
            "zone": .string(zone.rawValue), "upgrade": .string(kind.rawValue), "level": .int(run.level(kind)),
            "cost": .double(price), "area": .int(run.area), "run_seconds": .double(run.playSeconds),
        ])
        analytics.milestone(.firstUpgrade)
        if kind == .hireMiner { analytics.milestone(.firstMiner, ["zone": .string(zone.rawValue)]) }
    }

    func toolState(_ tool: Tool) -> ToolState {
        if run.toolIndex >= tool.id { return .owned }
        if tool.id > run.toolIndex + 1 || bestArea < tool.unlockArea { return .locked }
        return run.coins >= toolCost(tool) ? .affordable : .tooExpensive
    }

    /// Tool price: ×1.5 shop scaling, minus Toolsmith.
    func toolCost(_ tool: Tool) -> Double {
        (tool.cost * Config.shopPriceMultiplier * (1 - 0.08 * Double(level(.toolsmith)))).rounded()
    }

    func buyTool(_ tool: Tool) {
        guard toolState(tool) == .affordable else { return }
        run.coins -= toolCost(tool)
        run.toolIndex = tool.id
        emit(.purchase)
        analytics.log("tool_bought", ["zone": .string(zone.rawValue), "tool": .string(tool.name), "area": .int(run.area)])
        analytics.milestone(.firstTool)
    }

    // MARK: - Zones

    /// Every coin cost of an unlock, after Surveyor.
    func unlockCosts(_ target: ZoneID) -> [ZoneCost] {
        guard let unlock = target.unlock else { return [] }
        let discount = 1 - 0.05 * Double(level(.surveyor))
        return unlock.costs.map { ZoneCost(zone: $0.zone, amount: ($0.amount * discount).rounded()) }
    }

    /// The main (previous-zone) coin cost.
    func unlockCost(_ target: ZoneID) -> Double { unlockCosts(target).first?.amount ?? 0 }

    func unlockAreaMet(_ target: ZoneID) -> Bool {
        guard let unlock = target.unlock else { return true }
        return isUnlocked(unlock.previous) && record(for: unlock.previous).bestCleared >= unlock.clearArea
    }

    /// Coins held toward an unlock, in the main cost's zone.
    func unlockCoinsHeld(_ target: ZoneID) -> Double {
        guard let zone = unlockCosts(target).first?.zone else { return 0 }
        return run(for: zone)?.coins ?? 0
    }

    func canUnlock(_ target: ZoneID) -> Bool {
        !isUnlocked(target) && unlockAreaMet(target)
            && unlockCosts(target).allSatisfy { (run(for: $0.zone)?.coins ?? 0) >= $0.amount }
    }

    /// Pays the previous zone's coins, opens the new mine, and moves the player into it.
    func unlockZone(_ target: ZoneID) {
        guard canUnlock(target) else { return }
        for cost in unlockCosts(target) { runs[cost.zone.rawValue]?.coins -= cost.amount }
        unlockedZones.append(target)
        seeds[target.rawValue] = UInt64.random(in: 1...UInt64.max)
        records[target.rawValue] = ZoneRecord()
        runs[target.rawValue] = freshRun(for: target)
        analytics.log("zone_unlocked", ["zone": .string(target.rawValue)])
        if target == .caverns { analytics.milestone(.zone2Unlocked) }
        switchZone(to: target)
    }

    func switchZone(to target: ZoneID) {
        guard isUnlocked(target), target != activeZone else { return }
        let from = activeZone
        run.leftAt = Date()
        run.treasureCollapse = nil
        activeZone = target
        floaters = []
        hitPulses = [:]
        feverRemaining = 0
        banner = nil
        minerTargets = []
        areaGeneration += 1
        resetTransientInput()
        if run.blocks.isEmpty { run.blocks = newBlocks(area: run.area) }

        let banked = backgroundEarnings(for: target)
        analytics.log("zone_switched", ["from": .string(from.rawValue), "to": .string(target.rawValue),
                                        "banked": .double(banked?.coins ?? 0)])
        if let banked, banked.coins >= 1 {
            earnUnboosted(banked.coins)
            toast = Toast(text: "Your miners banked +\(NumberText.format(banked.coins, short: settings.shortNumbers)) \(target.currencyShort) while you were away")
        }
        run.leftAt = nil
        if !record.seenIntro {
            record.seenIntro = true
            zoneIntro = target
        }
        save()
    }

    private func collectOfflineReport() {
        guard offlineReport == nil else { return }
        offlineReport = offlineEarnings()
    }

    private func seed(for target: ZoneID) -> UInt64 { seeds[target.rawValue] ?? 1 }

    /// Offline coins were mined without Coin Rush, so they are credited as they are.
    private func creditActive(_ amount: Double) { earnUnboosted(amount) }

    /// Adds coins to a zone the player is not in, and restarts its background clock.
    private func creditBackground(_ amount: Double, to target: ZoneID) {
        runs[target.rawValue]?.coins += amount
        runs[target.rawValue]?.lifetimeCoins += amount
        stats.coins[target.rawValue, default: 0] += amount
        runs[target.rawValue]?.leftAt = Date()
    }

    private func resetTransientInput() {
        armedGadget = nil
        gadgetCooldowns = [:]
        toolPunches = 0
        effectPunches = 0
        rhythmCounter = 0
        regrowAfter = [:]
        regrowCap = [:]
        ventTimer = 0
        ventCharge = 0
        tideTimer = 0
        tideCharge = 0
        tideRemaining = 0
        playerDamage = 0
        minerDamage = 0
        recentPunches = []
        recentTaps = []
        pressIndex = nil
        autoTarget = nil
        minerTimers = [:]
        focusIndex = nil
        focusStacks = 0
        holdAccumulator = 0
    }

    // MARK: - Saving

    func save() {
        sinceSave = 0
        lastActive = Date()
        let data = SaveData(runs: runs, records: records, seeds: seeds, activeZone: activeZone,
                            unlockedZones: unlockedZones, holdUnlocked: holdUnlocked, settings: settings,
                            perks: perks, perkCoins: perkCoins, lastActive: lastActive,
                            coinRushRemaining: coinRushRemaining, adLedger: adLedger)
        var withHearts = data
        // Older versions read Pebble Quarry's Heart record from here.
        withHearts.heartsDefeated = record(for: .quarry).heartsDefeated
        withHearts.deepestHeart = record(for: .quarry).deepestHeart
        withHearts.items = items
        withHearts.equipped = equipped
        withHearts.chests = chests
        withHearts.scrap = scrap
        withHearts.seenTips = seenTips.sorted()
        withHearts.chestsSinceEpic = chestsSinceEpic
        withHearts.chestsSinceLegendary = chestsSinceLegendary
        withHearts.stats = stats
        withHearts.daily = daily
        withHearts.affixes = affixes
        withHearts.stars = stars
        withHearts.ascended = ascended.sorted()
        withHearts.ownedProducts = ownedProducts.sorted()
        withHearts.processedTransactions = processedTransactions.sorted()
        if let encoded = try? JSONEncoder().encode(withHearts) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }

    /// Starts over. With `keepItems`, gear, item levels, equipped slots, unopened chests and Scrap carry over.
    func resetProgress(keepItems: Bool = false) {
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
        var record = ZoneRecord()
        record.seenIntro = true
        perks = [:]
        perkCoins = 0
        conquest = nil
        if !keepItems {
            items = [:]
            equipped = [:]
            chests = [:]
            scrap = 0
            chestsSinceEpic = 0
            chestsSinceLegendary = 0
            affixes = [:]
        }
        stars = [:]
        ascended = []
        stats = LifetimeStats()
        daily = DailyState()
        dailyReveal = nil
        chestReveal = nil
        activeTip = nil
        activeZone = .quarry
        unlockedZones = [.quarry]
        seeds = [ZoneID.quarry.rawValue: UInt64.random(in: 1...UInt64.max)]
        records = [ZoneID.quarry.rawValue: record]
        runs = [ZoneID.quarry.rawValue: ZoneRun()]
        run.blocks = newBlocks(area: 1)
        holdUnlocked = false
        offlineReport = nil
        zoneIntro = nil
        coinRushRemaining = 0
        treasureOffer = nil
        toast = nil
        floaters = []
        feverRemaining = 0
        minerTargets = []
        banner = nil
        areaGeneration += 1
        resetTransientInput()
        save()
    }
}

enum ToolState { case owned, affordable, tooExpensive, locked }

enum PerkState { case maxed, affordable, tooExpensive, locked }

extension GameModel {
    // MARK: - Ascension

    func buyStar(_ star: StarPerk) {
        guard starState(star) == .affordable else { return }
        let price = star.cost(level: starLevel(star))
        perkCoins -= price
        stars[star.rawValue] = starLevel(star) + 1
        emit(.purchase)
        analytics.log("star_bought", ["star": .string(star.rawValue), "level": .int(starLevel(star)), "cost": .int(price)])
        save()
    }

    func buyAscension(_ perk: AscensionPerk) {
        guard ascensionState(perk) == .affordable else { return }
        perkCoins -= perk.cost
        ascended.insert(perk.rawValue)
        emit(.purchase)
        analytics.log("ascension_bought", ["perk": .string(perk.rawValue), "cost": .int(perk.cost)])
        save()
    }

    /// Auto-Prestige: a run with no new area for a while prestiges itself. Never during a Heart fight.
    func checkAutoPrestige() {
        guard owns(.autoPrestige), settings.autoPrestige, canPrestige, heartBlock == nil,
              run.areaSeconds >= Ascension.autoPrestigeStall else { return }
        let reward = prestigeReward
        prestige()
        toast = Toast(text: "Auto-prestige: +\(reward) Perk Coins")
    }

    // MARK: - Affixes and salvage

    func affix(_ id: String) -> Affix? { affixes[id] }

    func canRerollAffix(_ id: String) -> Bool {
        guard let def = ItemDef.find(id), items[id] != nil else { return false }
        return scrap >= Affixes.rerollCost(def.rarity)
    }

    func rerollAffix(_ id: String) {
        guard canRerollAffix(id), let def = ItemDef.find(id) else { return }
        scrap -= Affixes.rerollCost(def.rarity)
        affixes[id] = Affixes.roll(for: def)
        emit(.purchase)
        analytics.log("affix_rerolled", ["item": .string(id)])
        save()
    }

    /// Scrap for breaking an item down: twice its duplicate value plus half the Scrap spent upgrading it.
    func salvageValue(_ id: String) -> Int {
        guard let def = ItemDef.find(id), let level = items[id] else { return 0 }
        let spent = (1..<max(level, 1)).map { def.upgradeCost(level: $0) }.reduce(0, +)
        return def.rarity.scrapValue * 2 + spent / 2
    }

    /// Relics can't be salvaged: they never drop again.
    func canSalvage(_ id: String) -> Bool {
        guard let def = ItemDef.find(id), items[id] != nil else { return false }
        return def.heartZone == nil
    }

    func salvage(_ id: String) {
        guard canSalvage(id), let def = ItemDef.find(id) else { return }
        let gained = salvageValue(id)
        if equipped[def.slot.rawValue] == id { equipped[def.slot.rawValue] = nil }
        items[id] = nil
        affixes[id] = nil
        scrap += gained
        emit(.purchase)
        analytics.log("item_salvaged", ["item": .string(id), "scrap": .int(gained)])
        save()
    }

    // MARK: - Daily reward

    var dailyUnlocked: Bool { record(for: .quarry).bestArea >= Daily.unlockArea }

    func dailyAvailable(now: Date = Date()) -> Bool {
        dailyUnlocked && daily.lastClaimDay != Daily.dayKey(now)
    }

    /// Streak day the next claim would be, 1…7. A missed day starts over at 1; after day 7 the track repeats.
    func nextDailyDay(now: Date = Date()) -> Int {
        guard let last = daily.lastClaimDay else { return 1 }
        if last == Daily.dayKey(now) { return daily.streak % 7 + 1 }
        return Daily.isYesterday(last, now: now) ? daily.streak % 7 + 1 : 1
    }

    /// Days already claimed in the current week of the track, for the reward strip.
    func dailyClaimedThisWeek(now: Date = Date()) -> Int {
        guard let last = daily.lastClaimDay else { return 0 }
        if last == Daily.dayKey(now) { return (daily.streak - 1) % 7 + 1 }
        return Daily.isYesterday(last, now: now) ? daily.streak % 7 : 0
    }

    func claimDaily(now: Date = Date()) {
        guard dailyAvailable(now: now) else { return }
        let day = nextDailyDay(now: now)
        let reward = DailyReward.track[day - 1]
        daily.streak = day == 1 ? 1 : daily.streak + 1
        daily.lastClaimDay = Daily.dayKey(now)
        for (tier, count) in reward.chests { chests[tier.rawValue, default: 0] += count }
        scrap += reward.scrap
        stats.dailyClaims += 1
        dailyReveal = reward
        emit(.chest(reward.chests[.golden] != nil ? .legendary : .rare))
        analytics.log("daily_claimed", ["day": .int(day), "streak": .int(daily.streak)])
        save()
    }

    // MARK: - Perks

    func level(_ perk: Perk) -> Int { perks[perk.rawValue, default: 0] }

    func perkState(_ perk: Perk) -> PerkState {
        if level(perk) >= perk.maxLevel { return .maxed }
        if let req = perk.requirement, level(req.perk) < req.level { return .locked }
        if let req = perk.secondRequirement, level(req.perk) < req.level { return .locked }
        return perkCoins >= perk.cost(level: level(perk)) ? .affordable : .tooExpensive
    }

    func buyPerk(_ perk: Perk) {
        guard perkState(perk) == .affordable else { return }
        let price = perk.cost(level: level(perk))
        perkCoins -= price
        perks[perk.rawValue] = level(perk) + 1
        emit(.purchase)
        analytics.log("perk_bought", ["perk": .string(perk.rawValue), "level": .int(level(perk)), "cost": .int(price)])
        save()
    }

    // MARK: - Prestige (per zone)

    var bestPrestigeArea: Int { record.bestPrestigeArea }
    var prestigeCount: Int { record.prestigeCount }
    var totalPrestiges: Int { records.values.map(\.prestigeCount).reduce(0, +) }
    var prestigeArea: Int { run.maxCleared }
    var prestigeRequiredArea: Int { Prestige.requiredArea(bestPrestigeArea: bestPrestigeArea) }
    var canPrestige: Bool { prestigeArea >= prestigeRequiredArea }
    var prestigeDepthReward: Int { Prestige.depthReward(area: prestigeArea, multiplier: zone.prestigeMultiplier) }
    var prestigeRecordBonus: Int {
        Prestige.recordBonus(area: prestigeArea, bestPrestigeArea: bestPrestigeArea, multiplier: zone.prestigeMultiplier)
    }
    var prestigeReward: Int { prestigeDepthReward + prestigeRecordBonus }

    /// Resets the active zone's run. Other zones, perks, Perk Coins, records and settings stay.
    func prestige() {
        guard canPrestige else { return }
        analytics.log("prestige", [
            "zone": .string(zone.rawValue), "area": .int(prestigeArea), "reward": .int(prestigeReward),
            "record_bonus": .int(prestigeRecordBonus), "run_seconds": .double(run.playSeconds),
            "index": .int(record.prestigeCount + 1),
        ])
        analytics.milestone(.firstPrestige, ["zone": .string(zone.rawValue), "area": .int(prestigeArea)])
        perkCoins += prestigeReward
        record.lastRunSeconds = run.playSeconds
        record.lastPrestigeDepth = prestigeArea
        record.bestPrestigeArea = max(bestPrestigeArea, prestigeArea)
        record.prestigeCount += 1
        seeds[zone.rawValue] = UInt64.random(in: 1...UInt64.max)
        run = freshRun(for: zone)
        floaters = []
        hitPulses = [:]
        feverRemaining = 0
        banner = nil
        minerTargets = []
        areaGeneration += 1
        resetTransientInput()
        save()
    }

    /// A new run with the starting perks applied (Seed Money, Day-One Crew).
    func freshRun(for target: ZoneID) -> ZoneRun {
        var fresh = ZoneRun()
        fresh.coins = Perk.seedMoneyAmounts[min(level(.seedMoney), Perk.seedMoneyAmounts.count - 1)]
        let crew = min(level(.dayOneCrew), UpgradeKind.hireMiner.maxLevel)
        if crew > 0 { fresh.setLevel(.hireMiner, crew) }
        // Union Contract: the old run's miners come along.
        if owns(.unionContract), let old = runs[target.rawValue] {
            for kind in MinerKind.allCases { fresh.setLevel(kind.hire, max(fresh.level(kind.hire), old.level(kind.hire))) }
        }
        fresh.area = min(1 + 2 * level(.expressElevator), target.maxArea)
        fresh.blocks = AreaGenerator.blocks(zone: target, area: fresh.area, seed: seed(for: target), treasureChance: treasureChance)
        return fresh
    }

    func newBlocks(area: Int, salt: UInt64 = 0) -> [Block] {
        AreaGenerator.blocks(zone: zone, area: area, seed: seed(for: zone) &+ salt, treasureChance: treasureChance)
    }

    // MARK: - Offline and background mining

    var offlineCapSeconds: Double { (Offline.baseCapHours + Double(level(.nightShift))) * 3600 }

    /// Miner income for a zone's current area: (1 + clear bonus) · Σ reward ÷ Σ (HP ÷ miner DPS on that block).
    /// The sum treats damage as landing on one block at a time; a Blaster swing lands on up to 9
    /// (about 6 on average once edges and broken blocks are counted).
    func minerCoinsPerSecond(for target: ZoneID) -> Double {
        guard let run = run(for: target) else { return 0 }
        let crews = MinerKind.allCases.map { ($0, run.level($0.hire)) }.filter { $0.1 > 0 }
        guard !crews.isEmpty else { return 0 }
        let blocks = AreaGenerator.blocks(zone: target, area: run.area, seed: 0, treasureChance: 0)
        let hitRaw = minerHit(for: run, in: target)
        let seconds = blocks.reduce(0.0) { total, b in
            let dps = crews.reduce(0.0) { sum, crew in
                let (kind, count) = crew
                let hit = Config.hitDamage(raw: hitRaw * kind.damageFactor, armor: b.armor * kind.armorShare, penetration: 0)
                let coverage = kind == .blaster ? Config.blasterAverageTargets : 1
                return sum + hit * Double(count) * coverage / minerInterval(kind, run: run)
            }
            return total + b.maxHP / dps
        }
        guard seconds > 0 else { return 0 }
        var rewards = blocks.map(\.reward).reduce(0, +) * (1 + clearBonusShare(for: run))
        // Sunken Ruins: average the tide over a full cycle.
        if target == .ruins { rewards *= Tide.averageRewardFactor * Tide.averageDamageFactor }
        return rewards * crownMultiplier * coinMultiplier(for: run) / seconds
    }

    var minerCoinsPerSecond: Double { minerCoinsPerSecond(for: zone) }

    func earnings(for target: ZoneID, elapsed: Double) -> OfflineEntry? {
        let elapsed = max(0, elapsed)
        guard elapsed >= Offline.minimumSeconds else { return nil }
        let capped = min(elapsed, offlineCapSeconds)
        let cps = minerCoinsPerSecond(for: target)
        let coins = (cps * offlineEfficiency * capped).rounded(.down)
        guard coins >= 1 else { return nil }
        return OfflineEntry(zone: target, seconds: elapsed, cappedSeconds: capped, coinsPerSecond: cps,
                            efficiency: offlineEfficiency, coins: coins)
    }

    /// The active zone counts from the last save; other zones count from when the player left them.
    func offlineEarnings(now: Date = Date()) -> OfflineReport? {
        guard let last = lastActive else { return nil }
        let away = now.timeIntervalSince(last)
        var entries: [OfflineEntry] = []
        for target in unlockedZones {
            let since = target == zone ? last : (run(for: target)?.leftAt ?? last)
            if let entry = earnings(for: target, elapsed: now.timeIntervalSince(since)) { entries.append(entry) }
        }
        guard !entries.isEmpty, away >= Offline.minimumSeconds else { return nil }
        return OfflineReport(seconds: away, entries: entries)
    }

    func claimOffline(multiplier: Double = 1) {
        guard let report = offlineReport else { return }
        analytics.log("offline_claimed", [
            "multiplier": .double(multiplier),
            "away_seconds": .double(report.seconds),
            "zones": .int(report.entries.count),
            "coins_quarry": .double(report.entries.first { $0.zone == .quarry }?.coins ?? 0),
            "coins_caverns": .double(report.entries.first { $0.zone == .caverns }?.coins ?? 0),
            "coins_magma": .double(report.entries.first { $0.zone == .magma }?.coins ?? 0),
            "coins_ruins": .double(report.entries.first { $0.zone == .ruins }?.coins ?? 0),
        ])
        for entry in report.entries {
            if entry.zone == zone {
                creditActive(entry.coins * multiplier)
            } else {
                creditBackground(entry.coins * multiplier, to: entry.zone)
            }
        }
        offlineReport = nil
        save()
    }

    func backgroundEarnings(for target: ZoneID) -> OfflineEntry? {
        guard let leftAt = run(for: target)?.leftAt else { return nil }
        return earnings(for: target, elapsed: Date().timeIntervalSince(leftAt))
    }
}
