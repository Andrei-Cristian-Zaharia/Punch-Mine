import Foundation

/// Anything the game hands out at once: chests, currencies, consumables, items, pets and cosmetics.
/// Weekly Heart prizes, event tracks, the event boss and the event shop all pay with it.
struct Reward: Equatable, Codable {
    var chests: [ChestTier: Int] = [:]
    var scrap = 0
    var perkCoins = 0
    var consumables: [Consumable: Int] = [:]
    /// Item ids (seasonal set pieces). An item already owned gains levels instead.
    var items: [String] = []
    var pets: [String] = []
    var cosmetics: [String] = []

    init(chests: [ChestTier: Int] = [:], scrap: Int = 0, perkCoins: Int = 0, consumables: [Consumable: Int] = [:],
         items: [String] = [], pets: [String] = [], cosmetics: [String] = []) {
        self.chests = chests
        self.scrap = scrap
        self.perkCoins = perkCoins
        self.consumables = consumables
        self.items = items
        self.pets = pets
        self.cosmetics = cosmetics
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chests = try c.decodeIfPresent([ChestTier: Int].self, forKey: .chests) ?? [:]
        scrap = try c.decodeIfPresent(Int.self, forKey: .scrap) ?? 0
        perkCoins = try c.decodeIfPresent(Int.self, forKey: .perkCoins) ?? 0
        consumables = try c.decodeIfPresent([Consumable: Int].self, forKey: .consumables) ?? [:]
        items = try c.decodeIfPresent([String].self, forKey: .items) ?? []
        pets = try c.decodeIfPresent([String].self, forKey: .pets) ?? []
        cosmetics = try c.decodeIfPresent([String].self, forKey: .cosmetics) ?? []
    }

    var text: String {
        var parts: [String] = []
        parts += cosmetics.compactMap { Cosmetic.find($0).map { "\($0.name) (\($0.kind.label))" } }
        parts += pets.compactMap { PetDef.find($0).map { "\($0.name) pet" } }
        parts += items.compactMap { ItemDef.find($0)?.name }
        parts += chests.sorted { $0.key.order > $1.key.order }.map { $0.value > 1 ? "\($0.value) \($0.key.name)s" : $0.key.name }
        parts += consumables.sorted { $0.key.order < $1.key.order }.map { $0.value > 1 ? "\($0.value)× \($0.key.name)" : $0.key.name }
        if scrap > 0 { parts.append("\(scrap) Scrap") }
        if perkCoins > 0 { parts.append("\(perkCoins) Perk Coins") }
        return parts.joined(separator: " + ")
    }

    /// The headline part, for a small reward cell.
    var headline: String {
        if let id = cosmetics.first, let c = Cosmetic.find(id) { return c.name }
        if let id = pets.first, let p = PetDef.find(id) { return p.name }
        if let id = items.first, let i = ItemDef.find(id) { return i.name }
        return text
    }
}
