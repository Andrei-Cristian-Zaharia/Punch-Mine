import Foundation

enum PerkBranch: String, CaseIterable, Identifiable {
    case power = "Power", industry = "Industry", exploration = "Exploration"
    var id: String { rawValue }
}

/// The perk tree. Costs: next level = base + step × L. Cases are in tree order: each perk follows its prerequisite.
enum Perk: String, Codable, CaseIterable, Identifiable {
    // Power
    case heavyFists, keenEye, brutalCrits, piercer, resonantKnuckles, titanPunch, quarryBrawler
    // Industry
    case foreman, dayOneCrew, doubleShift, treasureCrew, nightShift, overtime, toolsmith, sharedDrills, gadgeteer, coldCrew
    // Exploration
    case seedMoney, scrapper, expressElevator, prospector, luckyHaul, chestHunter, surveyor, geodeSense

    var id: String { rawValue }

    var name: String {
        switch self {
        case .heavyFists: "Heavy Fists"
        case .keenEye: "Keen Eye"
        case .brutalCrits: "Brutal Crits"
        case .piercer: "Piercer"
        case .resonantKnuckles: "Resonant Knuckles"
        case .titanPunch: "Titan Punch"
        case .quarryBrawler: "Quarry Brawler"
        case .foreman: "Foreman"
        case .dayOneCrew: "Day-One Crew"
        case .doubleShift: "Double Shift"
        case .treasureCrew: "Treasure Crew"
        case .nightShift: "Night Shift"
        case .overtime: "Overtime"
        case .toolsmith: "Toolsmith"
        case .sharedDrills: "Shared Drills"
        case .gadgeteer: "Gadgeteer"
        case .coldCrew: "Cold Crew"
        case .seedMoney: "Seed Money"
        case .scrapper: "Scrapper"
        case .expressElevator: "Express Elevator"
        case .prospector: "Prospector"
        case .luckyHaul: "Lucky Haul"
        case .chestHunter: "Chest Hunter"
        case .surveyor: "Surveyor"
        case .geodeSense: "Geode Sense"
        }
    }

    var branch: PerkBranch {
        switch self {
        case .heavyFists, .keenEye, .brutalCrits, .piercer, .resonantKnuckles, .titanPunch, .quarryBrawler: .power
        case .foreman, .dayOneCrew, .doubleShift, .treasureCrew, .nightShift, .overtime, .toolsmith, .sharedDrills, .gadgeteer,
             .coldCrew: .industry
        default: .exploration
        }
    }

    /// Zone this perk is limited to, if any.
    var zoneOnly: String? {
        switch self {
        case .quarryBrawler: "Zone 1"
        case .resonantKnuckles, .geodeSense: "Zone 2"
        case .coldCrew: "Zone 3"
        default: nil
        }
    }

    var isCapstone: Bool { self == .titanPunch }

    /// Indent depth in the tree view.
    var depth: Int {
        switch self {
        case .heavyFists, .foreman, .seedMoney: 0
        case .brutalCrits, .resonantKnuckles, .titanPunch, .treasureCrew, .overtime, .sharedDrills, .gadgeteer,
             .luckyHaul, .chestHunter, .surveyor, .geodeSense: 2
        default: 1
        }
    }

    var requirement: (perk: Perk, level: Int)? {
        switch self {
        case .keenEye, .piercer: (.heavyFists, 3)
        case .brutalCrits: (.keenEye, 5)
        case .resonantKnuckles: (.piercer, 3)
        case .titanPunch: (.piercer, 5)
        case .quarryBrawler: (.heavyFists, 5)
        case .dayOneCrew: (.foreman, 2)
        case .doubleShift: (.foreman, 4)
        case .treasureCrew: (.doubleShift, 1)
        case .nightShift, .toolsmith: (.foreman, 3)
        case .overtime: (.nightShift, 1)
        case .sharedDrills: (.toolsmith, 3)
        case .gadgeteer: (.toolsmith, 2)
        case .coldCrew: (.foreman, 5)
        case .scrapper: (.seedMoney, 2)
        case .expressElevator: (.seedMoney, 3)
        case .prospector: (.seedMoney, 1)
        case .luckyHaul, .chestHunter, .surveyor: (.prospector, 2)
        case .geodeSense: (.prospector, 3)
        default: nil
        }
    }

