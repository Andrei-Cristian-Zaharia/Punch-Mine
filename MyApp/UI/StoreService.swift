import SwiftUI
import Combine
import StoreKit

/// StoreKit 2: loads products, buys, restores, and hands every verified transaction to the game exactly once.
/// Debug builds that can't reach the App Store (or a StoreKit configuration) switch to a free test store.
@MainActor
final class StoreService: ObservableObject {
    enum Status: Equatable { case loading, ready, test, unavailable }

    @Published private(set) var status: Status = .loading
    @Published private(set) var products: [String: Product] = [:]
    /// The product being bought, for its spinner.
    @Published private(set) var buying: StoreProduct?
    @Published var message: String?

    private weak var game: GameModel?
    private var updates: Task<Void, Never>?

    func attach(to game: GameModel) {
        guard self.game !== game else { return }
        self.game = game
        // Purchases finished outside the app (Ask to Buy, another device, interrupted runs).
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates { await self?.handle(result) }
        }
        Task { await load() }
    }

    func load() async {
        status = .loading
        do {
            let found = try await Product.products(for: StoreProduct.allCases.map(\.rawValue))
            products = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0) })
        } catch {
            products = [:]
        }
        if products.isEmpty {
            #if DEBUG
            status = .test
            #else
            status = .unavailable
            #endif
        } else {
            status = .ready
            await creditUnfinished()
        }
    }

    func price(_ item: StoreProduct) -> String {
        products[item.rawValue]?.displayPrice ?? item.fallbackPrice
    }

    func canBuy(_ item: StoreProduct) -> Bool {
        guard let game, buying == nil else { return false }
        if item.isOneTime && game.owns(item) { return false }
        return status == .ready ? products[item.rawValue] != nil : status == .test
    }

    func buy(_ item: StoreProduct) {
        guard canBuy(item), let game else { return }
        buying = item
        Task {
            defer { buying = nil }
            if status == .test {
                // Debug only: no App Store, so the purchase is free and instant.
                try? await Task.sleep(for: .milliseconds(400))
                game.grantPurchase(item, transactionID: "test-\(UUID().uuidString)")
                return
            }
            guard let product = products[item.rawValue] else { return }
            do {
                switch try await product.purchase() {
                case .success(let result): await handle(result)
                case .pending: message = "Waiting for approval. You'll get it as soon as it's approved."
                case .userCancelled: break
                @unknown default: break
                }
            } catch {
                message = "The purchase didn't go through. You weren't charged."
            }
        }
    }

    /// Re-syncs with the App Store and credits one-time purchases made on other devices or before a reinstall.
    func restore() {
        Task {
            if status == .ready { try? await AppStore.sync() }
            var restored = 0
            for await result in StoreKit.Transaction.currentEntitlements {
                guard case .verified(let t) = result, let item = StoreProduct(rawValue: t.productID), item.isOneTime else { continue }
                if game?.owns(item) == true { continue }
                if game?.grantPurchase(item, transactionID: String(t.id)) == true { restored += 1 }
            }
            message = restored > 0 ? "Restored \(restored) purchase\(restored == 1 ? "" : "s")." : "Nothing new to restore."
        }
    }

    private func creditUnfinished() async {
        for await result in StoreKit.Transaction.unfinished { await handle(result) }
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result else { return }
        if t.revocationDate == nil, let item = StoreProduct(rawValue: t.productID) {
            game?.grantPurchase(item, transactionID: String(t.id))
        }
        // Finish only after the game has saved the reward.
        await t.finish()
    }
}
