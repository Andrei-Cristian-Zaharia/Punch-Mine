import SwiftUI

/// The static art of a block, in a flat cartoon style: two-tone body, bold outlines, chunky deposits.
/// It only redraws when the material or block changes, so 30 blocks stay cheap while cracks and numbers update.
struct OreArt: View, Equatable {
    let material: Ore
    let seed: Int

    var body: some View {
        Canvas { context, size in
            OreRenderer.draw(material, seed: seed, in: &context, size: size)
        }
    }
}

/// How each material looks. Deposits carry the material's identity in shape as well as color.
private struct OreStyle {
    enum Texture { case none, dots, dashes, columns, stars }
    enum Deposit {
        case none, pebbles, nuggets, crystals, gems, rings, plates, lumps, core, embers
        case chest, geode, opal
        case coral, rune, bone, clam
    }

    /// Flat body color and the darker band along the bottom.
    var base: UInt32
    var shade: UInt32
    var texture: Texture = .dots
    var deposit: Deposit = .none
    var count = 3
    /// Main, highlight and dark side of the deposit.
    var ore: (UInt32, UInt32, UInt32) = (0, 0, 0)
    var sparkle = false

    static func of(_ m: Ore) -> OreStyle {
        switch m {
        // Pebble Quarry
        case .dirt:
            OreStyle(base: 0xB0733F, shade: 0x8A5530, deposit: .pebbles, count: 3, ore: (0xC9B8A3, 0xF2E8DA, 0x9A8872))
        case .stone:
            OreStyle(base: 0x9C958D, shade: 0x78716A, texture: .dashes)
        case .iron:
            OreStyle(base: 0x877F78, shade: 0x665F59, deposit: .nuggets, count: 3, ore: (0xE57D38, 0xFFB57A, 0xB0521C))
        case .gold:
            OreStyle(base: 0x6E6359, shade: 0x51483F, deposit: .nuggets, count: 3, ore: (0xFFC93C, 0xFFF3B0, 0xD08E14), sparkle: true)
        case .granite:
            OreStyle(base: 0x6C6577, shade: 0x504959, texture: .stars)
        case .copperOre:
            OreStyle(base: 0x8E7D70, shade: 0x6C5D52, deposit: .nuggets, count: 4, ore: (0xF2893A, 0xFFC78E, 0x3FB8A0))
        case .coal:
            OreStyle(base: 0x48433F, shade: 0x322E2B, texture: .none, deposit: .lumps, count: 3,
                     ore: (0x1A1716, 0x8E8C94, 0xFF7A3D))
        case .silver:
            OreStyle(base: 0x7A808C, shade: 0x5D636F, deposit: .nuggets, count: 3, ore: (0xC3CCD8, 0xFFFFFF, 0x8E98A8), sparkle: true)
        case .diamond:
            OreStyle(base: 0x4E5C6A, shade: 0x3A4652, deposit: .gems, count: 3, ore: (0x8FE6FF, 0xFFFFFF, 0x4FB0D6), sparkle: true)
        case .mithril:
            OreStyle(base: 0x445A7C, shade: 0x31415E, deposit: .rings, count: 4, ore: (0x9FD0FF, 0xFFFFFF, 0x5A86C8), sparkle: true)
        case .adamantite:
            OreStyle(base: 0x403454, shade: 0x2C233A, texture: .none, deposit: .plates, ore: (0x8A62F0, 0xD6C2FF, 0x5A3AB0))
        case .treasure:
            OreStyle(base: 0x4E3622, shade: 0x382616, texture: .none, deposit: .chest)
        // Crystal Caverns
        case .limestone:
            OreStyle(base: 0xD4C8AC, shade: 0xB3A688, texture: .dashes)
        case .quartz:
            OreStyle(base: 0x5EA3AA, shade: 0x467F86, texture: .none, deposit: .crystals, count: 3,
                     ore: (0xA8F6F8, 0xFFFFFF, 0x5CC2C8))
        case .amethyst:
            OreStyle(base: 0x7B55A2, shade: 0x5D3F80, texture: .none, deposit: .crystals, count: 3,
                     ore: (0xD49DFF, 0xF6E8FF, 0x9A60D8), sparkle: true)
        case .voidstone:
            OreStyle(base: 0x353A5C, shade: 0x242840, texture: .stars, deposit: .rings, count: 1,
                     ore: (0x8A62F0, 0xD0B8FF, 0x5A3AB0))
        case .geode:
            OreStyle(base: 0x7A7E86, shade: 0x5E6269, texture: .none, deposit: .geode)
        // Magma Depths
        case .basalt:
            OreStyle(base: 0x62626C, shade: 0x484850, texture: .columns)
        case .obsidian:
            OreStyle(base: 0x34294E, shade: 0x221A36, texture: .none, sparkle: true)
        case .magmaCore:
            OreStyle(base: 0x7E301C, shade: 0x5C1E10, texture: .none, deposit: .core, ore: (0xFF7A2A, 0xFFE08A, 0xD0401A))
        case .emberOre:
            OreStyle(base: 0x56423B, shade: 0x3E2E29, deposit: .embers, count: 3, ore: (0xFF9A3D, 0xFFE08A, 0xC8501A))
        case .heartstone:
            OreStyle(base: 0x721C32, shade: 0x521224, texture: .none, deposit: .gems, count: 2,
                     ore: (0xFF5A7A, 0xFFC6D2, 0xB8264C), sparkle: true)
        case .vent:
            OreStyle(base: 0x42302A, shade: 0x2E201C, texture: .none)
        case .fireOpal:
            OreStyle(base: 0x5C3219, shade: 0x40220F, texture: .none, deposit: .opal)
        case .sapphire:
            OreStyle(base: 0x2E4C8A, shade: 0x203668, texture: .none, deposit: .crystals, count: 3,
                     ore: (0x6FA8FF, 0xE4F0FF, 0x3A6CD8), sparkle: true)
        case .starstone:
            OreStyle(base: 0x1E2240, shade: 0x13162C, texture: .stars, deposit: .gems, count: 2,
                     ore: (0xFFE58A, 0xFFFFFF, 0xD8A83A), sparkle: true)
        case .brimstone:
            OreStyle(base: 0x5A4A22, shade: 0x403416, deposit: .lumps, count: 3, ore: (0xF2D03A, 0xFFF3A0, 0xB89414))
        case .dragonglass:
            OreStyle(base: 0x1C1018, shade: 0x10080E, texture: .none, deposit: .plates,
                     ore: (0xE2453A, 0xFFB0A0, 0x8E1A16), sparkle: true)
        // Sunken Ruins
        case .sand:
            OreStyle(base: 0xDCC08A, shade: 0xBC9E68, deposit: .pebbles, count: 2, ore: (0xF4ECDC, 0xFFFFFF, 0xC8B89A))
        case .coral:
            OreStyle(base: 0x3A6A8A, shade: 0x2A5070, texture: .none, deposit: .coral, ore: (0xFF7A8A, 0xFFC6CC, 0xC8485A))
        case .ruinStone:
            OreStyle(base: 0x7A968C, shade: 0x5A766C, texture: .dashes, deposit: .rings, count: 1, ore: (0x9FD8C8, 0xE0FFF4, 0x4A8070))
        case .runestone:
            OreStyle(base: 0x3A5A6E, shade: 0x2A4050, texture: .none, deposit: .rune, ore: (0x5FF0E0, 0xE8FFFC, 0x1FA8A0))
        case .abyssite:
            OreStyle(base: 0x24385A, shade: 0x182640, texture: .stars, deposit: .gems, count: 2,
                     ore: (0x4F8AFF, 0xD6E6FF, 0x2A4CB0), sparkle: true)
        case .leviathanBone:
            OreStyle(base: 0x2E4A5E, shade: 0x203644, texture: .none, deposit: .bone, ore: (0xEDE4CA, 0xFFFFFF, 0xB8AC8C))
        case .pearlClam:
            OreStyle(base: 0x2E5470, shade: 0x203E56, texture: .none, deposit: .clam)
        case .heart, .heartPart:
            OreStyle(base: 0x5A0E14, shade: 0x3A060C, texture: .none)
        }
    }
}

