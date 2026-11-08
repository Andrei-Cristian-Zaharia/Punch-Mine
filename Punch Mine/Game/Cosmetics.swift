import Foundation

/// Looks only, never power: punch effects (fist skins), block-break effects, titles and app icons.
enum CosmeticKind: String, Codable, CaseIterable, Identifiable {
    case fist, burst, title, icon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fist: "fist skin"
        case .burst: "break effect"
        case .title: "title"
        case .icon: "app icon"
        }
    }

    var plural: String {
        switch self {
        case .fist: "Fist Skins"
        case .burst: "Break Effects"
        case .title: "Titles"
        case .icon: "App Icons"
        }
    }
}

/// The shape a fist skin flashes on a hit, or a break effect throws out.
enum CosmeticShape: String, Codable {
    case ring, star, flake, flame, candy, coin, heart, petal, bubble
}

struct Cosmetic: Identifiable, Equatable {
    let id: String
    let kind: CosmeticKind
    let name: String
    var shape: CosmeticShape = .ring
    /// Main and second color; fist skins also tint hit numbers with the main one.
    var colors: [UInt32] = []
    /// App icons: the name in the asset catalog.
    var iconName: String? = nil
    var season: SeasonID? = nil
    /// Where it comes from, for the locked card.
    var source = ""

