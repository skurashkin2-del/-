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

    // MARK: - Filter by Date
    public func tasks(for date: Date) -> [TaskItem] {
        tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) }
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

    // MARK: - Mutations
    public func addTask(
        title: String,
        notes: String,
        dueDate: Date,
        priority: TaskPriority,
        hasReminder: Bool = false,
        reminderDate: Date? = nil
    ) {
        let newTask = TaskItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            priority: priority,
            hasReminder: hasReminder,
            reminderDate: reminderDate
        )
        tasks.append(newTask)
        if newTask.hasReminder {
            NotificationManager.shared.scheduleNotification(for: newTask)
        }
    }

    public func toggleTaskCompletion(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            let updated = tasks[index]
            if updated.isCompleted {
                NotificationManager.shared.cancelNotification(for: updated)
            } else if updated.hasReminder {
                NotificationManager.shared.scheduleNotification(for: updated)
            }
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
            // Write to shared App Group container
            if let groupDefaults = UserDefaults(suiteName: widgetSuiteName) {
                groupDefaults.set(encoded, forKey: widgetStorageKey)
                groupDefaults.synchronize()
            }
            // Fallback to standard
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
                priority: .medium
            ),
            TaskItem(
                title: "Спланировать неделю",
                notes: "Переключайте дни недели в верхней панели, чтобы планировать дела.",
                dueDate: today,
                isCompleted: false,
                priority: .high
            ),
            TaskItem(
                title: "Зарядка и спорт",
                notes: "Выпить стакан воды и размяться.",
                dueDate: tomorrow,
                isCompleted: false,
                priority: .low
            )
        ]
    }
}
