import Foundation

/// Seasonal events. While one runs, its event block appears in every zone; breaking those earns the event
/// currency, which fills a 20-step reward track. An optional Event Pass unlocks a second, richer track.
enum SeasonID: String, Codable, CaseIterable, Identifiable {
    case harvest, frostfall, lantern, bloom, splash, goldrush

    var id: String { rawValue }

    var name: String {
        switch self {
        case .harvest: "Haunted Harvest"
        case .frostfall: "Frostfall"
        case .lantern: "Lantern Festival"
        case .bloom: "Spring Bloom"
        case .splash: "Sunny Splash"
        case .goldrush: "Gold Rush"
        }
    }

    var tagline: String {
        switch self {
        case .harvest: "Pumpkins have sprouted in every mine. Smash them for Candy!"
        case .frostfall: "Winter has frozen the mines. Crack the Frost Shards for Snowflakes!"
        case .lantern: "Red lanterns light up every mine. Break them for Lucky Coins!"
        case .bloom: "Flowers are pushing up through the rock. Pick the Bloom Buds for Petals!"
        case .splash: "The tide washed seashells into every mine. Crack them for Pearls!"
        case .goldrush: "Lucky Nuggets glitter in every wall. Dig them out for Gold Dust!"
        }
    }

    var currency: String {
        switch self {
        case .harvest: "Candy"
        case .frostfall: "Snowflakes"
        case .lantern: "Lucky Coins"
        case .bloom: "Petals"
        case .splash: "Pearls"
        case .goldrush: "Gold Dust"
        }
    }

    /// SF Symbol for the currency and the event button.
    var symbol: String {
        switch self {
        case .harvest: "leaf.fill"
        case .frostfall: "snowflake"
        case .lantern: "sparkles"
        case .bloom: "camera.macro"
        case .splash: "sun.max.fill"
        case .goldrush: "circle.hexagongrid.fill"
        }
    }

    var ore: Ore {
        switch self {
        case .harvest: .pumpkin
        case .frostfall: .frostShard
        case .lantern: .redLantern
        case .bloom: .bloomBud
        case .splash: .seashell
        case .goldrush: .luckyNugget
        }
    }

    /// The three-piece set on the free track, in the order it is handed out.
    var setPieces: [String] {
        switch self {
        case .harvest: ["candyBelt", "pumpkinCharm", "scarecrowHat"]
        case .frostfall: ["icicleCharm", "frostCrown", "frostfallBoots"]
        case .lantern: ["silkSash", "dragonHelm", "jadeDragon"]
        case .bloom: ["vineBelt", "petalCharm", "flowerCrown"]
        case .splash: ["shellCharm", "surfBoots", "sunHat"]
        case .goldrush: ["panBelt", "miningBoots", "prospectorHat"]
        }
    }

    var bossName: String {
        switch self {
        case .harvest: "The Pumpkin Lord"
        case .frostfall: "The Frost Giant"
        case .lantern: "The Golden Dragon"
        case .bloom: "The Thorn Queen"
        case .splash: "The Kraken"
        case .goldrush: "The Gold Golem"
        }
    }

    /// The mini-mine that runs beside the main game during the event.
    var miniMineName: String {
        switch self {
        case .harvest: "Candy Mine"
        case .frostfall: "Ice Cave"
        case .lantern: "Lantern Vault"
        case .bloom: "Flower Mine"
        case .splash: "Tide Pools"
        case .goldrush: "Panning Creek"
        }
    }

    var accent: UInt32 {
        switch self {
        case .harvest: 0xFF8A2A
        case .frostfall: 0x8FD8FF
        case .lantern: 0xE8343A
        case .bloom: 0xFF8AC8
        case .splash: 0x3FD8E8
        case .goldrush: 0xE0A82A
        }
    }

    /// Lunar New Year, which moves every year. The festival runs from a week before to the Lantern Festival (day 15).
    private static let lunarNewYear: [Int: (month: Int, day: Int)] = [
        2027: (2, 6), 2028: (1, 26), 2029: (2, 13), 2030: (2, 3), 2031: (1, 23), 2032: (2, 11),
    ]

