import Foundation

/// Rewarded ads the player starts by tapping a button. Interstitials ("break" ads) are separate: see `BreakAdRules`.
enum AdPlacement: String, Codable, CaseIterable, Identifiable {
    case coinRush, offlineDouble, treasureDouble, weeklyHeart, eventBoss
    case dailyDouble, freeGadget, eventRush, chestUpgrade

    var id: String { rawValue }

    var dailyLimit: Int {
        switch self {
        case .coinRush: 6
        case .offlineDouble: AdRules.dailyCap
        case .treasureDouble: 5
        case .weeklyHeart: WeeklyHeart.adAttemptsPerDay
        case .eventBoss: Seasons.bossAdTriesPerDay
        case .dailyDouble: 1
        case .freeGadget: 2
        case .eventRush: 3
        case .chestUpgrade: 3
        }
    }

    var title: String {
        switch self {
        case .coinRush: "Coin Rush"
        case .offlineDouble: "Double offline earnings"
        case .treasureDouble: "Double treasure"
        case .weeklyHeart: "Extra Weekly Heart try"
        case .eventBoss: "Extra boss attack"
        case .dailyDouble: "Double daily reward"
        case .freeGadget: "Free gadget"
        case .eventRush: "Event Rush"
        case .chestUpgrade: "Chest upgrade"
        }
    }
}

enum AdRules {
    static let dailyCap = 20
    /// Event Rush from an ad: double event currency for this long.
    static let eventRushSeconds = 300.0
    /// Coin Rush: ×2 zone coins for 2 minutes of play. Another ad adds time; it never raises the multiplier.
    static let coinRushSeconds = 120.0
    static let coinRushMultiplier = 2.0
    static let treasureOfferSeconds = 4.0
    /// Offline ×2 needs at least this long away.
    static let offlineDoubleMinimumSeconds = 600.0
}

/// Interstitials only at natural breaks the player chose (a manual prestige, entering another zone, leaving a
/// finished fight, the mini-mine, a Heart celebration or a run of chest openings), never in the
/// first minutes of a player's life or of a session, and never close to another ad.
enum BreakAdRules {
    /// No break ads until the player has played this long in total.
    static let minimumPlaySeconds = 10 * 60.0
    /// Play time between two ads of any kind; also counts from app launch.
    static let spacingSeconds = 3 * 60.0
    static let dailyCap = 10
    /// Closing the Items screen after opening at least this many chests counts as a break.
    static let chestRun = 3
    /// Leaving the mini-mine counts as a break after at least this long inside.
    static let miniMineSeconds = 60.0
}

/// Ad views per placement for the current local day.
struct AdLedger: Codable, Equatable {
    var day = ""
    var counts: [String: Int] = [:]

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Starts a fresh count when the local date changes.
    mutating func rollOver(now: Date = Date()) {
        let today = Self.dayKey(now)
        if day != today {
            day = today
            counts = [:]
        }
    }

    private static let breakKey = "break"

    func count(_ placement: AdPlacement) -> Int { counts[placement.rawValue, default: 0] }
    /// Rewarded views only; break ads have their own cap.
    var total: Int { counts.filter { $0.key != Self.breakKey }.values.reduce(0, +) }
    var breaks: Int { counts[Self.breakKey, default: 0] }

    mutating func record(_ placement: AdPlacement) {
        counts[placement.rawValue, default: 0] += 1
    }

    mutating func recordBreak() {
        counts[Self.breakKey, default: 0] += 1
    }
}

/// Shown once when a zone's Heart falls at a new record depth.
struct ConquestEvent: Identifiable, Equatable {
    let id = UUID()
    var zone: ZoneID = .quarry
    let area: Int
    /// True for the first Heart (the Crown), false for a Crown Star.
    let isCrown: Bool
    let perkCoins: Int
    let coinMultiplier: Double
}

/// Shown for a few seconds after a treasure break.
struct TreasureOffer: Equatable, Identifiable {
    let id = UUID()
    let coins: Double
    let expires: Double
}
