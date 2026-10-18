import Foundation

enum Rarity: Int, Codable, CaseIterable, Comparable, Identifiable {
    case common, rare, epic, legendary

    var id: Int { rawValue }
    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .common: "Common"
        case .rare: "Rare"
        case .epic: "Epic"
        case .legendary: "Legendary"
        }
    }

    var maxLevel: Int { [10, 15, 20, 25][rawValue] }
    /// Scrap given for a duplicate.
    var scrapValue: Int { [8, 25, 80, 250][rawValue] }
    /// Scrap to go from level 1 to 2; later levels cost 25% more each.
    var upgradeBase: Double { [10, 25, 60, 150][rawValue] }
}

enum ItemSlot: String, Codable, CaseIterable, Identifiable {
    case helmet, belt, charm, boots

    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .helmet: "shield.lefthalf.filled"
        case .belt: "circle.dashed.inset.filled"
        case .charm: "sparkles"
        case .boots: "shoeprints.fill"
        }
    }
}

/// What an item does. Each one changes a different part of the game.
enum ItemEffect: String, Codable {
    case punchDamage, strengthBonus, minerDamage, minerSpeed, critChance, critDamage, penetration
    case coins, clearBonus, treasureChance, treasureReward, lucky
    case feverMultiplier, gadgetCooldown, doubleHit, holdRate, stomp, quake, storm, focus
    case offlineEfficiency, freeze
}

struct ItemDef: Identifiable {
    let id: String
    let name: String
    let slot: ItemSlot
    let rarity: Rarity
    let effect: ItemEffect
    let base: Double
    let perLevel: Double
    let symbol: String

    func value(level: Int) -> Double { base + perLevel * Double(max(level, 1) - 1) }

    func upgradeCost(level: Int) -> Int { Int((rarity.upgradeBase * pow(1.25, Double(level - 1))).rounded()) }

    /// Effect text at a level, e.g. "+14% punch damage".
    func describe(level: Int) -> String {
        let v = value(level: level)
        func pct(_ x: Double) -> String { NumberText.decimal(x * 100, digits: x * 100 < 10 ? 1 : 0) + "%" }
        switch effect {
        case .punchDamage: return "+\(pct(v)) punch damage"
        case .strengthBonus: return "Strength counts +\(pct(v))"
        case .minerDamage: return "+\(pct(v)) miner damage"
        case .minerSpeed: return "Miners swing \(pct(v)) faster"
        case .critChance: return "+\(pct(v)) crit chance"
        case .critDamage: return "+\(NumberText.decimal(v, digits: 2))× crit damage"
        case .penetration: return "+\(pct(v)) armor penetration"
        case .coins: return "+\(pct(v)) coins from blocks"
        case .clearBonus: return "+\(pct(v)) area clear bonus"
        case .treasureChance: return "+\(pct(v)) treasure chance"
        case .treasureReward: return "Treasure pays +\(pct(v))"
        case .lucky: return "\(pct(v)) chance a block pays double"
        case .feverMultiplier: return "Fever ×\(NumberText.decimal(2 + v, digits: 2)) instead of ×2"
        case .gadgetCooldown: return "Gadget cooldowns −\(pct(v))"
        case .doubleHit: return "\(pct(v)) chance a punch hits twice"
        case .holdRate: return "+\(NumberText.decimal(v, digits: 1)) hold punches/s"
        case .stomp: return "\(pct(v)) chance a punch stomps its 4 neighbours for 50%"
        case .quake: return "Every 20th punch shakes every block for \(pct(v))"
        case .storm: return "Every 15th punch zaps \(Int(v)) block\(Int(v) == 1 ? "" : "s")"
        case .focus: return "+\(Int(v)) Focus stacks"
        case .offlineEfficiency: return "+\(pct(v)) offline earnings rate"
        case .freeze: return "Magma: hit blocks can't regrow for \(NumberText.decimal(v, digits: 1)) s"
        }
    }

