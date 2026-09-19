import SwiftUI

struct LeaderboardView: View {
    let entries: [LeaderboardEntry]
    let achievements: [Achievement]

    @Environment(\.dismiss) private var dismiss
    @State private var sortMode: SortMode = .streak

    enum SortMode: String, CaseIterable {
        case streak = "Best Streak"
        case speed = "Fastest Clear"
        case achievements = "Achievements"
    }

    private var sortedEntries: [LeaderboardEntry] {
        switch sortMode {
        case .streak:
            return entries.sorted { $0.bestStreakInRun > $1.bestStreakInRun }
        case .speed:
            return entries.sorted { $0.duration < $1.duration }
        case .achievements:
            return []
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 16) {
                    Picker("Sort", selection: $sortMode) {
                        ForEach(SortMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if sortMode == .achievements {
                        ScrollView {
                            achievementsGrid
                                .padding(.vertical)
                        }
                    } else if sortedEntries.isEmpty {
                        Spacer()
                        Text("No decks beaten yet — go win one!")
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    } else {
                        List {
                            ForEach(Array(sortedEntries.prefix(20).enumerated()), id: \.element.id) { index, entry in
                                row(rank: index + 1, entry: entry)
                                    .listRowBackground(Color.white.opacity(0.06))
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Decks Beaten")
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

    private var achievementsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(achievements) { achievement in
                VStack(spacing: 8) {
                    Text(achievement.icon)
                        .font(.system(size: 38))
                        .opacity(achievement.isUnlocked ? 1 : 0.25)
                        .grayscale(achievement.isUnlocked ? 0 : 1)
                    Text(achievement.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(achievement.isUnlocked ? .white : .white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(achievement.description)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(achievement.isUnlocked ? 0.65 : 0.3))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176)
                .background(Color.white.opacity(achievement.isUnlocked ? 0.09 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(achievement.isUnlocked ? Color.yellow.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
                .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }

    private func row(rank: Int, entry: LeaderboardEntry) -> some View {
        HStack {
            Text("#\(rank)")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(entry.correctGuesses) correct guesses")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("🔥 \(entry.bestStreakInRun)")
                    .foregroundColor(.orange)
                Text(formattedDuration(entry.duration))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}
