import SwiftUI

/// On-device playtest dashboard: pacing milestones against the design doc's targets, and time per area.
struct PlaytestView: View {
    @EnvironmentObject private var game: GameModel
    @State private var state = AnalyticsState()
    @State private var zone = ZoneID.quarry
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                row("Sessions", "\(state.sessions)")
                row("Play time", Self.clock(state.playSeconds))
                row("Installed", state.installDate.formatted(date: .abbreviated, time: .shortened))
            } footer: {
                Text("Times are active play only. Everything stays on this device.")
            }

            Section("Pacing milestones") {
                ForEach(Milestone.allCases, id: \.self) { m in
                    let value = state.milestones[m.rawValue]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title)
                            if let target = m.target {
                                Text("Target \(Self.clock(target.lowerBound))–\(Self.clock(target.upperBound))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(value.map(Self.clock) ?? "—")
                            .monospacedDigit()
                            .foregroundStyle(color(value, m.target))
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                Picker("Zone", selection: $zone) {
                    ForEach(ZoneID.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                let areas = areaTimes(zone)
                if areas.isEmpty {
                    Text("No areas cleared yet").foregroundStyle(.secondary)
                }
                ForEach(areas, id: \.area) { item in
                    HStack {
                        Text("Area \(item.area)")
                        Spacer()
                        if item.isWall {
                            Text("WALL").font(.caption.bold()).foregroundStyle(.orange)
                        }
                        Text(Self.clock(item.seconds)).monospacedDigit()
                    }
                }
            } header: {
                Text("Seconds per area (latest run)")
            } footer: {
                Text("WALL marks an area that took more than 3× the one before it.")
            }

            Section {
                if let url = game.analytics.fileURL, FileManager.default.fileExists(atPath: url.path) {
                    ShareLink(item: url) { Label("Export events (JSON Lines)", systemImage: "square.and.arrow.up") }
                }
                Button("Clear playtest data", role: .destructive) { confirmClear = true }
            }
        }
        .navigationTitle("Playtest data")
        .onAppear { state = game.analytics.state }
        .confirmationDialog("Clear playtest data?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                game.analytics.clear()
                state = game.analytics.state
            }
        } message: {
            Text("Deletes recorded events and milestone times. Game progress is not affected.")
        }
    }

    private struct AreaTime { let area: Int; let seconds: Double; let isWall: Bool }

    private func areaTimes(_ zone: ZoneID) -> [AreaTime] {
        let last = max(zone.maxArea, game.record(for: zone).bestArea)
        let times = (1...last).compactMap { a in state.areaSeconds["\(zone.rawValue):\(a)"].map { (a, $0) } }
        return times.enumerated().map { i, item in
            let previous = i > 0 ? times[i - 1].1 : nil
            return AreaTime(area: item.0, seconds: item.1, isWall: previous.map { item.1 > 3 * $0 } ?? false)
        }
    }

    private func color(_ value: Double?, _ target: ClosedRange<Double>?) -> Color {
        guard let value, let target else { return .primary }
        if value > target.upperBound { return .orange }
        if value < target.lowerBound { return .yellow }
        return .green
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    nonisolated static func clock(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }
}
