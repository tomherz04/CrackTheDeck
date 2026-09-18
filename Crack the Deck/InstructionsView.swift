import SwiftUI

struct InstructionsView: View {
    /// Shown as first-launch onboarding vs. opened later from Settings — only changes the dismiss button label.
    var isOnboarding: Bool = false
    var onDismiss: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    Section("Goal") {
                        instructionRow(
                            icon: "square.grid.3x3.fill",
                            text: "You have 9 face-up piles. Keep at least one alive until the deck runs out to win."
                        )
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section("How to Play") {
                        instructionRow(
                            icon: "hand.tap.fill",
                            text: "Tap a face-up pile to select it, then guess whether the next card will be Higher, Lower, or the Same rank."
                        )
                        instructionRow(
                            icon: "checkmark.circle.fill",
                            text: "Guess right and the pile stays alive with the new card on top."
                        )
                        instructionRow(
                            icon: "xmark.circle.fill",
                            text: "Guess wrong and that pile dies — it flips face-down for the rest of the game."
                        )
                        instructionRow(
                            icon: "flag.checkered",
                            text: "Every guess draws a card, right or wrong. Run out of live piles before the deck empties and it's game over."
                        )
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section("Odds Hint") {
                        instructionRow(
                            icon: "percent",
                            text: "Tap the % button to show the real odds of Higher, Lower, and Same for your selected pile, based on what's left in the deck."
                        )
                        instructionRow(
                            icon: "lightbulb.fill",
                            text: "Since only one wrong guess per pile is allowed, picking the pile with the best odds each turn matters more than getting every single card right."
                        )
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section("Extras") {
                        instructionRow(
                            icon: "calendar",
                            text: "Daily Challenge gives everyone the same shuffle once a day — see how you stack up."
                        )
                        instructionRow(
                            icon: "square.stack.3d.up.fill",
                            text: "Beating decks unlocks new deck styles at 1, 3, 5, 10, and 100 wins."
                        )
                        instructionRow(
                            icon: "trophy.fill",
                            text: "Check the trophy for your leaderboard, best streaks, and achievements."
                        )
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isOnboarding ? "Let's Play" : "Done") {
                        dismiss()
                        onDismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: 22)
                .padding(.top, 1)
            Text(text)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    InstructionsView(isOnboarding: true)
}