    /// This event's run in a given year (UTC), if it has one.
    func window(year: Int) -> DateInterval? {
        switch self {
        case .harvest:
            return Seasons.interval(from: (year, 10, 17), to: (year, 11, 8))
        case .frostfall:
            return Seasons.interval(from: (year, 12, 5), to: (year + 1, 1, 6))
        case .lantern:
            guard let ny = Self.lunarNewYear[year], let day = Seasons.date(year, ny.month, ny.day) else { return nil }
            return DateInterval(start: day.addingTimeInterval(-7 * 86_400), end: day.addingTimeInterval(15 * 86_400))
        case .bloom:
            return Seasons.interval(from: (year, 3, 20), to: (year, 4, 21))
        case .splash:
            return Seasons.interval(from: (year, 6, 10), to: (year, 7, 11))
        case .goldrush:
            return Seasons.interval(from: (year, 8, 20), to: (year, 9, 21))
        }
    }
}

/// One run of an event, e.g. Frostfall 2026.
struct SeasonEvent: Equatable, Identifiable {
    let season: SeasonID
    let year: Int
    let window: DateInterval
    /// An encore reruns an earlier event in the gap between two others, so its set, pet and looks come round again.
    var encore = false

    var id: String {
        guard encore else { return "\(season.rawValue)-\(year)" }
        let c = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: window.start)
        return String(format: "%@-encore-%04d%02d%02d", season.rawValue, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    var name: String { encore ? "\(season.name) Encore" : season.name }
}

/// One step of the reward track.
struct SeasonStep: Identifiable, Equatable {
    let index: Int
    /// Event currency needed.
    let points: Int
    let free: Reward
    let premium: Reward
    var id: Int { index }
}

/// Progress in the current (or last) event.
struct SeasonState: Codable, Equatable {
    /// `SeasonEvent.id` this progress belongs to.
    var event = ""
    var points = 0
    var claimed: [Int] = []
    var premiumClaimed: [Int] = []
    var premium = false
    /// Spendable currency (the mini-mine and the event shop). `points` only ever grows; it fills the track.
    var wallet = 0
    /// Event boss: health locked at the first fight, damage dealt so far, phases paid, tries today.
    var bossMaxHP = 0.0
    var bossDamage = 0.0
    var bossPhases: [Int] = []
    var bossDay = ""
    var bossTries = 0
    var bossBonusTries = 0
    /// Mini-mine.
    var miniDepth = 1
    var miniBlocks: [Block] = []
    var miniPick = 0
    var miniHelpers = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        event = try c.decodeIfPresent(String.self, forKey: .event) ?? ""
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        claimed = try c.decodeIfPresent([Int].self, forKey: .claimed) ?? []
        premiumClaimed = try c.decodeIfPresent([Int].self, forKey: .premiumClaimed) ?? []
        premium = try c.decodeIfPresent(Bool.self, forKey: .premium) ?? false
        wallet = try c.decodeIfPresent(Int.self, forKey: .wallet) ?? 0
        bossMaxHP = try c.decodeIfPresent(Double.self, forKey: .bossMaxHP) ?? 0
        bossDamage = try c.decodeIfPresent(Double.self, forKey: .bossDamage) ?? 0
        bossPhases = try c.decodeIfPresent([Int].self, forKey: .bossPhases) ?? []
        bossDay = try c.decodeIfPresent(String.self, forKey: .bossDay) ?? ""
        bossTries = try c.decodeIfPresent(Int.self, forKey: .bossTries) ?? 0
        bossBonusTries = try c.decodeIfPresent(Int.self, forKey: .bossBonusTries) ?? 0
        miniDepth = try c.decodeIfPresent(Int.self, forKey: .miniDepth) ?? 1
        miniBlocks = try c.decodeIfPresent([Block].self, forKey: .miniBlocks) ?? []
        miniPick = try c.decodeIfPresent(Int.self, forKey: .miniPick) ?? 0
        miniHelpers = try c.decodeIfPresent(Int.self, forKey: .miniHelpers) ?? 0
    }

    /// A new day's boss tries.
    mutating func rollBossDay(_ today: String) {
        guard bossDay != today else { return }
        bossDay = today
        bossTries = 0
        bossBonusTries = 0
    }

    var bossDefeated: Bool { bossMaxHP > 0 && bossDamage >= bossMaxHP }

