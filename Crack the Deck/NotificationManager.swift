import Foundation
import UserNotifications

/// Schedules the optional "Daily Challenge is ready" local reminder.
enum NotificationManager {
    private static let reminderID = "dailyChallengeReminder"
    private static let reminderHour = 18

    static func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                DispatchQueue.main.async { completion(true) }
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async { completion(granted) }
                }
            default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    /// Cancels any pending reminder, then reschedules one for later today (or tomorrow) only if
    /// reminders are enabled and the player hasn't already finished today's Daily Challenge.
    static func refreshDailyReminder(enabled: Bool, alreadyCompletedToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        guard enabled, !alreadyCompletedToday else { return }

        let calendar = Calendar.current
        let now = Date()
        var target = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: now) ?? now
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Crack the Deck"
        content.body = "Today's Daily Challenge is waiting — come crack it!"
        content.sound = .default

        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(request)
    }
}
