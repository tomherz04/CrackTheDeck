import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameModel()
    @State private var showLeaderboard = false
    @State private var showSettings = false
    @State private var showNewGameConfirm = false
    @State private var showDailyStartConfirm = false
    @State private var showDailyResult = false
    @State private var showDeckStyles = false
    @State private var showInstructions = false
    @AppStorage(DefaultsKey.showOdds) private var showOdds = false
    @AppStorage(DefaultsKey.hasSeenInstructions) private var hasSeenInstructions = false
    @AppStorage(DefaultsKey.dailyReminderEnabled) private var dailyReminderEnabled = false
    @Environment(\.scenePhase) private var scenePhase

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                header

                Group {
                    if game.isDealing {
                        ShuffleView(deckStyle: game.selectedDeckStyle)
                            .frame(maxWidth: .infinity, minHeight: 360)
                            .transition(.opacity)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<9, id: \.self) { i in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) { game.selectCell(i) }
                                } label: {
                                    CardView(state: game.grid[i], isSelected: game.selectedIndex == i, deckStyle: game.selectedDeckStyle)
                                        .overlay(alignment: .topTrailing) {
                                            if bestMovePileIndex == i {
                                                BestMoveBadge()
                                                    .offset(x: 6, y: -6)
                                                    .accessibilityHidden(true)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(accessibilityLabel(forPile: i))
                                .accessibilityAddTraits(game.selectedIndex == i ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: game.isDealing)

                Text(game.lastResult ?? " ")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 24)
                    .padding(.horizontal)
                    .opacity(game.lastResult == nil ? 0 : 1)

                guessButtons

                Spacer(minLength: 0)
            }
            .padding(.top, 50)
            .frame(maxWidth: 500)

            if game.status != .playing {
                EndOverlayView(
                    status: game.status,
                    totalCorrect: game.totalCorrect,
                    bestStreak: game.bestStreak,
                    decksBeaten: game.decksBeaten,
                    isDailyMode: game.isDailyMode,
                    onPlayAgain: { withAnimation { game.newGame() } }
                )
            }

            VStack(spacing: 10) {
                if let achievement = game.newlyUnlockedAchievement {
                    AchievementToast(achievement: achievement)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let style = game.newlyUnlockedDeckStyle {
                    DeckUnlockToast(style: style)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 60)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: game.newlyUnlockedAchievement)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: game.newlyUnlockedDeckStyle)
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView(entries: game.leaderboard, achievements: game.achievements)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                onResetStats: { game.resetStats() },
                onShowInstructions: { showInstructions = true },
                onDailyReminderChanged: refreshDailyReminder
            )
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsView(isOnboarding: !hasSeenInstructions) {
                hasSeenInstructions = true
            }
        }
        .sheet(isPresented: $showDailyResult) {
            if let result = game.dailyResult {
                DailyResultView(result: result, decksBeaten: game.decksBeaten)
            }
        }
        .sheet(isPresented: $showDeckStyles) {
            DeckStylesView(
                decksBeaten: game.decksBeaten,
                selectedID: game.selectedDeckStyleID,
                onSelect: { game.selectDeckStyle($0) }
            )
        }
        .alert("Start New Game?", isPresented: $showNewGameConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("New Game", role: .destructive) {
                withAnimation { game.newGame() }
            }
        } message: {
            Text("Your current progress will be lost.")
        }
        .alert("Start Daily Challenge?", isPresented: $showDailyStartConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Start") {
                withAnimation { game.startDailyChallenge() }
            }
        } message: {
            Text("Your current progress will be lost. You get one attempt per day.")
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !hasSeenInstructions {
                showInstructions = true
            }
        }
        .onChange(of: scenePhase) { _, _ in refreshDailyReminder() }
        .onChange(of: game.hasCompletedDailyToday) { _, _ in refreshDailyReminder() }
    }

    private func refreshDailyReminder() {
        NotificationManager.refreshDailyReminder(enabled: dailyReminderEnabled, alreadyCompletedToday: game.hasCompletedDailyToday)
    }

    private var oddsBreakdown: (lower: Int, same: Int, higher: Int)? {
        guard showOdds, let index = game.selectedIndex,
              case .faceUp(let card) = game.grid[index],
              !game.deck.isEmpty
        else { return nil }

        let total = Double(game.deck.count)
        let lowerCount = game.deck.filter { $0.rank < card.rank }.count
        let sameCount = game.deck.filter { $0.rank == card.rank }.count
        let higherCount = game.deck.filter { $0.rank > card.rank }.count

        return (
            Int((Double(lowerCount) / total * 100).rounded()),
            Int((Double(sameCount) / total * 100).rounded()),
            Int((Double(higherCount) / total * 100).rounded())
        )
    }

    /// The single best-odds guess direction for the currently selected pile, used to highlight the matching button.
    private var bestDirection: GuessDirection? {
        guard let odds = oddsBreakdown else { return nil }
        let best = max(odds.lower, odds.same, odds.higher)
        if odds.lower == best { return .lower }
        if odds.same == best { return .same }
        return .higher
    }

    /// The live pile with the single best-odds guess available right now, used to highlight it when odds are shown.
    private var bestMovePileIndex: Int? {
        guard showOdds, !game.deck.isEmpty else { return nil }

        let total = Double(game.deck.count)
        var bestIndex: Int?
        var bestProbability = -1.0

        for i in 0..<9 {
            guard case .faceUp(let card) = game.grid[i] else { continue }
            let lower = Double(game.deck.filter { $0.rank < card.rank }.count) / total
            let same = Double(game.deck.filter { $0.rank == card.rank }.count) / total
            let higher = Double(game.deck.filter { $0.rank > card.rank }.count) / total
            let best = max(lower, same, higher)
            if best > bestProbability {
                bestProbability = best
                bestIndex = i
            }
        }
        return bestIndex
    }

    private func accessibilityLabel(forPile i: Int) -> String {
        switch game.grid[i] {
        case .faceUp(let card):
            var label = "\(card.accessibilityLabel), pile \(i + 1)"
            if bestMovePileIndex == i { label += ", recommended best move" }
            return label
        case .faceDown(let card):
            return "\(card.accessibilityLabel), pile \(i + 1), out of play"
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Text("CRACK THE DECK")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    if game.isDailyMode {
                        Text("DAILY")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .clipShape(Capsule())
                            .fixedSize()
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    headerIconButton(systemImage: "arrow.clockwise", active: false, accessibilityLabel: "New Game") {
                        showNewGameConfirm = true
                    }
                    headerIconButton(
                        systemImage: "calendar",
                        active: game.hasCompletedDailyToday,
                        accessibilityLabel: "Daily Challenge",
                        accessibilityValue: game.hasCompletedDailyToday ? "Completed" : "Not played yet"
                    ) {
                        if game.hasCompletedDailyToday {
                            showDailyResult = true
                        } else {
                            showDailyStartConfirm = true
                        }
                    }
                    headerIconButton(
                        systemImage: "percent",
                        active: showOdds,
                        accessibilityLabel: "Show Odds",
                        accessibilityValue: showOdds ? "On" : "Off"
                    ) {
                        showOdds.toggle()
                    }
                    headerIconButton(systemImage: "square.stack.3d.up.fill", active: false, accessibilityLabel: "Card Back Styles") {
                        showDeckStyles = true
                    }
                    headerIconButton(systemImage: "gearshape.fill", active: false, accessibilityLabel: "Settings") {
                        showSettings = true
                    }
                    headerIconButton(
                        systemImage: "trophy.fill",
                        active: false,
                        badge: game.decksBeaten,
                        accessibilityLabel: "Leaderboard and Achievements",
                        accessibilityValue: game.decksBeaten > 0 ? "\(game.decksBeaten) decks beaten" : nil
                    ) {
                        showLeaderboard = true
                    }
                }
            }

            HStack {
                statBlock(label: "DECK", value: "\(game.deckCount)")
                Spacer()
                statBlock(label: "STREAK", value: "\(game.currentStreak)", hot: game.currentStreak >= 3)
                Spacer()
                statBlock(label: "BEST", value: "\(game.bestStreak)")
            }
        }
        .padding(.horizontal)
    }

    private func headerIconButton(
        systemImage: String,
        active: Bool,
        badge: Int = 0,
        accessibilityLabel: String,
        accessibilityValue: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(active ? .black : .white.opacity(0.8))
                    .frame(width: 30, height: 30)
                    .background(active ? Color.white : Color.white.opacity(0.12))
                    .clipShape(Circle())

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(3)
                        .frame(minWidth: 15, minHeight: 15)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .offset(x: 7, y: -7)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "")
    }

    private func statBlock(label: String, value: String, hot: Bool = false) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                if hot { FlameView() }
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(hot ? .orange : .white)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.2)
        }
    }

    private var guessButtons: some View {
        HStack(spacing: 14) {
            guessButton(title: "Lower", oddsPercent: oddsBreakdown?.lower, systemImage: "arrow.down", color: .blue, compact: false, isBestMove: bestDirection == .lower) {
                game.guess(.lower, oddsVisible: showOdds)
            }
            .frame(maxWidth: .infinity)

            guessButton(title: "Same", oddsPercent: oddsBreakdown?.same, systemImage: "equal", color: .purple, compact: true, isBestMove: bestDirection == .same) {
                game.guess(.same, oddsVisible: showOdds)
            }
            .frame(width: 92)

            guessButton(title: "Higher", oddsPercent: oddsBreakdown?.higher, systemImage: "arrow.up", color: .orange, compact: false, isBestMove: bestDirection == .higher) {
                game.guess(.higher, oddsVisible: showOdds)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }

    private func guessButton(title: String, oddsPercent: Int?, systemImage: String, color: Color, compact: Bool, isBestMove: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring()) { action() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: compact ? 17 : 24, weight: .semibold))
                if let oddsPercent {
                    Text("\(oddsPercent)%")
                        .font(.system(compact ? .subheadline : .title3, design: .rounded).weight(.bold))
                } else {
                    Text(title)
                        .font(.system(compact ? .footnote : .body, design: .rounded).weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 16 : 24)
            .background(color.opacity(game.selectedIndex == nil ? 0.3 : 0.85))
            .foregroundColor(.white)
            .cornerRadius(18)
            .overlay(alignment: .topTrailing) {
                if isBestMove {
                    BestMoveBadge()
                        .offset(x: 6, y: -6)
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(game.selectedIndex == nil)
        .accessibilityLabel(guessAccessibilityLabel(title: title, oddsPercent: oddsPercent, isBestMove: isBestMove))
    }

    private func guessAccessibilityLabel(title: String, oddsPercent: Int?, isBestMove: Bool) -> String {
        var label = "Guess \(title)"
        if let oddsPercent {
            label += ", \(oddsPercent) percent odds"
        }
        if isBestMove {
            label += ", best odds"
        }
        return label
    }
}

private struct BestMoveBadge: View {
    @State private var pulse = false

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.black)
            .padding(6)
            .background(Color.green)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.appBackground, lineWidth: 2))
            .scaleEffect(pulse ? 1.15 : 0.95)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .transition(.scale.combined(with: .opacity))
    }
}

