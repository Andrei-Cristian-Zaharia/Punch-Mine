import Foundation

/// Tunable numbers for Zone 1 (Pebble Quarry), taken from the game design document.
/// Everything here is a starting value for playtesting.
enum Config {
    static let columns = 5
    static let rows = 6
    static var blocksPerArea: Int { columns * rows }
    /// Areas in Zones 2 and 3. Pebble Quarry goes to 100 (see `ZoneID.maxArea`).
    static let areasPerZone = 30
    /// Past this area, HP and rewards grow at the zone's slower "late" rates.
    static let lateGrowthStart = 30

    // Armor scaling per area (HP and reward growth are per zone, see ZoneID)
    static let armorGrowth = 0.06
    static let lateArmorGrowth = 0.02

    static let clearBonusShare = 0.25
    static let treasureChance = 0.15
    static let treasureFromArea = 3
    static let treasureHPMultiplier = 3.0
    static let treasureRewardMultiplier = 10.0
    static let treasureCollapseSeconds = 10.0

    // Punching
    static let damageFloor = 0.1
    static let penetrationCap = 0.9
    static let tapCapPerSecond = 12
    static let holdUnlockArea = 2
    static let holdDelay = 0.25
    static let baseHoldRate = 4.0
    static let holdRatePerLevel = 0.3

    // Crits
    static let critChancePerLevel = 0.02
    static let baseCritMultiplier = 2.0
    static let critMultiplierPerLevel = 0.1

    // Fever
    static let feverPunches = 60
    static let feverWindow = 15.0
    static let feverDuration = 8.0
    static let feverMultiplier = 2.0

    // Miners
    static let minerBaseDamage = 5.0
    static let minerDamagePerTraining = 3.0
    /// Miners hit for a share of your punch (before Fever and crits): 30%, +3% per Training level.
    static let minerPunchShare = 0.30
    static let minerPunchSharePerTraining = 0.03
    static let minerArmorShare = 0.5
    static let minerHitInterval = 1.0
    static let minerHireCosts: [Double] = [350, 1_500, 8_000, 40_000, 200_000]
    static let drillerHireCosts: [Double] = [2_000, 15_000, 90_000]
    static let blasterHireCosts: [Double] = [25_000, 250_000]
    static let blasterAverageTargets = 6.0

    // New upgrades
    static let focusPerStack = 0.04
    static let focusStacksPerLevel = 2
    static let feverSecondsPerLevel = 0.5
    static let shiftPacePerLevel = 0.04
    static let contractsPerLevel = 0.05
    /// Rhythm: every Nth punch is a guaranteed crit, N = 12 − level.
    static let rhythmBase = 12
    static let deepPocketsPerLevel = 0.05
    static let overchargePerLevel = 0.1
    static let treasureHunterPerLevel = 0.01
    static let lockpickPerLevel = 0.05

    // Shop prices
    static let shopPriceMultiplier = 1.5
    static let bonusPriceMultiplier = 2.5

    static let autosaveInterval = 10.0

    /// Areas 1–30 grow at the zone's normal rate, later areas at its slower late rate.
    private static func early(_ area: Int) -> Double { Double(min(area, lateGrowthStart) - 1) }
    private static func late(_ area: Int) -> Double { Double(max(0, area - lateGrowthStart)) }

    static func hp(_ m: Ore, area: Int, zone: ZoneID) -> Double {
        (m.baseHP * zone.hpMultiplier * pow(zone.hpGrowth, early(area)) * pow(zone.lateHPGrowth, late(area))).rounded()
    }

    static func armor(_ m: Ore, area: Int) -> Double {
        m.baseArmor * (1 + armorGrowth * early(area) + lateArmorGrowth * late(area))
    }

    static func reward(_ m: Ore, area: Int, zone: ZoneID) -> Double {
        (m.baseReward * zone.rewardMultiplier * pow(zone.rewardGrowth, early(area))
            * pow(zone.lateRewardGrowth, late(area))).rounded()
    }

