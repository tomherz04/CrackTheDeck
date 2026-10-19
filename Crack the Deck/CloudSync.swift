import Foundation

extension Notification.Name {
    static let cloudStatsDidChange = Notification.Name("CloudSync.statsDidChange")
}

/// Mirrors lifetime stats through iCloud's key-value store (NSUbiquitousKeyValueStore) so
/// progress follows the player across their devices. Cumulative "best" stats merge as
/// max(local, cloud) so a sync never rolls progress backward; the leaderboard is unioned by
/// entry id since it's a set of distinct wins rather than a single counter.
///
/// This is last-write-wins per field, not a true merge of concurrent offline play — if two
/// devices each rack up wins before ever syncing, the higher single count wins rather than
/// their sum. Acceptable for a casual stat screen; not appropriate for anything that needs
/// exact counts.
@MainActor
enum CloudSync {
    private static let store = NSUbiquitousKeyValueStore.default
    private static var isObserving = false

    static func start() {
        guard !isObserving else { return }
        isObserving = true
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { _ in
            Task { @MainActor in
                mergeFromCloud()
                NotificationCenter.default.post(name: .cloudStatsDidChange, object: nil)
            }
        }
        store.synchronize()
        mergeFromCloud()
    }

    /// Reconciles whatever iCloud currently has into UserDefaults, then pushes the merged
    /// result back up so every device converges. Called at launch and on remote changes.
    static func mergeFromCloud() {
        let defaults = UserDefaults.standard

        let decksBeaten = max(defaults.integer(forKey: DefaultsKey.decksBeaten), Int(store.longLong(forKey: DefaultsKey.decksBeaten)))
        defaults.set(decksBeaten, forKey: DefaultsKey.decksBeaten)

        let gamesPlayed = max(defaults.integer(forKey: DefaultsKey.gamesPlayed), Int(store.longLong(forKey: DefaultsKey.gamesPlayed)))
        defaults.set(gamesPlayed, forKey: DefaultsKey.gamesPlayed)

        let lifetimeBestStreak = max(defaults.integer(forKey: DefaultsKey.lifetimeBestStreak), Int(store.longLong(forKey: DefaultsKey.lifetimeBestStreak)))
        defaults.set(lifetimeBestStreak, forKey: DefaultsKey.lifetimeBestStreak)

        let hasWonWithoutOdds = defaults.bool(forKey: DefaultsKey.hasWonWithoutOdds) || store.bool(forKey: DefaultsKey.hasWonWithoutOdds)
        defaults.set(hasWonWithoutOdds, forKey: DefaultsKey.hasWonWithoutOdds)

        if defaults.string(forKey: DefaultsKey.selectedDeckStyleID) == nil, let cloudStyle = store.string(forKey: DefaultsKey.selectedDeckStyleID) {
            defaults.set(cloudStyle, forKey: DefaultsKey.selectedDeckStyleID)
        }

        let local = GameModel.loadLeaderboard()
        var merged = [UUID: LeaderboardEntry]()
        for entry in local { merged[entry.id] = entry }
        for entry in decodeLeaderboard(store.data(forKey: DefaultsKey.leaderboard)) { merged[entry.id] = entry }
        // Oldest first, matching GameModel.recordWin, which appends new wins and evicts from the front.
        let capped = Array(merged.values.sorted { $0.date < $1.date }.suffix(50))
        if capped != local {
            GameModel.saveLeaderboard(capped)
        }

        pushToCloud()
    }

    /// Mirrors the current local values up to iCloud so other devices pick them up. Only keys whose
    /// value actually changed are written, since every write is queued for upload to iCloud.
    static func pushToCloud() {
        let defaults = UserDefaults.standard
        setIfChanged(Int64(defaults.integer(forKey: DefaultsKey.decksBeaten)), forKey: DefaultsKey.decksBeaten)
        setIfChanged(Int64(defaults.integer(forKey: DefaultsKey.gamesPlayed)), forKey: DefaultsKey.gamesPlayed)
        setIfChanged(Int64(defaults.integer(forKey: DefaultsKey.lifetimeBestStreak)), forKey: DefaultsKey.lifetimeBestStreak)
        setIfChanged(defaults.bool(forKey: DefaultsKey.hasWonWithoutOdds), forKey: DefaultsKey.hasWonWithoutOdds)
        if let style = defaults.string(forKey: DefaultsKey.selectedDeckStyleID) {
            setIfChanged(style, forKey: DefaultsKey.selectedDeckStyleID)
        }
        if let data = defaults.data(forKey: DefaultsKey.leaderboard) {
            setIfChanged(data, forKey: DefaultsKey.leaderboard)
        }
    }

    private static func setIfChanged<T: Equatable>(_ value: T, forKey key: String) {
        guard store.object(forKey: key) as? T != value else { return }
        store.set(value, forKey: key)
    }

    /// Clears every synced key, both locally-mirrored and in iCloud, e.g. for "Reset All Stats" —
    /// otherwise the next merge would pull the old cloud values right back in.
    static func resetCloud() {
        store.removeObject(forKey: DefaultsKey.decksBeaten)
        store.removeObject(forKey: DefaultsKey.gamesPlayed)
        store.removeObject(forKey: DefaultsKey.lifetimeBestStreak)
        store.removeObject(forKey: DefaultsKey.hasWonWithoutOdds)
        store.removeObject(forKey: DefaultsKey.leaderboard)
    }

    private static func decodeLeaderboard(_ data: Data?) -> [LeaderboardEntry] {
        guard let data, let entries = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) else { return [] }
        return entries
    }
}
