import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
func grind(_ g: GameModel, to area: Int) {
    var n = 0
    while g.run.maxCleared < area && n < 400000 {
        for i in 0..<30 { g.punch(i) }
        for t in g.zone.tools where g.toolState(t) == .affordable { g.buyTool(t) }
        if g.canBuy(.hireMiner) { g.buy(.hireMiner) }
        for k in UpgradeKind.allCases where g.canBuy(k) { g.buy(k) }
        n += 1
    }
}
@main struct Main {
    static func main() {
        UserDefaults.standard.removeObject(forKey: "punchmine.save.v1")
        UserDefaults.standard.removeObject(forKey: "test.analytics4")
        let sink = MemoryAnalyticsSink()
        let analytics = Analytics(sinks: [sink], stateKey: "test.analytics4")
        let g = GameModel(analytics: analytics)
        g.start(); g.stop()
        check(sink.events.map(\.name).prefix(2) == ["session_start", "session_end"], "session start and end logged")
        grind(g, to: 12)
        let names = sink.events.map(\.name)
        check(names.filter { $0 == "area_cleared" }.count == 12, "one area_cleared per area (\(names.filter { $0 == "area_cleared" }.count))")
        for m in [Milestone.firstBlockBreak, .firstUpgrade, .firstTool, .firstMiner, .zone2Preview, .prestigeAvailable] {
            check(analytics.state.milestones[m.rawValue] != nil, "milestone \(m.rawValue) recorded")
        }
        check(names.filter { $0 == "milestone_first_upgrade" }.count == 1, "milestones fire once")
        let cleared = sink.events.filter { $0.name == "area_cleared" }
        let shares = cleared.compactMap { e -> Double? in if case .double(let v) = e.params["miner_share"] { return v }; return nil }
        check(shares.count == 12 && shares.allSatisfy { (0...1).contains($0) }, "miner_share stays within 0–1")
        // Let the real loop run so miners swing, then finish the area by hand.
        let area = g.run.area
        g.start()
        RunLoop.main.run(until: Date().addingTimeInterval(4))
        g.stop()
        while g.run.area == area { for i in 0..<30 { g.punch(i) } }
        let last = sink.events.last { $0.name == "area_cleared" }
        if case .double(let share)? = last?.params["miner_share"], case .double(let secs)? = last?.params["seconds"] {
            check(share > 0 && share < 1 && secs >= 3, "miners counted in live play: share \(share), \(secs) s in area")
        } else { check(false, "live area_cleared params") }
        check(analytics.state.playSeconds >= 3, "play time accumulates (\(analytics.state.playSeconds) s)")
        if case .int(let p) = cleared[0].params["punches"] { check(p > 0, "punches per area counted (\(p))") } else { check(false, "punches param") }
        check(names.contains("upgrade_bought") && names.contains("tool_bought"), "shop events logged")
        let depth = g.prestigeArea
        g.prestige()
        let pe = sink.events.last { $0.name == "prestige" }
        check(pe?.params["area"] == .int(depth) && pe?.params["reward"] == .int(Prestige.depthReward(area: depth)) && analytics.state.milestones["first_prestige"] != nil, "prestige event with area \(depth) and its reward")
        g.buyPerk(.heavyFists)
        check(sink.events.last?.name == "perk_bought", "perk purchase logged")
        grind(g, to: depth)
        check(sink.events.contains { $0.name == "returned_to_depth" && $0.params["depth"] == .int(depth) }, "returned_to_depth logged on reaching last prestige depth")
        // JSON Lines file sink
        let url = URL(fileURLWithPath: "events_test.jsonl")
        try? FileManager.default.removeItem(at: url)
        let file = FileAnalyticsSink(url: url)
        sink.events.prefix(5).forEach(file.record)
        let lines = try! String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let decoded = lines.compactMap { try? dec.decode(AnalyticsEvent.self, from: Data($0.utf8)) }
        check(lines.count == 5 && decoded.count == 5 && decoded[0].name == "session_start", "file sink writes decodable JSON lines")
        print(lines[2])
        UserDefaults.standard.removeObject(forKey: "punchmine.save.v1")
        UserDefaults.standard.removeObject(forKey: "test.analytics4")
    }
}