    /// A second prerequisite, for the capstone.
    var secondRequirement: (perk: Perk, level: Int)? { self == .titanPunch ? (.brutalCrits, 3) : nil }

    var maxLevel: Int {
        switch self {
        case .heavyFists, .foreman: 20
        case .keenEye, .piercer: 10
        case .quarryBrawler, .nightShift, .resonantKnuckles: 4
        case .dayOneCrew: 2
        case .doubleShift, .treasureCrew: 3
        case .expressElevator: 3
        case .titanPunch, .sharedDrills, .coldCrew, .geodeSense: 1
        case .seedMoney, .prospector, .surveyor, .brutalCrits, .overtime, .toolsmith, .gadgeteer,
             .scrapper, .luckyHaul, .chestHunter: 5
        }
    }

    /// Cost of the next level when the current level is `level`. Multi-level perks grow exponentially, so a full
    /// tree takes many deep prestiges (about 13,600 PC in total).
    func cost(level: Int) -> Int {
        func grow(_ base: Double, _ rate: Double) -> Int { Int((base * pow(rate, Double(level))).rounded()) }
        func table(_ costs: [Int]) -> Int { costs[min(level, costs.count - 1)] }
        switch self {
        case .heavyFists, .foreman: return grow(6, 1.3)
        case .keenEye, .piercer: return grow(10, 1.32)
        case .brutalCrits: return grow(40, 1.45)
        case .resonantKnuckles: return grow(25, 1.5)
        case .titanPunch: return 600
        case .quarryBrawler: return grow(20, 1.5)
        case .dayOneCrew: return table([30, 120])
        case .doubleShift: return grow(40, 1.6)
        case .treasureCrew: return table([150, 400, 900])
        case .nightShift: return grow(20, 1.6)
        case .overtime: return grow(25, 1.5)
        case .toolsmith: return grow(15, 1.45)
        case .sharedDrills: return 250
        case .gadgeteer: return grow(25, 1.45)
        case .coldCrew: return 200
        case .seedMoney: return table([10, 25, 60, 150, 400])
        case .scrapper: return grow(20, 1.5)
        case .expressElevator: return table([60, 180, 500])
        case .prospector: return grow(10, 1.4)
        case .luckyHaul: return grow(15, 1.45)
        case .chestHunter: return grow(25, 1.5)
        case .surveyor: return grow(20, 1.45)
        case .geodeSense: return 150
        }
    }

    /// Perk Coins needed to max this perk from zero.
    var totalCost: Int { (0..<maxLevel).map { cost(level: $0) }.reduce(0, +) }

    /// Share of normal damage miners deal to treasure.
    static func treasureCrewShare(level: Int) -> Double { Double(min(level, 3)) / 3 }

    static let seedMoneyAmounts: [Double] = [0, 200, 600, 1_800, 5_400, 16_200]

