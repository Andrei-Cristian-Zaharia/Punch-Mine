import SwiftUI

/// Shapes shared by fist skins (a flash on each hit) and break effects (what a block bursts into).
enum CosmeticShapes {
    static func path(_ shape: CosmeticShape, center c: CGPoint, size r: CGFloat, spin: Double = 0) -> Path {
        var p = Path()
        switch shape {
        case .ring:
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        case .candy, .coin:
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r * (shape == .coin ? 0.8 : 1), width: r * 2, height: r * (shape == .coin ? 1.6 : 2)))
        case .star:
            for k in 0..<10 {
                let a = spin + Double(k) * .pi / 5 - .pi / 2
                let rr = k.isMultiple(of: 2) ? r : r * 0.45
                let pt = CGPoint(x: c.x + rr * CGFloat(cos(a)), y: c.y + rr * CGFloat(sin(a)))
                if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        case .flake:
            for k in 0..<6 {
                let a = spin + Double(k) * .pi / 3
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a))))
            }
        case .flame:
            p.move(to: CGPoint(x: c.x, y: c.y - r * 1.2))
            p.addQuadCurve(to: CGPoint(x: c.x + r * 0.8, y: c.y + r * 0.5), control: CGPoint(x: c.x + r, y: c.y - r * 0.2))
            p.addQuadCurve(to: CGPoint(x: c.x - r * 0.8, y: c.y + r * 0.5), control: CGPoint(x: c.x, y: c.y + r * 1.3))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r * 1.2), control: CGPoint(x: c.x - r, y: c.y - r * 0.2))
        case .petal:
            p.addEllipse(in: CGRect(x: -r * 0.55, y: -r, width: r * 1.1, height: r * 2))
            p = p.applying(CGAffineTransform(rotationAngle: CGFloat(spin))).applying(CGAffineTransform(translationX: c.x, y: c.y))
        case .bubble:
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            p.addEllipse(in: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.6, width: r * 0.4, height: r * 0.4))
        case .heart:
            p.move(to: CGPoint(x: c.x, y: c.y + r * 0.9))
            p.addCurve(to: CGPoint(x: c.x, y: c.y - r * 0.4), control1: CGPoint(x: c.x - r * 1.4, y: c.y), control2: CGPoint(x: c.x - r * 0.6, y: c.y - r * 1.2))
            p.addCurve(to: CGPoint(x: c.x, y: c.y + r * 0.9), control1: CGPoint(x: c.x + r * 0.6, y: c.y - r * 1.2), control2: CGPoint(x: c.x + r * 1.4, y: c.y))
        }
        return p
    }

    /// Lines (flakes) are stroked; everything else is filled with a dark edge.
    static func draw(_ shape: CosmeticShape, center: CGPoint, size: CGFloat, color: Color, spin: Double = 0, in context: inout GraphicsContext) {
        let path = path(shape, center: center, size: size, spin: spin)
        if shape == .flake {
            context.stroke(path, with: .color(.black.opacity(0.5)), style: StrokeStyle(lineWidth: max(2, size * 0.35), lineCap: .round))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: max(1.2, size * 0.18), lineCap: .round))
        } else if shape == .bubble {
            context.fill(path, with: .color(color.opacity(0.35)))
            context.stroke(path, with: .color(color), lineWidth: max(1.5, size * 0.15))
        } else if shape == .ring {
            context.stroke(path, with: .color(color), lineWidth: max(2, size * 0.18))
        } else {
            context.fill(path, with: .color(color))
            context.stroke(path, with: .color(.black.opacity(0.45)), lineWidth: 1.5)
        }
    }
}

