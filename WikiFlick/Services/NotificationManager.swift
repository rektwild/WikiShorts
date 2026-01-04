import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isNotificationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isNotificationEnabled, forKey: "isNotificationEnabled")
            if isNotificationEnabled {
                scheduleAllNotifications()
            } else {
                cancelAllNotifications()
            }
        }
    }
    
    private let notificationTimes = [
        (hour: 8, minute: 0),   // 08:00
        (hour: 13, minute: 0),  // 13:00
        (hour: 18, minute: 0),  // 18:00
        (hour: 23, minute: 0)   // 23:00
    ]
    
    private init() {
        self.isNotificationEnabled = UserDefaults.standard.bool(forKey: "isNotificationEnabled")
    }
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            Logger.error("Notification permission error: \(error)", category: .general)
            return false
        }
    }
    
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    func scheduleAllNotifications() {
        guard isNotificationEnabled else { return }
        
        cancelAllNotifications()
        
        let languageManager = AppLanguageManager.shared
        let title = languageManager.localizedString(key: "daily_reminder_title")
        let body = languageManager.localizedString(key: "daily_reminder_body")
        
        for (index, time) in notificationTimes.enumerated() {
            scheduleNotification(
                identifier: "daily_reminder_\(index)",
                title: title,
                body: body,
                hour: time.hour,
                minute: time.minute
            )
        }
    }
    
    private func scheduleNotification(identifier: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Error scheduling notification \(identifier): \(error)", category: .general)
            } else {
                Logger.info("Successfully scheduled notification \(identifier) for \(hour):\(String(format: "%02d", minute))", category: .general)
            }
        }
    }
    
    func cancelAllNotifications() {
        let identifiers = notificationTimes.enumerated().map { "daily_reminder_\($0.offset)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func refreshNotifications() {
        guard isNotificationEnabled else { return }
        scheduleAllNotifications()
    }
}