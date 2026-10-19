import SwiftUI

struct DailyResultView: View {
    let result: DailyResult

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text(result.won ? "🎉" : "💀")
                        .font(.system(size: 56))

                    Text(result.won ? "You beat today's deck!" : "So close — try tomorrow!")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 14) {
                        statRow(label: "Correct guesses", value: "\(result.correctGuesses)")
                        statRow(label: "Best streak", value: "🔥 \(result.bestStreak)")
                        statRow(label: "Time", value: formattedDuration(result.duration))
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
                    .padding(.horizontal, 24)

                    VStack(spacing: 4) {
                        Text("NEXT CHALLENGE IN")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                        // Only this text ticks each second, rather than the whole sheet re-rendering.
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(timeRemaining(at: context.date))
                                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 4)

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share Result", systemImage: "square.and.arrow.up")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                }
                .padding(.top, 40)
            }
            .navigationTitle("Daily Challenge")
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
        .sheet(isPresented: $showShareSheet) {
            ActivityView(items: [shareMessage])
        }
    }

    private var shareMessage: String {
        if result.won {
            let seconds = Int(result.duration.rounded())
            return "I cracked the deck in \(seconds) seconds and my best streak was \(result.bestStreak)! \(AppLinks.appStoreURLString)"
        }
        return "Today's Daily Challenge in Crack the Deck got me... 💀 \(result.correctGuesses) correct guesses. Think you can beat it? \(AppLinks.appStoreURLString)"
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(.orange)
        }
    }

    private func timeRemaining(at now: Date) -> String {
        guard let tomorrow = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else {
            return "—"
        }
        let interval = max(0, tomorrow.timeIntervalSince(now))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
