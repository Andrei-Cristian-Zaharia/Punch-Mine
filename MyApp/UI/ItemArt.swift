import SwiftUI

/// Cartoon icon for an item, matching the ore art: flat colors, bold dark outlines, one shine.
struct ItemArt: View, Equatable {
    let itemID: String

    var body: some View {
        Canvas { context, size in
            ItemPainter(context: context, s: min(size.width, size.height) / 56).draw(itemID)
        }
    }
}

private struct ItemPainter {
    var context: GraphicsContext
    let s: CGFloat
    let ink = Color(hex: 0x1A120E)

    // MARK: Primitives (coordinates on a 56 × 56 grid)

    func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
    func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }
    func poly(_ pts: [(Double, Double)]) -> Path {
        var path = Path()
        path.move(to: p(pts[0].0, pts[0].1))
        for pt in pts.dropFirst() { path.addLine(to: p(pt.0, pt.1)) }
        path.closeSubpath()
        return path
    }
    /// An open path for strokes (no line back to the start).
    func open(_ pts: [(Double, Double)]) -> Path {
        var path = Path()
        path.move(to: p(pts[0].0, pts[0].1))
        for pt in pts.dropFirst() { path.addLine(to: p(pt.0, pt.1)) }
        return path
    }
    func circle(_ x: Double, _ y: Double, _ radius: Double) -> Path { Path(ellipseIn: r(x - radius, y - radius, radius * 2, radius * 2)) }
    func rounded(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: Double) -> Path {
        Path(roundedRect: r(x, y, w, h), cornerRadius: c * s)
    }
    func fill(_ path: Path, _ hex: UInt32, _ opacity: Double = 1) { context.fill(path, with: .color(Color(hex: hex, opacity: opacity))) }
    func line(_ path: Path, _ hex: UInt32, _ width: Double, opacity: Double = 1) {
        context.stroke(path, with: .color(Color(hex: hex, opacity: opacity)),
                       style: StrokeStyle(lineWidth: width * s, lineCap: .round, lineJoin: .round))
    }
    /// Fill plus bold outline.
    func inked(_ path: Path, _ hex: UInt32, _ width: Double = 2) {
        fill(path, hex)
        context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: width * s, lineJoin: .round))
    }
    func shine(_ x: Double, _ y: Double, _ w: Double = 6, _ h: Double = 3) {
        context.fill(Path(ellipseIn: r(x, y, w, h)), with: .color(.white.opacity(0.6)))
    }
    func sparkle(_ x: Double, _ y: Double, _ size: Double = 4) {
        let k = size * 0.28
        fill(poly([(x, y - size), (x + k, y - k), (x + size, y), (x + k, y + k), (x, y + size), (x - k, y + k), (x - size, y), (x - k, y - k)]), 0xFFFFFF)
    }

    // MARK: Items

    func draw(_ id: String) {
        switch id {
        // Helmets
        case "minersHelmet":
            fill(poly([(34, 18), (54, 10), (54, 30), (34, 25)]), 0xFFF6C8, 0.45)
            var dome = Path(); dome.move(to: p(9, 38)); dome.addQuadCurve(to: p(47, 38), control: p(28, -12)); dome.closeSubpath()
            inked(dome, 0xFFC93C)
            inked(rounded(5, 34, 46, 8, 4), 0xE0A020)
            inked(circle(28, 21, 6.5), 0xFFFFFF)
            fill(circle(28, 21, 3.5), 0xFFF0A0)
            shine(14, 24, 5, 3)
        case "hardHat":
            var dome = Path(); dome.move(to: p(9, 37)); dome.addQuadCurve(to: p(47, 37), control: p(28, -12)); dome.closeSubpath()
            inked(dome, 0xFF8A3D)
            inked(rounded(24, 12, 8, 24, 4), 0xFFB070, 1.6)
            inked(rounded(3, 34, 50, 8, 4), 0xE0702A)
            shine(14, 24, 5, 3)
        case "lanternCap":
            fill(circle(28, 12, 11), 0xFFE08A, 0.35)
            line(Path { $0.addArc(center: p(28, 9), radius: 4 * s, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }, 0x1A120E, 2)
            inked(rounded(23, 9, 10, 11, 2), 0xFFE08A, 1.8)
            fill(circle(28, 14.5, 2.5), 0xFFFFFF)
            var cap = Path(); cap.move(to: p(10, 40)); cap.addQuadCurve(to: p(46, 40), control: p(28, 2)); cap.closeSubpath()
            inked(cap, 0x8A5A30)
            inked(rounded(8, 37, 40, 7, 3.5), 0x6A4020)
        case "crownOfEmbers":
            for (x, y) in [(10.0, 15.0), (28, 8), (46, 15)] {
                var flame = Path(); flame.move(to: p(x, y - 7)); flame.addQuadCurve(to: p(x, y + 4), control: p(x + 7, y))
                flame.addQuadCurve(to: p(x, y - 7), control: p(x - 7, y)); inked(flame, 0xFFD27A, 1.4)
            }
            inked(poly([(9, 44), (9, 19), (19, 29), (28, 13), (37, 29), (47, 19), (47, 44)]), 0xFF7A2D)
            inked(rounded(8, 36, 40, 10, 3), 0xE0402A)
            for x in [17.0, 28, 39] { inked(circle(x, 41, 2.6), 0xFFE08A, 1.2) }
        case "seersVisor":
            inked(rounded(4, 20, 48, 18, 9), 0x6A3FB0)
            var eye = Path(); eye.move(to: p(13, 29)); eye.addQuadCurve(to: p(43, 29), control: p(28, 17))
            eye.addQuadCurve(to: p(13, 29), control: p(28, 41)); inked(eye, 0xFFFFFF, 1.6)
            inked(circle(28, 29, 6), 0xB06CFF, 1.4)
            fill(circle(28, 29, 2.6), 0x1A120E)
            fill(circle(26, 27, 1.3), 0xFFFFFF)
            sparkle(46, 12, 4)
        // Belts
        case "toolBelt":
            line(open([(13, 28), (11, 46)]), 0x1A120E, 6); line(open([(13, 28), (11, 46)]), 0xA8B0BC, 3.5)
            inked(circle(11, 47, 4), 0xA8B0BC, 1.6)
            line(open([(41, 28), (43, 44)]), 0x1A120E, 5); line(open([(41, 28), (43, 44)]), 0xB8763A, 2.8)
            inked(rounded(36, 42, 14, 7, 2), 0x7A808C, 1.6)
            inked(rounded(3, 17, 50, 12, 4), 0x8A5530)
            fill(rounded(22, 14, 12, 18, 3), 0x8A5530)
            context.stroke(rounded(22, 14, 12, 18, 3), with: .color(Color(hex: 0xFFC93C)), lineWidth: 3.5 * s)
            context.stroke(rounded(22, 14, 12, 18, 3), with: .color(ink), lineWidth: 1.2 * s)
        case "coinPouch":
            inked(Path(ellipseIn: r(11, 21, 32, 29)), 0xC8A060)
            inked(rounded(20, 14, 14, 10, 4), 0xB08848, 1.8)
            line(open([(19, 24), (35, 24)]), 0x6A4020, 2.4)
            for (x, y) in [(42.0, 44.0), (47, 37)] { inked(circle(x, y, 5), 0xFFC93C, 1.6); fill(circle(x, y, 2), 0xD08E14) }
            shine(17, 27, 6, 4)
        case "luckySash":
            inked(poly([(5, 15), (15, 6), (51, 41), (41, 50)]), 0x3FB070)
            for (dx, dy) in [(-5.0, 0.0), (5, 0), (0, -5), (0, 5)] { inked(circle(28 + dx, 28 + dy, 5.5), 0x8FE070, 1.4) }
            fill(circle(28, 28, 3), 0x8FE070)
            line(open([(29, 32), (33, 40)]), 0x1A120E, 2)
            sparkle(44, 14, 4)
        case "bandolier":
            inked(poly([(3, 13), (11, 6), (53, 41), (45, 48)]), 0x6A4A2A)
            for (i, x) in [12.0, 23, 34].enumerated() {
                let y = 15 + Double(i) * 8
                inked(rounded(x, y, 8, 20, 2), 0xE0402A, 1.8)
                fill(rounded(x, y + 4, 8, 3, 0), 0xFFC24A)
                line(Path { $0.move(to: p(x + 4, y)); $0.addQuadCurve(to: p(x + 8, y - 6), control: p(x + 2, y - 4)) }, 0x1A120E, 1.6)
                fill(circle(x + 8, y - 6, 2), 0xFFD23C)
            }
        case "titanBelt":
            inked(rounded(2, 18, 52, 18, 5), 0xD8A030)
            for x in [7.0, 13, 43, 49] { fill(circle(x, 27, 1.8), 0x8A5A10) }
            inked(rounded(17, 13, 22, 28, 5), 0xFFE07A)
            inked(poly([(28, 19), (34, 27), (28, 35), (22, 27)]), 0xE0402A, 1.6)
            shine(25, 21, 4, 3)
            sparkle(46, 10, 4)
        // Charms
        case "rabbitsFoot":
            for y in [4.0, 9] { context.stroke(circle(28, y, 2.4), with: .color(Color(hex: 0xC8D0DC)), lineWidth: 1.6 * s) }
            inked(rounded(22, 12, 12, 6, 2), 0xFFC93C, 1.6)
            inked(Path(ellipseIn: r(17, 16, 22, 32)), 0xF2EEE8)
            for (x, y) in [(21.0, 42.0), (28, 45), (35, 42)] { inked(circle(x, y, 3.2), 0xFFB8C8, 1.2) }
            fill(Path(ellipseIn: r(23, 30, 10, 8)), 0xFFB8C8)
            shine(21, 21, 5, 4)
        case "magnetCharm":
            var u = Path(); u.move(to: p(15, 12)); u.addLine(to: p(15, 30))
            u.addArc(center: p(28, 30), radius: 13 * s, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
            u.addLine(to: p(41, 12))
            context.stroke(u, with: .color(ink), style: StrokeStyle(lineWidth: 15 * s, lineJoin: .round))
            context.stroke(u, with: .color(Color(hex: 0xE0402A)), style: StrokeStyle(lineWidth: 11 * s, lineJoin: .round))
            inked(rounded(8.5, 5, 13, 9, 2), 0xD8DEE8, 1.8)
            inked(rounded(34.5, 5, 13, 9, 2), 0xD8DEE8, 1.8)
            for (a, b) in [((4.0, 20.0), (1.0, 23.0)), ((52, 20), (55, 23))] {
                line(open([a, b, a]), 0xFFE08A, 2)
            }
        case "hourglass":
            fill(poly([(16, 12), (40, 12), (30, 28), (40, 44), (16, 44), (26, 28)]), 0xBFEFFF, 0.55)
            fill(poly([(20, 44), (36, 44), (28, 34)]), 0xFFC93C)
            fill(poly([(20, 14), (36, 14), (28, 23)]), 0xFFC93C)
            line(open([(28, 26), (28, 34)]), 0xFFC93C, 1.6)
            context.stroke(poly([(16, 12), (40, 12), (30, 28), (40, 44), (16, 44), (26, 28)]), with: .color(ink), lineWidth: 2 * s)
            inked(rounded(11, 6, 34, 6, 2), 0xA86A32, 1.8)
            inked(rounded(11, 44, 34, 6, 2), 0xA86A32, 1.8)
        case "echoShard":
            for (radius, opacity) in [(16.0, 0.9), (22, 0.55)] {
                line(Path { $0.addArc(center: p(28, 28), radius: radius * s, startAngle: .degrees(150), endAngle: .degrees(210), clockwise: false) }, 0x5FD0C8, 2.6, opacity: opacity)
                line(Path { $0.addArc(center: p(28, 28), radius: radius * s, startAngle: .degrees(-30), endAngle: .degrees(30), clockwise: false) }, 0x5FD0C8, 2.6, opacity: opacity)
            }
            fill(poly([(28, 7), (38, 28), (28, 49), (18, 28)]), 0x8FF0F0)
            fill(poly([(28, 7), (38, 28), (28, 49)]), 0x4FB8C0)
            context.stroke(poly([(28, 7), (38, 28), (28, 49), (18, 28)]), with: .color(ink), lineWidth: 2 * s)
            line(open([(23, 22), (26, 15)]), 0xFFFFFF, 1.6)
        case "stormCharm":
            let puffs = [(18.0, 25.0, 9.0), (29, 19, 11.5), (39, 25, 9)]
            for (x, y, radius) in puffs { context.stroke(circle(x, y, radius), with: .color(ink), lineWidth: 4 * s) }
            context.stroke(rounded(12, 23, 34, 11, 5), with: .color(ink), lineWidth: 4 * s)
            for (x, y, radius) in puffs { fill(circle(x, y, radius), 0xC8D0DC) }
            fill(rounded(12, 23, 34, 11, 5), 0xC8D0DC)
            shine(22, 13, 7, 3)
            inked(poly([(31, 31), (22, 43), (28, 43), (24, 53), (37, 39), (31, 39), (35, 31)]), 0xFFD23C, 1.8)
        case "phoenixFeather":
            var vane = Path(); vane.move(to: p(13, 49)); vane.addQuadCurve(to: p(44, 6), control: p(6, 14))
            vane.addQuadCurve(to: p(13, 49), control: p(50, 32)); inked(vane, 0xFF6A2A)
            var inner = Path(); inner.move(to: p(17, 44)); inner.addQuadCurve(to: p(41, 11), control: p(15, 18))
            inner.addQuadCurve(to: p(17, 44), control: p(42, 30)); fill(inner, 0xFFC24A)
            line(open([(11, 52), (42, 9)]), 0x1A120E, 2.2)
            for t in [0.3, 0.5, 0.7] {
                let x = 11 + 31 * t, y = 52 - 43 * t
                line(open([(x, y), (x + 6, y + 3)]), 0xE0402A, 1.4)
            }
            sparkle(46, 40, 4)
        // Boots
        case "sprintBoots":
            for y in [26.0, 33, 40] { line(open([(2, y), (9, y)]), 0x9FD0FF, 2.4) }
            inked(poly([(13, 14), (27, 14), (29, 30), (47, 34), (50, 44), (13, 44)]), 0x4FA3FF)
            inked(rounded(11, 41, 41, 7, 3), 0xFFFFFF, 1.8)
            for x in [20.0, 25] { line(open([(x, 20), (x + 6, 22)]), 0xFFFFFF, 1.8) }
            shine(16, 18, 5, 3)
        case "minersClogs":
            inked(poly([(7, 36), (14, 25), (40, 22), (49, 31), (49, 43), (7, 43)]), 0xD8A060)
            inked(Path(ellipseIn: r(14, 23, 18, 8)), 0x6A4020, 1.6)
            line(open([(10, 39), (46, 39)]), 0xA86A32, 2)
            shine(38, 27, 5, 3)
        case "stompBoots":
            for (x, y) in [(6.0, 52.0), (28, 54), (50, 52)] { line(open([(x - 3, y), (x + 3, y)]), 0xFFE08A, 2) }
            inked(rounded(13, 6, 19, 26, 3), 0x4A4A56)
            inked(poly([(13, 30), (32, 30), (47, 36), (47, 46), (9, 46), (9, 32)]), 0x3A3A44)
            inked(Path(ellipseIn: r(35, 32, 14, 13)), 0xD8DEE8, 1.6)
            inked(rounded(7, 44, 42, 6, 2), 0x1E1E24, 1.6)
            for y in [12.0, 18, 24] { line(open([(17, y), (28, y)]), 0x8A8A96, 1.6) }
        case "emberGreaves":
            inked(rounded(15, 6, 26, 44, 12), 0x7AC8F0)
            inked(Path(ellipseIn: r(19, 4, 18, 12)), 0xA8E0FF, 1.6)
            for angle in [0.0, 60, 120] {
                let a = angle * .pi / 180
                line(open([(28 - cos(a) * 9, 31 - sin(a) * 9), (28 + cos(a) * 9, 31 + sin(a) * 9)]), 0xFFFFFF, 2.4)
            }
            fill(circle(28, 31, 2.2), 0xFFFFFF)
            shine(19, 18, 4, 6)
        case "quakeBoots":
            line(open([(4, 51), (14, 48), (19, 53), (28, 47), (36, 53), (44, 48), (52, 51)]), 0x1A120E, 2.4)
            inked(rounded(13, 6, 19, 24, 3), 0x9A6236)
            inked(poly([(13, 28), (32, 28), (47, 34), (47, 43), (9, 43), (9, 30)]), 0x8A5530)
            inked(rounded(7, 41, 42, 5, 2), 0x4A2A14, 1.6)
            for (x, y) in [(10.0, 36.0), (45, 30)] { inked(circle(x - 6, y, 2.4), 0x9C958D, 1.2) }
        case "windwalkers":
            for (i, off) in [0.0, 6, 12].enumerated() {
                inked(poly([(12 - off * 0.3, 14 + off), (1, 10 + off * 1.2), (6, 18 + off)]), i == 0 ? 0xFFFFFF : 0xE8F0FF, 1.4)
            }
            inked(poly([(14, 12), (28, 12), (30, 30), (46, 34), (49, 44), (14, 44)]), 0xF2F6FF)
            inked(rounded(12, 41, 39, 6, 3), 0x9FD0FF, 1.8)
            line(open([(18, 24), (27, 24)]), 0x9FD0FF, 2)
            sparkle(44, 14, 4)
        default:
            break
        }
    }
}

#if DEBUG
/// Debug gallery of every item icon. Launch with `-debugScreen itemart`.
struct ItemArtGalleryView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                ForEach(ItemDef.all) { def in
                    VStack(spacing: 4) {
                        ItemIcon(def: def, size: 76)
                        Text(def.name).font(Theme.body(10, .heavy)).foregroundStyle(Theme.textMuted)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.ground.ignoresSafeArea())
    }
}
#endif
