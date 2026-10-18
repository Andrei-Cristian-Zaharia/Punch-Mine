import Foundation

struct Block: Codable, Identifiable, Equatable {
    let id: Int
    let material: Ore
    let maxHP: Double
    var hp: Double
    let armor: Double
    let reward: Double

    var isBroken: Bool { hp <= 0 }
    var isTreasure: Bool { material.isTreasure }
    var hpFraction: Double { maxHP > 0 ? max(0, hp) / maxHP : 0 }

    /// 0 = intact, 1–3 = visible crack stages at 75 / 50 / 25% HP.
    var crackStage: Int {
        switch hpFraction {
        case 0.75...: 0
        case 0.5..<0.75: 1
        case 0.25..<0.5: 2
        default: 3
        }
    }
}

/// One zone's run. Everything here resets when the zone is prestiged.
struct ZoneRun: Codable {
    var area = 1
    /// Deepest area cleared in this run; drives the prestige reward.
    var maxCleared = 0
    var coins: Double = 0
    var lifetimeCoins: Double = 0
    var levels: [String: Int] = [:]
    var toolIndex = -1
    var blocks: [Block] = []
    var treasureCollapse: Double?
    /// When the player last left this zone; background mining is counted from here.
    var leftAt: Date?
    // Playtest timers
    var playSeconds: Double = 0
    var areaSeconds: Double = 0
    var areaPunches = 0
    var returnLogged = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        area = try c.decode(Int.self, forKey: .area)
        maxCleared = try c.decodeIfPresent(Int.self, forKey: .maxCleared) ?? area - 1
        coins = try c.decode(Double.self, forKey: .coins)
        lifetimeCoins = try c.decode(Double.self, forKey: .lifetimeCoins)
        levels = try c.decode([String: Int].self, forKey: .levels)
        toolIndex = try c.decode(Int.self, forKey: .toolIndex)
        blocks = try c.decode([Block].self, forKey: .blocks)
        treasureCollapse = try c.decodeIfPresent(Double.self, forKey: .treasureCollapse)
        leftAt = try c.decodeIfPresent(Date.self, forKey: .leftAt)
        playSeconds = try c.decodeIfPresent(Double.self, forKey: .playSeconds) ?? 0
        areaSeconds = try c.decodeIfPresent(Double.self, forKey: .areaSeconds) ?? 0
        areaPunches = try c.decodeIfPresent(Int.self, forKey: .areaPunches) ?? 0
        returnLogged = try c.decodeIfPresent(Bool.self, forKey: .returnLogged) ?? false
    }

    func level(_ kind: UpgradeKind) -> Int { levels[kind.rawValue, default: 0] }
    mutating func setLevel(_ kind: UpgradeKind, _ value: Int) { levels[kind.rawValue] = value }
}

enum DamageNumbers: String, Codable, CaseIterable, Identifiable {
    case all, critsOnly, off
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "On"
        case .critsOnly: "Crits only"
        case .off: "Off"
        }
    }
}

enum Vibration: String, Codable, CaseIterable, Identifiable {
    case off, light, strong
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct Settings: Codable, Equatable {
    var reducedMotion = false
    var vibration = Vibration.light
    var damageNumbers = DamageNumbers.all
    var shortNumbers = true
    /// When on, one tap keeps punching that block until it breaks.
    var tapToAutoPunch = false
}

struct SaveData: Codable {
    var version = 4
    var runs: [String: ZoneRun]
    var records: [String: ZoneRecord]
    var seeds: [String: UInt64]
    var activeZone: ZoneID
    var unlockedZones: [ZoneID]
    var holdUnlocked: Bool
    var settings: Settings
    var perks: [String: Int]
    var perkCoins: Int
    var lastActive: Date?
    var coinRushRemaining: Double = 0
    var adLedger = AdLedger()
    /// Hearts of the Quarry defeated at record depths: 1 = Quarry Crown, each more = a Crown Star.
    var heartsDefeated = 0
    var deepestHeart = 0
    /// Account-wide gear: item id → level, slot → equipped item id, chest tier → count.
    var items: [String: Int] = [:]
    var equipped: [String: String] = [:]
    var chests: [String: Int] = [:]
    var scrap = 0