    /// S(L) = (1 + L) · 2^floor(L / 25)
    static func strength(level: Int) -> Double {
        Double(1 + level) * pow(2, Double(level / 25))
    }

    static func holdRate(speedLevel: Int) -> Double {
        baseHoldRate + holdRatePerLevel * Double(speedLevel)
    }

    static func critChance(level: Int) -> Double {
        critChancePerLevel * Double(level)
    }

    static func critMultiplier(level: Int) -> Double {
        baseCritMultiplier + critMultiplierPerLevel * Double(level)
    }

    static func minerHit(trainingLevel: Int) -> Double {
        minerBaseDamage + minerDamagePerTraining * Double(trainingLevel)
    }

    /// Damage after armor, never below 10% of the raw punch.
    static func hitDamage(raw: Double, armor: Double, penetration: Double) -> Double {
        max(damageFloor * raw, raw - armor * (1 - min(penetration, penetrationCap)))
    }

    static let bareFists = Tool(id: -1, name: "Bare Fists", cost: 0, unlockArea: 1, damage: 1, penetration: 0, splash: 0,
                                chainBonus: 0, critBonus: 0, blurb: "No bonus")
}

enum Ore: String, Codable, CaseIterable {
    // Zone 1
    case dirt, stone, iron, gold, granite, treasure
    // Zone 2
    case limestone, quartz, amethyst, voidstone, geode
    // Zone 3
    case basalt, obsidian, magmaCore, emberOre, heartstone, vent, fireOpal
    // Zone 1, deeper tiers
    case copperOre, coal, silver, diamond, mithril, adamantite
    // Zones 2 and 3, deeper tiers
    case sapphire, starstone, brimstone, dragonglass
    // Zone 4
    case sand, coral, ruinStone, runestone, abyssite, leviathanBone, pearlClam
    /// Area-100 boss and the cells it covers.
    case heart, heartPart

    var isTreasure: Bool { self == .treasure || self == .geode || self == .fireOpal || self == .pearlClam }
    /// Breaking Coal adds Fever charge.
    var feverFuel: Int { self == .coal || self == .brimstone ? 5 : 0 }
    /// Crystals chain-break touching crystals of the same type.
    var isCrystal: Bool { self == .quartz || self == .amethyst || self == .sapphire }

    var baseHP: Double {
        switch self {
        case .dirt, .limestone, .basalt, .sand: 5
        case .stone, .quartz, .obsidian, .coral: 15
        case .iron, .amethyst, .magmaCore, .vent, .ruinStone: 50
        case .gold, .voidstone, .emberOre, .runestone: 140
        case .granite, .heartstone, .abyssite: 400
        case .leviathanBone: 2_000
        case .treasure, .geode, .fireOpal, .pearlClam, .heart, .heartPart: 0
        case .copperOre: 30
        case .coal: 60
        case .silver: 260
        case .diamond: 700
        case .mithril: 1_500
        case .adamantite: 3_000
        case .sapphire, .brimstone: 450
        case .starstone, .dragonglass: 2_000
        }
    }

    var baseArmor: Double {
        switch self {
        case .obsidian: 3
        case .iron, .amethyst, .magmaCore, .vent: 5
        case .ruinStone: 6
        case .runestone: 4
        case .abyssite: 32
        case .leviathanBone: 115
        case .gold, .voidstone, .emberOre: 12
        case .granite, .heartstone: 30
        case .copperOre: 2
        case .silver: 18
        case .diamond: 45
        case .mithril: 80
        case .adamantite: 130
        case .sapphire, .brimstone: 25
        case .starstone, .dragonglass: 110
        default: 0
        }
    }

    var baseReward: Double {
        switch self {
        case .dirt, .limestone, .basalt, .sand: 1
        case .stone, .quartz, .obsidian, .coral: 3
        case .iron, .amethyst, .magmaCore, .vent, .ruinStone: 10
        case .gold, .voidstone, .emberOre, .runestone: 28
        case .granite, .heartstone, .abyssite: 80
        case .leviathanBone: 600
        case .treasure, .geode, .fireOpal, .pearlClam, .heart, .heartPart: 0
        case .copperOre: 18
        case .coal: 12
        case .silver: 60
        case .diamond: 160
        case .mithril: 380
        case .adamantite: 800
        case .sapphire, .brimstone: 110
        case .starstone, .dragonglass: 600
        }
    }

