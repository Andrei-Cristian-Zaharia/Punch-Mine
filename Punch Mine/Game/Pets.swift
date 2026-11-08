import Foundation

/// A companion that floats by the mine and adds one small bonus. One is active at a time;
/// finding a pet again raises its level.
struct PetDef: Identifiable, Equatable {
    let id: String
    let name: String
    let effect: ItemEffect
    let base: Double
    let perLevel: Double
    /// The event that hands it out, if any.
    var season: SeasonID? = nil
    let color: UInt32

    static let maxLevel = 5
    /// A pet found again at max level pays Scrap instead.
    static let maxedScrap = 200

    func value(level: Int) -> Double { base + perLevel * Double(max(level, 1) - 1) }
    func describe(level: Int) -> String { ItemDef.describe(effect, value: value(level: level)) }

    static let all: [PetDef] = [
        PetDef(id: "bat", name: "Candy Bat", effect: .critChance, base: 0.02, perLevel: 0.004, season: .harvest, color: 0xFF8A2A),
        PetDef(id: "owl", name: "Snow Owl", effect: .treasureChance, base: 0.01, perLevel: 0.002, season: .frostfall, color: 0xBFE8FF),
        PetDef(id: "cat", name: "Lucky Cat", effect: .coins, base: 0.10, perLevel: 0.02, season: .lantern, color: 0xF5C64F),
        PetDef(id: "bunny", name: "Spring Bunny", effect: .lucky, base: 0.02, perLevel: 0.004, season: .bloom, color: 0xFFD0E8),
        PetDef(id: "crab", name: "Beach Crab", effect: .treasureReward, base: 0.15, perLevel: 0.03, season: .splash, color: 0xFF6A4A),
        PetDef(id: "mole", name: "Gold Mole", effect: .minerSpeed, base: 0.05, perLevel: 0.01, season: .goldrush, color: 0xB8885A),
        PetDef(id: "golem", name: "Rock Golem", effect: .minerDamage, base: 0.15, perLevel: 0.03, color: 0x9C958D),
        PetDef(id: "fox", name: "Ember Fox", effect: .feverDuration, base: 1.0, perLevel: 0.25, color: 0xFF5A3D),
    ]

    static func find(_ id: String) -> PetDef? { all.first { $0.id == id } }
    static func of(_ season: SeasonID) -> PetDef? { all.first { $0.season == season } }
}
