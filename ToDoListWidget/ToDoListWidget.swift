import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Models
struct WidgetTaskItem: Codable, Identifiable {
    var id: String
    var title: String
    var isCompleted: Bool
    var priority: String
}

struct WidgetExamItem: Codable, Identifiable {
    var id: String
    var title: String
    var daysRemaining: Int
    var dateString: String
    var categoryId: String
}

struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTaskItem]
}

struct ExamEntry: TimelineEntry {
    let date: Date
    let exams: [WidgetExamItem]
}

// MARK: - Helper Storage Reader
enum WidgetStorage {
    static let suiteName = "group.com.user.todolist"
    static let tasksKey = "widget_today_tasks"
    static let examsKey = "widget_exams_list"

    static func loadTasks() -> [WidgetTaskItem] {
        var data: Data? = nil

        // 1. Try Shared Container Directory File
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let fileURL = containerURL.appendingPathComponent("widget_tasks.json")
            if let fileData = try? Data(contentsOf: fileURL) {
                data = fileData
            }
        }

        // 2. Try App Group UserDefaults
        if data == nil, let groupDefaults = UserDefaults(suiteName: suiteName) {
            data = groupDefaults.data(forKey: tasksKey)
        }

        // 3. Try Standard UserDefaults
        if data == nil {
            data = UserDefaults.standard.data(forKey: tasksKey)
        }

        if let data = data,
           let items = try? JSONDecoder().decode([WidgetTaskItem].self, from: data) {
            return items
        }

        // Fallback sample tasks
        return [
            WidgetTaskItem(id: "1", title: "Повторить орфоэпию", isCompleted: false, priority: "Срочный"),
            WidgetTaskItem(id: "2", title: "Решить вариант по математике", isCompleted: true, priority: "Обычный"),
            WidgetTaskItem(id: "3", title: "Черновик эссе / заметки", isCompleted: false, priority: "Обычный")
        ]
    }

    static func loadExams() -> [WidgetExamItem] {
        var data: Data? = nil

        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let fileURL = containerURL.appendingPathComponent("widget_exams.json")
            if let fileData = try? Data(contentsOf: fileURL) {
                data = fileData
            }
        }

        if data == nil, let groupDefaults = UserDefaults(suiteName: suiteName) {
            data = groupDefaults.data(forKey: examsKey)
        }

        if data == nil {
            data = UserDefaults.standard.data(forKey: examsKey)
        }

        if let data = data,
           let items = try? JSONDecoder().decode([WidgetExamItem].self, from: data) {
            return items
        }

        return [
            WidgetExamItem(id: "1", title: "ЕГЭ Русский язык", daysRemaining: 34, dateString: "28 мая", categoryId: "russian"),
            WidgetExamItem(id: "2", title: "ЕГЭ Базовая математика", daysRemaining: 37, dateString: "31 мая", categoryId: "math"),
            WidgetExamItem(id: "3", title: "ЕГЭ Обществознание", daysRemaining: 41, dateString: "4 июня", categoryId: "social")
        ]
    }
}

