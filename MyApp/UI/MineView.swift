import SwiftUI

struct MineView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var ads: AdCoordinator
    @State private var showSettings = false
    @State private var showPerks = false
    @State private var showPrestige = false
    @State private var showZones = false
    @State private var showPlaytest = false
    @State private var drawer = DrawerState.collapsed
    @State private var showOreGallery = false
    @State private var showItems = false
    @State private var showItemArt = false
    @State private var showDaily = false
    @State private var showStore = false
    /// Day the daily reward last opened on its own, so it pops up at most once a day.
    @AppStorage("dailyPromptDay") private var dailyPromptDay = ""
    @Environment(\.scenePhase) private var scenePhase
    /// Remembers whether the player prefers the drawer minimized or collapsed.
    @AppStorage("drawerMinimized") private var prefersMinimized = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showSettings: $showSettings, showPerks: $showPerks, showStore: $showStore)
            ZoneStrip(showZones: $showZones, showItems: $showItems, showDaily: $showDaily)
            ShakeHost { MineGrid() }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxHeight: .infinity)
                // Floats over the grid so a tip never changes the layout.
                .overlay(alignment: .bottom) { TipCard().padding(.horizontal, 12).padding(.bottom, 6) }
            StatusRow(showPrestige: $showPrestige)
                .frame(height: 36)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            // Space for the collapsed drawer. Expanding slides the drawer up over the grid,
            // so the grid never changes size.
            Color.clear.frame(height: UpgradeDrawer.reservedHeight(drawer))
        }
        .overlay {
            if drawer == .expanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { setDrawer(.collapsed) }
                    .accessibilityLabel("Collapse upgrades")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            UpgradeDrawer(state: Binding(get: { drawer }, set: { setDrawer($0) }))
        }
        .background(game.zone.ground)
        .foregroundStyle(Theme.text)
        .overlay(alignment: .top) { ToastView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showZones) { ZonesView() }
        .sheet(isPresented: $showItems) { ItemsView() }
        .sheet(isPresented: $showDaily) { DailyView() }
        .sheet(isPresented: $showStore) { StoreView() }
        .sheet(isPresented: $showPlaytest) { NavigationStack { PlaytestView() } }
        .sheet(item: $game.zoneIntro) { zone in ZoneIntroView(zone: zone) }
        .sheet(item: $game.conquest) { event in ConquestView(event: event) }
        #if DEBUG
        .sheet(isPresented: $showOreGallery) { OreGalleryView() }
        .sheet(isPresented: $showItemArt) { ItemArtGalleryView() }
        #endif
        .sheet(isPresented: $showPerks) { PerksView() }
        .sheet(isPresented: $showPrestige) { PrestigeView() }
        .sheet(item: $game.offlineReport) { report in
            OfflineView(report: report)
                .interactiveDismissDisabled()
        }
        .onChange(of: game.punchCount) { _ in
            Haptics.punch(game.settings.vibration)
        }
        .onChange(of: game.zone) { _ in if drawer == .expanded { setDrawer(.collapsed) } }
        .onChange(of: game.offlineReport == nil) { _ in offerDaily() }
        .onChange(of: game.breakAdRequest) { _ in ads.showBreak(game: game) }
        .onChange(of: scenePhase) { phase in if phase == .active { offerDaily() } }
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(1))
                offerDaily()
            }
            drawer = prefersMinimized ? .minimized : .collapsed
            #if DEBUG
            // Screenshot helpers: launch with `-debugScreen perks`, `prestige`, `zones`, `intro`, `playtest`,
            // `drawer`, `minimized` or `autopunch`.
            switch UserDefaults.standard.string(forKey: "debugScreen") {
            case "perks", "ascension": showPerks = true
            case "prestige": showPrestige = true
            case "zones": showZones = true
            case "intro": game.zoneIntro = game.zone
            case "playtest": showPlaytest = true
            case "drawer": drawer = .expanded
            case "minimized": drawer = .minimized
            case "ores": showOreGallery = true
            case "armed": game.useGadget(.dynamite)
            case "items", "itemdetail": showItems = true
            case "daily": showDaily = true
            case "store": showStore = true
            case "storebuy":
                showStore = true
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    store.buy(.starterPack)
                }
            case "stats", "settings": showSettings = true
            case "itemart", "itemart2": showItemArt = true
            case "reveal":
                showItems = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    game.openChest(.golden)
                }
            case "autopunch":
                // Punches on its own so effects can be checked without touch input.
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    for n in 0..<400 {
                        let open = game.run.blocks.filter { !$0.isBroken }.map(\.id)
                        if let target = open.min(by: { game.run.blocks[$0].hp < game.run.blocks[$1].hp }) { game.punch(target) }
                        if n == 40 { game.useGadget(.dynamite); game.tap(12) }
                        try? await Task.sleep(for: .milliseconds(90))
                    }
                }
            case "conquest":
                game.conquest = ConquestEvent(zone: game.zone, area: 100, isCrown: true, perkCoins: Conquest.crownPerkCoins,
                                              coinMultiplier: Conquest.coinMultiplier(crowns: 1, hearts: 1))
            case "break":
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    ads.debugShowBreak(game: game)
                }
            case "ad":
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    ads.watch(.coinRush, game: game)
                }
            default: break
            }
            #endif
        }
    }

    /// Opens the daily reward once a day, when nothing else is on screen.
    private func offerDaily() {
        let today = Daily.dayKey(Date())
        guard game.dailyAvailable(), dailyPromptDay != today, game.offlineReport == nil, game.zoneIntro == nil,
              game.conquest == nil, !showSettings, !showZones, !showItems, !showStore, !showPerks, !showPrestige, !showPlaytest,
              UserDefaults.standard.string(forKey: "debugScreen") == nil else { return }
        dailyPromptDay = today
        showDaily = true
    }

    private func setDrawer(_ state: DrawerState) {
        guard state != drawer else { return }
        if state != .expanded { prefersMinimized = state == .minimized }
        if game.settings.reducedMotion {
            drawer = state
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { drawer = state }
        }
    }
}

