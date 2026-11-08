import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics22")) }
func withNightShift(_ level: Int) -> GameModel {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    dict["perks"] = ["nightShift": level]
    var runs = dict["runs"] as! [String: Any]; var q = runs["quarry"] as! [String: Any]
    q["levels"] = ["hireMiner": 3, "strength": 20]; runs["quarry"] = q; dict["runs"] = runs
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
    return model()
}

@main struct Main {
    static func main() {
        check(withNightShift(0).offlineCapSeconds == 2 * 3600, "away earnings: 2 h by default")
        check(withNightShift(1).offlineCapSeconds == 2.5 * 3600, "Night Shift 1: 2 h 30 min")
        check(withNightShift(Perk.nightShift.maxLevel).offlineCapSeconds == 4 * 3600, "Night Shift max: 4 h")
        check(abs(withNightShift(0).offlineEfficiency - 0.10) < 1e-9, "away rate: 10% of the miners' live rate")
        let g = withNightShift(0)
        let fourHours = g.earnings(for: .quarry, elapsed: 4 * 3600)!, twoHours = g.earnings(for: .quarry, elapsed: 2 * 3600)!
        check(fourHours.cappedSeconds == 2 * 3600 && abs(fourHours.coins - twoHours.coins) < 1, "a day away pays the same as 2 h")
        check(Perk.nightShift.effect(level: 1) == "Away earnings count up to 2 h 30 min" && Perk.nightShift.effect(level: 4).hasSuffix("4 h"),
              "perk text shows the cap")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