/// A cosmetic's card art: the shape scattered, a title tag, or the tinted app icon.
struct CosmeticIcon: View {
    let cosmetic: Cosmetic
    var owned = true
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22).fill(Theme.card)
            switch cosmetic.kind {
            case .fist, .burst:
                Canvas { context, sz in
                    let colors = cosmetic.colors.map { Color(hex: $0) }
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    if cosmetic.kind == .fist {
                        CosmeticShapes.draw(.ring, center: c, size: sz.width * 0.36, color: colors[0].opacity(0.6), in: &context)
                        CosmeticShapes.draw(cosmetic.shape, center: c, size: sz.width * 0.24, color: colors[0], in: &context)
                    } else {
                        for k in 0..<6 {
                            let a = Double(k) * 1.05
                            let pt = CGPoint(x: c.x + sz.width * 0.28 * CGFloat(cos(a)), y: c.y + sz.width * 0.28 * CGFloat(sin(a)))
                            CosmeticShapes.draw(cosmetic.shape, center: pt, size: sz.width * 0.1, color: colors[k % colors.count],
                                                spin: a, in: &context)
                        }
                    }
                }
            case .title:
                Image(systemName: "rosette").font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(Theme.gold)
            case .icon:
                Image(cosmetic.iconName?.replacingOccurrences(of: "AppIcon-", with: "IconPreview-") ?? "").resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
                    .padding(size * 0.1)
            }
        }
        .frame(width: size, height: size)
        .opacity(owned ? 1 : 0.35)
        .accessibilityHidden(true)
    }
}

/// A pet, drawn flat with bold outlines like the rest of the art.
struct PetArt: View {
    let pet: PetDef
    var size: CGFloat = 44

