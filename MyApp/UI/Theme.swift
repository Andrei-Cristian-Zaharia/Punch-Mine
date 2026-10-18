import SwiftUI

enum Theme {
    static let ground = Color(hex: 0x18130F)
    static let panel = Color(hex: 0x241D18)
    static let card = Color(hex: 0x2E251F)
    static let cardRaised = Color(hex: 0x3A2F26)
    static let line = Color(hex: 0x4A3B2F)
    static let text = Color(hex: 0xF5EDE3)
    static let textMuted = Color(hex: 0xC9B8A6)
    static let textFaint = Color(hex: 0x8F7D6C)

    static let copper = Color(hex: 0xE0843A)
    static let copperDark = Color(hex: 0x8A4A1C)
    static let fever = Color(hex: 0xFF7A3D)
    static let buy = Color(hex: 0x3E7A3A)
    static let buyShadow = Color(hex: 0x24501F)
    static let miner = Color(hex: 0x2F6FB0)
    static let minerLight = Color(hex: 0xA9D2FF)
    static let crit = Color(hex: 0xFF8A3D)
    static let gold = Color(hex: 0xF5C64F)
    static let crystal = Color(hex: 0x3FC1C9)
    static let ember = Color(hex: 0xE2553A)

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight, design: .rounded) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension Ore {
    var fill: Color {
        switch self {
        case .dirt: Color(hex: 0x8A5A3B)
        case .stone: Color(hex: 0x7D766E)
        case .iron: Color(hex: 0x6A625C)
        case .gold: Color(hex: 0x544B44)
        case .granite: Color(hex: 0x45404C)
        case .treasure: Color(hex: 0x3A2A1C)
        case .limestone: Color(hex: 0xA79E8C)
        case .quartz: Color(hex: 0x4E7F86)
        case .amethyst: Color(hex: 0x5B3F7A)
        case .voidstone: Color(hex: 0x23263A)
        case .geode: Color(hex: 0x3D4148)
        case .basalt: Color(hex: 0x4A4A50)
        case .obsidian: Color(hex: 0x221C2C)
        case .magmaCore: Color(hex: 0x5A2418)
        case .emberOre: Color(hex: 0x3E2C26)
        case .heartstone: Color(hex: 0x4A1020)
        case .vent: Color(hex: 0x2A1C18)
        case .fireOpal: Color(hex: 0x3A2214)
        case .copperOre: Color(hex: 0x6E6058)
        case .coal: Color(hex: 0x2C2A2A)
        case .silver: Color(hex: 0x5C6068)
        case .diamond: Color(hex: 0x3A4652)
        case .mithril: Color(hex: 0x2E3A4E)
        case .adamantite: Color(hex: 0x2A2236)
        case .heart, .heartPart: Color(hex: 0x5A0E14)
        }
    }

    var edge: Color {
        switch self {
        case .dirt: Color(hex: 0x5E3B24)
        case .stone: Color(hex: 0x5A544E)
        case .iron: Color(hex: 0x4A433E)
        case .gold: Color(hex: 0x3A332D)
        case .granite: Color(hex: 0x2E2A33)
        case .treasure: Theme.gold
        case .limestone: Color(hex: 0x7C7464)
        case .quartz: Color(hex: 0x2F5A5E)
        case .amethyst: Color(hex: 0x3D2853)
        case .voidstone: Color(hex: 0x14162A)
        case .geode: Color(hex: 0x6FE0E6)
        case .basalt: Color(hex: 0x323238)
        case .obsidian: Color(hex: 0x120E18)
        case .magmaCore: Color(hex: 0x3A140C)
        case .emberOre: Color(hex: 0x261A16)
        case .heartstone: Color(hex: 0x2E0812)
        case .vent: Color(hex: 0x5A2A18)
        case .fireOpal: Theme.gold
        case .copperOre: Color(hex: 0x4E4038)
        case .coal: Color(hex: 0x161414)
        case .silver: Color(hex: 0x3C4048)
        case .diamond: Color(hex: 0x24303A)
        case .mithril: Color(hex: 0x1A2436)
        case .adamantite: Color(hex: 0x16101E)
        case .heart, .heartPart: Color(hex: 0xFF5A3D)
        }
    }
}

