import SwiftUI

/// One mineable block: material pattern, bevel, cracks, and a squash on every hit.
struct BlockView: View {
    let block: Block
    let pulse: Int
    let reducedMotion: Bool
    let collapsing: Bool
    /// Magma Depths: 0 → 1 as vents get ready to erupt.
    var ventCharge: Double = 0
    /// Magma Depths: show HP so regrowth is visible.
    var showHealth = false
    @State private var squash: CGFloat = 1

    var body: some View {
        Group {
            if block.material == .heart || block.material == .heartPart {
                // Drawn once, across all nine cells, by HeartView.
                Color.clear
            } else if block.isBroken {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: 0x100C09))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(hex: 0x2E2620), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
            } else {
                solid
                    .overlay(alignment: .bottom) {
                        if showHealth && block.hpFraction < 1 && !block.isTreasure {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.black.opacity(0.6))
                                    Capsule().fill(Theme.ember).frame(width: geo.size.width * block.hpFraction)
                                }
                            }
                            .frame(height: 4)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 6)
                            .accessibilityHidden(true)
                        }
                    }
                    .scaleEffect(squash)
            }
        }
        .onChange(of: pulse) { _ in squashOnHit() }
    }

    /// Quick squash then a bouncy return.
    private func squashOnHit() {
        guard !reducedMotion, pulse > 0 else { return }
        withAnimation(.easeOut(duration: 0.04)) { squash = 0.88 }
        Task {
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { squash = 1 }
        }
    }

    private var solid: some View {
        ZStack {
            OreArt(material: block.material, seed: block.id).equatable()
            if block.material == .vent || block.crackStage > 0 {
                Canvas { context, size in
                    if block.material == .vent { drawVentGlow(in: &context, size: size) }
                    OreRenderer.drawCracks(stage: block.crackStage, seed: block.id, in: &context, size: size)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: glowColor, radius: glowRadius)
    }

    private var glowColor: Color {
        if block.isTreasure { return Theme.gold.opacity(collapsing ? 0.9 : 0.55) }
        if block.material == .vent { return Theme.ember.opacity(0.25 + 0.6 * ventCharge) }
        return .clear
    }

    private var glowRadius: CGFloat {
        if block.isTreasure { return 10 }
        if block.material == .vent { return 4 + 10 * ventCharge }
        return 0
    }

    /// The fissure brightens as the eruption nears.
    private func drawVentGlow(in context: inout GraphicsContext, size: CGSize) {
        let s = size.width / 56
        var p = Path()
        p.move(to: CGPoint(x: 28 * s, y: 6 * s))
        p.addLine(to: CGPoint(x: 21 * s, y: 22 * s))
        p.addLine(to: CGPoint(x: 32 * s, y: 31 * s))
        p.addLine(to: CGPoint(x: 25 * s, y: 50 * s))
        context.stroke(p, with: .color(Color(hex: 0xFF6A2A).opacity(0.35 + 0.6 * ventCharge)),
                       style: StrokeStyle(lineWidth: (2.5 + 2.5 * ventCharge) * s, lineCap: .round, lineJoin: .round))
        context.stroke(p, with: .color(Color(hex: 0xFFE08A).opacity(0.2 + 0.8 * ventCharge)),
                       style: StrokeStyle(lineWidth: 1.2 * s, lineCap: .round, lineJoin: .round))
    }
}

struct FloaterView: View {
    let floater: Floater
    let reducedMotion: Bool
    @State private var risen = false

    var body: some View {
        Text(floater.text)
            .font(font)
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.8), radius: 0, x: 0, y: 2)
            .rotationEffect(.degrees(floater.kind == .crit ? -8 : 0))
            .offset(x: floater.jitter, y: risen && !reducedMotion ? -44 : -8)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) { risen = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var font: Font {
        switch floater.kind {
        case .crit: Theme.display(26)
        case .coins: Theme.body(15, .heavy)
        case .miner, .weak, .chain: Theme.body(14, .heavy)
        case .hit: Theme.display(19)
        }
    }

    private var color: Color {
        switch floater.kind {
        case .crit: Theme.crit
        case .coins: Color(hex: 0xFFD2A6)
        case .miner: Theme.minerLight
        case .chain: Color(hex: 0x9AF0F3)
        case .weak: Color(hex: 0xB9B1A8)
        case .hit: .white
        }
    }
}

/// The Heart of the Quarry: one big block across the centre 3 × 3, with its name and HP always visible.
struct HeartView: View {
    let block: Block
    let rank: Int
    let pulse: Int
    let reducedMotion: Bool
    @State private var squash: CGFloat = 1
    @State private var glow = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(RadialGradient(colors: [Color(hex: 0xFF8A3D), Color(hex: 0xA8202A), Color(hex: 0x3A0810)],
                                     center: .center, startRadius: 4, endRadius: 140))
            RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0xFF5A3D), lineWidth: 3)
            Image(systemName: "suit.heart.fill")
                .resizable().scaledToFit()
                .foregroundStyle(Color(hex: 0xFFD27A).opacity(0.9))
                .padding(44)
                .scaleEffect(glow && !reducedMotion ? 1.06 : 0.96)
            VStack {
                Text(rank == 0 ? "HEART OF THE QUARRY" : "HEART · DEPTH \(Conquest.heartArea + rank * Conquest.endlessHeartEvery)")
                    .font(Theme.body(11, .black)).tracking(0.3)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .foregroundStyle(Theme.gold)
                Spacer()
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.6))
                            Capsule().fill(Theme.ember).frame(width: geo.size.width * block.hpFraction)
                        }
                    }
                    .frame(height: 8)
                    Text("\(NumberText.format(block.hp)) / \(NumberText.format(block.maxHP))")
                        .font(Theme.body(11, .black)).monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .padding(10)
        }
        .shadow(color: Color(hex: 0xFF5A3D).opacity(glow ? 0.8 : 0.4), radius: glow ? 18 : 10)
        .scaleEffect(squash)
        .onAppear {
            guard !reducedMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true }
        }
        .onChange(of: pulse) { _ in
            guard !reducedMotion else { return }
            withAnimation(.easeOut(duration: 0.04)) { squash = 0.97 }
            Task {
                try? await Task.sleep(for: .milliseconds(40))
                withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { squash = 1 }
            }
        }
        .accessibilityHidden(true)
    }
}
