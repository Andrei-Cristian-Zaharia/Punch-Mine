import SwiftUI

/// Three heights: minimized (handle only, biggest map), collapsed (3 rows) and expanded (over the map).
enum DrawerState: Int {
    case minimized, collapsed, expanded

    var lower: DrawerState { DrawerState(rawValue: max(rawValue - 1, 0)) ?? .minimized }
    var higher: DrawerState { DrawerState(rawValue: min(rawValue + 1, 2)) ?? .expanded }
}

struct UpgradeDrawer: View {
    enum Tab: String, CaseIterable, Identifiable {
        case punch = "Punch", tools = "Tools", miners = "Miners", bonus = "Bonus"
        var id: String { rawValue }
    }

    // Collapsed: top padding 8 + handle 28 + gap 8 + tabs 36 + gap 8 + list 196.
    static let handleHeight: CGFloat = 28
    static let collapsedListHeight: CGFloat = 196
    static let expandedListHeight: CGFloat = 360
    static let collapsedHeight: CGFloat = 8 + handleHeight + 8 + 36 + 8 + collapsedListHeight
    static let minimizedHeight: CGFloat = 8 + handleHeight + 8

    /// Space the map leaves free at the bottom for each state. Expanded slides over the map instead.
    static func reservedHeight(_ state: DrawerState) -> CGFloat {
        state == .minimized ? minimizedHeight : collapsedHeight
    }

    @EnvironmentObject private var game: GameModel
    @Binding var state: DrawerState
    @State private var tab = Tab.punch

