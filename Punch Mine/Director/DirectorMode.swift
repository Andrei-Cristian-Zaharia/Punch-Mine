#if DEBUG
import SwiftUI
import Combine

// MARK: - Director mode (Debug builds only)
//
// Scripted gameplay scenarios for recording promo footage, e.g. in CI
// (.github/workflows/record-scenarios.yml):
//
//   -scenario <name>|random     one of `Scenario`, or random (the seed picks one)
//   -scenarioSeed 12345         seeds everything: the zone, area and loadout,
//                               the terrain, every roll in play (crits, lucky
//                               coins, chests, zaps) and the autopilot's moves.
//                               Without it the clock picks a seed.
//   -scenarioDuration 47        seconds the autopilot plays; afterwards the app
//                               idles (miners keep digging)
//   -scenarioCapture 36         record this many seconds offline at exactly
//                               60 fps (DirectorCapture.swift) to
//                               Documents/DirectorCapture/capture.mp4
//   -scenarioZone ruins         heartFight / areaBlitz / weeklyHeart: force the zone
//   -scenarioArea 42            mine scenarios except heartFight: force the start area
//   -scenarioStyle holder       force the autopilot style (tapper, holder, sweeper, focus)
//   -scenarioTwist phasing      weeklyHeart: force the weekly twist
//   -scenarioDate 2026-11-20    in-game date (events, weekly twist). Default: today, UTC noon
//
// A directed launch goes straight into the mine (or the Weekly Heart fight),
// with no splash, consent form, ads, iCloud, Game Center, store, daily /
// event / zone pop-ups, tips or break ads. It plays on a fresh in-memory
// profile that is never saved, so it cannot touch real progress, and it
// needs no network.
//
// The autopilot plays through the same entry points as a finger:
// `beginPress` / `movePress` / `endPress` (the grid's drag gesture),
// `useGadget` (the gadget buttons), `use` (the stash) and `punchWeekly` (the
// Weekly Heart's gesture). It never calls a "win" function.
//
// Pacing: the user wants areas to break quickly and move on, so a pacer
// sets the punch power for each area from that area's real HP, aiming at
// a per-scenario clear time (about 3-5 s), and corrects itself from how long
// the last area really took. The power comes from Starforged Fists levels
// (and Strength), the game's own uncapped multiplier, so every number on
// screen is the game's real damage maths.
//
// Logging (stderr, prefix "[Director]"; CI reads these lines):
//   PLAN {json}       once, before anything is recorded
//   status …          once per second of scenario time
//   CAPTURE …         from DirectorCapture.swift
//   WARNING …         anything suspicious (CI turns it into a warning)

enum Scenario: String, CaseIterable {
    case heartFight, areaBlitz, crystalChain, highTide, magmaVents, weeklyHeart
    case quarryMining, cavernsMining, magmaMining, ruinsMining, cryptMining

    /// The zone of a plain mining scenario.
    var miningZone: ZoneID? {
        switch self {
        case .quarryMining: .quarry
        case .cavernsMining: .caverns
        case .magmaMining: .magma
        case .ruinsMining: .ruins
        case .cryptMining: .crypt
        default: nil
        }
    }
}

/// How the autopilot's finger mostly plays.
enum PlayStyle: String, CaseIterable {
    /// Rapid taps, block after block.
    case tapper
    /// Holds and slides to the next block when one breaks.
    case holder
    /// Holds and sweeps along rows or columns.
    case sweeper
    /// Holds on one block until it breaks (Magma regrowth never undoes it).
    case focus
}

/// One stretch of the autopilot's plan.
struct DirectorMove {
    enum Kind: String { case taps, hold, sweep, ring, pause }
    var kind: Kind
    var start: Double
    var duration: Double
    /// Taps per second (taps, ring).
    var rate: Double = 9
    /// Sweep: along rows (true) or columns.
    var rows = true
    /// Sweep: seconds per cell.
    var cellSeconds = 0.45
}

/// Everything rolled for one clip.
struct DirectorPlan {
    var scenario: Scenario
    var zone: ZoneID = .quarry
    var area = 20
    var style = PlayStyle.tapper
    /// Pacer target: seconds to clear one area.
    var clearSeconds = 4.0
    var levels: [UpgradeKind: Int] = [:]
    var gadgets = false
    var toolIndex = -1
    var perks: [Perk: Int] = [:]
    var coins = 0.0
    var fist: String?
    var burst: String?
    var pet: String?
    var chests = 0
    var boost: Consumable?
    var dynamiteAt: Double?
    var hornAt: Double?
    // heartFight
    var heartStart = 1.0
    var killAt = 26.0
    // highTide / ruinsMining
    var tideAt: Double?
    var tideGap = 10.0
    // magmaVents / magmaMining
    var ventAt: Double?
    var ventGap = 13.0
    // crystalChain
    var layoutTries = 1
    // weeklyHeart
    var twist = WeeklyModifier.armoured
    var tierGoal = 100
    var moves: [DirectorMove] = []
    var date = Date()

    var event: String { Seasons.active(at: date)?.name ?? "none" }

    /// Scenario + the parameters that change what the clip looks like. CI skips a repeat within one run.
    var key: String {
        var parts = [scenario.rawValue]
        switch scenario {
        case .heartFight:
            parts += [zone.rawValue, "hp\(Int((heartStart * 100).rounded()))", "kill\(Int(killAt.rounded()))", fist ?? "noFist"]
        case .areaBlitz:
            parts += [zone.rawValue, "a\(area)", boost?.rawValue ?? "noBoost"]
        case .crystalChain:
            parts += ["a\(area)", "res\(perks[.resonantKnuckles] ?? 0)"]
        case .highTide:
            parts += ["a\(area)", "tide\(Int((tideAt ?? 0).rounded()))", "gap\(Int(tideGap.rounded()))"]
        case .magmaVents:
            parts += ["a\(area)", "vent\(Int((ventAt ?? 0).rounded()))", "gap\(Int(ventGap.rounded()))"]
        case .weeklyHeart:
            parts += [twist.rawValue, zone.rawValue, "tier\(tierGoal)"]
        case .quarryMining, .cavernsMining, .magmaMining, .ruinsMining, .cryptMining:
            let crew = [UpgradeKind.hireMiner, .hireDriller, .hireBlaster].map { String(levels[$0] ?? 0) }.joined(separator: "-")
            parts += ["a\(area)", "crew\(crew)", pet ?? "noPet"]
        }
        parts.append(style.rawValue)
        return parts.joined(separator: "|")
    }
}

/// The virtual clock while capturing: views that animate observe it.
final class DirectorClock: ObservableObject {
    @Published var date = Date(timeIntervalSinceReferenceDate: 0)
}

final class Director {
    static let shared = Director()

    let scenario: Scenario?
    let requested: String?
    let seed: UInt64
    let duration: Double
    /// `-scenarioCapture <seconds>`: offline 60 fps capture on a virtual clock.
    let captureSeconds: Double?
    /// The in-game date (events, the weekly twist). Fixed for the whole launch.
    let gameDate: Date
    private(set) var plan: DirectorPlan?

    var isActive: Bool { scenario != nil }
    var isCapturing: Bool { isActive && captureSeconds != nil }
    static let captureFPS = 60

