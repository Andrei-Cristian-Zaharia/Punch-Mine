import SwiftUI

extension Rarity {
    var color: Color {
        switch self {
        case .common: Color(hex: 0xB8B0A6)
        case .rare: Color(hex: 0x4FA3FF)
        case .epic: Color(hex: 0xB06CFF)
        case .legendary: Color(hex: 0xFFB020)
        }
    }
}

extension ChestTier {
    var color: Color {
        switch self {
        case .wooden: Color(hex: 0xB8763A)
        case .iron: Color(hex: 0xA8B0BC)
        case .golden: Theme.gold
        }
    }
}

/// Item icon on a rarity-colored tile. Locked items show a "?".
struct ItemIcon: View {
    let def: ItemDef
    var owned = true
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(owned ? def.rarity.color.opacity(0.22) : Theme.cardRaised)
            RoundedRectangle(cornerRadius: size * 0.22)
                .strokeBorder(owned ? def.rarity.color : Theme.line, lineWidth: 2)
            if owned {
                ItemArt(itemID: def.id).equatable()
                    .padding(size * 0.12)
            } else {
                Text("?").font(Theme.display(size * 0.42)).foregroundStyle(Theme.textFaint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ItemsView: View {
    @EnvironmentObject private var game: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ItemDef?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    chestSection
                    equippedSection
                    collectionSection
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.2.fill")
                        Text("\(game.scrap) Scrap")
                    }
                    .font(Theme.body(15, .black))
                    .foregroundStyle(Color(hex: 0xC8D0DC))
                    .accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selected) { def in ItemDetailView(def: def) }
            .sheet(item: $game.chestReveal) { reveal in ChestRevealView(reveal: reveal) }
        }
        .foregroundStyle(Theme.text)
    }

    private var chestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("CHESTS", detail: "Treasure blocks, record areas (every 10th) and Hearts drop chests.")
            HStack(spacing: 8) {
                ForEach(ChestTier.allCases) { tier in
                    let count = game.chestCount(tier)
                    VStack(spacing: 6) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(tier.color)
                        Text(tier.name).font(Theme.body(11, .black)).lineLimit(1).minimumScaleFactor(0.7)
                        Button {
                            game.openChest(tier)
                        } label: {
                            Text(count > 0 ? "Open (\(count))" : "None")
                                .font(Theme.body(12, .black))
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(count > 0 ? tier.color : Theme.cardRaised, in: RoundedRectangle(cornerRadius: 9))
                                .foregroundStyle(count > 0 ? Color(hex: 0x1A120E) : Theme.textFaint)
                        }
                        .buttonStyle(.plain)
                        .disabled(count == 0)
                        .accessibilityLabel("Open \(tier.name), \(count) left")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var equippedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("EQUIPPED", detail: "One item per slot. Items work in every mine and survive prestige.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(ItemSlot.allCases) { slot in
                    let item = game.equippedItem(slot)
                    Button {
                        if let item { selected = item }
                    } label: {
                        HStack(spacing: 10) {
                            if let item {
                                ItemIcon(def: item, size: 40)
                            } else {
                                Image(systemName: slot.symbol)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Theme.textFaint)
                                    .frame(width: 40, height: 40)
                                    .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 9))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.name.uppercased()).font(Theme.body(10, .black)).tracking(1).foregroundStyle(Theme.textFaint)
                                Text(item?.name ?? "Empty").font(Theme.body(13, .black)).lineLimit(1).minimumScaleFactor(0.7)
                                    .foregroundStyle(item?.rarity.color ?? Theme.textMuted)
                                if let item {
                                    Text("Lv \(game.itemLevel(item.id))").font(Theme.body(11)).foregroundStyle(Theme.textMuted)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("COLLECTION", detail: "\(game.items.count) / \(ItemDef.all.count) found. Duplicates turn into Scrap for upgrades.")
            ForEach(ItemSlot.allCases) { slot in
                VStack(alignment: .leading, spacing: 6) {
                    Label(slot.name, systemImage: slot.symbol).font(Theme.body(13, .black)).foregroundStyle(Theme.textMuted)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(ItemDef.all.filter { $0.slot == slot }) { def in
                            let owned = game.items[def.id] != nil
                            Button {
                                if owned { selected = def }
                            } label: {
                                VStack(spacing: 4) {
                                    ItemIcon(def: def, owned: owned, size: 46)
                                    Text(owned ? def.name : def.rarity.name)
                                        .font(Theme.body(11, .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                                        .foregroundStyle(owned ? Theme.text : def.rarity.color.opacity(0.7))
                                    Text(owned ? "Lv \(game.itemLevel(def.id))" + (game.equipped[slot.rawValue] == def.id ? " · ON" : "") : " ")
                                        .font(Theme.body(10)).foregroundStyle(Theme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(owned ? "\(def.name), \(def.rarity.name), level \(game.itemLevel(def.id))" : "Undiscovered \(def.rarity.name) \(slot.name)")
                        }
                    }
                }
            }
        }
    }

    private func header(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.body(12, .black)).tracking(1.2).foregroundStyle(Theme.textFaint)
            Text(detail).font(Theme.body(12)).foregroundStyle(Theme.textMuted)
        }
    }
}

struct ItemDetailView: View {
    @EnvironmentObject private var game: GameModel
    @Environment(\.dismiss) private var dismiss
    let def: ItemDef

    var body: some View {
        let level = game.itemLevel(def.id)
        let maxed = level >= def.rarity.maxLevel
        let isEquipped = game.equipped[def.slot.rawValue] == def.id
        VStack(spacing: 16) {
            ItemIcon(def: def, size: 96)
                .shadow(color: def.rarity.color.opacity(0.6), radius: 16)
                .padding(.top, 24)
            VStack(spacing: 4) {
                Text(def.name).font(Theme.display(28))
                Text("\(def.rarity.name) \(def.slot.name) · Lv \(level) / \(def.rarity.maxLevel)")
                    .font(Theme.body(14, .heavy)).foregroundStyle(def.rarity.color)
            }
            VStack(alignment: .leading, spacing: 10) {
                Label(def.describe(level: level), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.text)
                if !maxed {
                    Label("Next: " + def.describe(level: level + 1), systemImage: "arrow.up.circle")
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .font(Theme.body(15))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

            if let current = game.equippedItem(def.slot), current.id != def.id {
                Text("Equipping replaces \(current.name).").font(Theme.body(12)).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Button {
                game.upgradeItem(def.id)
            } label: {
                Label(maxed ? "Max level" : "Upgrade · \(def.upgradeCost(level: level)) Scrap", systemImage: "arrow.up")
                    .font(Theme.body(16, .black))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(game.canUpgradeItem(def.id) ? Theme.buy : Theme.cardRaised, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(game.canUpgradeItem(def.id) ? Color(hex: 0xF2FFE9) : Theme.textFaint)
            }
            .buttonStyle(.plain)
            .disabled(!game.canUpgradeItem(def.id))
            Button {
                if isEquipped { game.unequip(def.slot) } else { game.equip(def.id) }
            } label: {
                Text(isEquipped ? "Unequip" : "Equip")
                    .font(Theme.body(16, .black))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(isEquipped ? Theme.card : def.rarity.color, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(isEquipped ? Theme.text : Color(hex: 0x1A120E))
            }
            .buttonStyle(.plain)
            Text("You have \(game.scrap) Scrap").font(Theme.body(12)).foregroundStyle(Theme.textFaint)
        }
        .padding(20)
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }
}

/// Shown after a chest opens.
struct ChestRevealView: View {
    @EnvironmentObject private var game: GameModel
    @Environment(\.dismiss) private var dismiss
    let reveal: ChestReveal
    @State private var shown = false

    var body: some View {
        let def = ItemDef.find(reveal.item)!
        VStack(spacing: 18) {
            Spacer()
            Text(reveal.tier.name.uppercased()).font(Theme.body(12, .black)).tracking(2).foregroundStyle(reveal.tier.color)
            ItemIcon(def: def, size: 120)
                .shadow(color: def.rarity.color.opacity(0.8), radius: shown ? 28 : 0)
                .scaleEffect(shown || game.settings.reducedMotion ? 1 : 0.4)
            Text(def.rarity.name.uppercased()).font(Theme.body(14, .black)).tracking(2).foregroundStyle(def.rarity.color)
            Text(def.name).font(Theme.display(32))
            Text(reveal.isNew ? "NEW! " + def.describe(level: 1) : "Duplicate: turned into Scrap")
                .font(Theme.body(15)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
            Label("+\(reveal.scrap) Scrap", systemImage: "gearshape.2.fill")
                .font(Theme.body(15, .black)).foregroundStyle(Color(hex: 0xC8D0DC))
            Spacer()
            if game.chestCount(reveal.tier) > 0 {
                Button {
                    game.openChest(reveal.tier)
                } label: {
                    Text("Open another (\(game.chestCount(reveal.tier)))")
                        .font(Theme.body(16, .black))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(reveal.tier.color, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Color(hex: 0x1A120E))
                }
                .buttonStyle(.plain)
            }
            Button("Continue") { dismiss() }
                .font(Theme.body(16, .heavy))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.text)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { shown = true }
        }
    }
}
