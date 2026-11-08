import Foundation

/// Lifetime totals for the Stats screen. Never reset by prestige.
struct LifetimeStats: Codable, Equatable {
    var punches = 0
    var crits = 0
    var blocksBroken = 0
    var treasuresBroken = 0
    var areasCleared = 0
    var chestsOpened = 0
    var dailyClaims = 0
    var playSeconds = 0.0
    /// Zone id → coins earned there, across every run.
    var coins: [String: Double] = [:]

    init() {}

    /// Best guess for saves from before stats existed: what the save still knows.
    init(legacyFrom save: SaveData) {
        for (zone, run) in save.runs { coins[zone] = run.lifetimeCoins }
        areasCleared = save.records.values.map(\.bestCleared).reduce(0, +)
        playSeconds = save.runs.values.map(\.playSeconds).reduce(0, +)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        punches = try c.decodeIfPresent(Int.self, forKey: .punches) ?? 0
        crits = try c.decodeIfPresent(Int.self, forKey: .crits) ?? 0
        blocksBroken = try c.decodeIfPresent(Int.self, forKey: .blocksBroken) ?? 0
        treasuresBroken = try c.decodeIfPresent(Int.self, forKey: .treasuresBroken) ?? 0
        areasCleared = try c.decodeIfPresent(Int.self, forKey: .areasCleared) ?? 0
        chestsOpened = try c.decodeIfPresent(Int.self, forKey: .chestsOpened) ?? 0
        dailyClaims = try c.decodeIfPresent(Int.self, forKey: .dailyClaims) ?? 0
        playSeconds = try c.decodeIfPresent(Double.self, forKey: .playSeconds) ?? 0
        coins = try c.decodeIfPresent([String: Double].self, forKey: .coins) ?? [:]
    }
}

/// One day of the 7-day login track.
struct DailyReward: Identifiable, Equatable {
    /// 1…7.
    let day: Int
    let chests: [ChestTier: Int]
    let scrap: Int

    var id: Int { day }

    var text: String {
        var parts = chests.sorted { $0.key.order < $1.key.order }.map { $0.value > 1 ? "\($0.value) \($0.key.name)s" : $0.key.name }
        if scrap > 0 { parts.append("\(scrap) Scrap") }
        return parts.joined(separator: " + ")
    }

    static let track: [DailyReward] = [
        DailyReward(day: 1, chests: [.wooden: 1], scrap: 0),
        DailyReward(day: 2, chests: [:], scrap: 60),
        DailyReward(day: 3, chests: [.wooden: 2], scrap: 0),
        DailyReward(day: 4, chests: [.iron: 1], scrap: 0),
        DailyReward(day: 5, chests: [:], scrap: 200),
        DailyReward(day: 6, chests: [.iron: 2], scrap: 0),
        DailyReward(day: 7, chests: [.golden: 1], scrap: 100),
    ]
}

extension ChestTier {
    var order: Int { ChestTier.allCases.firstIndex(of: self)! }
}

/// Login streak. A day is a local calendar day; missing one starts the track over.
struct DailyState: Codable, Equatable {
    /// "yyyy-MM-dd" of the last claim.
    var lastClaimDay: String?
    /// Days claimed in the current streak (0 before the first claim).
    var streak = 0
    /// Day the reward was doubled with an ad.
    var doubledDay: String?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastClaimDay = try c.decodeIfPresent(String.self, forKey: .lastClaimDay)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        doubledDay = try c.decodeIfPresent(String.self, forKey: .doubledDay)
    }
}

enum Daily {
    /// The track opens once the player has seen chests (the starter chest comes at area 5).
    static let unlockArea = 6

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Whether `last` was the calendar day before `now`.
    static func isYesterday(_ last: String, now: Date, calendar: Calendar = .current) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
        return dayKey(yesterday, calendar: calendar) == last
    }
}