    /// What the perk does at `level`, for the UI.
    func effect(level: Int) -> String {
        switch self {
        case .heavyFists: "+\(10 * level)% punch damage"
        case .keenEye: "+\(level)% crit chance"
        case .brutalCrits: "+\(NumberText.decimal(0.2 * Double(level)))× crit damage"
        case .piercer: "+\(3 * level)% armor penetration"
        case .resonantKnuckles: "Crystal chains +\(8 * level) points"
        case .titanPunch: "Every 20th punch ×10 and ignores armor"
        case .quarryBrawler: "+\(25 * level)% punch damage in Zone 1"
        case .foreman: "+\(15 * level)% miner damage"
        case .dayOneCrew: "Start each run with \(level) miner\(level == 1 ? "" : "s")"
        case .doubleShift: "Miners swing \(10 * level)% faster"
        case .treasureCrew: "Miners mine treasure at \(Int((Perk.treasureCrewShare(level: level) * 100).rounded()))% damage"
        case .nightShift: "Offline cap \(2 + level) h"
        case .overtime: "+\(5 * level) points offline earnings rate"
        case .toolsmith: "Tools \(8 * level)% cheaper"
        case .sharedDrills: "Miners use half your tool's penetration"
        case .gadgeteer: "Gadget cooldowns −\(5 * level)%"
        case .coldCrew: "Miner hits stop regrowth for 3 s"
        case .seedMoney: "Start each run with \(NumberText.format(Perk.seedMoneyAmounts[min(level, 5)])) coins"
        case .scrapper: "+\(10 * level)% Scrap from chests"
        case .expressElevator: "Start each run at area \(1 + 2 * level)"
        case .prospector: "Treasure chance \(15 + 3 * level)%"
        case .luckyHaul: "Treasure pays +\(20 * level)%"
        case .chestHunter: "\(5 * level)% chance treasure drops an extra chest"
        case .surveyor: "−\(5 * level)% zone unlock coin costs"
        case .geodeSense: "Zone 2 treasure pays +50%"
        }
    }

    var summary: String {
        switch self {
        case .heavyFists: "+10% punch damage per level"
        case .keenEye: "+1% crit chance per level"
        case .brutalCrits: "+0.2× crit damage per level"
        case .piercer: "+3% armor penetration per level"
        case .resonantKnuckles: "Zone 2: crystal chains +8 points per level"
        case .titanPunch: "Capstone: every 20th punch ×10, ignores armor"
        case .quarryBrawler: "+25% punch damage in Zone 1 per level"
        case .foreman: "+15% miner damage per level"
        case .dayOneCrew: "Start runs with miners already hired"
        case .doubleShift: "Miners swing 10% faster per level"
        case .treasureCrew: "Miners can mine treasure: 33% more damage per level"
        case .nightShift: "+1 h offline cap per level"
        case .overtime: "+5 points offline earnings rate per level"
        case .toolsmith: "Tools 8% cheaper per level"
        case .sharedDrills: "Miners get half your tool's penetration"
        case .gadgeteer: "Gadget cooldowns −5% per level"
        case .coldCrew: "Zone 3: miner hits stop regrowth"
        case .seedMoney: "Start runs with coins"
        case .scrapper: "+10% Scrap from chests per level"
        case .expressElevator: "Start each run 2 areas deeper per level"
        case .prospector: "+3 points treasure chance per level"
        case .luckyHaul: "Treasure pays +20% per level"
        case .chestHunter: "+5% chance per level of an extra chest from treasure"
        case .surveyor: "−5% zone unlock costs per level"
        case .geodeSense: "Zone 2 treasure pays +50%"
        }
    }
}

enum Prestige {
    static let firstUnlockArea = 12
    static let floorBelowBest = 8
    /// PC = floor(Z · 0.15 · (A − 5)²) + 2 · Z · max(0, A − A_best); the record bonus needs a previous prestige.
    static func depthReward(area: Int, multiplier: Double = 1) -> Int {
        Int((multiplier * 0.15 * pow(Double(max(area - 5, 0)), 2)).rounded(.down))
    }

    static func recordBonus(area: Int, bestPrestigeArea: Int, multiplier: Double = 1) -> Int {
        guard bestPrestigeArea > 0 else { return 0 }
        return Int(2 * multiplier * Double(max(0, area - bestPrestigeArea)))
    }

    static func requiredArea(bestPrestigeArea: Int) -> Int {
        max(firstUnlockArea, bestPrestigeArea - floorBelowBest)
    }
}

struct OfflineEntry: Identifiable, Equatable {
    var id: ZoneID { zone }
    let zone: ZoneID
    let seconds: Double
    let cappedSeconds: Double
    let coinsPerSecond: Double
    let efficiency: Double
    let coins: Double
}

struct OfflineReport: Identifiable, Equatable {
    let id = UUID()
    /// Time since the app was last open.
    let seconds: Double
    let entries: [OfflineEntry]
}

enum Offline {
    static let baseEfficiency = 0.25
    static let baseCapHours = 2.0
    static let minimumSeconds = 60.0
}
