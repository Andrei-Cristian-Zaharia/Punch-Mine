import Foundation

/// Each zone is its own mining business: own currency, materials, upgrades and prestige.
enum ZoneID: String, Codable, CaseIterable, Identifiable {
    case quarry, caverns, magma

    var id: String { rawValue }

    var number: Int {
        switch self {
        case .quarry: 1
        case .caverns: 2
        case .magma: 3
        }
    }

    var name: String {
        switch self {
        case .quarry: "Pebble Quarry"
        case .caverns: "Crystal Caverns"
        case .magma: "Magma Depths"
        }
    }

    var currencyName: String {
        switch self {
        case .quarry: "Copper Coins"
        case .caverns: "Crystal Shards"
        case .magma: "Ember Coins"
        }
    }

    var currencyShort: String {
        switch self {
        case .quarry: "Copper"
        case .caverns: "Shards"
        case .magma: "Embers"
        }
    }

    var twist: String {
        switch self {
        case .quarry: "Armor: Iron Ore deflects weak punches"
        case .caverns: "Crystals chain-break their neighbours"
        case .magma: "Magma regrows and vents erupt"
        }
    }

    /// One-line advice for the zone intro.
    var tip: String {
        switch self {
        case .quarry: "Crits and penetration beat armor."
        case .caverns: "Hit the crystal that touches the most crystals of the same color."
        case .magma: "A block left alone for 2 s heals back to its last crack. Finish what you start, and let vents (every 25 s) soften their neighbours."
        }
    }

    // Scaling. Later zones have more HP per block than they pay back in coins, so they stay harder,
    // while upgrade prices (same formulas in every zone) do not leave the first areas crawling.
    var hpMultiplier: Double {
        switch self {
        case .quarry: 1
        case .caverns: 2.5
        case .magma: 5
        }
    }
    var rewardMultiplier: Double {
        switch self {
        case .quarry: 1
        case .caverns: 2
        case .magma: 4
        }
    }
    var hpGrowth: Double {
        switch self {
        case .quarry: 1.16
        case .caverns: 1.17
        case .magma: 1.18
        }
    }
    var rewardGrowth: Double {
        switch self {
        case .quarry: 1.12
        case .caverns: 1.13
        case .magma: 1.14
        }
    }
    /// Growth past area 30. Only Pebble Quarry goes that deep.
    var lateHPGrowth: Double { 1.04 }
    var lateRewardGrowth: Double { 1.05 }

    /// Last area before Endless Depths. Pebble Quarry ends in the Heart of the Quarry at area 100.
    var maxArea: Int { self == .quarry ? Conquest.heartArea : Config.areasPerZone }

    var prestigeMultiplier: Double {
        switch self {
        case .quarry: 1.0
        case .caverns: 1.6
        case .magma: 2.5
        }
    }

    var treasureOre: Ore {
        switch self {
        case .quarry: .treasure
        case .caverns: .geode
        case .magma: .fireOpal
        }
    }

    /// Grid composition per tier (counts add up to 30).
    func mix(area: Int) -> [(Ore, Int)] {
        switch self {
        case .quarry:
            switch area {
            case ...5: [(.dirt, 20), (.stone, 10)]
            case 6...10: [(.dirt, 8), (.stone, 14), (.iron, 6), (.copperOre, 2)]
            case 11...15: [(.stone, 12), (.iron, 10), (.gold, 4), (.coal, 2), (.copperOre, 2)]
            case 16...20: [(.stone, 4), (.iron, 14), (.gold, 8), (.coal, 4)]
            case 21...25: [(.iron, 12), (.gold, 10), (.granite, 6), (.coal, 2)]
            case 26...30: [(.iron, 8), (.gold, 10), (.granite, 6), (.silver, 4), (.coal, 2)]
            case 31...40: [(.gold, 8), (.granite, 10), (.silver, 10), (.coal, 2)]
            case 41...50: [(.granite, 8), (.silver, 12), (.diamond, 6), (.coal, 4)]
            case 51...60: [(.granite, 6), (.silver, 10), (.diamond, 12), (.coal, 2)]
            case 61...70: [(.silver, 6), (.diamond, 12), (.mithril, 10), (.coal, 2)]
            case 71...80: [(.granite, 6), (.diamond, 8), (.mithril, 14), (.coal, 2)]
            case 81...90: [(.diamond, 4), (.mithril, 14), (.adamantite, 10), (.coal, 2)]
            default: [(.diamond, 2), (.mithril, 10), (.adamantite, 16), (.coal, 2)]
            }
        case .caverns:
            switch area {
            case ...5: [(.limestone, 18), (.quartz, 12)]
            case 6...10: [(.limestone, 8), (.quartz, 14), (.amethyst, 8)]
            case 11...15: [(.quartz, 14), (.amethyst, 12), (.voidstone, 4)]
            case 16...20: [(.quartz, 6), (.amethyst, 14), (.voidstone, 10)]
            default: [(.amethyst, 14), (.voidstone, 16)]
            }
        case .magma:
            switch area {
            case ...5: [(.basalt, 19), (.obsidian, 10), (.vent, 1)]
            case 6...10: [(.basalt, 8), (.obsidian, 13), (.magmaCore, 7), (.vent, 2)]
            case 11...15: [(.obsidian, 12), (.magmaCore, 12), (.emberOre, 4), (.vent, 2)]
            case 16...20: [(.obsidian, 4), (.magmaCore, 14), (.emberOre, 10), (.vent, 2)]
            default: [(.magmaCore, 11), (.emberOre, 11), (.heartstone, 6), (.vent, 2)]
            }
        }
    }

