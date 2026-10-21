import Foundation
import Combine

public class TaskManager: ObservableObject {
    @Published public var tasks: [TaskItem] = [] {
        didSet {
            saveTasks()
        }
    }

    private let storageKey = "TodoList_UserTasks_Storage_v1"
    private let calendar = Calendar.current

    public init() {
        loadTasks()
        if tasks.isEmpty {
            loadInitialSampleTasks()
        }
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
    public func addTask(title: String, notes: String, dueDate: Date, priority: TaskPriority) {
        let newTask = TaskItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            priority: priority
        )
        tasks.append(newTask)
    }

    public func toggleTaskCompletion(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
        }
    }

    public func deleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
    }

    public func deleteTask(withId id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    public func updateTask(_ updatedTask: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            tasks[index] = updatedTask
        }
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