    /// A different event starts from zero.
    mutating func rollOver(to event: SeasonEvent) {
        guard self.event != event.id else { return }
        self = SeasonState()
        self.event = event.id
    }
}

enum Seasons {
    /// Event blocks per area (never in a Heart area).
    static let blocksPerArea = 2
    /// Opens with the daily reward, once the player knows the basics.
    static let unlockArea = 6
    /// Event Pass holders earn this much more currency.
    static let passBonus = 0.5
    /// A relic you already own from an earlier year gains levels instead.
    static let repeatRelicLevels = 2
    static let repeatRelicScrap = 500

    private static var utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date? { utc.date(from: DateComponents(year: y, month: m, day: d)) }

    static func interval(from a: (Int, Int, Int), to b: (Int, Int, Int)) -> DateInterval? {
        guard let s = date(a.0, a.1, a.2), let e = date(b.0, b.1, b.2) else { return nil }
        return DateInterval(start: s, end: e)
    }

    /// The event running at `date`, if any. The end is exclusive.
    /// Gaps shorter than this between two events stay empty.
    static let minimumEncoreDays = 7.0

    /// Every dated event from the year before to the year after `date`, in order.
    private static func dated(around date: Date) -> [SeasonEvent] {
        let year = utc.component(.year, from: date)
        return (year - 1...year + 1).flatMap { y in
            SeasonID.allCases.compactMap { s in s.window(year: y).map { SeasonEvent(season: s, year: y, window: $0) } }
        }
        .sorted { $0.window.start < $1.window.start }
    }

    /// The event running at `date`: a dated event, or an encore filling the gap between two. The end is exclusive.
    /// Views ask many times a second, so the answer is cached until the event (or gap) it found is over.
    static func active(at date: Date) -> SeasonEvent? {
        if let cached = activeCache, cached.valid.start <= date, date < cached.valid.end { return cached.event }
        let event = computeActive(at: date)
        activeCache = (event?.window ?? DateInterval(start: date, duration: 60), event)
        return event
    }
    private static var activeCache: (valid: DateInterval, event: SeasonEvent?)?

    private static func computeActive(at date: Date) -> SeasonEvent? {
        let all = dated(around: date)
        if let event = all.first(where: { $0.window.start <= date && date < $0.window.end }) { return event }
        guard let before = all.last(where: { $0.window.end <= date }), let after = all.first(where: { $0.window.start > date }) else { return nil }
        let gap = DateInterval(start: before.window.end, end: after.window.start)
        guard gap.duration >= minimumEncoreDays * 86_400 else { return nil }
        return SeasonEvent(season: encoreSeason(between: before.season, and: after.season, gapStart: gap.start),
                           year: utc.component(.year, from: gap.start), window: gap, encore: true)
    }

    /// Reruns the event players have gone longest without (counting earlier encores), never the one that just
    /// ended or the one coming next. Worked out by walking the calendar forward from the first event, so every
    /// gap always gets the same pick.
    static func encoreSeason(between before: SeasonID, and after: SeasonID, gapStart: Date) -> SeasonID {
        if let pick = encoreCache[gapStart] { return pick }
        let year = utc.component(.year, from: gapStart)
        let all = (firstYear...max(firstYear, year + 1)).flatMap { y in
            SeasonID.allCases.compactMap { s in s.window(year: y).map { SeasonEvent(season: s, year: y, window: $0) } }
        }
        .sorted { $0.window.start < $1.window.start }
        var seen: [SeasonID: Date] = [:]
        for (a, b) in zip(all, all.dropFirst()) {
            seen[a.season] = a.window.end
            guard b.window.start.timeIntervalSince(a.window.end) >= minimumEncoreDays * 86_400 else { continue }
            let pick = SeasonID.allCases.filter { $0 != a.season && $0 != b.season }
                .min { (seen[$0] ?? .distantPast, $0.rawValue) < (seen[$1] ?? .distantPast, $1.rawValue) }!
            encoreCache[a.window.end] = pick
            seen[pick] = b.window.start
            if a.window.end >= gapStart { break }
        }
        return encoreCache[gapStart] ?? SeasonID.allCases.first { $0 != before && $0 != after }!
    }