    /// Bought in order; each one replaces the last.
    var tools: [Tool] {
        switch self {
        case .quarry:
            [
                Tool(id: 0, name: "Brass Knuckles", cost: 250, unlockArea: 3, damage: 1.5, penetration: 0, splash: 0,
                     chainBonus: 0, critBonus: 0, blurb: "×1.5 damage"),
                Tool(id: 1, name: "Pickaxe Gauntlet", cost: 4_000, unlockArea: 8, damage: 1.5, penetration: 0.6, splash: 0,
                     chainBonus: 0, critBonus: 0, blurb: "×1.5 damage, ignores 60% armor"),
                Tool(id: 2, name: "Spiked Gloves", cost: 15_000, unlockArea: 12, damage: 1.75, penetration: 0.6, splash: 0,
                     chainBonus: 0, critBonus: 0.05, blurb: "×1.75 damage, 60% pen, +5% crit"),
                Tool(id: 3, name: "Shockwave Glove", cost: 40_000, unlockArea: 16, damage: 2.0, penetration: 0.6, splash: 0.35,
                     chainBonus: 0, critBonus: 0.05, blurb: "×2 damage, 60% pen, 35% splash, +5% crit"),
                Tool(id: 4, name: "Titan Fists", cost: 400_000, unlockArea: 24, damage: 3.0, penetration: 0.75, splash: 0.4,
                     chainBonus: 0, critBonus: 0.05, blurb: "×3 damage, 75% pen, 40% splash, +5% crit"),
                Tool(id: 5, name: "Silver Knuckles", cost: 600_000, unlockArea: 32, damage: 4.0, penetration: 0.8, splash: 0.4,
                     chainBonus: 0, critBonus: 0.05, lucky: 0.1, blurb: "×4 damage, 80% pen, 40% splash, 10% lucky double coins"),
                Tool(id: 6, name: "Diamond Drill-Fist", cost: 1_500_000, unlockArea: 45, damage: 6.0, penetration: 0.85, splash: 0.4,
                     chainBonus: 0, critBonus: 0.05, pierce: 0.5, lucky: 0.1,
                     blurb: "×6 damage, 85% pen, pierces the block below for 50%"),
                Tool(id: 7, name: "Mithril Gauntlet", cost: 6_000_000, unlockArea: 60, damage: 9.0, penetration: 0.9, splash: 0.45,
                     chainBonus: 0, critBonus: 0.1, pierce: 0.5, lucky: 0.15,
                     blurb: "×9 damage, 90% pen, 45% splash, pierce, 15% lucky, +10% crit"),
                Tool(id: 8, name: "Thunder Fist", cost: 20_000_000, unlockArea: 75, damage: 13.0, penetration: 0.9, splash: 0.45,
                     chainBonus: 0, critBonus: 0.1, pierce: 0.5, lucky: 0.15, lightningEvery: 10, lightningTargets: 3,
                     blurb: "×13 damage, pierce, lucky; every 10th punch zaps 3 blocks"),
                Tool(id: 9, name: "Adamant Breaker", cost: 80_000_000, unlockArea: 90, damage: 18.0, penetration: 0.9, splash: 0.5,
                     chainBonus: 0, critBonus: 0.12, pierce: 0.6, lucky: 0.2, lightningEvery: 8, lightningTargets: 4,
                     blurb: "×18 damage, 50% splash, pierce, 20% lucky; every 8th punch zaps 4"),
            ]
        case .caverns:
            [
                Tool(id: 0, name: "Quartz Knuckles", cost: 300, unlockArea: 3, damage: 1.5, penetration: 0.3, splash: 0,
                     chainBonus: 0, critBonus: 0, blurb: "×1.5 damage, ignores 30% armor"),
                Tool(id: 1, name: "Resonator", cost: 3_000, unlockArea: 6, damage: 1.5, penetration: 0.3, splash: 0,
                     chainBonus: 0.25, critBonus: 0, blurb: "×1.5 damage, 30% pen, +25% chain damage"),
                Tool(id: 2, name: "Prism Fist", cost: 20_000, unlockArea: 10, damage: 2.0, penetration: 0.6, splash: 0,
                     chainBonus: 0.5, critBonus: 0, blurb: "×2 damage, 60% pen, +50% chain damage"),
                Tool(id: 3, name: "Void Breaker", cost: 150_000, unlockArea: 18, damage: 2.5, penetration: 0.85, splash: 0.25,
                     chainBonus: 0.5, critBonus: 0, blurb: "×2.5 damage, 85% pen, 25% splash, +50% chain"),
                Tool(id: 4, name: "Star Prism", cost: 400_000, unlockArea: 25, damage: 3.5, penetration: 0.9, splash: 0.3,
                     chainBonus: 0.75, critBonus: 0.05, lucky: 0.1, blurb: "×3.5 damage, +75% chain, 10% lucky double coins"),
            ]
        case .magma:
            [
                Tool(id: 0, name: "Basalt Knuckles", cost: 400, unlockArea: 3, damage: 1.5, penetration: 0.3, splash: 0,
                     chainBonus: 0, critBonus: 0, blurb: "×1.5 damage, ignores 30% armor"),
                Tool(id: 1, name: "Frost Knuckles", cost: 8_000, unlockArea: 8, damage: 1.75, penetration: 0.5, splash: 0,
                     chainBonus: 0, critBonus: 0, freezeSeconds: 10, blurb: "×1.75 damage, 50% pen, hit blocks can't regrow for 10 s"),
                Tool(id: 2, name: "Magma Maul", cost: 120_000, unlockArea: 16, damage: 2.5, penetration: 0.75, splash: 0.3,
                     chainBonus: 0, critBonus: 0.05, freezeSeconds: 10, blurb: "×2.5 damage, 75% pen, 30% splash, freezes for 10 s"),
                Tool(id: 3, name: "Inferno Gauntlet", cost: 1_000_000, unlockArea: 24, damage: 3.5, penetration: 0.85, splash: 0.35,
                     chainBonus: 0, critBonus: 0.05, freezeSeconds: 10, lightningEvery: 10, lightningTargets: 3,
                     blurb: "×3.5 damage, freezes; every 10th punch zaps 3 blocks"),
            ]
        }
    }

