import SwiftUI

public struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onEdit: () -> Void

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: task.dueDate)
    }

    public var body: some View {
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

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted, color: .secondary)

                    Spacer()

                    // Priority Pill
                    HStack(spacing: 3) {
                        Image(systemName: task.priority.iconName)
                            .font(.system(size: 10, weight: .bold))
                        Text(task.priority.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
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

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(timeString)
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.top, 2)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit()
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
