import SwiftUI

// The Punch Mine logo: a cartoon fist smashing an ore block, in the same flat, bold-outline style as the blocks.
// Self-contained (no Theme), so Tools/make-app-icon.sh can render the app icon from this exact drawing.

private func logoColor(_ hex: UInt32, _ opacity: Double = 1) -> Color {
    Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
          blue: Double(hex & 0xFF) / 255, opacity: opacity)
}

/// The square mark used for the app icon. Fills its frame edge to edge; the system rounds the corners.
struct LogoMark: View {
    var body: some View {
        Canvas { context, size in
            LogoPainter(context: context, s: min(size.width, size.height) / 100).draw()
        }
        .accessibilityHidden(true)
    }
}

/// Mark plus the "PUNCH MINE" wordmark, for the splash and Settings.
struct GameLogo: View {
    var size: CGFloat = 200

    var body: some View {
        VStack(spacing: size * 0.04) {
            LogoMark()
                .frame(width: size * 0.62, height: size * 0.62)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                    .strokeBorder(logoColor(0x1A120E), lineWidth: max(2, size * 0.018)))
                .shadow(color: logoColor(0xFF9A3D, 0.35), radius: size * 0.08)
            VStack(spacing: -size * 0.05) {
                Wordmark(text: "PUNCH", size: size * 0.24)
                Wordmark(text: "MINE", size: size * 0.2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Punch Mine")
    }
}

/// Chunky gold-to-copper letters with a thick dark outline and a drop shadow.
private struct Wordmark: View {
    let text: String
    let size: CGFloat

    var body: some View {
        let font = Font.system(size: size, weight: .black, design: .rounded)
        let outline = max(1.5, size * 0.07)
        ZStack {
            // Outline: the text stamped in a ring of offsets, then a deeper drop shadow.
            ForEach(0..<16, id: \.self) { i in
                let a = Double(i) / 16 * 2 * .pi
                Text(text).font(font).foregroundStyle(logoColor(0x1A120E))
                    .offset(x: cos(a) * outline, y: sin(a) * outline + outline * 0.9)
            }
            ForEach(0..<16, id: \.self) { i in
                let a = Double(i) / 16 * 2 * .pi
                Text(text).font(font).foregroundStyle(logoColor(0x1A120E))
                    .offset(x: cos(a) * outline, y: sin(a) * outline)
            }
            Text(text).font(font)
                .foregroundStyle(LinearGradient(colors: [logoColor(0xFFF3B0), logoColor(0xFFC93C), logoColor(0xE0843A)],
                                                startPoint: .top, endPoint: .bottom))
            // Shine across the top of the letters.
            Text(text).font(font).foregroundStyle(.white.opacity(0.35))
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.42)))
        }
        .fixedSize()
        .padding(.horizontal, outline)
    }
}

private struct LogoPainter {
    var context: GraphicsContext
    let s: CGFloat
    let ink: UInt32 = 0x1A120E

