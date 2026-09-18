import XCTest
@testable import Crack_the_Deck

final class GameModelTests: XCTestCase {

    private var originalDecksBeaten = 0
    private var originalLifetimeBestStreak = 0
    private var originalHasWonWithoutOdds = false
    private var originalLeaderboardData: Data?

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        originalDecksBeaten = defaults.integer(forKey: DefaultsKey.decksBeaten)
        originalLifetimeBestStreak = defaults.integer(forKey: DefaultsKey.lifetimeBestStreak)
        originalHasWonWithoutOdds = defaults.bool(forKey: DefaultsKey.hasWonWithoutOdds)
        originalLeaderboardData = defaults.data(forKey: DefaultsKey.leaderboard)
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        defaults.set(originalDecksBeaten, forKey: DefaultsKey.decksBeaten)
        defaults.set(originalLifetimeBestStreak, forKey: DefaultsKey.lifetimeBestStreak)
        defaults.set(originalHasWonWithoutOdds, forKey: DefaultsKey.hasWonWithoutOdds)
        if let originalLeaderboardData {
            defaults.set(originalLeaderboardData, forKey: DefaultsKey.leaderboard)
        } else {
            defaults.removeObject(forKey: DefaultsKey.leaderboard)
        }
        super.tearDown()
    }

    /// Always guessing the direction that matches the actual next card should clear the
    /// whole deck without ever losing a pile, ending in `.won`.
    @MainActor
    func testWinsWhenEveryGuessIsCorrect() async throws {
        let game = GameModel()
        try await waitForDeal(game)

        while game.status == .playing {
            guard let index = firstLivePileIndex(in: game) else {
                return XCTFail("No live pile left while the game is still marked as playing")
            }
            if game.selectedIndex != index {
                game.selectCell(index)
            }
            guard case .faceUp(let current) = game.grid[index], let upcoming = game.deck.first else {
                return XCTFail("Expected a face-up card and a card left in the deck")
            }

            let direction: GuessDirection = upcoming.rank == current.rank ? .same
                : (upcoming.rank > current.rank ? .higher : .lower)
            game.guess(direction, oddsVisible: false)
            try await waitForResolve(game)
        }

        XCTAssertEqual(game.status, .won)
        XCTAssertEqual(game.deckCount, 0)
    }

    /// Always guessing a direction that cannot match the actual next card kills every pile
    /// before the deck runs out, ending in `.lost`.
    @MainActor
    func testLosesWhenEveryGuessIsWrong() async throws {
        let game = GameModel()
        try await waitForDeal(game)

        while game.status == .playing {
            guard let index = firstLivePileIndex(in: game) else {
                return XCTFail("No live pile left while the game is still marked as playing")
            }
            if game.selectedIndex != index {
                game.selectCell(index)
            }
            guard case .faceUp(let current) = game.grid[index], let upcoming = game.deck.first else {
                return XCTFail("Expected a face-up card and a card left in the deck")
            }

            // Never guess .same, and pick the one of .lower/.higher that's guaranteed wrong.
            let direction: GuessDirection = upcoming.rank >= current.rank ? .lower : .higher
            game.guess(direction, oddsVisible: false)
            try await waitForResolve(game)
        }

        XCTAssertEqual(game.status, .lost)
        XCTAssertFalse(game.grid.contains { if case .faceUp = $0 { return true }; return false })
    }

    // MARK: - Helpers

    @MainActor
    private func firstLivePileIndex(in game: GameModel) -> Int? {
        (0..<9).first {
            if case .faceUp = game.grid[$0] { return true }
            return false
        }
    }

    @MainActor
    private func waitForDeal(_ game: GameModel) async throws {
        while game.isDealing {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    @MainActor
    private func waitForResolve(_ game: GameModel) async throws {
        while game.isResolving {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
