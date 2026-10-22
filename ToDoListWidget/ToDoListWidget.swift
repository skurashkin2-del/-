import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Models
public struct WidgetTaskItem: Codable, Identifiable {
    public var id: String
    public var title: String
    public var isCompleted: Bool
    public var priority: String

    public init(id: String, title: String, isCompleted: Bool, priority: String) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
    }
}

public struct WidgetExamItem: Codable, Identifiable {
    public var id: String
    public var title: String
    public var daysRemaining: Int
    public var dateString: String
    public var categoryId: String

    public init(id: String, title: String, daysRemaining: Int, dateString: String, categoryId: String) {
        self.id = id
        self.title = title
        self.daysRemaining = daysRemaining
        self.dateString = dateString
        self.categoryId = categoryId
    }
}

public struct DisplayExam {
    public var title: String
    public var daysRemaining: Int
    public var dateString: String
    public var colorHex: String
}

// MARK: - App Storage Helper
enum WidgetStorage {
    static let suiteNames = [
        "group.com.user.todolist",
        "group.com.user.todolist.widget"
    ]
    static let tasksKey = "widget_today_tasks"
    static let examsKey = "widget_exams_list"

    static func loadTasks() -> [WidgetTaskItem] {
        // 1. Try Shared Container Directory Files
        for suite in suiteNames {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite) {
                let fileURL = containerURL.appendingPathComponent("widget_tasks.json")
                if let fileData = try? Data(contentsOf: fileURL),
                   let items = try? JSONDecoder().decode([WidgetTaskItem].self, from: fileData),
                   !items.isEmpty {
                    return items
                }
            }
        }

        // 2. Try App Group UserDefaults
        for suite in suiteNames {
            if let groupDefaults = UserDefaults(suiteName: suite),
               let data = groupDefaults.data(forKey: tasksKey),
               let items = try? JSONDecoder().decode([WidgetTaskItem].self, from: data),
               !items.isEmpty {
                return items
            }
        }

        // 3. Try Standard UserDefaults
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let items = try? JSONDecoder().decode([WidgetTaskItem].self, from: data),
           !items.isEmpty {
            return items
        }

        // Fallback default tasks
        return [
            WidgetTaskItem(id: "1", title: "Повторить орфоэпию (Русский)", isCompleted: false, priority: "Срочный"),
            WidgetTaskItem(id: "2", title: "Решить вариант (Математика)", isCompleted: true, priority: "Обычный"),
            WidgetTaskItem(id: "3", title: "Черновик заметки (Журналистика)", isCompleted: false, priority: "Обычный")
        ]
    }

    static func loadExams() -> [WidgetExamItem] {
        for suite in suiteNames {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite) {
                let fileURL = containerURL.appendingPathComponent("widget_exams.json")
                if let fileData = try? Data(contentsOf: fileURL),
                   let items = try? JSONDecoder().decode([WidgetExamItem].self, from: fileData),
                   !items.isEmpty {
                    return items
                }
            }
        }

        for suite in suiteNames {
            if let groupDefaults = UserDefaults(suiteName: suite),
               let data = groupDefaults.data(forKey: examsKey),
               let items = try? JSONDecoder().decode([WidgetExamItem].self, from: data),
               !items.isEmpty {
                return items
            }
        }

        if let data = UserDefaults.standard.data(forKey: examsKey),
           let items = try? JSONDecoder().decode([WidgetExamItem].self, from: data),
           !items.isEmpty {
            return items
        }

        return []
    }
}

// MARK: - App Intent for Configurable Exam Widget
public enum ExamChoice: String, AppEnum {
    case nearest = "nearest"
    case russian = "russian"
    case math = "math"
    case literature = "literature"
    case social = "social"
    case journalism = "journalism"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Событие"

    public static var caseDisplayRepresentations: [ExamChoice: DisplayRepresentation] = [
        .nearest: "Ближайший экзамен",
        .russian: "ЕГЭ Русский язык",
        .math: "ЕГЭ Базовая математика",
        .literature: "ЕГЭ Литература",
        .social: "ЕГЭ Обществознание",
        .journalism: "ДВИ по Журналистике"
    ]
}

