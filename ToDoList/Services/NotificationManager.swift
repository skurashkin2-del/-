import Foundation
import UserNotifications

public class NotificationManager {
    public static let shared = NotificationManager()

    private init() {}

    public func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    public func scheduleNotification(for task: TaskItem) {
        // If task doesn't have reminder or is completed, cancel it
        guard task.hasReminder, let reminderDate = task.reminderDate, !task.isCompleted else {
            cancelNotification(for: task)
            return
        }

        // Only schedule if date is in the future
        guard reminderDate > Date() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Напоминание о задаче"
        content.body = task.title
        if !task.notes.isEmpty {
            content.subtitle = task.notes
        }
        content.sound = .default
        content.badge = 1

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    public func cancelNotification(for task: TaskItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }

    public func cancelNotification(withId id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}
