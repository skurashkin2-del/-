import SwiftUI

public struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var taskManager: TaskManager

    var initialDate: Date
    var editingTask: TaskItem?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Date()
    @State private var priority: TaskPriority = .medium

    public init(taskManager: TaskManager, initialDate: Date, editingTask: TaskItem? = nil) {
        self.taskManager = taskManager
        self.initialDate = initialDate
        self.editingTask = editingTask
    }

    private var isEditing: Bool {
        editingTask != nil
    }

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Основное")) {
                    TextField("Что нужно сделать?", text: $title)
                        .font(.system(size: 16))

                    TextField("Заметки или детали (необязательно)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 15))
                }

                Section(header: Text("Дата и время")) {
                    DatePicker("Срок", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }

                Section(header: Text("Приоритет")) {
                    Picker("Приоритет", selection: $priority) {
                        ForEach(TaskPriority.allCases) { p in
                            HStack {
                                Circle()
                                    .fill(p.color)
                                    .frame(width: 8, height: 8)
                                Text(p.rawValue)
                            }
                            .tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(isEditing ? "Редактировать" : "Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Сохранить" : "Добавить") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if let task = editingTask {
                    title = task.title
                    notes = task.notes
                    dueDate = task.dueDate
                    priority = task.priority
                } else {
                    // Set dueDate keeping current hour/minute but setting day to initialDate
                    let calendar = Calendar.current
                    let now = Date()
                    let hour = calendar.component(.hour, from: now)
                    let minute = calendar.component(.minute, from: now)
                    if let combined = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: initialDate) {
                        dueDate = combined
                    } else {
                        dueDate = initialDate
                    }
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        if var task = editingTask {
            task.title = trimmedTitle
            task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            task.dueDate = dueDate
            task.priority = priority
            taskManager.updateTask(task)
        } else {
            taskManager.addTask(
                title: trimmedTitle,
                notes: notes,
                dueDate: dueDate,
                priority: priority
            )
        }
        presentationMode.wrappedValue.dismiss()
    }
}