    /// Tool positions used by saves before version 4, mapped to the current list.
    func migrateToolIndex(fromV3 index: Int) -> Int {
        switch self {
        case .quarry: index >= 2 ? index + 1 : index      // Spiked Gloves inserted at 2
        case .caverns: index >= 1 ? index + 1 : index     // Resonator inserted at 1
        case .magma: index
        }
    }

    /// What it takes to open this zone. Nil means it is open from the start.
    var unlock: ZoneUnlock? {
        switch self {
        case .quarry: nil
        case .caverns: ZoneUnlock(previous: .quarry, clearArea: 15, costs: [ZoneCost(zone: .quarry, amount: 15_000)])
        case .magma: ZoneUnlock(previous: .caverns, clearArea: 15, costs: [
            ZoneCost(zone: .caverns, amount: 60_000),
            ZoneCost(zone: .quarry, amount: 40_000),
        ])
        }
    }
}

struct ZoneUnlock {
    /// The zone whose area must be cleared.
    let previous: ZoneID
    let clearArea: Int
    /// Paid from these zones' wallets: the previous zone, plus a smaller amount from an older one.
    let costs: [ZoneCost]
}

struct ZoneCost: Identifiable {
    var id: ZoneID { zone }
    let zone: ZoneID
    let amount: Double
}

