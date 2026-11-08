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
        // Plumber's Kit
        case "plumbersCap":
            var dome = Path(); dome.move(to: p(8, 36)); dome.addQuadCurve(to: p(44, 36), control: p(24, 0)); dome.closeSubpath()
            inked(dome, 0xE0302A)
            inked(Path(ellipseIn: r(26, 31, 26, 10)), 0xC0201C)
            inked(circle(24, 22, 7), 0xFFFFFF, 1.6)
            inked(circle(24, 22, 3), 0xE0302A, 1.2)
            shine(13, 22, 5, 3)
        case "plumbersOveralls":
            inked(poly([(12, 8), (20, 8), (22, 22), (34, 22), (36, 8), (44, 8), (46, 50), (32, 50), (28, 40), (24, 50), (10, 50)]), 0x3A68D8)
            for x in [17.0, 39] { inked(circle(x, 24, 3.6), 0xFFD23C, 1.4) }
            inked(rounded(21, 30, 14, 9, 2), 0x2A50B0, 1.4)
            shine(13, 30, 4, 6)
        case "powerStar":
            fill(circle(28, 29, 24), 0xFFE08A, 0.25)
            let star = (0..<10).map { i -> (Double, Double) in
                let a = Double(i) * .pi / 5 - .pi / 2, rad = i % 2 == 0 ? 23.0 : 10
                return (28 + cos(a) * rad, 30 + sin(a) * rad)
            }
            inked(poly(star), 0xFFD23C, 2.2)
            for x in [23.0, 33] { inked(rounded(x - 2, 23, 4, 9, 2), 0x1A120E, 0.5) }
            shine(17, 21, 5, 3)
            sparkle(48, 9, 4)
        case "groundPoundBoots":
            for (x, y) in [(6.0, 52.0), (28, 54), (50, 52)] { line(open([(x - 3, y), (x + 3, y)]), 0xFFE08A, 2) }
            line(open([(28, 2), (28, 9)]), 0xFFFFFF, 2.2)
            inked(poly([(12, 30), (14, 14), (30, 14), (32, 28), (48, 32), (50, 44), (10, 44)]), 0x8A4A20)
            inked(rounded(8, 41, 44, 7, 3), 0x5A2E12, 1.8)
            line(open([(14, 22), (30, 22)]), 0xE0302A, 3)
            shine(18, 17, 5, 3)
        // Blockcrafter's Gear
        case "diamondHelm":
            inked(poly([(8, 44), (8, 16), (14, 10), (42, 10), (48, 16), (48, 44), (38, 44), (38, 26), (18, 26), (18, 44)]), 0x5FE0E0)
            fill(rounded(12, 14, 8, 6, 0), 0xC8FFFF)
            fill(rounded(30, 14, 6, 4, 0), 0x3FB8C0)
            fill(rounded(40, 30, 4, 8, 0), 0x3FB8C0)
            fill(rounded(10, 32, 4, 6, 0), 0xC8FFFF)
        case "craftingBelt":
            inked(rounded(2, 22, 52, 12, 0), 0x9A6A3A)
            for x in stride(from: 6.0, through: 46, by: 8) { fill(rounded(x, 24, 4, 4, 0), 0x7A4A22) }
            inked(rounded(18, 12, 20, 22, 0), 0xB88A50)
            for i in 0..<3 { for j in 0..<3 { fill(rounded(20 + Double(i) * 6, 14 + Double(j) * 6, 4, 4, 0), (i + j) % 2 == 0 ? 0x6A4020 : 0xD8A868) } }
            context.stroke(rounded(18, 12, 20, 22, 0), with: .color(ink), lineWidth: 2 * s)
        case "creeperCharm":
            for y in [3.0, 8] { context.stroke(circle(28, y, 2.4), with: .color(Color(hex: 0xC8D0DC)), lineWidth: 1.6 * s) }
            inked(rounded(10, 12, 36, 36, 0), 0x5FC050)
            fill(rounded(14, 16, 6, 6, 0), 0x8FE070); fill(rounded(36, 38, 6, 6, 0), 0x3FA040)
            fill(rounded(16, 22, 8, 8, 0), 0x1A120E); fill(rounded(32, 22, 8, 8, 0), 0x1A120E)
            fill(poly([(24, 30), (32, 30), (32, 34), (36, 34), (36, 44), (32, 44), (32, 40), (24, 40), (24, 44), (20, 44), (20, 34), (24, 34)]), 0x1A120E)
        case "diamondBoots":
            inked(poly([(10, 46), (10, 12), (26, 12), (26, 32), (48, 32), (48, 46)]), 0x5FE0E0)
            fill(rounded(13, 15, 6, 6, 0), 0xC8FFFF)
            fill(rounded(36, 35, 6, 4, 0), 0xC8FFFF)
            fill(rounded(18, 38, 6, 5, 0), 0x3FB8C0)
            line(open([(10, 40), (48, 40)]), 0x3FB8C0, 2)
        // Hero's Garb
        case "herosCap":
            inked(poly([(8, 42), (22, 12), (30, 8), (36, 12), (52, 50), (40, 40), (30, 38)]), 0x3FB050)
            inked(rounded(6, 38, 28, 8, 4), 0x2A8A3A, 1.8)
            line(open([(24, 14), (36, 40)]), 0x8FE070, 2)
            shine(23, 18, 4, 5)
        case "rupeeWallet":
            inked(rounded(8, 18, 34, 28, 6), 0x8A5530)
            inked(poly([(8, 18), (42, 18), (36, 30), (14, 30)]), 0xA86A3A, 1.8)
            fill(circle(25, 28, 2.2), 0xFFC93C)
            inked(poly([(44, 20), (50, 27), (50, 41), (44, 48), (38, 41), (38, 27)]), 0x3FD070, 1.8)
            fill(poly([(44, 23), (47, 28), (44, 31), (41, 28)]), 0xB8FFC8)
        case "fairyBottle":
            inked(rounded(22, 4, 12, 7, 2), 0xA86A32, 1.6)
            var bottle = Path(); bottle.move(to: p(24, 11)); bottle.addLine(to: p(24, 18))
            bottle.addQuadCurve(to: p(28, 52), control: p(4, 40)); bottle.addQuadCurve(to: p(32, 18), control: p(52, 40))
            bottle.addLine(to: p(32, 11)); bottle.closeSubpath()
            fill(bottle, 0xBFEFFF, 0.5)
            fill(circle(28, 34, 9), 0xFFB8E8, 0.45)
            fill(circle(28, 34, 4.5), 0xFFF0FA)
            for (dx, dy) in [(-6.0, -4.0), (6, -4)] { fill(Path(ellipseIn: r(28 + dx - 3, 30 + dy - 2, 6, 7)), 0xFFFFFF, 0.8) }
            context.stroke(bottle, with: .color(ink), lineWidth: 2 * s)
            shine(18, 26, 3, 7)
        case "pegasusBoots":
            for (i, off) in [0.0, 7].enumerated() {
                inked(poly([(14, 16 + off), (2, 8 + off), (4, 20 + off)]), i == 0 ? 0xFFFFFF : 0xE8F0FF, 1.4)
            }
            inked(poly([(14, 12), (28, 12), (30, 30), (46, 34), (49, 44), (14, 44)]), 0xB06A3A)
            inked(rounded(12, 41, 39, 6, 3), 0x6A3A1A, 1.8)
            line(open([(16, 20), (28, 20)]), 0xFFD23C, 2.4)
            shine(18, 26, 4, 3)
        // Standalone nods
        case "estusFlask":
            fill(circle(28, 34, 18), 0xFFB040, 0.25)
            inked(rounded(23, 4, 10, 7, 2), 0x6A4A2A, 1.6)
            var flask = Path(); flask.move(to: p(24, 11)); flask.addLine(to: p(24, 20))
            flask.addQuadCurve(to: p(28, 50), control: p(8, 44)); flask.addQuadCurve(to: p(32, 20), control: p(48, 44))
            flask.addLine(to: p(32, 11)); flask.closeSubpath()
            fill(flask, 0x6AA0A0)
            fill(Path(ellipseIn: r(16, 28, 24, 21)), 0xFF9A2A)
            fill(Path(ellipseIn: r(21, 32, 10, 9)), 0xFFE08A)
            context.stroke(flask, with: .color(ink), lineWidth: 2 * s)
            shine(19, 30, 3, 6)
        case "companionCube":
            inked(rounded(8, 8, 40, 40, 6), 0xC8CCD4)
            for (x, y) in [(8.0, 8.0), (36, 8), (8, 36), (36, 36)] { inked(rounded(x, y, 12, 12, 3), 0x8A8E98, 1.4) }
            inked(circle(28, 28, 10), 0xE8EAF0, 1.6)
            var heart = Path(); heart.move(to: p(28, 34))
            heart.addCurve(to: p(28, 24), control1: p(19, 28), control2: p(23, 20))
            heart.addCurve(to: p(28, 34), control1: p(33, 20), control2: p(37, 28))
            fill(heart, 0xFF5AA8)
        case "goblinSack":
            inked(Path(ellipseIn: r(8, 16, 40, 36)), 0x9A7040)
            inked(poly([(20, 18), (28, 6), (36, 18)]), 0x8A6030, 1.8)
            line(open([(19, 18), (37, 18)]), 0x4A2A14, 3)
            for (x, y) in [(18.0, 38.0), (30, 44), (38, 34)] { inked(circle(x, y, 4.5), 0xFFC93C, 1.4) }
            inked(poly([(26, 28), (30, 24), (34, 28), (30, 34)]), 0xB06CFF, 1.4)
            sparkle(46, 12, 4)
        case "mushroomCap":
            fill(circle(28, 26, 22), 0x9FE8FF, 0.22)
            inked(rounded(22, 32, 12, 16, 4), 0xF2EEE8)
            var cap = Path(); cap.move(to: p(6, 34)); cap.addQuadCurve(to: p(50, 34), control: p(28, -2)); cap.closeSubpath()
            inked(cap, 0x4A5AA8)
            for (x, y) in [(18.0, 24.0), (30, 16), (38, 27)] { fill(circle(x, y, 3), 0x9FE8FF) }
            fill(circle(24, 41, 1.6), 0x1A120E); fill(circle(32, 41, 1.6), 0x1A120E)
        // Heart relics
        case "heartstoneBuckle":
            fill(circle(28, 28, 26), 0xFF3A5A, 0.2)
            inked(rounded(2, 20, 52, 16, 5), 0x6A2A30)
            inked(rounded(14, 10, 28, 36, 8), 0xFFC93C)
            var heart = Path(); heart.move(to: p(28, 40))
            heart.addCurve(to: p(28, 20), control1: p(14, 30), control2: p(20, 14))
            heart.addCurve(to: p(28, 40), control1: p(36, 14), control2: p(42, 30))
            inked(heart, 0xFF3A5A, 1.6)
            shine(22, 22, 4, 3)
            sparkle(48, 8, 4)
        case "prismHeart":
            fill(circle(28, 28, 26), 0x8FE0FF, 0.22)
            inked(poly([(28, 4), (48, 22), (28, 52), (8, 22)]), 0x7AD8FF, 2.2)
            fill(poly([(28, 4), (48, 22), (28, 22)]), 0xC8F4FF)
            fill(poly([(8, 22), (28, 22), (28, 52)]), 0x4FA8E0)
            fill(poly([(18, 22), (28, 12), (38, 22), (28, 34)]), 0xFFFFFF, 0.6)
            context.stroke(poly([(28, 4), (48, 22), (28, 52), (8, 22)]), with: .color(ink), lineWidth: 2.2 * s)
            sparkle(46, 42, 4); sparkle(10, 8, 3)
        case "magmaTreads":
            fill(circle(28, 30, 26), 0xFF7A2D, 0.22)
            for x in [16.0, 28, 40] {
                var flame = Path(); flame.move(to: p(x, 4)); flame.addQuadCurve(to: p(x, 18), control: p(x + 8, 12))
                flame.addQuadCurve(to: p(x, 4), control: p(x - 8, 12)); inked(flame, 0xFFC24A, 1.4)
            }
            inked(poly([(12, 30), (14, 16), (30, 16), (32, 28), (48, 32), (50, 44), (10, 44)]), 0x3A2A2A)
            inked(rounded(8, 41, 44, 7, 3), 0xFF5A1A, 1.8)
            for x in [16.0, 24, 40] { line(open([(x, 34), (x + 3, 38)]), 0xFF9A3A, 2) }
            shine(18, 19, 5, 3)
        case "candyBelt":
            fill(circle(28, 30, 26), 0xFF8A2A, 0.22)
            inked(rounded(4, 22, 48, 12, 4), 0x6A3A1A)
            for (i, x) in [10.0, 22, 34].enumerated() {
                inked(poly([(x, 24), (x + 8, 24), (x + 4, 33)]), [0xFFE85A, 0xFF8A2A, 0xFFFFFF][i], 1.4)
            }
            inked(rounded(42, 19, 10, 18, 2), 0xFFC93C)
            fill(rounded(45, 23, 4, 10, 1), 0x6A3A1A)
            sparkle(46, 10, 4)
        case "pumpkinCharm":
            fill(circle(28, 30, 26), 0xFF8A2A, 0.22)
            line(open([(28, 3), (28, 12)]), 0x6A6878, 2.4)
            inked(circle(28, 31, 17), 0xFF8A2A)
            line(open([(20, 18), (20, 44)]), 0xC8641A, 1.6); line(open([(36, 18), (36, 44)]), 0xC8641A, 1.6)
            inked(poly([(21, 28), (26, 28), (23.5, 23)]), 0xFFE85A, 1.2)
            inked(poly([(30, 28), (35, 28), (32.5, 23)]), 0xFFE85A, 1.2)
            var grin = Path(); grin.move(to: p(20, 35)); grin.addQuadCurve(to: p(36, 35), control: p(28, 43))
            line(grin, 0xFFE85A, 2.4)
            line(open([(28, 14), (32, 9)]), 0x4E8A2E, 3)
        case "frostCrown":
            fill(circle(28, 30, 26), 0x8FD8FF, 0.22)
            inked(poly([(8, 40), (8, 18), (17, 28), (28, 10), (39, 28), (48, 18), (48, 40)]), 0xBFE8FF)
            inked(rounded(6, 38, 44, 8, 3), 0x8FD8FF)
            for x in [17.0, 28, 39] { fill(circle(x, 42, 2.4), 0xFFFFFF) }
            inked(circle(28, 10, 3.5), 0xFFFFFF, 1.4)
            sparkle(46, 9, 4); sparkle(10, 12, 3)
        case "icicleCharm":
            fill(circle(28, 30, 26), 0x8FD8FF, 0.22)
            line(open([(14, 10), (42, 10)]), 0x6A6878, 3)
            for (x, len) in [(17.0, 26.0), (24, 38), (31, 32), (38, 22)] {
                inked(poly([(x - 4, 11), (x + 4, 11), (x, 11 + len)]), 0xDFF4FF, 1.4)
            }
            shine(20, 16, 3, 8)
            sparkle(46, 40, 4)
        case "dragonHelm":
            fill(circle(28, 30, 26), 0xE8343A, 0.22)
            var dome = Path(); dome.move(to: p(8, 42)); dome.addQuadCurve(to: p(48, 42), control: p(28, 0)); dome.closeSubpath()
            inked(dome, 0xC8202A)
            for side in [-1.0, 1] {
                inked(poly([(28 + side * 10, 16), (28 + side * 22, 4), (28 + side * 16, 20)]), 0xFFC93C, 1.4)
            }
            inked(rounded(6, 38, 44, 8, 3), 0xFFC93C)
            inked(circle(28, 26, 6), 0x3FC890, 1.4)
            fill(circle(26, 24, 1.6), 0xFFFFFF)
        case "silkSash":
            fill(circle(28, 30, 26), 0xE8343A, 0.22)
            var sash = Path(); sash.move(to: p(4, 20)); sash.addQuadCurve(to: p(52, 20), control: p(28, 32))
            sash.addLine(to: p(52, 30)); sash.addQuadCurve(to: p(4, 30), control: p(28, 42)); sash.closeSubpath()
            inked(sash, 0xE8343A)
            inked(circle(28, 31, 6), 0xFFC93C, 1.4)
            line(open([(26, 36), (20, 50)]), 0xE8343A, 4); line(open([(30, 36), (36, 50)]), 0xE8343A, 4)
            line(open([(10, 25), (46, 25)]), 0xFFC93C, 1.2, opacity: 0.8)
        case "flowerCrown":
            fill(circle(28, 30, 26), 0xFF8AC8, 0.22)
            var band = Path(); band.move(to: p(6, 36)); band.addQuadCurve(to: p(50, 36), control: p(28, 26))
            line(band, 0x4E8A2E, 6)
            for (x, col) in [(10.0, 0xFF8AC8), (20, 0xFFE85A), (30, 0xFF8AC8), (40, 0xBFE8FF), (48, 0xFF8AC8)] as [(Double, UInt32)] {
                let y = 34 - (x > 15 && x < 45 ? 4.0 : 0)
                for k in 0..<5 { let a = Double(k) * 1.256; fill(circle(x + cos(a) * 3.5, y + sin(a) * 3.5, 3), col) }
                fill(circle(x, y, 2), 0xFFD25A)
            }
            sparkle(46, 12, 4)
        case "vineBelt":
            fill(circle(28, 30, 26), 0x7AC85A, 0.22)
            inked(rounded(4, 22, 48, 12, 6), 0x4E8A2E)
            var vine = Path(); vine.move(to: p(6, 28))
            for k in 0..<6 { vine.addQuadCurve(to: p(14 + Double(k) * 8, 28), control: p(10 + Double(k) * 8, k.isMultiple(of: 2) ? 22 : 34)) }
            line(vine, 0x9AE07A, 2)
            for x in [14.0, 30, 46] { inked(circle(x, 28, 4), 0xFF8AC8, 1.4) }
        case "petalCharm":
            fill(circle(28, 30, 26), 0xFF8AC8, 0.22)
            line(open([(28, 3), (28, 12)]), 0x6A6878, 2.4)
            for k in 0..<5 { let a = Double(k) * 1.256 - 1.57; inked(circle(28 + cos(a) * 10, 30 + sin(a) * 10, 8), 0xFF8AC8, 1.6) }
            inked(circle(28, 30, 6), 0xFFD25A, 1.6)
            shine(22, 22, 4, 2)
        case "sunHat":
            fill(circle(28, 30, 26), 0x3FD8E8, 0.22)
            var brim = Path(); brim.move(to: p(2, 36)); brim.addQuadCurve(to: p(54, 36), control: p(28, 28)); brim.addQuadCurve(to: p(2, 36), control: p(28, 46))
            inked(brim, 0xF4D88A)
            var top = Path(); top.move(to: p(14, 34)); top.addQuadCurve(to: p(42, 34), control: p(28, 6)); top.closeSubpath()
            inked(top, 0xF4D88A)
            inked(rounded(14, 28, 28, 6, 2), 0x3FD8E8)
            sparkle(46, 10, 4)
        case "surfBoots":
            fill(circle(28, 30, 26), 0x3FD8E8, 0.22)
            for dx in [0.0, 20] {
                inked(poly([(8 + dx, 12), (20 + dx, 12), (20 + dx, 36), (27 + dx, 40), (27 + dx, 46), (8 + dx, 46)]), 0xFFC93C)
                line(open([(9 + dx, 24), (19 + dx, 24)]), 0xFF6A4A, 3)
                line(open([(9 + dx, 30), (19 + dx, 30)]), 0x3FD8E8, 3)
            }
            var wave = Path(); wave.move(to: p(2, 50)); wave.addQuadCurve(to: p(28, 50), control: p(15, 44)); wave.addQuadCurve(to: p(54, 50), control: p(41, 44))
            line(wave, 0x9FF4FF, 2.4)
        case "shellCharm":
            fill(circle(28, 30, 26), 0xFF9A7A, 0.22)
            line(open([(28, 3), (28, 12)]), 0x6A6878, 2.4)
            var shell = Path(); shell.move(to: p(28, 46)); shell.addLine(to: p(10, 26)); shell.addQuadCurve(to: p(46, 26), control: p(28, 6)); shell.closeSubpath()
            inked(shell, 0xFF9A7A)
            for x in [18.0, 24, 32, 38] { line(open([(28, 44), (x, 18)]), 0xC85A4A, 1.4) }
            fill(circle(28, 32, 4), 0xF4F0FF)
        case "prospectorHat":
            fill(circle(28, 30, 26), 0xE0A82A, 0.22)
            inked(rounded(4, 34, 48, 8, 4), 0x8A5A2A)
            var crown = Path(); crown.move(to: p(14, 36)); crown.addLine(to: p(16, 14)); crown.addQuadCurve(to: p(40, 14), control: p(28, 8)); crown.addLine(to: p(42, 36)); crown.closeSubpath()
            inked(crown, 0xA8743A)
            inked(rounded(15, 28, 26, 5, 1), 0x5A3A1A)
            inked(circle(28, 20, 4), 0xFFE85A, 1.4)
            sparkle(46, 10, 4)
        case "panBelt":
            fill(circle(28, 30, 26), 0xE0A82A, 0.22)
            inked(rounded(4, 22, 48, 12, 4), 0x6A4A2A)
            inked(circle(28, 28, 11), 0x9A9EA6)
            inked(circle(28, 28, 7), 0x6A6E78, 1.4)
            for (x, y) in [(25.0, 26.0), (30, 29), (27, 31)] { fill(circle(x, y, 1.8), 0xFFC93C) }
        case "miningBoots":
            fill(circle(28, 30, 26), 0xE0A82A, 0.22)
            for dx in [0.0, 20] {
                inked(poly([(8 + dx, 12), (20 + dx, 12), (20 + dx, 36), (27 + dx, 40), (27 + dx, 46), (8 + dx, 46)]), 0x8A5A2A)
                inked(rounded(20 + dx, 38, 8, 8, 2), 0x9A9EA6, 1.4)
                line(open([(9 + dx, 18), (19 + dx, 18)]), 0xFFC93C, 2)
            }
            sparkle(48, 10, 4)
        case "scarecrowHat":
            fill(circle(28, 30, 26), 0xFF8A2A, 0.22)
            inked(poly([(28, 4), (40, 30), (16, 30)]), 0xA8783A)
            line(open([(22, 22), (34, 22)]), 0x6A4A22, 2)
            inked(rounded(14, 26, 28, 6, 2), 0xC8302A)
            var brim = Path(); brim.move(to: p(4, 36)); brim.addQuadCurve(to: p(52, 36), control: p(28, 26))
            brim.addQuadCurve(to: p(4, 36), control: p(28, 44))
            inked(brim, 0xC8984A)
            for x in [8.0, 14, 42, 48] { line(open([(x, 38), (x + (x < 28 ? -2 : 2), 46)]), 0xFFE07A, 2) }
            sparkle(46, 10, 4)
        case "frostfallBoots":
            fill(circle(28, 30, 26), 0x8FD8FF, 0.22)
            for dx in [0.0, 20] {
                inked(poly([(8 + dx, 10), (20 + dx, 10), (20 + dx, 36), (27 + dx, 40), (27 + dx, 46), (8 + dx, 46)]), 0x5AA8E8)
                inked(rounded(6 + dx, 8, 16, 7, 3), 0xF4FAFF, 1.6)
                line(open([(10 + dx, 41), (26 + dx, 41)]), 0xBFE8FF, 2)
            }
            sparkle(48, 12, 4); sparkle(8, 26, 3)
        case "jadeDragon":
            fill(circle(28, 30, 26), 0x3FC890, 0.22)
            line(open([(28, 3), (28, 9)]), 0xE8343A, 3)
            inked(circle(28, 28, 18), 0x3FC890)
            inked(circle(28, 28, 7), 0x1E7A56, 1.6)
            var dragon = Path(); dragon.move(to: p(16, 22))
            dragon.addQuadCurve(to: p(28, 16), control: p(20, 12)); dragon.addQuadCurve(to: p(40, 30), control: p(42, 16))
            dragon.addQuadCurve(to: p(26, 40), control: p(38, 42))
            line(dragon, 0xFFC93C, 2.6)
            line(open([(28, 46), (24, 54)]), 0xE8343A, 2.4); line(open([(28, 46), (32, 54)]), 0xE8343A, 2.4)
            shine(20, 16, 5, 3)
        case "lichLantern":
            fill(circle(28, 30, 26), 0xA98CFF, 0.22)
            line(open([(28, 4), (28, 10)]), 0x1A120E, 4)
            inked(circle(28, 6, 3.5), 0x6A6878, 1.4)
            inked(rounded(16, 10, 24, 6, 2), 0x4A4458)
            inked(rounded(14, 16, 28, 28, 6), 0x2A2440, 2)
            var wisp = Path(); wisp.move(to: p(28, 20))
            wisp.addQuadCurve(to: p(28, 40), control: p(40, 34)); wisp.addQuadCurve(to: p(28, 20), control: p(16, 34))
            inked(wisp, 0x7AFFB8, 1.4)
            fill(circle(28, 34, 3), 0xE8FFF0)
            for x in [14.0, 42] { line(open([(x, 18), (x, 42)]), 0x6A6878, 2.4) }
            inked(rounded(12, 43, 32, 6, 2), 0x4A4458)
            sparkle(46, 12, 4); sparkle(9, 40, 3)
        case "tidecallerHelm":
            fill(circle(28, 30, 26), 0x3FD8C8, 0.22)
            for x in [18.0, 28, 38] {
                let top = x == 28 ? 3.0 : 8.0
                line(open([(x, 18), (x, top + 4)]), 0x1A120E, 5); line(open([(x, 18), (x, top + 4)]), 0xFFD27A, 2.6)
                inked(poly([(x - 3, top + 5), (x, top), (x + 3, top + 5)]), 0xFFD27A, 1.4)
            }
            var dome = Path(); dome.move(to: p(8, 44)); dome.addQuadCurve(to: p(48, 44), control: p(28, 4)); dome.closeSubpath()
            inked(dome, 0x2A9A9A)
            inked(circle(28, 33, 9), 0xB8885A, 2)
            inked(circle(28, 33, 6), 0x9FF4FF, 1.4)
            fill(circle(26, 31, 2), 0xFFFFFF, 0.8)
            inked(rounded(6, 42, 44, 8, 4), 0xB8885A, 1.8)
            inked(circle(44, 46, 4.5), 0xF4F0FF, 1.4)
            fill(circle(43, 45, 1.4), 0xFFFFFF)
            sparkle(10, 12, 3.5)
        default:
            break
        }
    }
}

#if DEBUG
/// Debug gallery of every item icon. Launch with `-debugScreen itemart`.
struct ItemArtGalleryView: View {
    /// `-debugScreen itemart2` shows the second half, for screenshots.
    var items: [ItemDef] {
        UserDefaults.standard.string(forKey: "debugScreen") == "itemart2" ? Array(ItemDef.all.suffix(20)) : ItemDef.all
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                ForEach(items) { def in
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
