import SwiftUI

/// The in-app store. Opened from the cart button in the zone bar.
struct StoreView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch store.status {
                    case .test:
                        banner("TEST STORE", "Debug build without the App Store: purchases are free and instant.", Theme.miner)
                    case .unavailable:
                        banner("STORE UNAVAILABLE", "Couldn't reach the App Store. Check your connection and try again.", Theme.fever)
                    case .loading, .ready:
                        EmptyView()
                    }
                    ForEach(StoreProduct.Section.allCases) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.rawValue.uppercased())
                                .font(Theme.body(12, .black)).tracking(1.2).foregroundStyle(Theme.textFaint)
                            ForEach(StoreProduct.allCases.filter { $0.section == section }) { item in
                                ProductCard(item: item)
                            }
                        }
                    }
                    VStack(spacing: 8) {
                        Button("Restore purchases") { store.restore() }
                            .font(Theme.body(15, .heavy))
                            .foregroundStyle(Theme.gold)
                            .frame(minHeight: 44)
                        Text("Remove Ads and the Starter Pack are yours for good and come back with Restore. Prices are in your local currency and charged to your Apple Account.")
                            .font(Theme.body(11)).foregroundStyle(Theme.textFaint).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 10) {
                        HStack(spacing: 4) { Image(systemName: "gearshape.2.fill"); Text("\(game.scrap)") }
                            .foregroundStyle(Color(hex: 0xC8D0DC))
                        HStack(spacing: 4) { PerkCoinIcon(size: 14); Text("\(game.perkCoins)") }.foregroundStyle(Color(hex: 0xE6DAFF))
                    }
                    .font(Theme.body(14, .black))
                    .accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(store.message ?? "", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
    }

    private func banner(_ title: String, _ text: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(Theme.body(11, .black)).tracking(1.2).foregroundStyle(color)
            Text(text).font(Theme.body(13)).foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.6), lineWidth: 2))
    }
}

private struct ProductCard: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var store: StoreService
    let item: StoreProduct

    var body: some View {
        let owned = item.isOneTime && game.owns(item)
        HStack(spacing: 12) {
            ProductArt(item: item)
                .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(Theme.body(16, .black))
                ForEach(item.contents, id: \.self) { line in
                    Text(line).font(Theme.body(12)).foregroundStyle(Theme.textMuted)
                }
            }
            Spacer(minLength: 6)
            Button {
                store.buy(item)
            } label: {
                ZStack {
                    if store.buying == item {
                        ProgressView().tint(Color(hex: 0xF2FFE9))
                    } else {
                        Text(owned ? "OWNED" : store.price(item))
                            .font(Theme.body(15, .black))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .frame(minWidth: 84, minHeight: 46)
                .padding(.horizontal, 6)
                .background(owned ? Theme.cardRaised : (store.canBuy(item) ? Theme.buy : Theme.cardRaised), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(owned || !store.canBuy(item) ? Theme.textFaint : Color(hex: 0xF2FFE9))
            }
            .buttonStyle(.plain)
            .disabled(!store.canBuy(item))
            .accessibilityLabel(owned ? "\(item.title), owned" : "Buy \(item.title) for \(store.price(item))")
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(item.tag != nil ? Theme.gold : Theme.line, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            if let tag = item.tag, !owned {
                Text(tag).font(Theme.body(10, .black)).tracking(0.5)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Theme.gold, in: Capsule())
                    .foregroundStyle(Color(hex: 0x1A120E))
                    .offset(x: -14, y: -9)
            }
        }
    }
}

/// Icon tile per product, built from art the game already has.
private struct ProductArt: View {
    let item: StoreProduct

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Theme.cardRaised)
            switch item {
            case .removeAds:
                ZStack {
                    Image(systemName: "rectangle.on.rectangle").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.textMuted)
                    Image(systemName: "nosign").font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.fever)
                }
            case .starterPack:
                LogoMark().clipShape(RoundedRectangle(cornerRadius: 12)).padding(4)
            case .scrapSmall, .scrapMedium, .scrapLarge:
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: item == .scrapSmall ? 22 : (item == .scrapMedium ? 27 : 32), weight: .bold))
                    .foregroundStyle(Color(hex: 0xC8D0DC))
            case .ironChests, .goldenChests:
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(item == .goldenChests ? ChestTier.golden.color : ChestTier.iron.color)
            }
        }
        .accessibilityHidden(true)
    }
}
