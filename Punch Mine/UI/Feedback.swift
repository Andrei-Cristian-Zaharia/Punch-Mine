import SwiftUI
import Combine

/// One shower of rock chunks from a broken block.
struct DebrisBurst: Identifiable {
    let id: Int
    let index: Int
    let colors: [Color]
    let born: Date
    /// 1 for a block, 3 for the Heart.
    let scale: CGFloat
    let sparkle: Bool
    /// A break effect's shape; nil throws rock chunks.
    var shape: CosmeticShape? = nil
}

/// A fist skin's flash where a punch landed.
struct ImpactMark: Identifiable {
    let id: Int
    let index: Int
    let born: Date
    let shape: CosmeticShape
    let colors: [Color]
}

/// Turns `GameEvent`s into sound, haptics, screen shake and debris.
final class GameFeedback: ObservableObject {
    static let debrisLife: TimeInterval = 0.6

    let sound = SoundEngine()
    @Published private(set) var debris: [DebrisBurst] = []
    @Published private(set) var impacts: [ImpactMark] = []
    static let impactLife: TimeInterval = 0.3
    @Published private(set) var shakeTravel: CGFloat = 0
    @Published private(set) var shakeAmount: CGFloat = 0

    private weak var game: GameModel?
    private var nextDebrisID = 0
    private var lastShake = Date.distantPast
    private var cancellables: Set<AnyCancellable> = []

    func attach(to game: GameModel) {
        guard self.game !== game else { return }
        self.game = game
        game.onEvent = { [weak self] event in self?.handle(event) }
        game.$settings
            .sink { [weak self] settings in
                self?.sound.effectsOn = settings.soundEffects
                self?.sound.effectsVolume = Float(settings.effectsVolume)
                self?.sound.musicVolume = Float(settings.musicVolume)
                self?.sound.musicOn = settings.music
            }
            .store(in: &cancellables)
        game.$activeZone
            .removeDuplicates()
            .sink { [weak self] zone in self?.sound.musicZone = zone.rawValue }
            .store(in: &cancellables)
        // Ads bring their own audio.
        game.$isPaused
            .removeDuplicates()
            .sink { [weak self] paused in self?.sound.musicSuspended = paused }
            .store(in: &cancellables)
    }

    private var motionAllowed: Bool {
        guard let settings = game?.settings else { return false }
        return !settings.reducedMotion
    }

    private func handle(_ event: GameEvent) {
        guard let game else { return }
        let vibration = game.settings.vibration
        switch event {
        case let .punch(index, crit, weak, titan):
            if !weak { impact(at: index, crit: crit) }
            if titan {
                sound.play(.titan)
                shake(9)
                Haptics.impact(.heavy, vibration)
            } else if weak {
                sound.play(.deflect, volume: 0.8)
            } else if crit {
                sound.play(.crit)
                shake(2.5)
            } else {
                sound.play(.punch, volume: 0.85)
            }
        case .minerHit:
            sound.play(.minerTick, volume: 0.45)
        case let .blockBreak(index, ore, treasure, lucky):
            sound.play(Self.crunch(for: ore), volume: ore == .heart ? 1 : 0.8)
            sound.play(treasure ? .treasure : (lucky ? .lucky : .coin), volume: treasure ? 1 : 0.55)
            if treasure { shake(4); Haptics.impact(.medium, vibration) }
            burst(at: index, ore: ore, treasure: treasure)
        case .chain:
            sound.play(.chain)
        case .zap:
            sound.play(.zap)
            shake(2)
        case .boom:
            sound.play(.boom)
            shake(10)
            Haptics.impact(.heavy, vibration)
        case .erupt:
            sound.play(.erupt)
            shake(5)
            Haptics.impact(.medium, vibration)
        case .areaClear:
            sound.play(.clear, volume: 0.9)
        case .fever:
            sound.play(.fever)
            Haptics.success(vibration)
        case .heartDefeated:
            sound.play(.heart)
            shake(14)
            Haptics.impact(.heavy, vibration)
        case let .chest(rarity):
            sound.play([.chestCommon, .chestRare, .chestEpic, .chestLegendary, .chestLegendary][rarity.rawValue])
            if rarity >= .epic { Haptics.success(vibration) }
        case .purchase:
            sound.play(.purchase, volume: 0.8)
        case let .tide(rising):
            sound.play(.erupt, volume: rising ? 0.7 : 0.4)
            if rising { Haptics.impact(.medium, vibration) }
        case .rune:
            sound.play(.zap)
            shake(3)
        case let .haunt(faded):
            sound.play(.chain, volume: faded ? 0.45 : 0.6)
        case .curse:
            sound.play(.deflect)
            Haptics.impact(.medium, vibration)
        case .weeklyTier:
            sound.play(.clear, volume: 0.8)
            Haptics.impact(.medium, vibration)
        }
    }

