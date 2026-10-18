import Foundation
func check(_ c: Bool, _ msg: String) { print((c ? "PASS " : "FAIL ") + msg) }
let key = "punchmine.save.v1"
func model() -> GameModel { GameModel(analytics: Analytics(sinks: [MemoryAnalyticsSink()], stateKey: "test.analytics9")) }
/// A save at `area` with `tool` equipped, `coins` in the wallet, optionally with 1-HP blocks.
func saveAt(area: Int, tool: Int, coins: Double = 0, weak: Bool = false) {
    UserDefaults.standard.removeObject(forKey: key)
    let g = model(); g.save()
    var dict = try! JSONSerialization.jsonObject(with: UserDefaults.standard.data(forKey: key)!) as! [String: Any]
    var blocks = AreaGenerator.blocks(zone: .quarry, area: area, seed: 11, treasureChance: 0)
    if weak { blocks = blocks.map { Block(id: $0.id, material: $0.material, maxHP: $0.maxHP, hp: 1, armor: 0, reward: $0.reward) } }
    var runs = dict["runs"] as! [String: Any]; var q = runs["quarry"] as! [String: Any]
    q["area"] = area; q["maxCleared"] = area - 1; q["toolIndex"] = tool; q["coins"] = coins
    q["blocks"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(blocks))
    runs["quarry"] = q; dict["runs"] = runs; dict["seeds"] = ["quarry": 11]
    var recs = dict["records"] as! [String: Any]; var r = recs["quarry"] as! [String: Any]
    r["bestArea"] = area; r["bestCleared"] = area - 1; recs["quarry"] = r; dict["records"] = recs
    UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: dict), forKey: key)
}
@main struct Main {
    static func main() {
        check(ZoneID.quarry.tools.count == 10 && ZoneID.caverns.tools.count == 10 && ZoneID.magma.tools.count == 9, "10 / 10 / 9 tools")
        check(ZoneID.quarry.tools.map(\.unlockArea) == ZoneID.quarry.tools.map(\.unlockArea).sorted(), "Zone 1 tools unlock in order")
        // Pierce
        saveAt(area: 45, tool: 6)
        var g = model()
        check(g.tool.name == "Diamond Drill-Fist", "Drill-Fist equipped")
        let top = 7, below = 12
        let hpBelow = g.run.blocks[below].hp
        g.punch(top)
        check(g.run.blocks[below].hp < hpBelow, "Pierce damages the block below")
        // Lightning
        saveAt(area: 75, tool: 8)
        g = model()
        let before = g.run.blocks.map(\.hp)
        for _ in 0..<10 { g.punch(0) }
        let hitOthers = zip(before, g.run.blocks.map(\.hp)).enumerated().filter { $0.offset != 0 && $0.offset != 5 && $0.element.1 < $0.element.0 }.count
        check(hitOthers >= 2, "Thunder Fist zaps random blocks on the 10th punch (\(hitOthers) other blocks hit)")
        // Lucky: extra coins should be about 10% of the normal payout
        var extra = 0.0, normal = 0.0
        for _ in 0..<20 {
            saveAt(area: 32, tool: 5, weak: true)
            g = model()
            let start = g.run.coins
            // Punch every other block; splash breaks some neighbours too, so count whatever broke.
            for i in stride(from: 0, to: 20, by: 2) where !g.run.blocks[i].isBroken { g.punch(i) }
            guard g.run.area == 32 else { continue }
            let expected = g.run.blocks.filter(\.isBroken).map(\.reward).reduce(0, +)
            extra += g.run.coins - start - expected
            normal += expected
        }
        let rate = extra / normal
        check(rate > 0.05 && rate < 0.16, "Silver Knuckles' Lucky doubles about 10% of payouts (measured \(Int(rate * 100))%)")
        // Dynamite
        saveAt(area: 20, tool: 3, coins: 50_000)
        g = model()
        check(g.gadgetState(.dynamite) == .affordable && g.gadgetState(.horn) == .affordable, "both gadgets unlocked by area 20")
        g.buyGadget(.dynamite); g.buyGadget(.horn)
        check(g.ownsGadget(.dynamite) && g.run.coins == 50_000 - Gadget.dynamite.cost - Gadget.horn.cost, "gadgets bought for 7,500 + 30,000")
        g.useGadget(.dynamite)
        check(g.armedGadget == .dynamite, "Dynamite arms")
        let hp0 = g.run.blocks.map(\.hp)
        g.beginPress(at: 12); g.endPress()
        let blasted = [6, 7, 8, 11, 12, 13, 16, 17, 18].filter { g.run.blocks[$0].hp < hp0[$0] || g.run.blocks[$0].isBroken }.count
        let outside = [0, 4, 20, 24].filter { g.run.blocks[$0].hp < hp0[$0] }.count
        check(blasted == 9 && outside == 0 && g.armedGadget == nil, "Dynamite blasts exactly the 3×3 (\(blasted) hit, \(outside) outside)")
        check(g.cooldownLeft(.dynamite) == 45 && !g.canUseGadget(.dynamite), "Dynamite cooldown 45 s")
        g.useGadget(.dynamite)
        check(g.armedGadget == nil, "cannot arm during cooldown")
        // Fever Horn
        g.useGadget(.horn)
        check(g.feverActive && g.cooldownLeft(.horn) == 90 && !g.canUseGadget(.horn), "Fever Horn starts Fever, 90 s cooldown")
        // Cooldowns tick with the game loop
        g.start(); RunLoop.main.run(until: Date().addingTimeInterval(2)); g.stop()
        check(g.cooldownLeft(.dynamite) < 44 && g.cooldownLeft(.dynamite) > 40, "cooldowns count down (\(g.cooldownLeft(.dynamite)))")
        // Prestige resets gadgets
        g.prestige()
        check(!g.ownsGadget(.dynamite) && !g.ownsGadget(.horn), "prestige resets gadgets with the run")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
