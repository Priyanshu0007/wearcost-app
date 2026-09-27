import Foundation
import Combine
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private let reminderIdentifier = "wearcost_nightly_reminder"

    @Published var isAuthorized: Bool = false
    @Published var isReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isReminderEnabled, forKey: "wearcost_reminder_enabled")
            if isReminderEnabled {
                scheduleReminder(at: reminderTime)
            } else {
                cancelReminder()
            }
        }
    }
    @Published var reminderTime: Date {
        didSet {
            UserDefaults.standard.set(reminderTime.timeIntervalSince1970, forKey: "wearcost_reminder_time")
            if isReminderEnabled {
                scheduleReminder(at: reminderTime)
            }
        }
    }

    private init() {
        self.isReminderEnabled = UserDefaults.standard.bool(forKey: "wearcost_reminder_enabled")

        let savedTimestamp = UserDefaults.standard.double(forKey: "wearcost_reminder_time")
        if savedTimestamp > 0 {
            self.reminderTime = Date(timeIntervalSince1970: savedTimestamp)
        } else {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 20
            components.minute = 0
            self.reminderTime = Calendar.current.date(from: components) ?? Date()
        }

        checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            if granted && self.isReminderEnabled {
                scheduleReminder(at: self.reminderTime)
            }
            return granted
        } catch {
            self.isAuthorized = false
            return false
        }
    }

    func scheduleReminder(at time: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Log Today's Outfit 👔"
        content.body = "Record the pieces you wore today to lower your Cost-Per-Wear and boost wardrobe utility!"
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }
}
