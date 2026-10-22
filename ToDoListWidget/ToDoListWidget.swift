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

// MARK: - Dynamic Storage Helper (Inspects All App Groups and Provisioning Profile)
enum WidgetStorage {
    static let tasksKey = "widget_today_tasks"
    static let examsKey = "widget_exams_list"

    static func discoverSuites() -> [String] {
        var suites = [
            "group.com.user.todolist",
            "group.com.user.todolist.widget"
        ]
        if let bundleId = Bundle.main.bundleIdentifier {
            suites.append("group.\(bundleId)")
            let cleanId = bundleId.replacingOccurrences(of: ".widget", with: "")
            suites.append("group.\(cleanId)")
        }

        // Dynamically parse embedded.mobileprovision for signer-injected App Groups
        if let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let content = String(data: data, encoding: .isoLatin1) {
            if let range = content.range(of: "<key>com.apple.security.application-groups</key>") {
                let sub = content[range.upperBound...]
                if let endRange = sub.range(of: "</array>") {
                    let arrayContent = String(sub[..<endRange.lowerBound])
                    let pattern = "<string>(.*?)</string>"
                    if let regex = try? NSRegularExpression(pattern: pattern) {
                        let nsStr = arrayContent as NSString
                        let matches = regex.matches(in: arrayContent, range: NSRange(location: 0, length: nsStr.length))
                        for match in matches {
                            if match.numberOfRanges > 1 {
                                let groupName = nsStr.substring(with: match.range(at: 1))
                                if !suites.contains(groupName) {
                                    suites.insert(groupName, at: 0)
                                }
                            }
                        }
                    }
                }
            }
        }
        return suites
    }

    static func loadTasks() -> [WidgetTaskItem]? {
        let suites = discoverSuites()

        // 1. Try Shared Container Directory Files
        for suite in suites {
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
        for suite in suites {
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

        return nil
    }

    static func loadExams() -> [WidgetExamItem]? {
        let suites = discoverSuites()

        for suite in suites {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite) {
                let fileURL = containerURL.appendingPathComponent("widget_exams.json")
                if let fileData = try? Data(contentsOf: fileURL),
                   let items = try? JSONDecoder().decode([WidgetExamItem].self, from: fileData),
                   !items.isEmpty {
                    return items
                }
            }
        }

        for suite in suites {
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

        return nil
    }
}

// MARK: - App Intent for Configurable Exam Countdown
public enum ExamChoice: String, AppEnum {
    case nearest = "nearest"
    case russian = "russian"
    case math = "math"
    case literature = "literature"
    case social = "social"
    case journalism = "journalism"
    case custom = "custom"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Событие"

    public static var caseDisplayRepresentations: [ExamChoice: DisplayRepresentation] = [
        .nearest: "Ближайший экзамен из приложения",
        .russian: "ЕГЭ Русский язык",
        .math: "ЕГЭ Базовая математика",
        .literature: "ЕГЭ Литература",
        .social: "ЕГЭ Обществознание",
        .journalism: "ДВИ по Журналистике",
        .custom: "Своё событие (ввести дату)"
    ]
}

public struct SelectExamIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Настроить отсчёт"
    public static var description = IntentDescription("Выберите экзамен или настройте своё событие.")

    @Parameter(title: "Экзамен / Событие", default: .nearest)
    public var selectedExam: ExamChoice

    @Parameter(title: "Своё название (для своего события)")
    public var customTitle: String?

    @Parameter(title: "Своя дата (ДД.ММ.ГГГГ)")
    public var customDateString: String?

    public init() {}
}

// MARK: - App Intent for Configurable Tasks Widget
public enum TaskWidgetMode: String, AppEnum {
    case autoSync = "autoSync"
    case manual = "manual"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Режим задач"

    public static var caseDisplayRepresentations: [TaskWidgetMode: DisplayRepresentation] = [
        .autoSync: "Автоматически из приложения",
        .manual: "Задать задачи вручную"
    ]
}

public struct SelectTasksIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Настройка списка задач"
    public static var description = IntentDescription("Выберите режим: автосинхронизация или ручной ввод задач.")

    @Parameter(title: "Режим", default: .autoSync)
    public var mode: TaskWidgetMode

    @Parameter(title: "Задача 1 (ручной режим)")
    public var customTask1: String?

    @Parameter(title: "Задача 2 (ручной режим)")
    public var customTask2: String?

    @Parameter(title: "Задача 3 (ручной режим)")
    public var customTask3: String?

    public init() {}
}

// MARK: - Exam Provider
struct ExamEntry: TimelineEntry {
    let date: Date
    let exam: DisplayExam
}

struct ExamAppIntentProvider: AppIntentTimelineProvider {
    typealias Entry = ExamEntry
    typealias Intent = SelectExamIntent

    func placeholder(in context: Context) -> ExamEntry {
        ExamEntry(date: Date(), exam: DisplayExam(title: "ЕГЭ Русский язык", daysRemaining: 34, dateString: "28 мая", colorHex: "#EF4444"))
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

        // 1. If user chose custom event or entered custom title/date
        if configuration.selectedExam == .custom || (configuration.customTitle != nil && !configuration.customTitle!.isEmpty) {
            let title = (configuration.customTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? configuration.customTitle! : "Мой экзамен"
            let targetDate = parseDate(configuration.customDateString) ?? calendar.date(byAdding: .day, value: 30, to: today)!
            let diff = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: targetDate)).day ?? 0
            return DisplayExam(title: title, daysRemaining: max(0, diff), dateString: formatDate(targetDate), colorHex: "#F59E0B")
        }