    var body: some View {
        VStack(spacing: 8) {
            handle
            if state != .minimized {
                tabs
                ScrollView {
                    VStack(spacing: 6) { rows }
                }
                .frame(height: state == .expanded ? Self.expandedListHeight : Self.collapsedListHeight)
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, state == .minimized ? 8 : 0)
        .background {
            // Bottom corners are pushed off screen, so only the top corners show rounded.
            RoundedRectangle(cornerRadius: 22)
                .fill(game.zone.panel)
                .padding(.bottom, -40)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases) { t in
                Button {
                    tab = t
                } label: {
                    Text(t.rawValue)
                        .font(Theme.body(13, .black))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(tab == t ? game.zone.accent : Theme.card, in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(tab == t ? game.zone.onAccent : Theme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private var rows: some View {
        switch tab {
        case .punch:
            UpgradeRow(kind: .strength)
            UpgradeRow(kind: .speed)
            UpgradeRow(kind: .critChance)
            UpgradeRow(kind: .critDamage)
            UpgradeRow(kind: .focus)
            UpgradeRow(kind: .rhythm)
        case .tools:
            ForEach(game.zone.tools) { ToolRow(tool: $0) }
            Text("GADGETS")
                .font(Theme.body(11, .black)).tracking(1)
                .foregroundStyle(Theme.textFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            ForEach(Gadget.allCases) { GadgetRow(gadget: $0) }
        case .miners:
            if game.minerCount > 0 {
                Label("\(game.minerCount) miner\(game.minerCount == 1 ? "" : "s") · \(NumberText.format(game.minerHit)) base hit",
                      systemImage: "hammer.fill")
                    .font(Theme.body(12, .heavy))
                    .foregroundStyle(Color(hex: 0xCFE5FF))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            UpgradeRow(kind: .hireMiner)
            UpgradeRow(kind: .hireDriller)
            UpgradeRow(kind: .hireBlaster)
            UpgradeRow(kind: .training)
            UpgradeRow(kind: .shiftPace)
        case .bonus:
            UpgradeRow(kind: .deepPockets)
            UpgradeRow(kind: .treasureHunter)
            UpgradeRow(kind: .lockpick)
            UpgradeRow(kind: .feverStamina)
            UpgradeRow(kind: .overcharge)
            UpgradeRow(kind: .contracts)
        }
    }

    /// Upgrades and tools the player can buy right now; shown on the minimized handle.
    private var affordable: Int {
        UpgradeKind.allCases.filter { game.canBuy($0) }.count
            + game.zone.tools.filter { game.toolState($0) == .affordable }.count
    }

    /// Tap: minimized → collapsed → expanded → collapsed. Drag up or down to step one level.
    private var handle: some View {
        Button {
            state = state == .collapsed ? .expanded : .collapsed
        } label: {
            ZStack {
                VStack(spacing: 0) {
                    Capsule().fill(Theme.textFaint).frame(width: 44, height: 5)
                    Image(systemName: state == .expanded ? "chevron.compact.down" : "chevron.compact.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textFaint)
                        .frame(height: 18)
                }
                if state == .minimized {
                    HStack {
                        Text("Upgrades")
                            .font(Theme.body(13, .black))
                            .foregroundStyle(Theme.textMuted)
                        Spacer()
                        if affordable > 0 {
                            Text("\(affordable) ready")
                                .font(Theme.body(12, .black))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.buy, in: Capsule())
                                .foregroundStyle(Color(hex: 0xF2FFE9))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.handleHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.height < -20 { state = state.higher }
                    if value.translation.height > 20 { state = state.lower }
                }
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAction(named: "Minimize upgrades") { state = .minimized }
        .accessibilityAction(named: "Expand upgrades") { state = .expanded }
    }

    private var accessibilityLabel: String {
        switch state {
        case .minimized: "Show upgrades, \(affordable) ready to buy"
        case .collapsed: "Expand upgrades"
        case .expanded: "Collapse upgrades"
        }
    }
}

private struct UpgradeRow: View {
    @EnvironmentObject private var game: GameModel
    let kind: UpgradeKind

    var body: some View {
        let level = game.run.level(kind)
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(kind.title).font(Theme.body(14, .black))
                    Text("Lv \(level)").font(Theme.body(12)).foregroundStyle(Theme.textFaint)
                }
                Text(game.isUnlocked(kind) ? effectText : lockedText)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 4)
            if game.isMaxed(kind) {
                Text("MAX").font(Theme.body(14, .black)).foregroundStyle(Theme.textFaint).frame(minWidth: 82)
            } else if game.isUnlocked(kind) {
                BuyButton(cost: game.cost(kind), enabled: game.canBuy(kind)) { game.buy(kind) }
            } else {
                Image(systemName: "lock.fill").foregroundStyle(Theme.textFaint).frame(minWidth: 82)
                    .accessibilityLabel("Locked")
            }
        }
        .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .opacity(game.isUnlocked(kind) ? 1 : 0.6)
    }

    private var lockedText: String {
        kind == .training || kind == .shiftPace ? "Hire a miner first" : "Unlocks at area \(kind.unlockArea)"
    }

    private var effectText: String {
        let l = game.run.level(kind)
        switch kind {
        case .strength:
            return "\(NumberText.format(Config.strength(level: l))) → \(NumberText.format(Config.strength(level: l + 1))) base damage"
        case .speed:
            return "\(NumberText.decimal(Config.holdRate(speedLevel: l))) → \(NumberText.decimal(Config.holdRate(speedLevel: l + 1))) hold punches/s"
        case .critChance:
            return "\(NumberText.percent(Config.critChance(level: l))) → \(NumberText.percent(Config.critChance(level: l + 1))) · cap 30%"
        case .critDamage:
            return "\(NumberText.decimal(Config.critMultiplier(level: l)))× → \(NumberText.decimal(Config.critMultiplier(level: l + 1)))× crit damage"
        case .focus:
            return "Up to +\(Int(Config.focusPerStack * 100) * Config.focusStacksPerLevel * l)% → +\(Int(Config.focusPerStack * 100) * Config.focusStacksPerLevel * (l + 1))% on one block"
        case .hireMiner:
            return "\(l) → \(l + 1) diggers · hit the weakest block"
        case .hireDriller:
            return "\(l) → \(l + 1) drillers · ×4 hit every 3 s, ignores 75% armor"
        case .hireBlaster:
            return "\(l) → \(l + 1) blasters · ×3 blast on 3×3 every 5 s"
        case .training:
            let now = Config.minerPunchShare + Config.minerPunchSharePerTraining * Double(l)
            return "Miners hit \(NumberText.percent(now)) → \(NumberText.percent(now + Config.minerPunchSharePerTraining)) of your punch"
        case .shiftPace:
            return "\(Int(Config.shiftPacePerLevel * 100) * l)% → \(Int(Config.shiftPacePerLevel * 100) * (l + 1))% faster miner swings"
        case .feverStamina:
            let now = Config.feverDuration + Config.feverSecondsPerLevel * Double(l)
            return "\(NumberText.decimal(now)) → \(NumberText.decimal(now + Config.feverSecondsPerLevel)) s of Fever"
        case .contracts:
            let now = Config.clearBonusShare + Config.contractsPerLevel * Double(l)
            return "\(NumberText.percent(now)) → \(NumberText.percent(now + Config.contractsPerLevel)) area clear bonus"
        case .rhythm:
            return l == 0 ? "Every 11th punch is a sure crit"
                          : "Every \(Config.rhythmBase - l) → \(Config.rhythmBase - l - 1) punches: a sure crit"
        case .deepPockets:
            return "+\(Int(Config.deepPocketsPerLevel * 100) * l)% → +\(Int(Config.deepPocketsPerLevel * 100) * (l + 1))% block coins"
        case .overcharge:
            let now = Config.feverMultiplier + Config.overchargePerLevel * Double(l)
            return "Fever ×\(NumberText.decimal(now)) → ×\(NumberText.decimal(now + Config.overchargePerLevel))"
        case .treasureHunter:
            return "+\(l) → +\(l + 1) points treasure chance"
        case .lockpick:
            return "\(Int(Config.lockpickPerLevel * 100) * l)% → \(Int(Config.lockpickPerLevel * 100) * (l + 1))% chance of an extra chest"
        }
    }

    private var icon: String {
        switch kind {
        case .strength: "hand.raised.fill"
        case .speed: "hare.fill"
        case .critChance: "star.fill"
        case .critDamage: "sparkle"
        case .focus: "scope"
        case .hireMiner: "hammer.fill"
        case .hireDriller: "screwdriver.fill"
        case .hireBlaster: "burst.fill"
        case .training: "figure.strengthtraining.traditional"
        case .shiftPace: "timer"
        case .feverStamina: "flame.fill"
        case .contracts: "doc.text.fill"
        case .rhythm: "metronome.fill"
        case .deepPockets: "bag.fill"
        case .overcharge: "bolt.fill"
        case .treasureHunter: "map.fill"
        case .lockpick: "key.fill"
        }
    }

    private var iconColor: Color {
        switch kind {
        case .strength: Color(hex: 0xFFB27A)
        case .speed: Color(hex: 0x8FC6FF)
        case .critChance, .critDamage, .focus: Color(hex: 0xFFC24F)
        case .hireMiner, .training, .shiftPace: Theme.minerLight
        case .hireDriller: MinerKind.driller.lightColor
        case .hireBlaster: MinerKind.blaster.lightColor
        case .feverStamina: Theme.fever
        case .contracts, .deepPockets: Color(hex: 0x9FE08F)
        case .rhythm: Color(hex: 0xFFC24F)
        case .overcharge: Theme.fever
        case .treasureHunter, .lockpick: Theme.gold
        }
    }
}

private struct ToolRow: View {
    @EnvironmentObject private var game: GameModel
    let tool: Tool

    var body: some View {
        let state = game.toolState(tool)
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fingers.spread.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 36, height: 36)
                .background(Theme.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name).font(Theme.body(14, .black))
                Text(state == .locked ? "Unlocks at area \(tool.unlockArea)" : tool.blurb)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 4)
            switch state {
            case .owned:
                Text(game.run.toolIndex == tool.id ? "EQUIPPED" : "OWNED")
                    .font(Theme.body(12, .black)).foregroundStyle(Color(hex: 0x9FE08F)).frame(minWidth: 82)
            case .affordable, .tooExpensive:
                BuyButton(cost: game.toolCost(tool), enabled: state == .affordable) { game.buyTool(tool) }
            case .locked:
                Image(systemName: "lock.fill").foregroundStyle(Theme.textFaint).frame(minWidth: 82)
                    .accessibilityLabel("Locked")
            }
        }
        .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .opacity(state == .locked ? 0.6 : 1)
    }
}

private struct BuyButton: View {
    @EnvironmentObject private var game: GameModel
    let cost: Double
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                CurrencyIcon(zone: game.zone, size: 14)
                Text(NumberText.format(cost, short: game.settings.shortNumbers))
                    .font(Theme.body(15, .black))
            }
            .frame(minWidth: 82, minHeight: 44)
            .background(enabled ? Theme.buy : Theme.cardRaised, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(enabled ? Color(hex: 0xF2FFE9) : Theme.textFaint)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("Buy for \(NumberText.format(cost, short: false)) \(game.zone.currencyShort)")
    }
}

private struct GadgetRow: View {
    @EnvironmentObject private var game: GameModel
    let gadget: Gadget

    var body: some View {
        let state = game.gadgetState(gadget)
        HStack(spacing: 10) {
            Image(systemName: gadget.symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(gadget == .dynamite ? Theme.fever : Theme.gold)
                .frame(width: 36, height: 36)
                .background(Theme.fever.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(gadget.name).font(Theme.body(14, .black))
                Text(state == .locked ? "Unlocks at area \(gadget.unlockArea)" : gadget.blurb)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            switch state {
            case .owned:
                Text("OWNED").font(Theme.body(12, .black)).foregroundStyle(Color(hex: 0x9FE08F)).frame(minWidth: 82)
            case .affordable, .tooExpensive:
                BuyButton(cost: gadget.cost, enabled: state == .affordable) { game.buyGadget(gadget) }
            case .locked:
                Image(systemName: "lock.fill").foregroundStyle(Theme.textFaint).frame(minWidth: 82)
                    .accessibilityLabel("Locked")
            }
        }
        .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .opacity(state == .locked ? 0.6 : 1)
    }
}