    init(runs: [String: ZoneRun], records: [String: ZoneRecord], seeds: [String: UInt64], activeZone: ZoneID,
         unlockedZones: [ZoneID], holdUnlocked: Bool, settings: Settings, perks: [String: Int], perkCoins: Int,
         lastActive: Date?, coinRushRemaining: Double = 0, adLedger: AdLedger = AdLedger()) {
        self.coinRushRemaining = coinRushRemaining
        self.adLedger = adLedger
        self.runs = runs
        self.records = records
        self.seeds = seeds
        self.activeZone = activeZone
        self.unlockedZones = unlockedZones
        self.holdUnlocked = holdUnlocked
        self.settings = settings
        self.perks = perks
        self.perkCoins = perkCoins
        self.lastActive = lastActive
    }

    /// Keys used by versions 1–2, which had a single zone.
    private enum LegacyKeys: String, CodingKey {
        case run, bestArea, bestPrestigeArea, prestigeCount, seed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        holdUnlocked = try c.decodeIfPresent(Bool.self, forKey: .holdUnlocked) ?? false
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        perks = try c.decodeIfPresent([String: Int].self, forKey: .perks) ?? [:]
        perkCoins = try c.decodeIfPresent(Int.self, forKey: .perkCoins) ?? 0
        lastActive = try c.decodeIfPresent(Date.self, forKey: .lastActive)
        coinRushRemaining = try c.decodeIfPresent(Double.self, forKey: .coinRushRemaining) ?? 0
        adLedger = try c.decodeIfPresent(AdLedger.self, forKey: .adLedger) ?? AdLedger()
        heartsDefeated = try c.decodeIfPresent(Int.self, forKey: .heartsDefeated) ?? 0
        deepestHeart = try c.decodeIfPresent(Int.self, forKey: .deepestHeart) ?? 0
        items = try c.decodeIfPresent([String: Int].self, forKey: .items) ?? [:]
        equipped = try c.decodeIfPresent([String: String].self, forKey: .equipped) ?? [:]
        chests = try c.decodeIfPresent([String: Int].self, forKey: .chests) ?? [:]
        scrap = try c.decodeIfPresent(Int.self, forKey: .scrap) ?? 0

        if let runs = try c.decodeIfPresent([String: ZoneRun].self, forKey: .runs) {
            self.runs = runs
            records = try c.decodeIfPresent([String: ZoneRecord].self, forKey: .records) ?? [:]
            seeds = try c.decodeIfPresent([String: UInt64].self, forKey: .seeds) ?? [:]
            activeZone = try c.decodeIfPresent(ZoneID.self, forKey: .activeZone) ?? .quarry
            unlockedZones = try c.decodeIfPresent([ZoneID].self, forKey: .unlockedZones) ?? [.quarry]
        } else {
            // Migrate a single-zone save into Pebble Quarry.
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let run = try legacy.decode(ZoneRun.self, forKey: .run)
            var record = ZoneRecord()
            record.bestArea = try legacy.decodeIfPresent(Int.self, forKey: .bestArea) ?? run.area
            record.bestCleared = max(run.maxCleared, record.bestArea - 1)
            record.bestPrestigeArea = try legacy.decodeIfPresent(Int.self, forKey: .bestPrestigeArea) ?? 0
            record.prestigeCount = try legacy.decodeIfPresent(Int.self, forKey: .prestigeCount) ?? 0
            record.seenIntro = true
            runs = [ZoneID.quarry.rawValue: run]
            records = [ZoneID.quarry.rawValue: record]
            seeds = [ZoneID.quarry.rawValue: try legacy.decodeIfPresent(UInt64.self, forKey: .seed) ?? 1]
            activeZone = .quarry
            unlockedZones = [.quarry]
        }

