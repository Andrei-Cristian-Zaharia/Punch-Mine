import SwiftUI

/// The 7-day login track. Opens on its own once a day; the gift button in the zone bar opens it too.
struct DailyView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var ads: AdCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let available = game.dailyAvailable()
        let next = game.nextDailyDay()
        let claimed = game.dailyClaimedThisWeek()
        VStack(spacing: 16) {
            Image(systemName: "gift.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.gold)
                .padding(.top, 24)
                .accessibilityHidden(true)
            Text("Daily Reward").font(Theme.display(32))
            Text(available ? "Day \(next) of 7. Come back tomorrow to keep the streak; miss a day and it starts over."
                           : "Claimed for today. Next reward: day \(next).")
                .font(Theme.body(14)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(DailyReward.track) { reward in
                    let done = reward.day <= claimed
                    let today = available && reward.day == next
                    VStack(spacing: 4) {
                        Text("DAY \(reward.day)").font(Theme.body(10, .black)).tracking(1)
                            .foregroundStyle(today ? Theme.gold : Theme.textFaint)
                        Image(systemName: done ? "checkmark.circle.fill" : (reward.chests.isEmpty ? "gearshape.2.fill" : "shippingbox.fill"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(done ? Theme.buy : (reward.chests.keys.max { $0.order < $1.order }?.color ?? Color(hex: 0xC8D0DC)))
                        Text(reward.text).font(Theme.body(10, .heavy)).multilineTextAlignment(.center)
                            .lineLimit(2).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 86)
                    .padding(4)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(today ? Theme.gold : .clear, lineWidth: 2))
                    .opacity(done ? 0.6 : 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Day \(reward.day): \(reward.text)" + (done ? ", claimed" : today ? ", today" : ""))
                }
            }

            if let reveal = game.dailyReveal {
                Label("Got \(reveal.text)!", systemImage: "sparkles")
                    .font(Theme.body(15, .black)).foregroundStyle(Theme.gold)
            }
            Spacer()
            if available {
                Button {
                    game.claimDaily()
                } label: {
                    Text("Claim day \(next)")
                        .font(Theme.body(17, .black))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.gold, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Color(hex: 0x1A120E))
                }
                .buttonStyle(.plain)
            }
            if !available {
                AdOfferButton(placement: .dailyDouble, title: "Watch an ad to get today's reward again", symbol: "gift.fill")
            }
            Button(available ? "Later" : "Continue") { dismiss() }
                .font(Theme.body(16, .heavy))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(20)
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.text)
        .onDisappear { game.dailyReveal = nil }
        .adCover(item: ads.simulatedBinding(when: true), ads: ads)
    }
}

/// Lifetime totals, from Settings.
struct StatsView: View {
    @EnvironmentObject private var game: GameModel

    var body: some View {
        let s = game.stats
        List {
            Section("Mining") {
                row("Punches", count(s.punches))
                row("Critical hits", count(s.crits))
                row("Blocks broken", count(s.blocksBroken))
                row("Treasure broken", count(s.treasuresBroken))
                row("Areas cleared", count(s.areasCleared))
            }
            Section("Zones") {
                ForEach(ZoneID.allCases.filter(game.isUnlocked)) { zone in
                    let rec = game.record(for: zone)
                    row("\(zone.name): deepest area", "\(rec.bestArea)")
                    row("\(zone.name): \(zone.currencyName) earned", NumberText.format(s.coins[zone.rawValue] ?? 0, short: true))
                    row("\(zone.name): prestiges", "\(rec.prestigeCount)")
                }
                row("Hearts defeated", "\(game.heartsDefeated)")
            }
            Section("Collection") {
                row("Items found", "\(game.items.count) / \(ItemDef.all.count)")
                row("Chests opened", count(s.chestsOpened))
                row("Daily rewards claimed", count(s.dailyClaims))
            }
            Section("Time") {
                row("Time played", Self.duration(s.playSeconds))
            }
        }
        .navigationTitle("Stats")
    }

    private func count(_ n: Int) -> String { NumberText.format(Double(n), short: false) }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s >= 3600 { return "\(s / 3600)h \(s / 60 % 60)m" }
        return "\(s / 60)m \(s % 60)s"
    }
}