/// The Heart of the Quarry and Endless Depths.
enum Conquest {
    static let heartArea = 100
    /// In Endless Depths a stronger Heart appears every 25 areas.
    static let endlessHeartEvery = 25
    /// The Heart covers the centre 3 × 3 of the grid (rows 1–3, columns 1–3); its logic lives in cell 12.
    static let heartCells = [6, 7, 8, 11, 12, 13, 16, 17, 18]
    static let heartIndex = 12
    static let heartHPPerBlock = 25.0
    static let heartRewardPerBlock = 30.0
    /// Each Heart past the first is 50% tougher than the last.
    static let heartToughening = 0.5

    // Rewards, given only for a Heart deeper than any defeated before.
    static let crownCoinBonus = 0.25
    static let starCoinBonus = 0.05
    static let crownPerkCoins = 100
    static let starPerkCoins = 50

    static func isHeartArea(_ area: Int) -> Bool {
        area == heartArea || (area > heartArea && (area - heartArea) % endlessHeartEvery == 0)
    }

    /// 0 for the first Heart (area 100), 1 for area 125, and so on.
    static func heartRank(_ area: Int) -> Int { max(0, (area - heartArea) / endlessHeartEvery) }

    /// All-zone coin multiplier from the Crown (first Heart) and Crown Stars (later Hearts).
    static func coinMultiplier(hearts: Int) -> Double {
        guard hearts > 0 else { return 1 }
        return 1 + crownCoinBonus + starCoinBonus * Double(hearts - 1)
    }
}

/// Regrowth and vents in Magma Depths.
enum Magma {
    static let regrowDelay = 2.0
    static let regrowPerSecond = 0.05
    static let ventInterval = 25.0
    /// 25% puts a full block exactly on its first crack, so regrowth cannot undo it.
    static let ventShare = 0.25
}

/// Active gadgets: bought once per run, then used on a cooldown.
enum Gadget: String, CaseIterable, Identifiable {
    case dynamite, horn

    var id: String { rawValue }
    var name: String { self == .dynamite ? "Dynamite" : "Fever Horn" }
    /// Base price 5,000 / 20,000, with the ×1.5 shop scaling.
    var cost: Double { (self == .dynamite ? 5_000 : 20_000) * Config.shopPriceMultiplier }
    var unlockArea: Int { self == .dynamite ? 12 : 18 }
    var cooldown: Double { self == .dynamite ? 45 : 90 }
    var symbol: String { self == .dynamite ? "flame.circle.fill" : "megaphone.fill" }
    var blurb: String {
        switch self {
        case .dynamite: "Tap, then tap a block: 3×3 blast for 8× punch damage · 45 s"
        case .horn: "Starts Fever instantly · 90 s"
        }
    }
    /// Stored in the run's levels so it resets on prestige like other purchases.
    var levelKey: String { "gadget." + rawValue }
    static let dynamiteMultiplier = 8.0
}

/// Crystal chain rule for Crystal Caverns.
enum Chain {
    static let share = 0.4
    static let maxSteps = 3
}

/// Records that survive a zone's prestige.
struct ZoneRecord: Codable {
    var bestArea = 1
    var bestCleared = 0
    var bestPrestigeArea = 0
    var prestigeCount = 0
    var seenIntro = false
    /// Play time and depth of the last prestiged run, to measure how much faster the next run gets back.
    var lastRunSeconds: Double = 0
    var lastPrestigeDepth = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bestArea = try c.decodeIfPresent(Int.self, forKey: .bestArea) ?? 1
        bestCleared = try c.decodeIfPresent(Int.self, forKey: .bestCleared) ?? 0
        bestPrestigeArea = try c.decodeIfPresent(Int.self, forKey: .bestPrestigeArea) ?? 0
        prestigeCount = try c.decodeIfPresent(Int.self, forKey: .prestigeCount) ?? 0
        seenIntro = try c.decodeIfPresent(Bool.self, forKey: .seenIntro) ?? false
        lastRunSeconds = try c.decodeIfPresent(Double.self, forKey: .lastRunSeconds) ?? 0
        lastPrestigeDepth = try c.decodeIfPresent(Int.self, forKey: .lastPrestigeDepth) ?? 0
    }
}
