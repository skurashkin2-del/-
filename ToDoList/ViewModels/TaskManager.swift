import Foundation
import Combine
import WidgetKit

public class TaskManager: ObservableObject {
    @Published public var tasks: [TaskItem] = [] {
        didSet {
            saveTasks()
            syncToWidget()
        }
    }

    @Published public var exams: [ExamEvent] = [] {
        didSet {
            saveExams()
            syncToWidget()
        }
    }

    @Published public var categories: [TaskCategory] = TaskCategory.defaults

    private let storageKey = "TodoList_UserTasks_Storage_v1"
    private let examsStorageKey = "TodoList_Exams_Storage_v1"
    private let widgetSuiteName = "group.com.user.todolist"
    private let widgetStorageKey = "widget_today_tasks"
    private let widgetExamsStorageKey = "widget_exams_list"
    private let calendar = Calendar.current

    public init() {
        loadTasks()
        loadExams()
        NotificationManager.shared.requestAuthorization()
        syncToWidget()
    }

    // MARK: - Filter by Date and Category
    public func tasks(for date: Date, categoryId: String = "all") -> [TaskItem] {
        tasks.filter { task in
            let isSameDay = calendar.isDate(task.dueDate, inSameDayAs: date)
            let matchesCategory = (categoryId == "all" || task.categoryId == categoryId)
            return isSameDay && matchesCategory
        }
        .sorted { (task1, task2) -> Bool in
            if task1.isCompleted != task2.isCompleted {
                return !task1.isCompleted
            }
            return task1.dueDate < task2.dueDate
        }
    }

