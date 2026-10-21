import WidgetKit
import SwiftUI

struct WidgetTaskItem: Codable, Identifiable {
    var id: String
    var title: String
    var isCompleted: Bool
    var priority: String
}

struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTaskItem]
}

struct Provider: TimelineProvider {
    private let widgetSuiteName = "group.com.user.todolist"
    private let widgetStorageKey = "widget_today_tasks"

    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            tasks: [
                WidgetTaskItem(id: "1", title: "Спланировать день", isCompleted: true, priority: "Обычный"),
                WidgetTaskItem(id: "2", title: "Спортзал в 18:00", isCompleted: false, priority: "Срочный"),
                WidgetTaskItem(id: "3", title: "Купить продукты", isCompleted: false, priority: "Низкий")
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> ()) {
        let entry = loadTasksFromStorage()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> ()) {
        let entry = loadTasksFromStorage()
        // Refresh periodically (every 30 minutes)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadTasksFromStorage() -> TaskEntry {
        var data: Data? = nil
        if let groupDefaults = UserDefaults(suiteName: widgetSuiteName) {
            data = groupDefaults.data(forKey: widgetStorageKey)
        }
        if data == nil {
            data = UserDefaults.standard.data(forKey: widgetStorageKey)
        }

        if let data = data,
           let items = try? JSONDecoder().decode([WidgetTaskItem].self, from: data) {
            return TaskEntry(date: Date(), tasks: items)
        }

        return TaskEntry(date: Date(), tasks: [])
    }
}

struct ToDoListWidgetEntryView: View {
    var entry: Provider.Entry

    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE, d MMM"
        return formatter.string(from: entry.date).uppercased()
    }

    private var pendingCount: Int {
        entry.tasks.filter { !$0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(alignment: .center) {
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
                            Circle()
                                .stroke(task.isCompleted ? Color.green : Color.secondary.opacity(0.4), lineWidth: 1.5)
                                .background(task.isCompleted ? Circle().fill(Color.green) : Circle().fill(Color.clear))
                                .frame(width: 9, height: 9)
                                .overlay(
                                    Group {
                                        if task.isCompleted {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 5, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                )

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
}

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

@main
struct ToDoListWidget: Widget {
    let kind: String = "ToDoListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ToDoListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Мой План")
        .description("Список задач на сегодня.")
        .supportedFamilies([.systemSmall])
    }
}
