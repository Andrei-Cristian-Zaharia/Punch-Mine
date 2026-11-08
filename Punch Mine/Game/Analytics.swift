import Foundation

/// A value attached to an analytics event.
enum AnalyticsValue: Codable, Equatable {
    case int(Int), double(Double), string(String), bool(Bool)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else { self = .string(try c.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode((v * 100).rounded() / 100)
        case .string(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        }
    }
}

struct AnalyticsEvent: Codable, Equatable {
    let name: String
    let time: Date
    let session: Int
    /// Total active play time when the event happened, across all sessions.
    let playSeconds: Double
    let params: [String: AnalyticsValue]
}

/// Where events go. Swap in or add a vendor SDK by writing another sink.
protocol AnalyticsSink: AnyObject {
    func record(_ event: AnalyticsEvent)
}

/// Appends one JSON object per line to Application Support/analytics.jsonl. Nothing leaves the device.
final class FileAnalyticsSink: AnalyticsSink {
    static let maxBytes = 2_000_000
    let url: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .sortedKeys
        return e
    }()

    init(fileName: String = "analytics.jsonl") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent(fileName)
    }

    init(url: URL) {
        self.url = url
    }

    func record(_ event: AnalyticsEvent) {
        guard var line = try? encoder.encode(event) else { return }
        line.append(0x0A)
        if let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int, size > Self.maxBytes {
            // Keep the newest half when the file grows too large.
            if let data = try? Data(contentsOf: url) {
                let tail = data.suffix(Self.maxBytes / 2)
                let start = tail.firstIndex(of: 0x0A).map { tail.index(after: $0) } ?? tail.startIndex
                try? Data(tail[start...]).write(to: url)
            }
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }

    func clear() { try? FileManager.default.removeItem(at: url) }
}

final class MemoryAnalyticsSink: AnalyticsSink {
    private(set) var events: [AnalyticsEvent] = []
    func record(_ event: AnalyticsEvent) { events.append(event) }
}

/// Pacing milestones from the design doc, with their target times in active play.
enum Milestone: String, CaseIterable, Codable {
    case firstBlockBreak = "first_block_break"
    case firstUpgrade = "first_upgrade"
    case firstTool = "first_tool"
    case firstMiner = "first_miner"
    case zone2Preview = "zone2_preview"
    case prestigeAvailable = "prestige_available"
    case zone2Unlocked = "zone2_unlocked"
    case firstPrestige = "first_prestige"

    var title: String {
        switch self {
        case .firstBlockBreak: "First block break"
        case .firstUpgrade: "First upgrade"
        case .firstTool: "First tool"
        case .firstMiner: "First miner"
        case .zone2Preview: "Zone 2 preview (area 10)"
        case .prestigeAvailable: "Prestige available"
        case .zone2Unlocked: "Zone 2 unlocked"
        case .firstPrestige: "First prestige"
        }
    }

    /// Target from the doc's pacing table, in seconds of play (low, high).
    var target: ClosedRange<Double>? {
        switch self {
        case .firstBlockBreak: 0...3
        case .firstUpgrade: 0...30
        case .firstTool: 0...180
        case .firstMiner: 180...360
        case .zone2Preview: 0...360
        case .prestigeAvailable: nil
        case .zone2Unlocked: 1800...2400
        case .firstPrestige: 2100...3000
        }
    }
}

/// Account-level analytics state, saved separately from the game so a progress reset can keep it.
struct AnalyticsState: Codable {
    var installDate = Date()
    var sessions = 0
    var playSeconds: Double = 0
    var milestones: [String: Double] = [:]
    /// Latest seconds spent per area, keyed "zone:area".
    var areaSeconds: [String: Double] = [:]
}

final class Analytics {
    private(set) var state: AnalyticsState
    private let sinks: [AnalyticsSink]
    private let stateKey: String
    private var sessionStart: Double?
    private var unsaved: Double = 0

    init(sinks: [AnalyticsSink], stateKey: String = "punchmine.analytics.v1") {
        self.sinks = sinks
        self.stateKey = stateKey
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let saved = try? JSONDecoder().decode(AnalyticsState.self, from: data) {
            state = saved
        } else {
            state = AnalyticsState()
        }
    }

    /// Debug builds keep an on-device event log for the playtest screen; App Store builds write no log
    /// (session and milestone counts still work, and nothing ever leaves the device either way).
    static func makeDefault() -> Analytics {
        #if DEBUG
        Analytics(sinks: [FileAnalyticsSink()])
        #else
        Analytics(sinks: [])
        #endif
    }

    var fileURL: URL? { sinks.compactMap { ($0 as? FileAnalyticsSink)?.url }.first }

    func log(_ name: String, _ params: [String: AnalyticsValue] = [:]) {
        let event = AnalyticsEvent(name: name, time: Date(), session: state.sessions,
                                   playSeconds: (state.playSeconds * 10).rounded() / 10, params: params)
        sinks.forEach { $0.record(event) }
    }

    /// Logs a milestone once per install, with the play time it took.
    func milestone(_ m: Milestone, _ params: [String: AnalyticsValue] = [:]) {
        guard state.milestones[m.rawValue] == nil else { return }
        state.milestones[m.rawValue] = state.playSeconds
        var p = params
        p["seconds"] = .double(state.playSeconds)
        log("milestone_" + m.rawValue, p)
        persist()
    }

    func sessionStarted() {
        state.sessions += 1
        sessionStart = state.playSeconds
        let days = Calendar.current.dateComponents([.day], from: state.installDate, to: Date()).day ?? 0
        log("session_start", ["session_index": .int(state.sessions), "days_since_install": .int(days)])
        persist()
    }

    func sessionEnded() {
        guard let start = sessionStart else { return }
        log("session_end", ["play_seconds": .double(state.playSeconds - start)])
        sessionStart = nil
        persist()
    }

    func addPlayTime(_ dt: Double) {
        state.playSeconds += dt
        unsaved += dt
        if unsaved >= 10 { persist() }
    }

    func recordArea(zone: ZoneID, area: Int, seconds: Double) {
        state.areaSeconds["\(zone.rawValue):\(area)"] = seconds
    }

    func persist() {
        unsaved = 0
        if let data = try? JSONEncoder().encode(state) { UserDefaults.standard.set(data, forKey: stateKey) }
    }

    func clear() {
        state = AnalyticsState()
        sinks.compactMap { $0 as? FileAnalyticsSink }.forEach { $0.clear() }
        persist()
    }
}