    public func pendingTasksCount(for date: Date) -> Int {
        tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) && !$0.isCompleted }.count
    }

    public func totalTasksCount(for date: Date) -> Int {
        tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) }.count
    }

    public func completedTasksCount(for date: Date) -> Int {
        tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) && $0.isCompleted }.count
    }

    public func hasTasks(for date: Date) -> Bool {
        tasks.contains { calendar.isDate($0.dueDate, inSameDayAs: date) }
    }

    public func weekDays(for referenceDate: Date) -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return []
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekInterval.start)
        }
    }

    // MARK: - Overdue Tasks (Прошлые невыполненные)
    public func overdueTasks() -> [TaskItem] {
        let startOfToday = calendar.startOfDay(for: Date())
        return tasks.filter { !$0.isCompleted && $0.dueDate < startOfToday }
            .sorted { $0.dueDate < $1.dueDate }
    }

    public func rolloverOverdueTasksToToday() {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        for i in 0..<tasks.count {
            if !tasks[i].isCompleted && tasks[i].dueDate < startOfToday {
                let hour = calendar.component(.hour, from: tasks[i].dueDate)
                let minute = calendar.component(.minute, from: tasks[i].dueDate)
                if let newDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) {
                    tasks[i].dueDate = newDate
                    if tasks[i].hasReminder {
                        tasks[i].reminderDate = newDate
                        NotificationManager.shared.scheduleNotification(for: tasks[i])
                    }
                }
            }
        }
    }

    // MARK: - Task Mutations
    public func addTask(
        title: String,
        notes: String,
        dueDate: Date,
        priority: TaskPriority,
        hasReminder: Bool = false,
        reminderDate: Date? = nil,
        recurrence: RecurrenceRule = .none,
        categoryId: String = "russian",
        subtasks: [SubTask] = []
    ) {
        let newTask = TaskItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            priority: priority,
            hasReminder: hasReminder,
            reminderDate: reminderDate,
            recurrence: recurrence,
            categoryId: categoryId,
            subtasks: subtasks
        )
        tasks.append(newTask)
        if newTask.hasReminder {
            NotificationManager.shared.scheduleNotification(for: newTask)
        }
    }

    public func toggleTaskCompletion(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        let willBeCompleted = !tasks[index].isCompleted
        tasks[index].isCompleted = willBeCompleted

        let updated = tasks[index]
        if willBeCompleted {
            NotificationManager.shared.cancelNotification(for: updated)
            if updated.recurrence != .none {
                createNextRecurrence(for: updated)
            }
        } else if updated.hasReminder {
            NotificationManager.shared.scheduleNotification(for: updated)
        }
    }

    private func createNextRecurrence(for task: TaskItem) {
        var nextDate: Date? = nil
        let currentDueDate = task.dueDate

        switch task.recurrence {
        case .none:
            return
        case .daily:
            nextDate = calendar.date(byAdding: .day, value: 1, to: currentDueDate)
        case .weekdays:
            var testDate = calendar.date(byAdding: .day, value: 1, to: currentDueDate) ?? currentDueDate
            while calendar.isDateInWeekend(testDate) {
                testDate = calendar.date(byAdding: .day, value: 1, to: testDate) ?? testDate
            }
            nextDate = testDate
        case .weekly:
            nextDate = calendar.date(byAdding: .day, value: 7, to: currentDueDate)
        case .monthly:
            nextDate = calendar.date(byAdding: .month, value: 1, to: currentDueDate)
        }

        if let validNextDate = nextDate {
            let resetSubtasks = task.subtasks.map { SubTask(id: UUID(), title: $0.title, isCompleted: false) }
            var nextReminder: Date? = nil
            if task.hasReminder, let oldReminder = task.reminderDate {
                let interval = oldReminder.timeIntervalSince(task.dueDate)
                nextReminder = validNextDate.addingTimeInterval(interval)
            }

            let nextTask = TaskItem(
                id: UUID(),
                title: task.title,
                notes: task.notes,
                dueDate: validNextDate,
                isCompleted: false,
                priority: task.priority,
                createdAt: Date(),
                hasReminder: task.hasReminder,
                reminderDate: nextReminder,
                recurrence: task.recurrence,
                categoryId: task.categoryId,
                subtasks: resetSubtasks
            )
            tasks.append(nextTask)
            if nextTask.hasReminder {
                NotificationManager.shared.scheduleNotification(for: nextTask)
            }
        }
    }

    public func toggleSubtask(taskId: UUID, subtaskId: UUID) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        if let subIndex = tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) {
            tasks[taskIndex].subtasks[subIndex].isCompleted.toggle()
        }
    }

    public func deleteTask(_ task: TaskItem) {
        NotificationManager.shared.cancelNotification(for: task)
        tasks.removeAll { $0.id == task.id }
    }

    public func deleteTask(withId id: UUID) {
        NotificationManager.shared.cancelNotification(withId: id)
        tasks.removeAll { $0.id == id }
    }

    public func updateTask(_ updatedTask: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            tasks[index] = updatedTask
            if updatedTask.isCompleted {
                NotificationManager.shared.cancelNotification(for: updatedTask)
            } else if updatedTask.hasReminder {
                NotificationManager.shared.scheduleNotification(for: updatedTask)
            } else {
                NotificationManager.shared.cancelNotification(for: updatedTask)
            }
        }
    }

    // MARK: - Exams & Olympiads Mutations
    public func addExam(title: String, date: Date, categoryId: String, targetScore: String, notes: String) {
        let newExam = ExamEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            categoryId: categoryId,
            targetScore: targetScore.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        exams.append(newExam)
    }

    public func updateExam(_ exam: ExamEvent) {
        if let index = exams.firstIndex(where: { $0.id == exam.id }) {
            exams[index] = exam
        }
    }

    public func deleteExam(_ exam: ExamEvent) {
        exams.removeAll { $0.id == exam.id }
    }

    public var upcomingExams: [ExamEvent] {
        let startOfToday = calendar.startOfDay(for: Date())
        return exams.filter { $0.date >= startOfToday }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Search
    public func searchTasks(query: String) -> [TaskItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return tasks.filter {
            $0.title.lowercased().contains(q) ||
            $0.notes.lowercased().contains(q) ||
            $0.subtasks.contains { $0.title.lowercased().contains(q) }
        }
        .sorted { $0.dueDate > $1.dueDate }
    }

    // MARK: - Streak & Productivity Stats
    public var streakCount: Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        let todayTasks = tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: checkDate) }
        let hasCompletedToday = todayTasks.contains { $0.isCompleted }

        if hasCompletedToday {
            streak += 1
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return streak }
            checkDate = yesterday
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        for _ in 0..<365 {
            let dayTasks = tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: checkDate) }
            if dayTasks.contains(where: { $0.isCompleted }) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    public var totalCompletedEver: Int {
        tasks.filter { $0.isCompleted }.count
    }

    public var overallCompletionRate: Double {
        guard !tasks.isEmpty else { return 0.0 }
        return Double(totalCompletedEver) / Double(tasks.count)
    }

    public func completedStatsForLast7Days() -> [(dayName: String, count: Int, date: Date)] {
        let today = calendar.startOfDay(for: Date())
        var results: [(dayName: String, count: Int, date: Date)] = []

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"

        for offset in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
                let count = tasks.filter {
                    calendar.isDate($0.dueDate, inSameDayAs: date) && $0.isCompleted
                }.count
                let dayName = formatter.string(from: date).capitalized
                results.append((dayName: dayName, count: count, date: date))
            }
        }
        return results
    }

    // MARK: - JSON Export
    public func exportTasksJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(tasks),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }

    // MARK: - Widget Synchronization
    public func syncToWidget() {
        let today = Date()
        let todayTasks = tasks(for: today)
        let widgetItems = todayTasks.map {
            WidgetTaskItem(
                id: $0.id.uuidString,
                title: $0.title,
                isCompleted: $0.isCompleted,
                priority: $0.priority.rawValue
            )
        }

        let widgetExams = upcomingExams.prefix(5).map {
            WidgetExamItem(
                id: $0.id.uuidString,
                title: $0.title,
                daysRemaining: $0.daysRemaining,
                dateString: $0.formattedDate,
                categoryId: $0.categoryId
            )
        }

        // Encode tasks
        if let tasksData = try? JSONEncoder().encode(widgetItems) {
            if let groupDefaults = UserDefaults(suiteName: widgetSuiteName) {
                groupDefaults.set(tasksData, forKey: widgetStorageKey)
                groupDefaults.synchronize()
            }
            UserDefaults.standard.set(tasksData, forKey: widgetStorageKey)

            // Also write to shared file container if App Groups directory exists
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetSuiteName) {
                let fileURL = containerURL.appendingPathComponent("widget_tasks.json")
                try? tasksData.write(to: fileURL)
            }
        }

        // Encode exams
        if let examsData = try? JSONEncoder().encode(widgetExams) {
            if let groupDefaults = UserDefaults(suiteName: widgetSuiteName) {
                groupDefaults.set(examsData, forKey: widgetExamsStorageKey)
                groupDefaults.synchronize()
            }
            UserDefaults.standard.set(examsData, forKey: widgetExamsStorageKey)

            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetSuiteName) {
                let fileURL = containerURL.appendingPathComponent("widget_exams.json")
                try? examsData.write(to: fileURL)
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Persistence (SAFE FOR UPDATES)
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadTasks() {
        // ALWAYS keep user's existing tasks intact upon app update
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: savedData) {
            let validIds = Set(categories.map { $0.id })
            self.tasks = decoded.map { task in
                var t = task
                if !validIds.contains(t.categoryId) {
                    t.categoryId = "russian"
                }
                return t
            }
            return
        }

        // ONLY on the very first install when nothing was saved yet
        loadInitialSampleTasks()
    }

    private func saveExams() {
        if let encoded = try? JSONEncoder().encode(exams) {
            UserDefaults.standard.set(encoded, forKey: examsStorageKey)
        }
    }

    private func loadExams() {
        if let savedData = UserDefaults.standard.data(forKey: examsStorageKey),
           let decoded = try? JSONDecoder().decode([ExamEvent].self, from: savedData) {
            self.exams = decoded
            return
        }

        // Default initial exams if empty
        let currentYear = calendar.component(.year, from: Date())
        var comp = DateComponents()
        comp.year = currentYear
        comp.month = 5
        comp.day = 28
        let examDate1 = calendar.date(from: comp) ?? Date().addingTimeInterval(86400 * 30)

        comp.day = 31
        let examDate2 = calendar.date(from: comp) ?? Date().addingTimeInterval(86400 * 33)

        comp.month = 6
        comp.day = 4
        let examDate3 = calendar.date(from: comp) ?? Date().addingTimeInterval(86400 * 37)

        comp.day = 8
        let examDate4 = calendar.date(from: comp) ?? Date().addingTimeInterval(86400 * 41)

        comp.month = 7
        comp.day = 10
        let examDate5 = calendar.date(from: comp) ?? Date().addingTimeInterval(86400 * 70)

        exams = [
            ExamEvent(title: "ЕГЭ Русский язык", date: examDate1, categoryId: "russian", targetScore: "90+"),
            ExamEvent(title: "ЕГЭ Базовая математика", date: examDate2, categoryId: "math", targetScore: "5 (Отлично)"),
            ExamEvent(title: "ЕГЭ Обществознание", date: examDate3, categoryId: "social", targetScore: "85+"),
            ExamEvent(title: "ЕГЭ Литература", date: examDate4, categoryId: "literature", targetScore: "90+"),
            ExamEvent(title: "ДВИ по Журналистике", date: examDate5, categoryId: "journalism", targetScore: "Максимум")
        ]
    }

    private func loadInitialSampleTasks() {
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        tasks = [
            TaskItem(
                title: "Повторить орфоэпический словник и паронимы",
                notes: "Пройтись по ударениям из кодификатора ЕГЭ.",
                dueDate: today,
                isCompleted: false,
                priority: .high,
                recurrence: .none,
                categoryId: "russian",
                subtasks: [
                    SubTask(title: "Задание 4 (Ударения)", isCompleted: true),
                    SubTask(title: "Задание 5 (Паронимы)", isCompleted: false)
                ]
            ),
            TaskItem(
                title: "Решить вариант по базовой математике",
                notes: "Потренировать вычисления с дробями и геометрию.",
                dueDate: today,
                isCompleted: false,
                priority: .medium,
                recurrence: .weekly,
                categoryId: "math"
            ),
            TaskItem(
                title: "Прочитать критическую статью к произведению",
                notes: "Выписать ключевые цитаты и аргументы для сочинения.",
                dueDate: tomorrow,
                isCompleted: false,
                priority: .medium,
                recurrence: .none,
                categoryId: "literature"
            ),
            TaskItem(
                title: "Повторить блок «Человек и общество»",
                notes: "Составить развёрнутый план и выписать определения.",
                dueDate: tomorrow,
                isCompleted: false,
                priority: .medium,
                recurrence: .weekly,
                categoryId: "social"
            ),
            TaskItem(
                title: "Подготовить план репортажа / эссе",
                notes: "Выбрать актуальную тему, тезисы и структуру материала.",
                dueDate: today,
                isCompleted: false,
                priority: .high,
                recurrence: .none,
                categoryId: "journalism"
            )
        ]
    }
}
