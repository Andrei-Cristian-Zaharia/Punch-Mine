import Foundation

/// In-app purchases. Product IDs must match App Store Connect (and Config/PunchMine.storekit for local testing).
enum StoreProduct: String, CaseIterable, Codable, Identifiable {
    case removeAds = "punchmine.removeads"
    case starterPack = "punchmine.starterpack"
    case scrapSmall = "punchmine.scrap.small"
    case scrapMedium = "punchmine.scrap.medium"
    case scrapLarge = "punchmine.scrap.large"
    case ironChests = "punchmine.chests.iron5"
    case goldenChests = "punchmine.chests.golden3"
    /// Unlocks the premium track of the event running when it is bought. Shown only on the event screen.
    case eventPass = "punchmine.eventpass"

    var id: String { rawValue }

    enum Section: String, CaseIterable, Identifiable {
        case offers = "Offers", scrap = "Scrap", chests = "Chests"
        var id: String { rawValue }
    }

    var section: Section {
        switch self {
        case .removeAds, .starterPack: .offers
        case .scrapSmall, .scrapMedium, .scrapLarge: .scrap
        case .ironChests, .goldenChests: .chests
        case .eventPass: .offers
        }
    }

    /// Bought once and kept forever (restored on a new device); the rest can be bought again.
    var isOneTime: Bool { self == .removeAds || self == .starterPack }
    /// The Event Pass lives on the event screen, not in the shop.
    var inShop: Bool { self != .eventPass }

    var title: String {
        switch self {
        case .removeAds: "Remove Ads"
        case .starterPack: "Starter Pack"
        case .scrapSmall: "Pile of Scrap"
        case .scrapMedium: "Crate of Scrap"
        case .scrapLarge: "Cart of Scrap"
        case .ironChests: "5 Iron Chests"
        case .goldenChests: "3 Golden Chests"
        case .eventPass: "Event Pass"
        }
    }

    /// What's inside, for the store card.
    var contents: [String] {
        if self == .removeAds { return ["No more ads between runs", "Bonus ads you choose stay available"] }
        if self == .eventPass { return ["Premium reward track", "+50% event currency"] }
        var lines = grant.chests.sorted { $0.key.order > $1.key.order }
            .map { "\($0.value) \($0.key.name)\($0.value == 1 ? "" : "s")" }
        if grant.scrap > 0 { lines.append("\(grant.scrap.formatted()) Scrap") }
        if grant.perkCoins > 0 { lines.append("\(grant.perkCoins.formatted()) Perk Coins") }
        return lines
    }

    /// Shown until the App Store returns the real, localized price.
    var fallbackPrice: String {
        switch self {
        case .removeAds: "$3.99"
        case .starterPack: "$1.99"
        case .scrapSmall: "$0.99"
        case .scrapMedium: "$4.99"
        case .scrapLarge: "$9.99"
        case .ironChests: "$2.99"
        case .goldenChests: "$4.99"
        case .eventPass: "$4.99"
        }
    }

    /// A short ribbon on the card.
    var tag: String? {
        switch self {
        case .starterPack: "BEST VALUE · ONCE"
        case .scrapLarge: "+25% EXTRA"
        default: nil
        }
    }

    struct Grant: Equatable {
        var chests: [ChestTier: Int] = [:]
        var scrap = 0
        var perkCoins = 0
        var removesAds = false
    }

    var grant: Grant {
        switch self {
        case .removeAds: Grant(removesAds: true)
        case .starterPack: Grant(chests: [.golden: 1, .iron: 3], scrap: 500, perkCoins: 200)
        case .scrapSmall: Grant(scrap: 300)
        case .scrapMedium: Grant(scrap: 2_000)
        case .scrapLarge: Grant(scrap: 5_000)
        case .ironChests: Grant(chests: [.iron: 5])
        case .goldenChests: Grant(chests: [.golden: 3])
        // Paid out by `grantEventPass`; this is only the fallback if no event is running.
        case .eventPass: Grant(chests: [.golden: 3])
        }
    }
}

extension GameModel {
    var adsRemoved: Bool { ownedProducts.contains(StoreProduct.removeAds.rawValue) }

    func owns(_ product: StoreProduct) -> Bool { ownedProducts.contains(product.rawValue) }
}