        // Version 4 inserted tools into the middle of each zone's list.
        if version < 4 {
            for zone in ZoneID.allCases {
                guard var run = runs[zone.rawValue], run.toolIndex >= 0 else { continue }
                run.toolIndex = zone.migrateToolIndex(fromV3: run.toolIndex)
                runs[zone.rawValue] = run
            }
            version = 4
        }
    }
}

/// Deterministic generator so an area's layout is stable across saves.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum AreaGenerator {
    static func blocks(zone: ZoneID, area: Int, seed: UInt64, treasureChance: Double = Config.treasureChance) -> [Block] {
        var rng = SplitMix64(seed: seed ^ (UInt64(area) &* 0x2545_F491_4F6C_DD1D))
        var materials = zone.mix(area: area).flatMap { Array(repeating: $0.0, count: $0.1) }
        materials.shuffle(using: &rng)

        var blocks = materials.enumerated().map { index, m in
            let hp = Config.hp(m, area: area, zone: zone)
            return Block(id: index, material: m, maxHP: hp, hp: hp,
                         armor: Config.armor(m, area: area), reward: Config.reward(m, area: area, zone: zone))
        }

        if zone == .quarry && Conquest.isHeartArea(area) {
            // Boss area: the Heart takes the centre 3 × 3 and no treasure spawns.
            let normal = blocks.filter { !Conquest.heartCells.contains($0.id) }
            let avgHP = normal.map(\.maxHP).reduce(0, +) / Double(max(normal.count, 1))
            let avgReward = normal.map(\.reward).reduce(0, +) / Double(max(normal.count, 1))
            let avgArmor = normal.map(\.armor).reduce(0, +) / Double(max(normal.count, 1))
            let toughness = 1 + Conquest.heartToughening * Double(Conquest.heartRank(area))
            for cell in Conquest.heartCells {
                if cell == Conquest.heartIndex {
                    let hp = (avgHP * Conquest.heartHPPerBlock * toughness).rounded()
                    blocks[cell] = Block(id: cell, material: .heart, maxHP: hp, hp: hp, armor: avgArmor * 0.5,
                                         reward: (avgReward * Conquest.heartRewardPerBlock * toughness).rounded())
                } else {
                    blocks[cell] = Block(id: cell, material: .heartPart, maxHP: 0, hp: 0, armor: 0, reward: 0)
                }
            }
            return blocks
        }

        if Double.random(in: 0..<1, using: &rng) < treasureChance {
            let avgHP = blocks.map(\.maxHP).reduce(0, +) / Double(blocks.count)
            let avgReward = blocks.map(\.reward).reduce(0, +) / Double(blocks.count)
            let slot = Int.random(in: 0..<blocks.count, using: &rng)
            let hp = (avgHP * Config.treasureHPMultiplier).rounded()
            blocks[slot] = Block(id: slot, material: zone.treasureOre, maxHP: hp, hp: hp, armor: 0,
                                 reward: (avgReward * Config.treasureRewardMultiplier).rounded())
        }
        return blocks
    }
}

enum NumberText {
    static func format(_ value: Double, short: Bool = true) -> String {
        let v = value.rounded(.down)
        if !short || abs(v) < 10_000 {
            return v.formatted(.number.precision(.fractionLength(0)))
        }
        let units: [(Double, String)] = [(1e15, "Q"), (1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
        for (size, suffix) in units where abs(v) >= size {
            let scaled = v / size
            let digits = scaled >= 100 ? 0 : 1
            return scaled.formatted(.number.precision(.fractionLength(digits))) + suffix
        }
        return v.formatted(.number.precision(.fractionLength(0)))
    }

    /// Damage numbers: one decimal below 10 so weak hits never read as 0.
    static func hit(_ value: Double) -> String {
        if value < 10 {
            let rounded = (value * 10).rounded() / 10
            return rounded == rounded.rounded() ? format(rounded) : decimal(max(rounded, 0.1))
        }
        return format(value)
    }

    static func decimal(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }

    static func percent(_ value: Double) -> String {
        (value * 100).formatted(.number.precision(.fractionLength(0))) + "%"
    }
}