private struct TopBar: View {
    @EnvironmentObject private var game: GameModel
    @Binding var showSettings: Bool
    @Binding var showPerks: Bool
    @Binding var showStore: Bool

    var body: some View {
        HStack(spacing: 10) {
            CurrencyIcon(zone: game.zone, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(NumberText.format(game.run.coins, short: game.settings.shortNumbers))
                    .font(Theme.display(28))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(game.zone.currencyShort.uppercased())
                    .font(Theme.body(11, .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                    .fixedSize()
            }
            .layoutPriority(1)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            if game.totalPrestiges > 0 || game.perkCoins > 0 || game.canPrestige {
                Button {
                    showPerks = true
                } label: {
                    HStack(spacing: 6) {
                        PerkCoinIcon(size: 20)
                        Text("\(game.perkCoins)").font(Theme.body(16, .black))
                    }
                    .padding(.leading, 8).padding(.trailing, 12)
                    .frame(height: 44)
                    .background(Theme.perkPanel, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.perk, lineWidth: 2))
                    .foregroundStyle(Theme.text)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel("Perks, \(game.perkCoins) Perk Coins")
            }
            if game.adsAvailable {
                CoinRushButton()
            }
            Button {
                showStore = true
            } label: {
                Image(systemName: "cart.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: 0x23301F), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: 0x4C7A3A), lineWidth: 2))
                    .foregroundStyle(Color(hex: 0x9FE08F))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shop")
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Theme.textMuted)
            }
            .accessibilityLabel("Settings")
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct ZoneStrip: View {
    @EnvironmentObject private var game: GameModel
    @Binding var showZones: Bool
    @Binding var showItems: Bool
    @Binding var showDaily: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    showZones = true
                } label: {
                    HStack(spacing: 6) {
                        Text(game.zone.name).lineLimit(1).minimumScaleFactor(0.75)
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    }
                    .font(Theme.body(14, .heavy))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line, lineWidth: 2))
                    .overlay(alignment: .topTrailing) {
                        if game.unlockedZones.count == 1 && ZoneID.allCases.contains(where: game.canUnlock) {
                            Circle().fill(Theme.crystal).frame(width: 10, height: 10).offset(x: 3, y: -3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(game.zone.name). Switch zone")
                if game.chestCount > 0 || !game.items.isEmpty {
                    Button {
                        showItems = true
                    } label: {
                        Image(systemName: Symbols.backpack)
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 40, height: 36)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line, lineWidth: 2))
                            .foregroundStyle(Theme.gold)
                            .overlay(alignment: .topTrailing) {
                                if game.chestCount > 0 {
                                    Text("\(game.chestCount)")
                                        .font(Theme.body(10, .black))
                                        .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                                        .background(Theme.fever, in: Capsule())
                                        .foregroundStyle(.white)
                                        .offset(x: 6, y: -6)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Items, \(game.chestCount) chests to open")
                }
                if game.dailyUnlocked {
                    let ready = game.dailyAvailable()
                    Button {
                        showDaily = true
                    } label: {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 40, height: 36)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line, lineWidth: 2))
                            .foregroundStyle(ready ? Theme.gold : Theme.textFaint)
                            .overlay(alignment: .topTrailing) {
                                if ready { Circle().fill(Theme.fever).frame(width: 10, height: 10).offset(x: 3, y: -3) }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ready ? "Daily reward ready" : "Daily reward, claimed today")
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if game.isEndless {
                        Image(systemName: "crown.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.gold)
                    }
                    Text("Area \(game.run.area)").font(Theme.display(20))
                    Text(game.isEndless ? "Endless" : "/ \(game.zone.maxArea)")
                        .font(Theme.display(15)).foregroundStyle(Theme.textFaint)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(game.isEndless ? "Area \(game.run.area), Endless Depths"
                                                   : "Area \(game.run.area) of \(game.zone.maxArea)")
            }
            ProgressView(value: Double(Config.blocksPerArea - game.blocksLeft), total: Double(Config.blocksPerArea))
                .tint(game.zone.accent)
                .accessibilityLabel("\(game.blocksLeft) blocks left")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// The 5 × 6 grid. One gesture covers the whole grid so a held finger can slide between blocks.
private struct MineGrid: View {
    @EnvironmentObject private var game: GameModel
    @State private var pressing = false

    private let gap: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let side = floor(min((geo.size.width - gap * CGFloat(Config.columns - 1)) / CGFloat(Config.columns),
                                 (geo.size.height - gap * CGFloat(Config.rows - 1)) / CGFloat(Config.rows)))
            let gridW = side * CGFloat(Config.columns) + gap * CGFloat(Config.columns - 1)
            let gridH = side * CGFloat(Config.rows) + gap * CGFloat(Config.rows - 1)

            ZStack(alignment: .topLeading) {
                ForEach(game.run.blocks) { block in
                    BlockView(block: block,
                              pulse: game.hitPulses[block.id, default: 0],
                              reducedMotion: game.settings.reducedMotion,
                              collapsing: game.run.treasureCollapse != nil,
                              ventCharge: game.ventCharge,
                              showHealth: game.zone == .magma)
                        .frame(width: side, height: side)
                        .offset(origin(block.id, side))
                        .accessibilityElement()
                        .accessibilityLabel(accessibilityLabel(block))
                        .accessibilityAddTraits(block.isBroken ? [] : .isButton)
                        .accessibilityAction { game.tap(block.id) }
                        .accessibilityHidden(block.material == .heartPart)
                }

                if let heart = game.heartBlock, !heart.isBroken {
                    HeartView(block: heart, zone: game.zone, rank: Conquest.heartRank(game.run.area),
                              pulse: game.hitPulses[Conquest.heartIndex, default: 0],
                              reducedMotion: game.settings.reducedMotion)
                        .frame(width: side * 3 + gap * 2, height: side * 3 + gap * 2)
                        .offset(origin(Conquest.heartCells[0], side))
                        .allowsHitTesting(false)
                }

                ForEach(Array(Set(game.minerTargets)), id: \.self) { mark in
                    MinerBadge(kind: mark.kind)
                        .offset(origin(mark.index, side))
                        .offset(badgeOffset(mark.kind, side))
                }

                if game.focusStacks > 0, let index = game.focusIndex {
                    Text("FOCUS +\(Int((game.focusMultiplier - 1) * 100 + 0.5))%")
                        .font(Theme.body(10, .black))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.black.opacity(0.75), in: Capsule())
                        .foregroundStyle(Theme.gold)
                        .frame(width: side)
                        .offset(origin(index, side))
                        .offset(y: side - 10)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                DebrisLayer(side: side, gap: gap)
                    .frame(width: gridW, height: gridH)

                if game.zone == .ruins {
                    TideOverlay(charge: game.tideCharge, remaining: game.tideRemaining, reducedMotion: game.settings.reducedMotion)
                        .frame(width: gridW, height: gridH)
                }

                ForEach(game.floaters) { floater in
                    FloaterView(floater: floater, reducedMotion: game.settings.reducedMotion)
                        .frame(width: side)
                        .offset(origin(floater.blockIndex, side))
                }

                if game.punchCount == 0 && game.run.area == 1 {
                    Text("Tap a block to punch it")
                        .font(Theme.body(15, .heavy))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.7), in: Capsule())
                        .frame(width: gridW, height: gridH)
                        .allowsHitTesting(false)
                }

                AreaBannerView(gridSize: CGSize(width: gridW, height: gridH))

                if game.armedGadget == .dynamite {
                    Text("Tap a block to place Dynamite")
                        .font(Theme.body(13, .heavy))
                        .lineLimit(1)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.black.opacity(0.8), in: Capsule())
                        .foregroundStyle(Theme.fever)
                        .frame(width: gridW)
                        .offset(y: -14)
                        .allowsHitTesting(false)
                }

                if let offer = game.treasureOffer {
                    TreasureOfferView(offer: offer)
                        .frame(width: gridW, height: gridH, alignment: .bottom)
                        .padding(.bottom, 8)
                }

                if let collapse = game.run.treasureCollapse {
                    Text("Treasure collapsing in \(Int(collapse.rounded(.up))) s — punch it!")
                        .font(Theme.body(13, .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.black.opacity(0.8), in: Capsule())
                        .foregroundStyle(Theme.gold)
                        .frame(width: gridW)
                        .offset(y: -14)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: gridW, height: gridH, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = blockIndex(at: value.location, side: side)
                        if pressing {
                            game.movePress(to: index)
                        } else {
                            pressing = true
                            game.beginPress(at: index)
                        }
                    }
                    .onEnded { _ in
                        pressing = false
                        game.endPress()
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Each miner type sits on its own corner so a shared target shows every crew.
    private func badgeOffset(_ kind: MinerKind, _ side: CGFloat) -> CGSize {
        switch kind {
        case .digger: CGSize(width: side - 22, height: -8)
        case .driller: CGSize(width: -6, height: -8)
        case .blaster: CGSize(width: side - 22, height: side - 20)
        }
    }

    private func origin(_ index: Int, _ side: CGFloat) -> CGSize {
        CGSize(width: CGFloat(index % Config.columns) * (side + gap),
               height: CGFloat(index / Config.columns) * (side + gap))
    }

    private func blockIndex(at point: CGPoint, side: CGFloat) -> Int? {
        let col = Int(point.x / (side + gap)), row = Int(point.y / (side + gap))
        guard point.x >= 0, point.y >= 0, col < Config.columns, row < Config.rows else { return nil }
        let inCellX = point.x - CGFloat(col) * (side + gap), inCellY = point.y - CGFloat(row) * (side + gap)
        guard inCellX <= side, inCellY <= side else { return nil }
        return row * Config.columns + col
    }

    private func accessibilityLabel(_ block: Block) -> String {
        if block.material == .heart {
            return "\(game.zone.heartName), \(NumberText.percent(block.hpFraction)) health"
        }
        if block.isBroken { return "Empty" }
        return "\(block.material.displayName), \(NumberText.percent(block.hpFraction)) health"
    }
}

private struct MinerBadge: View {
    let kind: MinerKind
    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(kind.color, in: Circle())
            .overlay(Circle().strokeBorder(kind.lightColor, lineWidth: 2))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct AreaBannerView: View {
    @EnvironmentObject private var game: GameModel
    let gridSize: CGSize
    @State private var visible: AreaBanner?

    var body: some View {
        ZStack {
            if let banner = visible {
                VStack(spacing: 4) {
                    Text("Area \(banner.area) cleared!")
                        .font(Theme.display(26))
                    HStack(spacing: 6) {
                        CurrencyIcon(zone: game.zone, size: 18)
                        Text("+" + NumberText.format(banner.bonus, short: game.settings.shortNumbers) + " clear bonus")
                            .font(Theme.body(15, .heavy))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
                .transition(game.settings.reducedMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .frame(width: gridSize.width, height: gridSize.height)
        .allowsHitTesting(false)
        .onChange(of: game.banner) { banner in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { visible = banner }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                if visible == banner { withAnimation(.easeOut(duration: 0.3)) { visible = nil } }
            }
        }
    }
}

/// Sunken Ruins: the waterline creeps up the grid as high tide nears, then floods it. A pill shows the countdown.
private struct TideOverlay: View {
    let charge: Double
    let remaining: Double
    let reducedMotion: Bool

    private var high: Bool { remaining > 0 }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                let level = high ? 1 : 0.12 * charge
                TimelineView(.animation(paused: reducedMotion)) { timeline in
                    Canvas { context, size in
                        let t = reducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                        let top = size.height * (1 - level)
                        var water = Path()
                        water.move(to: CGPoint(x: 0, y: size.height))
                        for x in stride(from: 0.0, through: size.width, by: 6) {
                            let y = top + 4 * sin(x / 28 + t * 2) + 2 * sin(x / 11 - t * 3)
                            water.addLine(to: CGPoint(x: x, y: y))
                        }
                        water.addLine(to: CGPoint(x: size.width, y: size.height))
                        water.closeSubpath()
                        context.fill(water, with: .color(Theme.tide.opacity(high ? 0.22 : 0.3)))
                        var crest = Path()
                        for x in stride(from: 0.0, through: size.width, by: 6) {
                            let y = top + 4 * sin(x / 28 + t * 2) + 2 * sin(x / 11 - t * 3)
                            if x == 0 { crest.move(to: CGPoint(x: x, y: y)) } else { crest.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        context.stroke(crest, with: .color(.white.opacity(high ? 0.35 : 0.5)), lineWidth: 2)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .animation(reducedMotion ? nil : .easeInOut(duration: 1.2), value: high)

            HStack(spacing: 5) {
                Image(systemName: "water.waves")
                Text(high ? "HIGH TIDE ×\(NumberText.decimal(Tide.rewardFactor)) · \(Int(remaining.rounded(.up))) s"
                          : "Tide in \(Int((Tide.interval * (1 - charge)).rounded(.up))) s")
            }
            .font(Theme.body(11, .black))
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(high ? Theme.tide : Color.black.opacity(0.6), in: Capsule())
            .foregroundStyle(high ? Color(hex: 0x061E30) : Theme.tide)
            .offset(y: -12)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(high ? "High tide, \(Int(remaining.rounded(.up))) seconds left. Blocks pay more, hits are weaker."
                                 : "High tide in \(Int((Tide.interval * (1 - charge)).rounded(.up))) seconds")
    }
}

private struct StatusRow: View {
    @EnvironmentObject private var game: GameModel
    @Binding var showPrestige: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(game.feverActive ? "FEVER ×2" : "FEVER")
                        .foregroundStyle(Theme.fever)
                    Spacer(minLength: 4)
                    Text(game.feverActive ? "\(Int(game.feverRemaining.rounded(.up))) s"
                                          : "\(game.feverCharge) / \(Config.feverPunches)")
                        .foregroundStyle(Theme.textMuted)
                }
                .font(Theme.body(11, .black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                ProgressView(value: game.feverActive ? game.feverRemaining / game.feverDuration
                                                     : Double(game.feverCharge) / Double(Config.feverPunches))
                    .tint(Theme.fever)
            }
            .accessibilityElement(children: .combine)

            if game.canPrestige {
                Button {
                    showPrestige = true
                } label: {
                    HStack(spacing: 5) {
                        PerkCoinIcon(size: 13)
                        Text("Prestige +\(game.prestigeReward)").lineLimit(1)
                    }
                    .font(Theme.body(12, .heavy))
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Theme.perkPanel, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.perk, lineWidth: 2))
                    .foregroundStyle(Color(hex: 0xE6DAFF))
                }
                .buttonStyle(.plain)
                .fixedSize()
            }

            ForEach(Gadget.allCases.filter(game.ownsGadget)) { gadget in
                GadgetButton(gadget: gadget)
            }
        }
    }
}

/// Short message at the top, e.g. background earnings collected when entering a zone.
private struct ToastView: View {
    @EnvironmentObject private var game: GameModel
    @State private var visible: Toast?

    var body: some View {
        ZStack {
            if let toast = visible {
                Text(toast.text)
                    .font(Theme.body(14, .heavy))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.85), in: Capsule())
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 60)
        .allowsHitTesting(false)
        .onChange(of: game.toast) { toast in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { visible = toast }
            Task {
                try? await Task.sleep(for: .seconds(3))
                if visible == toast { withAnimation(.easeOut(duration: 0.3)) { visible = nil } }
            }
        }
    }
}

/// Top-bar Coin Rush: watch an ad for ×2 zone coins for 10 minutes of play. Shows the time left while active.
private struct CoinRushButton: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var ads: AdCoordinator

    var body: some View {
        let canWatch = game.canWatch(.coinRush)
        Button {
            ads.watch(.coinRush, game: game)
        } label: {
            VStack(spacing: 0) {
                if game.coinRushActive {
                    Text("×2").font(Theme.body(11, .black))
                    Text(Self.clock(game.coinRushRemaining)).font(Theme.body(12, .black)).monospacedDigit()
                } else {
                    Image(systemName: "play.rectangle.fill").font(.system(size: 13, weight: .bold))
                    Text("×2").font(Theme.body(12, .black))
                }
            }
            .lineLimit(1)
            .frame(width: 52, height: 44)
            .background(game.coinRushActive ? Color(hex: 0x23301F) : Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: 0x4C7A3A), lineWidth: game.coinRushActive ? 2 : 0))
            .foregroundStyle(canWatch || game.coinRushActive ? Color(hex: 0xD6F2C4) : Theme.textFaint)
        }
        .buttonStyle(.plain)
        .disabled(!canWatch)
        .accessibilityLabel(game.coinRushActive
            ? "Coin Rush active, \(Int(game.coinRushRemaining / 60)) minutes left. Watch an ad to add 10 minutes."
            : "Watch an ad for double coins for 10 minutes. \(game.adsLeftToday(.coinRush)) left today.")
    }

    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Appears for 4 seconds after a treasure break.
private struct TreasureOfferView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var ads: AdCoordinator
    let offer: TreasureOffer

    var body: some View {
        Button {
            ads.watch(.treasureDouble, game: game)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                Text("Double treasure +\(NumberText.format(offer.coins, short: game.settings.shortNumbers))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(Theme.body(14, .black))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Theme.gold, in: Capsule())
            .foregroundStyle(Color(hex: 0x2A1406))
            .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Watch an ad to double the treasure, plus \(NumberText.format(offer.coins, short: false))")
    }
}

/// A gadget in the status row: tap to use, with a ring showing the cooldown.
private struct GadgetButton: View {
    @EnvironmentObject private var game: GameModel
    let gadget: Gadget

    var body: some View {
        let left = game.cooldownLeft(gadget)
        let armed = game.armedGadget == gadget
        Button {
            game.useGadget(gadget)
        } label: {
            ZStack {
                Circle().fill(armed ? Theme.fever.opacity(0.35) : Theme.card)
                if left > 0 {
                    Circle()
                        .trim(from: 0, to: left / gadget.cooldown)
                        .stroke(Theme.textFaint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(2)
                }
                Image(systemName: gadget.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(left > 0 ? Theme.textFaint : (gadget == .dynamite ? Theme.fever : Theme.gold))
            }
            .frame(width: 36, height: 36)
            .overlay(Circle().strokeBorder(armed ? Theme.fever : Theme.line, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(!armed && !game.canUseGadget(gadget))
        .accessibilityLabel(left > 0 ? "\(gadget.name), ready in \(Int(left.rounded(.up))) seconds"
                                     : (armed ? "\(gadget.name) armed. Tap a block, or tap again to cancel" : gadget.name))
    }
}
