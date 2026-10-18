import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics10")) }
func saveAt(area: Int, weak: Bool = false, treasure: Bool = false, levels: [String: Int] = [:], items: [String: Int] = [:],
            equipped: [String: String] = [:], chests: [String: Int] = [:], scrap: Int = 0, coins: Double = 0,
            perks: [String: Int] = [:], tool: Int = -1) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var blocks = AreaGenerator.blocks(zone: .quarry, area: area, seed: 21, treasureChance: treasure ? 1 : 0)
    if weak { blocks = blocks.map { Block(id: $0.id, material: $0.material, maxHP: $0.maxHP, hp: 1, armor: 0, reward: $0.reward) } }
    var runs = dict["runs"] as! [String: Any]; var q = runs["quarry"] as! [String: Any]
    q["area"] = area; q["maxCleared"] = area - 1; q["levels"] = levels; q["coins"] = coins
    q["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(blocks))
    runs["quarry"] = q; dict["runs"] = runs; dict["seeds"] = ["quarry": 21]
    var recs = dict["records"] as! [String: Any]; var r = recs["quarry"] as! [String: Any]
    r["bestArea"] = area; r["bestCleared"] = area - 1; recs["quarry"] = r; dict["records"] = recs
    dict["items"] = items; dict["equipped"] = equipped; dict["chests"] = chests; dict["scrap"] = scrap
    dict["perks"] = perks
    var runs2 = dict["runs"] as! [String: Any]; var q2 = runs2["quarry"] as! [String: Any]; q2["toolIndex"] = tool; runs2["quarry"] = q2; dict["runs"] = runs2
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func clearWeak(_ g: GameModel) { var n = 0; let a = g.run.area; while g.run.area == a && n < 100 { for i in 0..<30 { g.punch(i) }; n += 1 } }
@main struct Main {
    static func main() {
        // Events: what the UI turns into sound, shake and debris
        saveAt(area: 3, weak: true, treasure: true, coins: 1_000)
        let g = model()
        var events: [String] = []
        g.onEvent = { event in
            switch event {
            case .punch: events.append("punch")
            case .blockBreak(_, _, let treasure, _): events.append(treasure ? "treasureBreak" : "break")
            case .areaClear: events.append("clear")
            case .purchase: events.append("purchase")
            case .fever: events.append("fever")
            case .chest: events.append("chest")
            default: events.append("other")
            }
        }
        g.punch(0)
        check(events.prefix(2) == ["punch", "break"], "a punch that breaks a block raises punch, then break (\(events.prefix(2)))")
        for i in 1..<30 { g.punch(i) }
        check(events.contains("treasureBreak"), "breaking treasure raises a treasure break")
        check(events.contains("clear"), "clearing the area raises areaClear")
        events = []
        g.buy(.strength)
        check(events == ["purchase"], "buying an upgrade raises purchase")
        events = []
        while g.canBuy(.strength) { g.buy(.strength) }
        events = []
        g.buy(.strength)
        check(events.isEmpty, "a purchase you can't afford raises nothing")
        // Fever fires once when it starts, not every tick
        events = []
        let open = g.run.blocks.filter { !$0.isBroken }.map(\.id)
        for n in 0..<Config.feverPunches + 10 { g.punch(open[n % open.count]) }
        check(events.filter { $0 == "fever" }.count == 1, "Fever start raises exactly one fever event")

        // Settings from a save made before sound settings existed
        let legacy = #"{"reducedMotion":true,"vibration":"strong","damageNumbers":"all","shortNumbers":false}"#
        let s = try! JSONDecoder().decode(Settings.self, from: Data(legacy.utf8))
        check(s.reducedMotion && s.vibration == .strong && !s.shortNumbers, "old settings keep their values")
        check(s.soundEffects && s.music && s.screenShake && !s.tapToAutoPunch, "missing sound settings default to on")
        var t = Settings(); t.music = false; t.screenShake = false
        let back = try! JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(t))
        check(back == t, "new settings round-trip")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
