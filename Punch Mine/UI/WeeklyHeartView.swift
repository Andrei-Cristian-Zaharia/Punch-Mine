import SwiftUI

/// The Weekly Heart: this week's twist, tries left, the leaderboard and its prizes.
struct WeeklyHeartView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var ads: AdCoordinator
    @EnvironmentObject private var center: GameCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let now = Date()
        let state = game.weeklyState(now: now)
        let modifier = game.weeklyModifier(now: now)
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    header(state: state, now: now)
                    modifierCard(modifier)
                    powerCard
                    if let last = state.lastRank, !last.seen { lastWeekCard(last) }
                    standings
                    milestones(state)
                    prizes
                }
                .padding(20)
            }
            actions(now: now)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.text)
        .onAppear { center.refresh() }
        .onDisappear { game.markWeeklyRankSeen() }
        .fightCover(isPresented: Binding(get: { game.weeklyFight != nil || game.weeklyResult != nil },
                                         set: { if !$0 { game.weeklyResult = nil } }))
        .adCover(item: ads.simulatedBinding(when: true), ads: ads)
    }

    private func header(state: WeeklyState, now: Date) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "suit.heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(WeeklyHeartArt.crimson)
                .accessibilityHidden(true)
            Text("Weekly Heart").font(Theme.display(32))
            Text("Ends in \(Self.countdown(WeeklyHeart.end(of: state.week).timeIntervalSince(now)))")
                .font(Theme.body(14)).foregroundStyle(Theme.textMuted)
            HStack(spacing: 10) {
                stat("BEST THIS WEEK", state.best > 0 ? WeeklyHeart.scoreText(state.best) : "—")
                stat("TRIES LEFT", "\(game.weeklyAttemptsLeft(now: now))")
            }
            .padding(.top, 4)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(Theme.body(10, .black)).tracking(1).foregroundStyle(Theme.textFaint)
            Text(value).font(Theme.display(22)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func modifierCard(_ modifier: WeeklyModifier) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: modifier.symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("THIS WEEK: \(modifier.name.uppercased())").font(Theme.body(12, .black)).tracking(0.5).foregroundStyle(Theme.gold)
                Text(modifier.text).font(Theme.body(14)).foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    /// Where the numbers come from: your strongest zone, its Strength, tool, crits and crew.
    private var powerCard: some View {
        let z = game.weeklyZone
        return VStack(alignment: .leading, spacing: 10) {
            Text("YOUR POWER").font(Theme.body(12, .black)).tracking(1).foregroundStyle(Theme.textFaint)
            Text("From \(z.name), your strongest zone. Upgrade there to hit harder here.")
                .font(Theme.body(13)).foregroundStyle(Theme.textMuted)
            HStack(spacing: 8) {
                powerStat("PUNCH", NumberText.format(game.weeklyPunch, short: true),
                          "Strength Lv \(game.weeklyStrengthLevel) × \(game.weeklyTool.name)")
                powerStat("CRITS", "\(Int((game.weeklyCritChance * 100).rounded()))%",
                          "hit ×\(NumberText.decimal(game.weeklyCritMultiplier, digits: 1))")
                powerStat("CREW", NumberText.format(game.weeklyCrewDPS, short: true),
                          game.weeklyCrewCapped ? "a second (max \(Int(WeeklyHeart.crewCapPunchesPerSecond)) punches)" : "damage per second")
            }
            Text("Scoring: break as many Heart tiers as you can in \(Int(WeeklyHeart.fightSeconds)) s. Each tier has \(Int(((WeeklyHeart.tierGrowth - 1) * 100).rounded()))% more health than the last, and leftover damage carries on. 12.47 means 12 tiers and 47% of the next. Tapping fast matters: your crew helps, but only up to \(Int(WeeklyHeart.crewCapPunchesPerSecond)) of your punches a second.")
                .font(Theme.body(12)).foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func powerStat(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(Theme.body(10, .black)).tracking(1).foregroundStyle(Theme.textFaint)
            Text(value).font(Theme.display(20)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(detail).font(Theme.body(10, .heavy)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 74)
        .padding(.horizontal, 4)
        .background(Theme.ground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private func lastWeekCard(_ last: WeeklyRankResult) -> some View {
        VStack(spacing: 4) {
            Text("LAST WEEK").font(Theme.body(11, .black)).tracking(1).foregroundStyle(Theme.textFaint)
            Text("#\(last.rank) of \(last.total) · \(last.band)").font(Theme.display(22)).foregroundStyle(Theme.gold)
            Text("Added: \(last.reward.text)").font(Theme.body(13)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.gold, lineWidth: 2))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var standings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LEADERBOARD").font(Theme.body(12, .black)).tracking(1).foregroundStyle(Theme.textFaint)
            if center.isAuthenticated {
                if center.top.isEmpty {
                    Text("No scores yet this week. Be the first!").font(Theme.body(14)).foregroundStyle(Theme.textMuted)
                }
                ForEach(center.top) { entry in row(entry) }
                if let me = center.me, me.rank > 3 {
                    Divider().overlay(Theme.line)
                    row(me)
                    Text(WeeklyHeart.band(rank: me.rank, total: center.players).name + " right now · \(center.players) players")
                        .font(Theme.body(12)).foregroundStyle(Theme.textFaint)
                }
                Button("Full leaderboard") { center.showLeaderboard() }
                    .font(Theme.body(14, .heavy))
                    .foregroundStyle(Theme.crystal)
            } else {
                Text("Sign in to Game Center to compete. The top 3 each week win big, and everyone ranked gets a prize.")
                    .font(Theme.body(14)).foregroundStyle(Theme.textMuted)
                if center.canSignIn {
                    Button("Sign in to Game Center") { center.signIn() }
                        .font(Theme.body(14, .heavy))
                        .foregroundStyle(Theme.crystal)
                } else {
                    Text("Sign in from the Settings app under Game Center.").font(Theme.body(12)).foregroundStyle(Theme.textFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ entry: GameCenter.Entry) -> some View {
        HStack(spacing: 10) {
            Group {
                if entry.rank <= 3 {
                    Image(systemName: "medal.fill").foregroundStyle(Self.medal(entry.rank))
                } else {
                    Text("#\(entry.rank)").font(Theme.body(13, .black)).foregroundStyle(Theme.textMuted)
                }
            }
            .frame(width: 40)
            Text(entry.isMe ? "You" : entry.name).font(Theme.body(15, entry.isMe ? .black : .heavy)).lineLimit(1)
            Spacer()
            Text(WeeklyHeart.scoreText(entry.score)).font(Theme.body(15, .black)).monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(entry.rank), \(entry.isMe ? "you" : entry.name), \(WeeklyHeart.scoreText(entry.score)) tiers")
    }

    private func milestones(_ state: WeeklyState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK'S GOALS").font(Theme.body(12, .black)).tracking(1).foregroundStyle(Theme.textFaint)
            ForEach(WeeklyHeart.milestones) { m in
                let done = state.milestones.contains(m.tiers)
                HStack(spacing: 10) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done ? Theme.buy : Theme.textFaint)
                    Text("\(m.tiers) tiers").font(Theme.body(14, .heavy)).frame(width: 70, alignment: .leading)
                    Text(m.reward.text).font(Theme.body(13)).foregroundStyle(Theme.textMuted).lineLimit(2)
                    Spacer(minLength: 0)
                }
                .opacity(done ? 0.6 : 1)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var prizes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEEKLY PRIZES").font(Theme.body(12, .black)).tracking(1).foregroundStyle(Theme.textFaint)
            ForEach(Array(WeeklyHeart.rankBands.enumerated()), id: \.offset) { index, band in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: index < 3 ? "medal.fill" : "rosette")
                        .foregroundStyle(index < 3 ? Self.medal(index + 1) : Theme.textMuted)
                        .frame(width: 20)
                    Text(band.name).font(Theme.body(14, .heavy)).frame(width: 82, alignment: .leading)
                    Text(band.reward.text).font(Theme.body(13)).foregroundStyle(Theme.textMuted)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
            Text("Paid the next time you open the game after the week ends (Monday 00:00 UTC).")
                .font(Theme.body(12)).foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private func actions(now: Date) -> some View {
        let left = game.weeklyAttemptsLeft(now: now)
        VStack(spacing: 6) {
            if left > 0 {
                bigButton("Fight! (\(left) \(left == 1 ? "try" : "tries") left)", color: WeeklyHeartArt.crimson) {
                    game.startWeeklyFight()
                }
            } else if game.canWatch(.weeklyHeart) {
                bigButton("Watch an ad for another try", color: Theme.gold, dark: true) {
                    ads.watch(.weeklyHeart, game: game)
                }
            } else {
                Text("Out of tries. \(WeeklyHeart.freeAttemptsPerDay) more tomorrow.")
                    .font(Theme.body(15, .heavy)).foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            Button("Close") { dismiss() }
                .font(Theme.body(16, .heavy))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func bigButton(_ title: String, color: Color, dark: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.body(17, .black))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(color, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(dark ? Color(hex: 0x1A120E) : .white)
        }
        .buttonStyle(.plain)
    }

    static func medal(_ rank: Int) -> Color {
        switch rank {
        case 1: Theme.gold
        case 2: Color(hex: 0xC8D0DC)
        default: Color(hex: 0xD08A4E)
        }
    }

    static func countdown(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        let d = s / 86_400, h = s % 86_400 / 3_600, m = s % 3_600 / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

/// The fight itself: tap the Heart, break tiers until time runs out.
struct WeeklyFightView: View {
    @EnvironmentObject private var game: GameModel
    @State private var pressing = false
    @State private var pops: [HitPop] = []
    @State private var tierFlash = 0

    struct HitPop: Identifiable {
        let id: Int
        let text: String
        let crit: Bool
        let x: CGFloat
        let y: CGFloat
    }

    var body: some View {
        let palette = HeartView.palette(game.weeklyZone)
        ZStack {
            RadialGradient(colors: [Color(hex: palette.gradient[1]).opacity(0.45), Theme.ground], center: .center,
                           startRadius: 20, endRadius: 520)
                .ignoresSafeArea()
            if let fight = game.weeklyFight {
                fightBody(fight, palette: palette)
            } else if let result = game.weeklyResult {
                resultBody(result)
            }
        }
        .foregroundStyle(Theme.text)
    }

    private func fightBody(_ f: WeeklyFight, palette: (gradient: [UInt32], edge: UInt32, core: UInt32)) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                Label(f.modifier.name, systemImage: f.modifier.symbol)
                    .font(Theme.body(13, .black)).foregroundStyle(Theme.gold)
                Spacer()
                TimeRing(left: f.timeLeft, total: WeeklyHeart.fightSeconds)
            }
            VStack(spacing: 0) {
                Text("TIER").font(Theme.body(12, .black)).tracking(3).foregroundStyle(Theme.textFaint)
                tierNumber(f.tier)
            }
            ZStack {
                WeeklyHeartArt(fight: f, palette: palette, reducedMotion: game.settings.reducedMotion)
                    .frame(maxWidth: 300, maxHeight: 300)
                ForEach(pops) { pop in
                    HitPopView(pop: pop, reducedMotion: game.settings.reducedMotion)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressing else { return }
                        pressing = true
                        game.punchWeekly()
                    }
                    .onEnded { _ in pressing = false }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Weekly Heart, tier \(f.tier), \(Int(f.progress * 100))% broken" + (f.faded ? ", faded out of reach" : ""))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { game.punchWeekly() }
            HStack(spacing: 8) {
                liveStat("SCORE", WeeklyHeart.scoreText(f.score))
                liveStat("DAMAGE", NumberText.format(f.damage, short: true))
                liveStat("PUNCH", NumberText.format(game.weeklyPunch * game.weeklyArmourFactor(f.modifier), short: true))
            }
            if game.weeklyCrewDPS > 0 {
                Label("Your crew adds \(NumberText.format(game.weeklyCrewDPS * game.weeklyArmourFactor(f.modifier), short: true)) a second",
                      systemImage: "person.3.fill")
                    .font(Theme.body(12, .heavy)).foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 0)
            Button("Stop and keep score") { game.finishWeeklyFightEarly() }
                .font(Theme.body(14, .heavy)).foregroundStyle(Theme.textFaint)
        }
        .padding(20)
        .onChange(of: f.punches) { _ in
            let text = f.lastHit > 0 ? NumberText.hit(f.lastHit) : "PHASE"
            pops.append(HitPop(id: f.punches, text: text, crit: f.lastCrit, x: Self.popOffset(-110...110), y: Self.popOffset(-40...60)))
            if pops.count > 6 { pops.removeFirst(pops.count - 6) }
        }
        .onChange(of: f.tier) { _ in tierFlash += 1 }
    }

    @ViewBuilder private func tierNumber(_ tier: Int) -> some View {
        #if DEBUG
        if Director.shared.isCapturing {
            // Offline capture: the number pops on every new tier, on the virtual clock.
            DirectorFrame { date in
                let age = Director.shared.seconds(date) - Director.shared.weeklyTierAt
                Text("\(tier)").font(Theme.display(64)).monospacedDigit()
                    .scaleEffect(game.settings.reducedMotion || age > 0.8 ? 1 : CGFloat(1 + 0.15 * exp(-7 * age) * cos(2 * .pi * age / 0.5)))
            }
        } else {
            liveTierNumber(tier)
        }
        #else
        liveTierNumber(tier)
        #endif
    }

    private func liveTierNumber(_ tier: Int) -> some View {
        Text("\(tier)").font(Theme.display(64)).monospacedDigit()
            .scaleEffect(tierFlash % 2 == 1 && !game.settings.reducedMotion ? 1.15 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.4), value: tierFlash)
    }

    /// Where a hit number appears around the Heart (seeded in Director mode, Debug only).
    private static func popOffset(_ range: ClosedRange<CGFloat>) -> CGFloat {
        #if DEBUG
        if Director.shared.isActive { return CGFloat(Director.shared.viewRandom(Double(range.lowerBound)...Double(range.upperBound))) }
        #endif
        return CGFloat.random(in: range)
    }

    private func liveStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(Theme.body(10, .black)).tracking(1).foregroundStyle(Theme.textFaint)
            Text(value).font(Theme.display(20)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func resultBody(_ result: WeeklyResult) -> some View {
        let left = game.weeklyAttemptsLeft()
        let best = game.weekly.best
        return VStack(spacing: 14) {
            Spacer()
            timeTitle
            Text("\(WeeklyHeart.scoreText(result.score)) tiers").font(Theme.display(40)).monospacedDigit()
            Text(result.isBest ? "New best this week!" : "Best this week: \(WeeklyHeart.scoreText(best))")
                .font(Theme.body(17, .heavy)).foregroundStyle(result.isBest ? Theme.gold : Theme.textMuted)
            ForEach(result.milestones) { m in
                Label("\(m.tiers) tiers: \(m.reward.text)", systemImage: "sparkles")
                    .font(Theme.body(14, .black)).foregroundStyle(Theme.gold)
            }
            Spacer()
            if left > 0 {
                Button {
                    game.startWeeklyFight()
                } label: {
                    Text("Fight again (\(left) left today)")
                        .font(Theme.body(17, .black))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(WeeklyHeartArt.crimson, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            Button("Done") {
                game.weeklyResult = nil
                game.requestBreakAd("weekly_heart")
            }
                .font(Theme.body(16, .heavy))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(20)
    }

    @ViewBuilder private var timeTitle: some View {
        #if DEBUG
        if Director.shared.isCapturing {
            // Offline capture: "TIME!" springs in on the virtual clock.
            DirectorFrame { date in
                let age = Director.shared.seconds(date) - (Director.shared.weeklyEndAt ?? Director.shared.seconds(date))
                Text("TIME!").font(Theme.display(44)).foregroundStyle(Theme.gold)
                    .scaleEffect(CGFloat(Director.pop(age, from: 0.4)))
            }
        } else {
            Text("TIME!").font(Theme.display(44)).foregroundStyle(Theme.gold)
        }
        #else
        Text("TIME!").font(Theme.display(44)).foregroundStyle(Theme.gold)
        #endif
    }
}

/// A hit number that floats up and fades.
private struct HitPopView: View {
    let pop: WeeklyFightView.HitPop
    let reducedMotion: Bool
    @State private var risen = false

    var body: some View {
        #if DEBUG
        if Director.shared.isCapturing {
            // Offline capture: the number rises and fades on the virtual clock.
            DirectorFrame { date in
                let born = Director.shared.weeklyPunchTime(pop.id) ?? -100
                let p = min(1, max(0, (Director.shared.seconds(date) - born) / 0.8))
                let eased = 1 - (1 - p) * (1 - p)
                label
                    .offset(x: pop.x, y: pop.y + (reducedMotion ? -20 : -20 - 90 * eased))
                    .opacity(1 - eased)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            live
        }
        #else
        live
        #endif
    }

    private var label: some View {
        Text(pop.text + (pop.crit ? "!" : ""))
            .font(Theme.display(pop.crit ? 34 : 24))
            .foregroundStyle(pop.crit ? Theme.gold : .white)
            .shadow(color: .black.opacity(0.8), radius: 0, x: 0, y: 2)
            .rotationEffect(.degrees(pop.crit ? -8 : 0))
    }

    private var live: some View {
        label
            .offset(x: pop.x, y: pop.y + (risen && !reducedMotion ? -110 : -20))
            .opacity(risen ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.8)) { risen = true } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Seconds left, as a ring that drains.
private struct TimeRing: View {
    let left: Double
    let total: Double

    var body: some View {
        let urgent = left <= 5
        ZStack {
            Circle().stroke(Color.black.opacity(0.4), lineWidth: 6)
            Circle().trim(from: 0, to: left / total)
                .stroke(urgent ? Theme.fever : Theme.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(left.rounded(.up)))").font(Theme.display(20)).monospacedDigit()
                .foregroundStyle(urgent ? Theme.fever : Theme.text)
        }
        .frame(width: 54, height: 54)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(left.rounded(.up))) seconds left")
    }
}

/// The Weekly Heart in your strongest zone's colors, cracking as the tier wears down.
struct WeeklyHeartArt: View {
    static let crimson = Color(hex: 0xE0344B)
    let fight: WeeklyFight
    let palette: (gradient: [UInt32], edge: UInt32, core: UInt32)
    let reducedMotion: Bool
    @State private var squash: CGFloat = 1
    @State private var glow = false

    var body: some View {
        #if DEBUG
        if Director.shared.isCapturing {
            // Offline capture: glow, hit squash and the Phantom fade follow the virtual clock.
            DirectorFrame { date in
                let t = Director.shared.seconds(date)
                let fade = Director.ease(t - Director.shared.weeklyFadeAt, 0.25)
                art(glow: 0.5 - 0.5 * cos(.pi * t / 1.2))
                    .scaleEffect(reducedMotion ? 1 : Director.shared.weeklySquash(at: date))
                    .opacity(fight.faded ? 1 - 0.7 * fade : 0.3 + 0.7 * fade)
            }
        } else {
            live
        }
        #else
        live
        #endif
    }

    private var live: some View {
        art(glow: glow ? 1 : 0)
            .scaleEffect(squash)
            .opacity(fight.faded ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.25), value: fight.faded)
            .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true } }
            .onChange(of: fight.punches) { _ in
                guard !reducedMotion else { return }
                squash = 0.93
                withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) { squash = 1 }
            }
    }

    /// `glow` 0…1: the halo breathes and the core shines brighter.
    private func art(glow: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: palette.edge).opacity(0.55), .clear], center: .center, startRadius: 30, endRadius: 170))
                .scaleEffect(reducedMotion ? 0.95 : 0.95 + 0.13 * glow)
            RoundedRectangle(cornerRadius: 32)
                .fill(RadialGradient(colors: palette.gradient.map { Color(hex: $0) }, center: .center, startRadius: 6, endRadius: 190))
                .padding(18)
            RoundedRectangle(cornerRadius: 32).strokeBorder(Color(hex: palette.edge), lineWidth: 5).padding(18)
            Image(systemName: "suit.heart.fill")
                .resizable().scaledToFit()
                .foregroundStyle(Color(hex: palette.core).opacity(0.92))
                .shadow(color: Color(hex: palette.edge), radius: 6 + 10 * glow)
                .padding(78)
            Canvas { context, size in
                // Cracks grow with the damage to this tier.
                let crack = fight.progress
                guard crack > 0.05 else { return }
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                var rng = Noise(seed: UInt64(fight.tier) &* 7_919)
                for k in 0..<Int(2 + crack * 6) {
                    var p = Path(); p.move(to: c)
                    var pt = c
                    let a = Double(k) * 1.1 + rng.next()
                    for step in 1...4 {
                        let len = Double(size.width) * 0.09 * crack
                        pt = CGPoint(x: pt.x + CGFloat(cos(a + rng.next() * 0.6) * len), y: pt.y + CGFloat(sin(a + rng.next() * 0.6) * len))
                        p.addLine(to: pt)
                        _ = step
                    }
                    context.stroke(p, with: .color(Color(hex: 0x1A120E).opacity(0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
            VStack {
                Spacer()
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.6))
                            Capsule().fill(Color(hex: palette.edge)).frame(width: geo.size.width * (1 - fight.progress))
                        }
                    }
                    .frame(height: 12)
                    Text("\(NumberText.format(fight.hp)) / \(NumberText.format(fight.maxHP))")
                        .font(Theme.body(12, .black)).monospacedDigit()
                }
                .padding(.horizontal, 36).padding(.bottom, 30)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private extension View {
    /// Full-screen on iOS; a sheet on macOS, which has no full-screen cover.
    func fightCover(isPresented: Binding<Bool>) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented) { WeeklyFightView().frame(minWidth: 420, minHeight: 640) }
        #else
        fullScreenCover(isPresented: isPresented) { WeeklyFightView() }
        #endif
    }
}
