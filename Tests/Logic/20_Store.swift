import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics20")) }
func run(_ g: GameModel, _ seconds: Double) { for _ in 0..<Int(seconds * 20) { g.advance(by: 0.05) } }

@main struct Main {
    static func main() {
        check(Set(StoreProduct.allCases.map(\.rawValue)).count == StoreProduct.allCases.count, "unique product IDs")
        check(StoreProduct.allCases.allSatisfy { !$0.contents.isEmpty && $0.fallbackPrice.hasPrefix("$") }, "every product lists contents and a price")

        UserDefaults.standard.removeObject(forKey: key)
        var g = model()
        let scrap = g.scrap, pc = g.perkCoins
        check(g.grantPurchase(.starterPack, transactionID: "t1"), "Starter Pack is granted")
        check(g.chestCount(.golden) == 1 && g.chestCount(.iron) == 3 && g.scrap == scrap + 500 && g.perkCoins == pc + 200 && g.owns(.starterPack),
              "Starter Pack: 1 Golden, 3 Iron, 500 Scrap, 200 PC")
        check(!g.grantPurchase(.starterPack, transactionID: "t1"), "the same transaction never pays twice")
        check(!g.grantPurchase(.starterPack, transactionID: "t2") && g.chestCount(.golden) == 1, "a one-time product never pays twice, even on a new transaction")
        g.grantPurchase(.scrapSmall, transactionID: "t3")
        g.grantPurchase(.scrapSmall, transactionID: "t4")
        check(g.scrap == scrap + 500 + 600, "consumables can be bought again")
        g.grantPurchase(.goldenChests, transactionID: "t5")
        check(g.chestCount(.golden) == 4, "3 Golden Chests")

        // Remove Ads blocks break ads, keeps rewarded ones
        g.save(); g = model()
        check(g.owns(.starterPack) && !g.grantPurchase(.scrapSmall, transactionID: "t3"), "ownership and processed transactions survive a reload")
        do {
            g.save()
            var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
            dict["stats"] = ["playSeconds": 3_600]
            UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
        }
        g = model(); g.breakAdsAvailable = true; g.adsAvailable = true
        run(g, BreakAdRules.spacingSeconds + 1)
        check(g.canShowBreakAd(), "break ads allowed before Remove Ads")
        g.grantPurchase(.removeAds, transactionID: "t6")
        check(g.adsRemoved && !g.canShowBreakAd() && g.canWatch(.coinRush), "Remove Ads: no break ads, rewarded ads still offered")

        // Purchases survive a progress reset
        g.resetProgress(keepItems: false)
        check(g.adsRemoved && g.owns(.starterPack), "resetting progress keeps what was bought")
        g = model()
        check(g.adsRemoved && !g.grantPurchase(.removeAds, transactionID: "t7"), "and it's still there after a reload")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