extension ZoneID {
    /// Wallet, tab and progress color for the zone.
    var accent: Color {
        switch self {
        case .quarry: Theme.copper
        case .caverns: Theme.crystal
        case .magma: Theme.ember
        }
    }
    /// Text color on top of `accent`.
    var onAccent: Color {
        switch self {
        case .quarry: Color(hex: 0x2A1406)
        case .caverns: Color(hex: 0x072A2C)
        case .magma: Color(hex: 0x2A0A04)
        }
    }
    var cardFill: Color {
        switch self {
        case .quarry: Color(hex: 0x2A2019)
        case .caverns: Color(hex: 0x1A2426)
        case .magma: Color(hex: 0x2A1614)
        }
    }
    var cardEdge: Color {
        switch self {
        case .quarry: Color(hex: 0x5A4130)
        case .caverns: Color(hex: 0x2F5A5E)
        case .magma: Color(hex: 0x6A2C20)
        }
    }
    var ground: Color {
        switch self {
        case .quarry: Theme.ground
        case .caverns: Color(hex: 0x111719)
        case .magma: Color(hex: 0x1A100E)
        }
    }
    var panel: Color {
        switch self {
        case .quarry: Theme.panel
        case .caverns: Color(hex: 0x1A2326)
        case .magma: Color(hex: 0x261614)
        }
    }
    /// Background of the zone's badge in zone select.
    var badgeOre: Ore {
        switch self {
        case .quarry: .stone
        case .caverns: .quartz
        case .magma: .magmaCore
        }
    }
}

/// The zone's coin: round copper or a teal hexagon shard, so wallets differ in shape as well as color.
struct CurrencyIcon: View {
    let zone: ZoneID
    var size: CGFloat = 18
    var body: some View {
        switch zone {
        case .quarry: CoinIcon(size: size)
        case .caverns: ShardIcon(size: size)
        case .magma: EmberIcon(size: size)
        }
    }
}

/// Ember Coins: a red notched coin with a flame, distinct in shape from copper and shards.
struct EmberIcon: View {
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            Canvas { context, s in
                let c = CGPoint(x: s.width / 2, y: s.height / 2)
                var gear = Path()
                let teeth = 8
                for i in 0..<(teeth * 2) {
                    let r = (i % 2 == 0 ? 0.5 : 0.42) * s.width
                    let a = Double(i) * .pi / Double(teeth) - .pi / 2
                    let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                    if i == 0 { gear.move(to: p) } else { gear.addLine(to: p) }
                }
                gear.closeSubpath()
                context.fill(gear, with: .color(Theme.ember))
                context.stroke(gear, with: .color(Color(hex: 0x6A1A0E)), lineWidth: max(1.2, s.width * 0.07))
            }
            Image(systemName: "flame.fill")
                .resizable().scaledToFit()
                .foregroundStyle(Color(hex: 0xFFD27A))
                .frame(width: size * 0.42, height: size * 0.42)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ShardIcon: View {
    var size: CGFloat = 18
    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width, h = canvasSize.height
            var hex = Path()
            for i in 0..<6 {
                let angle = Double(i) * .pi / 3 - .pi / 2
                let p = CGPoint(x: w / 2 + cos(angle) * w * 0.46, y: h / 2 + sin(angle) * h * 0.48)
                if i == 0 { hex.move(to: p) } else { hex.addLine(to: p) }
            }
            hex.closeSubpath()
            context.fill(hex, with: .color(Theme.crystal))
            context.stroke(hex, with: .color(Color(hex: 0x1C6E73)), lineWidth: max(1.5, w * 0.08))
            var glint = Path()
            glint.move(to: CGPoint(x: w * 0.5, y: h * 0.24))
            glint.addLine(to: CGPoint(x: w * 0.72, y: h * 0.38))
            glint.addLine(to: CGPoint(x: w * 0.72, y: h * 0.6))
            context.stroke(glint, with: .color(Color(hex: 0xBFF7F9)), lineWidth: max(1, w * 0.07))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CoinIcon: View {
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            Circle().fill(Theme.copper)
            Circle().strokeBorder(Theme.copperDark, lineWidth: size * 0.09)
            Circle().stroke(Color(hex: 0xFFD2A6, opacity: 0.7), lineWidth: size * 0.07).padding(size * 0.26)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension Theme {
    static let perk = Color(hex: 0x7A55D6)
    static let perkLight = Color(hex: 0xA98BFF)
    static let perkPanel = Color(hex: 0x2B2240)
    static let perkGround = Color(hex: 0x15111F)
}

struct PerkCoinIcon: View {
    var size: CGFloat = 18
    var body: some View {
        Image(systemName: "star.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Theme.perkLight)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

extension MinerKind {
    var symbol: String {
        switch self {
        case .digger: "hammer.fill"
        case .driller: "screwdriver.fill"
        case .blaster: "burst.fill"
        }
    }
    var color: Color {
        switch self {
        case .digger: Theme.miner
        case .driller: Color(hex: 0xB0612F)
        case .blaster: Color(hex: 0xA8323A)
        }
    }
    var lightColor: Color {
        switch self {
        case .digger: Theme.minerLight
        case .driller: Color(hex: 0xFFC08A)
        case .blaster: Color(hex: 0xFF9A9F)
        }
    }
}
