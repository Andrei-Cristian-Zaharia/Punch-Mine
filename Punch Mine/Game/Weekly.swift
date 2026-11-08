import Foundation

/// This week's twist on the Weekly Heart. Every player gets the same one, so the leaderboard is fair.
enum WeeklyModifier: String, CaseIterable, Codable {
    case armoured, regenerating, critical, phasing

    var name: String {
        switch self {
        case .armoured: "Armoured Heart"
        case .regenerating: "Regenerating Heart"
        case .critical: "Brittle Heart"
        case .phasing: "Phantom Heart"
        }
    }

    var text: String {
        switch self {
        case .armoured: "Thick armour cuts your hits by up to \(Int((1 - WeeklyHeart.armourFloor) * 100))%. Armour Penetration wins this week."
        case .regenerating: "Heals \(Int(WeeklyHeart.regenPerSecond * 100))% of its health every second. Hit hard and fast."
        case .critical: "Critical hits deal double damage, and you crit \(Int(WeeklyHeart.brittleCritBonus * 100))% more often."
        case .phasing: "Fades out of reach every few seconds. The first second after it returns, every punch crits."
        }
    }

    var symbol: String {
        switch self {
        case .armoured: "shield.fill"
        case .regenerating: "cross.case.fill"
        case .critical: "bolt.fill"
        case .phasing: "moon.stars.fill"
        }
    }
}

typealias WeeklyReward = Reward

/// Personal goals for one week, paid out as soon as the score is reached.
struct WeeklyMilestone: Identifiable, Equatable {
    /// Tiers broken in a single fight.
    let tiers: Int
    let reward: WeeklyReward
    var id: Int { tiers }
}

/// A leaderboard placement for a finished week, by rank or by share of players.
struct WeeklyRankBand: Identifiable, Equatable {
    let name: String
    let reward: WeeklyReward
    var id: String { name }
}

/// The final placement of a past week, kept for the Weekly Heart screen.
struct WeeklyRankResult: Codable, Equatable {
    let week: Int
    let rank: Int
    let total: Int
    let reward: WeeklyReward
    var band: String
    var seen = false
}

/// A 30-second fight against an endless stack of Heart tiers. Each broken tier spawns a tougher one.
struct WeeklyFight: Equatable {
    let modifier: WeeklyModifier
    var tier = 1
    var hp: Double
    var maxHP: Double
    var timeLeft = WeeklyHeart.fightSeconds
    var damage = 0.0
    var punches = 0
    /// Phantom Heart: faded out of reach, and seconds left in the current phase.
    var faded = false
    var phaseLeft = WeeklyHeart.phaseSolidSeconds
    var returnedAt = -10.0
    var elapsed = 0.0
    /// For the hit pop-ups.
    var lastHit = 0.0
    var lastCrit = false

    init(modifier: WeeklyModifier) {
        self.modifier = modifier
        maxHP = WeeklyHeart.hp(tier: 1)
        hp = maxHP
    }

    var tiersBroken: Int { tier - 1 }
    var progress: Double {
        guard maxHP > 0, maxHP.isFinite, hp.isFinite else { return 0 }
        return min(1, max(0, 1 - hp / maxHP))
    }
    var score: Int { WeeklyHeart.score(tiersBroken: tiersBroken, progress: progress) }
    var isOver: Bool { timeLeft <= 0 }
}

/// What one finished fight earned.
struct WeeklyResult: Identifiable, Equatable {
    let id = UUID()
    let score: Int
    let isBest: Bool
    let milestones: [WeeklyMilestone]
}

/// The player's Weekly Heart progress. Weeks run Monday 00:00 UTC to Monday 00:00 UTC, like the leaderboard.
struct WeeklyState: Codable, Equatable {
    var week = -1
    /// Best score this week (see `WeeklyHeart.score`).
    var best = 0
    var milestones: [Int] = []
    /// Local day the counts below belong to.
    var day = ""
    var attemptsUsed = 0
    /// Extra tries from rewarded ads today.
    var bonusAttempts = 0
    /// Past weeks whose leaderboard reward was already paid.
    var rankClaimedWeeks: [Int] = []
    var lastRank: WeeklyRankResult?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        week = try c.decodeIfPresent(Int.self, forKey: .week) ?? -1
        best = try c.decodeIfPresent(Int.self, forKey: .best) ?? 0
        milestones = try c.decodeIfPresent([Int].self, forKey: .milestones) ?? []
        day = try c.decodeIfPresent(String.self, forKey: .day) ?? ""
        attemptsUsed = try c.decodeIfPresent(Int.self, forKey: .attemptsUsed) ?? 0
        bonusAttempts = try c.decodeIfPresent(Int.self, forKey: .bonusAttempts) ?? 0
        rankClaimedWeeks = try c.decodeIfPresent([Int].self, forKey: .rankClaimedWeeks) ?? []
        lastRank = try c.decodeIfPresent(WeeklyRankResult.self, forKey: .lastRank)
    }

    /// Starts a new week's score and a new day's tries when the calendar moves on.
    mutating func rollOver(now: Date) {
        let current = WeeklyHeart.week(of: now)
        if week != current {
            week = current
            best = 0
            milestones = []
        }
        let today = Daily.dayKey(now)
        if day != today {
            day = today
            attemptsUsed = 0
            bonusAttempts = 0
        }
    }
}