    /// Observed by animated views while capturing. Its date is `captureOrigin` + virtual seconds.
    let clock = DirectorClock()
    static let captureOrigin: TimeInterval = 1_000_000
    private(set) var virtualNow: Double = 0
    /// First captured frame that shows gameplay (CI measures real fps from there on).
    private(set) var captureRunFrom: Int?
    private var lastRender: Date?
    #if canImport(UIKit)
    private var recorder: DirectorRecorder?
    #endif

    /// Rolls the game makes in play (crits, lucky coins, chests, zaps).
    private var gameRNG: SplitMix64
    /// Rolls views make (Weekly Heart hit positions).
    private var viewRNG: SplitMix64
    /// Choices the autopilot makes while playing; kept apart so they never shift the plan.
    private var liveRNG: SplitMix64

    private weak var game: GameModel?
    private var began = false
    private var finished = false
    /// Scenario time in seconds.
    private(set) var t = 0.0

    // Autopilot
    private var moveIndex = 0
    private var holding: Int?
    private var tapTarget: Int?
    private var nextTapAt = 0.0
    private var lastCell = 12
    private var sweepPath: [Int] = []
    private var sweepPos = 0
    private var sweepNextAt = 0.0
    private var sweepMove = -1
    private var armedAt: Double?
    private var dynamiteDone = false
    private var hornDone = false
    private var boostDone = false
    private var conquestSince: Double?

    // Pacer
    private var pace = 1.0
    private var areaGen = -1
    private var areaStart = 0.0
    private var areaNumber = 0
    private var midBoost = false
    private var heartCheck: (t: Double, hp: Double)?
    private var heartAlive = false
    private var lastAreaSeconds: Double?

    // Scripted twists
    private var tideWasHigh = false
    private var tideRescheduled = false
    private var eruptions = 0
    private var nextEruption: Double?
    private var lastVentTimer = 0.0

    // Effect timestamps (virtual seconds), read by views while capturing
    private var lastPulses: [Int: Int] = [:]
    private var hitAt: [Int: Double] = [:]
    private(set) var bannerAt: Double?
    private var bannerID: Int?
    private(set) var toastAt: Double?
    private var toastID: UUID?
    private(set) var hauntAt: Double = -10
    private var lastFaded = false
    private var tideChangeAt: Double = -10
    private var lastHigh = false
    private var weeklyPunches = 0
    private var weeklyPunchAt: [Int: Double] = [:]
    private(set) var weeklyTierAt: Double = -10
    private var weeklyTier = 1
    private(set) var weeklyFadeAt: Double = -10
    private var weeklyFaded = false
    private(set) var weeklyEndAt: Double?
    private(set) var conquestAt: Double?

    // Log
    private var lastStatus = -1.0
    private var lastPunchCount = 0
    private var lastPunchAt = 0.0
    private var lastWarning: [String: Double] = [:]
    private var framesThisSecond = 0
    private var realSecondStart = Date()
    private var realFPS = 0.0

    private init() {
        let defaults = UserDefaults.standard
        let name = defaults.string(forKey: "scenario")
        requested = name
        let seconds = defaults.double(forKey: "scenarioDuration")
        duration = seconds > 0 ? seconds : 40
        let capture = defaults.double(forKey: "scenarioCapture")
        captureSeconds = capture > 0 ? capture : nil
        let given = defaults.string(forKey: "scenarioSeed").flatMap { UInt64($0.trimmingCharacters(in: .whitespaces)) }
        seed = given ?? UInt64(Date().timeIntervalSince1970 * 1000) % 1_000_000_000
        gameRNG = SplitMix64(seed: directorHash("game:\(seed)"))
        viewRNG = SplitMix64(seed: directorHash("view:\(seed)"))
        liveRNG = SplitMix64(seed: directorHash("live:\(seed)"))

        var rng = SplitMix64(seed: directorHash("director:\(seed)"))
        let picked: Scenario?
        if name == "random" {
            picked = rng.pick(Scenario.allCases)
        } else {
            picked = name.flatMap(Scenario.init(rawValue:))
        }
        scenario = picked
        let base = Self.baseDate(defaults.string(forKey: "scenarioDate"))
        if let picked {
            let rolled = Self.roll(picked, rng: &rng, base: base, duration: duration, defaults: defaults)
            plan = rolled
            gameDate = rolled.date
        } else {
            gameDate = base
            if let name { log("WARNING: unknown scenario '\(name)' (allowed: random, \(Scenario.allCases.map(\.rawValue).joined(separator: ", ")))") }
        }
    }

