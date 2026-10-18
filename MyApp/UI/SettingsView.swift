import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var game: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Feel") {
                    Toggle("Reduced motion", isOn: $game.settings.reducedMotion)
                    Picker("Vibration", selection: $game.settings.vibration) {
                        ForEach(Vibration.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section {
                    Toggle("Tap to keep punching", isOn: $game.settings.tapToAutoPunch)
                } header: {
                    Text("Input")
                } footer: {
                    Text("One tap keeps punching that block until it breaks. Hold to punch unlocks at area 2.")
                }
                Section("Numbers") {
                    Picker("Damage numbers", selection: $game.settings.damageNumbers) {
                        ForEach(DamageNumbers.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Short numbers (12.4K)", isOn: $game.settings.shortNumbers)
                }
                Section("Playtesting") {
                    NavigationLink("Playtest data") { PlaytestView() }
                }
                Section {
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                }
            }
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
    }
}