        // 2. Try reading synced exams from the app
        let syncedExams = WidgetStorage.loadExams() ?? []

        func findSynced(categoryId: String) -> DisplayExam? {
            if let match = syncedExams.first(where: { $0.categoryId == categoryId }) {
                return DisplayExam(title: match.title, daysRemaining: match.daysRemaining, dateString: match.dateString, colorHex: colorHex(for: categoryId))
            }
            return nil
        }

        switch configuration.selectedExam {
        case .nearest:
            if let first = syncedExams.first {
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
        case .custom:
            return fallbackExam(choice: .russian, today: today)
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
        case .custom:
            title = "Экзамен"
            comp.month = 6; comp.day = 15
            color = "#F59E0B"
        }

        var target = calendar.date(from: comp) ?? today.addingTimeInterval(86400 * 30)
        if target < today {
            comp.year = year + 1
            target = calendar.date(from: comp) ?? today.addingTimeInterval(86400 * 30)
        }

        let diff = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: target)).day ?? 0
        return DisplayExam(title: title, daysRemaining: max(0, diff), dateString: formatDate(target), colorHex: color)
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        let formatter = DateFormatter()
        for format in ["dd.MM.yyyy", "dd/MM/yyyy", "dd.MM.yy", "dd.MM", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let d = formatter.date(from: s) { return d }
        }
        return nil
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

// MARK: - Task Timeline Provider (with AppIntent configuration!)
struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTaskItem]
    let isConnected: Bool
}

struct TaskAppIntentProvider: AppIntentTimelineProvider {
    typealias Entry = TaskEntry
    typealias Intent = SelectTasksIntent

    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            tasks: [
                WidgetTaskItem(id: "1", title: "Задачи из приложения", isCompleted: false, priority: "Обычный")
            ],
            isConnected: true
        )
    }

    func snapshot(for configuration: SelectTasksIntent, in context: Context) async -> TaskEntry {
        resolveEntry(configuration: configuration)
    }

    func timeline(for configuration: SelectTasksIntent, in context: Context) async -> Timeline<TaskEntry> {
        let entry = resolveEntry(configuration: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func resolveEntry(configuration: SelectTasksIntent) -> TaskEntry {
        // 1. Manual Mode
        if configuration.mode == .manual {
            var items: [WidgetTaskItem] = []
            if let t1 = configuration.customTask1?.trimmingCharacters(in: .whitespacesAndNewlines), !t1.isEmpty {
                items.append(WidgetTaskItem(id: "m1", title: t1, isCompleted: false, priority: "Обычный"))
            }
            if let t2 = configuration.customTask2?.trimmingCharacters(in: .whitespacesAndNewlines), !t2.isEmpty {
                items.append(WidgetTaskItem(id: "m2", title: t2, isCompleted: false, priority: "Обычный"))
            }
            if let t3 = configuration.customTask3?.trimmingCharacters(in: .whitespacesAndNewlines), !t3.isEmpty {
                items.append(WidgetTaskItem(id: "m3", title: t3, isCompleted: false, priority: "Обычный"))
            }
            if items.isEmpty {
                items.append(WidgetTaskItem(id: "m0", title: "Зажмите виджет ➔ настройте задачи", isCompleted: false, priority: "Обычный"))
            }
            return TaskEntry(date: Date(), tasks: items, isConnected: true)
        }

        // 2. Auto Sync Mode from App
        if let synced = WidgetStorage.loadTasks(), !synced.isEmpty {
            return TaskEntry(date: Date(), tasks: synced, isConnected: true)
        }

        // 3. Fallback when App Groups is blocked by developer certificate
        return TaskEntry(
            date: Date(),
            tasks: [
                WidgetTaskItem(id: "f1", title: "Откройте приложение для синхронизации", isCompleted: false, priority: "Срочный"),
                WidgetTaskItem(id: "f2", title: "Или зажмите виджет ➔ ручной ввод", isCompleted: false, priority: "Обычный")
            ],
            isConnected: false
        )
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
        if var items = WidgetStorage.loadTasks() {
            if let idx = items.firstIndex(where: { $0.id == taskId }) {
                items[idx].isCompleted.toggle()
                if let data = try? JSONEncoder().encode(items) {
                    for suite in WidgetStorage.discoverSuites() {
                        UserDefaults(suiteName: suite)?.set(data, forKey: WidgetStorage.tasksKey)
                        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite) {
                            try? data.write(to: containerURL.appendingPathComponent("widget_tasks.json"))
                        }
                    }
                    UserDefaults.standard.set(data, forKey: WidgetStorage.tasksKey)
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
    var entry: TaskAppIntentProvider.Entry
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
                    Text("План")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text("\(pendingCount) ост.")
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

// MARK: - Views for Exam Widget
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
        AppIntentConfiguration(
            kind: kind,
            intent: SelectTasksIntent.self,
            provider: TaskAppIntentProvider()
        ) { entry in
            ToDoListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Задачи на день")
        .description("Список дел: автосинхронизация с приложением или настраиваемый ручной ввод.")
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