    /// `-scenarioDate yyyy-MM-dd`, or today; always 12:00 UTC so one seed gives one set-up all day.
    private static func baseDate(_ text: String?) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        if let text {
            let parts = text.split(separator: "-").compactMap { Int($0) }
            if parts.count == 3, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) {
                return date
            }
        }
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        return calendar.date(from: DateComponents(year: today.year, month: today.month, day: today.day, hour: 12)) ?? Date()
    }

    // MARK: - Rolling a clip

    private static func roll(_ scenario: Scenario, rng: inout SplitMix64, base: Date, duration: Double,
                             defaults: UserDefaults) -> DirectorPlan {
        var plan = DirectorPlan(scenario: scenario)
        plan.date = base
        let forcedZone = defaults.string(forKey: "scenarioZone").flatMap(ZoneID.init(rawValue:))
        let forcedArea = defaults.object(forKey: "scenarioArea") != nil ? defaults.integer(forKey: "scenarioArea") : nil
        let forcedStyle = defaults.string(forKey: "scenarioStyle").flatMap(PlayStyle.init(rawValue:))

        func area(_ ranges: [ClosedRange<Int>]) -> Int {
            if let forcedArea { return min(max(forcedArea, 2), Conquest.heartArea - 1) }
            return rng.int(rng.pick(ranges))
        }

        switch scenario {
        case .heartFight:
            plan.zone = forcedZone ?? rng.pick(ZoneID.allCases)
            plan.area = Conquest.heartArea
            plan.heartStart = rng.pick([1.0, 1.0, 0.7, 0.45])
            plan.killAt = rng.double(23...29)
            plan.clearSeconds = rng.double(2.8...3.6)
            plan.hornAt = rng.double(6...11)
            plan.dynamiteAt = rng.double(13...18)
            plan.style = forcedStyle ?? rng.pick([.tapper, .holder, .holder, .tapper])
        case .areaBlitz:
            plan.zone = forcedZone ?? rng.pick([.quarry, .quarry, .caverns, .magma, .ruins, .crypt])
            plan.area = area([15...35, 36...60, 61...90])
            plan.clearSeconds = rng.double(2.6...3.4)
            plan.boost = rng.pick([nil, .goldenPick, .goldenPick, .snowball, .timeBell] as [Consumable?])
            plan.hornAt = plan.area >= Gadget.horn.unlockArea && rng.chance(0.6) ? rng.double(8...20) : nil
            plan.dynamiteAt = rng.double(4...24)
            plan.style = forcedStyle ?? rng.pick([.tapper, .holder, .sweeper])
        case .crystalChain:
            plan.zone = .caverns
            plan.area = area([8...15, 8...15, 31...45])
            plan.clearSeconds = rng.double(3.0...4.0)
            plan.layoutTries = 12
            plan.style = forcedStyle ?? rng.pick([.tapper, .tapper, .holder])
        case .highTide:
            plan.zone = .ruins
            plan.area = area([20...45, 46...80])
            plan.clearSeconds = rng.double(3.8...4.8)
            plan.tideAt = rng.double(3...7)
            plan.tideGap = rng.double(8...11)
            plan.style = forcedStyle ?? rng.pick([.tapper, .holder, .sweeper])
        case .magmaVents:
            plan.zone = .magma
            plan.area = area([30...45, 46...70])
            plan.clearSeconds = rng.double(4.5...5.5)
            plan.ventAt = rng.double(5...8)
            plan.ventGap = rng.double(11...15)
            plan.hornAt = rng.chance(0.6) ? rng.double(10...18) : nil
            plan.style = forcedStyle ?? rng.pick([.focus, .focus, .tapper])
        case .weeklyHeart:
            plan.zone = forcedZone ?? rng.pick(ZoneID.allCases)
            plan.area = rng.int(30...70)
            plan.twist = defaults.string(forKey: "scenarioTwist").flatMap(WeeklyModifier.init(rawValue:))
                ?? rng.pick(WeeklyModifier.allCases)
            plan.tierGoal = rng.pick([70, 110, 150])
            plan.style = forcedStyle ?? .tapper
            // The twist follows the week: the first week from today that has it.
            var date = base
            for _ in 0..<WeeklyModifier.allCases.count where WeeklyHeart.modifier(week: WeeklyHeart.week(of: date)) != plan.twist {
                date = date.addingTimeInterval(WeeklyHeart.weekSeconds)
            }
            plan.date = date
        case .quarryMining, .cavernsMining, .magmaMining, .ruinsMining, .cryptMining:
            plan.zone = scenario.miningZone ?? .quarry
            plan.area = area([6...20, 21...45, 46...70, 71...95])
            plan.clearSeconds = rng.double(3.4...4.6)
            let styles: [PlayStyle] = plan.zone == .magma ? [.focus, .holder, .tapper] : [.tapper, .holder, .sweeper]
            plan.style = forcedStyle ?? rng.pick(styles)
            plan.dynamiteAt = rng.chance(0.4) ? rng.double(6...24) : nil
            if plan.zone == .ruins { plan.tideAt = rng.double(5...14) }
            if plan.zone == .magma { plan.ventAt = rng.double(7...16) }
        }

        rollLoadout(&plan, rng: &rng)
        plan.moves = rollMoves(plan, rng: &rng, until: duration + 20)
        return plan
    }

    /// Upgrades, crew, perks and looks that fit the area. The pacer then sets the punch power itself.
    private static func rollLoadout(_ plan: inout DirectorPlan, rng: inout SplitMix64) {
        let a = plan.area
        var levels: [UpgradeKind: Int] = [:]
        levels[.strength] = min(100, max(5, Int(Double(a) * 0.9) + rng.int(0...12)))
        levels[.speed] = rng.int(14...20)
        levels[.critChance] = a >= 6 ? rng.int(6...15) : 0
        levels[.critDamage] = a >= 9 ? rng.int(6...20) : 0
        levels[.focus] = a >= 7 ? rng.int(3...10) : 0
        levels[.rhythm] = a >= 10 ? rng.int(2...9) : 0
        levels[.hireMiner] = rng.int(3...5)
        levels[.hireDriller] = a >= 8 ? rng.int(1...3) : 0
        levels[.hireBlaster] = a >= 14 ? rng.int(1...2) : 0
        levels[.training] = rng.int(10...40)
        levels[.shiftPace] = rng.int(3...10)
        levels[.feverStamina] = rng.int(2...10)
        levels[.overcharge] = a >= 7 ? rng.int(0...6) : 0
        levels[.deepPockets] = rng.int(3...14)
        levels[.treasureHunter] = a >= 5 ? rng.int(2...10) : 0
        levels[.contracts] = a >= 10 ? rng.int(0...5) : 0
        levels[.lockpick] = a >= 8 ? rng.int(0...5) : 0
        plan.levels = levels
        plan.gadgets = a >= Gadget.dynamite.unlockArea
        plan.toolIndex = plan.zone.tools.last(where: { $0.unlockArea <= a })?.id ?? -1

        var perks: [Perk: Int] = [:]
        perks[.heavyFists] = rng.int(2...12)
        perks[.keenEye] = rng.int(0...6)
        perks[.brutalCrits] = rng.int(0...3)
        perks[.piercer] = rng.int(4...10)
        perks[.prospector] = rng.int(1...4)
        perks[.foreman] = rng.int(2...10)
        if plan.scenario == .heartFight || rng.chance(0.45) { perks[.titanPunch] = 1 }
        if plan.zone == .caverns { perks[.resonantKnuckles] = rng.int(0...5) }
        if plan.zone == .magma { perks[.coldCrew] = rng.int(0...1) }
        plan.perks = perks.filter { $0.value > 0 }
        plan.coins = (Double(rng.int(20...900)) * pow(1.12, Double(min(a, 60)))).rounded()

        let fists = ["fist.pumpkin", "fist.frost", "fist.dragon", "fist.bloom", "fist.splash", "fist.nugget", "fist.golden", "fist.heart"]
        let bursts = ["burst.candy", "burst.snow", "burst.fireworks", "burst.petals", "burst.bubbles", "burst.nuggets", "burst.gold"]
        plan.fist = rng.chance(0.75) ? rng.pick(fists) : nil
        plan.burst = rng.chance(0.55) ? rng.pick(bursts) : nil
        plan.pet = rng.chance(0.75) ? rng.pick(PetDef.all.map(\.id)) : nil
        plan.chests = rng.int(0...4)
    }

    /// A move plan covering `until` seconds: varied stretches, never a long idle (a pause is short and never
    /// follows another pause).
    private static func rollMoves(_ plan: DirectorPlan, rng: inout SplitMix64, until: Double) -> [DirectorMove] {
        var weights: [(DirectorMove.Kind, Double)]
        switch plan.style {
        case .tapper: weights = [(.taps, 5), (.hold, 2), (.sweep, 1), (.pause, 1)]
        case .holder: weights = [(.taps, 2), (.hold, 5), (.sweep, 1.5), (.pause, 1)]
        case .sweeper: weights = [(.taps, 2), (.hold, 1.5), (.sweep, 5), (.pause, 1)]
        case .focus: weights = [(.taps, 2), (.hold, 6), (.pause, 1)]
        }
        if plan.scenario == .heartFight { weights.append((.ring, 2.2)) }
        if plan.scenario == .weeklyHeart { weights = [(.taps, 6), (.pause, 1)] }
        let total = weights.reduce(0) { $0 + $1.1 }
        var moves: [DirectorMove] = []
        var t = 0.0
        while t < until {
            var kind = DirectorMove.Kind.taps
            var roll = rng.double(0...total)
            for (k, w) in weights {
                if roll < w { kind = k; break }
                roll -= w
            }
            if kind == .pause && (moves.isEmpty || moves.last?.kind == .pause) { kind = weights[0].0 }
            var move = DirectorMove(kind: kind, start: t, duration: 1)
            switch kind {
            case .taps:
                move.duration = rng.double(1.5...3.5)
                move.rate = rng.double(7.5...11)
            case .hold: move.duration = rng.double(2...4.5)
            case .sweep:
                move.duration = rng.double(2...4)
                move.rows = rng.chance(0.6)
                move.cellSeconds = rng.double(0.3...0.6)
            case .ring:
                move.duration = rng.double(0.8...1.6)
                move.rate = rng.double(8...11)
            case .pause: move.duration = rng.double(0.2...0.45)
            }
            moves.append(move)
            t += move.duration
        }
        return moves
    }

    // MARK: - The starting profile

    /// The throwaway profile `GameModel` loads instead of the save (nil when no scenario runs).
    func startingSave() -> SaveData? {
        guard let plan else { return nil }
        let all = ZoneID.allCases
        let upTo = all.firstIndex(of: plan.zone) ?? 0
        let unlocked = Array(all.prefix(upTo + 1))
        var runs: [String: ZoneRun] = [:]
        var records: [String: ZoneRecord] = [:]
        for zone in unlocked {
            var record = ZoneRecord()
            record.seenIntro = true
            if zone == plan.zone {
                record.bestArea = plan.area
                record.bestCleared = plan.area - 1
            } else {
                // Earlier zones were played far enough to open the next one.
                record.bestArea = 60
                record.bestCleared = 59
            }
            records[zone.rawValue] = record
        }
        var run = ZoneRun()
        run.area = plan.area
        run.maxCleared = plan.area - 1
        run.coins = plan.coins
        run.lifetimeCoins = plan.coins * 6
        run.toolIndex = plan.toolIndex
        for (kind, level) in plan.levels { run.setLevel(kind, level) }
        if plan.gadgets {
            run.levels[Gadget.dynamite.levelKey] = 1
            if plan.area >= Gadget.horn.unlockArea { run.levels[Gadget.horn.levelKey] = 1 }
        }
        runs[plan.zone.rawValue] = run

        var settings = Settings()
        settings.vibration = .off
        settings.soundEffects = false
        settings.music = false
        settings.showTips = false
        settings.autoPrestige = false
        settings.iCloudSync = false
        settings.tapToAutoPunch = false
        settings.damageNumbers = .all

        var save = SaveData(runs: runs, records: records,
                            seeds: [plan.zone.rawValue: directorHash("terrain:\(seed)") | 1],
                            activeZone: plan.zone, unlockedZones: unlocked, holdUnlocked: true, settings: settings,
                            perks: Dictionary(uniqueKeysWithValues: plan.perks.map { ($0.key.rawValue, $0.value) }),
                            perkCoins: 40 + Int(seed % 1_900), lastActive: nil)
        save.seenTips = Tip.allCases.map(\.rawValue)
        save.daily.lastClaimDay = Daily.dayKey(Date())
        save.daily.streak = 3
        if plan.chests > 0 { save.chests = [ChestTier.wooden.rawValue: plan.chests] }
        if let boost = plan.boost { save.consumables = [boost.rawValue: 1] }
        if let pet = plan.pet {
            save.pets = [pet: 1]
            save.activePet = pet
        }
        let looks = [plan.fist, plan.burst].compactMap { $0 }
        save.cosmetics = looks
        if let fist = plan.fist { save.equippedCosmetics[CosmeticKind.fist.rawValue] = fist }
        if let burst = plan.burst { save.equippedCosmetics[CosmeticKind.burst.rawValue] = burst }
        return save
    }

    // MARK: - JSON plan (CI manifest)

    private func planJSON(_ plan: DirectorPlan) -> String {
        var params: [String: Any] = [
            "zone": plan.zone.rawValue,
            "area": plan.area,
            "style": plan.style.rawValue,
            "date": Self.dayText(plan.date),
            "event": plan.event,
            "levels": Dictionary(uniqueKeysWithValues: plan.levels.filter { $0.value > 0 }.map { ($0.key.rawValue, $0.value) }),
            "tool": plan.zone.tools.first { $0.id == plan.toolIndex }?.name ?? "Bare Fists",
            "perks": Dictionary(uniqueKeysWithValues: plan.perks.map { ($0.key.rawValue, $0.value) }),
            "miners": [
                "diggers": plan.levels[.hireMiner] ?? 0,
                "drillers": plan.levels[.hireDriller] ?? 0,
                "blasters": plan.levels[.hireBlaster] ?? 0,
            ],
            "fistSkin": plan.fist ?? "none",
            "breakEffect": plan.burst ?? "none",
            "pet": plan.pet ?? "none",
        ]
        if plan.scenario != .weeklyHeart { params["clearSeconds"] = round2(plan.clearSeconds) }
        if let boost = plan.boost { params["boost"] = boost.rawValue }
        if let at = plan.dynamiteAt { params["dynamiteAt"] = round1(at) }
        if let at = plan.hornAt { params["hornAt"] = round1(at) }
        switch plan.scenario {
        case .heartFight:
            params["heart"] = plan.zone.heartName
            params["heartStartHP"] = plan.heartStart
            params["killAt"] = round1(plan.killAt)
        case .highTide, .ruinsMining:
            if let at = plan.tideAt { params["tideAt"] = round1(at) }
            if plan.scenario == .highTide { params["tideGap"] = round1(plan.tideGap) }
        case .magmaVents, .magmaMining:
            if let at = plan.ventAt { params["ventAt"] = round1(at) }
            if plan.scenario == .magmaVents { params["ventGap"] = round1(plan.ventGap) }
        case .crystalChain:
            params["layoutTries"] = plan.layoutTries
        case .weeklyHeart:
            params["twist"] = plan.twist.rawValue
            params["tierGoal"] = plan.tierGoal
        default: break
        }
        let movement: [String: Any] = [
            "style": plan.style.rawValue,
            "pattern": plan.moves.prefix(24).map { "\($0.kind.rawValue):\(String(format: "%.1f", $0.duration))" }
                .joined(separator: ","),
            "avgTapRate": round1(averageTapRate(plan)),
        ]
        let object: [String: Any] = [
            "seed": String(seed),
            "requested": requested ?? "",
            "scenario": plan.scenario.rawValue,
            "key": plan.key,
            "params": params,
            "movement": movement,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private func round1(_ x: Double) -> Double { (x * 10).rounded() / 10 }
    private func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }

    private static func dayText(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func averageTapRate(_ plan: DirectorPlan) -> Double {
        let taps = plan.moves.filter { $0.kind == .taps || $0.kind == .ring }
        guard !taps.isEmpty else { return 0 }
        return taps.map(\.rate).reduce(0, +) / Double(taps.count)
    }

    // MARK: - Rolls for the game and views

    /// The game's next roll in 0..<1 during a directed launch (see `GameModel.diceRoll`).
    func nextRoll() -> Double? {
        guard isActive else { return nil }
        return gameRNG.unit()
    }

    /// A seeded value for views (Weekly Heart hit positions).
    func viewRandom(_ range: ClosedRange<Double>) -> Double { viewRNG.double(range) }

    // MARK: - Start

    /// Called once from `DirectorRoot` when the app appears.
    func begin(game: GameModel) {
        guard let scenario, let plan, !began else { return }
        began = true
        self.game = game
        log("begin scenario=\(scenario.rawValue) seed=\(seed) duration=\(duration)s capture=\(captureSeconds.map { "\($0)s" } ?? "off")")
        log("PLAN \(planJSON(plan))")
        lastPunchCount = game.punchCount

        if scenario == .weeklyHeart {
            paceWeekly(plan)
            game.startWeeklyFight(now: plan.date)
            if game.weeklyFight == nil { log("WARNING: the Weekly Heart fight did not start") }
        } else {
            setUpMine(plan)
        }

        #if canImport(UIKit)
        if let captureSeconds {
            virtualNow = 0
            clock.date = Date(timeIntervalSinceReferenceDate: Self.captureOrigin)
            let recorder = DirectorRecorder(seconds: captureSeconds, fps: Self.captureFPS)
            self.recorder = recorder
            recorder.start()
            return
        }
        #endif
        runRealtime()
    }

    private func setUpMine(_ plan: DirectorPlan) {
        guard let game else { return }
        if plan.scenario == .heartFight, let heart = game.heartBlock {
            game.directorSetHP(Conquest.heartIndex, heart.maxHP * plan.heartStart)
        }
        if let tideAt = plan.tideAt { game.directorSetTideTimer(Tide.interval - tideAt) }
        if let ventAt = plan.ventAt { nextEruption = ventAt }
        pacer()
    }

    /// Without capture: follow real time, ~60 updates a second (the game runs its own loop).
    private func runRealtime() {
        Task { @MainActor [weak self] in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self else { return }
                let now = ContinuousClock.now
                let elapsed = now - last
                last = now
                let dt = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                self.virtualNow += dt
                self.step(min(dt, 0.1))
                self.observe()
            }
        }
    }

    // MARK: - Offline capture (driven by DirectorRecorder)

    /// Called by the probe in `DirectorRoot` each time the screen draws a clock date.
    func noteRender(_ date: Date) { lastRender = date }

    /// True once the screen shows virtual frame `index`.
    func captureFrameOnScreen(_ index: Int) -> Bool {
        guard lastRender == clock.date else { return false }
        if captureRunFrom == nil, began {
            captureRunFrom = index
            log("CAPTURE gameplay on screen from frame \(index)")
        }
        return true
    }

    /// Moves everything to virtual frame `index`: exactly 1/60 s of game time per frame.
    func captureAdvance(to index: Int) {
        let dt = 1.0 / Double(Self.captureFPS)
        step(dt)
        game?.advance(by: dt)
        virtualNow = Double(index) / Double(Self.captureFPS)
        observe()
        clock.date = Date(timeIntervalSinceReferenceDate: Self.captureOrigin + virtualNow)
    }

    // MARK: - Effects on the virtual clock (read by views while capturing)

    /// Virtual seconds of a clock date.
    func seconds(_ date: Date) -> Double { date.timeIntervalSinceReferenceDate - Self.captureOrigin }

    /// The game's own clock (floaters are timed with it).
    var gameClock: Double { game?.clock ?? 0 }

    /// Scale of a block that was just hit: a quick squash, then a bouncy return.
    func squash(_ index: Int, at date: Date, depth: Double) -> CGFloat {
        guard let hit = hitAt[index] else { return 1 }
        return CGFloat(Self.squashCurve(seconds(date) - hit, depth: depth))
    }

    func weeklySquash(at date: Date) -> CGFloat {
        guard let hit = weeklyPunchAt[weeklyPunches] else { return 1 }
        return CGFloat(Self.squashCurve(seconds(date) - hit, depth: 0.07))
    }

    /// When the Weekly Heart hit with this punch number landed.
    func weeklyPunchTime(_ punch: Int) -> Double? { weeklyPunchAt[punch] }

    static func squashCurve(_ age: Double, depth: Double) -> Double {
        if age < 0 || age > 0.9 { return 1 }
        if age < 0.04 { return 1 - depth * age / 0.04 }
        let tau = age - 0.04
        return 1 - depth * exp(-12 * tau) * cos(2 * .pi * tau / 0.22)
    }

    /// Sunken Ruins: the water rises over 1.2 s when the tide comes in, and falls when it goes out.
    func tideLevel(_ target: Double, high: Bool, at date: Date) -> Double {
        let from = high ? 0.12 : 1.0
        return from + (target - from) * Self.ease(seconds(date) - tideChangeAt, 1.2)
    }

    /// Haunted Crypt: a block's opacity; ghosts fade over 0.35 s when the haunt turns.
    func ghostOpacity(_ index: Int, faded: Bool, at date: Date) -> Double {
        guard game?.isGhostly(index) == true else { return 1 }
        let p = Self.ease(seconds(date) - hauntAt, 0.35)
        return faded ? 1 - 0.75 * p : 0.25 + 0.75 * p
    }

    /// 0 → 1 over `duration` seconds after `start`, eased.
    static func ease(_ age: Double, _ duration: Double) -> Double {
        let p = min(1, max(0, age / duration))
        return p * p * (3 - 2 * p)
    }

    /// A spring-like pop from `from` to 1 with a small overshoot, settled after about 0.5 s.
    static func pop(_ age: Double, from: Double) -> Double {
        guard age >= 0 else { return from }
        return 1 - (1 - from) * exp(-9 * age) * cos(2 * .pi * age / 0.45)
    }

    /// Records the moments effects are timed from: hits, banners, toasts, the haunt, Weekly Heart punches.
    private func observe() {
        guard let game else { return }
        let now = virtualNow
        let pulses = game.hitPulses
        for (index, count) in pulses where count > (lastPulses[index] ?? 0) { hitAt[index] = now }
        lastPulses = pulses
        if let banner = game.banner, banner.id != bannerID { bannerID = banner.id; bannerAt = now }
        if let toast = game.toast, toast.id != toastID { toastID = toast.id; toastAt = now }
        if game.ghostsFaded != lastFaded { lastFaded = game.ghostsFaded; hauntAt = now }
        if game.highTide != lastHigh { lastHigh = game.highTide; tideChangeAt = now }
        if game.conquest != nil { if conquestAt == nil { conquestAt = now } } else { conquestAt = nil }
        if let fight = game.weeklyFight {
            if fight.punches != weeklyPunches {
                weeklyPunches = fight.punches
                weeklyPunchAt[fight.punches] = now
                weeklyPunchAt = weeklyPunchAt.filter { $0.key > fight.punches - 12 }
            }
            if fight.tier != weeklyTier { weeklyTier = fight.tier; weeklyTierAt = now }
            if fight.faded != weeklyFaded { weeklyFaded = fight.faded; weeklyFadeAt = now }
        } else if game.weeklyResult != nil, weeklyEndAt == nil {
            weeklyEndAt = now
        }
    }

    // MARK: - Per frame

    private func step(_ dt: Double) {
        guard let game, let plan, !finished else { return }
        framesThisSecond += 1
        if t >= duration {
            finished = true
            release()
            log(String(format: "t=%.1fs scenario finished, finger lifted (the app idles now)", t))
            return
        }
        if plan.scenario == .weeklyHeart {
            weeklyPilot(plan, game: game)
        } else if game.conquest != nil {
            // The crown card: read it for a moment, then "Keep digging" (the card's button just closes it).
            release()
            if conquestSince == nil {
                conquestSince = t
                log(String(format: "t=%.1fs %@ destroyed, crown card on screen", t, plan.zone.heartName))
            }
            if let since = conquestSince, t - since >= 2.6 {
                game.conquest = nil
                conquestSince = nil
                log(String(format: "t=%.1fs Keep digging", t))
            }
        } else {
            script(plan, game: game)
            pacer()
            minePilot(plan, game: game)
        }
        logStatus(plan, game: game)
        t += dt
    }

    // MARK: Scripted beats

    private func script(_ plan: DirectorPlan, game: GameModel) {
        // A boost from the stash, as if tapped there.
        if let boost = plan.boost, !boostDone, t >= 1.0 {
            boostDone = true
            game.use(boost)
            log(String(format: "t=%.1fs used %@", t, boost.rawValue))
        }
        // High tide, then a second one sooner than the game would bring it.
        if plan.tideAt != nil, game.zone == .ruins {
            if game.highTide { tideWasHigh = true }
            if tideWasHigh, !game.highTide, !tideRescheduled, plan.scenario == .highTide {
                tideRescheduled = true
                game.directorSetTideTimer(Tide.interval - plan.tideGap)
                log(String(format: "t=%.1fs tide out, next high tide in %.1fs", t, plan.tideGap))
            }
        }
        // Vent eruptions, timed to land on a fresh, full area so they hit something.
        if let at = nextEruption, game.zone == .magma {
            let ventsUp = game.run.blocks.contains { $0.material == .vent && !$0.isBroken }
            let timer = game.directorVentTimer
            if timer + 0.001 < lastVentTimer, lastVentTimer > Magma.ventInterval - 1 {
                eruptions += 1
                log(String(format: "t=%.1fs vents erupted (%d)", t, eruptions))
                nextEruption = plan.scenario == .magmaVents && eruptions < 2 ? t + plan.ventGap : nil
            } else if ventsUp {
                if t >= at - 0.05 {
                    game.directorSetVentTimer(Magma.ventInterval - 1.0 / 60)
                } else {
                    game.directorSetVentTimer(max(0, Magma.ventInterval - (at - t)))
                }
            }
            lastVentTimer = game.directorVentTimer
        }
    }

    // MARK: Pacer

    /// Sets the punch power so the current area (or the Heart) falls in about the planned time.
    private func pacer() {
        guard let game, let plan else { return }
        let gen = game.directorAreaGeneration
        if gen != areaGen {
            if areaGen >= 0 {
                let took = t - areaStart
                lastAreaSeconds = took
                if !(plan.scenario == .heartFight && areaNumber == Conquest.heartArea) {
                    let ratio = took / plan.clearSeconds
                    pace *= min(1.7, max(0.6, pow(ratio, 0.7)))
                    if ratio > 3 { warn("slowArea", String(format: "area %d took %.1fs (target %.1fs)", areaNumber, took, plan.clearSeconds)) }
                }
                log(String(format: "t=%.1fs area %d cleared in %.1fs (target %.1fs), pace %.2f", t, areaNumber, took,
                           plan.clearSeconds, pace))
            }
            areaGen = gen
            areaStart = t
            areaNumber = game.run.area
            midBoost = false
            heartCheck = nil
            if plan.scenario == .crystalChain { pickCrystalLayout(plan, game: game) }
            applyPace(plan, game: game)
            return
        }
        let heartUp = game.heartBlock.map { !$0.isBroken } == true
        if heartUp {
            heartAlive = true
            paceHeart(plan, game: game)
        } else if heartAlive {
            // The Heart fell: clear what is left of its area quickly and move on.
            heartAlive = false
            applyPace(plan, game: game)
        } else if !midBoost, t - areaStart > 2 * plan.clearSeconds {
            midBoost = true
            pace *= 1.6
            applyPace(plan, game: game)
            log(String(format: "t=%.1fs area %d is slow (%.1fs), pace %.2f", t, areaNumber, t - areaStart, pace))
        }
    }

    /// Player punches per second of the plan's finger, and what one unit of base punch is worth per second.
    private func damagePerBase(_ plan: DirectorPlan, game: GameModel, heartShare: Double = 1) -> Double {
        let taps = averageTapRate(plan)
        let rate = 0.8 * (plan.style == .tapper && taps > 0 ? taps : max(game.holdRate, taps))
        let crit = 1 + game.critChance * (game.critMultiplier - 1)
        let tool = game.tool
        let spread = heartShare < 1 ? 1 : 1 + tool.splash * 2 + tool.pierce * 0.5
        let titan = game.level(.titanPunch) > 0 ? 1.45 : 1
        let base = max(1, game.directorBasePunch)
        let crew = heartShare < 1 ? 0.2 : 1
        return rate * crit * spread * titan * heartShare + crew * game.directorMinerDPS / base
    }

    /// Base punch as a function of Strength level and Starforged Fists: B = unit · S(strength) · (1 + 0.03 · stars).
    private func setBasePunch(_ wanted: Double, game: GameModel) {
        let strength = game.run.level(.strength)
        let stars = game.starLevel(.fists)
        let now = max(1e-9, game.directorBasePunch)
        let unit = now / (Config.strength(level: strength) * game.starMultiplier(.fists))
        var level = strength
        if unit * Config.strength(level: level) > wanted {
            while level > 1 && unit * Config.strength(level: level) > wanted { level -= 1 }
            game.directorSetLevel(.strength, level)
        }
        let ratio = wanted / (unit * Config.strength(level: level))
        let needed = max(0, ((ratio - 1) / StarPerk.fists.perLevel).rounded(.up))
        if needed > 1e15 { warn("power", "punch power capped (needed \(needed) Starforged Fists levels)") }
        let starLevel = Int(min(needed, 1e15))
        if starLevel != stars { game.directorSetStar(.fists, level: starLevel) }
    }

    private func applyPace(_ plan: DirectorPlan, game: GameModel) {
        if game.heartBlock.map({ !$0.isBroken }) == true {
            paceHeart(plan, game: game, force: true)
            return
        }
        let open = game.run.blocks.filter { !$0.isBroken && $0.material != .heartPart }
        let hp = open.reduce(0.0) { $0 + ($1.isTreasure ? 0.6 * $1.hp : $1.hp) }
        guard hp > 0 else { return }
        let dps = hp / plan.clearSeconds * pace
        setBasePunch(dps / damagePerBase(plan, game: game), game: game)
    }

    /// The Heart: lands the killing punch near `killAt`, re-checked every few seconds from the HP really lost.
    private func paceHeart(_ plan: DirectorPlan, game: GameModel, force: Bool = false) {
        guard let heart = game.heartBlock, !heart.isBroken else { return }
        let left = max(1.5, plan.killAt - t)
        let heartShare = 0.75
        if force || heartCheck == nil {
            let rate = heart.hp / left
            setBasePunch(rate / damagePerBase(plan, game: game, heartShare: heartShare), game: game)
            heartCheck = (t, heart.hp)
            return
        }
        guard let check = heartCheck, t - check.t >= 4 else { return }
        let lost = check.hp - heart.hp
        let measured = lost / (t - check.t)
        let wanted = heart.hp / left
        heartCheck = (t, heart.hp)
        guard measured > 0 else {
            setBasePunch(game.directorBasePunch * 2, game: game)
            return
        }
        let factor = min(4, max(0.3, wanted / measured))
        setBasePunch(game.directorBasePunch * factor, game: game)
        if t > plan.killAt + 4 { warn("heart", String(format: "the Heart is still at %.0f%% after %.0fs", heart.hpFraction * 100, t)) }
    }

    /// Weekly Heart: punch power for about `tierGoal` tiers in the 30 s fight.
    private func paceWeekly(_ plan: DirectorPlan) {
        guard let game else { return }
        let growth = WeeklyHeart.tierGrowth
        let total = WeeklyHeart.baseHP * pow(growth, Double(plan.tierGoal)) / (growth - 1)
        let taps = averageTapRate(plan) * WeeklyHeart.fightSeconds * 0.85
        let crit = 1 + game.weeklyCritChance * (game.weeklyCritMultiplier - 1)
        let twist: Double
        switch plan.twist {
        case .armoured: twist = game.weeklyArmourFactor(.armoured)
        case .phasing: twist = 0.7
        case .critical: twist = 1.25
        case .regenerating: twist = 0.95
        }
        let crew = WeeklyHeart.crewCapPunchesPerSecond * WeeklyHeart.fightSeconds * 0.8
        setBasePunch(total / ((taps * crit + crew) * twist), game: game)
        log(String(format: "weekly pacing: punch %@ for about %d tiers", NumberText.format(game.weeklyPunch), plan.tierGoal))
    }

    // MARK: Crystal layouts

    /// Of a few layouts the game's generator makes for this area, keep the one with the most touching
    /// crystals of the same kind, so chains go off.
    private func pickCrystalLayout(_ plan: DirectorPlan, game: GameModel) {
        guard game.zone == .caverns, game.heartBlock == nil else { return }
        var best = game.run.blocks
        var bestScore = crystalScore(best)
        for k in 1..<max(2, plan.layoutTries) {
            let candidate = game.newBlocks(area: game.run.area, salt: directorHash("layout:\(seed):\(game.run.area):\(k)"))
            let score = crystalScore(candidate)
            if score > bestScore { best = candidate; bestScore = score }
        }
        game.directorSetBlocks(best)
    }

    private func crystalScore(_ blocks: [Block]) -> Int {
        var score = 0
        for b in blocks where b.material.isCrystal && !b.isBroken {
            score += neighbors(b.id).filter { blocks[$0].material == b.material && !blocks[$0].isBroken }.count
        }
        return score
    }

    // MARK: Autopilot (mine)

    private func currentMove(_ plan: DirectorPlan) -> DirectorMove {
        while moveIndex + 1 < plan.moves.count && plan.moves[moveIndex + 1].start <= t { moveIndex += 1 }
        return plan.moves.isEmpty ? DirectorMove(kind: .taps, start: 0, duration: 1) : plan.moves[moveIndex]
    }

    private func minePilot(_ plan: DirectorPlan, game: GameModel) {
        // Dynamite: tap the gadget, then a block.
        if let armed = armedAt {
            if game.armedGadget != .dynamite {
                armedAt = nil
            } else if t - armed >= 0.3 {
                let target = blastTarget(game)
                game.beginPress(at: target)
                game.endPress()
                armedAt = nil
                log(String(format: "t=%.1fs dynamite on block %d", t, target))
            }
            return
        }
        if let at = plan.dynamiteAt, !dynamiteDone, t >= at, game.canUseGadget(.dynamite) {
            dynamiteDone = true
            release()
            game.useGadget(.dynamite)
            if game.armedGadget == .dynamite { armedAt = t }
            return
        }
        if let at = plan.hornAt, !hornDone, t >= at, game.canUseGadget(.horn), !game.feverActive {
            hornDone = true
            game.useGadget(.horn)
            log(String(format: "t=%.1fs Fever Horn", t))
        }

        let move = currentMove(plan)
        switch move.kind {
        case .pause:
            release()
        case .taps, .ring:
            release()
            guard t >= nextTapAt else { return }
            if let target = chooseTarget(plan, game: game, current: tapTarget, ring: move.kind == .ring) {
                game.beginPress(at: target)
                game.endPress()
                tapTarget = target
                lastCell = target
            }
            nextTapAt = t + liveRNG.double(0.8...1.2) / move.rate
        case .hold:
            let target = chooseTarget(plan, game: game, current: holding, ring: false)
            hold(target, game: game)
        case .sweep:
            sweep(move, plan: plan, game: game)
        }
    }

    private func hold(_ target: Int?, game: GameModel) {
        guard let target else { release(); return }
        if holding == nil {
            game.beginPress(at: target)
        } else if holding != target {
            game.movePress(to: target)
        }
        holding = target
        lastCell = target
    }

    /// A held finger sliding along rows (snake) or columns, a cell at a time.
    private func sweep(_ move: DirectorMove, plan: DirectorPlan, game: GameModel) {
        if sweepMove != moveIndex {
            sweepMove = moveIndex
            sweepPath = Self.snake(rows: move.rows, reverse: liveRNG.chance(0.5))
            sweepPos = sweepPath.firstIndex(of: lastCell) ?? 0
            sweepNextAt = t
        }
        let open = openCells(game, ring: false)
        guard !open.isEmpty else { release(); return }
        let current = sweepPath[sweepPos % sweepPath.count]
        if t >= sweepNextAt || !open.contains(redirect(current, game)) {
            for step in 1...sweepPath.count {
                let cell = sweepPath[(sweepPos + step) % sweepPath.count]
                if open.contains(redirect(cell, game)) { sweepPos = (sweepPos + step) % sweepPath.count; break }
            }
            sweepNextAt = t + move.cellSeconds
        }
        hold(sweepPath[sweepPos % sweepPath.count], game: game)
    }

    private static func snake(rows: Bool, reverse: Bool) -> [Int] {
        var path: [Int] = []
        if rows {
            for r in 0..<Config.rows {
                let cols = Array(0..<Config.columns)
                path += ((r % 2 == 0) != reverse ? cols : cols.reversed()).map { r * Config.columns + $0 }
            }
        } else {
            for c in 0..<Config.columns {
                let rows = Array(0..<Config.rows)
                path += ((c % 2 == 0) != reverse ? rows : rows.reversed()).map { $0 * Config.columns + c }
            }
        }
        return path
    }

    private func release() {
        guard holding != nil, let game else { holding = nil; return }
        game.endPress()
        holding = nil
    }

    private func neighbors(_ index: Int) -> [Int] {
        let c = index % Config.columns, r = index / Config.columns
        var result: [Int] = []
        if c > 0 { result.append(index - 1) }
        if c < Config.columns - 1 { result.append(index + 1) }
        if r > 0 { result.append(index - Config.columns) }
        if r < Config.rows - 1 { result.append(index + Config.columns) }
        return result
    }

    /// A press on the Heart's outer cells lands on the Heart itself.
    private func redirect(_ index: Int, _ game: GameModel) -> Int {
        guard game.run.blocks.indices.contains(index), game.run.blocks[index].material == .heartPart else { return index }
        return Conquest.heartIndex
    }

    /// Blocks a punch can land on now (faded ghosts can't be hit).
    private func openCells(_ game: GameModel, ring: Bool) -> Set<Int> {
        var cells = Set<Int>()
        for b in game.run.blocks where !b.isBroken && b.material != .heartPart {
            if game.ghostsFaded && game.isGhostly(b.id) { continue }
            if ring && b.material == .heart { continue }
            cells.insert(b.id)
        }
        return cells
    }

    /// Stays on a block until it breaks, then picks the next one like a player would.
    private func chooseTarget(_ plan: DirectorPlan, game: GameModel, current: Int?, ring: Bool) -> Int? {
        let open = openCells(game, ring: ring)
        if open.isEmpty { return ring ? chooseTarget(plan, game: game, current: current, ring: false) : nil }
        let blocks = game.run.blocks
        // The Heart is the point of the clip: back to it unless this is a short stretch on the ring.
        if !ring, open.contains(Conquest.heartIndex), blocks[Conquest.heartIndex].material == .heart {
            return Conquest.heartIndex
        }
        if let current, open.contains(current), !(ring && blocks[current].material == .heart) { return current }

        var candidates = Array(open)
        // Treasure first: it glows, pays ×10 and collapses if left.
        let treasure = candidates.filter { blocks[$0].isTreasure }
        if !treasure.isEmpty, liveRNG.chance(0.8) { return nearest(treasure) }
        // High tide: runestones send a pulse through their row.
        if game.highTide {
            let runes = candidates.filter { blocks[$0].material == .runestone }
            if !runes.isEmpty { return nearest(runes) }
        }
        // Crystals: the one with the biggest cluster of its own kind sets off the longest chain.
        if game.zone == .caverns {
            let crystals = candidates.filter { blocks[$0].material.isCrystal }
            if let best = crystals.max(by: { clusterSize($0, blocks) < clusterSize($1, blocks) }), clusterSize(best, blocks) > 1 {
                return best
            }
        }
        // Magma: leave the vents for the eruption.
        if game.zone == .magma, nextEruption != nil {
            let calm = candidates.filter { blocks[$0].material != .vent }
            if !calm.isEmpty { candidates = calm }
        }
        if liveRNG.chance(0.25) {
            return candidates.min { (blocks[$0].hp, $0) < (blocks[$1].hp, $1) }
        }
        return nearest(candidates)
    }

    private func nearest(_ cells: [Int]) -> Int? {
        func distance(_ i: Int) -> Int {
            abs(i % Config.columns - lastCell % Config.columns) + abs(i / Config.columns - lastCell / Config.columns)
        }
        let best = cells.map(distance).min() ?? 0
        let ties = cells.filter { distance($0) == best }.sorted()
        return ties.isEmpty ? nil : ties[liveRNG.int(0...(ties.count - 1))]
    }

    private func clusterSize(_ start: Int, _ blocks: [Block]) -> Int {
        let material = blocks[start].material
        var seen: Set<Int> = [start]
        var queue = [start]
        while let i = queue.popLast() {
            for n in neighbors(i) where !seen.contains(n) && !blocks[n].isBroken && blocks[n].material == material {
                seen.insert(n)
                queue.append(n)
            }
        }
        return seen.count
    }

    /// Dynamite goes where its 3×3 blast does the most: the Heart, or the toughest cluster.
    private func blastTarget(_ game: GameModel) -> Int {
        if let heart = game.heartBlock, !heart.isBroken { return Conquest.heartIndex }
        let blocks = game.run.blocks
        func cluster(_ i: Int) -> Double {
            let c = i % Config.columns, r = i / Config.columns
            var total = 0.0
            for dr in -1...1 {
                for dc in -1...1 {
                    let nr = r + dr, nc = c + dc
                    guard nr >= 0, nr < Config.rows, nc >= 0, nc < Config.columns else { continue }
                    let b = blocks[nr * Config.columns + nc]
                    if !b.isBroken { total += b.hp }
                }
            }
            return total
        }
        return openCells(game, ring: false).max { (cluster($0), $0) < (cluster($1), $1) } ?? 12
    }

    // MARK: Autopilot (Weekly Heart)

    private func weeklyPilot(_ plan: DirectorPlan, game: GameModel) {
        guard let fight = game.weeklyFight, !fight.isOver else { return }
        let move = currentMove(plan)
        guard move.kind != .pause, t >= nextTapAt else { return }
        // The fight's drag gesture punches once per touch.
        game.punchWeekly()
        nextTapAt = t + liveRNG.double(0.8...1.2) / move.rate
    }

    // MARK: - Log

    private func logStatus(_ plan: DirectorPlan, game: GameModel) {
        let now = Date()
        if now.timeIntervalSince(realSecondStart) >= 1 {
            realFPS = Double(framesThisSecond) / now.timeIntervalSince(realSecondStart)
            framesThisSecond = 0
            realSecondStart = now
        }
        if game.punchCount != lastPunchCount || game.weeklyFight != nil {
            lastPunchCount = game.punchCount
            lastPunchAt = t
        }
        guard t - lastStatus >= 1 else { return }
        lastStatus = t
        let move = currentMove(plan)
        var line = String(format: "status t=%.1fs fps=%.0f realFps=%.1f", t, isCapturing ? Double(Self.captureFPS) : realFPS, realFPS)
        if let fight = game.weeklyFight {
            line += String(format: " weekly twist=%@ tier=%d hp=%.0f%% time=%.1fs punches=%d punch=%@", fight.modifier.rawValue,
                           fight.tier, (1 - fight.progress) * 100, fight.timeLeft, fight.punches, NumberText.format(game.weeklyPunch))
        } else if let result = game.weeklyResult {
            line += " weekly result score=\(WeeklyHeart.scoreText(result.score))"
        } else {
            line += String(format: " zone=%@ area=%d left=%d areaT=%.1f/%.1fs pace=%.2f stars=%d punch=%@ coins=%@ fever=%@",
                           game.zone.rawValue, game.run.area, game.blocksLeft, t - areaStart, plan.clearSeconds, pace,
                           game.starLevel(.fists), NumberText.format(game.punchDamage), NumberText.format(game.run.coins),
                           game.feverActive ? String(format: "on(%.0fs)", game.feverRemaining) : "\(game.feverCharge)/\(Config.feverPunches)")
            let miners: Int = game.minerCount
            line += " miners=\(miners) punches=\(game.punchCount)"
            if let heart = game.heartBlock { line += String(format: " heart=%.1f%%", heart.hpFraction * 100) }
            if game.zone == .ruins { line += String(format: " tide=%@", game.highTide ? String(format: "high(%.0fs)", game.tideRemaining) : String(format: "%.0f%%", game.tideCharge * 100)) }
            if game.zone == .magma { line += String(format: " vent=%.0f%%", game.ventCharge * 100) }
            if game.zone == .crypt { line += " ghosts=\(game.ghostsFaded ? "faded" : "solid")" }
        }
        line += " move=\(move.kind.rawValue) pressing=\(holding.map(String.init) ?? "-")"
        log(line)

        if game.isPaused { warn("paused", "the game is paused") }
        if game.mineCovered { warn("covered", "a menu or sheet covers the mine") }
        if game.offlineReport != nil || game.zoneIntro != nil { warn("popup", "a pop-up is on screen") }
        if plan.scenario != .weeklyHeart, game.conquest == nil, t > 2, t - lastPunchAt > 1.5 {
            warn("idle", String(format: "no punch for %.1fs", t - lastPunchAt))
        }
        if plan.scenario == .weeklyHeart, game.weeklyFight == nil, t < WeeklyHeart.fightSeconds - 1 {
            warn("weekly", "the Weekly Heart fight is not running")
        }
    }

    /// At most one warning of a kind every 5 s.
    private func warn(_ kind: String, _ text: String) {
        if let last = lastWarning[kind], t - last < 5 { return }
        lastWarning[kind] = t
        log("WARNING: t=\(String(format: "%.1f", t))s \(text)")
    }

    /// Unbuffered stderr, so lines reach `simctl launch --stderr` at once.
    func log(_ line: String) {
        FileHandle.standardError.write(Data("[Director] \(line)\n".utf8))
    }
}

// MARK: - Seeded helpers

/// Stable 64-bit FNV-1a hash for seeding from a string (Swift's `hashValue` is salted per launch).
func directorHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100_0000_01B3
    }
    return hash
}

extension SplitMix64 {
    /// Uniform in 0..<1 (53 bits).
    mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992.0 }
    mutating func double(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit()
    }
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        min(range.upperBound, range.lowerBound + Int(unit() * Double(range.count)))
    }
    mutating func chance(_ probability: Double) -> Bool { unit() < probability }
    mutating func pick<T>(_ items: [T]) -> T { items[int(0...(items.count - 1))] }
}
#endif
