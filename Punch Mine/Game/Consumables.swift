import Foundation

/// One-use boosts and gadgets, kept in the Stash and used whenever the player likes.
enum Consumable: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    // Boosts
    case coinRush, feverStarter, shiftDoubler, eventRush
    // Gadgets
    case snowball, firework, magnet, goldenPick, timeBell

    var id: String { rawValue }
    var order: Int { Consumable.allCases.firstIndex(of: self)! }
    var isGadget: Bool { order >= Consumable.snowball.order }

    var name: String {
        switch self {
        case .coinRush: "Coin Rush Token"
        case .feverStarter: "Fever Starter"
        case .shiftDoubler: "Double Shift"
        case .eventRush: "Event Rush"
        case .snowball: "Snowball"
        case .firework: "Firework"
        case .magnet: "Treasure Magnet"
        case .goldenPick: "Golden Pickaxe"
        case .timeBell: "Time Bell"
        }
    }

    var text: String {
        switch self {
        case .coinRush: "\(Int(ConsumableRules.coinRushSeconds / 60)) minutes of Coin Rush, no ad needed."
        case .feverStarter: "Starts Fever right away."
        case .shiftDoubler: "Doubles your crew's next offline earnings."
        case .eventRush: "\(Int(ConsumableRules.eventRushSeconds / 60)) minutes of double event currency."
        case .snowball: "Freezes the mine: your punches hit ×\(Int(ConsumableRules.snowballFactor)) for \(Int(ConsumableRules.snowballSeconds)) s."
        case .firework: "Blasts a whole row and column for \(Int(ConsumableRules.fireworkPunches))× your punch."
        case .magnet: "Pulls in every treasure in the area at once."
        case .goldenPick: "Everything you break pays ×\(Int(ConsumableRules.goldenFactor)) for \(Int(ConsumableRules.goldenSeconds)) s."
        case .timeBell: "Your miners swing twice as fast for \(Int(ConsumableRules.bellSeconds)) s."
        }
    }

    var symbol: String {
        switch self {
        case .coinRush: "bolt.fill"
        case .feverStarter: "flame.fill"
        case .shiftDoubler: "moon.zzz.fill"
        case .eventRush: "sparkles"
        case .snowball: "snowflake"
        case .firework: "burst.fill"
        case .magnet: "dollarsign.circle.fill"
        case .goldenPick: "hammer.fill"
        case .timeBell: "bell.fill"
        }
    }

    var color: UInt32 {
        switch self {
        case .coinRush: 0xF5C64F
        case .feverStarter: 0xFF7A3D
        case .shiftDoubler: 0x8A7AFF
        case .eventRush: 0xFF6AB0
        case .snowball: 0x8FD8FF
        case .firework: 0xE8343A
        case .magnet: 0xF5C64F
        case .goldenPick: 0xFFD25A
        case .timeBell: 0x3FC1C9
        }
    }
}

enum ConsumableRules {
    static let coinRushSeconds = 600.0
    static let eventRushSeconds = 1_800.0
    static let snowballSeconds = 15.0
    static let snowballFactor = 3.0
    static let fireworkPunches = 10.0
    static let goldenSeconds = 20.0
    static let goldenFactor = 5.0
    static let bellSeconds = 30.0
}
