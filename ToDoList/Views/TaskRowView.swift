import SwiftUI

public struct TaskRowView: View {
    let task: TaskItem
    var taskManager: TaskManager? = nil
    let onToggle: () -> Void
    let onEdit: () -> Void

    @State private var isExpanded: Bool = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: task.dueDate)
    }

    private var reminderTimeString: String? {
        guard task.hasReminder, let reminderDate = task.reminderDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: reminderDate)
    }

    private var category: TaskCategory? {
        taskManager?.categories.first { $0.id == task.categoryId }
    }

    private var completedSubtasksCount: Int {
        taskManager?.tasks.first(where: { $0.id == task.id })?.subtasks.filter { $0.isCompleted }.count ?? task.subtasks.filter { $0.isCompleted }.count
    }

    private var currentSubtasks: [SubTask] {
        taskManager?.tasks.first(where: { $0.id == task.id })?.subtasks ?? task.subtasks
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                // Checkbox button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        onToggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(task.isCompleted ? Color.green : Color.secondary.opacity(0.4), lineWidth: 2)
                            .frame(width: 26, height: 26)

                        if task.isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 26, height: 26)

                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Main Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted, color: .secondary)

                        Spacer()

                        // Category Pill
                        if let cat = category, cat.id != "all" {
                            HStack(spacing: 3) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 9))
                                Text(cat.name)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(cat.color.opacity(0.12))
                            .foregroundColor(cat.color)
                            .clipShape(Capsule())
                        }

                        // Priority Pill
                        HStack(spacing: 3) {
                            Image(systemName: task.priority.iconName)
                                .font(.system(size: 10, weight: .bold))
                            Text(task.priority.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(task.priority.color.opacity(0.12))
                        .foregroundColor(task.priority.color)
                        .clipShape(Capsule())
                    }

                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    // Metadata Row
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(timeString)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary.opacity(0.8))

                        if let reminderStr = reminderTimeString {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 10))
                                Text(reminderStr)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.orange)
                        }

                        if task.recurrence != .none {
                            HStack(spacing: 4) {
                                Image(systemName: task.recurrence.iconName)
                                    .font(.system(size: 10))
                                Text(task.recurrence.rawValue)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.blue)
                        }

                        if !currentSubtasks.isEmpty {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checklist")
                                        .font(.system(size: 10))
                                    Text("\(completedSubtasksCount)/\(currentSubtasks.count)")
                                        .font(.system(size: 11, weight: .semibold))
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onEdit()
                }
            }

            // Expanded Subtasks List
            if isExpanded && !currentSubtasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .padding(.vertical, 2)

                    ForEach(currentSubtasks) { subtask in
                        HStack(spacing: 8) {
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation {
                                    taskManager?.toggleSubtask(taskId: task.id, subtaskId: subtask.id)
                                }
                            }) {
                                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(subtask.isCompleted ? .green : .secondary)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)

                            Text(subtask.title)
                                .font(.system(size: 13))
                                .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                                .strikethrough(subtask.isCompleted)

                            Spacer()
                        }
                        .padding(.leading, 40)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
}
