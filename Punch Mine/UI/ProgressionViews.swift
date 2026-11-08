import SwiftUI

// MARK: - Prestige confirmation

struct PrestigeView: View {
    @EnvironmentObject private var game: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var holding = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ZONE \(game.zone.number) · \(game.zone.name.uppercased())")
                        .font(Theme.body(11, .black)).tracking(1.5).foregroundStyle(Theme.perkLight)
                    Text("Prestige this mine?").font(Theme.display(28))
                }

                HStack(spacing: 14) {
                    PerkCoinIcon(size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("+\(game.prestigeReward) Perk Coins")
                            .font(Theme.display(32))
                            .foregroundStyle(Color(hex: 0xE6DAFF))
                        Text("Depth (area \(game.prestigeArea)) \(game.prestigeDepthReward) · Record bonus \(game.prestigeRecordBonus)")
                            .font(Theme.body(12, .heavy))
                            .foregroundStyle(Color(hex: 0xBBA9E6))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.perkPanel, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityElement(children: .combine)

                HStack(alignment: .top, spacing: 10) {
                    listCard("RESETS · THIS ZONE", color: Color(hex: 0xFF9C8A), fill: Color(hex: 0x2A1C1C), items: [
                        "\(game.zone.currencyName) (\(NumberText.format(game.run.coins)))",
                        "Area \(game.run.area) → area 1",
                        "Strength, Speed, Crit",
                        "Tools",
                        "Miners and Training",
                    ])
                    listCard("STAYS", color: Color(hex: 0x9FE08F), fill: Color(hex: 0x1C2A20), items: stays)
                }

                if !startBonuses.isEmpty {
                    Text("Your perks start the next run with \(startBonuses.joined(separator: " and ")).")
                        .font(Theme.body(13)).foregroundStyle(Color(hex: 0xC9BFE0))
                }

                holdButton

                Button("Keep mining") { dismiss() }
                    .font(Theme.body(15, .heavy))
                    .foregroundStyle(Color(hex: 0xC7B2FF))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(18)
        }
        .background(Theme.perkGround.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }

    private var stays: [String] {
        var items = game.unlockedZones.filter { $0 != game.zone }.map { "\($0.name) progress" }
        items += ["Perks and Perk Coins", "Best area: \(game.bestArea)", "Hold to punch", "Settings"]
        return items
    }

    private var startBonuses: [String] {
        var parts: [String] = []
        let seed = Perk.seedMoneyAmounts[min(game.level(.seedMoney), Perk.seedMoneyAmounts.count - 1)]
        if seed > 0 { parts.append("\(NumberText.format(seed)) \(game.zone.currencyShort)") }
        let crew = game.level(.dayOneCrew)
        if crew > 0 { parts.append("\(crew) miner\(crew == 1 ? "" : "s")") }
        return parts
    }

    /// Hold for one second to confirm, so a stray tap never resets a run.
    private var holdButton: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x3A2D63))
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.perk)
                    .frame(width: holding ? geo.size.width : 0)
            }
            Text(holding ? "Keep holding…" : "Hold to prestige")
                .font(Theme.body(17, .black))
                .frame(maxWidth: .infinity)
        }
        .frame(height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.0, maximumDistance: 40) {
            confirm()
        } onPressingChanged: { pressing in
            withAnimation(pressing ? .linear(duration: 1.0) : .easeOut(duration: 0.2)) { holding = pressing }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prestige for \(game.prestigeReward) Perk Coins")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirm() }
    }

    private func confirm() {
        game.prestige()
        game.requestBreakAd("prestige")
        dismiss()
    }

    private func listCard(_ title: String, color: Color, fill: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.body(12, .black)).tracking(1).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text("• " + item).font(Theme.body(13)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(fill, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Perk tree

struct PerksView: View {
    @EnvironmentObject private var game: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab = PerksTab.branch(.power)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if game.totalPrestiges == 0 {
                        Text(game.canPrestige
                             ? "Prestige \(game.zone.name) to earn \(game.prestigeReward) Perk Coins. Deeper runs pay much more."
                             : "Prestige unlocks at area \(game.prestigeRequiredArea). Deeper runs pay more Perk Coins.")
                            .font(Theme.body(13))
                            .foregroundStyle(Color(hex: 0xD7C9E8))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.perkPanel, in: RoundedRectangle(cornerRadius: 12))
                    }


                    switch tab {
                    case .branch(let branch):
                        ForEach(Perk.allCases.filter { $0.branch == branch }) { perk in
                            PerkRow(perk: perk)
                                .padding(.leading, CGFloat(perk.depth) * 24)
                        }
                    case .ascension:
                        AscensionSection()
                    }

                    Text("Perk Coins are shared by every zone and buy perks only. Bonuses to the same stat add together.")
                        .font(Theme.body(12))
                        .foregroundStyle(Color(hex: 0x9C90B3))
                        .padding(.top, 4)
                }
                .padding(16)
            }
            // Pinned above the list, so the tabs never move under a finger.
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Branch", selection: $tab) {
                    ForEach(PerkBranch.allCases) { Text($0.rawValue).tag(PerksTab.branch($0)) }
                    Text("Ascension").tag(PerksTab.ascension)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Theme.perkGround)
            }
            .background(Theme.perkGround.ignoresSafeArea())
            .navigationTitle("Perks")
            #if DEBUG
            .onAppear { if UserDefaults.standard.string(forKey: "debugScreen") == "ascension" { tab = .ascension } }
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        PerkCoinIcon(size: 18)
                        Text("\(game.perkCoins) Perk Coins").font(Theme.body(16, .black))
                    }
                    .accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .foregroundStyle(Theme.text)
    }
}