    var displayName: String {
        switch self {
        case .dirt: "Dirt"
        case .stone: "Stone"
        case .iron: "Iron Ore"
        case .gold: "Gold Ore"
        case .granite: "Granite"
        case .treasure: "Treasure"
        case .limestone: "Limestone"
        case .quartz: "Quartz"
        case .amethyst: "Amethyst"
        case .voidstone: "Voidstone"
        case .geode: "Geode"
        case .basalt: "Basalt"
        case .obsidian: "Obsidian"
        case .magmaCore: "Magma Core"
        case .emberOre: "Ember Ore"
        case .heartstone: "Heartstone"
        case .vent: "Vent"
        case .fireOpal: "Fire Opal"
        case .copperOre: "Copper Ore"
        case .coal: "Coal"
        case .silver: "Silver Ore"
        case .diamond: "Diamond"
        case .mithril: "Mithril"
        case .adamantite: "Adamantite"
        case .sapphire: "Sapphire"
        case .starstone: "Starstone"
        case .brimstone: "Brimstone"
        case .dragonglass: "Dragonglass"
        case .sand: "Sand"
        case .coral: "Coral"
        case .ruinStone: "Ruin Stone"
        case .runestone: "Runestone"
        case .abyssite: "Abyssite"
        case .leviathanBone: "Leviathan Bone"
        case .pearlClam: "Giant Clam"
        case .heart, .heartPart: "Heart"
        }
    }
}

struct Tool: Identifiable {
    let id: Int
    let name: String
    let cost: Double
    let unlockArea: Int
    let damage: Double
    let penetration: Double
    let splash: Double
    /// Extra share added to crystal chain damage.
    let chainBonus: Double
    /// Flat crit chance added while equipped.
    let critBonus: Double
    /// Magma Depths: blocks hit by this tool cannot regrow for this long.
    var freezeSeconds: Double = 0
    /// Share of the punch that also hits the block directly below.
    var pierce: Double = 0
    /// Chance that a broken block pays double.
    var lucky: Double = 0
    /// Every Nth punch zaps `lightningTargets` random blocks for a full punch (0 = no lightning).
    var lightningEvery: Int = 0
    var lightningTargets: Int = 0
    let blurb: String
}

