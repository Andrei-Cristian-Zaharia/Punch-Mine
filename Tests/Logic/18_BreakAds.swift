import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics18")) }
/// A save with `played` seconds of lifetime play.
func playedSave(_ played: Double, ledger: [String: Any]? = nil) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    dict["stats"] = ["playSeconds": played]
    if let ledger { dict["adLedger"] = ledger }
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
func run(_ g: GameModel, _ seconds: Double) { for _ in 0..<Int(seconds * 20) { g.advance(by: 0.05) } }

@main struct Main {
    static func main() {
        // New players: nothing for the first 15 minutes of lifetime play
        playedSave(0)
        var g = model(); g.breakAdsAvailable = true
        run(g, 6 * 60)
        check(!g.canShowBreakAd(), "no break ads in a player's first 15 minutes")
        // Veterans: not right after launch, then allowed
        playedSave(3_600)
        g = model(); g.breakAdsAvailable = true
        check(!g.canShowBreakAd(), "no break ad within 5 minutes of launch")
        run(g, BreakAdRules.spacingSeconds + 1)
        check(g.canShowBreakAd(), "allowed after 5 minutes of play")
        g.requestBreakAd("test")
        check(g.breakAdRequest == 1, "a request asks the UI for an ad")
        g.breakAdWillShow()
        check(g.isPaused, "the game pauses during the ad")
        g.breakAdDidFinish(shown: true)
        check(!g.isPaused && !g.canShowBreakAd() && g.adLedger.breaks == 1, "then 5 minutes of spacing again, and it's counted")
        g.requestBreakAd("test")
        check(g.breakAdRequest == 1, "requests inside the spacing are ignored")
        // Rewarded ads reset the spacing too, and break ads don't use up the rewarded cap
        run(g, BreakAdRules.spacingSeconds + 1)
        g.adsAvailable = true
        g.adWillShow(.coinRush); g.adDidFinish(.coinRush, rewarded: true)
        check(!g.canShowBreakAd(), "no break ad within 5 minutes of a rewarded ad")
        check(g.adLedger.total == 1, "break ads don't count toward the rewarded daily cap (\(g.adLedger.total))")
        // Off when unavailable or a card is up, and capped per day
        playedSave(3_600)
        g = model()
        run(g, BreakAdRules.spacingSeconds + 1)
        check(!g.canShowBreakAd(), "off when no interstitial provider is ready")
        g.breakAdsAvailable = true
        g.zoneIntro = .caverns
        check(!g.canShowBreakAd(), "never over the zone intro")
        g.zoneIntro = nil
        playedSave(3_600, ledger: ["day": AdLedger.dayKey(), "counts": ["break": BreakAdRules.dailyCap]])
        g = model(); g.breakAdsAvailable = true
        run(g, BreakAdRules.spacingSeconds + 1)
        check(!g.canShowBreakAd(), "at most \(BreakAdRules.dailyCap) a day")
        // Auto-prestige never asks for one: only the prestige screen does
        UserDefaults.standard.removeObject(forKey: key)
    }
}