    func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
    func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }
    func poly(_ pts: [(Double, Double)]) -> Path {
        var path = Path()
        path.move(to: p(pts[0].0, pts[0].1))
        for q in pts.dropFirst() { path.addLine(to: p(q.0, q.1)) }
        path.closeSubpath()
        return path
    }
    func fill(_ path: Path, _ hex: UInt32, _ opacity: Double = 1) { context.fill(path, with: .color(logoColor(hex, opacity))) }
    func inked(_ path: Path, _ hex: UInt32, _ width: Double = 2.4) {
        fill(path, hex)
        context.stroke(path, with: .color(logoColor(ink)), style: StrokeStyle(lineWidth: width * s, lineJoin: .round))
    }
    func line(_ pts: [(Double, Double)], _ hex: UInt32, _ width: Double, _ opacity: Double = 1) {
        var path = Path()
        path.move(to: p(pts[0].0, pts[0].1))
        for q in pts.dropFirst() { path.addLine(to: p(q.0, q.1)) }
        context.stroke(path, with: .color(logoColor(hex, opacity)),
                       style: StrokeStyle(lineWidth: width * s, lineCap: .round, lineJoin: .round))
    }
    func sparkle(_ x: Double, _ y: Double, _ size: Double) {
        let k = size * 0.28
        fill(poly([(x, y - size), (x + k, y - k), (x + size, y), (x + k, y + k), (x, y + size), (x - k, y + k), (x - size, y), (x - k, y - k)]),
             0xFFFFFF)
    }

    func draw() {
        background()
        block()
        burst()
        debris()
        fist()
        sparkle(84, 14, 4.5)
        sparkle(14, 20, 3)
        sparkle(88, 60, 2.6)
    }

    /// Warm mine glow with soft rays from the point of impact.
    private func background() {
        let all = Path(r(0, 0, 100, 100))
        context.fill(all, with: .radialGradient(Gradient(colors: [logoColor(0xFFB347), logoColor(0xB8501C), logoColor(0x3A1A0E), logoColor(0x1E120C)]),
                                                center: p(52, 44), startRadius: 0, endRadius: 72 * s))
        for i in 0..<10 {
            let a = Double(i) / 10 * 2 * .pi + 0.2, w = 0.13
            fill(poly([(52, 44), (52 + cos(a - w) * 90, 44 + sin(a - w) * 90), (52 + cos(a + w) * 90, 44 + sin(a + w) * 90)]),
                 0xFFE08A, 0.10)
        }
    }

    /// A gold-veined stone block, tilted, cracking where the fist lands.
    private func block() {
        var ctx = context
        ctx.translateBy(x: 64 * s, y: 46 * s)
        ctx.rotate(by: .degrees(9))
        let painter = LogoPainter(context: ctx, s: s)
        let body = Path(roundedRect: painter.r(-24, -24, 48, 48), cornerRadius: 8 * s)
        painter.fill(body, 0x9C958D)
        var band = ctx
        band.clip(to: body)
        band.fill(Path(painter.r(-24, 10, 48, 14)), with: .color(logoColor(0x78716A)))
        // Gold nuggets
        for (x, y, rad) in [(8.0, -10.0, 6.0), (12, 9, 4.5), (-8, 12, 3.8)] {
            painter.inked(Path(ellipseIn: painter.r(x - rad, y - rad * 0.85, rad * 2, rad * 1.7)), 0xFFC93C, 1.8)
            painter.fill(Path(ellipseIn: painter.r(x - rad * 0.5, y - rad * 0.6, rad * 0.7, rad * 0.45)), 0xFFF3B0)
        }
        // Shine
        painter.fill(Path(roundedRect: painter.r(-18, -20, 14, 3.4), cornerRadius: 1.7 * s), 0xFFFFFF, 0.3)
        // Cracks from the impact point on the left edge
        for crack in [[(-24.0, -2.0), (-14, -6), (-8, -2), (2, -8), (6, -4)],
                      [(-24, -2), (-16, 6), (-6, 4), (-2, 14)],
                      [(-14, -6), (-12, -16), (-4, -20)]] {
            painter.line(crack, ink, 2.6)
            painter.line(crack, 0x5A544E, 1)
        }
        ctx.stroke(body, with: .color(logoColor(ink)), lineWidth: 3.2 * s)
    }

    /// Comic impact star where knuckles meet stone.
    private func burst() {
        let cx = 42.0, cy = 50.0
        let star = (0..<20).map { i -> (Double, Double) in
            let a = Double(i) / 20 * 2 * .pi, rad = i % 2 == 0 ? 17.0 : 9.0
            return (cx + cos(a) * rad, cy + sin(a) * rad)
        }
        inked(poly(star), 0xFFF3B0, 2.2)
        let inner = (0..<16).map { i -> (Double, Double) in
            let a = Double(i) / 16 * 2 * .pi + 0.2, rad = i % 2 == 0 ? 10.0 : 5.5
            return (cx + cos(a) * rad, cy + sin(a) * rad)
        }
        fill(poly(inner), 0xFFFFFF)
    }

    /// Rock chunks flying off the block.
    private func debris() {
        for (x, y, size, color) in [(78.0, 18.0, 4.5, 0x9C958D as UInt32), (86, 30, 3.2, 0xFFC93C), (70, 78, 3.8, 0x78716A),
                                    (88, 74, 2.8, 0x9C958D), (54, 18, 2.6, 0xFFC93C)] {
            let chunk = poly([(x - size, y - size * 0.6), (x + size * 0.7, y - size), (x + size, y + size * 0.5), (x - size * 0.4, y + size)])
            inked(chunk, color, 1.4)
        }
    }

    /// A cartoon fist with a red cuff, punching up and to the right from the bottom-left corner.
    private func fist() {
        var ctx = context
        ctx.translateBy(x: 20 * s, y: 72 * s)
        ctx.rotate(by: .degrees(-32))
        let f = LogoPainter(context: ctx, s: s)
        // Arm and cuff
        f.inked(Path(roundedRect: f.r(-52, -9, 40, 18), cornerRadius: 4 * s), 0xF2B27A)
        f.inked(Path(roundedRect: f.r(-16, -13, 12, 26), cornerRadius: 3 * s), 0xE0402A)
        f.fill(Path(f.r(-12.5, -12, 2.6, 24)), 0xFFFFFF, 0.85)
        // Fist body
        let body = Path(roundedRect: f.r(-6, -15, 26, 30), cornerRadius: 8 * s)
        f.inked(body, 0xF7C08A)
        // Knuckles along the leading edge
        for y in [-10.5, -3.5, 3.5, 10.5] {
            f.inked(Path(ellipseIn: f.r(15, y - 4.4, 9.6, 8.8)), 0xF7C08A, 2)
        }
        // Finger creases
        for y in [-7.0, 0, 7] { f.line([(8, y), (19, y)], 0xC8875A, 1.8) }
        // Thumb wrapped across the bottom
        f.inked(Path(roundedRect: f.r(-2, 6, 18, 9), cornerRadius: 4.5 * s), 0xFFD2A6, 2)
        // Shine on the knuckles
        f.fill(Path(roundedRect: f.r(-1, -12, 12, 3.4), cornerRadius: 1.7 * s), 0xFFFFFF, 0.5)
    }
}

/// Shown for a moment at launch, then fades into the mine.
struct LaunchSplash: View {
    @State private var visible = true
    @State private var appeared = false

    var body: some View {
        if visible {
            ZStack {
                logoColor(0x18130F).ignoresSafeArea()
                GameLogo(size: 230)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
            }
            .transition(.opacity)
            .task {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
                try? await Task.sleep(for: .seconds(1.3))
                withAnimation(.easeOut(duration: 0.4)) { visible = false }
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        LogoMark().frame(width: 180, height: 180)
        GameLogo(size: 220)
    }
    .padding()
    .background(logoColor(0x18130F))
}
