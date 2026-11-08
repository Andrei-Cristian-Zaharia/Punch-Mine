import Foundation

/// Ascension: the Perk Coin sink after the first Crown. Star perks repeat with no level cap (Star Luck has one);
/// Ascension perks are bought once.
enum StarPerk: String, Codable, CaseIterable, Identifiable {
    case fists, crew, fortune, luck, salvage

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fists: "Starforged Fists"
        case .crew: "Star Crew"
        case .fortune: "Star Fortune"
        case .luck: "Star Luck"
        case .salvage: "Star Salvage"
        }
    }

    var symbol: String {
        switch self {
        case .fists: "hand.raised.fill"
        case .crew: "person.3.fill"
        case .fortune: "dollarsign.circle.fill"
        case .luck: "sparkles"
        case .salvage: "gearshape.2.fill"
        }
    }

    /// Bonus per level (multiplicative with everything else for damage and coins).
    var perLevel: Double {
        switch self {
        case .fists, .crew, .fortune: 0.03
        case .luck: 0.02
        case .salvage: 0.05
        }
    }

    var maxLevel: Int? { self == .luck ? 25 : nil }

    /// Perk Coins for the next level.
    func cost(level: Int) -> Int {
        let base: Double = self == .luck ? 120 : (self == .salvage ? 60 : 80)
        return Int((base * pow(Ascension.starGrowth, Double(level))).rounded())
    }

    func effect(level: Int) -> String {
        let pct = Int((perLevel * Double(level) * 100).rounded())
        switch self {
        case .fists: return "×\(NumberText.decimal(1 + perLevel * Double(level), digits: 2)) punch damage"
        case .crew: return "×\(NumberText.decimal(1 + perLevel * Double(level), digits: 2)) miner damage"
        case .fortune: return "×\(NumberText.decimal(1 + perLevel * Double(level), digits: 2)) coins in every zone"
        case .luck: return "+\(pct)% chest luck"
        case .salvage: return "+\(pct)% Scrap from chests"
        }
    }

    var summary: String {
        switch self {
        case .fists: "+3% punch damage per level, on top of everything"
        case .crew: "+3% miner damage per level, on top of everything"
        case .fortune: "+3% coins per level, on top of everything"
        case .luck: "+2% chest luck per level (Epic and Legendary odds), up to 25 levels"
        case .salvage: "+5% Scrap from chests per level"
        }
    }
}

enum AscensionPerk: String, Codable, CaseIterable, Identifiable {
    case autoPrestige, unionContract, secondWind

    var id: String { rawValue }

    var name: String {
        switch self {
        case .autoPrestige: "Auto-Prestige"
        case .unionContract: "Union Contract"
        case .secondWind: "Second Wind"
        }
    }

    var symbol: String {
        switch self {
        case .autoPrestige: "arrow.triangle.2.circlepath"
        case .unionContract: "signature"
        case .secondWind: "flame.fill"
        }
    }

    var cost: Int {
        switch self {
        case .autoPrestige: 2_500
        case .unionContract: 1_800
        case .secondWind: 1_500
        }
    }

    var summary: String {
        switch self {
        case .autoPrestige: "Prestiges for you when a run stalls for \(Int(Ascension.autoPrestigeStall)) s. Can be turned off."
        case .unionContract: "Hired miners stay with you when you prestige"
        case .secondWind: "Fever multiplier +1 (×2 → ×3)"
        }
    }
}

enum Ascension {
    static let starGrowth = 1.12
    static let autoPrestigeStall = 120.0
}

extension GameModel {
    var ascensionUnlocked: Bool { crowns > 0 }

    func starLevel(_ star: StarPerk) -> Int { stars[star.rawValue, default: 0] }
    func owns(_ perk: AscensionPerk) -> Bool { ascended.contains(perk.rawValue) }

    func starState(_ star: StarPerk) -> PerkState {
        if let max = star.maxLevel, starLevel(star) >= max { return .maxed }
        guard ascensionUnlocked else { return .locked }
        return perkCoins >= star.cost(level: starLevel(star)) ? .affordable : .tooExpensive
    }

    func ascensionState(_ perk: AscensionPerk) -> PerkState {
        if owns(perk) { return .maxed }
        guard ascensionUnlocked else { return .locked }
        return perkCoins >= perk.cost ? .affordable : .tooExpensive
    }

    /// Multiplier from a Star perk: 1 + bonus × level.
    func starMultiplier(_ star: StarPerk) -> Double { 1 + star.perLevel * Double(starLevel(star)) }
}
