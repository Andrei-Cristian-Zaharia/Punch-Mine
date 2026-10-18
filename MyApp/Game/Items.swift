import Foundation

enum Rarity: Int, Codable, CaseIterable, Comparable, Identifiable {
    case common, rare, epic, legendary
    /// Heart relics: never in chests, one per zone Heart.
    case mythic

    var id: Int { rawValue }
    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .common: "Common"
        case .rare: "Rare"
        case .epic: "Epic"
        case .legendary: "Legendary"
        case .mythic: "Mythic"
        }
    }

    var maxLevel: Int { [10, 15, 20, 25, 30][rawValue] }
    /// Scrap given for a duplicate.
    var scrapValue: Int { [8, 25, 80, 250, 0][rawValue] }
    /// Scrap to go from level 1 to 2; later levels cost 25% more each.
    var upgradeBase: Double { [10, 25, 60, 150, 300][rawValue] }
    /// Rarities a chest can roll.
    static let chestRarities: [Rarity] = [.common, .rare, .epic, .legendary]
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
    case feverDuration, chestLuck
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
    /// The set this item belongs to, if any (see `ItemSet`).
    var set: ItemSet? = nil
    /// The game it nods to, shown on the item card.
    var nod: String? = nil
    /// Mythic relics drop from this zone's Heart instead of chests.
    var heartZone: ZoneID? = nil

    func value(level: Int) -> Double { base + perLevel * Double(max(level, 1) - 1) }

    func upgradeCost(level: Int) -> Int { Int((rarity.upgradeBase * pow(1.25, Double(level - 1))).rounded()) }

    /// Effect text at a level, e.g. "+14% punch damage".
    func describe(level: Int) -> String {
        let v = value(level: level)
        // One decimal only when it matters: "2.5%", but "8%" rather than "8.0%".
        func pct(_ x: Double) -> String {
            let p = x * 100
            return NumberText.decimal(p, digits: p < 10 && abs(p - p.rounded()) >= 0.05 ? 1 : 0) + "%"
        }
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
        case .feverDuration: return "Fever lasts +\(NumberText.decimal(v, digits: 1)) s"
        case .chestLuck: return "+\(pct(v)) chance of Epic and Legendary from chests"
        }
    }

    /// Short effect text for a value that isn't tied to an item level (set bonuses).
    static func describe(_ effect: ItemEffect, value: Double) -> String {
        ItemDef(id: "", name: "", slot: .charm, rarity: .common, effect: effect, base: value, perLevel: 0, symbol: "").describe(level: 1)
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
        // Plumber's Kit (Super Mario)
        ItemDef(id: "plumbersCap", name: "Plumber's Cap", slot: .helmet, rarity: .common, effect: .coins,
                base: 0.06, perLevel: 0.015, symbol: "", set: .plumber, nod: "Super Mario"),
        ItemDef(id: "plumbersOveralls", name: "Plumber's Overalls", slot: .belt, rarity: .rare, effect: .treasureChance,
                base: 0.03, perLevel: 0.004, symbol: "", set: .plumber, nod: "Super Mario"),
        ItemDef(id: "powerStar", name: "Power Star", slot: .charm, rarity: .legendary, effect: .feverDuration,
                base: 3, perLevel: 0.3, symbol: "", set: .plumber, nod: "Super Mario"),
        ItemDef(id: "groundPoundBoots", name: "Ground-Pound Boots", slot: .boots, rarity: .rare, effect: .stomp,
                base: 0.10, perLevel: 0.012, symbol: "", set: .plumber, nod: "Super Mario"),
        // Blockcrafter's Gear (Minecraft)
        ItemDef(id: "diamondHelm", name: "Diamond Helm", slot: .helmet, rarity: .rare, effect: .penetration,
                base: 0.05, perLevel: 0.007, symbol: "", set: .blocky, nod: "Minecraft"),
        ItemDef(id: "craftingBelt", name: "Crafting Belt", slot: .belt, rarity: .common, effect: .strengthBonus,
                base: 0.06, perLevel: 0.02, symbol: "", set: .blocky, nod: "Minecraft"),
        ItemDef(id: "creeperCharm", name: "Creeper Charm", slot: .charm, rarity: .epic, effect: .quake,
                base: 0.12, perLevel: 0.015, symbol: "", set: .blocky, nod: "Minecraft"),
        ItemDef(id: "diamondBoots", name: "Diamond Boots", slot: .boots, rarity: .rare, effect: .minerSpeed,
                base: 0.07, perLevel: 0.012, symbol: "", set: .blocky, nod: "Minecraft"),
        // Hero's Garb (The Legend of Zelda)
        ItemDef(id: "herosCap", name: "Hero's Cap", slot: .helmet, rarity: .common, effect: .critChance,
                base: 0.02, perLevel: 0.003, symbol: "", set: .hero, nod: "The Legend of Zelda"),
        ItemDef(id: "rupeeWallet", name: "Rupee Wallet", slot: .belt, rarity: .rare, effect: .treasureReward,
                base: 0.4, perLevel: 0.08, symbol: "", set: .hero, nod: "The Legend of Zelda"),
        ItemDef(id: "fairyBottle", name: "Fairy in a Bottle", slot: .charm, rarity: .rare, effect: .critDamage,
                base: 0.25, perLevel: 0.04, symbol: "", set: .hero, nod: "The Legend of Zelda"),
        ItemDef(id: "pegasusBoots", name: "Pegasus Boots", slot: .boots, rarity: .epic, effect: .holdRate,
                base: 1.0, perLevel: 0.15, symbol: "", set: .hero, nod: "The Legend of Zelda"),
        // Standalone nods
        ItemDef(id: "estusFlask", name: "Estus Flask", slot: .charm, rarity: .rare, effect: .gadgetCooldown,
                base: 0.10, perLevel: 0.012, symbol: "", nod: "Dark Souls"),
        ItemDef(id: "companionCube", name: "Companion Cube", slot: .charm, rarity: .common, effect: .minerDamage,
                base: 0.08, perLevel: 0.025, symbol: "", nod: "Portal"),
        ItemDef(id: "goblinSack", name: "Treasure Goblin's Sack", slot: .belt, rarity: .epic, effect: .chestLuck,
                base: 0.25, perLevel: 0.03, symbol: "", nod: "Diablo"),
        ItemDef(id: "mushroomCap", name: "Spore Lamp Hood", slot: .helmet, rarity: .epic, effect: .offlineEfficiency,
                base: 0.10, perLevel: 0.01, symbol: "", nod: "Hollow Knight"),
        // Heart relics (Mythic): one per zone, from its first Heart
        ItemDef(id: "heartstoneBuckle", name: "Heartstone Buckle", slot: .belt, rarity: .mythic, effect: .punchDamage,
                base: 0.5, perLevel: 0.05, symbol: "", heartZone: .quarry),
        ItemDef(id: "prismHeart", name: "Prism Heart", slot: .charm, rarity: .mythic, effect: .doubleHit,
                base: 0.12, perLevel: 0.006, symbol: "", heartZone: .caverns),
        ItemDef(id: "magmaTreads", name: "Magma Treads", slot: .boots, rarity: .mythic, effect: .minerDamage,
                base: 0.6, perLevel: 0.06, symbol: "", heartZone: .magma),
        ItemDef(id: "tidecallerHelm", name: "Tidecaller's Helm", slot: .helmet, rarity: .mythic, effect: .coins,
                base: 0.4, perLevel: 0.04, symbol: "", heartZone: .ruins),
    ]

    static func find(_ id: String) -> ItemDef? { all.first { $0.id == id } }

    /// Items chests can give.
    static var chestPool: [ItemDef] { all.filter { $0.heartZone == nil } }
    static func relic(for zone: ZoneID) -> ItemDef? { all.first { $0.heartZone == zone } }
}

