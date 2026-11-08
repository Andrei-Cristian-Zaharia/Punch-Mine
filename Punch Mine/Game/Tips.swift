import Foundation

/// One-time coaching tips. Each appears the first time its feature matters, at most one at a time,
/// and goes away when the player does the thing, taps "Got it", or after a while. Cases are in priority order.
enum Tip: String, CaseIterable, Codable, Identifiable {
    case upgrade, hold, armor, miner, fever, treasure, chest, drawer, gadget, newZone, prestige, perks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upgrade: "Buy an upgrade"
        case .hold: "Hold to punch"
        case .armor: "Armored block"
        case .miner: "Hire a miner"
        case .fever: "FEVER!"
        case .treasure: "Treasure block"
        case .chest: "You found a chest"
        case .drawer: "More room to mine"
        case .gadget: "Gadgets"
        case .newZone: "A new zone"
        case .prestige: "Prestige is ready"
        case .perks: "Spend Perk Coins"
        }
    }

    var text: String {
        switch self {
        case .upgrade: "Open the drawer below and buy Strength to hit harder."
        case .hold: "Keep your finger on a block and you'll punch it again and again."
        case .armor: "\"DEFLECT\" means armor is soaking up your punch. Tools with penetration cut through it."
        case .miner: "Miners dig on their own, even while you're away. Hire one in the Miners tab."
        case .fever: "60 punches in quick succession light up Fever: every punch hits twice as hard for a few seconds."
        case .treasure: "Tough, but pays 10× and may drop a chest. Once the rest of the area is clear, you have 10 s to break it."
        case .chest: "Open it from the backpack in the zone bar. Items stay with you through prestige."
        case .drawer: "Drag the drawer handle down to shrink it, or up to see every upgrade."
        case .gadget: "Dynamite and the Fever Horn are in the Tools tab. Buy once, use whenever they're charged."
        case .newZone: "You've gone deep enough to open Crystal Caverns. Tap the zone bar at the top."
        case .prestige: "Restart this mine for Perk Coins and permanent perks. The deeper you are, the more you get."
        case .perks: "Tap the ★ at the top to buy perks. They last forever."
        }
    }

    var symbol: String {
        switch self {
        case .upgrade: "arrow.up.circle.fill"
        case .hold: "hand.point.up.left.fill"
        case .armor: "shield.lefthalf.filled"
        case .miner: "person.fill"
        case .fever: "flame.fill"
        case .treasure: "shippingbox.fill"
        case .chest: Symbols.backpack
        case .drawer: "rectangle.bottomhalf.filled"
        case .gadget: "bolt.fill"
        case .newZone: "map.fill"
        case .prestige: "star.circle.fill"
        case .perks: "star.fill"
        }
    }

    /// Seconds before an unanswered tip quietly goes away (it still counts as seen).
    var duration: Double {
        switch self {
        case .upgrade, .miner, .chest, .prestige, .perks, .newZone: 25
        default: 10
        }
    }

    /// Tips raised by a moment rather than by state.
    var isEvent: Bool { self == .armor || self == .fever }
}

extension GameModel {
    /// Seconds of play between two tips, so they never feel like a stream of pop-ups.
    static let tipGap = 20.0

    /// Whether the game state calls for this tip right now.
    func wantsTip(_ tip: Tip) -> Bool {
        switch tip {
        case .upgrade: run.levels.values.allSatisfy { $0 == 0 } && canBuy(.strength)
        case .hold: holdUnlocked && run.area >= 2 && punchCount >= 15
        case .armor, .fever: pendingTipEvents.contains(tip)
        case .miner: minerCount(.digger) == 0 && canBuy(.hireMiner)
        case .treasure: run.blocks.contains { $0.isTreasure && !$0.isBroken }
        case .chest: ChestTier.allCases.contains { chestCount($0) > 0 }
        case .drawer: run.area >= 8 && run.levels.values.contains { $0 > 0 }
        case .gadget: Gadget.allCases.contains { gadgetState($0) != .locked && !ownsGadget($0) }
        case .newZone: zone == .quarry && unlockAreaMet(.caverns) && !isUnlocked(.caverns)
        // Not the moment it unlocks at area 12 (a few PC): wait until a first prestige is worth it.
        case .prestige: canPrestige && record.prestigeCount == 0 && prestigeReward >= Prestige.depthReward(area: 30)
        case .perks: perkCoins > 0 && perks.isEmpty
        }
    }

    /// The player already did what this tip teaches, so it's skipped for good.
    func didTipAction(_ tip: Tip) -> Bool {
        switch tip {
        case .upgrade: run.levels.values.contains { $0 > 0 } || record.prestigeCount > 0
        case .miner: minerCount(.digger) > 0
        case .chest: !items.isEmpty
        case .gadget: Gadget.allCases.contains { ownsGadget($0) }
        case .newZone: isUnlocked(.caverns)
        case .prestige: record.prestigeCount > 0
        case .perks: !perks.isEmpty
        default: false
        }
    }

    /// Called from the game loop.
    func updateTips() {
        // Moments only count if a tip can react to them now.
        defer { pendingTipEvents.removeAll() }
        if let tip = activeTip {
            // State tips end when the player acts on them; every tip ends after its duration.
            if (!tip.isEvent && !wantsTip(tip)) || clock - tipShownAt > tip.duration { finishTip() }
            return
        }
        for tip in Tip.allCases where !seenTips.contains(tip.rawValue) && didTipAction(tip) {
            seenTips.insert(tip.rawValue)
        }
        guard settings.showTips, clock >= 2, clock - lastTipEnded >= Self.tipGap, !isPaused else { return }
        if let next = Tip.allCases.first(where: { !seenTips.contains($0.rawValue) && wantsTip($0) }) {
            activeTip = next
            tipShownAt = clock
            analytics.log("tip_shown", ["tip": .string(next.rawValue)])
        }
    }

    func dismissTip() { finishTip() }

    func resetTips() {
        seenTips = []
        activeTip = nil
        save()
    }

    func noteTipEvent(_ tip: Tip) {
        if !seenTips.contains(tip.rawValue) { pendingTipEvents.insert(tip) }
    }

    private func finishTip() {
        guard let tip = activeTip else { return }
        seenTips.insert(tip.rawValue)
        activeTip = nil
        lastTipEnded = clock
        save()
    }
}

/// SF Symbols that are newer than iOS 16, with the closest older symbol as a fallback.
enum Symbols {
    static var backpack: String {
        if #available(iOS 17, macOS 14, *) { return "backpack.fill" }
        return "bag.fill"
    }
}
