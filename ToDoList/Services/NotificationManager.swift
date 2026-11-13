import Foundation
import UserNotifications

public struct ToxicNotificationMessage {
    public let title: String
    public let body: String
}

public class NotificationManager {
    public static let shared = NotificationManager()

    private let calendar = Calendar.current
    private let toxicIdentifiers = [
        "toxic_evening_early",
        "toxic_evening_prime",
        "toxic_evening_late",
        "toxic_tomorrow_evening"
    ]

    public static let toxicEveningPhrases: [ToxicNotificationMessage] = [
        ToxicNotificationMessage(
            title: "⚠️ Слышишь? Это твоё будущее плачет",
            body: "День на исходе, а задачи так и висят! Конкуренты уже готовятся занять твоё место в вузе. Живо за учёбу!"
        ),
        ToxicNotificationMessage(
            title: "🤡 Конкуренты передают СПАСИБО",
            body: "Пока ты листаешь ленту, другие зубрят теорию и решают тесты. Ты так и собираешься всё слить?"
        ),
        ToxicNotificationMessage(
            title: "💀 Задачи сами себя не закроют",
            body: "Ты думаешь, экзаменаторы пожалеют тебя за красивые глаза? Открывай планер и добивай долги!"
        ),
        ToxicNotificationMessage(
            title: "📉 План на сегодня: полный провал?",
            body: "Вечер наступил, а задачи не закрыты. Не позорься — закрой дела до полуночи!"
        ),
        ToxicNotificationMessage(
            title: "🧹 Дворники стране тоже нужны",
            body: "Но ты вроде планировал поступить в приличный вуз? Тогда почему дела на сегодня заброшены?!"
        ),
        ToxicNotificationMessage(
            title: "🔥 Дедлайн стучит ногами в дверь",
            body: "Опять перенос на завтра? Спойлер: завтра легче не станет. Иди и сделай прямо сейчас!"
        ),
        ToxicNotificationMessage(
            title: "👀 Мы всё видим",
            body: "Ты серьезно собираешься лечь спать с незакрытыми делами? Докажи себе, что ты не тряпка!"
        ),
        ToxicNotificationMessage(
            title: "⚡ Хватит деградировать",
            body: "Осталось немного времени до конца дня. Сделай хотя бы главное, хватит кормить лень!"
        ),
        ToxicNotificationMessage(
            title: "🤦‍♂️ Оправдания не помогут на экзамене",
            body: "Баллы за лень и жалость к себе не начисляют. Открывай конспекты и закрой горящие задачи!"
        ),
        ToxicNotificationMessage(
            title: "🏆 Мечтаешь о бюджете?",
            body: "С таким отношением к сегодняшним задачам бюджет тебе только приснится. Быстро за работу!"
        ),
        ToxicNotificationMessage(
            title: "🚨 Внимание: прокрастинация зашкаливает",
            body: "Список дел на сегодня не закрыт. С такими темпами диплом престижного вуза достанется не тебе!"
        ),
        ToxicNotificationMessage(
            title: "🥱 Устал? Конкуренты не устали",
            body: "Они прямо сейчас повторяют сложный материал. Закрой задачи на сегодня и спи спокойно!"
        )
    ]

    private init() {}

    public func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Task Reminder
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

        let components = calendar.dateComponents(
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

    // MARK: - TOXIC STUDY MOTIVATION NOTIFICATIONS
    public func scheduleToxicEveningNotifications(tasks: [TaskItem]) {
        // Remove prior toxic schedule to avoid duplicate spam
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toxicIdentifiers)

        let todayPending = tasks.filter { calendar.isDateInToday($0.dueDate) && !$0.isCompleted }
        let now = Date()

        // If there are unfinished tasks for today, schedule evening toxic alerts
        if !todayPending.isEmpty {
            let shuffled = Self.toxicEveningPhrases.shuffled()

            // Slots: 19:30, 21:15, 22:45
            let slots: [(id: String, hour: Int, minute: Int, phrase: ToxicNotificationMessage)] = [
                ("toxic_evening_early", 19, 30, shuffled[0 % shuffled.count]),
                ("toxic_evening_prime", 21, 15, shuffled[1 % shuffled.count]),
                ("toxic_evening_late", 22, 45, shuffled[2 % shuffled.count])
            ]

            for slot in slots {
                var comp = calendar.dateComponents([.year, .month, .day], from: now)
                comp.hour = slot.hour
                comp.minute = slot.minute
                comp.second = 0

                if let triggerDate = calendar.date(from: comp), triggerDate > now {
                    let content = UNMutableNotificationContent()
                    content.title = slot.phrase.title
                    content.body = "\(slot.phrase.body) (Осталось дел: \(todayPending.count))"
                    content.sound = .defaultCriticalSound(withAudioVolume: 1.0)
                    content.badge = NSNumber(value: todayPending.count)

                    let triggerComp = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComp, repeats: false)
                    let request = UNNotificationRequest(identifier: slot.id, content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request)
                }
            }
        }

        // Also schedule a tomorrow evening toxic reminder in case user forgets to check the app tomorrow
        var tomorrowComp = calendar.dateComponents([.year, .month, .day], from: now)
        if let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) {
            tomorrowComp = calendar.dateComponents([.year, .month, .day], from: tomorrowDate)
            tomorrowComp.hour = 21
            tomorrowComp.minute = 0
            tomorrowComp.second = 0

            let tomorrowPhrase = Self.toxicEveningPhrases.randomElement() ?? Self.toxicEveningPhrases[0]
            let content = UNMutableNotificationContent()
            content.title = tomorrowPhrase.title
            content.body = tomorrowPhrase.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: tomorrowComp, repeats: false)
            let request = UNNotificationRequest(identifier: "toxic_tomorrow_evening", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
