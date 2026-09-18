import SwiftUI

struct DeckStylesView: View {
    let decksBeaten: Int
    let selectedID: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(DeckStyle.all) { style in
                            styleCard(style)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Card Backs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func styleCard(_ style: DeckStyle) -> some View {
        let unlocked = DeckStyle.isUnlocked(style, decksBeaten: decksBeaten)
        let isSelected = style.id == selectedID

        return Button {
            onSelect(style.id)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    CardBackView(style: style, cornerRadius: 12)
                        .frame(width: 84, height: 118)
                        .opacity(unlocked ? 1 : 0.35)
                        .saturation(unlocked ? 1 : 0)

                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yellow, lineWidth: 3)
                            .frame(width: 84, height: 118)
                    }
                }

                Text(style.name)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(unlocked ? .white : .white.opacity(0.5))

                Text(unlocked ? (isSelected ? "Equipped" : "Tap to equip") : "Beat \(style.winsRequired) deck\(style.winsRequired == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(unlocked ? (isSelected ? .yellow : .white.opacity(0.5)) : .white.opacity(0.4))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(isSelected ? 0.12 : 0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .disabled(!unlocked)
    }
}
