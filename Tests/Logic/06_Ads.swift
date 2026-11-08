import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics6")) }
@main struct Main {
    static func main() {
        UserDefaults.standard.removeObject(forKey: key)
        let g = model()
        check(!g.canWatch(.coinRush), "no ads offered while no provider is available")
        g.adsAvailable = true
        check(g.canWatch(.coinRush) && !g.canWatch(.treasureDouble) && !g.canWatch(.offlineDouble), "Coin Rush offered; treasure and offline need context")
        // Coin Rush doubles block rewards
        g.adWillShow(.coinRush)
        check(g.isPaused, "game pauses while an ad shows")
        g.adDidFinish(.coinRush, rewarded: true)
        check(!g.isPaused && g.coinRushRemaining == 120, "Coin Rush grants 2 minutes")
        let target = g.run.blocks.firstIndex { !$0.isBroken && !$0.isTreasure }!
        let reward = g.run.blocks[target].reward
        let before = g.run.coins
        while !g.run.blocks[target].isBroken { g.punch(target) }
        check(g.run.coins - before == reward * 2, "block reward doubled during Coin Rush (\(reward) → \(g.run.coins - before))")
        // Another ad adds time, multiplier stays ×2
        g.adWillShow(.coinRush); g.adDidFinish(.coinRush, rewarded: true)
        check(g.coinRushRemaining == 240, "second Coin Rush extends to 4 min, still ×2")
        // Skipped or failed ad: no reward, and it doesn't use up a daily slot
        g.adWillShow(.coinRush); g.adDidFinish(.coinRush, rewarded: false)
        check(g.coinRushRemaining == 240 && g.adLedger.count(.coinRush) == 2, "skipped ad gives nothing and isn't counted")
        // Daily limit of 6 Coin Rush
        for _ in 0..<4 { g.adWillShow(.coinRush); g.adDidFinish(.coinRush, rewarded: true) }
        check(!g.canWatch(.coinRush) && g.adsLeftToday(.coinRush) == 0, "Coin Rush stops after 6 a day")
        // Rollover
        var ledger = g.adLedger
        ledger.rollOver(now: Date().addingTimeInterval(86_400))
        check(ledger.total == 0, "ledger resets on a new day")
        // Treasure offer
        var found = false
        var guardN = 0
        while !found && guardN < 20000 {
            if let t = g.run.blocks.firstIndex(where: { $0.isTreasure && !$0.isBroken }) {
                while !g.run.blocks[t].isBroken && g.run.blocks[t].isTreasure { g.punch(t) }
                found = true
            } else {
                for i in 0..<30 { g.punch(i) }
                if g.canBuy(.strength) { g.buy(.strength) }
            }
            guardN += 1
        }
        check(found && g.treasureOffer != nil && g.canWatch(.treasureDouble), "treasure break offers a double")
        if let offer = g.treasureOffer {
            let c0 = g.run.coins
            g.adWillShow(.treasureDouble)
            check(g.treasureOffer == nil, "offer clears once the ad starts")
            g.adDidFinish(.treasureDouble, rewarded: true)
            check(g.run.coins - c0 == offer.coins, "treasure double adds the same amount again (\(offer.coins))")
        }
        // Total daily cap
        UserDefaults.standard.removeObject(forKey: key)
        let h = model(); h.adsAvailable = true
        for _ in 0..<6 { h.adWillShow(.coinRush); h.adDidFinish(.coinRush, rewarded: true) }
        var l = h.adLedger
        for _ in 0..<(AdRules.dailyCap - 6) { l.record(.offlineDouble) }
        check(l.total == AdRules.dailyCap, "ledger counts toward the \(AdRules.dailyCap)-a-day cap")
        // Persistence
        h.save()
        let h2 = model()
        check(h2.adLedger.count(.coinRush) == 6, "ad counts persist across launches")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