    var body: some View {
        Canvas { context, sz in
            let s = sz.width / 56
            func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func inked(_ p: Path, _ hex: UInt32) {
                context.fill(p, with: .color(Color(hex: hex)))
                context.stroke(p, with: .color(Color(hex: 0x1A120E)), lineWidth: 2 * s)
            }
            func eyes(_ y: Double, _ hex: UInt32 = 0x1A120E) {
                for x in [22.0, 34] { context.fill(Path(ellipseIn: r(x - 2.5, y - 3, 5, 6)), with: .color(Color(hex: hex))) }
            }
            switch pet.id {
            case "bat":
                for side in [-1.0, 1] {
                    var wing = Path(); wing.move(to: pt(28, 26))
                    wing.addLine(to: pt(28 + side * 24, 16)); wing.addLine(to: pt(28 + side * 20, 30))
                    wing.addLine(to: pt(28 + side * 14, 26)); wing.addLine(to: pt(28 + side * 10, 34)); wing.closeSubpath()
                    inked(wing, 0x4A2A5A)
                }
                inked(Path(ellipseIn: r(17, 18, 22, 22)), 0xFF8A2A)
                for side in [-1.0, 1] {
                    var ear = Path(); ear.move(to: pt(28 + side * 5, 20)); ear.addLine(to: pt(28 + side * 9, 10)); ear.addLine(to: pt(28 + side * 10, 22))
                    inked(ear, 0xFF8A2A)
                }
                eyes(28, 0xFFE85A)
            case "owl":
                inked(Path(ellipseIn: r(12, 10, 32, 38)), 0xF4FAFF)
                for x in [22.0, 34] { inked(Path(ellipseIn: r(x - 6, 18, 12, 12)), 0xBFE8FF) }
                eyes(24)
                var beak = Path(); beak.move(to: pt(25, 31)); beak.addLine(to: pt(31, 31)); beak.addLine(to: pt(28, 36)); beak.closeSubpath()
                inked(beak, 0xFFC93C)
            case "cat":
                for side in [-1.0, 1] {
                    var ear = Path(); ear.move(to: pt(28 + side * 6, 16)); ear.addLine(to: pt(28 + side * 14, 6)); ear.addLine(to: pt(28 + side * 16, 20))
                    inked(ear, 0xFFFFFF)
                }
                inked(Path(ellipseIn: r(10, 12, 36, 32)), 0xFFFFFF)
                eyes(26)
                context.fill(Path(ellipseIn: r(25, 31, 6, 4)), with: .color(Color(hex: 0xFF6A8A)))
                inked(Path(ellipseIn: r(22, 40, 12, 12)), 0xF5C64F)
            case "golem":
                inked(Path(roundedRect: r(10, 12, 36, 34), cornerRadius: 8 * s), 0x9C958D)
                inked(Path(roundedRect: r(4, 24, 10, 16), cornerRadius: 4 * s), 0x7A746C)
                inked(Path(roundedRect: r(42, 24, 10, 16), cornerRadius: 4 * s), 0x7A746C)
                eyes(26, 0x6FE0E6)
                context.stroke(Path(roundedRect: r(22, 34, 12, 3), cornerRadius: 1.5 * s), with: .color(Color(hex: 0x1A120E)), lineWidth: 2 * s)
            case "bunny":
                for side in [-1.0, 1] { inked(Path(roundedRect: r(28 + side * 7 - 4, 2, 8, 22), cornerRadius: 4 * s), 0xFFF4F8) }
                inked(Path(ellipseIn: r(12, 16, 32, 30)), 0xFFF4F8)
                eyes(29)
                context.fill(Path(ellipseIn: r(25, 35, 6, 4)), with: .color(Color(hex: 0xFF8AC8)))
                context.fill(Path(ellipseIn: r(38, 6, 8, 8)), with: .color(Color(hex: 0xFF8AC8)))
            case "crab":
                for side in [-1.0, 1] {
                    inked(Path(ellipseIn: r(28 + side * 18 - 7, 10, 14, 12)), 0xFF6A4A)
                    for k in 0..<3 {
                        var leg = Path(); leg.move(to: pt(28 + side * 12, 36 + Double(k) * 3)); leg.addLine(to: pt(28 + side * 22, 42 + Double(k) * 3))
                        context.stroke(leg, with: .color(Color(hex: 0x1A120E)), lineWidth: 2.5 * s)
                    }
                }
                inked(Path(ellipseIn: r(12, 22, 32, 24)), 0xFF6A4A)
                for x in [22.0, 34] {
                    inked(Path(ellipseIn: r(x - 4, 14, 8, 8)), 0xFFFFFF)
                    context.fill(Path(ellipseIn: r(x - 2, 16, 4, 4)), with: .color(Color(hex: 0x1A120E)))
                }
            case "mole":
                inked(Path(ellipseIn: r(10, 14, 36, 34)), 0x8A6A4A)
                inked(Path(ellipseIn: r(22, 30, 12, 9)), 0xFF9AB0)
                eyes(26)
                inked(Path(roundedRect: r(14, 8, 28, 10), cornerRadius: 3 * s), 0xFFC93C)
                context.fill(Path(ellipseIn: r(25, 9, 6, 6)), with: .color(Color(hex: 0xFFF3B0)))
            default: // fox
                var tail = Path(); tail.move(to: pt(40, 40)); tail.addQuadCurve(to: pt(54, 22), control: pt(56, 40))
                tail.addQuadCurve(to: pt(38, 34), control: pt(46, 30))
                inked(tail, 0xFFC93C)
                for side in [-1.0, 1] {
                    var ear = Path(); ear.move(to: pt(28 + side * 6, 18)); ear.addLine(to: pt(28 + side * 14, 6)); ear.addLine(to: pt(28 + side * 16, 22))
                    inked(ear, 0xFF5A3D)
                }
                var head = Path(); head.move(to: pt(10, 20)); head.addLine(to: pt(46, 20)); head.addLine(to: pt(28, 46)); head.closeSubpath()
                inked(head, 0xFF5A3D)
                context.fill(Path(ellipseIn: r(25, 40, 6, 5)), with: .color(Color(hex: 0x1A120E)))
                eyes(27)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Switches the home-screen icon. iOS shows its own confirmation alert.
enum AppIconSwitcher {
    static var supported: Bool {
        #if os(iOS)
        UIApplication.shared.supportsAlternateIcons
        #else
        false
        #endif
    }

    static func set(_ name: String?) {
        #if os(iOS)
        guard supported, UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name)
        #endif
    }
}