enum PerksTab: Hashable {
    case branch(PerkBranch), ascension
}

/// Star perks (repeatable) and Ascension perks (one-time), unlocked by the first Crown.
private struct AscensionSection: View {
    @EnvironmentObject private var game: GameModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(game.ascensionUnlocked
                 ? "Spend Perk Coins forever: Star perks have no level cap and stack on top of everything else."
                 : "Defeat any zone's Heart to unlock Ascension: endless Star perks and powerful one-time upgrades.")
                .font(Theme.body(13))
                .foregroundStyle(Color(hex: 0xD7C9E8))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.perkPanel, in: RoundedRectangle(cornerRadius: 12))
            Text("STAR PERKS").font(Theme.body(12, .black)).tracking(1.2).foregroundStyle(Color(hex: 0x9C90B3))
            ForEach(StarPerk.allCases) { star in
                let level = game.starLevel(star)
                AscensionRow(symbol: star.symbol, name: star.name,
                             levelText: star.maxLevel.map { "\(level) / \($0)" } ?? "Lv \(level)",
                             detail: level == 0 ? star.summary : "Now: " + star.effect(level: level),
                             state: game.starState(star), cost: star.cost(level: level)) { game.buyStar(star) }
            }
            Text("ASCENSION PERKS").font(Theme.body(12, .black)).tracking(1.2).foregroundStyle(Color(hex: 0x9C90B3))
                .padding(.top, 6)
            ForEach(AscensionPerk.allCases) { perk in
                AscensionRow(symbol: perk.symbol, name: perk.name, levelText: game.owns(perk) ? "OWNED" : "ONCE",
                             detail: perk.summary, state: game.ascensionState(perk), cost: perk.cost) { game.buyAscension(perk) }
                if perk == .autoPrestige && game.owns(.autoPrestige) {
                    Toggle("Auto-prestige on", isOn: $game.settings.autoPrestige)
                        .font(Theme.body(14, .heavy))
                        .tint(Theme.perk)
                        .padding(.horizontal, 12)
                }
            }
        }
    }
}

private struct AscensionRow: View {
    let symbol: String
    let name: String
    let levelText: String
    let detail: String
    let state: PerkState
    let cost: Int
    let buy: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state == .locked ? "lock.fill" : symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(state == .locked ? Color(hex: 0x8A7FA0) : Theme.gold)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name).font(Theme.body(15, .black))
                    Text(levelText).font(Theme.body(11, .heavy)).foregroundStyle(Color(hex: 0x9C90B3))
                }
                Text(detail).font(Theme.body(12)).foregroundStyle(Color(hex: 0xC9BEDB))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if state == .maxed {
                Text("MAX").font(Theme.body(14, .black)).foregroundStyle(Color(hex: 0x9C90B3)).frame(minWidth: 70)
            } else if state != .locked {
                Button(action: buy) {
                    Text("\(NumberText.format(Double(cost))) PC")
                        .font(Theme.body(14, .black))
                        .frame(minWidth: 70, minHeight: 44)
                        .background(state == .affordable ? Theme.perk : Color(hex: 0x3A3148), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(state == .affordable ? .white : Color(hex: 0x8A7FA0))
                }
                .buttonStyle(.plain)
                .disabled(state != .affordable)
                .accessibilityLabel("Buy \(name) for \(cost) Perk Coins")
            }
        }
        .padding(12)
        .background(state == .locked ? Color(hex: 0x1A1524) : Color(hex: 0x221B2E), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.gold.opacity(state == .locked ? 0.3 : 0.7), lineWidth: 2))
        .opacity(state == .locked ? 0.75 : 1)
    }
}

private struct PerkRow: View {
    @EnvironmentObject private var game: GameModel
    let perk: Perk