    static let all: [ItemDef] = [
        // Helmets
        ItemDef(id: "minersHelmet", name: "Miner's Helmet", slot: .helmet, rarity: .common, effect: .minerDamage,
                base: 0.10, perLevel: 0.03, symbol: "flashlight.on.fill"),
        ItemDef(id: "hardHat", name: "Hard Hat", slot: .helmet, rarity: .common, effect: .penetration,
                base: 0.03, perLevel: 0.005, symbol: "shield.fill"),
        ItemDef(id: "lanternCap", name: "Lantern Cap", slot: .helmet, rarity: .rare, effect: .treasureChance,
                base: 0.03, perLevel: 0.005, symbol: "lightbulb.fill"),
        ItemDef(id: "crownOfEmbers", name: "Crown of Embers", slot: .helmet, rarity: .epic, effect: .feverMultiplier,
                base: 0.3, perLevel: 0.05, symbol: "crown.fill"),
        ItemDef(id: "seersVisor", name: "Seer's Visor", slot: .helmet, rarity: .legendary, effect: .critDamage,
                base: 0.5, perLevel: 0.08, symbol: "eye.fill"),
        // Belts
        ItemDef(id: "toolBelt", name: "Tool Belt", slot: .belt, rarity: .common, effect: .punchDamage,
                base: 0.08, perLevel: 0.03, symbol: "wrench.and.screwdriver.fill"),
        ItemDef(id: "coinPouch", name: "Coin Pouch", slot: .belt, rarity: .rare, effect: .coins,
                base: 0.08, perLevel: 0.02, symbol: "bag.fill"),
        ItemDef(id: "luckySash", name: "Lucky Sash", slot: .belt, rarity: .rare, effect: .lucky,
                base: 0.04, perLevel: 0.005, symbol: "leaf.fill"),
        ItemDef(id: "bandolier", name: "Dynamite Bandolier", slot: .belt, rarity: .epic, effect: .gadgetCooldown,
                base: 0.15, perLevel: 0.015, symbol: "flame.fill"),
        ItemDef(id: "titanBelt", name: "Titan Belt", slot: .belt, rarity: .legendary, effect: .strengthBonus,
                base: 0.20, perLevel: 0.05, symbol: "figure.strengthtraining.traditional"),
        // Charms
        ItemDef(id: "rabbitsFoot", name: "Rabbit's Foot", slot: .charm, rarity: .common, effect: .critChance,
                base: 0.02, perLevel: 0.003, symbol: "hare.fill"),
        ItemDef(id: "magnetCharm", name: "Magnet Charm", slot: .charm, rarity: .common, effect: .clearBonus,
                base: 0.05, perLevel: 0.01, symbol: "magnet"),
        ItemDef(id: "hourglass", name: "Hourglass", slot: .charm, rarity: .rare, effect: .offlineEfficiency,
                base: 0.05, perLevel: 0.01, symbol: "hourglass"),
        ItemDef(id: "echoShard", name: "Echo Shard", slot: .charm, rarity: .epic, effect: .doubleHit,
                base: 0.05, perLevel: 0.008, symbol: "waveform"),
        ItemDef(id: "stormCharm", name: "Storm Charm", slot: .charm, rarity: .epic, effect: .storm,
                base: 1, perLevel: 0.2, symbol: "cloud.bolt.fill"),
        ItemDef(id: "phoenixFeather", name: "Phoenix Feather", slot: .charm, rarity: .legendary, effect: .treasureReward,
                base: 1.0, perLevel: 0.2, symbol: "bird.fill"),
        // Boots
        ItemDef(id: "sprintBoots", name: "Sprint Boots", slot: .boots, rarity: .common, effect: .holdRate,
                base: 0.5, perLevel: 0.1, symbol: "figure.run"),
        ItemDef(id: "minersClogs", name: "Miner's Clogs", slot: .boots, rarity: .common, effect: .minerSpeed,
                base: 0.05, perLevel: 0.01, symbol: "timer"),
        ItemDef(id: "stompBoots", name: "Stomp Boots", slot: .boots, rarity: .rare, effect: .stomp,
                base: 0.08, perLevel: 0.01, symbol: "arrow.down.to.line"),
        ItemDef(id: "emberGreaves", name: "Ember Greaves", slot: .boots, rarity: .rare, effect: .freeze,
                base: 3, perLevel: 0.3, symbol: "snowflake"),
        ItemDef(id: "quakeBoots", name: "Quake Boots", slot: .boots, rarity: .epic, effect: .quake,
                base: 0.15, perLevel: 0.02, symbol: "waveform.path"),
        ItemDef(id: "windwalkers", name: "Windwalkers", slot: .boots, rarity: .legendary, effect: .focus,
                base: 4, perLevel: 0.4, symbol: "wind"),
    ]

    static func find(_ id: String) -> ItemDef? { all.first { $0.id == id } }
}

enum ChestTier: String, Codable, CaseIterable, Identifiable {
    case wooden, iron, golden

    var id: String { rawValue }
    var name: String { rawValue.capitalized + " Chest" }

    /// Chance of each rarity, in order common → legendary.
    var odds: [Double] {
        switch self {
        case .wooden: [0.70, 0.25, 0.045, 0.005]
        case .iron: [0.40, 0.40, 0.17, 0.03]
        case .golden: [0.0, 0.40, 0.45, 0.15]
        }
    }

    /// Scrap that comes with every opening.
    var bonusScrap: Int { [5, 15, 50][ChestTier.allCases.firstIndex(of: self)!] }

    func rollRarity(_ roll: Double) -> Rarity {
        var total = 0.0
        for (i, p) in odds.enumerated() {
            total += p
            if roll < total { return Rarity(rawValue: i)! }
        }
        return .legendary
    }
}

/// What a chest gave, for the reveal card.
struct ChestReveal: Identifiable, Equatable {
    let id = UUID()
    let tier: ChestTier
    let item: String
    let isNew: Bool
    let scrap: Int
}

enum ItemRules {
    /// A treasure break gives a Wooden Chest; this share of them are Iron instead.
    static let treasureIronChance = 0.2
    /// Record areas at multiples of this give an Iron Chest.
    static let ironChestEvery = 10
    /// The first clear of this area in Pebble Quarry gives a starter Wooden Chest.
    static let starterChestArea = 5
    static let gadgetCooldownCap = 0.6
    static let minerSpeedCap = 0.6
    static let critCap = 0.5
}