    /// The calendar starts here; encores are picked by replaying it from this year.
    private static let firstYear = 2026
    private static var encoreCache: [Date: SeasonID] = [:]

    /// The next event to start after `date`.
    static func next(after date: Date) -> SeasonEvent? {
        let current = active(at: date)
        let probe = current.map { $0.window.end } ?? date.addingTimeInterval(1)
        if current == nil, let soonest = dated(around: date).first(where: { $0.window.start > date }) {
            // Inside a gap too short for an encore: the next dated event.
            return soonest
        }
        return active(at: probe)
    }

    /// Currency for one event block: deeper areas pay more.
    static func points(area: Int, coinRush: Bool, pass: Bool) -> Int {
        var p = 1 + area / 40
        if coinRush { p *= 2 }
        if pass { p += max(1, Int(Double(p) * passBonus)) }
        return p
    }

    /// Swaps a few ordinary blocks for the event block. Same health and reward, so balance is untouched.
    static func sprinkle(_ season: SeasonID, into blocks: [Block], seed: UInt64) -> [Block] {
        var candidates = blocks.indices.filter { i in
            let m = blocks[i].material
            return !m.isTreasure && m != .heart && m != .heartPart && !m.isGhost && m != .vent && m != .cursedUrn
        }
        var out = blocks
        var state = seed | 1
        for _ in 0..<min(blocksPerArea, candidates.count) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let pick = candidates.remove(at: Int((state >> 33) % UInt64(candidates.count)))
            let b = out[pick]
            out[pick] = Block(id: b.id, material: season.ore, maxHP: b.maxHP, hp: b.hp, armor: b.armor, reward: b.reward)
        }
        return out
    }

    private static func r(_ chests: [ChestTier: Int] = [:], scrap: Int = 0, pc: Int = 0, use: [Consumable: Int] = [:],
                          items: [String] = [], pets: [String] = [], cosmetics: [String] = []) -> Reward {
        Reward(chests: chests, scrap: scrap, perkCoins: pc, consumables: use, items: items, pets: pets, cosmetics: cosmetics)
    }

    static let trackPoints = [10, 25, 45, 70, 100, 135, 175, 220, 270, 325, 385, 450, 520, 600, 690, 790, 900, 1_020, 1_150, 1_300]

    /// 20 steps. The free track builds the event's three-piece set between chests and consumables;
    /// the pass track holds the event's fist skin, break effect, pet and app icon. About 9 hours of
    /// active play fills it; an event lasts about 3 weeks.
    static func track(for season: SeasonID) -> [SeasonStep] {
        if let cached = trackCache[season] { return cached }
        let steps = buildTrack(for: season)
        trackCache[season] = steps
        return steps
    }
    private static var trackCache: [SeasonID: [SeasonStep]] = [:]

    private static func buildTrack(for season: SeasonID) -> [SeasonStep] {
        let set = season.setPieces
        let fist = Cosmetic.of(.fist, season: season)?.id ?? ""
        let burst = Cosmetic.of(.burst, season: season)?.id ?? ""
        let icon = Cosmetic.of(.icon, season: season)?.id ?? ""
        let pet = PetDef.of(season)?.id ?? ""
        let free: [Reward] = [
            r([.wooden: 1]), r(use: [.coinRush: 1]), r(scrap: 80), r(use: [.snowball: 2]), r([.iron: 1]),
            r(pc: 40), r(items: [set[0]]), r(use: [.firework: 2]), r([.iron: 1]), r([.golden: 1]),
            r(use: [.feverStarter: 2]), r(scrap: 200), r(use: [.magnet: 2]), r(items: [set[1]]), r([.golden: 1]),
            r(use: [.timeBell: 2]), r(pc: 100), r(use: [.eventRush: 1]), r([.golden: 1]), r([.golden: 1], items: [set[2]]),
        ]
        let premium: [Reward] = [
            r(cosmetics: [fist]), r([.iron: 2]), r(use: [.coinRush: 2]), r(scrap: 200), r(cosmetics: [burst]),
            r([.golden: 1]), r(use: [.goldenPick: 2]), r(pc: 100), r([.golden: 1]), r(pets: [pet]),
            r(scrap: 400), r(use: [.shiftDoubler: 2]), r([.golden: 1]), r(pc: 150), r([.golden: 1], cosmetics: [icon]),
            r(scrap: 500), r([.golden: 2]), r(pc: 200), r(use: [.timeBell: 2, .goldenPick: 2]), r([.golden: 3], pc: 500),
        ]
        return trackPoints.indices.map { i in SeasonStep(index: i + 1, points: trackPoints[i], free: free[i], premium: premium[i]) }
    }

    // MARK: Event boss

    /// The boss has this many of your punches of health, locked at the first fight, so every player can win.
    static let bossHits = 2_500.0
    static let bossFreeTriesPerDay = 2
    static let bossAdTriesPerDay = 2
    static let bossFightSeconds = 30.0
    /// Health lost (share of max) at which each phase pays.
    static let bossPhaseShares = [0.33, 0.66, 1.0]

    static func bossRewards(_ season: SeasonID) -> [Reward] {
        [
            r([.iron: 2], use: [.coinRush: 1]),
            r(use: [.snowball: 2], pets: [PetDef.of(season)?.id ?? ""]),
            r([.golden: 3], cosmetics: [Cosmetic.of(.title, season: season)?.id ?? "", "fist.heart"]),
        ]
    }

    // MARK: Mini-mine

    static let miniBaseHP = 4.0
    static let miniHPGrowth = 1.22
    static let miniHelperMax = 5
    /// Each helper hits once a second for this share of your pick.
    static let miniHelperShare = 0.4

    static func miniHP(depth: Int) -> Double { (miniBaseHP * pow(miniHPGrowth, Double(depth - 1))).rounded(.up) }
    static func miniPickDamage(level: Int) -> Double { pow(1.6, Double(level)) }
    static func miniPickCost(level: Int) -> Int { Int((15 * pow(1.7, Double(level))).rounded()) }
    static func miniHelperCost(count: Int) -> Int { Int((40 * pow(2.2, Double(count))).rounded()) }
    /// Wallet coins per block broken in the mini-mine.
    static func miniBlockCoins(depth: Int) -> Int { 1 + depth / 4 }
    /// Track points for clearing a mini-mine level.
    static func miniClearPoints(depth: Int) -> Int { 3 + depth / 3 }

    static func miniBlocks(_ season: SeasonID, depth: Int) -> [Block] {
        let hp = miniHP(depth: depth)
        return (0..<Config.blocksPerArea).map { Block(id: $0, material: season.ore, maxHP: hp, hp: hp, armor: 0, reward: 0) }
    }

    // MARK: Event shop

    struct ShopItem: Identifiable, Equatable {
        let id: String
        let price: Int
        let reward: Reward
    }

    static let shop: [ShopItem] = [
        ShopItem(id: "snowball", price: 30, reward: r(use: [.snowball: 1])),
        ShopItem(id: "firework", price: 40, reward: r(use: [.firework: 1])),
        ShopItem(id: "magnet", price: 50, reward: r(use: [.magnet: 1])),
        ShopItem(id: "goldenPick", price: 60, reward: r(use: [.goldenPick: 1])),
        ShopItem(id: "coinRush", price: 60, reward: r(use: [.coinRush: 1])),
        ShopItem(id: "iron", price: 80, reward: r([.iron: 1])),
        ShopItem(id: "golden", price: 250, reward: r([.golden: 1])),
        ShopItem(id: "goldRain", price: 600, reward: r(cosmetics: ["burst.gold"])),
        ShopItem(id: "golem", price: 450, reward: r(pets: ["golem"])),
        ShopItem(id: "fox", price: 450, reward: r(pets: ["fox"])),
    ]
}

/// A 30-second attack on the event boss. Damage carries over between fights until the boss falls.
struct BossFight: Equatable {
    /// The event this attack belongs to.
    let event: String
    let season: SeasonID
    var timeLeft = Seasons.bossFightSeconds
    var damage = 0.0
    var punches = 0
    var lastHit = 0.0
    var lastCrit = false
    var isOver: Bool { timeLeft <= 0 }
}

/// What one boss attack did.
struct BossResult: Identifiable, Equatable {
    let id = UUID()
    let damage: Double
    /// Phases (1–3) this attack completed, with their rewards.
    let phases: [Int]
    let defeated: Bool
    let season: SeasonID
}
