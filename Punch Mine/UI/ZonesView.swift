import SwiftUI

/// Zone select: enter an open mine, see what a locked one needs, and unlock it.
struct ZonesView: View {
    @EnvironmentObject private var game: GameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Each zone is its own mine with its own coins. Progress stays when you leave, and its miners keep working.")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textMuted)
                    ForEach(ZoneID.allCases) { zone in
                        if game.isUnlocked(zone) {
                            OpenZoneCard(zone: zone) { dismiss() }
                        } else {
                            LockedZoneCard(zone: zone) { dismiss() }
                        }
                    }
                    if ZoneID.allCases.allSatisfy(game.isUnlocked) { ComingSoonCard() }
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("Zones")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .foregroundStyle(Theme.text)
    }
}

private struct ZoneBadge: View {
    let zone: ZoneID
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(zone.badgeOre.fill)
            CurrencyIcon(zone: zone, size: 30)
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}

private struct OpenZoneCard: View {
    @EnvironmentObject private var game: GameModel
    let zone: ZoneID
    let onEnter: () -> Void

    var body: some View {
        let run = game.run(for: zone)
        let record = game.record(for: zone)
        let isActive = game.zone == zone
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZoneBadge(zone: zone)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("ZONE \(zone.number)\(isActive ? " · ACTIVE" : "")")
                            .font(Theme.body(11, .black)).tracking(1).foregroundStyle(zone.accent)
                        if zone == .quarry && game.hasCrown {
                            Label("CONQUERED", systemImage: "crown.fill")
                                .font(Theme.body(10, .black))
                                .foregroundStyle(Theme.gold)
                        }
                    }
                    Text(zone.name).font(Theme.display(22))
                    Text("Area \(run?.area ?? 1)\(game.hasCrown(zone) ? "" : " / \(zone.maxArea)") · best \(record.bestArea) · \(minerText(run?.level(.hireMiner) ?? 0))")
                        .font(Theme.body(12)).foregroundStyle(Theme.textMuted)
                    HStack(spacing: 5) {
                        CurrencyIcon(zone: zone, size: 13)
                        Text("\(NumberText.format(run?.coins ?? 0, short: game.settings.shortNumbers)) \(zone.currencyShort)")
                    }
                    .font(Theme.body(12, .heavy))
                }
            }
            Button {
                let switching = !isActive
                game.switchZone(to: zone)
                if switching { game.requestBreakAd("zone_switch") }
                onEnter()
            } label: {
                Text(isActive ? "Back to mining" : "Enter")
                    .font(Theme.body(15, .black))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(zone.accent, in: RoundedRectangle(cornerRadius: 11))
                    .foregroundStyle(zone.onAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(zone.cardFill, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(isActive ? zone.accent : zone.cardEdge, lineWidth: 2))
    }
}

private func minerText(_ count: Int) -> String { count == 1 ? "1 miner" : "\(count) miners" }

private struct LockedZoneCard: View {
    @EnvironmentObject private var game: GameModel
    let zone: ZoneID
    let onUnlock: () -> Void

    var body: some View {
        if let unlock = zone.unlock {
            let costs = game.unlockCosts(zone)
            let areaMet = game.unlockAreaMet(zone)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZoneBadge(zone: zone).opacity(0.7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ZONE \(zone.number) · LOCKED")
                            .font(Theme.body(11, .black)).tracking(1).foregroundStyle(zone.accent)
                        Text(zone.name).font(Theme.display(22))
                        Text("Twist: \(zone.twist.lowercased())").font(Theme.body(12)).foregroundStyle(Theme.textMuted)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: areaMet ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(areaMet ? Color(hex: 0x9FE08F) : Theme.textFaint)
                    Text("Clear \(unlock.previous.name) area \(unlock.clearArea)")
                    Spacer()
                    Text(areaMet ? "Done" : "Best \(game.record(for: unlock.previous).bestCleared)")
                        .foregroundStyle(areaMet ? Color(hex: 0x9FE08F) : Theme.textMuted)
                }
                .font(Theme.body(13, .heavy))
                .accessibilityElement(children: .combine)

                ForEach(costs) { cost in
                    let held = game.run(for: cost.zone)?.coins ?? 0
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            CurrencyIcon(zone: cost.zone, size: 18)
                            Text(cost.zone.currencyName)
                            Spacer()
                            Text("\(NumberText.format(min(held, cost.amount), short: false)) / \(NumberText.format(cost.amount, short: false))")
                        }
                        .font(Theme.body(13, .heavy))
                        ProgressView(value: min(held, cost.amount), total: max(cost.amount, 1))
                            .tint(cost.zone.accent)
                    }
                    .opacity(game.isUnlocked(cost.zone) ? 1 : 0.5)
                    .accessibilityElement(children: .combine)
                }
                if game.level(.surveyor) > 0 {
                    Text("Surveyor takes \(5 * game.level(.surveyor))% off these costs")
                        .font(Theme.body(11)).foregroundStyle(Theme.textMuted)
                }

