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
    /// Haunted Crypt: ghosts fade out (true) or turn solid again (false).
    case haunt(faded: Bool)
    /// A cursed urn broke: punches are weaker for a while.
    case curse
    case chest(Rarity)
    /// Weekly Heart: a tier broke.
    case weeklyTier
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
    @Published private(set) var runs: [String: ZoneRun] = [:]
    @Published private(set) var records: [String: ZoneRecord] = [:]
    @Published private(set) var activeZone: ZoneID = .quarry
    @Published private(set) var unlockedZones: [ZoneID] = [.quarry]

    // Account-level, survives prestige
    @Published private(set) var holdUnlocked = false
    @Published private(set) var perks: [String: Int] = [:]
    @Published private(set) var perkCoins = 0
    @Published var settings = Settings() {
        didSet { if settings != oldValue && !isLoading { save() } }
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
    @Published private(set) var weekly = WeeklyState()
    @Published private(set) var season = SeasonState()
    /// Stash: consumable → count.
    @Published private(set) var consumables: [String: Int] = [:]
    @Published private(set) var pets: [String: Int] = [:]
    @Published private(set) var activePet: String?
    @Published private(set) var cosmetics: Set<String> = []
    /// Cosmetic kind → equipped cosmetic id.
    @Published private(set) var equippedCosmetics: [String: String] = [:]
    /// Forge shards by rarity.
    @Published private(set) var shards: [String: Int] = [:]
    /// Consumable timers, in seconds of play.
    @Published private(set) var snowballRemaining = 0.0
    @Published private(set) var goldenRemaining = 0.0
    @Published private(set) var bellRemaining = 0.0
    @Published private(set) var eventRushRemaining = 0.0
    @Published private(set) var shiftDoubled = false
    /// The event boss fight in progress, and the last one's outcome.
    @Published private(set) var bossFight: BossFight?
    @Published var bossResult: BossResult?
    /// Set while a menu covers the mine: the game then steps 4 times a second instead of 30.
    var mineCovered = false
    private var pendingPlay = 0.0

    /// Adds play time collected since the last flush to the run and the lifetime stats.
    func flushPlayTime() {
        guard pendingPlay > 0 else { return }
        let p = pendingPlay
        pendingPlay = 0
        run.playSeconds += p
        run.areaSeconds += p
        stats.playSeconds += p
    }
    static let coveredTickInterval = 0.25
    /// The clock events read. Tests move it to a date inside or outside an event.
    var now: () -> Date = Date.init
    /// The Weekly Heart fight in progress. The mine stands still while it runs.
    @Published private(set) var weeklyFight: WeeklyFight?
    @Published var weeklyResult: WeeklyResult?
    /// Called with (week, score) when a fight sets a new best, for the leaderboard.
    var onWeeklyBest: ((Int, Int) -> Void)?
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

    // Haunted Crypt
    /// True while ghost blocks (and the Heart) are faded out of reach.
    @Published private(set) var ghostsFaded = false
    /// Seconds left in the current haunt phase, solid or faded.
    @Published private(set) var hauntRemaining: Double = Haunt.solidSeconds
    /// Clock time the ghosts last turned solid, for the Heart's return crits.
    private var ghostsReturnedAt = -100.0
    /// Seconds of curse left; while cursed your punches are weaker.
    @Published private(set) var curseRemaining: Double = 0
    var cursed: Bool { zone == .crypt && curseRemaining > 0 }

    // Magma Depths
    /// 0 → 1 as the next vent eruption approaches.
    @Published private(set) var ventCharge: Double = 0
    private var ventTimer: Double = 0
    /// Clock time after which a block may start regrowing.
    private var regrowAfter: [Int: Double] = [:]
    /// Highest HP fraction a block may regrow to: the top of the crack stage it was in.
    private var regrowCap: [Int: Double] = [:]

    private var seeds: [String: UInt64] = [:]
    /// True while a save is being applied, so nothing writes a half-loaded save.
    private var isLoading = false
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
        #if DEBUG
        // Director mode (Director/DirectorMode.swift): a throwaway in-memory profile, never read from or saved to disk.
        if let directed = Director.shared.startingSave() {
            let date = Director.shared.gameDate
            now = { date }
            load(directed)
            finishLoading()
            return
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: Self.saveKey) {
            if let save = try? JSONDecoder().decode(SaveData.self, from: data) {
                load(save)
            } else {
                // Never overwrite a save this version can't read (e.g. from a newer version): keep a copy to recover.
                UserDefaults.standard.set(data, forKey: Self.saveKey + ".unreadable")
                loadFresh()
            }
        } else {
            loadFresh()
        }
        finishLoading()
    }

    /// Fills every saved field from a save, migrating older formats.
    private func load(_ save: SaveData) {
        isLoading = true
        defer { isLoading = false }
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
        weekly = save.weekly
        season = save.season
        consumables = save.consumables
        pets = save.pets
        activePet = save.activePet
        cosmetics = Set(save.cosmetics)
        equippedCosmetics = save.equippedCosmetics
        shards = save.shards
        eventRushRemaining = save.eventRushRemaining
        shiftDoubled = save.shiftDoubled
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
    }

    private func loadFresh() {
        isLoading = true
        defer { isLoading = false }
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

    private func finishLoading() {
        if runs[activeZone.rawValue] == nil { runs[activeZone.rawValue] = ZoneRun() }
        if seeds[activeZone.rawValue] == nil { seeds[activeZone.rawValue] = UInt64.random(in: 1...UInt64.max) }
        if run.blocks.isEmpty { run.blocks = newBlocks(area: run.area) }
        lastAdPlaySeconds = stats.playSeconds
        // Saves from before Heart relics: hand over the relic of every Heart already defeated.
        for zone in ZoneID.allCases where hasCrown(zone) { grantRelic(for: zone) }
    }

    // MARK: - Save transfer (iCloud)

    /// Called after every save (iCloud sync listens).
    var onSaved: (() -> Void)?

    func showToast(_ text: String) { toast = Toast(text: text) }

    /// Replaces this device's progress with another save (from iCloud). Purchases from both are kept,
    /// and this device's settings stay as they are. Returns false if the data isn't a save.
    @discardableResult
    func importSave(_ data: Data) -> Bool {
        guard let incoming = try? JSONDecoder().decode(SaveData.self, from: data) else { return false }
        let keepProducts = ownedProducts, keepTransactions = processedTransactions, keepSettings = settings
        let keepSeason = season
        load(incoming)
        settings = keepSettings
        // An Event Pass bought on this device can't be bought or restored again, so it survives an import.
        if keepSeason.premium && !season.premium {
            if season.event == keepSeason.event || season.event.isEmpty { season.event = keepSeason.event; season.premium = true }
        }
        weeklyFight = nil
        weeklyResult = nil
        bossFight = nil
        bossResult = nil
        ownedProducts.formUnion(keepProducts)
        processedTransactions.formUnion(keepTransactions)
        finishLoading()
        activeTip = nil
        conquest = nil
        offlineReport = nil
        zoneIntro = nil
        chestReveal = nil
        floaters = []
        feverRemaining = 0
        minerTargets = []
        banner = nil
        treasureOffer = nil
        areaGeneration += 1
        resetTransientInput()
        save()
        analytics.log("save_imported", [:])
        return true
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
        #if DEBUG
        // Offline capture: Director steps the game by exactly 1/60 s per recorded frame instead.
        if Director.shared.isCapturing { return }
        #endif
        analytics.sessionStarted()
        collectOfflineReport()
        loop = Task { [weak self] in
            var last = ContinuousClock.now
            var pending = 0.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                let now = ContinuousClock.now
                let elapsed = now - last
                pending += min(Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18, 0.25)
                last = now
                guard let self else { return }
                // Behind a menu the mine only needs a few updates a second; fewer redraws keep menus smooth.
                if self.mineCovered && self.weeklyFight == nil && self.bossFight == nil && pending < Self.coveredTickInterval { continue }
                self.tick(min(pending, 0.25))
                pending = 0
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
    func advance(by dt: Double) {
        tick(dt)
        flushPlayTime()
    }

    private func tick(_ dt: Double) {
        guard !isPaused else { return }
        clock += dt
        if weeklyFight != nil {
            tickWeekly(dt)
            return
        }
        if bossFight != nil {
            tickBoss(dt)
            return
        }
        tickConsumables(dt)
        if coinRushRemaining > 0 { coinRushRemaining = max(0, coinRushRemaining - dt) }
        if !gadgetCooldowns.isEmpty {
            var next = gadgetCooldowns
            for (g, left) in next { next[g] = left - dt > 0 ? left - dt : nil }
            gadgetCooldowns = next
        }
        if let offer = treasureOffer, clock > offer.expires { treasureOffer = nil }
        analytics.addPlayTime(dt)
        // Play time is added once a second, not every tick: `runs` and `stats` are published,
        // and touching them 30 times a second made every view redraw.
        pendingPlay += dt
        if pendingPlay >= 1 { flushPlayTime() }

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
        if zone == .crypt { tickHaunt(dt) }
        if curseRemaining > 0 { curseRemaining = max(0, curseRemaining - dt) }

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
        if cursed { raw *= Curse.damageFactor }
        if snowballRemaining > 0 { raw *= ConsumableRules.snowballFactor }
        var isCrit = diceRoll() < critChance
        // Heart of the Crypt: punches right after it returns always crit.
        if zone == .crypt, index == Conquest.heartIndex, heartBlock != nil, !ghostsFaded,
           clock - ghostsReturnedAt < Haunt.returnCritWindow {
            isCrit = true
        }
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
        let shown = hit * tideFactor(at: index) * hauntFactor(at: index)
        if shown == 0 {
            addFloater(index, text: "PHASE", kind: .weak)
        } else {
            addFloater(index, text: titan ? "TITAN " + NumberText.hit(shown) : (weak ? "DEFLECT" : NumberText.hit(shown)),
                       kind: isCrit || titan ? .crit : (weak ? .weak : .hit))
        }
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

    /// Haunted Crypt: a faded ghost (or Heart) takes nothing from miners and only your tool's spectral share from you.
    func hauntFactor(at index: Int, byMiner: Bool = false) -> Double {
        guard zone == .crypt, ghostsFaded, isGhostly(index) else { return 1 }
        return byMiner ? 0 : tool.spectral
    }

    /// Ghost blocks and the Heart of the Crypt fade with the haunt.
    func isGhostly(_ index: Int) -> Bool {
        guard zone == .crypt, run.blocks.indices.contains(index) else { return false }
        let material = run.blocks[index].material
        return material.isGhost || material == .heart || material == .heartPart
    }

    /// `tide: false` for damage the tide doesn't touch (runestone pulses).
    private func applyDamage(_ amount: Double, to index: Int, chainStep: Int = 0, byMiner: Bool = false, tide: Bool = true) {
        guard run.blocks.indices.contains(index), !run.blocks[index].isBroken else { return }
        let amount = (tide ? amount * tideFactor(at: index) : amount) * hauntFactor(at: index, byMiner: byMiner)
        guard amount > 0 else { return }
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
        let lucky = luckyChance > 0 && diceRoll() < luckyChance
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
        if block.material == .cursedUrn {
            curseRemaining = Curse.seconds
            addFloater(index, text: "CURSED", kind: .weak)
            emit(.curse)
        }
        if block.material == .heart { defeatHeart() }
        if let event = block.material.season { collectEventPoints(event, at: index) }
        if block.isTreasure {
            analytics.log("treasure_broken", ["zone": .string(zone.rawValue), "area": .int(run.area), "reward": .double(block.reward)])
            if diceRoll() < ItemRules.treasureChestChance {
                awardChest(diceRoll() < ItemRules.treasureIronChance ? .iron : .wooden, reason: "treasure")
                // Lockpick and Chest Hunter can add a second chest to a drop, never one from nothing.
                if diceRoll() < Config.lockpickPerLevel * Double(run.level(.lockpick)) + 0.05 * Double(level(.chestHunter)) {
                    awardChest(.wooden, reason: "lockpick")
                }
            }
            if canWatch(.treasureDouble, ignoringOffer: true) {
                // The offer repeats exactly what this break paid; with Magnet, several breaks add up.
                let earlier = treasureOffer.map { $0.coins } ?? 0
                treasureOffer = TreasureOffer(coins: earlier + boosted(payout), expires: clock + AdRules.treasureOfferSeconds)
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
        flushPlayTime()
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
        var crowned = amount * crownMultiplier * coinMultiplier(for: run)
        if goldenRemaining > 0 { crowned *= ConsumableRules.goldenFactor }
        return coinRushRemaining > 0 ? crowned * AdRules.coinRushMultiplier : crowned
    }

    // MARK: - Tool effects and gadgets

    private func zap(count: Int, raw: Double) {
        let generation = areaGeneration
        var open = run.blocks.filter { !$0.isBroken && !$0.isTreasure && $0.material != .heartPart }.map(\.id)
        open = diceShuffled(open)
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
        return fromItems + activeSetBonuses.filter { $0.effect == effect }.map(\.value).reduce(0, +) + petBonus(effect)
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
        min(Offline.maxEfficiency, Offline.baseEfficiency + itemBonus(.offlineEfficiency) + 0.05 * Double(level(.overtime)))
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
        var rarity = tier.rollRarity(diceRoll(), luck: chestLuck)
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
        guard let item = dicePick(pool) else { return }
        let isNew = items[item.id] == nil
        var gained = tier.bonusScrap
        if isNew {
            items[item.id] = 1
            affixes[item.id] = Affixes.roll(for: item)
            // Fill an empty slot right away so a first item is felt immediately.
            if equipped[item.slot.rawValue] == nil { equipped[item.slot.rawValue] = item.id }
        } else {
            gained += item.rarity.scrapValue
            if Forge.canForge(from: item.rarity) { shards[String(item.rarity.rawValue), default: 0] += 1 }
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
        if echo > 0, diceRoll() < echo, !run.blocks[index].isBroken {
            let hit = Config.hitDamage(raw: raw, armor: run.blocks[index].armor, penetration: penetration)
            addFloater(index, text: "ECHO " + NumberText.hit(hit), kind: .hit)
            applyDamage(hit, to: index)
        }
        let stomp = itemBonus(.stomp)
        if stomp > 0, generation == areaGeneration, diceRoll() < stomp {
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
        case .weeklyHeart:
            return weeklyUnlocked && weeklyFight == nil && freeWeeklyAttemptsLeft() == 0
        case .eventBoss:
            return bossFight == nil && activeEvent != nil && !eventProgress.bossDefeated && freeBossTriesLeft == 0
        case .dailyDouble:
            let today = Daily.dayKey(Date())
            return daily.lastClaimDay == today && daily.doubledDay != today
        case .freeGadget:
            return seasonUnlocked
        case .eventRush:
            return seasonUnlocked && activeEvent != nil && eventRushRemaining == 0
        case .chestUpgrade:
            return upgradableChest != nil
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
        lastAdPlaySeconds = stats.playSeconds
        isPaused = true
        resetTransientInput()
        analytics.log("ad_started", ["placement": .string(placement.rawValue), "today": .int(adLedger.total)])
    }

    /// Call when the ad closes. Grants the reward only if the player watched to the end.
    func adDidFinish(_ placement: AdPlacement, rewarded: Bool) {
        isPaused = false
        analytics.log(rewarded ? "ad_rewarded" : "ad_skipped", ["placement": .string(placement.rawValue)])
        // Counted only when it paid, so an ad that fails to load never uses up a daily slot.
        if rewarded {
            adLedger.rollOver()
            adLedger.record(placement)
        }
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
        case .weeklyHeart:
            weekly.rollOver(now: Date())
            weekly.bonusAttempts += 1
        case .dailyDouble:
            let reward = DailyReward.track[(max(daily.streak, 1) - 1) % 7]
            for (tier, count) in reward.chests { chests[tier.rawValue, default: 0] += count }
            scrap += reward.scrap
            daily.doubledDay = Daily.dayKey(Date())
            toast = Toast(text: "Daily reward doubled: +\(reward.text)")
        case .freeGadget:
            let gadget = dicePick(Consumable.allCases.filter(\.isGadget))!
            consumables[gadget.rawValue, default: 0] += 1
            toast = Toast(text: "Free gadget: \(gadget.name)!")
        case .eventRush:
            eventRushRemaining += AdRules.eventRushSeconds
            toast = Toast(text: "Event Rush: double \(activeEvent?.season.currency ?? "event currency") for \(Int(AdRules.eventRushSeconds / 60)) min")
        case .chestUpgrade:
            if let tier = upgradableChest, let next = ChestTier.allCases.first(where: { $0.order == tier.order + 1 }) {
                chests[tier.rawValue, default: 0] -= 1
                chests[next.rawValue, default: 0] += 1
                toast = Toast(text: "\(tier.name) upgraded to \(next.name)!")
                emit(.chest(next == .golden ? .legendary : .rare))
            }
        case .eventBoss:
            if let event = activeEvent {
                season.rollOver(to: event)
                season.rollBossDay(Daily.dayKey(now()))
                season.bossBonusTries += 1
            }
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
        if product == .eventPass, grantEventPass() {
            analytics.log("purchase_granted", ["product": .string(product.rawValue), "event": .string(season.event)])
            save()
            return true
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
        flushPlayTime()
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
                                jitter: -10 + 20 * diceRoll()))
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
            let interval = minerInterval(kind, run: run) * (bellRemaining > 0 ? 0.5 : 1)
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
        // Miners can't touch faded ghosts, so they work elsewhere until the ghosts return.
        let open = run.blocks.filter { !$0.isBroken && (canMineTreasure || !$0.isTreasure) && $0.material != .heartPart
            && hauntFactor(at: $0.id, byMiner: true) > 0 }
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

    /// One shared haunt timer: ghosts are solid for `Haunt.solidSeconds`, then faded for `Haunt.fadedSeconds`.
    private func tickHaunt(_ dt: Double) {
        hauntRemaining -= dt
        guard hauntRemaining <= 0 else { return }
        ghostsFaded.toggle()
        hauntRemaining += ghostsFaded ? Haunt.fadedSeconds : Haunt.solidSeconds
        if !ghostsFaded { ghostsReturnedAt = clock }
        emit(.haunt(faded: ghostsFaded))
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
        flushPlayTime()
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
        flushPlayTime()
        guard !isLoading else { return }
        sinceSave = 0
        #if DEBUG
        // Director mode plays on a throwaway profile: nothing is ever written.
        if Director.shared.isActive { return }
        #endif
        lastActive = Date()
        if let encoded = encodedSaveWithoutSaving() {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
        onSaved?()
    }

    /// The current state encoded exactly as `save()` writes it, without writing anything.
    func encodedSaveWithoutSaving() -> Data? {
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
        withHearts.weekly = weekly
        withHearts.season = season
        withHearts.consumables = consumables
        withHearts.pets = pets
        withHearts.activePet = activePet
        withHearts.cosmetics = cosmetics.sorted()
        withHearts.equippedCosmetics = equippedCosmetics
        withHearts.shards = shards
        withHearts.eventRushRemaining = eventRushRemaining
        withHearts.shiftDoubled = shiftDoubled
        withHearts.affixes = affixes
        withHearts.stars = stars
        withHearts.ascended = ascended.sorted()
        withHearts.ownedProducts = ownedProducts.sorted()
        withHearts.processedTransactions = processedTransactions.sorted()
        return try? JSONEncoder().encode(withHearts)
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
        if !keepItems {
            pets = [:]
            activePet = nil
            cosmetics = []
            equippedCosmetics = [:]
            shards = [:]
        }
        consumables = [:]
        snowballRemaining = 0
        goldenRemaining = 0
        bellRemaining = 0
        eventRushRemaining = 0
        shiftDoubled = false
        // The event starts over, except a paid Event Pass, which stays.
        let paid = season
        season = SeasonState()
        if paid.premium { season.event = paid.event; season.premium = true }
        weeklyFight = nil
        weeklyResult = nil
        bossFight = nil
        bossResult = nil
        stars = [:]
        ascended = []
        stats = LifetimeStats()
        pendingPlay = 0
        lastAdPlaySeconds = 0
        // Today's daily reward stays claimed, so a reset can't be used to claim it twice.
        var freshDaily = DailyState()
        freshDaily.lastClaimDay = daily.lastClaimDay
        freshDaily.doubledDay = daily.doubledDay
        daily = freshDaily
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
        flushPlayTime()
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
        return def.heartZone == nil && def.season == nil
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
        flushPlayTime()
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
        let blocks = AreaGenerator.blocks(zone: zone, area: area, seed: seed(for: zone) &+ salt, treasureChance: treasureChance)
        guard seasonUnlocked, let event = activeEvent, !Conquest.isHeartArea(area) else { return blocks }
        return Seasons.sprinkle(event.season, into: blocks, seed: seed(for: zone) &+ salt &+ UInt64(area) &* 7919)
    }

    // MARK: - Offline and background mining

    var offlineCapSeconds: Double { Offline.capHours(nightShift: level(.nightShift)) * 3600 }

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
            "coins_crypt": .double(report.entries.first { $0.zone == .crypt }?.coins ?? 0),
        ])
        // Double Shift multiplies whatever the claim already pays.
        let multiplier = shiftDoubled ? multiplier * 2 : multiplier
        if shiftDoubled { shiftDoubled = false }
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

extension GameModel {
    // MARK: - Weekly Heart

    var weeklyUnlocked: Bool { record(for: .quarry).bestArea >= WeeklyHeart.unlockArea || unlockedZones.count > 1 }

    /// The weekly state as of `now`, with a new week or day already rolled over. Changes nothing.
    func weeklyState(now: Date = Date()) -> WeeklyState {
        var w = weekly
        w.rollOver(now: now)
        return w
    }

    func weeklyModifier(now: Date = Date()) -> WeeklyModifier { WeeklyHeart.modifier(week: WeeklyHeart.week(of: now)) }

    /// Free tries left today, not counting tries earned from ads.
    func freeWeeklyAttemptsLeft(now: Date = Date()) -> Int {
        max(0, WeeklyHeart.freeAttemptsPerDay - weeklyState(now: now).attemptsUsed)
    }

    func weeklyAttemptsLeft(now: Date = Date()) -> Int {
        let w = weeklyState(now: now)
        return max(0, WeeklyHeart.freeAttemptsPerDay + w.bonusAttempts - w.attemptsUsed)
    }

    /// Boss fights (Weekly Heart, event boss) use your strongest zone, wherever you are standing.
    var weeklyZone: ZoneID {
        unlockedZones.filter { runs[$0.rawValue] != nil }
            .max { basePunch(for: runs[$0.rawValue]!, in: $0) < basePunch(for: runs[$1.rawValue]!, in: $1) } ?? zone
    }
    private var weeklyRun: ZoneRun { runs[weeklyZone.rawValue] ?? run }

    /// Your punch in your strongest zone, before crits: Strength × tool × perks, items and stars.
    var weeklyPunch: Double { basePunch(for: weeklyRun, in: weeklyZone) }
    var weeklyStrengthLevel: Int { weeklyRun.level(.strength) }
    var weeklyTool: Tool { tool(for: weeklyZone, run: weeklyRun) }

    var weeklyCritChance: Double {
        min(ItemRules.critCap, Config.critChance(level: weeklyRun.level(.critChance)) + 0.01 * Double(level(.keenEye))
            + weeklyTool.critBonus + itemBonus(.critChance))
    }
    var weeklyCritMultiplier: Double {
        Config.critMultiplier(level: weeklyRun.level(.critDamage)) + itemBonus(.critDamage) + 0.2 * Double(level(.brutalCrits))
    }

    /// That zone's crew, at full strength (before the fight cap).
    var weeklyCrewFullDPS: Double {
        let r = weeklyRun
        return MinerKind.allCases.reduce(0) { sum, kind in
            sum + Double(r.level(kind.hire)) * minerHit(for: r, in: weeklyZone) * kind.damageFactor / minerInterval(kind, run: r)
        }
    }

    /// The crew keeps swinging during boss fights, but adds at most a few of your punches a second.
    var weeklyCrewDPS: Double { min(weeklyCrewFullDPS, weeklyPunch * WeeklyHeart.crewCapPunchesPerSecond) }
    var weeklyCrewCapped: Bool { weeklyCrewFullDPS > weeklyCrewDPS }

    /// Armoured Heart: Armour Penetration wins back what the armour takes.
    func weeklyArmourFactor(_ modifier: WeeklyModifier) -> Double {
        guard modifier == .armoured else { return 1 }
        let pen = min(Config.penetrationCap, weeklyTool.penetration + 0.03 * Double(level(.piercer)) + itemBonus(.penetration))
        return WeeklyHeart.armourFloor + (1 - WeeklyHeart.armourFloor) * pen / Config.penetrationCap
    }

    func startWeeklyFight(now: Date = Date()) {
        guard weeklyUnlocked, weeklyFight == nil, bossFight == nil else { return }
        weekly.rollOver(now: now)
        guard weeklyAttemptsLeft(now: now) > 0 else { return }
        weekly.attemptsUsed += 1
        resetTransientInput()
        weeklyResult = nil
        let modifier = WeeklyHeart.modifier(week: weekly.week)
        weeklyFight = WeeklyFight(modifier: modifier)
        analytics.log("weekly_start", ["week": .int(weekly.week), "modifier": .string(modifier.rawValue),
                                       "attempt": .int(weekly.attemptsUsed)])
        save()
    }

    /// A tap on the Weekly Heart, limited to 12 per second like the mine.
    func punchWeekly() {
        guard var f = weeklyFight, !f.isOver else { return }
        recentTaps.removeAll { clock - $0 > 1 }
        guard recentTaps.count < Config.tapCapPerSecond else { return }
        recentTaps.append(clock)
        f.punches += 1
        if f.faded {
            f.lastHit = 0
            f.lastCrit = false
            weeklyFight = f
            emit(.punch(index: Conquest.heartIndex, crit: false, weak: true, titan: false))
            return
        }
        var chance = weeklyCritChance
        var multiplier = weeklyCritMultiplier
        if f.modifier == .critical {
            chance += WeeklyHeart.brittleCritBonus
            multiplier *= WeeklyHeart.brittleCritFactor
        }
        let returnCrit = f.modifier == .phasing && f.elapsed - f.returnedAt <= WeeklyHeart.phaseReturnCritWindow
        let crit = returnCrit || diceRoll() < chance
        let hit = weeklyPunch * (crit ? multiplier : 1) * weeklyArmourFactor(f.modifier)
        f.lastHit = hit
        f.lastCrit = crit
        weeklyFight = f
        damageWeekly(hit)
        emit(.punch(index: Conquest.heartIndex, crit: crit, weak: false, titan: false))
    }

    /// Ends the fight now; the score so far counts.
    func finishWeeklyFightEarly() {
        guard weeklyFight != nil else { return }
        finishWeeklyFight()
    }

    private func tickWeekly(_ dt: Double) {
        guard var f = weeklyFight else { return }
        f.elapsed += dt
        f.timeLeft = max(0, f.timeLeft - dt)
        if f.modifier == .phasing {
            f.phaseLeft -= dt
            if f.phaseLeft <= 0 {
                f.faded.toggle()
                f.phaseLeft += f.faded ? WeeklyHeart.phaseFadedSeconds : WeeklyHeart.phaseSolidSeconds
                if !f.faded { f.returnedAt = f.elapsed }
                emit(.haunt(faded: f.faded))
            }
        }
        if f.modifier == .regenerating {
            f.hp = min(f.maxHP, f.hp + f.maxHP * WeeklyHeart.regenPerSecond * dt)
        }
        weeklyFight = f
        if !f.faded { damageWeekly(weeklyCrewDPS * weeklyArmourFactor(f.modifier) * dt) }
        if weeklyFight?.isOver == true { finishWeeklyFight() }
    }

    /// Damage past a tier's health carries into the next tier, so a strong player races through the early ones.
    private func damageWeekly(_ amount: Double) {
        // Late-game numbers can overflow to infinity; keep everything finite so the score never turns into NaN.
        guard var f = weeklyFight, amount > 0 else { return }
        let amount = min(amount, WeeklyHeart.maxHit)
        f.damage = min(f.damage + amount, .greatestFiniteMagnitude)
        var left = amount
        var broke = false
        while left >= f.hp && f.hp.isFinite && f.tier < WeeklyHeart.maxTier {
            left -= f.hp
            f.tier += 1
            f.maxHP = WeeklyHeart.hp(tier: f.tier)
            f.hp = f.maxHP
            broke = true
        }
        f.hp -= left
        weeklyFight = f
        if broke { emit(.weeklyTier) }
    }

    private func finishWeeklyFight() {
        guard let f = weeklyFight else { return }
        weeklyFight = nil
        let score = f.score
        let isBest = score > weekly.best
        if isBest { weekly.best = score }
        var earned: [WeeklyMilestone] = []
        for m in WeeklyHeart.milestones where f.tiersBroken >= m.tiers && !weekly.milestones.contains(m.tiers) {
            weekly.milestones.append(m.tiers)
            grantWeekly(m.reward)
            earned.append(m)
        }
        weeklyResult = WeeklyResult(score: score, isBest: isBest, milestones: earned)
        if !earned.isEmpty { emit(.chest(earned.contains { $0.reward.chests[.golden] != nil } ? .legendary : .rare)) }
        analytics.log("weekly_end", ["week": .int(weekly.week), "score": .int(score), "best": .bool(isBest),
                                     "punches": .int(f.punches), "modifier": .string(f.modifier.rawValue)])
        if isBest { onWeeklyBest?(weekly.week, score) }
        save()
    }

    private func grantWeekly(_ reward: WeeklyReward) { grant(reward) }

    /// Pays a finished week's leaderboard reward once. Returns whether it paid.
    @discardableResult
    func claimWeeklyRank(week: Int, rank: Int, total: Int, now: Date = Date()) -> Bool {
        guard rank >= 1, total >= 1, week < WeeklyHeart.week(of: now), !weekly.rankClaimedWeeks.contains(week) else { return false }
        let band = WeeklyHeart.band(rank: rank, total: total)
        grantWeekly(band.reward)
        weekly.rankClaimedWeeks = Array((weekly.rankClaimedWeeks + [week]).suffix(12))
        weekly.lastRank = WeeklyRankResult(week: week, rank: rank, total: total, reward: band.reward, band: band.name)
        toast = Toast(text: "Weekly Heart: #\(rank), \(band.name)! Rewards added")
        emit(.chest(rank <= 3 ? .legendary : .rare))
        analytics.log("weekly_rank", ["week": .int(week), "rank": .int(rank), "total": .int(total), "band": .string(band.name)])
        save()
        return true
    }

    func markWeeklyRankSeen() {
        guard weekly.lastRank?.seen == false else { return }
        weekly.lastRank?.seen = true
        save()
    }
}


extension GameModel {
    // MARK: - Rewards

    /// Pays a reward. An item, pet or cosmetic already owned is turned into levels or Scrap.
    func grant(_ reward: Reward) {
        for (tier, count) in reward.chests { chests[tier.rawValue, default: 0] += count }
        scrap += reward.scrap
        perkCoins += reward.perkCoins
        for (c, count) in reward.consumables { consumables[c.rawValue, default: 0] += count }
        for id in reward.items { grantItem(id) }
        for id in reward.pets { grantPet(id) }
        for id in reward.cosmetics { grantCosmetic(id) }
    }

    /// A seasonal set piece: new at level 1, or two more levels if owned (Scrap once maxed).
    private func grantItem(_ id: String) {
        guard let def = ItemDef.find(id) else { return }
        if let level = items[id] {
            if level < def.rarity.maxLevel {
                items[id] = min(def.rarity.maxLevel, level + Seasons.repeatRelicLevels)
            } else {
                scrap += Seasons.repeatRelicScrap
            }
        } else {
            items[id] = 1
            affixes[id] = Affixes.roll(for: def)
            if equipped[def.slot.rawValue] == nil { equipped[def.slot.rawValue] = id }
        }
    }

    private func grantPet(_ id: String) {
        guard PetDef.find(id) != nil else { return }
        if let level = pets[id] {
            if level < PetDef.maxLevel { pets[id] = level + 1 } else { scrap += PetDef.maxedScrap }
        } else {
            pets[id] = 1
            if activePet == nil { activePet = id }
        }
    }

    private func grantCosmetic(_ id: String) {
        guard let c = Cosmetic.find(id), !cosmetics.contains(id) else { return }
        cosmetics.insert(id)
        // Wear new looks right away, but never switch the app icon without asking.
        if c.kind != .icon, equippedCosmetics[c.kind.rawValue] == nil { equippedCosmetics[c.kind.rawValue] = id }
    }

    // MARK: - Stash

    func consumableCount(_ c: Consumable) -> Int { consumables[c.rawValue, default: 0] }

    /// The chest a rewarded ad would upgrade: your lowest one below Golden.
    var upgradableChest: ChestTier? { [ChestTier.wooden, .iron].first { chestCount($0) > 0 } }
    var stashCount: Int { consumables.values.reduce(0, +) }

    func canUse(_ c: Consumable) -> Bool {
        guard consumableCount(c) > 0, weeklyFight == nil, bossFight == nil else { return false }
        switch c {
        case .feverStarter: return !feverActive
        case .shiftDoubler: return !shiftDoubled
        case .eventRush: return activeEvent != nil
        case .magnet: return run.blocks.contains { $0.isTreasure && !$0.isBroken }
        default: return true
        }
    }

    func use(_ c: Consumable) {
        guard canUse(c) else { return }
        consumables[c.rawValue, default: 0] -= 1
        if consumables[c.rawValue] == 0 { consumables[c.rawValue] = nil }
        switch c {
        case .coinRush: coinRushRemaining += ConsumableRules.coinRushSeconds
        case .feverStarter:
            feverRemaining = feverDuration
            recentPunches.removeAll()
            emit(.fever)
        case .shiftDoubler: shiftDoubled = true
        case .eventRush: eventRushRemaining += ConsumableRules.eventRushSeconds
        case .snowball: snowballRemaining += ConsumableRules.snowballSeconds
        case .goldenPick: goldenRemaining += ConsumableRules.goldenSeconds
        case .timeBell: bellRemaining += ConsumableRules.bellSeconds
        case .firework:
            let open = run.blocks.filter { !$0.isBroken && $0.material != .heartPart }
            if let center = dicePick(open) {
                let row = center.id / Config.columns, col = center.id % Config.columns
                let generation = areaGeneration
                let hit = punchDamage * ConsumableRules.fireworkPunches
                // Cells over the Heart hit the Heart itself, once.
                let targets = Set(run.blocks.filter { $0.id / Config.columns == row || $0.id % Config.columns == col }.map { redirectToHeart($0.id) })
                for target in targets.sorted() where generation == areaGeneration {
                    guard !run.blocks[target].isBroken, run.blocks[target].material != .heartPart else { continue }
                    applyDamage(hit, to: target)
                }
                emit(.boom(index: center.id))
            }
        case .magnet:
            let generation = areaGeneration
            for b in run.blocks where b.isTreasure && !b.isBroken && generation == areaGeneration {
                applyDamage(b.hp + 1, to: b.id, tide: false)
            }
        }
        analytics.log("consumable_used", ["item": .string(c.rawValue)])
        save()
    }

    private func tickConsumables(_ dt: Double) {
        if snowballRemaining > 0 { snowballRemaining = max(0, snowballRemaining - dt) }
        if goldenRemaining > 0 { goldenRemaining = max(0, goldenRemaining - dt) }
        if bellRemaining > 0 { bellRemaining = max(0, bellRemaining - dt) }
        if eventRushRemaining > 0 { eventRushRemaining = max(0, eventRushRemaining - dt) }
    }

    // MARK: - Pets

    func petLevel(_ id: String) -> Int { pets[id, default: 0] }
    var activePetDef: PetDef? { activePet.flatMap { PetDef.find($0) } }

    func petBonus(_ effect: ItemEffect) -> Double {
        guard let pet = activePetDef, pet.effect == effect else { return 0 }
        return pet.value(level: petLevel(pet.id))
    }

    func setActivePet(_ id: String?) {
        guard id == nil || pets[id!] != nil else { return }
        activePet = id
        save()
    }

    // MARK: - Cosmetics

    func owns(cosmetic id: String) -> Bool { cosmetics.contains(id) }
    func equippedCosmetic(_ kind: CosmeticKind) -> Cosmetic? { equippedCosmetics[kind.rawValue].flatMap { Cosmetic.find($0) } }

    /// nil puts the default look back.
    func equipCosmetic(_ id: String?, kind: CosmeticKind) {
        if let id {
            guard cosmetics.contains(id), Cosmetic.find(id)?.kind == kind else { return }
        }
        equippedCosmetics[kind.rawValue] = id
        save()
    }

    // MARK: - Forge

    func shardCount(_ rarity: Rarity) -> Int { shards[String(rarity.rawValue), default: 0] }

    func canForge(_ rarity: Rarity) -> Bool {
        Forge.canForge(from: rarity) && shardCount(rarity) >= Forge.shardsNeeded && scrap >= Forge.scrapCost(rarity)
    }

    /// Three shards and some Scrap: an item one rarity up, one you don't have yet if there is any.
    func forge(_ rarity: Rarity) {
        guard canForge(rarity), let target = Rarity(rawValue: rarity.rawValue + 1) else { return }
        shards[String(rarity.rawValue), default: 0] -= Forge.shardsNeeded
        scrap -= Forge.scrapCost(rarity)
        let pool = ItemDef.chestPool.filter { $0.rarity == target }
        let fresh = pool.filter { items[$0.id] == nil }
        guard let item = dicePick(fresh.isEmpty ? pool : fresh) else { return }
        let isNew = items[item.id] == nil
        var gained = 0
        if isNew {
            items[item.id] = 1
            affixes[item.id] = Affixes.roll(for: item)
            if equipped[item.slot.rawValue] == nil { equipped[item.slot.rawValue] = item.id }
        } else {
            gained = item.rarity.scrapValue
            scrap += gained
            if Forge.canForge(from: item.rarity) { shards[String(item.rarity.rawValue), default: 0] += 1 }
        }
        if target == .legendary { grantCosmetic("title.smith") }
        chestReveal = ChestReveal(tier: target >= .epic ? .golden : .iron, item: item.id, isNew: isNew, scrap: gained)
        emit(.chest(item.rarity))
        analytics.log("forged", ["from": .int(rarity.rawValue), "item": .string(item.id), "new": .bool(isNew)])
        save()
    }

    // MARK: - Seasonal events

    var seasonUnlocked: Bool { record(for: .quarry).bestArea >= Seasons.unlockArea || unlockedZones.count > 1 }

    /// The event running now, if any.
    var activeEvent: SeasonEvent? { Seasons.active(at: now()) }

    /// Progress in the running event (fresh if the save holds an older event's progress). Changes nothing.
    var eventProgress: SeasonState {
        guard let event = activeEvent else { return SeasonState() }
        var state = season
        state.rollOver(to: event)
        state.rollBossDay(Daily.dayKey(now()))
        return state
    }

    var eventTrack: [SeasonStep] { activeEvent.map { Seasons.track(for: $0.season) } ?? [] }

    /// Adds event currency: it fills the track and the wallet.
    private func addEventCurrency(_ amount: Int, event: SeasonEvent) {
        season.rollOver(to: event)
        season.points += amount
        season.wallet += amount
    }

    func collectEventPoints(_ which: SeasonID, at index: Int) {
        guard let event = activeEvent, event.season == which else { return }
        var points = Seasons.points(area: run.area, coinRush: coinRushActive, pass: season.event == event.id && season.premium)
        if eventRushRemaining > 0 { points *= 2 }
        addEventCurrency(points, event: event)
        addFloater(index, text: "+\(points) \(which.currency)", kind: .crit)
    }

    func canClaimEventStep(_ step: SeasonStep, premium: Bool) -> Bool {
        guard activeEvent != nil else { return false }
        return Self.canClaim(step, premium: premium, state: eventProgress)
    }

    private static func canClaim(_ step: SeasonStep, premium: Bool, state: SeasonState) -> Bool {
        guard state.points >= step.points else { return false }
        return premium ? state.premium && !state.premiumClaimed.contains(step.index) : !state.claimed.contains(step.index)
    }

    /// Steps reached but not yet claimed, for the badge. Reads the event state once.
    var readyEventSteps: Int {
        guard activeEvent != nil else { return 0 }
        let state = eventProgress
        return eventTrack.reduce(0) { n, step in
            n + (Self.canClaim(step, premium: false, state: state) ? 1 : 0) + (Self.canClaim(step, premium: true, state: state) ? 1 : 0)
        }
    }

    func claimEventStep(_ step: SeasonStep, premium: Bool) {
        guard canClaimEventStep(step, premium: premium), let event = activeEvent else { return }
        season.rollOver(to: event)
        let reward = premium ? step.premium : step.free
        grant(reward)
        if premium { season.premiumClaimed.append(step.index) } else { season.claimed.append(step.index) }
        let special = !reward.items.isEmpty || !reward.pets.isEmpty || !reward.cosmetics.isEmpty
        emit(.chest(reward.chests[.golden] != nil || special ? .legendary : .rare))
        toast = Toast(text: "Got \(reward.headline)!")
        analytics.log("event_step", ["event": .string(event.id), "step": .int(step.index), "premium": .bool(premium)])
        save()
    }

    func claimAllEventSteps() {
        for step in eventTrack {
            if canClaimEventStep(step, premium: false) { claimEventStep(step, premium: false) }
            if canClaimEventStep(step, premium: true) { claimEventStep(step, premium: true) }
        }
    }

    /// Unlocks the premium track of the running event. Returns false when there is nothing to unlock,
    /// and the purchase then pays its fallback (3 Golden Chests) instead.
    func grantEventPass() -> Bool {
        guard let event = activeEvent else { return false }
        season.rollOver(to: event)
        guard !season.premium else { return false }
        season.premium = true
        toast = Toast(text: "Event Pass unlocked!")
        emit(.chest(.legendary))
        return true
    }

    // MARK: Event shop

    func canBuy(_ item: Seasons.ShopItem) -> Bool {
        guard activeEvent != nil, eventProgress.wallet >= item.price else { return false }
        return item.reward.cosmetics.allSatisfy { !cosmetics.contains($0) }
    }

    func buy(_ item: Seasons.ShopItem) {
        guard canBuy(item), let event = activeEvent else { return }
        season.rollOver(to: event)
        season.wallet -= item.price
        grant(item.reward)
        emit(.purchase)
        analytics.log("event_shop", ["event": .string(event.id), "item": .string(item.id)])
        save()
    }

    // MARK: Event boss

    var freeBossTriesLeft: Int { max(0, Seasons.bossFreeTriesPerDay - eventProgress.bossTries) }
    var bossTriesLeft: Int {
        let s = eventProgress
        return max(0, Seasons.bossFreeTriesPerDay + s.bossBonusTries - s.bossTries)
    }

    func startBossFight() {
        guard let event = activeEvent, seasonUnlocked, bossFight == nil, weeklyFight == nil, bossTriesLeft > 0 else { return }
        season.rollOver(to: event)
        season.rollBossDay(Daily.dayKey(now()))
        guard !season.bossDefeated else { return }
        // Health is set by your punch at the first attack, so the boss is a fair fight at any stage.
        if season.bossMaxHP == 0 { season.bossMaxHP = min(WeeklyHeart.maxHit, (weeklyPunch * Seasons.bossHits).rounded()) }
        season.bossTries += 1
        resetTransientInput()
        bossResult = nil
        bossFight = BossFight(event: event.id, season: event.season)
        analytics.log("boss_start", ["event": .string(event.id), "share": .double(season.bossDamage / season.bossMaxHP)])
        save()
    }

    func punchBoss() {
        guard var f = bossFight, !f.isOver else { return }
        recentTaps.removeAll { clock - $0 > 1 }
        guard recentTaps.count < Config.tapCapPerSecond else { return }
        recentTaps.append(clock)
        let crit = diceRoll() < weeklyCritChance
        let hit = weeklyPunch * (crit ? weeklyCritMultiplier : 1)
        f.punches += 1
        f.lastHit = hit
        f.lastCrit = crit
        bossFight = f
        damageBoss(hit)
        emit(.punch(index: Conquest.heartIndex, crit: crit, weak: false, titan: false))
    }

    func finishBossFightEarly() {
        guard bossFight != nil else { return }
        finishBossFight()
    }

    private func tickBoss(_ dt: Double) {
        guard var f = bossFight else { return }
        f.timeLeft = max(0, f.timeLeft - dt)
        bossFight = f
        damageBoss(weeklyCrewDPS * dt)
        if bossFight?.isOver == true || season.bossDefeated { finishBossFight() }
    }

    private func damageBoss(_ amount: Double) {
        guard var f = bossFight, amount > 0, !season.bossDefeated else { return }
        let dealt = min(amount, season.bossMaxHP - season.bossDamage)
        f.damage += dealt
        season.bossDamage += dealt
        bossFight = f
    }

    /// Bosses pay at a third, two thirds and the kill.
    /// Bosses pay for the event the fight started in, even if a new event began during it.
    private func finishBossFight() {
        guard let f = bossFight else { return }
        bossFight = nil
        guard season.event == f.event else { bossResult = BossResult(damage: f.damage, phases: [], defeated: false, season: f.season); return }
        let share = season.bossMaxHP > 0 ? season.bossDamage / season.bossMaxHP : 0
        let rewards = Seasons.bossRewards(f.season)
        var paid: [Int] = []
        for (i, needed) in Seasons.bossPhaseShares.enumerated() where share >= needed - 1e-9 && !season.bossPhases.contains(i + 1) {
            season.bossPhases.append(i + 1)
            grant(rewards[i])
            paid.append(i + 1)
        }
        if !paid.isEmpty { emit(.heartDefeated) }
        bossResult = BossResult(damage: f.damage, phases: paid, defeated: season.bossDefeated, season: f.season)
        analytics.log("boss_end", ["event": .string(f.event), "share": .double(share), "phases": .int(paid.count)])
        save()
    }

    // MARK: Mini-mine

    /// The mini-mine's blocks, made on first visit.
    var miniBlocks: [Block] {
        let s = eventProgress
        guard let event = activeEvent else { return [] }
        return s.miniBlocks.isEmpty ? Seasons.miniBlocks(event.season, depth: s.miniDepth) : s.miniBlocks
    }

    var miniPickDamage: Double { Seasons.miniPickDamage(level: eventProgress.miniPick) }
    var miniHelperDPS: Double { Double(eventProgress.miniHelpers) * miniPickDamage * Seasons.miniHelperShare }

    private func prepareMini() -> SeasonEvent? {
        guard let event = activeEvent else { return nil }
        season.rollOver(to: event)
        if season.miniBlocks.isEmpty { season.miniBlocks = Seasons.miniBlocks(event.season, depth: season.miniDepth) }
        return event
    }

    func punchMini(_ index: Int) {
        recentTaps.removeAll { clock - $0 > 1 }
        guard recentTaps.count < Config.tapCapPerSecond else { return }
        recentTaps.append(clock)
        guard let event = prepareMini(), season.miniBlocks.indices.contains(index), !season.miniBlocks[index].isBroken else { return }
        damageMini(miniPickDamage, at: index, event: event)
        emit(.punch(index: index, crit: false, weak: false, titan: false))
    }

    /// Helpers hit the weakest block, a second's worth at a time, only while the mini-mine is open.
    func tickMini(_ dt: Double) {
        guard miniHelperDPS > 0, let event = prepareMini(),
              let target = season.miniBlocks.filter({ !$0.isBroken }).min(by: { $0.hp < $1.hp }) else { return }
        damageMini(miniHelperDPS * dt, at: target.id, event: event)
    }

    private func damageMini(_ amount: Double, at index: Int, event: SeasonEvent) {
        season.miniBlocks[index].hp = max(0, season.miniBlocks[index].hp - amount)
        guard season.miniBlocks[index].isBroken else { return }
        season.wallet += Seasons.miniBlockCoins(depth: season.miniDepth)
        emit(.blockBreak(index: index, ore: event.season.ore, treasure: false, lucky: false))
        if season.miniBlocks.allSatisfy(\.isBroken) {
            let points = Seasons.miniClearPoints(depth: season.miniDepth)
            season.points += points
            toast = Toast(text: "\(event.season.miniMineName) level \(season.miniDepth) cleared: +\(points) \(event.season.currency)")
            season.miniDepth += 1
            season.miniBlocks = Seasons.miniBlocks(event.season, depth: season.miniDepth)
            emit(.areaClear)
            save()
        }
    }

    func buyMiniPick() {
        guard prepareMini() != nil else { return }
        let cost = Seasons.miniPickCost(level: season.miniPick)
        guard season.wallet >= cost else { return }
        season.wallet -= cost
        season.miniPick += 1
        emit(.purchase)
        save()
    }

    func buyMiniHelper() {
        guard prepareMini() != nil, season.miniHelpers < Seasons.miniHelperMax else { return }
        let cost = Seasons.miniHelperCost(count: season.miniHelpers)
        guard season.wallet >= cost else { return }
        season.wallet -= cost
        season.miniHelpers += 1
        emit(.purchase)
        save()
    }
}

// MARK: - Dice

extension GameModel {
    /// Every roll made in play, in 0..<1. Director launches (Debug only) draw them from the clip's seed.
    private func diceRoll() -> Double {
        #if DEBUG
        if let value = Director.shared.nextRoll() { return value }
        #endif
        return Double.random(in: 0..<1)
    }

    private func dicePick<T>(_ items: [T]) -> T? {
        #if DEBUG
        if Director.shared.isActive, !items.isEmpty { return items[min(items.count - 1, Int(diceRoll() * Double(items.count)))] }
        #endif
        return items.randomElement()
    }

    private func diceShuffled<T>(_ items: [T]) -> [T] {
        #if DEBUG
        if Director.shared.isActive {
            var rest = items, out: [T] = []
            while !rest.isEmpty { out.append(rest.remove(at: min(rest.count - 1, Int(diceRoll() * Double(rest.count))))) }
            return out
        }
        #endif
        return items.shuffled()
    }
}

#if DEBUG
// MARK: - Director mode hooks (Debug builds only, see Director/DirectorMode.swift)

extension GameModel {
    /// Your punch before Fever, Focus and crits, in the active zone.
    var directorBasePunch: Double { basePunch(for: run, in: zone) }

    /// The crew's damage per second at full swing (a Blaster lands on about 4 blocks).
    var directorMinerDPS: Double {
        MinerKind.allCases.reduce(0) { sum, kind in
            sum + Double(minerCount(kind)) * minerHit * kind.damageFactor * (kind == .blaster ? 4 : 1) / minerInterval(kind, run: run)
        }
    }

    var directorAreaGeneration: Int { areaGeneration }
    var directorVentTimer: Double { ventTimer }
    var directorTideTimer: Double { tideTimer }

    func directorSetStar(_ star: StarPerk, level: Int) { stars[star.rawValue] = max(0, level) }
    func directorSetLevel(_ kind: UpgradeKind, _ level: Int) { run.setLevel(kind, level) }

    /// Replaces the area's layout (same area, same generator), e.g. to pick a crystal-rich one.
    func directorSetBlocks(_ blocks: [Block]) {
        run.blocks = blocks
        hitPulses = [:]
        minerTargets = []
        regrowAfter = [:]
        regrowCap = [:]
    }

    func directorSetHP(_ index: Int, _ hp: Double) {
        guard run.blocks.indices.contains(index), !run.blocks[index].isBroken else { return }
        run.blocks[index].hp = min(run.blocks[index].maxHP, max(1, hp.rounded()))
    }

    /// Sunken Ruins: seconds already counted toward the next high tide.
    func directorSetTideTimer(_ seconds: Double) {
        guard tideRemaining == 0 else { return }
        tideTimer = min(Tide.interval, max(0, seconds))
        tideCharge = min(1, tideTimer / Tide.interval)
    }

    /// Magma Depths: seconds already counted toward the next vent eruption.
    func directorSetVentTimer(_ seconds: Double) {
        ventTimer = min(Magma.ventInterval, max(0, seconds))
        ventCharge = min(1, ventTimer / Magma.ventInterval)
    }
}
#endif