enum OreRenderer {
    /// Outline color used on every block and deposit.
    private static let ink: UInt32 = 0x1A120E

    private struct Painter {
        var context: GraphicsContext
        let s: CGFloat
        var rng: SplitMix64

        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }
        mutating func rand(_ range: ClosedRange<Double>) -> Double { Double.random(in: range, using: &rng) }
        func c(_ hex: UInt32, _ opacity: Double = 1) -> GraphicsContext.Shading { .color(Color(hex: hex, opacity: opacity)) }

        /// Fill, then a bold outline: the core of the cartoon look.
        func inked(_ path: Path, _ fill: UInt32, width: Double = 1.6) {
            context.fill(path, with: c(fill))
            context.stroke(path, with: c(OreRenderer.ink), style: StrokeStyle(lineWidth: width * s, lineJoin: .round))
        }
    }

    static func draw(_ m: Ore, seed: Int, in context: inout GraphicsContext, size: CGSize) {
        let style = OreStyle.of(m)
        let rect = CGRect(origin: .zero, size: size)
        let body = Path(roundedRect: rect, cornerRadius: 10)
        var pt = Painter(context: context, s: size.width / 56,
                         rng: SplitMix64(seed: UInt64(seed + 1) &* 0x9E37_79B9 &+ stableHash(m.rawValue)))

        // Two-tone body: flat color with a hard-edged darker band at the bottom
        pt.context.fill(body, with: pt.c(style.base))
        pt.context.clip(to: body)
        pt.context.fill(Path(pt.r(0, 41, 56, 15)), with: pt.c(style.shade))

        drawTexture(style, &pt)
        if m == .obsidian { drawObsidian(&pt) }
        if m == .vent { drawVentBase(&pt) }
        drawDeposit(style, m, &pt)

        // Shine in the top-left corner
        pt.context.fill(Path(roundedRect: pt.r(7, 5, 16, 4), cornerRadius: 2 * pt.s), with: .color(.white.opacity(0.28)))
        pt.context.fill(Path(ellipseIn: pt.r(25, 5, 4, 4)), with: .color(.white.opacity(0.28)))
        if m.baseArmor > 0 { drawArmorRim(&pt, size: size) }

        pt.context.stroke(Path(roundedRect: rect.insetBy(dx: 1.3, dy: 1.3), cornerRadius: 9),
                          with: pt.c(ink), lineWidth: 2.6)
        context = pt.context
    }

    // MARK: - Layers

    private static func drawTexture(_ st: OreStyle, _ pt: inout Painter) {
        switch st.texture {
        case .none:
            break
        case .dots:
            for _ in 0..<4 {
                let x = pt.rand(8...46), y = pt.rand(10...44), d = pt.rand(2.5...3.5)
                pt.context.fill(Path(ellipseIn: pt.r(x, y, d, d)), with: pt.c(st.shade))
            }
        case .dashes:
            for (x, y, w) in [(10.0, 16.0, 12.0), (30, 26, 16), (14, 36, 10)] {
                var dash = Path()
                dash.move(to: pt.p(x + pt.rand(-2...2), y)); dash.addLine(to: pt.p(x + w, y + pt.rand(-1...1)))
                pt.context.stroke(dash, with: pt.c(st.shade), style: StrokeStyle(lineWidth: 2.6 * pt.s, lineCap: .round))
            }
        case .stars:
            for i in 0..<8 {
                let x = pt.rand(8...46), y = pt.rand(10...44), d = pt.rand(2.4...3.4)
                pt.context.fill(Path(ellipseIn: pt.r(x, y, d, d)), with: pt.c(i % 2 == 0 ? 0xF0E8F8 : 0xC890A0, 0.85))
            }
        case .columns:
            for (cx, cy) in [(16.0, 18.0), (38, 18), (27, 33)] {
                var hex = Path()
                for k in 0..<6 {
                    let a = Double(k) * .pi / 3
                    let pnt = pt.p(cx + cos(a) * 9, cy + sin(a) * 8)
                    if k == 0 { hex.move(to: pnt) } else { hex.addLine(to: pnt) }
                }
                hex.closeSubpath()
                pt.context.stroke(hex, with: pt.c(st.shade), lineWidth: 2.4 * pt.s)
            }
        }
    }

    /// Deposit positions. Three deposits use off-centre layouts (never two-on-top, one-below, which reads as a face).
    private static func slots(_ n: Int, variant: Int = 0) -> [(Double, Double)] {
        switch n {
        case 1: return [(28, 26)]
        case 2: return [(19, 20), (37, 34)]
        case 3:
            let layouts: [[(Double, Double)]] = [
                [(14, 16), (36, 24), (21, 39)],
                [(38, 14), (17, 26), (37, 39)],
                [(16, 37), (26, 14), (40, 30)],
            ]
            return layouts[variant % layouts.count]
        default: return [(16, 18), (38, 16), (18, 37), (39, 36)]
        }
    }

    private static func drawDeposit(_ st: OreStyle, _ m: Ore, _ pt: inout Painter) {
        let (main, light, dark) = st.ore
        let variant = Int(pt.rand(0...2.999))
        func slots(_ n: Int) -> [(Double, Double)] { OreRenderer.slots(n, variant: variant) }
        switch st.deposit {
        case .none:
            break
        case .pebbles:
            for (x, y) in slots(st.count) {
                let w = pt.rand(8...10), h = w * 0.7
                let pebble = Path(ellipseIn: pt.r(x - w / 2, y - h / 2, w, h))
                pt.inked(pebble, main, width: 1.3)
                pt.context.fill(Path(ellipseIn: pt.r(x - w / 4, y - h / 3, w / 3, h / 4)), with: pt.c(light))
            }
        case .nuggets:
            for (i, (x, y)) in slots(st.count).enumerated() {
                let radius = (m == .copperOre ? 5.0 : 7.0) + pt.rand(-0.5...1)
                let cx = x + pt.rand(-2...2), cy = y + pt.rand(-2...2)
                if m == .copperOre && i == 3 {
                    // One teal patina chip for copper
                    pt.inked(blob(cx: cx, cy: cy, radius: 3.6, &pt), dark, width: 1.2)
                    continue
                }
                let shape = blob(cx: cx, cy: cy, radius: radius, &pt)
                pt.inked(shape, main)
                pt.context.fill(Path(ellipseIn: pt.r(cx - radius * 0.55, cy - radius * 0.55, radius * 0.6, radius * 0.4)),
                                with: pt.c(light))
            }
        case .crystals:
            let base = 46.0
            for (x, height, lean) in [(12.0, 22.0, -0.25), (23, 30, 0.05), (34, 22, 0.3)] {
                drawCrystal(x: x, base: base, width: 10, height: height + pt.rand(-2...2), lean: lean, colors: st.ore, &pt)
            }
        case .gems:
            for (x, y) in slots(st.count) {
                drawGem(cx: x + pt.rand(-1.5...1.5), cy: y + pt.rand(-1.5...1.5), size: 13, colors: st.ore, &pt)
            }
        case .rings:
            let centers: [(Double, Double)] = st.count == 1 ? [(28, 27)] : [(19, 21), (31, 21), (25, 32), (37, 32)]
            for (x, y) in centers {
                let radius = st.count == 1 ? 12.0 : 6.5
                let ring = Path(ellipseIn: pt.r(x - radius, y - radius, radius * 2, radius * 2))
                pt.context.stroke(ring, with: pt.c(ink), lineWidth: 4.6 * pt.s)
                pt.context.stroke(ring, with: pt.c(main), lineWidth: 2.6 * pt.s)
                var arc = Path()
                arc.addArc(center: pt.p(x, y), radius: radius * pt.s, startAngle: .degrees(205), endAngle: .degrees(275), clockwise: false)
                pt.context.stroke(arc, with: pt.c(light), style: StrokeStyle(lineWidth: 1.3 * pt.s, lineCap: .round))
            }
        case .plates:
            for (i, rect) in [(8.0, 9.0, 21.0, 18.0), (27, 11, 21, 18), (10, 29, 20, 15), (28, 30, 20, 14)].enumerated() {
                let plate = Path(roundedRect: pt.r(rect.0, rect.1, rect.2, rect.3), cornerRadius: 3 * pt.s)
                pt.inked(plate, i % 2 == 0 ? 0x5A4878 : 0x4E3E6A)
                pt.context.stroke(Path(roundedRect: pt.r(rect.0 + 2, rect.1 + 2, rect.2 - 4, rect.3 - 4), cornerRadius: 2 * pt.s),
                                  with: pt.c(main, 0.7), lineWidth: 1 * pt.s)
                for (rx, ry) in [(rect.0 + 3.5, rect.1 + 3.5), (rect.0 + rect.2 - 3.5, rect.1 + rect.3 - 3.5)] {
                    pt.inked(Path(ellipseIn: pt.r(rx - 1.8, ry - 1.8, 3.6, 3.6)), light, width: 1)
                }
            }
        case .lumps:
            for (x, y) in slots(st.count) {
                let radius = pt.rand(6.5...8)
                let shape = blob(cx: x, cy: y, radius: radius, &pt)
                pt.context.fill(shape, with: pt.c(main))
                pt.context.stroke(shape, with: pt.c(0x5A5652), lineWidth: 1.3 * pt.s)
                var glint = Path()
                glint.move(to: pt.p(x - radius * 0.5, y - radius * 0.15))
                glint.addLine(to: pt.p(x - radius * 0.15, y - radius * 0.55))
                pt.context.stroke(glint, with: pt.c(light), style: StrokeStyle(lineWidth: 1.6 * pt.s, lineCap: .round))
            }
            let (ex, ey) = slots(st.count)[1]
            pt.inked(Path(ellipseIn: pt.r(ex + 1, ey, 4.5, 4.5)), dark, width: 1)
        case .core:
            pt.inked(Path(ellipseIn: pt.r(12, 10, 32, 32)), dark, width: 1.8)
            pt.context.fill(Path(ellipseIn: pt.r(16, 14, 24, 24)), with: pt.c(main))
            pt.context.fill(Path(ellipseIn: pt.r(21, 19, 14, 14)), with: pt.c(light))
            pt.context.fill(Path(ellipseIn: pt.r(22, 20, 5, 4)), with: .color(.white.opacity(0.7)))
        case .embers:
            for (x, y) in slots(st.count) {
                let h = 13.0, w = 11.0
                var tri = Path()
                tri.move(to: pt.p(x, y - h / 2)); tri.addLine(to: pt.p(x + w / 2, y + h / 2)); tri.addLine(to: pt.p(x - w / 2, y + h / 2))
                tri.closeSubpath()
                pt.context.fill(tri, with: pt.c(main))
                var shadeSide = Path()
                shadeSide.move(to: pt.p(x, y - h / 2)); shadeSide.addLine(to: pt.p(x + w / 2, y + h / 2)); shadeSide.addLine(to: pt.p(x, y + h / 2))
                shadeSide.closeSubpath()
                pt.context.fill(shadeSide, with: pt.c(dark))
                pt.context.stroke(tri, with: pt.c(ink), style: StrokeStyle(lineWidth: 1.5 * pt.s, lineJoin: .round))
                var shine = Path()
                shine.move(to: pt.p(x - 1, y - h * 0.15)); shine.addLine(to: pt.p(x - w * 0.22, y + h * 0.3))
                pt.context.stroke(shine, with: pt.c(light), style: StrokeStyle(lineWidth: 1.6 * pt.s, lineCap: .round))
            }
        case .chest:
            drawChest(&pt)
        case .coral:
            // Branching coral: a trunk with forked arms, rounded tips.
            let branches: [[(Double, Double)]] = [[(28, 47), (28, 30), (20, 20), (18, 10)], [(28, 30), (36, 20), (38, 9)],
                                                   [(22, 23), (12, 18)], [(34, 23), (45, 17)], [(28, 38), (40, 34)]]
            for width in [7.0, 4.4] {
                for b in branches {
                    var path = Path()
                    path.move(to: pt.p(b[0].0, b[0].1))
                    for q in b.dropFirst() { path.addLine(to: pt.p(q.0, q.1)) }
                    pt.context.stroke(path, with: pt.c(width > 5 ? ink : main),
                                      style: StrokeStyle(lineWidth: width * pt.s, lineCap: .round, lineJoin: .round))
                }
            }
            for (x, y) in [(18.0, 10.0), (38, 9), (12, 18), (45, 17)] {
                pt.context.fill(Path(ellipseIn: pt.r(x - 1.4, y - 1.4, 2.8, 2.8)), with: pt.c(light))
            }
        case .rune:
            // A carved tablet with a glowing glyph.
            pt.inked(Path(roundedRect: pt.r(13, 9, 30, 36), cornerRadius: 4 * pt.s), dark, width: 1.6)
            pt.context.fill(Path(roundedRect: pt.r(16, 12, 24, 30), cornerRadius: 3 * pt.s), with: pt.c(0x1C3240))
            var glyph = Path()
            glyph.move(to: pt.p(28, 15)); glyph.addLine(to: pt.p(28, 39))
            glyph.move(to: pt.p(28, 21)); glyph.addLine(to: pt.p(20, 28)); glyph.addLine(to: pt.p(28, 33))
            glyph.move(to: pt.p(28, 21)); glyph.addLine(to: pt.p(36, 28)); glyph.addLine(to: pt.p(28, 33))
            pt.context.stroke(glyph, with: pt.c(main, 0.35), style: StrokeStyle(lineWidth: 5.5 * pt.s, lineCap: .round, lineJoin: .round))
            pt.context.stroke(glyph, with: pt.c(light), style: StrokeStyle(lineWidth: 2 * pt.s, lineCap: .round, lineJoin: .round))
        case .bone:
            // A great curved rib with a knobbed end.
            var rib = Path()
            rib.move(to: pt.p(10, 44)); rib.addQuadCurve(to: pt.p(44, 12), control: pt.p(14, 14))
            pt.context.stroke(rib, with: pt.c(ink), style: StrokeStyle(lineWidth: 11 * pt.s, lineCap: .round))
            pt.context.stroke(rib, with: pt.c(main), style: StrokeStyle(lineWidth: 7.5 * pt.s, lineCap: .round))
            for (x, y) in [(41.0, 9.0), (47, 15)] { pt.inked(Path(ellipseIn: pt.r(x - 4, y - 4, 8, 8)), main, width: 1.4) }
            var shadow = Path()
            shadow.move(to: pt.p(14, 42)); shadow.addQuadCurve(to: pt.p(42, 16), control: pt.p(19, 19))
            pt.context.stroke(shadow, with: pt.c(dark), style: StrokeStyle(lineWidth: 2 * pt.s, lineCap: .round))
            var shine = Path()
            shine.move(to: pt.p(12, 38)); shine.addQuadCurve(to: pt.p(30, 15), control: pt.p(13, 20))
            pt.context.stroke(shine, with: pt.c(light), style: StrokeStyle(lineWidth: 1.6 * pt.s, lineCap: .round))
        case .clam:
            // Giant clam: two ridged shells, open, with a pearl.
            var lower = Path()
            lower.move(to: pt.p(8, 30)); lower.addQuadCurve(to: pt.p(48, 30), control: pt.p(28, 56)); lower.closeSubpath()
            pt.inked(lower, 0xE8B8C8, width: 1.8)
            var upper = Path()
            upper.move(to: pt.p(8, 28)); upper.addQuadCurve(to: pt.p(48, 28), control: pt.p(28, 2)); upper.closeSubpath()
            pt.inked(upper, 0xF4CCD8, width: 1.8)
            for x in [16.0, 22, 28, 34, 40] {
                var ridge = Path()
                ridge.move(to: pt.p(28, 27)); ridge.addLine(to: pt.p(x, 27 - 12 + abs(x - 28) * 0.5))
                pt.context.stroke(ridge, with: pt.c(0xC88898), lineWidth: 1.2 * pt.s)
            }
            pt.inked(Path(ellipseIn: pt.r(22, 28, 12, 12)), 0xF8F8FF, width: 1.4)
            pt.context.fill(Path(ellipseIn: pt.r(25, 30, 4, 3)), with: .color(.white))
            drawSparkle(x: 44, y: 12, size: 4.5, &pt)
        case .geode:
            pt.inked(Path(ellipseIn: pt.r(8, 8, 40, 40)), 0x9A9EA6, width: 1.8)
            pt.inked(Path(ellipseIn: pt.r(14, 14, 28, 28)), 0x1C6E73, width: 1.4)
            for (x, h, lean) in [(17.0, 14.0, -0.3), (24, 18, 0.0), (31, 13, 0.3)] {
                drawCrystal(x: x, base: 38, width: 8, height: h, lean: lean, colors: (0xA8F6F8, 0xFFFFFF, 0x5CC2C8), &pt)
            }
        case .opal:
            // Four flat facets in different fire colors
            let top = pt.p(28, 9), right = pt.p(46, 26), bottom = pt.p(28, 47), left = pt.p(10, 26), center = pt.p(28, 26)
            for (a, b, color) in [(top, right, 0xFFC24A as UInt32), (right, bottom, 0xFF5A3D), (bottom, left, 0xE23A7A), (left, top, 0x5FD0C8)] {
                var facet = Path()
                facet.move(to: center); facet.addLine(to: a); facet.addLine(to: b); facet.closeSubpath()
                pt.context.fill(facet, with: pt.c(color))
            }
            var outline = Path()
            outline.move(to: top); outline.addLine(to: right); outline.addLine(to: bottom); outline.addLine(to: left); outline.closeSubpath()
            pt.context.stroke(outline, with: pt.c(ink), style: StrokeStyle(lineWidth: 2 * pt.s, lineJoin: .round))
            pt.context.fill(Path(ellipseIn: pt.r(20, 16, 6, 4)), with: .color(.white.opacity(0.75)))
        }
        if st.sparkle {
            drawSparkle(x: pt.rand(38...46), y: pt.rand(9...14), size: 4.5, &pt)
        }
    }

    private static func drawObsidian(_ pt: inout Painter) {
        var stripe = Path()
        stripe.move(to: pt.p(10, 46)); stripe.addLine(to: pt.p(32, 8)); stripe.addLine(to: pt.p(40, 8)); stripe.addLine(to: pt.p(18, 46))
        stripe.closeSubpath()
        pt.context.fill(stripe, with: .color(.white.opacity(0.16)))
        var thin = Path()
        thin.move(to: pt.p(24, 46)); thin.addLine(to: pt.p(44, 12))
        pt.context.stroke(thin, with: .color(.white.opacity(0.16)), style: StrokeStyle(lineWidth: 2.4 * pt.s, lineCap: .round))
    }

    private static func drawVentBase(_ pt: inout Painter) {
        var fissure = Path()
        fissure.move(to: pt.p(28, 6)); fissure.addLine(to: pt.p(21, 22)); fissure.addLine(to: pt.p(32, 31)); fissure.addLine(to: pt.p(25, 50))
        pt.context.stroke(fissure, with: pt.c(ink), style: StrokeStyle(lineWidth: 7 * pt.s, lineCap: .round, lineJoin: .round))
    }

    /// Armored blocks get a light inner rim, so they read as "needs penetration" at a glance.
    private static func drawArmorRim(_ pt: inout Painter, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
        pt.context.stroke(Path(roundedRect: rect, cornerRadius: 7), with: .color(.white.opacity(0.32)), lineWidth: 1.6)
    }

    // MARK: - Shapes

    /// A slightly lumpy round shape, so nuggets look chunky rather than like perfect circles.
    private static func blob(cx: Double, cy: Double, radius: Double, _ pt: inout Painter) -> Path {
        let n = 6
        var points: [CGPoint] = []
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi + 0.3
            let rr = radius * pt.rand(0.9...1.08)
            points.append(pt.p(cx + cos(a) * rr, cy + sin(a) * rr * 0.88))
        }
        var path = Path()
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(points[n - 1], points[0]))
        for i in 0..<n { path.addQuadCurve(to: mid(points[i], points[(i + 1) % n]), control: points[i]) }
        path.closeSubpath()
        return path
    }

    private static func drawCrystal(x: Double, base: Double, width: Double, height: Double, lean: Double,
                                    colors: (UInt32, UInt32, UInt32), _ pt: inout Painter) {
        let (main, light, dark) = colors
        let tipX = x + width / 2 + lean * height
        let shoulder = base - height * 0.75
        let midX = x + width / 2
        var left = Path()
        left.move(to: pt.p(x, base)); left.addLine(to: pt.p(x + lean * height * 0.75, shoulder))
        left.addLine(to: pt.p(tipX, base - height)); left.addLine(to: pt.p(midX + lean * height * 0.75, shoulder))
        left.addLine(to: pt.p(midX, base)); left.closeSubpath()
        var right = Path()
        right.move(to: pt.p(midX, base)); right.addLine(to: pt.p(midX + lean * height * 0.75, shoulder))
        right.addLine(to: pt.p(tipX, base - height)); right.addLine(to: pt.p(x + width + lean * height * 0.75, shoulder))
        right.addLine(to: pt.p(x + width, base)); right.closeSubpath()
        pt.context.fill(left, with: pt.c(main))
        pt.context.fill(right, with: pt.c(dark))
        var stripe = Path()
        stripe.move(to: pt.p(x + 2.2, base - 2)); stripe.addLine(to: pt.p(x + 2.2 + lean * height * 0.7, shoulder + 2))
        pt.context.stroke(stripe, with: pt.c(light), style: StrokeStyle(lineWidth: 1.6 * pt.s, lineCap: .round))
        var outline = Path()
        outline.move(to: pt.p(x, base)); outline.addLine(to: pt.p(x + lean * height * 0.75, shoulder))
        outline.addLine(to: pt.p(tipX, base - height)); outline.addLine(to: pt.p(x + width + lean * height * 0.75, shoulder))
        outline.addLine(to: pt.p(x + width, base)); outline.closeSubpath()
        pt.context.stroke(outline, with: pt.c(ink), style: StrokeStyle(lineWidth: 1.5 * pt.s, lineJoin: .round))
    }

    private static func drawGem(cx: Double, cy: Double, size: Double, colors: (UInt32, UInt32, UInt32), _ pt: inout Painter) {
        let (main, light, dark) = colors
        let w = size, h = size * 0.92
        let top = cy - h / 2, girdle = cy - h * 0.1, bottom = cy + h / 2
        var crown = Path()
        crown.move(to: pt.p(cx - w * 0.28, top)); crown.addLine(to: pt.p(cx + w * 0.28, top))
        crown.addLine(to: pt.p(cx + w / 2, girdle)); crown.addLine(to: pt.p(cx - w / 2, girdle)); crown.closeSubpath()
        var pavilion = Path()
        pavilion.move(to: pt.p(cx - w / 2, girdle)); pavilion.addLine(to: pt.p(cx + w / 2, girdle)); pavilion.addLine(to: pt.p(cx, bottom))
        pavilion.closeSubpath()
        var pavilionShade = Path()
        pavilionShade.move(to: pt.p(cx, girdle)); pavilionShade.addLine(to: pt.p(cx + w / 2, girdle)); pavilionShade.addLine(to: pt.p(cx, bottom))
        pavilionShade.closeSubpath()
        pt.context.fill(crown, with: pt.c(light))
        pt.context.fill(pavilion, with: pt.c(main))
        pt.context.fill(pavilionShade, with: pt.c(dark))
        var outline = Path()
        outline.move(to: pt.p(cx - w * 0.28, top)); outline.addLine(to: pt.p(cx + w * 0.28, top))
        outline.addLine(to: pt.p(cx + w / 2, girdle)); outline.addLine(to: pt.p(cx, bottom))
        outline.addLine(to: pt.p(cx - w / 2, girdle)); outline.closeSubpath()
        outline.move(to: pt.p(cx - w / 2, girdle)); outline.addLine(to: pt.p(cx + w / 2, girdle))
        pt.context.stroke(outline, with: pt.c(ink), style: StrokeStyle(lineWidth: 1.5 * pt.s, lineJoin: .round))
    }

    private static func drawSparkle(x: Double, y: Double, size: Double, _ pt: inout Painter) {
        var star = Path()
        star.move(to: pt.p(x, y - size)); star.addLine(to: pt.p(x + size * 0.28, y - size * 0.28))
        star.addLine(to: pt.p(x + size, y)); star.addLine(to: pt.p(x + size * 0.28, y + size * 0.28))
        star.addLine(to: pt.p(x, y + size)); star.addLine(to: pt.p(x - size * 0.28, y + size * 0.28))
        star.addLine(to: pt.p(x - size, y)); star.addLine(to: pt.p(x - size * 0.28, y - size * 0.28))
        star.closeSubpath()
        pt.context.fill(star, with: .color(.white))
    }

    private static func drawChest(_ pt: inout Painter) {
        let body = Path(roundedRect: pt.r(10, 25, 36, 20), cornerRadius: 3 * pt.s)
        pt.inked(body, 0xB8763A, width: 1.8)
        var lid = Path()
        lid.move(to: pt.p(10, 26)); lid.addLine(to: pt.p(10, 20))
        lid.addQuadCurve(to: pt.p(46, 20), control: pt.p(28, 7)); lid.addLine(to: pt.p(46, 26)); lid.closeSubpath()
        pt.inked(lid, 0xD58E4A, width: 1.8)
        for x in [16.0, 40] {
            pt.inked(Path(pt.r(x - 2, 14, 4, 31)), 0xFFC93C, width: 1.2)
        }
        let lock = Path(roundedRect: pt.r(24, 22, 8, 10), cornerRadius: 2 * pt.s)
        pt.inked(lock, 0xFFE07A, width: 1.4)
        pt.context.fill(Path(ellipseIn: pt.r(26.8, 25, 2.4, 2.4)), with: pt.c(ink))
        drawSparkle(x: 42, y: 11, size: 4, &pt)
    }

    // MARK: - Cracks (drawn live, on top of the art)

    /// Bold cartoon cracks that differ per block; each stage adds branches.
    static func drawCracks(stage: Int, seed: Int, in context: inout GraphicsContext, size: CGSize) {
        guard stage > 0 else { return }
        let s = size.width / 56
        var rng = SplitMix64(seed: UInt64(seed + 7) &* 0x2545_F491)
        func j(_ r: Double) -> Double { Double.random(in: -r...r, using: &rng) }
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }

        var points = [(28 + j(8), 3.0)]
        for k in 1...min(stage * 2, 5) {
            let last = points[k - 1]
            points.append((last.0 + j(7), last.1 + 10 + j(2)))
        }
        var crack = Path()
        crack.move(to: p(points[0].0, points[0].1))
        for pnt in points.dropFirst() { crack.addLine(to: p(pnt.0, pnt.1)) }
        if stage >= 2 {
            let a = points[min(1, points.count - 1)]
            crack.move(to: p(a.0, a.1)); crack.addLine(to: p(a.0 - 12 + j(3), a.1 + 4 + j(3)))
        }
        if stage >= 3 {
            let b = points[min(2, points.count - 1)]
            crack.move(to: p(b.0, b.1)); crack.addLine(to: p(b.0 + 14 + j(3), b.1 + 2 + j(3)))
            let c = points[min(3, points.count - 1)]
            crack.move(to: p(c.0, c.1)); crack.addLine(to: p(c.0 - 10 + j(3), c.1 + 8 + j(3)))
        }
        context.stroke(crack, with: .color(Color(hex: 0x120C0A)),
                       style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round, lineJoin: .round))
    }

    /// Stable across launches (Swift's `hashValue` is not).
    private static func stableHash(_ text: String) -> UInt64 {
        text.unicodeScalars.reduce(1469598103934665603) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
    }
}

#if DEBUG
/// Debug gallery of every material, for reviewing the art. Launch with `-debugScreen ores`.
struct OreGalleryView: View {
    private let ores = Ore.allCases.filter { $0 != .heart && $0 != .heartPart }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                ForEach(Array(ores.enumerated()), id: \.offset) { i, ore in
                    VStack(spacing: 4) {
                        ZStack {
                            OreArt(material: ore, seed: i * 7)
                            if i % 4 == 3 {
                                Canvas { context, size in
                                    OreRenderer.drawCracks(stage: 2, seed: i, in: &context, size: size)
                                }
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text(ore.displayName)
                            .font(Theme.body(10, .heavy))
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.ground.ignoresSafeArea())
    }
}
#endif

extension Ore {
    /// Chunk colors for the break debris: body, shadow and the ore deposit (when there is one).
    var debrisColors: [Color] {
        let style = OreStyle.of(self)
        var colors = [Color(hex: style.base), Color(hex: style.shade)]
        if style.ore.0 != 0 { colors.append(Color(hex: style.ore.0)) }
        return colors
    }
}