/// A random bonus stat rolled the first time an item is found. It doesn't scale with level; Scrap can reroll it.
struct Affix: Codable, Equatable {
    let effect: ItemEffect
    let value: Double
    /// 0…1: how close the roll is to the best possible one, for the UI.
    let quality: Double

    var text: String { ItemDef.describe(effect, value: value) }
}

enum Affixes {
    /// Stats an affix can roll, with the best roll for a Common. Rarer items roll higher (`rarityScale`).
    static let pool: [(effect: ItemEffect, best: Double)] = [
        (.punchDamage, 0.04), (.minerDamage, 0.05), (.coins, 0.04), (.critChance, 0.01), (.treasureChance, 0.005),
        (.clearBonus, 0.04), (.offlineEfficiency, 0.02), (.chestLuck, 0.03), (.feverDuration, 0.4),
    ]
    static let rarityScale: [Double] = [1, 1.5, 2.2, 3, 4]
    /// Worst roll as a share of the best.
    static let floor = 0.4

    static func best(_ effect: ItemEffect, rarity: Rarity) -> Double {
        (pool.first { $0.effect == effect }?.best ?? 0) * rarityScale[rarity.rawValue]
    }

    /// Never the item's own effect, so an affix always adds something new.
    static func roll<R: RandomNumberGenerator>(for def: ItemDef, using rng: inout R) -> Affix {
        let options = pool.filter { $0.effect != def.effect }
        let pick = options.randomElement(using: &rng)!
        let quality = Double.random(in: 0...1, using: &rng)
        let value = pick.best * rarityScale[def.rarity.rawValue] * (floor + (1 - floor) * quality)
        return Affix(effect: pick.effect, value: value, quality: quality)
    }

