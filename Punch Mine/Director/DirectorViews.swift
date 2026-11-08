#if DEBUG
import SwiftUI

// MARK: - Director mode views (Debug builds only)

/// The whole app during a directed launch: straight into the mine (or the Weekly Heart fight),
/// with no splash, no ads and no pop-ups. See `DirectorMode.swift`.
struct DirectorRoot: View {
    @EnvironmentObject private var game: GameModel

    var body: some View {
        ZStack {
            if Director.shared.scenario == .weeklyHeart && (game.weeklyFight != nil || game.weeklyResult != nil) {
                WeeklyFightView()
            } else {
                MineView()
            }
        }
        .overlay(alignment: .topLeading) {
            if Director.shared.isCapturing {
                DirectorFrame { RenderProbe(date: $0) }
            }
        }
        // Capturing: no SwiftUI animation may run on wall time. Every moving effect is drawn from the
        // virtual clock instead (see `DirectorFrame`).
        .transaction { transaction in
            if Director.shared.isCapturing {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { Director.shared.begin(game: game) }
    }
}

/// Redraws its content on every virtual frame while capturing (and gives it the frame's date).
struct DirectorFrame<Content: View>: View {
    @ObservedObject private var clock = Director.shared.clock
    private let content: (Date) -> Content

    init(@ViewBuilder content: @escaping (Date) -> Content) { self.content = content }

    var body: some View { content(clock.date) }
}

/// One invisible pixel that reports which virtual frame the screen shows, so the recorder captures
/// a frame only after SwiftUI has drawn it.
private struct RenderProbe: View {
    let date: Date

    var body: some View {
        Canvas { _, _ in Director.shared.noteRender(date) }
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The crown card after a Heart falls, shown over the mine instead of as a sheet (a sheet slides in on
/// wall time). It pops in and breathes gently while it is read.
struct DirectorConquestCard: View {
    let event: ConquestEvent

    var body: some View {
        if Director.shared.isCapturing {
            DirectorFrame { date in
                let age = Director.shared.seconds(date) - (Director.shared.conquestAt ?? Director.shared.seconds(date))
                ConquestView(event: event)
                    .scaleEffect(CGFloat(Director.pop(age, from: 0.8) + 0.01 * sin(age * 2 * .pi / 1.6)))
                    .opacity(Director.ease(age, 0.18))
            }
        } else {
            ConquestView(event: event)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }
}
#endif