    static let all: [Cosmetic] = [
        // Fist skins
        Cosmetic(id: "fist.pumpkin", kind: .fist, name: "Pumpkin Punch", shape: .candy, colors: [0xFF8A2A, 0xFFE85A], season: .harvest,
                 source: "Haunted Harvest pass"),
        Cosmetic(id: "fist.frost", kind: .fist, name: "Frost Knuckles", shape: .flake, colors: [0x8FD8FF, 0xFFFFFF], season: .frostfall,
                 source: "Frostfall pass"),
        Cosmetic(id: "fist.dragon", kind: .fist, name: "Dragon Fist", shape: .flame, colors: [0xE8343A, 0xFFC93C], season: .lantern,
                 source: "Lantern Festival pass"),
        Cosmetic(id: "fist.bloom", kind: .fist, name: "Petal Punch", shape: .petal, colors: [0xFF8AC8, 0xFFF0F8], season: .bloom,
                 source: "Spring Bloom pass"),
        Cosmetic(id: "fist.splash", kind: .fist, name: "Splash Fist", shape: .bubble, colors: [0x3FD8E8, 0xE8FFFF], season: .splash,
                 source: "Sunny Splash pass"),
        Cosmetic(id: "fist.nugget", kind: .fist, name: "Nugget Knuckles", shape: .coin, colors: [0xE0A82A, 0xFFE07A], season: .goldrush,
                 source: "Gold Rush pass"),
        Cosmetic(id: "fist.golden", kind: .fist, name: "Golden Glove", shape: .star, colors: [0xF5C64F, 0xFFF3B0],
                 source: "Weekly Heart top 3"),
        Cosmetic(id: "fist.heart", kind: .fist, name: "Heartbreaker", shape: .heart, colors: [0xFF5A6E, 0xFFD0D8],
                 source: "Defeat an event boss"),
        // Break effects
        Cosmetic(id: "burst.candy", kind: .burst, name: "Candy Burst", shape: .candy, colors: [0xFF6AB0, 0xFF8A2A, 0x7AE07A, 0xFFE85A],
                 season: .harvest, source: "Haunted Harvest pass"),
        Cosmetic(id: "burst.snow", kind: .burst, name: "Snowfall", shape: .flake, colors: [0xFFFFFF, 0xBFE8FF, 0x8FD8FF],
                 season: .frostfall, source: "Frostfall pass"),
        Cosmetic(id: "burst.fireworks", kind: .burst, name: "Firecrackers", shape: .star, colors: [0xE8343A, 0xFFC93C, 0xFF8A2A],
                 season: .lantern, source: "Lantern Festival pass"),
        Cosmetic(id: "burst.petals", kind: .burst, name: "Petal Storm", shape: .petal, colors: [0xFF8AC8, 0xFFD0E8, 0xFFFFFF, 0x9AE07A],
                 season: .bloom, source: "Spring Bloom pass"),
        Cosmetic(id: "burst.bubbles", kind: .burst, name: "Bubbles", shape: .bubble, colors: [0x9FF4FF, 0x3FD8E8, 0xFFFFFF],
                 season: .splash, source: "Sunny Splash pass"),
        Cosmetic(id: "burst.nuggets", kind: .burst, name: "Nugget Shower", shape: .star, colors: [0xE0A82A, 0xFFE07A, 0x8A5A2A],
                 season: .goldrush, source: "Gold Rush pass"),
        Cosmetic(id: "burst.gold", kind: .burst, name: "Gold Rain", shape: .coin, colors: [0xF5C64F, 0xFFE07A, 0xD08E14],
                 source: "Event shop"),
        // Titles
        Cosmetic(id: "title.pumpkin", kind: .title, name: "Pumpkin King", season: .harvest, source: "Haunted Harvest boss"),
        Cosmetic(id: "title.frost", kind: .title, name: "Frostborn", season: .frostfall, source: "Frostfall boss"),
        Cosmetic(id: "title.dragon", kind: .title, name: "Dragon Lord", season: .lantern, source: "Lantern Festival boss"),
        Cosmetic(id: "title.bloom", kind: .title, name: "Bloom Keeper", season: .bloom, source: "Spring Bloom boss"),
        Cosmetic(id: "title.sun", kind: .title, name: "Sun Chaser", season: .splash, source: "Sunny Splash boss"),
        Cosmetic(id: "title.prospector", kind: .title, name: "Prospector", season: .goldrush, source: "Gold Rush boss"),
        Cosmetic(id: "title.champion", kind: .title, name: "Weekly Champion", source: "Weekly Heart top 3"),
        Cosmetic(id: "title.smith", kind: .title, name: "Master Smith", source: "Forge a Legendary"),
        // App icons
        Cosmetic(id: "icon.pumpkin", kind: .icon, name: "Pumpkin Icon", colors: [0xFF8A2A], iconName: "AppIcon-Pumpkin", season: .harvest,
                 source: "Haunted Harvest pass"),
        Cosmetic(id: "icon.frost", kind: .icon, name: "Frost Icon", colors: [0x8FD8FF], iconName: "AppIcon-Frost", season: .frostfall,
                 source: "Frostfall pass"),
        Cosmetic(id: "icon.lantern", kind: .icon, name: "Lantern Icon", colors: [0xE8343A], iconName: "AppIcon-Lantern", season: .lantern,
                 source: "Lantern Festival pass"),
        Cosmetic(id: "icon.bloom", kind: .icon, name: "Bloom Icon", colors: [0xFF8AC8], iconName: "AppIcon-Bloom", season: .bloom,
                 source: "Spring Bloom pass"),
        Cosmetic(id: "icon.sun", kind: .icon, name: "Sun Icon", colors: [0x3FD8E8], iconName: "AppIcon-Sun", season: .splash,
                 source: "Sunny Splash pass"),
        Cosmetic(id: "icon.nugget", kind: .icon, name: "Nugget Icon", colors: [0xE0A82A], iconName: "AppIcon-Nugget", season: .goldrush,
                 source: "Gold Rush pass"),
        Cosmetic(id: "icon.gold", kind: .icon, name: "Golden Icon", colors: [0xF5C64F], iconName: "AppIcon-Gold",
                 source: "Weekly Heart 1st place"),
    ]

    static func find(_ id: String) -> Cosmetic? { all.first { $0.id == id } }
    static func of(_ kind: CosmeticKind, season: SeasonID) -> Cosmetic? { all.first { $0.kind == kind && $0.season == season } }
}