    var body: some View {
        let state = game.perkState(perk)
        let level = game.level(perk)
        HStack(spacing: 10) {
            if state == .locked {
                Image(systemName: "lock.fill").foregroundStyle(Color(hex: 0x8A7FA0)).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(perk.name).font(Theme.body(15, .black))
                    Text("\(level) / \(perk.maxLevel)").font(Theme.body(11, .heavy)).foregroundStyle(Color(hex: 0x9C90B3))
                    if let zone = perk.zoneOnly {
                        Text(zone.uppercased()).font(Theme.body(10, .black)).tracking(1).foregroundStyle(Theme.copper)
                    }
                    if perk.isCapstone {
                        Text("CAPSTONE").font(Theme.body(10, .black)).tracking(1).foregroundStyle(Theme.gold)
                    }
                }
                Text(detail(state: state, level: level))
                    .font(Theme.body(12))
                    .foregroundStyle(Color(hex: 0xC9BEDB))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            switch state {
            case .maxed:
                Text("MAX").font(Theme.body(14, .black)).foregroundStyle(Color(hex: 0x9C90B3)).frame(minWidth: 70)
            case .affordable, .tooExpensive:
                Button {
                    game.buyPerk(perk)
                } label: {
                    Text("\(perk.cost(level: level)) PC")
                        .font(Theme.body(14, .black))
                        .frame(minWidth: 70, minHeight: 44)
                        .background(state == .affordable ? Theme.perk : Color(hex: 0x3A3148), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(state == .affordable ? .white : Color(hex: 0x8A7FA0))
                }
                .buttonStyle(.plain)
                .disabled(state != .affordable)
                .accessibilityLabel("Buy \(perk.name) level \(level + 1) for \(perk.cost(level: level)) Perk Coins")
            case .locked:
                EmptyView()
            }
        }
        .padding(12)
        .background(state == .locked ? Color(hex: 0x1A1524) : Color(hex: 0x221B2E), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(perk.isCapstone ? Theme.gold : Color(hex: 0x4A3E5E), style: StrokeStyle(lineWidth: 2, dash: perk.zoneOnly == nil ? [] : [5, 4]))
        )
        .opacity(state == .locked ? 0.75 : 1)
    }

    private func detail(state: PerkState, level: Int) -> String {
        if state == .locked, let req = perk.requirement {
            var needs = "Needs \(req.perk.name) \(req.level)"
            if let second = perk.secondRequirement { needs += " + \(second.perk.name) \(second.level)" }
            return needs + " · " + perk.summary
        }
        if level == 0 { return perk.summary }
        return "Now: " + perk.effect(level: level)
    }
}

// MARK: - Welcome back

struct OfflineView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var ads: AdCoordinator
    let report: OfflineReport

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "hammer.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.minerLight, Theme.miner)
                        .padding(.top, 24)
                        .accessibilityHidden(true)
                    Text("Welcome back!").font(Theme.display(32))
                    Text("You were away \(Self.duration(report.seconds)). Your miners kept working.")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                    ForEach(report.entries) { entry in
                        OfflineCard(entry: entry)
                    }
                    Text("Each mine counts up to \(Self.duration(game.offlineCapSeconds)). Night Shift perks raise the cap.")
                        .font(Theme.body(12))
                        .foregroundStyle(Color(hex: 0xA8968A))
                        .multilineTextAlignment(.center)
                }
            }
            if game.canWatch(.offlineDouble) {
                Button {
                    ads.watch(.offlineDouble, game: game)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                        Text("Collect ×2")
                    }
                    .font(Theme.body(17, .black))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color(hex: 0x23301F), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0x4C7A3A), lineWidth: 2))
                    .foregroundStyle(Color(hex: 0xD6F2C4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Watch an ad to collect double")
            }
            Button {
                game.claimOffline()
            } label: {
                Text(report.entries.count > 1 ? "Collect all" : "Collect")
                    .font(Theme.body(17, .black))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(game.zone.accent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(game.zone.onAccent)
            }
            .buttonStyle(.plain)
        }
        .adCover(item: ads.simulatedBinding(when: true), ads: ads)
        .padding(20)
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds) / 60
        let h = total / 60, m = total % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }
}

private struct OfflineCard: View {
    @EnvironmentObject private var game: GameModel
    let entry: OfflineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.zone.name).font(Theme.body(15, .black))
                Spacer()
                if entry.seconds > entry.cappedSeconds {
                    Text("CAPPED AT \(OfflineView.duration(entry.cappedSeconds).uppercased())")
                        .font(Theme.body(11, .black)).tracking(1)
                        .foregroundStyle(entry.zone.accent)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(entry.zone.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            HStack(spacing: 10) {
                CurrencyIcon(zone: entry.zone, size: 32)
                Text(NumberText.format(entry.coins, short: game.settings.shortNumbers)).font(Theme.display(34))
                Text(entry.zone.currencyShort).font(Theme.body(13, .heavy)).foregroundStyle(Theme.textMuted)
            }
            .accessibilityElement(children: .combine)
            Text("\(NumberText.decimal(entry.coinsPerSecond)) / s miner rate × \(NumberText.percent(entry.efficiency)) offline × \(OfflineView.clock(entry.cappedSeconds))")
                .font(Theme.body(12))
                .foregroundStyle(Color(hex: 0xA8968A))
        }
        .padding(14)
        .background(entry.zone.cardFill, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(entry.zone.cardEdge, lineWidth: 2))
    }
}
