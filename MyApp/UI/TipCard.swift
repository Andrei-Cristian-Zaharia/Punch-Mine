import SwiftUI

/// The current coaching tip, floating over the bottom of the mine. One at a time; "Got it" or acting on it dismisses it.
struct TipCard: View {
    @EnvironmentObject private var game: GameModel

    var body: some View {
        ZStack {
            if let tip = game.activeTip {
                card(tip)
                    .id(tip)
                    .transition(game.settings.reducedMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(game.settings.reducedMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: game.activeTip)
    }

    private func card(_ tip: Tip) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tip.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ground)
                .frame(width: 30, height: 30)
                .background(Theme.gold, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .font(Theme.body(14, .black))
                    .foregroundStyle(Theme.gold)
                Text(tip.text)
                    .font(Theme.body(12, .semibold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Got it") { game.dismissTip() }
                .font(Theme.body(13, .heavy))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.cardRaised, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Theme.panel.opacity(0.97), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tip: \(tip.title). \(tip.text)")
    }
}