public struct SelectExamIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Настроить отсчёт"
    public static var description = IntentDescription("Выберите экзамен или введите своё событие.")

    @Parameter(title: "Экзамен", default: .nearest)
    public var selectedExam: ExamChoice

    @Parameter(title: "Своё название (опционально)")
    public var customTitle: String?

    @Parameter(title: "Своя дата (ДД.ММ.ГГГГ, опционально)")
    public var customDate: String?

    public init() {}
}

// MARK: - Exam Provider with AppIntent
struct ExamEntry: TimelineEntry {
    let date: Date
    let exam: DisplayExam
}

struct ExamAppIntentProvider: AppIntentTimelineProvider {
    typealias Entry = ExamEntry
    typealias Intent = SelectExamIntent

    func placeholder(in context: Context) -> ExamEntry {
        ExamEntry(date: Date(), exam: resolveExam(configuration: SelectExamIntent()))
    }

    func snapshot(for configuration: SelectExamIntent, in context: Context) async -> ExamEntry {
        ExamEntry(date: Date(), exam: resolveExam(configuration: configuration))
    }

    func timeline(for configuration: SelectExamIntent, in context: Context) async -> Timeline<ExamEntry> {
        let exam = resolveExam(configuration: configuration)
        let entry = ExamEntry(date: Date(), exam: exam)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func resolveExam(configuration: SelectExamIntent) -> DisplayExam {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 1. If user entered custom event title and date
        if let customTitle = configuration.customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !customTitle.isEmpty {
            let targetDate = parseDate(configuration.customDate) ?? Date().addingTimeInterval(86400 * 30)
            let diff = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: targetDate)).day ?? 0
            let dateStr = formatDate(targetDate)
            return DisplayExam(title: customTitle, daysRemaining: diff, dateString: dateStr, colorHex: "#F59E0B")
        }

        // 2. Try synced exams from app
        let synced = WidgetStorage.loadExams()

        func findSynced(categoryId: String) -> DisplayExam? {
            if let match = synced.first(where: { $0.categoryId == categoryId }) {
                return DisplayExam(title: match.title, daysRemaining: match.daysRemaining, dateString: match.dateString, colorHex: colorHex(for: categoryId))
            }
            return nil
        }

        switch configuration.selectedExam {
        case .nearest:
            if let first = synced.first {
                return DisplayExam(title: first.title, daysRemaining: first.daysRemaining, dateString: first.dateString, colorHex: colorHex(for: first.categoryId))
            }
            return fallbackExam(choice: .russian, today: today)
        case .russian:
            return findSynced(categoryId: "russian") ?? fallbackExam(choice: .russian, today: today)
        case .math:
            return findSynced(categoryId: "math") ?? fallbackExam(choice: .math, today: today)
        case .literature:
            return findSynced(categoryId: "literature") ?? fallbackExam(choice: .literature, today: today)
        case .social:
            return findSynced(categoryId: "social") ?? fallbackExam(choice: .social, today: today)
        case .journalism:
            return findSynced(categoryId: "journalism") ?? fallbackExam(choice: .journalism, today: today)
        }
    }

    private func fallbackExam(choice: ExamChoice, today: Date) -> DisplayExam {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: today)

        var comp = DateComponents()
        comp.year = year

        var title = "ЕГЭ"
        var color = "#EF4444"

        switch choice {
        case .russian, .nearest:
            title = "ЕГЭ Русский язык"
            comp.month = 5; comp.day = 28
            color = "#EF4444"
        case .math:
            title = "ЕГЭ Базовая математика"
            comp.month = 5; comp.day = 31
            color = "#3B82F6"
        case .social:
            title = "ЕГЭ Обществознание"
            comp.month = 6; comp.day = 4
            color = "#10B981"
        case .literature:
            title = "ЕГЭ Литература"
            comp.month = 6; comp.day = 8
            color = "#8B5CF6"
        case .journalism:
            title = "ДВИ Журналистика"
            comp.month = 7; comp.day = 10
            color = "#F59E0B"
        }

        var target = calendar.date(from: comp) ?? today.addingTimeInterval(86400 * 30)
        if target < today {
            comp.year = year + 1
            target = calendar.date(from: comp) ?? today.addingTimeInterval(86400 * 30)
        }

        let diff = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: target)).day ?? 0
        return DisplayExam(title: title, daysRemaining: diff, dateString: formatDate(target), colorHex: color)
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        if let d = formatter.date(from: s) { return d }
        formatter.dateFormat = "dd/MM/yyyy"
        if let d = formatter.date(from: s) { return d }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: s)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    private func colorHex(for categoryId: String) -> String {
        switch categoryId {
        case "russian": return "#EF4444"
        case "math": return "#3B82F6"
        case "literature": return "#8B5CF6"
        case "social": return "#10B981"
        case "journalism": return "#F59E0B"
        default: return "#6366F1"
        }
    }
}

