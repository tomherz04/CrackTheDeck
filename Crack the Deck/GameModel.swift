import Foundation
import SwiftUI
import UIKit

/// Centralized UserDefaults keys, shared across the model and @AppStorage in the views.
enum DefaultsKey {
    static let decksBeaten = "decksBeaten"
    static let lifetimeBestStreak = "lifetimeBestStreak"
    static let selectedDeckStyleID = "selectedDeckStyleID"
    static let hasWonWithoutOdds = "hasWonWithoutOdds"
    static let leaderboard = "leaderboard"
    static let dailyResult = "dailyResult"
    static let soundEnabled = "soundEnabled"
    static let hapticsEnabled = "hapticsEnabled"
    static let showOdds = "showOdds"
    static let hasSeenInstructions = "hasSeenInstructions"
}

extension Color {
    /// The app's shared dark background, used behind every full-screen view and sheet.
    static let appBackground = Color(red: 0.04, green: 0.09, blue: 0.18)
}

enum Suit: String, CaseIterable {
    case hearts = "♥"
    case diamonds = "♦"
    case clubs = "♣"
    case spades = "♠"

    var isRed: Bool { self == .hearts || self == .diamonds }
}

struct Card: Identifiable, Equatable {
    let id = UUID()
    let rank: Int // 2...14, Ace = 14 (high)
    let suit: Suit

    var rankLabel: String {
        switch rank {
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        case 14: return "A"
        default: return "\(rank)"
        }
    }
}

enum CellState: Equatable {
    case faceUp(Card)
    case faceDown(Card)
}

enum GuessDirection {
    case higher
    case lower
    case same
}

enum GameStatus {
    case playing
    case won
    case lost
}

struct LeaderboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let correctGuesses: Int
    let bestStreakInRun: Int
    let duration: TimeInterval
}

struct Achievement: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let isUnlocked: Bool
}

private let cardsPerDeal = 9
private let fullDeckSize = 52

func freshShuffledDeck() -> [Card] {
    var cards: [Card] = []
    for suit in Suit.allCases {
        for rank in 2...14 {
            cards.append(Card(rank: rank, suit: suit))
        }
    }
    cards.shuffle()
    return cards
}

/// Deterministic xorshift64* generator so the daily challenge deals the
/// same shuffle for everyone on a given calendar day, regardless of device.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}

/// FNV-1a — stable across processes/devices, unlike Swift's randomized Hasher.
func stableHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

func seededShuffledDeck(seed: UInt64) -> [Card] {
    var cards: [Card] = []
    for suit in Suit.allCases {
        for rank in 2...14 {
            cards.append(Card(rank: rank, suit: suit))
        }
    }
    var rng = SeededGenerator(seed: seed)
    cards.shuffle(using: &rng)
    return cards
}

