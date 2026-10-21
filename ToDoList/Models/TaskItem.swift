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

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date = Date(),
        isCompleted: Bool = false,
        priority: TaskPriority = .medium,
        createdAt: Date = Date(),
        hasReminder: Bool = false,
        reminderDate: Date? = nil
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
