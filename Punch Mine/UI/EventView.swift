import SwiftUI

/// The running seasonal event: its reward track and pass, the boss, the mini-mine and the shop.
struct EventView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var ads: AdCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var tab = Tab.track
    @State private var showMini = false

    enum Tab: String, CaseIterable, Identifiable {
        case track = "Rewards", boss = "Boss", shop = "Shop"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let event = game.activeEvent {
                let state = game.eventProgress
                ScrollView {
                    VStack(spacing: 14) {
                        header(event, state: state)
                        switch tab {
                        case .track:
                            AdOfferButton(placement: .eventRush,
                                          title: "Watch an ad: double \(event.season.currency) for \(Int(AdRules.eventRushSeconds / 60)) min",
                                          symbol: "sparkles", color: Color(hex: event.season.accent))
                            if !state.premium { passCard(event) }
                            track(event, state: state)
                        case .boss:
                            boss(event, state: state)
                        case .shop:
                            miniMineCard(event, state: state)
                            shop(event, state: state)
                        }
                    }
                    .padding(20)
                }
                // Pinned, so the tabs never move under a finger.
                .safeAreaInset(edge: .top, spacing: 0) {
                    Picker("Section", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
                    .background(Theme.ground)
                }
                footer(event)
            } else {
                noEvent
            }
        }
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.text)
        .bossCover(isPresented: Binding(get: { game.bossFight != nil || game.bossResult != nil },
                                        set: { if !$0 { game.bossResult = nil } }))
        .sheet(isPresented: $showMini) { MiniMineView() }
        .adCover(item: ads.simulatedBinding(when: !showMini), ads: ads)
    }

    // MARK: Header

    private func header(_ event: SeasonEvent, state: SeasonState) -> some View {
        let accent = Color(hex: event.season.accent)
        return VStack(spacing: 8) {
            OreArt(material: event.season.ore, seed: 1)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accent, lineWidth: 3))
                .accessibilityHidden(true)
            Text(event.name).font(Theme.display(30)).multilineTextAlignment(.center)
            Text(event.season.tagline).font(Theme.body(14)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
            if event.encore {
                Text("Back between events: a second chance at its set, pet and looks.")
                    .font(Theme.body(13, .heavy)).foregroundStyle(accent).multilineTextAlignment(.center)
            }
            Text("Ends in \(WeeklyHeartView.countdown(event.window.end.timeIntervalSince(game.now())))")
                .font(Theme.body(13, .heavy)).foregroundStyle(Theme.textFaint)
            HStack(spacing: 10) {
                pill(symbol: "chart.bar.fill", value: "\(state.points)", label: "earned", color: accent)
                pill(symbol: event.season.symbol, value: "\(state.wallet)", label: "to spend", color: accent)
            }
        }
    }

    private func pill(symbol: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).font(Theme.display(20)).monospacedDigit()
            Text(label).font(Theme.body(11, .heavy)).foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Theme.card, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    // MARK: Track

    private func passCard(_ event: SeasonEvent) -> some View {
        let golden = game.eventTrack.map { $0.premium.chests[.golden, default: 0] }.reduce(0, +)
        return HStack(spacing: 12) {
            Image(systemName: "crown.fill").font(.system(size: 26)).foregroundStyle(Theme.gold).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("EVENT PASS").font(Theme.body(12, .black)).tracking(1).foregroundStyle(Theme.gold)
                Text("A fist skin, break effect, pet and app icon, \(golden) Golden Chests and more. Plus 50% more \(event.season.currency).")
                    .font(Theme.body(13)).foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 0)
            Button {
                store.buy(.eventPass)
            } label: {
                Text(store.buying == .eventPass ? "…" : store.price(.eventPass))
                    .font(Theme.body(15, .black))
                    .frame(minWidth: 70, minHeight: 40)
                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color(hex: 0x1A120E))
            }
            .buttonStyle(.plain)
            .disabled(!store.canBuy(.eventPass))
            .accessibilityLabel("Buy Event Pass, \(store.price(.eventPass))")
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.gold.opacity(0.6), lineWidth: 2))
    }

    private func track(_ event: SeasonEvent, state: SeasonState) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Break \(event.season.ore.displayName)s in any zone. Deeper areas and Coin Rush pay more.")
                    .font(Theme.body(12)).foregroundStyle(Theme.textFaint)
                Spacer()
            }
            HStack {
                Spacer()
                Text("FREE").font(Theme.body(11, .black)).frame(width: 104)
                Text("PASS").font(Theme.body(11, .black)).foregroundStyle(Theme.gold).frame(width: 104)
            }
            ForEach(game.eventTrack) { step in
                let reached = state.points >= step.points
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(step.index)").font(Theme.display(18))
                        Text("\(step.points)").font(Theme.body(11, .heavy)).monospacedDigit()
                            .foregroundStyle(reached ? Color(hex: event.season.accent) : Theme.textFaint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    RewardCell(reward: step.free, claimed: state.claimed.contains(step.index),
                               canClaim: game.canClaimEventStep(step, premium: false), locked: false) {
                        game.claimEventStep(step, premium: false)
                    }
                    RewardCell(reward: step.premium, claimed: state.premiumClaimed.contains(step.index),
                               canClaim: game.canClaimEventStep(step, premium: true), locked: !state.premium) {
                        game.claimEventStep(step, premium: true)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.card.opacity(reached ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: Boss

    private func boss(_ event: SeasonEvent, state: SeasonState) -> some View {
        let share = state.bossMaxHP > 0 ? min(1, state.bossDamage / state.bossMaxHP) : 0
        let rewards = Seasons.bossRewards(event.season)
        return VStack(spacing: 12) {
            BossArt(season: event.season, share: share, reducedMotion: game.settings.reducedMotion)
                .frame(height: 180)
            Text(event.season.bossName).font(Theme.display(26))
            Text("Its health is set by your punch the first time you attack, so it takes the same effort at any level. Damage stays between attacks.")
                .font(Theme.body(13)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
            ProgressView(value: share).tint(Color(hex: event.season.accent))
            Text(state.bossDefeated ? "Defeated!" : "\(Int(share * 100))% defeated").font(Theme.body(14, .black))
            VStack(spacing: 8) {
                ForEach(Array(rewards.enumerated()), id: \.offset) { i, reward in
                    let done = state.bossPhases.contains(i + 1)
                    HStack(spacing: 10) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? Theme.buy : Theme.textFaint)
                        Text(i == 2 ? "Defeat" : "\(Int(Seasons.bossPhaseShares[i] * 100))%")
                            .font(Theme.body(14, .heavy)).frame(width: 58, alignment: .leading)
                        Text(reward.text).font(Theme.body(12)).foregroundStyle(Theme.textMuted)
                        Spacer(minLength: 0)
                    }
                    .opacity(done ? 0.6 : 1)
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            if !state.bossDefeated {
                let left = game.bossTriesLeft
                if left > 0 {
                    bigButton("Attack! (\(left) left today)", color: Color(hex: event.season.accent)) { game.startBossFight() }
                } else if game.canWatch(.eventBoss) {
                    bigButton("Watch an ad for another attack", color: Theme.gold) { ads.watch(.eventBoss, game: game) }
                } else {
                    Text("No attacks left. \(Seasons.bossFreeTriesPerDay) more tomorrow.")
                        .font(Theme.body(14, .heavy)).foregroundStyle(Theme.textMuted)
                }
            }
        }
    }

    // MARK: Mini-mine and shop

    private func miniMineCard(_ event: SeasonEvent, state: SeasonState) -> some View {
        Button { showMini = true } label: {
            HStack(spacing: 12) {
                OreArt(material: event.season.ore, seed: 7).frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.season.miniMineName).font(Theme.body(17, .black))
                    Text("Level \(state.miniDepth). Dig for \(event.season.currency) to spend; every level cleared also fills the track.")
                        .font(Theme.body(12)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Theme.textFaint)
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: event.season.accent), lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func shop(_ event: SeasonEvent, state: SeasonState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SHOP").font(Theme.body(12, .black)).tracking(1).foregroundStyle(Theme.textFaint)
            ForEach(Seasons.shop) { item in
                HStack(spacing: 10) {
                    RewardIcon(reward: item.reward, size: 40)
                    Text(item.reward.text).font(Theme.body(14, .heavy)).lineLimit(2)
                    Spacer(minLength: 4)
                    Button {
                        game.buy(item)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: event.season.symbol)
                            Text("\(item.price)")
                        }
                        .font(Theme.body(14, .black))
                        .padding(.horizontal, 12).frame(height: 34)
                        .background(game.canBuy(item) ? Theme.buy : Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(game.canBuy(item) ? .white : Theme.textFaint)
                    }
                    .buttonStyle(.plain)
                    .disabled(!game.canBuy(item))
                    .accessibilityLabel("Buy \(item.reward.text) for \(item.price) \(event.season.currency)")
                }
                .padding(8)
                .background(Theme.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: Footer

    private func footer(_ event: SeasonEvent) -> some View {
        let ready = game.readyEventSteps
        return VStack(spacing: 6) {
            if ready > 0 && tab == .track {
                bigButton("Claim all (\(ready))", color: Color(hex: event.season.accent)) { game.claimAllEventSteps() }
            }
            Button("Close") { dismiss() }
                .font(Theme.body(16, .heavy))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func bigButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.body(17, .black))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(color, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(Color(hex: 0x1A120E))
        }
        .buttonStyle(.plain)
    }

    private var noEvent: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar").font(.system(size: 48)).foregroundStyle(Theme.textFaint)
            Text("No event right now").font(Theme.display(26))
            if let next = Seasons.next(after: game.now()) {
                Text("\(next.name) starts in \(WeeklyHeartView.countdown(next.window.start.timeIntervalSince(game.now()))).")
                    .font(Theme.body(15)).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Button("Close") { dismiss() }.font(Theme.body(16, .heavy)).frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(20)
    }
}

/// The picture for a reward: its cosmetic, pet, item, chest or consumable.
struct RewardIcon: View {
    let reward: Reward
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let c = reward.cosmetics.first.flatMap(Cosmetic.find) {
                CosmeticIcon(cosmetic: c, size: size)
            } else if let p = reward.pets.first.flatMap(PetDef.find) {
                PetArt(pet: p, size: size)
            } else if let i = reward.items.first.flatMap(ItemDef.find) {
                ItemIcon(def: i, size: size)
            } else if let tier = reward.chests.keys.max(by: { $0.order < $1.order }) {
                Image(systemName: "shippingbox.fill").font(.system(size: size * 0.55, weight: .bold)).foregroundStyle(tier.color)
            } else if let c = reward.consumables.keys.first {
                Image(systemName: c.symbol).font(.system(size: size * 0.55, weight: .bold)).foregroundStyle(Color(hex: c.color))
            } else if reward.perkCoins > 0 {
                PerkCoinIcon(size: size * 0.55)
            } else {
                Image(systemName: "gearshape.2.fill").font(.system(size: size * 0.55, weight: .bold)).foregroundStyle(Color(hex: 0xC8D0DC))
            }
        }
        .frame(width: size, height: size)
    }
}

/// One reward on the track, claimable with a tap.
private struct RewardCell: View {
    let reward: Reward
    let claimed: Bool
    let canClaim: Bool
    let locked: Bool
    let claim: () -> Void

    var body: some View {
        Button(action: claim) {
            VStack(spacing: 2) {
                ZStack(alignment: .bottomTrailing) {
                    RewardIcon(reward: reward, size: 30)
                    if claimed {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(Theme.buy)
                    } else if locked {
                        Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Theme.textFaint)
                    }
                }
                Text(reward.headline)
                    .font(Theme.body(9, .heavy)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
            }
            .frame(width: 104, height: 58)
            .background(canClaim ? Theme.gold.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(canClaim ? Theme.gold : .clear, lineWidth: 2))
            .opacity(claimed ? 0.5 : locked ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!canClaim)
        .accessibilityLabel(reward.text + (claimed ? ", claimed" : canClaim ? ", claim" : locked ? ", needs the Event Pass" : ""))
    }
}

/// The event boss: its event block, huge, with a health bar.
struct BossArt: View {
    let season: SeasonID
    let share: Double
    let reducedMotion: Bool
    var squashKey = 0
    @State private var squash: CGFloat = 1

    var body: some View {
        VStack(spacing: 8) {
            OreArt(material: season.ore, seed: 3)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color(hex: season.accent), lineWidth: 4))
                .shadow(color: Color(hex: season.accent).opacity(0.5), radius: 18)
                .scaleEffect(squash)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.6))
                    Capsule().fill(Color(hex: season.accent)).frame(width: geo.size.width * (1 - share))
                }
            }
            .frame(height: 10)
        }
        .onChange(of: squashKey) { _ in
            guard !reducedMotion else { return }
            squash = 0.94
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { squash = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(season.bossName), \(Int((1 - share) * 100))% health left")
    }
}

/// One 30-second attack on the event boss.
struct BossFightView: View {
    @EnvironmentObject private var game: GameModel
    @State private var pressing = false

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            if game.activeEvent == nil && game.bossFight == nil {
                // The event ended while the result was up: never leave the player on a blank screen.
                VStack(spacing: 14) {
                    Spacer()
                    Text("The event has ended").font(Theme.display(28))
                    Spacer()
                    Button("Done") { game.bossResult = nil }.font(Theme.body(17, .black)).frame(maxWidth: .infinity, minHeight: 54)
                }
                .padding(20)
            } else if let event = game.activeEvent {
                let state = game.eventProgress
                let share = state.bossMaxHP > 0 ? min(1, state.bossDamage / state.bossMaxHP) : 0
                if let f = game.bossFight {
                    VStack(spacing: 14) {
                        HStack {
                            Text(event.season.bossName.uppercased()).font(Theme.body(12, .black)).tracking(1)
                                .foregroundStyle(Color(hex: event.season.accent))
                            Spacer()
                            Text(String(format: "0:%02d", Int(f.timeLeft.rounded(.up)))).font(Theme.display(24)).monospacedDigit()
                        }
                        ProgressView(value: f.timeLeft, total: Seasons.bossFightSeconds).tint(Theme.gold)
                        Text(f.lastHit > 0 ? NumberText.hit(f.lastHit) + (f.lastCrit ? "!" : "") : " ")
                            .font(Theme.display(f.lastCrit ? 32 : 24))
                            .foregroundStyle(f.lastCrit ? Theme.gold : Theme.text)
                            .frame(height: 40)
                            .accessibilityHidden(true)
                        BossArt(season: event.season, share: share, reducedMotion: game.settings.reducedMotion, squashKey: f.punches)
                            .frame(maxWidth: 300)
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { _ in if !pressing { pressing = true; game.punchBoss() } }
                                .onEnded { _ in pressing = false })
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { game.punchBoss() }
                        Text("This attack: \(NumberText.format(f.damage, short: true)) · \(Int(share * 100))% defeated")
                            .font(Theme.body(14, .heavy)).foregroundStyle(Theme.textMuted)
                        Spacer(minLength: 0)
                        Button("Stop") { game.finishBossFightEarly() }.font(Theme.body(14, .heavy)).foregroundStyle(Theme.textFaint)
                    }
                    .padding(20)
                } else if let result = game.bossResult {
                    VStack(spacing: 14) {
                        Spacer()
                        Text(result.defeated ? "DEFEATED!" : "ATTACK OVER").font(Theme.display(40)).foregroundStyle(Theme.gold)
                        Text("\(NumberText.format(result.damage, short: true)) damage · \(Int(share * 100))% defeated")
                            .font(Theme.body(16, .heavy))
                        ForEach(result.phases, id: \.self) { phase in
                            Label(Seasons.bossRewards(result.season)[phase - 1].text, systemImage: "sparkles")
                                .font(Theme.body(14, .black)).foregroundStyle(Theme.gold).multilineTextAlignment(.center)
                        }
                        Spacer()
                        Button("Done") {
                            game.bossResult = nil
                            game.requestBreakAd("event_boss")
                        }
                            .font(Theme.body(17, .black))
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color(hex: event.season.accent), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(Color(hex: 0x1A120E))
                            .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
        }
        .foregroundStyle(Theme.text)
    }
}

/// The event's own little mine: tap blocks, buy a better pick and helpers with the currency it drops.
struct MiniMineView: View {
    @EnvironmentObject private var game: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var pulses: [Int: Int] = [:]
    @State private var openedAt = Date()

    var body: some View {
        if let event = game.activeEvent {
            let state = game.eventProgress
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.season.miniMineName).font(Theme.display(26))
                        Text("Level \(state.miniDepth)").font(Theme.body(14, .heavy)).foregroundStyle(Theme.textMuted)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: event.season.symbol).foregroundStyle(Color(hex: event.season.accent))
                        Text("\(state.wallet)").font(Theme.display(22)).monospacedDigit()
                    }
                }
                GeometryReader { geo in
                    let gap: CGFloat = 8
                    let side = min((geo.size.width - gap * 4) / 5, (geo.size.height - gap * 5) / 6)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: gap), count: 5), spacing: gap) {
                        ForEach(game.miniBlocks) { block in
                            ZStack(alignment: .bottom) {
                                if block.isBroken {
                                    RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x100C09))
                                } else {
                                    OreArt(material: block.material, seed: block.id)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Capsule().fill(Color.black.opacity(0.6)).frame(height: 5).padding(5)
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(Color(hex: event.season.accent))
                                                .frame(width: max(0, (side - 10) * block.hpFraction), height: 5).padding(.leading, 5)
                                        }
                                }
                            }
                            .frame(width: side, height: side)
                            .scaleEffect(pulses[block.id, default: 0] % 2 == 1 ? 0.92 : 1)
                            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: pulses[block.id])
                            .onTapGesture {
                                game.punchMini(block.id)
                                pulses[block.id, default: 0] += 1
                            }
                            .accessibilityLabel(block.isBroken ? "Broken" : "\(block.material.displayName), \(Int(block.hpFraction * 100))% left")
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                upgrade(title: "Pick Lv \(state.miniPick)", detail: "\(NumberText.format(game.miniPickDamage, short: true)) per tap",
                        cost: Seasons.miniPickCost(level: state.miniPick), can: state.wallet >= Seasons.miniPickCost(level: state.miniPick),
                        symbol: event.season.symbol) { game.buyMiniPick() }
                if state.miniHelpers < Seasons.miniHelperMax {
                    upgrade(title: "Helpers \(state.miniHelpers) / \(Seasons.miniHelperMax)", detail: "Dig while this screen is open",
                            cost: Seasons.miniHelperCost(count: state.miniHelpers), can: state.wallet >= Seasons.miniHelperCost(count: state.miniHelpers),
                            symbol: event.season.symbol) { game.buyMiniHelper() }
                }
                Button("Close") { dismiss() }.font(Theme.body(16, .heavy)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(20)
            .background(Theme.ground.ignoresSafeArea())
            .foregroundStyle(Theme.text)
            .onAppear { openedAt = Date() }
            .onDisappear {
                if Date().timeIntervalSince(openedAt) >= BreakAdRules.miniMineSeconds { game.requestBreakAd("mini_mine") }
            }
            .task {
                var last = Date()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(200))
                    let now = Date()
                    game.tickMini(min(0.5, now.timeIntervalSince(last)))
                    last = now
                }
            }
        }
    }

    private func upgrade(title: String, detail: String, cost: Int, can: Bool, symbol: String, buy: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.body(15, .heavy))
                Text(detail).font(Theme.body(12)).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Button(action: buy) {
                HStack(spacing: 4) { Image(systemName: symbol); Text("\(cost)") }
                    .font(Theme.body(14, .black))
                    .padding(.horizontal, 14).frame(height: 38)
                    .background(can ? Theme.buy : Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(can ? .white : Theme.textFaint)
            }
            .buttonStyle(.plain)
            .disabled(!can)
        }
        .padding(10)
        .background(Theme.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension View {
    /// Full-screen on iOS; a sheet on macOS, which has no full-screen cover.
    func bossCover(isPresented: Binding<Bool>) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented) { BossFightView().frame(minWidth: 420, minHeight: 640) }
        #else
        fullScreenCover(isPresented: isPresented) { BossFightView() }
        #endif
    }
}