func formattedDuration(_ interval: TimeInterval) -> String {
    let minutes = Int(interval) / 60
    let seconds = Int(interval) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

func dailyDateString(for date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = .current
    return formatter.string(from: date)
}

struct DailyResult: Codable, Equatable {
    let date: String
    let won: Bool
    let correctGuesses: Int
    let bestStreak: Int
    let duration: TimeInterval
}

@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var grid: [CellState] = []
    @Published private(set) var deck: [Card] = []
    @Published var selectedIndex: Int?
    @Published private(set) var status: GameStatus = .playing
    @Published private(set) var currentStreak = 0
    @Published private(set) var bestStreak = 0
    @Published private(set) var totalCorrect = 0
    @Published var lastResult: String?
    @Published private(set) var isResolving = false
    @Published private(set) var isDealing = false
    @Published private(set) var decksBeaten = UserDefaults.standard.integer(forKey: DefaultsKey.decksBeaten)
    @Published private(set) var runBestStreak = 0
    @Published private(set) var leaderboard: [LeaderboardEntry] = GameModel.loadLeaderboard()
    @Published private(set) var lifetimeBestStreak = UserDefaults.standard.integer(forKey: DefaultsKey.lifetimeBestStreak)
    @Published var newlyUnlockedAchievement: Achievement?
    @Published var newlyUnlockedDeckStyle: DeckStyle?
    @Published private(set) var isDailyMode = false
    @Published private(set) var dailyResult: DailyResult? = GameModel.loadDailyResult()
    @Published private(set) var selectedDeckStyleID = UserDefaults.standard.string(forKey: DefaultsKey.selectedDeckStyleID) ?? DeckStyle.classic.id
    @Published private(set) var hasWonWithoutOdds = UserDefaults.standard.bool(forKey: DefaultsKey.hasWonWithoutOdds)

    private var runStartDate: Date?
    private var usedOddsThisRun = false

    var deckCount: Int { deck.count }

    var todayString: String { dailyDateString() }

    var hasCompletedDailyToday: Bool { dailyResult?.date == todayString }

    var selectedDeckStyle: DeckStyle {
        DeckStyle.all.first { $0.id == selectedDeckStyleID } ?? .classic
    }

    var achievements: [Achievement] {
        let flawless = leaderboard.contains { $0.correctGuesses >= fullDeckSize - cardsPerDeal }
        let speedrun = leaderboard.contains { $0.duration < 90 }
        return [
            Achievement(id: "first_win", icon: "🏅", title: "First Win", description: "Beat your first deck", isUnlocked: decksBeaten >= 1),
            Achievement(id: "hot_streak", icon: "🔥", title: "Hot Streak", description: "Reach a streak of 10", isUnlocked: lifetimeBestStreak >= 10),
            Achievement(id: "veteran", icon: "🎖️", title: "Veteran", description: "Beat 5 decks", isUnlocked: decksBeaten >= 5),
            Achievement(id: "deck_master", icon: "👑", title: "Deck Master", description: "Beat 10 decks", isUnlocked: decksBeaten >= 10),
            Achievement(id: "flawless", icon: "💎", title: "Flawless Victory", description: "Beat a deck with zero wrong guesses", isUnlocked: flawless),
            Achievement(id: "speedrunner", icon: "⚡", title: "Speedrunner", description: "Beat a deck in under 90 seconds", isUnlocked: speedrun),
            Achievement(id: "century", icon: "💯", title: "Century", description: "Beat 100 decks", isUnlocked: decksBeaten >= 100),
            Achievement(id: "no_odds", icon: "🙈", title: "Blind Faith", description: "Beat a deck without using the odds hint", isUnlocked: hasWonWithoutOdds),
        ]
    }

    init() {
        newGame()
    }

    func newGame(daily: Bool = false) {
        selectedIndex = nil
        status = .playing
        currentStreak = 0
        totalCorrect = 0
        runBestStreak = 0
        lastResult = nil
        isResolving = false
        isDealing = true
        runStartDate = nil
        isDailyMode = daily
        usedOddsThisRun = false

        let freshDeck = daily ? seededShuffledDeck(seed: stableHash(todayString)) : freshShuffledDeck()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            var d = freshDeck
            grid = (0..<9).map { _ in .faceUp(d.removeLast()) }
            deck = d
            runStartDate = Date()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isDealing = false
            }
        }
    }

    func startDailyChallenge() {
        guard !hasCompletedDailyToday else { return }
        newGame(daily: true)
    }

    func selectDeckStyle(_ id: String) {
        guard let style = DeckStyle.all.first(where: { $0.id == id }),
              DeckStyle.isUnlocked(style, decksBeaten: decksBeaten)
        else { return }
        selectedDeckStyleID = id
        UserDefaults.standard.set(id, forKey: DefaultsKey.selectedDeckStyleID)
    }

    func selectCell(_ index: Int) {
        guard status == .playing, !isResolving, !isDealing else { return }
        guard case .faceUp = grid[index] else { return }
        let wasSelected = selectedIndex == index
        selectedIndex = wasSelected ? nil : index
        if !wasSelected {
            SoundManager.shared.play(.select)
        }
    }

    func guess(_ direction: GuessDirection, oddsVisible: Bool) {
        guard status == .playing, !isResolving, let index = selectedIndex, !deck.isEmpty else { return }
        guard case .faceUp(let current) = grid[index] else { return }

        if oddsVisible {
            usedOddsThisRun = true
        }

        let achievementsBefore = Set(achievements.filter(\.isUnlocked).map(\.id))

        isResolving = true

        let drawn = deck.removeFirst()

        let correct: Bool
        switch direction {
        case .higher:
            correct = drawn.rank > current.rank
        case .lower:
            correct = drawn.rank < current.rank
        case .same:
            correct = drawn.rank == current.rank
        }

        if correct {
            grid[index] = .faceUp(drawn)
            currentStreak += 1
            totalCorrect += 1
            bestStreak = max(bestStreak, currentStreak)
            runBestStreak = max(runBestStreak, currentStreak)
            if currentStreak > lifetimeBestStreak {
                lifetimeBestStreak = currentStreak
                UserDefaults.standard.set(lifetimeBestStreak, forKey: DefaultsKey.lifetimeBestStreak)
            }
            lastResult = "Correct!"
            SoundManager.shared.play(.correct)
        } else {
            grid[index] = .faceDown(drawn)
            currentStreak = 0
            lastResult = (direction != .same && drawn.rank == current.rank)
                ? "Tie — drew \(drawn.rankLabel)\(drawn.suit.rawValue), that card is out!"
                : "Wrong — drew \(drawn.rankLabel)\(drawn.suit.rawValue), that card is out!"
            selectedIndex = nil
            SoundManager.shared.play(.wrong)
        }

        if deck.isEmpty {
            let decksBeatenBefore = decksBeaten
            status = .won
            decksBeaten += 1
            UserDefaults.standard.set(decksBeaten, forKey: DefaultsKey.decksBeaten)
            recordWin()
            if !usedOddsThisRun && !hasWonWithoutOdds {
                hasWonWithoutOdds = true
                UserDefaults.standard.set(true, forKey: DefaultsKey.hasWonWithoutOdds)
            }
            SoundManager.shared.play(.win)
            if GameSettings.hapticsEnabled {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            if let unlockedStyle = DeckStyle.all.first(where: { $0.winsRequired > decksBeatenBefore && $0.winsRequired <= decksBeaten }) {
                newlyUnlockedDeckStyle = unlockedStyle
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    if newlyUnlockedDeckStyle?.id == unlockedStyle.id {
                        newlyUnlockedDeckStyle = nil
                    }
                }
            }
        } else if !grid.contains(where: { if case .faceUp = $0 { return true }; return false }) {
            status = .lost
            if GameSettings.hapticsEnabled {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }

        if isDailyMode, status != .playing {
            recordDailyResult()
        }

        let achievementsAfter = Set(achievements.filter(\.isUnlocked).map(\.id))
        if let newID = achievementsAfter.subtracting(achievementsBefore).first,
           let unlocked = achievements.first(where: { $0.id == newID }) {
            newlyUnlockedAchievement = unlocked
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if newlyUnlockedAchievement?.id == unlocked.id {
                    newlyUnlockedAchievement = nil
                }
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            isResolving = false
        }
    }

    func resetStats() {
        decksBeaten = 0
        leaderboard = []
        lifetimeBestStreak = 0
        bestStreak = 0
        hasWonWithoutOdds = false
        UserDefaults.standard.removeObject(forKey: DefaultsKey.decksBeaten)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.leaderboard)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.lifetimeBestStreak)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.hasWonWithoutOdds)
        if !DeckStyle.isUnlocked(selectedDeckStyle, decksBeaten: decksBeaten) {
            selectedDeckStyleID = DeckStyle.classic.id
            UserDefaults.standard.set(DeckStyle.classic.id, forKey: DefaultsKey.selectedDeckStyleID)
        }
    }

    private func recordDailyResult() {
        let result = DailyResult(
            date: todayString,
            won: status == .won,
            correctGuesses: totalCorrect,
            bestStreak: runBestStreak,
            duration: Date().timeIntervalSince(runStartDate ?? Date())
        )
        dailyResult = result
        Self.saveDailyResult(result)
    }

    private static func loadDailyResult() -> DailyResult? {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.dailyResult),
              let result = try? JSONDecoder().decode(DailyResult.self, from: data)
        else { return nil }
        return result
    }

    private static func saveDailyResult(_ result: DailyResult) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.dailyResult)
    }

    private func recordWin() {
        let duration = Date().timeIntervalSince(runStartDate ?? Date())
        let entry = LeaderboardEntry(
            id: UUID(),
            date: Date(),
            correctGuesses: totalCorrect,
            bestStreakInRun: runBestStreak,
            duration: duration
        )
        leaderboard.append(entry)
        if leaderboard.count > 50 {
            leaderboard.removeFirst(leaderboard.count - 50)
        }
        Self.saveLeaderboard(leaderboard)
    }

    private static func loadLeaderboard() -> [LeaderboardEntry] {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.leaderboard),
              let entries = try? JSONDecoder().decode([LeaderboardEntry].self, from: data)
        else { return [] }
        return entries
    }

    private static func saveLeaderboard(_ entries: [LeaderboardEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.leaderboard)
    }
}
