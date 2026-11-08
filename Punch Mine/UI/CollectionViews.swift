import SwiftUI

/// Consumables you hold, used with one tap.
struct StashSection: View {
    @EnvironmentObject private var game: GameModel
    var onUse: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdOfferButton(placement: .freeGadget, title: "Watch an ad for a free gadget", symbol: "gift.fill")
            if game.stashCount == 0 {
                Text("Nothing in your stash yet. Boosts and gadgets come from event tracks, the event shop and the event boss.")
                    .font(Theme.body(14)).foregroundStyle(Theme.textMuted)
            }
            ForEach(Consumable.allCases.filter { game.consumableCount($0) > 0 }) { c in
                HStack(spacing: 12) {
                    Image(systemName: c.symbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: c.color))
                        .frame(width: 44, height: 44)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(c.name) ×\(game.consumableCount(c))").font(Theme.body(15, .heavy))
                        Text(c.text).font(Theme.body(12)).foregroundStyle(Theme.textMuted)
                    }
                    Spacer(minLength: 4)
                    Button("Use") {
                        game.use(c)
                        onUse()
                    }
                    .font(Theme.body(14, .black))
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(game.canUse(c) ? Theme.buy : Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(game.canUse(c) ? .white : Theme.textFaint)
                    .buttonStyle(.plain)
                    .disabled(!game.canUse(c))
                    .accessibilityLabel("Use \(c.name)")
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The stash on its own, opened from the mine.
struct StashView: View {
    @EnvironmentObject private var ads: AdCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView { StashSection(onUse: { dismiss() }).padding(16) }
                .background(Theme.ground.ignoresSafeArea())
                .adCover(item: ads.simulatedBinding(when: true), ads: ads)
                .navigationTitle("Stash")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .foregroundStyle(Theme.text)
    }
}

/// Pets: pick the one that follows you.
struct PetsSection: View {
    @EnvironmentObject private var game: GameModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("One pet follows you and adds its bonus. Finding a pet again levels it up (max \(PetDef.maxLevel)).")
                .font(Theme.body(13)).foregroundStyle(Theme.textMuted)
            ForEach(PetDef.all) { pet in
                let level = game.petLevel(pet.id)
                let active = game.activePet == pet.id
                Button {
                    if level > 0 { game.setActivePet(active ? nil : pet.id) }
                } label: {
                    HStack(spacing: 12) {
                        PetArt(pet: pet, size: 48)
                            .frame(width: 56, height: 56)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                            .opacity(level > 0 ? 1 : 0.3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level > 0 ? "\(pet.name) · Lv \(level)" : pet.name).font(Theme.body(15, .heavy))
                            Text(pet.describe(level: max(level, 1))).font(Theme.body(12)).foregroundStyle(Theme.textMuted)
                            if level == 0 {
                                Text(pet.season.map { "From the \($0.name) event" } ?? "From the event shop")
                                    .font(Theme.body(11)).foregroundStyle(Theme.textFaint)
                            }
                        }
                        Spacer(minLength: 4)
                        if active {
                            Text("WITH YOU").font(Theme.body(10, .black)).foregroundStyle(Theme.buy)
                        }
                    }
                    .padding(8)
                    .background(Theme.card.opacity(active ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(active ? Color(hex: pet.color) : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(level == 0)
                .accessibilityLabel("\(pet.name), " + (level > 0 ? "level \(level), \(pet.describe(level: level))" : "not found yet")
                                    + (active ? ", following you" : ""))
            }
        }
    }
}

/// Fist skins, break effects, titles and app icons.
struct StyleSection: View {
    @EnvironmentObject private var game: GameModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = game.equippedCosmetic(.title) {
                Label(title.name, systemImage: "rosette").font(Theme.display(20)).foregroundStyle(Theme.gold)
            }
            ForEach(CosmeticKind.allCases) { kind in
                if kind != .icon || AppIconSwitcher.supported {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(kind.plural.uppercased()).font(Theme.body(12, .black)).tracking(1).foregroundStyle(Theme.textFaint)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                            defaultCard(kind)
                            ForEach(Cosmetic.all.filter { $0.kind == kind }) { c in card(c) }
                        }
                    }
                }
            }
        }
    }

    private func isOn(_ id: String?, _ kind: CosmeticKind) -> Bool { game.equippedCosmetics[kind.rawValue] == id }

    private func defaultCard(_ kind: CosmeticKind) -> some View {
        Button {
            game.equipCosmetic(nil, kind: kind)
            if kind == .icon { AppIconSwitcher.set(nil) }
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 12).fill(Theme.card)
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: kind == .icon ? "app.fill" : "circle.slash").foregroundStyle(Theme.textFaint))
                Text(kind == .title ? "No title" : "Default").font(Theme.body(10, .heavy)).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(selectedBackground(isOn(nil, kind)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Default \(kind.label)" + (isOn(nil, kind) ? ", in use" : ""))
    }

    private func card(_ c: Cosmetic) -> some View {
        let owned = game.owns(cosmetic: c.id)
        let on = isOn(c.id, c.kind)
        return Button {
            guard owned else { return }
            game.equipCosmetic(c.id, kind: c.kind)
            if c.kind == .icon { AppIconSwitcher.set(c.iconName) }
        } label: {
            VStack(spacing: 4) {
                CosmeticIcon(cosmetic: c, owned: owned)
                Text(c.name).font(Theme.body(10, .heavy)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                if !owned {
                    Text(c.source).font(Theme.body(8)).foregroundStyle(Theme.textFaint).multilineTextAlignment(.center).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .padding(4)
            .background(selectedBackground(on))
        }
        .buttonStyle(.plain)
        .disabled(!owned)
        .accessibilityLabel("\(c.name), \(c.kind.label)" + (owned ? (on ? ", in use" : "") : ", locked. \(c.source)"))
    }

    private func selectedBackground(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12).fill(Theme.card.opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? Theme.gold : .clear, lineWidth: 2))
    }
}

/// Turn three duplicate shards into an item one rarity up.
struct ForgeSection: View {
    @EnvironmentObject private var game: GameModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Every duplicate from a chest leaves a shard. Forge \(Forge.shardsNeeded) shards and some Scrap into an item one rarity up, one you don't own yet if there is any.")
                .font(Theme.body(13)).foregroundStyle(Theme.textMuted)
            ForEach([Rarity.common, .rare, .epic]) { r in
                let next = Rarity(rawValue: r.rawValue + 1)!
                HStack(spacing: 12) {
                    Image(systemName: "diamond.fill").font(.system(size: 22)).foregroundStyle(r.color)
                        .frame(width: 44, height: 44).background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(r.name) shards: \(game.shardCount(r)) / \(Forge.shardsNeeded)").font(Theme.body(15, .heavy))
                        Text("→ \(next == .epic ? "an" : "a") \(next.name) item · \(Forge.scrapCost(r)) Scrap").font(Theme.body(12)).foregroundStyle(next.color)
                    }
                    Spacer(minLength: 4)
                    Button("Forge") { game.forge(r) }
                        .font(Theme.body(14, .black))
                        .padding(.horizontal, 14).frame(height: 36)
                        .background(game.canForge(r) ? Theme.buy : Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(game.canForge(r) ? .white : Theme.textFaint)
                        .buttonStyle(.plain)
                        .disabled(!game.canForge(r))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Running consumable timers, floating over the top of the mine.
struct BoostPills: View {
    @EnvironmentObject private var game: GameModel

    var body: some View {
        let pills: [(Consumable, Double)] = [(.snowball, game.snowballRemaining), (.goldenPick, game.goldenRemaining),
                                            (.timeBell, game.bellRemaining), (.eventRush, game.eventRushRemaining)]
            .filter { $0.1 > 0 }
        HStack(spacing: 6) {
            ForEach(pills, id: \.0) { c, left in
                HStack(spacing: 4) {
                    Image(systemName: c.symbol)
                    Text(left >= 60 ? "\(Int(left / 60))m" : "\(Int(left.rounded(.up)))s").monospacedDigit()
                }
                .font(Theme.body(11, .black))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.black.opacity(0.75), in: Capsule())
                .foregroundStyle(Color(hex: c.color))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(c.name), \(Int(left.rounded(.up))) seconds left")
            }
            if game.shiftDoubled {
                Image(systemName: Consumable.shiftDoubler.symbol)
                    .font(Theme.body(11, .black))
                    .padding(6)
                    .background(Color.black.opacity(0.75), in: Capsule())
                    .foregroundStyle(Color(hex: Consumable.shiftDoubler.color))
                    .accessibilityLabel("Double Shift ready")
            }
        }
        .allowsHitTesting(false)
    }
}

/// The active pet, bobbing beside the mine.
struct PetBuddy: View {
    @EnvironmentObject private var game: GameModel
    @State private var up = false

    var body: some View {
        if let pet = game.activePetDef {
            PetArt(pet: pet, size: 40)
                .offset(y: up && !game.settings.reducedMotion ? -5 : 3)
                // Scoped to the bob, so the endless animation never catches other layout changes.
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: up)
                .id(pet.id)
                .onAppear { up = true }
                .onDisappear { up = false }
                .allowsHitTesting(false)
                .accessibilityLabel("\(pet.name) is with you")
        }
    }
}

/// An optional rewarded ad offer: icon, title, how many are left today.
struct AdOfferButton: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var ads: AdCoordinator
    let placement: AdPlacement
    let title: String
    var symbol = "play.rectangle.fill"
    var color: Color = Theme.gold

    var body: some View {
        if game.canWatch(placement) {
            Button {
                ads.watch(placement, game: game)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: symbol).font(.system(size: 18, weight: .bold))
                    Text(title).font(Theme.body(14, .black)).multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    HStack(spacing: 4) {
                        Image(systemName: "play.rectangle.fill")
                        Text("\(game.adsLeftToday(placement)) left")
                    }
                    .font(Theme.body(11, .heavy))
                    .opacity(0.8)
                }
                .padding(.horizontal, 14).frame(minHeight: 48)
                .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color, lineWidth: 2))
                .foregroundStyle(color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Watch an ad: \(title). \(game.adsLeftToday(placement)) left today")
        }
    }
}
