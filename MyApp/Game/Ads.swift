import Foundation

/// Every ad is a rewarded ad the player starts by tapping a button. No interstitials, no banners.
enum AdPlacement: String, Codable, CaseIterable, Identifiable {
    case coinRush, offlineDouble, treasureDouble

    var id: String { rawValue }

    var dailyLimit: Int {
        switch self {
        case .coinRush: 6
        case .offlineDouble: AdRules.dailyCap
        case .treasureDouble: 5
        }
    }

    var title: String {
        switch self {
        case .coinRush: "Coin Rush"
        case .offlineDouble: "Double offline earnings"
        case .treasureDouble: "Double treasure"
        }
    }
}

enum AdRules {
    static let dailyCap = 15
    /// Coin Rush: ×2 zone coins for 10 minutes of play. Another ad adds time; it never raises the multiplier.
    static let coinRushSeconds = 600.0
    static let coinRushMultiplier = 2.0
    static let treasureOfferSeconds = 4.0
    /// Offline ×2 needs at least this long away.
    static let offlineDoubleMinimumSeconds = 600.0
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

    func count(_ placement: AdPlacement) -> Int { counts[placement.rawValue, default: 0] }
    var total: Int { counts.values.reduce(0, +) }

    mutating func record(_ placement: AdPlacement) {
        counts[placement.rawValue, default: 0] += 1
    }
}

/// Shown once when a Heart of the Quarry falls at a new record depth.
struct ConquestEvent: Identifiable, Equatable {
    let id = UUID()
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