                Button {
                    game.unlockZone(zone)
                    onUnlock()
                } label: {
                    Text(costs.count == 1
                         ? "Unlock for \(NumberText.format(costs[0].amount, short: false)) \(costs[0].zone.currencyShort)"
                         : "Unlock")
                        .font(Theme.body(15, .black))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(game.canUnlock(zone) ? zone.accent : Theme.cardRaised, in: RoundedRectangle(cornerRadius: 11))
                        .foregroundStyle(game.canUnlock(zone) ? zone.onAccent : Theme.textFaint)
                }
                .buttonStyle(.plain)
                .disabled(!game.canUnlock(zone))
            }
            .padding(14)
            .background(zone.cardFill, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(zone.cardEdge, lineWidth: 2))
        }
    }
}

private struct ComingSoonCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: 0xB07560))
                .frame(width: 56, height: 56)
                .background(Color(hex: 0x2A1C18), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("ZONE \(ZoneID.allCases.count + 1) · COMING SOON").font(Theme.body(11, .black)).tracking(1).foregroundStyle(Color(hex: 0xD98068))
                Text("More mines").font(Theme.display(22)).foregroundStyle(Color(hex: 0xE9D6CF))
            }
            Spacer()
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0x4A2C24), style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
    }
}

/// Shown once, the first time a zone is entered: what its coins are for and what carries over.
struct ZoneIntroView: View {
    @Environment(\.dismiss) private var dismiss
    let zone: ZoneID

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NEW MINE").font(Theme.body(12, .black)).tracking(1.5).foregroundStyle(zone.accent)
            Text(zone.name).font(Theme.display(32))
            row(icon: AnyView(CurrencyIcon(zone: zone, size: 26)),
                text: "\(zone.currencyName) are this mine's money. They buy \(zone.name) upgrades only.")
            row(icon: AnyView(PerkCoinIcon(size: 24)),
                text: "Your perks and Perk Coins carry over. Upgrades, tools and miners start fresh here.")
            row(icon: AnyView(Image(systemName: "sparkles").font(.system(size: 22)).foregroundStyle(zone.accent)),
                text: zone.twist + ". " + zone.tip)
            row(icon: AnyView(Image(systemName: "suit.heart.fill").font(.system(size: 20)).foregroundStyle(Theme.ember)),
                text: "At area \(Conquest.heartArea) the \(zone.heartName) waits. \(zone.heartTwist)")
            row(icon: AnyView(Image(systemName: "arrow.left.arrow.right").font(.system(size: 20)).foregroundStyle(Theme.textMuted)),
                text: "Switch mines any time from the zone button. Mines you leave keep their progress.")
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Start mining")
                    .font(Theme.body(17, .black))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(zone.accent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(zone.onAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(zone.ground.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }

    private func row(icon: AnyView, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon.frame(width: 30)
            Text(text).font(Theme.body(15)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Celebrates a zone's Heart at a new record depth.
struct ConquestView: View {
    @EnvironmentObject private var game: GameModel
    @Environment(\.dismiss) private var dismiss
    let event: ConquestEvent

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 20)
            Image(systemName: event.isCrown ? "crown.fill" : "star.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.gold)
                .shadow(color: Theme.gold.opacity(0.6), radius: 20)
                .accessibilityHidden(true)
            Text(event.isCrown ? event.zone.crownName : "Crown Star")
                .font(Theme.display(36))
            Text(event.isCrown
                 ? "You destroyed the \(event.zone.heartName) at area \(event.area)."
                 : "You destroyed a deeper Heart at area \(event.area).")
                .font(Theme.body(16))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 14) {
                reward(icon: "chart.line.uptrend.xyaxis", color: Color(hex: 0x9FE08F),
                       text: "Coins in every mine now ×\(NumberText.decimal(event.coinMultiplier, digits: 2)) (\(event.isCrown ? "+25%" : "+5%"))")
                reward(icon: "star.fill", color: Theme.perkLight, text: "+\(event.perkCoins) Perk Coins")
                if event.isCrown {
                    reward(icon: "infinity", color: Theme.copper,
                           text: "Endless Depths open: \(event.zone.name) goes on past area 100. A stronger Heart waits every 25 areas.")
                } else {
                    reward(icon: "arrow.down.to.line", color: Theme.copper,
                           text: "The next Heart waits at area \(event.area + Conquest.endlessHeartEvery).")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))

            Text("Rewards come from new record depths only, so each Heart pays once.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Keep digging")
                    .font(Theme.body(17, .black))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color(hex: 0x2A1406))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Theme.ground.ignoresSafeArea())
        // A natural pause: the celebration is over and the player goes back to mining.
        .onDisappear { game.requestBreakAd("heart") }
        .foregroundStyle(Theme.text)
    }

    private func reward(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(color).frame(width: 26)
            Text(text).font(Theme.body(15)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