// MARK: - Task Timeline Provider
struct TaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), tasks: WidgetStorage.loadTasks())
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> ()) {
        completion(TaskEntry(date: Date(), tasks: WidgetStorage.loadTasks()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> ()) {
        let entry = TaskEntry(date: Date(), tasks: WidgetStorage.loadTasks())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Exam Timeline Provider
struct ExamProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExamEntry {
        ExamEntry(date: Date(), exams: WidgetStorage.loadExams())
    }

    func getSnapshot(in context: Context, completion: @escaping (ExamEntry) -> ()) {
        completion(ExamEntry(date: Date(), exams: WidgetStorage.loadExams()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExamEntry>) -> ()) {
        let entry = ExamEntry(date: Date(), exams: WidgetStorage.loadExams())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - App Intent for Interactive Toggle
@available(iOS 16.0, *)
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Отметить задачу"

    @Parameter(title: "ID Задачи")
    var taskId: String

    init() {}
    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        var items = WidgetStorage.loadTasks()
        if let idx = items.firstIndex(where: { $0.id == taskId }) {
            items[idx].isCompleted.toggle()
            if let data = try? JSONEncoder().encode(items) {
                UserDefaults(suiteName: WidgetStorage.suiteName)?.set(data, forKey: WidgetStorage.tasksKey)
                UserDefaults.standard.set(data, forKey: WidgetStorage.tasksKey)
                if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetStorage.suiteName) {
                    try? data.write(to: containerURL.appendingPathComponent("widget_tasks.json"))
                }
            }
        }
        return .result()
    }
}

// MARK: - Views for Task Widget
struct TaskCheckboxCircle: View {
    let isCompleted: Bool

    var body: some View {
        Circle()
            .stroke(isCompleted ? Color.green : Color.secondary.opacity(0.4), lineWidth: 1.5)
            .background(isCompleted ? Circle().fill(Color.green) : Circle().fill(Color.clear))
            .frame(width: 11, height: 11)
            .overlay(
                Group {
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            )
    }
}

struct ToDoListWidgetEntryView: View {
    var entry: TaskProvider.Entry
    @Environment(\.widgetFamily) var family

    private var pendingCount: Int {
        entry.tasks.filter { !$0.isCompleted }.count
    }

    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE, d MMM"
        return formatter.string(from: entry.date).uppercased()
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            lockScreenCircularView
        case .accessoryRectangular:
            lockScreenRectangularView
        case .accessoryInline:
            lockScreenInlineView
        case .systemMedium:
            systemMediumView
        default:
            systemSmallView
        }
    }

    // 1. Lock Screen: Circular
    private var lockScreenCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                if pendingCount == 0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                } else {
                    Text("\(pendingCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Image(systemName: "checklist")
                        .font(.system(size: 8))
                }
            }
        }
    }

    // 2. Lock Screen: Rectangular
    private var lockScreenRectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .bold))
                Text("План на сегодня")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("\(pendingCount)")
                    .font(.system(size: 11, weight: .bold))
            }

            if let firstPending = entry.tasks.first(where: { !$0.isCompleted }) {
                Text("• \(firstPending.title)")
                    .font(.system(size: 11))
                    .lineLimit(1)
            } else {
                Text("Все задачи выполнены! 🎉")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // 3. Lock Screen: Inline
    private var lockScreenInlineView: some View {
        HStack(spacing: 3) {
            Image(systemName: "checklist")
            if pendingCount == 0 {
                Text("Все дела закрыты!")
            } else {
                Text("\(pendingCount) \(pendingCount == 1 ? "задача" : "задачи") осталось")
            }
        }
    }

    // 4. Home Screen: Small (.systemSmall)
    private var systemSmallView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(weekdayString)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
            }

            if entry.tasks.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                    Text("Дел нет")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else if pendingCount == 0 {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                    Text("Все сделано!")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Text("\(pendingCount) к выполнению")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Divider()
                    .padding(.vertical, 1)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(entry.tasks.prefix(3)) { task in
                        HStack(spacing: 6) {
                            if #available(iOS 17.0, *) {
                                Button(intent: ToggleTaskIntent(taskId: task.id)) {
                                    TaskCheckboxCircle(isCompleted: task.isCompleted)
                                }
                                .buttonStyle(.plain)
                            } else {
                                TaskCheckboxCircle(isCompleted: task.isCompleted)
                            }

                            Text(task.title)
                                .font(.system(size: 11, weight: task.isCompleted ? .regular : .medium))
                                .foregroundColor(task.isCompleted ? .secondary : .primary)
                                .strikethrough(task.isCompleted)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .widgetBackground()
    }

    // 5. Home Screen: Medium (.systemMedium)
    private var systemMediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(weekdayString)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(entry.tasks.filter { $0.isCompleted }.count) из \(entry.tasks.count) сделано")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                ForEach(entry.tasks.prefix(4)) { task in
                    HStack(spacing: 7) {
                        if #available(iOS 17.0, *) {
                            Button(intent: ToggleTaskIntent(taskId: task.id)) {
                                TaskCheckboxCircle(isCompleted: task.isCompleted)
                            }
                            .buttonStyle(.plain)
                        } else {
                            TaskCheckboxCircle(isCompleted: task.isCompleted)
                        }

                        Text(task.title)
                            .font(.system(size: 12, weight: task.isCompleted ? .regular : .medium))
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .widgetBackground()
    }
}

// MARK: - Views for Exam Widget
struct ExamWidgetEntryView: View {
    var entry: ExamProvider.Entry
    @Environment(\.widgetFamily) var family

    private var nearestExam: WidgetExamItem? {
        entry.exams.first
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    if let exam = nearestExam {
                        Text("\(exam.daysRemaining)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("дн")
                            .font(.system(size: 8, weight: .semibold))
                    } else {
                        Image(systemName: "flag.checkered")
                    }
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .bold))
                    Text("Экзамен")
                        .font(.system(size: 10, weight: .bold))
                }
                if let exam = nearestExam {
                    Text(exam.title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    Text("Через \(exam.daysRemaining) дн. (\(exam.dateString))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Text("Все экзамены сданы!")
                        .font(.system(size: 11))
                }
            }
        case .accessoryInline:
            if let exam = nearestExam {
                Text("\(exam.title): через \(exam.daysRemaining) дн.")
            } else {
                Text("Экзамены сданы!")
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                        Text("Экзамены и дедлайны")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.exams.prefix(3)) { exam in
                        HStack {
                            Text(exam.title)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(exam.daysRemaining) дн.")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .widgetBackground()
        default:
            // .systemSmall
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                    Text("ДО ЭКЗАМЕНА")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                if let exam = nearestExam {
                    Spacer(minLength: 0)
                    Text("\(exam.daysRemaining)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)

                    Text(exam.daysRemaining == 1 ? "день остался" : (exam.daysRemaining < 5 ? "дня осталось" : "дней осталось"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(exam.title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .padding(.top, 2)

                    Text(exam.dateString)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 0)
                } else {
                    Spacer()
                    Text("Все сдано! 🎉")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                }
            }
            .padding(12)
            .widgetBackground()
        }
    }
}

// MARK: - Widget Configurations
struct ToDoListWidget: Widget {
    let kind: String = "ToDoListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskProvider()) { entry in
            ToDoListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Задачи на сегодня")
        .description("Список дел и невыполненных задач на рабочий стол и экран блокировки.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct ExamCountdownWidget: Widget {
    let kind: String = "ExamCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExamProvider()) { entry in
            ExamWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Отсчёт до экзаменов")
        .description("Обратный отсчёт дней до ЕГЭ, олимпиад и дедлайнов.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Widget Bundle
@main
struct ToDoListWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ToDoListWidget()
        ExamCountdownWidget()
    }
}

// MARK: - Background Compatibility Helper
extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color(UIColor.secondarySystemBackground)
            }
        } else {
            self.background(Color(UIColor.secondarySystemBackground))
        }
    }
}