enum UpgradeKind: String, Codable, CaseIterable, Identifiable {
    case strength, speed, critChance, critDamage, focus, rhythm
    case hireMiner, hireDriller, hireBlaster, training, shiftPace
    case feverStamina, contracts, deepPockets, overcharge, treasureHunter, lockpick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: "Strength"
        case .speed: "Speed"
        case .critChance: "Crit Chance"
        case .critDamage: "Crit Damage"
        case .focus: "Focus"
        case .hireMiner: "Hire Digger"
        case .hireDriller: "Hire Driller"
        case .hireBlaster: "Hire Blaster"
        case .training: "Miner Training"
        case .shiftPace: "Shift Pace"
        case .feverStamina: "Fever Stamina"
        case .contracts: "Contracts"
        case .rhythm: "Rhythm"
        case .deepPockets: "Deep Pockets"
        case .overcharge: "Overcharge"
        case .treasureHunter: "Treasure Hunter"
        case .lockpick: "Lockpick"
        }
    }

    var unlockArea: Int {
        switch self {
        case .strength: 1
        case .speed: 2
        case .deepPockets: 3
        case .treasureHunter: 5
        case .overcharge: 7
        case .lockpick: 8
        case .rhythm: 10
        case .hireMiner, .training, .shiftPace: 4
        case .feverStamina: 5
        case .critChance: 6
        case .focus: 7
        case .hireDriller: 8
        case .critDamage: 9
        case .contracts: 10
        case .hireBlaster: 14
        }
    }

    var maxLevel: Int {
        switch self {
        case .strength: 100
        case .speed: 20
        case .critChance: 15
        case .critDamage: 20
        case .focus: 10
        case .hireMiner: Config.minerHireCosts.count
        case .hireDriller: Config.drillerHireCosts.count
        case .hireBlaster: Config.blasterHireCosts.count
        case .training: 50
        case .shiftPace: 10
        case .feverStamina: 10
        case .contracts: 5
        case .rhythm: 9
        case .deepPockets: 20
        case .overcharge: 10
        case .treasureHunter: 10
        case .lockpick: 10
        }
    }

    /// Cost of buying the next level when the current level is `level`.
    /// Upgrades in the drawer's Bonus tab.
    var isBonus: Bool {
        switch self {
        case .deepPockets, .treasureHunter, .lockpick, .feverStamina, .overcharge, .contracts: true
        default: false
        }
    }

    /// Shop price scaling: Bonus upgrades ×2.5, everything else ×1.5.
    var priceMultiplier: Double { isBonus ? Config.bonusPriceMultiplier : Config.shopPriceMultiplier }

    func cost(level: Int) -> Double {
        (baseCost(level: level) * priceMultiplier).rounded()
    }

    private func baseCost(level: Int) -> Double {
        func table(_ costs: [Double]) -> Double { costs[min(level, costs.count - 1)] }
        switch self {
        case .strength: return (15 * pow(1.17, Double(level))).rounded()
        case .speed: return (40 * pow(1.25, Double(level))).rounded()
        case .critChance: return (120 * pow(1.32, Double(level))).rounded()
        case .critDamage: return (300 * pow(1.28, Double(level))).rounded()
        case .focus: return (200 * pow(1.35, Double(level))).rounded()
        case .hireMiner: return table(Config.minerHireCosts)
        case .hireDriller: return table(Config.drillerHireCosts)
        case .hireBlaster: return table(Config.blasterHireCosts)
        case .training: return (100 * pow(1.18, Double(level))).rounded()
        case .shiftPace: return (500 * pow(1.45, Double(level))).rounded()
        case .feverStamina: return (150 * pow(1.4, Double(level))).rounded()
        case .contracts: return (1_000 * pow(1.6, Double(level))).rounded()
        case .rhythm: return (400 * pow(1.5, Double(level))).rounded()
        // Cheap early so first runs aren't slowed; steep after level 10 so it isn't maxed by area 30.
        case .deepPockets: return (60 * pow(1.3, Double(level)) * pow(1.45, Double(max(0, level - 10)))).rounded()
        case .overcharge: return (250 * pow(1.38, Double(level))).rounded()
        case .treasureHunter: return (200 * pow(1.35, Double(level))).rounded()
        case .lockpick: return (500 * pow(1.4, Double(level))).rounded()
        }
    }

    /// Hire upgrades whose level is a miner count.
    var minerKind: MinerKind? {
        switch self {
        case .hireMiner: .digger
        case .hireDriller: .driller
        case .hireBlaster: .blaster
        default: nil
        }
    }
}

/// Three miner types, each answering a different block problem.
enum MinerKind: String, CaseIterable, Codable {
    /// Steady single hits on the weakest block.
    case digger
    /// Slow heavy hits that mostly ignore armor, on the most armored block.
    case driller
    /// Periodic 3×3 blast centred on the toughest cluster.
    case blaster

    var name: String { rawValue.capitalized }
    var hire: UpgradeKind {
        switch self {
        case .digger: .hireMiner
        case .driller: .hireDriller
        case .blaster: .hireBlaster
        }
    }
    /// Base seconds between hits, before Shift Pace.
    var interval: Double {
        switch self {
        case .digger: 1
        case .driller: 3
        case .blaster: 5
        }
    }
    /// Multiplier on the shared miner hit (5 + 3 × Training).
    var damageFactor: Double {
        switch self {
        case .digger: 1
        case .driller: 4
        case .blaster: 3
        }
    }
    /// Share of block armor this miner feels.
    var armorShare: Double {
        switch self {
        case .digger, .blaster: 0.5
        case .driller: 0.25
        }
    }
}
