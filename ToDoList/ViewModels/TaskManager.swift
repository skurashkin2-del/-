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

    @Published public var categories: [TaskCategory] = TaskCategory.defaults

    private let storageKey = "TodoList_UserTasks_Storage_v1"
    private let widgetSuiteName = "group.com.user.todolist"
    private let widgetStorageKey = "widget_today_tasks"
    private let calendar = Calendar.current

    public init() {
        loadTasks()
        if tasks.isEmpty {
            loadInitialSampleTasks()
        }
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
                // Set to today, keeping time of task
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

    // MARK: - Mutations
    public func addTask(
        title: String,
        notes: String,
        dueDate: Date,
        priority: TaskPriority,
        hasReminder: Bool = false,
        reminderDate: Date? = nil,
        recurrence: RecurrenceRule = .none,
        categoryId: String = "personal",
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

            // If recurring, schedule the next instance!
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
            // Reset subtasks completion
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

        // Check today first
        let todayTasks = tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: checkDate) }
        let hasCompletedToday = todayTasks.contains { $0.isCompleted }

        // If today has completed tasks, streak starts with today, otherwise check from yesterday
        if hasCompletedToday {
            streak += 1
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return streak }
            checkDate = yesterday
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        // Loop backwards in days
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

        if let encoded = try? JSONEncoder().encode(widgetItems) {
            if let groupDefaults = UserDefaults(suiteName: widgetSuiteName) {
                groupDefaults.set(encoded, forKey: widgetStorageKey)
                groupDefaults.synchronize()
            }
            UserDefaults.standard.set(encoded, forKey: widgetStorageKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Persistence
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadTasks() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: savedData) {
            self.tasks = decoded
        }
    }

    private func loadInitialSampleTasks() {
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        tasks = [
            TaskItem(
                title: "Добро пожаловать в To-Do!",
                notes: "Нажмите на кружок слева, чтобы отметить задачу как выполненную.",
                dueDate: today,
                isCompleted: false,
                priority: .medium,
                recurrence: .none,
                categoryId: "personal",
                subtasks: [
                    SubTask(title: "Попробовать добавить подзадачу", isCompleted: true),
                    SubTask(title: "Посмотреть статистику в шапке", isCompleted: false)
                ]
            ),
            TaskItem(
                title: "Спланировать неделю",
                notes: "Переключайте дни недели в верхней панели, чтобы планировать дела.",
                dueDate: today,
                isCompleted: false,
                priority: .high,
                recurrence: .weekly,
                categoryId: "work"
            ),
            TaskItem(
                title: "Утренняя зарядка",
                notes: "Разминка и стакан воды.",
                dueDate: tomorrow,
                isCompleted: false,
                priority: .low,
                recurrence: .daily,
                categoryId: "health"
            )
        ]
    }
}
