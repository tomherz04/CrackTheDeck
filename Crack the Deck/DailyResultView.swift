import SwiftUI
import Combine

struct DailyResultView: View {
    let result: DailyResult
    let decksBeaten: Int

    @Environment(\.dismiss) private var dismiss
    @State private var shareFileURL: URL?
    @State private var showShareSheet = false
    @State private var timeRemaining = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                        Text(timeRemaining)
                            .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)

                    Button {
                        shareFileURL = renderShareImageFile(
                            totalCorrect: result.correctGuesses,
                            bestStreak: result.bestStreak,
                            decksBeaten: decksBeaten
                        )
                        showShareSheet = shareFileURL != nil
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
        .onReceive(timer) { _ in updateTimeRemaining() }
        .onAppear { updateTimeRemaining() }
        .sheet(isPresented: $showShareSheet) {
            if let shareFileURL {
                ActivityView(items: [shareMessage, shareFileURL])
            }
        }
    }

    private var shareMessage: String {
        if result.won {
            return "I beat today's Daily Challenge in Crack the Deck! 🔥 Streak: \(result.bestStreak) · \(result.correctGuesses) correct guesses in \(formattedDuration(result.duration)). Can you beat it?"
        }
        return "Today's Daily Challenge in Crack the Deck got me... 💀 \(result.correctGuesses) correct guesses. Think you can beat it?"
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

    private func updateTimeRemaining() {
        let calendar = Calendar.current
        let now = Date()
        guard let tomorrow = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else {
            timeRemaining = "—"
            return
        }
        let interval = max(0, tomorrow.timeIntervalSince(now))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