private struct FlameView: View {
    @State private var pulse = false

    var body: some View {
        Text("🔥")
            .font(.system(size: 16))
            .scaleEffect(pulse ? 1.2 : 0.85)
            .opacity(pulse ? 1 : 0.7)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .transition(.scale.combined(with: .opacity))
    }
}

private struct AchievementToast: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            Text(achievement.icon)
                .font(.system(size: 30))
            VStack(alignment: .leading, spacing: 1) {
                Text("Achievement Unlocked!")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundColor(.yellow)
                Text(achievement.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.black.opacity(0.85))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

private struct DeckUnlockToast: View {
    let style: DeckStyle

    var body: some View {
        HStack(spacing: 12) {
            CardBackView(style: style, cornerRadius: 8)
                .frame(width: 34, height: 48)
            VStack(alignment: .leading, spacing: 1) {
                Text("New Deck Unlocked!")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundColor(.cyan)
                Text(style.name)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.black.opacity(0.85))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style.topColor.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

private struct EndOverlayView: View {
    let status: GameStatus
    let totalCorrect: Int
    let bestStreak: Int
    let decksBeaten: Int
    let isDailyMode: Bool
    let onPlayAgain: () -> Void

    @State private var popIn = false
    @State private var shareFileURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            if status == .won {
                ConfettiView().ignoresSafeArea()
            }

            VStack(spacing: 22) {
                Text(status == .won ? "🎉" : "💀")
                    .font(.system(size: 60))

                Text(titleText)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                HStack(spacing: 0) {
                    endStat(label: "CORRECT", value: "\(totalCorrect)")
                    endStatDivider
                    endStat(label: "BEST STREAK", value: "\(bestStreak)")
                    if status == .won {
                        endStatDivider
                        endStat(label: "DECKS BEATEN", value: "\(decksBeaten)")
                    }
                }
                .padding(.vertical, 18)
                .background(Color.white.opacity(0.08))
                .cornerRadius(18)

                if isDailyMode {
                    Text("Come back tomorrow for a new challenge!")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button(action: onPlayAgain) {
                        Text(isDailyMode ? "Play a Random Game" : "Play Again")
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if status == .won {
                        Button {
                            shareFileURL = renderShareImageFile(
                                totalCorrect: totalCorrect,
                                bestStreak: bestStreak,
                                decksBeaten: decksBeaten
                            )
                            showShareSheet = shareFileURL != nil
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(14)
                    }
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 420)
            .scaleEffect(popIn ? 1 : 0.7)
            .opacity(popIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                popIn = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareFileURL {
                ActivityView(items: [shareMessage, shareFileURL])
            }
        }
    }

    private var endStatDivider: some View {
        Divider()
            .frame(width: 1, height: 34)
            .background(Color.white.opacity(0.15))
    }

    private func endStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.0)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var shareMessage: String {
        if isDailyMode {
            return "I beat today's Daily Challenge in Crack the Deck! 🔥 Streak: \(bestStreak) · \(totalCorrect) correct guesses. Can you beat it?"
        }
        return "I beat the deck! 🎉 Best streak: \(bestStreak) · \(totalCorrect) correct guesses. Can you beat it?"
    }

    private var titleText: String {
        if isDailyMode {
            return status == .won ? "🎉 Daily Challenge Beaten! 🎉" : "Daily Challenge Over"
        }
        return status == .won ? "🎉 You beat the deck! 🎉" : "Game Over"
    }
}

#Preview {
    ContentView()
}
