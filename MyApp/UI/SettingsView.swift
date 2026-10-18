import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var ads: AdCoordinator
    @EnvironmentObject private var cloud: CloudSync
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GameLogo(size: 150)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
                progressSection
                Section {
                    Toggle(isOn: $game.settings.iCloudSync) { SettingLabel("iCloud backup", "icloud.fill", Theme.tide) }
                        .onChange(of: game.settings.iCloudSync) { _ in cloud.settingChanged() }
                } header: {
                    Text("Save")
                } footer: {
                    Text(cloud.statusText + ". A new or reinstalled device picks up where you left off.")
                }
                .listRowBackground(Theme.card)
                soundSection
                gameplaySection
                feelSection
                displaySection
                if ads.privacyOptionsRequired {
                    Section {
                        Button { ads.showPrivacyOptions() } label: { SettingLabel("Ad privacy choices", "hand.raised.fill", Theme.miner) }
                    } header: {
                        Text("Privacy")
                    } footer: {
                        Text("Change how ads may use your data.")
                    }
                    .listRowBackground(Theme.card)
                }
                Section {
                    NavigationLink { PlaytestView() } label: { SettingLabel("Playtest data", "chart.bar.fill", Theme.miner) }
                } header: {
                    Text("Playtesting")
                }
                .listRowBackground(Theme.card)
                Section {
                    Button(role: .destructive) { confirmReset = true } label: {
                        SettingLabel("Reset all progress", "trash.fill", Color(hex: 0xD8463A))
                    }
                } footer: {
                    Text(Self.versionText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground.ignoresSafeArea())
            .tint(Theme.gold)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset progress, keep items", role: .destructive) {
                    game.resetProgress(keepItems: true)
                    dismiss()
                }
                Button("Reset everything", role: .destructive) {
                    game.resetProgress(keepItems: false)
                    dismiss()
                }
            } message: {
                Text("This deletes your mines, coins, upgrades, perks and records. You can keep your items, chests and Scrap.")
            }
        }
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
    }

    // MARK: Sections

    private var progressSection: some View {
        Section {
            HStack(spacing: 0) {
                summary(StatsView.duration(game.stats.playSeconds), "played")
                summary("\(ZoneID.allCases.map { game.record(for: $0).bestArea }.max() ?? 1)", "deepest area")
                summary("\(game.heartsDefeated)", game.heartsDefeated == 1 ? "Heart" : "Hearts")
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
            NavigationLink { StatsView() } label: { SettingLabel("Stats", "chart.line.uptrend.xyaxis", Theme.crystal) }
            if game.dailyUnlocked {
                NavigationLink { DailyView() } label: {
                    HStack {
                        SettingLabel("Daily reward", "gift.fill", Theme.gold)
                        Spacer()
                        if game.dailyAvailable() {
                            Text("READY").font(Theme.body(11, .black)).tracking(1)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.fever, in: Capsule())
                                .foregroundStyle(.white)
                        } else {
                            Text("Day \(game.dailyClaimedThisWeek()) of 7").foregroundStyle(Theme.textFaint)
                        }
                    }
                }
            }
        } header: {
            Text("Progress")
        }
        .listRowBackground(Theme.card)
    }

    private var soundSection: some View {
        Section {
            Toggle(isOn: $game.settings.soundEffects) { SettingLabel("Sound effects", "speaker.wave.2.fill", Theme.copper) }
            if game.settings.soundEffects {
                VolumeSlider(value: $game.settings.effectsVolume, label: "Effects volume")
            }
            Toggle(isOn: $game.settings.music) { SettingLabel("Music", "music.note", Theme.perk) }
            if game.settings.music {
                VolumeSlider(value: $game.settings.musicVolume, label: "Music volume")
            }
        } header: {
            Text("Sound")
        } footer: {
            Text("Each zone has its own music. It pauses while music from another app is playing.")
        }
        .listRowBackground(Theme.card)
    }

    private var gameplaySection: some View {
        Section {
            Toggle(isOn: $game.settings.tapToAutoPunch) { SettingLabel("Tap to keep punching", "hand.tap.fill", Theme.buy) }
            if game.owns(.autoPrestige) {
                Toggle(isOn: $game.settings.autoPrestige) {
                    SettingLabel("Auto-prestige", "arrow.triangle.2.circlepath", Theme.perk)
                }
            }
            Toggle(isOn: $game.settings.showTips) { SettingLabel("Show tips", "lightbulb.fill", Theme.gold) }
            Button { game.resetTips() } label: { SettingLabel("Show all tips again", "arrow.counterclockwise", Theme.textFaint) }
        } header: {
            Text("Gameplay")
        } footer: {
            Text("One tap keeps punching a block until it breaks. Hold to punch unlocks at area 2."
                 + (game.owns(.autoPrestige) ? " Auto-prestige restarts a run that hasn't reached a new area for \(Int(Ascension.autoPrestigeStall)) s." : ""))
        }
        .listRowBackground(Theme.card)
    }

    private var feelSection: some View {
        Section {
            Toggle(isOn: $game.settings.reducedMotion) { SettingLabel("Reduced motion", "figure.walk", Theme.miner) }
            Toggle(isOn: $game.settings.screenShake) { SettingLabel("Screen shake", "iphone.radiowaves.left.and.right", Theme.fever) }
                .disabled(game.settings.reducedMotion)
            Picker(selection: $game.settings.vibration) {
                ForEach(Vibration.allCases) { Text($0.label).tag($0) }
            } label: {
                SettingLabel("Vibration", "waveform", Theme.crystal)
            }
        } header: {
            Text("Feel")
        }
        .listRowBackground(Theme.card)
    }

    private var displaySection: some View {
        Section {
            Picker(selection: $game.settings.damageNumbers) {
                ForEach(DamageNumbers.allCases) { Text($0.label).tag($0) }
            } label: {
                SettingLabel("Damage numbers", "number", Theme.copper)
            }
            Toggle(isOn: $game.settings.shortNumbers) { SettingLabel("Short numbers (12.4K)", "textformat.size", Theme.buy) }
        } header: {
            Text("Display")
        }
        .listRowBackground(Theme.card)
    }

    private func summary(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.display(20)).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(Theme.body(11)).foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity)
    }

    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Punch Mine \(version) (\(build))"
    }
}

/// A settings row title with a small colored icon tile, like the system Settings app.
private struct SettingLabel: View {
    let title: String
    let symbol: String
    let color: Color

    init(_ title: String, _ symbol: String, _ color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
            Text(title).foregroundStyle(Theme.text)
        }
    }
}

private struct VolumeSlider: View {
    @Binding var value: Double
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill").foregroundStyle(Theme.textFaint).accessibilityHidden(true)
            Slider(value: $value, in: 0...1)
                .accessibilityLabel(label)
                .accessibilityValue("\(Int((value * 100).rounded()))%")
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(Theme.textFaint).accessibilityHidden(true)
        }
        .padding(.leading, 40)
    }
}
