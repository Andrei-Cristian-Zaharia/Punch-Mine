import SwiftUI

/// Shown when this device and iCloud both have real progress: pick the save to keep.
struct CloudChoiceView: View {
    @EnvironmentObject private var cloud: CloudSync
    let conflict: CloudConflict

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.tide)
                .padding(.top, 24)
                .accessibilityHidden(true)
            Text("Choose your save").font(Theme.display(28))
            Text("This device and iCloud both have progress. Pick the one to keep; the other is replaced. Purchases from both are always kept.")
                .font(Theme.body(14)).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
            HStack(alignment: .top, spacing: 10) {
                SaveCard(title: "This device", subtitle: "Now", summary: conflict.local, color: Theme.copper)
                SaveCard(title: "iCloud", subtitle: "From \(conflict.cloudDeviceName), \(Self.ago(conflict.cloudSavedAt))",
                         summary: conflict.cloud, color: Theme.tide)
            }
            Spacer()
            Button {
                cloud.resolve(useCloud: true)
            } label: {
                Text("Use iCloud save")
                    .font(Theme.body(17, .black))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.tide, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color(hex: 0x061E30))
            }
            .buttonStyle(.plain)
            Button {
                cloud.resolve(useCloud: false)
            } label: {
                Text("Keep this device")
                    .font(Theme.body(17, .black))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.copper, lineWidth: 2))
                    .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.text)
        .interactiveDismissDisabled()
    }

    static func ago(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}

private struct SaveCard: View {
    let title: String
    let subtitle: String
    let summary: SaveSummary
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(Theme.body(12, .black)).tracking(1).foregroundStyle(color)
            Text(subtitle).font(Theme.body(11)).foregroundStyle(Theme.textFaint).lineLimit(2)
            Divider().overlay(Theme.line)
            row("Played", StatsView.duration(summary.playSeconds))
            row("Deepest area", "\(summary.deepest)")
            row("Zones open", "\(summary.zones)")
            row("Prestiges", "\(summary.prestiges)")
            row("Hearts", "\(summary.hearts)")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.7), lineWidth: 2))
        .accessibilityElement(children: .combine)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.body(12)).foregroundStyle(Theme.textMuted)
            Spacer(minLength: 4)
            Text(value).font(Theme.body(13, .black)).monospacedDigit()
        }
    }
}

extension CloudSync {
    /// For Settings.
    var statusText: String {
        switch status {
        case .off: "Off: progress stays on this device"
        case .unavailable: "Sign in to iCloud in the Settings app to back up progress"
        case .checking: "Checking iCloud…"
        case .waiting: "Waiting for you to choose a save"
        case .synced(let date): "Backed up " + CloudChoiceView.ago(date)
        }
    }
}