// MARK: - Task Timeline Provider
struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTaskItem]
}

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

// MARK: - Interactive Toggle Task Intent
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
                for suite in WidgetStorage.suiteNames {
                    UserDefaults(suiteName: suite)?.set(data, forKey: WidgetStorage.tasksKey)
                    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite) {
                        try? data.write(to: containerURL.appendingPathComponent("widget_tasks.json"))
                    }
                }
                UserDefaults.standard.set(data, forKey: WidgetStorage.tasksKey)
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
        case .accessoryRectangular:
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
        case .accessoryInline:
            HStack(spacing: 3) {
                Image(systemName: "checklist")
                if pendingCount == 0 {
                    Text("Все дела закрыты!")
                } else {
                    Text("\(pendingCount) \(pendingCount == 1 ? "задача" : "задачи") осталось")
                }
            }
        case .systemMedium:
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
                            Button(intent: ToggleTaskIntent(taskId: task.id)) {
                                TaskCheckboxCircle(isCompleted: task.isCompleted)
                            }
                            .buttonStyle(.plain)

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
            .containerBackground(for: .widget) {
                Color(UIColor.secondarySystemBackground)
            }
        default:
            // .systemSmall
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
                                Button(intent: ToggleTaskIntent(taskId: task.id)) {
                                    TaskCheckboxCircle(isCompleted: task.isCompleted)
                                }
                                .buttonStyle(.plain)

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
            .containerBackground(for: .widget) {
                Color(UIColor.secondarySystemBackground)
            }
        }
    }
}

// MARK: - Views for Configurable Exam Widget
struct ExamWidgetEntryView: View {
    var entry: ExamAppIntentProvider.Entry
    @Environment(\.widgetFamily) var family

    private var accentColor: Color {
        Color(hex: entry.exam.colorHex) ?? .orange
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(entry.exam.daysRemaining)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("дн")
                        .font(.system(size: 8, weight: .semibold))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .bold))
                    Text(entry.exam.title)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }
                Text("Через \(entry.exam.daysRemaining) дн. (\(entry.exam.dateString))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        case .accessoryInline:
            Text("\(entry.exam.title): через \(entry.exam.daysRemaining) дн.")
        case .systemMedium:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(accentColor)
                        Text("ОБРАТНЫЙ ОТСЧЁТ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(entry.exam.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .lineLimit(2)

                    Text(entry.exam.dateString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(entry.exam.daysRemaining)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)

                    Text(entry.exam.daysRemaining == 1 ? "день" : (entry.exam.daysRemaining < 5 ? "дня" : "дней"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
            }
            .padding(16)
            .containerBackground(for: .widget) {
                Color(UIColor.secondarySystemBackground)
            }
        default:
            // .systemSmall
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accentColor)
                    Text("ДО ЭКЗАМЕНА")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Spacer(minLength: 0)

                Text("\(entry.exam.daysRemaining)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)

                Text(entry.exam.daysRemaining == 1 ? "день остался" : (entry.exam.daysRemaining < 5 ? "дня осталось" : "дней осталось"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(entry.exam.title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .padding(.top, 2)

                Text(entry.exam.dateString)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer(minLength: 0)
            }
            .padding(12)
            .containerBackground(for: .widget) {
                Color(UIColor.secondarySystemBackground)
            }
        }
    }
}

// MARK: - Color Hex Helper
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Widgets
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
        AppIntentConfiguration(
            kind: kind,
            intent: SelectExamIntent.self,
            provider: ExamAppIntentProvider()
        ) { entry in
            ExamWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Отсчёт до экзаменов")
        .description("Настраиваемый обратный отсчёт до конкретного экзамена, олимпиады или своего события.")
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