enum WeeklyHeart {
    /// Opens once the player knows the basics.
    static let unlockArea = 12
    /// Must match the leaderboard in App Store Connect (recurring, starts on a Monday 00:00 UTC, lasts 1 week).
    static let leaderboardID = "weekly_heart"
    /// Monday 5 January 2026, 00:00 UTC. Week 0.
    static let epoch = Date(timeIntervalSince1970: 1_767_571_200)
    static let weekSeconds = 7 * 86_400.0

    static let fightSeconds = 30.0
    static let freeAttemptsPerDay = 3
    /// Caps on a single hit and on tiers, so huge late-game numbers stay finite.
    static let maxHit = 1e300
    static let maxTier = 4_000
    /// Extra tries a day from rewarded ads.
    static let adAttemptsPerDay = 3
    static let baseHP = 25.0
    /// Each tier is 18% tougher than the last, so the score grows with the log of your damage.
    static let tierGrowth = 1.18

    static let armourFloor = 0.4
    /// In boss fights your crew adds at most this many of your punches per second, so tapping decides the fight.
    static let crewCapPunchesPerSecond = 4.0
    static let regenPerSecond = 0.04
    static let brittleCritBonus = 0.10
    static let brittleCritFactor = 2.0
    static let phaseSolidSeconds = 3.5
    static let phaseFadedSeconds = 1.5
    static let phaseReturnCritWindow = 1.0

    static func week(of date: Date) -> Int { Int((date.timeIntervalSince(epoch) / weekSeconds).rounded(.down)) }
    static func start(of week: Int) -> Date { epoch.addingTimeInterval(Double(week) * weekSeconds) }
    static func end(of week: Int) -> Date { start(of: week + 1) }
    static func modifier(week: Int) -> WeeklyModifier {
        let all = WeeklyModifier.allCases
        return all[((week % all.count) + all.count) % all.count]
    }

    static func hp(tier: Int) -> Double { (baseHP * pow(tierGrowth, Double(tier - 1))).rounded() }

    /// Tiers broken × 100 plus the share of the next tier, so 12.47 tiers is 1247. The leaderboard shows it with 2 decimals.
    static func score(tiersBroken: Int, progress: Double) -> Int {
        tiersBroken * 100 + min(99, max(0, Int((progress * 100).rounded(.down))))
    }
    static func scoreText(_ score: Int) -> String { String(format: "%d.%02d", score / 100, score % 100) }

    static let milestones: [WeeklyMilestone] = [
        WeeklyMilestone(tiers: 10, reward: WeeklyReward(chests: [.wooden: 2])),
        WeeklyMilestone(tiers: 25, reward: WeeklyReward(chests: [.iron: 1], scrap: 50)),
        WeeklyMilestone(tiers: 50, reward: WeeklyReward(chests: [.iron: 2], scrap: 100)),
        WeeklyMilestone(tiers: 100, reward: WeeklyReward(chests: [.golden: 1], scrap: 150)),
    ]

    static let rankBands: [WeeklyRankBand] = [
        WeeklyRankBand(name: "1st place", reward: WeeklyReward(chests: [.golden: 3], scrap: 1_000, perkCoins: 300,
                                                               cosmetics: ["icon.gold", "fist.golden", "title.champion"])),
        WeeklyRankBand(name: "2nd place", reward: WeeklyReward(chests: [.golden: 2], scrap: 600, perkCoins: 200,
                                                               cosmetics: ["fist.golden", "title.champion"])),
        WeeklyRankBand(name: "3rd place", reward: WeeklyReward(chests: [.golden: 1, .iron: 2], scrap: 400, perkCoins: 150,
                                                               cosmetics: ["fist.golden", "title.champion"])),
        WeeklyRankBand(name: "Top 10%", reward: WeeklyReward(chests: [.golden: 1], scrap: 150)),
        WeeklyRankBand(name: "Top 25%", reward: WeeklyReward(chests: [.iron: 2], scrap: 100)),
        WeeklyRankBand(name: "Top 50%", reward: WeeklyReward(chests: [.iron: 1], scrap: 50)),
        WeeklyRankBand(name: "Took part", reward: WeeklyReward(chests: [.wooden: 2])),
    ]

    /// Ranks 1–3 by place; everyone else by their share of the field.
    static func band(rank: Int, total: Int) -> WeeklyRankBand {
        if (1...3).contains(rank) { return rankBands[rank - 1] }
        let share = Double(rank) / Double(max(total, 1))
        if share <= 0.10 { return rankBands[3] }
        if share <= 0.25 { return rankBands[4] }
        if share <= 0.50 { return rankBands[5] }
        return rankBands[6]
    }
}