    static func crunch(for ore: Ore) -> Synth.Cue {
        switch ore {
        case .quartz, .amethyst, .diamond, .fireOpal, .geode: .crunchCrystal
        case .dirt, .coal, .limestone, .emberOre, .magmaCore, .heartstone, .treasure, .sand, .coral, .pearlClam,
             .graveDirt, .bonePile, .reliquary, .pumpkin, .redLantern, .bloomBud, .seashell: .crunch
        case .soulstone, .lichCrystal, .frostShard: .crunchCrystal
        default: .crunchHard
        }
    }

    // MARK: - Shake

    private func shake(_ amount: CGFloat) {
        guard motionAllowed, game?.settings.screenShake == true else { return }
        let now = Date()
        // A new shake during one in progress never makes it weaker.
        shakeAmount = now.timeIntervalSince(lastShake) < 0.35 ? max(shakeAmount, amount) : amount
        lastShake = now
        withAnimation(.linear(duration: 0.35)) { shakeTravel += 1 }
    }

    // MARK: - Debris

    private func burst(at index: Int, ore: Ore, treasure: Bool) {
        guard motionAllowed, ore != .heartPart else { return }
        nextDebrisID += 1
        var colors = ore.debrisColors
        if treasure { colors.append(Theme.gold) }
        let style = game?.equippedCosmetic(.burst)
        if let style { colors = style.colors.map { Color(hex: $0) } + (treasure ? [Theme.gold] : []) }
        debris.append(DebrisBurst(id: nextDebrisID, index: ore == .heart ? Conquest.heartIndex : index, colors: colors,
                                  born: Date(), scale: ore == .heart ? 3 : 1, sparkle: treasure || ore == .heart, shape: style?.shape))
        if debris.count > 14 { debris.removeFirst(debris.count - 14) }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.debrisLife + 0.05))
            self?.pruneDebris()
        }
    }

    private func impact(at index: Int, crit: Bool) {
        guard motionAllowed, let skin = game?.equippedCosmetic(.fist) else { return }
        nextDebrisID += 1
        impacts.append(ImpactMark(id: nextDebrisID, index: index, born: Date(), shape: skin.shape,
                                  colors: skin.colors.map { Color(hex: $0) }))
        if impacts.count > 8 { impacts.removeFirst(impacts.count - 8) }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.impactLife + 0.05))
            guard let self else { return }
            let now = Date()
            self.impacts.removeAll { now.timeIntervalSince($0.born) > Self.impactLife }
        }
    }

    private func pruneDebris() {
        let now = Date()
        if debris.contains(where: { now.timeIntervalSince($0.born) > Self.debrisLife }) {
            debris.removeAll { now.timeIntervalSince($0.born) > Self.debrisLife }
        }
    }
}

/// Decaying wobble. `travel` goes up by 1 per shake; its fractional part is the shake's progress.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat
    var travel: CGFloat

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = travel - travel.rounded(.down)
        let decay = (1 - progress) * (1 - progress)
        let x = amount * decay * sin(progress * .pi * 9)
        let y = amount * 0.7 * decay * cos(progress * .pi * 7 + 0.5) * (progress > 0 ? 1 : 0)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}

/// Applies the screen shake to its content.
struct ShakeHost<Content: View>: View {
    @EnvironmentObject private var fx: GameFeedback
    @ViewBuilder var content: Content

    var body: some View {
        content.modifier(ShakeEffect(amount: fx.shakeAmount, travel: fx.shakeTravel))
    }
}

/// Rock chunks flying out of broken blocks, drawn over the grid.
struct DebrisLayer: View {
    @EnvironmentObject private var fx: GameFeedback
    let side: CGFloat
    let gap: CGFloat

