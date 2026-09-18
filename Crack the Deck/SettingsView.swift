import SwiftUI

struct SettingsView: View {
    let onResetStats: () -> Void
    let onShowInstructions: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.soundEnabled) private var soundEnabled = true
    @AppStorage(DefaultsKey.hapticsEnabled) private var hapticsEnabled = true
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    Section {
                        Toggle(isOn: $soundEnabled) {
                            Text("Sound Effects").foregroundColor(.white)
                        }
                        Toggle(isOn: $hapticsEnabled) {
                            Text("Haptics").foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section {
                        Button {
                            onShowInstructions()
                        } label: {
                            Text("How to Play")
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section {
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Text("Reset All Stats")
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("Reset All Stats?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    onResetStats()
                    dismiss()
                }
            } message: {
                Text("This clears your decks beaten, leaderboard, and achievement progress. This can't be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }
}