    static func roll(for def: ItemDef) -> Affix {
        var rng = SystemRandomNumberGenerator()
        return roll(for: def, using: &rng)
    }

    /// Heart relics come with a designed affix instead of a random one.
    static func relicAffix(_ def: ItemDef) -> Affix {
        switch def.heartZone {
        case .caverns: Affix(effect: .chestLuck, value: 0.10, quality: 1)
        case .magma: Affix(effect: .feverDuration, value: 1.5, quality: 1)
        case .ruins: Affix(effect: .offlineEfficiency, value: 0.05, quality: 1)
        default: Affix(effect: .critChance, value: 0.03, quality: 1)
        }
    }

    static func rerollCost(_ rarity: Rarity) -> Int { [30, 75, 180, 450, 900][rarity.rawValue] }
}

/// Themed sets: wearing 2 or 4 pieces adds a bonus on top of the items themselves.
enum ItemSet: String, Codable, CaseIterable, Identifiable {
    case plumber, blocky, hero

    var id: String { rawValue }

    var name: String {
        switch self {
        case .plumber: "Plumber's Kit"
        case .blocky: "Blockcrafter's Gear"
        case .hero: "Hero's Garb"
        }
    }

    /// (pieces needed, effect, value). Bonuses stack: four pieces get both.
    var bonuses: [(pieces: Int, effect: ItemEffect, value: Double)] {
        switch self {
        case .plumber: [(2, .coins, 0.15), (4, .lucky, 0.08)]
        case .blocky: [(2, .punchDamage, 0.15), (4, .penetration, 0.10)]
        case .hero: [(2, .critChance, 0.05), (4, .treasureChance, 0.05)]
        }
    }

    var pieces: [ItemDef] { ItemDef.all.filter { $0.set == self } }
}

enum ChestTier: String, Codable, CaseIterable, Identifiable {
    case wooden, iron, golden

    var id: String { rawValue }
    var name: String { rawValue.capitalized + " Chest" }

    /// Chance of each rarity, in order common → legendary.
    var odds: [Double] {
        switch self {
        case .wooden: [0.86, 0.129, 0.010, 0.001]
        case .iron: [0.62, 0.325, 0.05, 0.005]
        case .golden: [0.0, 0.66, 0.29, 0.05]
        }
    }

    /// Odds with Epic and Legendary scaled up by `luck` (+25% → ×1.25), taken from Common first, then Rare.
    func odds(luck: Double) -> [Double] {
        var o = odds
        guard luck > 0 else { return o }
        var extra = (o[2] + o[3]) * luck
        o[2] *= 1 + luck
        o[3] *= 1 + luck
        for i in [0, 1] {
            let take = min(o[i], extra)
            o[i] -= take
            extra -= take
        }
        return o
    }

    /// Scrap that comes with every opening.
    var bonusScrap: Int { [5, 15, 50][ChestTier.allCases.firstIndex(of: self)!] }

    func rollRarity(_ roll: Double, luck: Double = 0) -> Rarity {
        var total = 0.0
        for (i, p) in odds(luck: luck).enumerated() {
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
    /// The bad-luck guarantee decided this roll.
    var guaranteed = false
}

enum ItemRules {
    /// Share of treasure breaks that drop a chest at all.
    static let treasureChestChance = 0.35
    /// Of those, this share are Iron instead of Wooden.
    static let treasureIronChance = 0.12
    /// Record areas at multiples of this give an Iron Chest.
    static let ironChestEvery = 10
    /// The first clear of this area in Pebble Quarry gives a starter Wooden Chest.
    static let starterChestArea = 5
    static let gadgetCooldownCap = 0.6
    static let minerSpeedCap = 0.6
    static let critCap = 0.5
    static let chestLuckCap = 1.0
    /// Bad-luck protection: chests in a row without an Epic (or better) / Legendary before one is guaranteed.
    static let epicPity = 50
    static let legendaryPity = 250
}