    var body: some View {
        if !fx.debris.isEmpty || !fx.impacts.isEmpty {
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    for burst in fx.debris {
                        draw(burst, in: &context, at: timeline.date)
                    }
                    for mark in fx.impacts {
                        draw(mark, in: &context, at: timeline.date)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func center(_ index: Int) -> CGPoint {
        let col = CGFloat(index % Config.columns), row = CGFloat(index / Config.columns)
        return CGPoint(x: col * (side + gap) + side / 2, y: row * (side + gap) + side / 2)
    }

    private func draw(_ burst: DebrisBurst, in context: inout GraphicsContext, at now: Date) {
        let t = now.timeIntervalSince(burst.born)
        guard t >= 0, t < GameFeedback.debrisLife else { return }
        let life = t / GameFeedback.debrisLife
        let origin = center(burst.index)
        var rng = Noise(seed: UInt64(burst.id) &* 2_654_435_761)
        let count = burst.scale > 1 ? 18 : 8
        let gravity = 1_100.0 * Double(burst.scale > 1 ? 1.4 : 1)
        let alpha = 1 - life * life

        for k in 0..<count {
            let angle = Double(k) / Double(count) * 2 * .pi + rng.next() * 0.6
            let speed = (140 + 130 * abs(rng.next())) * Double(burst.scale > 1 ? 1.8 : 1)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed - 220
            let x = origin.x + CGFloat(vx * t)
            let y = origin.y + CGFloat(vy * t + 0.5 * gravity * t * t)
            let size = side * CGFloat(0.11 + 0.08 * abs(rng.next())) * (burst.scale > 1 ? 1.6 : 1) * CGFloat(1 - 0.35 * life)
            let spin = rng.next() * 14 * t
            let color = burst.colors[k % burst.colors.count]

            if let shape = burst.shape {
                context.opacity = alpha
                CosmeticShapes.draw(shape, center: CGPoint(x: x, y: y), size: size * 0.9, color: color, spin: spin, in: &context)
                continue
            }
            // An irregular four-sided chunk, cartoon style with a dark edge.
            var chunk = Path()
            for corner in 0..<4 {
                let a = spin + Double(corner) * .pi / 2 + rng.next() * 0.35
                let r = size * CGFloat(0.75 + 0.25 * abs(rng.next()))
                let p = CGPoint(x: x + r * CGFloat(cos(a)), y: y + r * CGFloat(sin(a)))
                if corner == 0 { chunk.move(to: p) } else { chunk.addLine(to: p) }
            }
            chunk.closeSubpath()
            context.opacity = alpha
            context.fill(chunk, with: .color(color))
            context.stroke(chunk, with: .color(.black.opacity(0.45)), lineWidth: 1.5)
        }

        if burst.sparkle {
            for k in 0..<(burst.scale > 1 ? 14 : 6) {
                let angle = Double(k) * 2.4 + rng.next()
                let dist = side * burst.scale * CGFloat(0.25 + 0.5 * life) * CGFloat(0.6 + 0.4 * abs(rng.next()))
                let p = CGPoint(x: origin.x + dist * CGFloat(cos(angle)), y: origin.y + dist * CGFloat(sin(angle)))
                let r = side * 0.06 * CGFloat(1 - life)
                var star = Path()
                star.move(to: CGPoint(x: p.x, y: p.y - r * 2))
                star.addQuadCurve(to: CGPoint(x: p.x + r * 2, y: p.y), control: p)
                star.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r * 2), control: p)
                star.addQuadCurve(to: CGPoint(x: p.x - r * 2, y: p.y), control: p)
                star.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r * 2), control: p)
                context.opacity = alpha
                context.fill(star, with: .color(Theme.gold))
            }
        }
        context.opacity = 1
    }

    /// A ring that grows and fades, with the skin's shape at its centre.
    private func draw(_ mark: ImpactMark, in context: inout GraphicsContext, at now: Date) {
        let t = now.timeIntervalSince(mark.born)
        guard t >= 0, t < GameFeedback.impactLife else { return }
        let life = t / GameFeedback.impactLife
        let c = center(mark.index)
        context.opacity = 1 - life
        CosmeticShapes.draw(.ring, center: c, size: side * CGFloat(0.2 + 0.35 * life), color: mark.colors[0], in: &context)
        CosmeticShapes.draw(mark.shape, center: c, size: side * CGFloat(0.22 * (1 - 0.4 * life)), color: mark.colors[mark.colors.count - 1],
                            spin: life * 2, in: &context)
        context.opacity = 1
    }
}
