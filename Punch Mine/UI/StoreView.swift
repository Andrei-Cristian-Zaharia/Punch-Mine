import SwiftUI

/// The in-app store. Opened from the cart button in the zone bar.
struct StoreView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    balances
                    switch store.status {
                    case .test:
                        // Debug builds only: StoreService never enters test mode in release builds.
                        #if DEBUG
                        if !MineView.screenshotLaunch {
                            banner("TEST STORE", "Debug build without the App Store: purchases are free and instant.", Theme.miner)
                        }
                        #endif
                    case .unavailable:
                        VStack(alignment: .leading, spacing: 10) {
                            banner("STORE UNAVAILABLE", "Couldn't reach the App Store. Check your connection and try again.", Theme.fever)
                            Button("Try again") { Task { await store.load() } }
                                .font(Theme.body(15, .heavy)).foregroundStyle(Theme.gold)
                                .frame(minHeight: 44)
                        }
                    case .loading:
                        HStack(spacing: 10) {
                            ProgressView().tint(Theme.textMuted)
                            Text("Loading prices…").font(Theme.body(13)).foregroundStyle(Theme.textMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    case .ready:
                        EmptyView()
                    }
                    ForEach(StoreProduct.Section.allCases) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.rawValue.uppercased())
                                .id(section.rawValue)
                                .font(Theme.body(12, .black)).tracking(1.2).foregroundStyle(Theme.textFaint)
                            ForEach(StoreProduct.allCases.filter { $0.section == section && $0.inShop }) { item in
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
            .onAppear {
                #if DEBUG
                // Screenshot helper: `-debugStoreSection Chests` opens the shop scrolled to that section.
                if let section = UserDefaults.standard.string(forKey: "debugStoreSection") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { proxy.scrollTo(section, anchor: .top) }
                }
                #endif
            }
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("Shop")
            .onAppear { store.reloadIfNeeded() }
            .toolbar {
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

    /// What the player has now: shown in the page (not the toolbar) so it never collides with the title or Done.
    private var balances: some View {
        HStack(spacing: 10) {
            balance(Image(systemName: "gearshape.2.fill").foregroundStyle(Color(hex: 0xC8D0DC)), game.scrap.formatted(), "Scrap")
            balance(PerkCoinIcon(size: 18), game.perkCoins.formatted(), "Perk Coins")
        }
    }

    private func balance(_ icon: some View, _ value: String, _ label: String) -> some View {
        HStack(spacing: 8) {
            icon.font(.system(size: 18, weight: .bold))
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(Theme.body(17, .black)).lineLimit(1).minimumScaleFactor(0.6)
                Text(label.uppercased()).font(Theme.body(10, .black)).tracking(0.8).foregroundStyle(Theme.textFaint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
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

/// Icon tile per product: the same art as the App Store promotional images (Tools/store-screenshots/product_art.py).
private struct ProductArt: View {
    let item: StoreProduct

    var body: some View {
        Image("product-" + item.rawValue.replacingOccurrences(of: "punchmine.", with: "").replacingOccurrences(of: ".", with: "-"))
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0x1A120E), lineWidth: 2))
            .accessibilityHidden(true)
    }
}
