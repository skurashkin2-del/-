import Foundation
import SwiftUI

public enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low = "Низкий"
    case medium = "Обычный"
    case high = "Срочный"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    public var iconName: String {
        switch self {
        case .low:
            return "arrow.down"
        case .medium:
            return "minus"
        case .high:
            return "exclamationmark"
        }
    }
}

public enum RecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case none = "Без повтора"
    case daily = "Каждый день"
    case weekdays = "По будням"
    case weekly = "Каждую неделю"
    case monthly = "Каждый месяц"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .none:
            return "slash.circle"
        case .daily:
            return "repeat"
        case .weekdays:
            return "briefcase"
        case .weekly:
            return "calendar"
        case .monthly:
            return "calendar.badge.clock"
        }
    }
}

public struct SubTask: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool

    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

public struct TaskCategory: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var icon: String
    public var colorHex: String

    public init(id: String, name: String, icon: String, colorHex: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    public var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    public static let defaults: [TaskCategory] = [
        TaskCategory(id: "all", name: "Все", icon: "tray.fill", colorHex: "#3B82F6"),
        TaskCategory(id: "personal", name: "Личное", icon: "person.fill", colorHex: "#0EA5E9"),
        TaskCategory(id: "work", name: "Работа", icon: "briefcase.fill", colorHex: "#8B5CF6"),
        TaskCategory(id: "shopping", name: "Покупки", icon: "cart.fill", colorHex: "#10B981"),
        TaskCategory(id: "health", name: "Здоровье", icon: "heart.fill", colorHex: "#EF4444"),
        TaskCategory(id: "study", name: "Учёба", icon: "book.fill", colorHex: "#F59E0B")
    ]
}

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

public struct TaskItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var dueDate: Date
    public var isCompleted: Bool
    public var priority: TaskPriority
    public var createdAt: Date
    public var hasReminder: Bool
    public var reminderDate: Date?
    public var recurrence: RecurrenceRule
    public var categoryId: String
    public var subtasks: [SubTask]

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date = Date(),
        isCompleted: Bool = false,
        priority: TaskPriority = .medium,
        createdAt: Date = Date(),
        hasReminder: Bool = false,
        reminderDate: Date? = nil,
        recurrence: RecurrenceRule = .none,
        categoryId: String = "personal",
        subtasks: [SubTask] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.createdAt = createdAt
        self.hasReminder = hasReminder
        self.reminderDate = reminderDate ?? dueDate
        self.recurrence = recurrence
        self.categoryId = categoryId
        self.subtasks = subtasks
    }
}

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
