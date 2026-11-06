import SwiftUI

// MARK: - Chip для быстрого заполнения
private struct QuickFillChip: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12))
                .foregroundColor(.accentColor)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AddTaskView
public struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var taskManager: TaskManager

    var initialDate: Date
    var editingTask: TaskItem?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Date()
    @State private var priority: TaskPriority = .medium
    @State private var hasReminder: Bool = false
    @State private var reminderDate: Date = Date()
    @State private var recurrence: RecurrenceRule = .none
    @State private var weeklyRepeat: Bool = false
    @State private var categoryId: String = "russian"
    @State private var subtasks: [SubTask] = []
    @State private var newSubtaskTitle: String = ""
    @State private var showQuickFill: Bool = true

    public init(taskManager: TaskManager, initialDate: Date, editingTask: TaskItem? = nil) {
        self.taskManager = taskManager
        self.initialDate = initialDate
        self.editingTask = editingTask
    }

    private var isEditing: Bool { editingTask != nil }

    // Название дня недели из даты (на русском)
    private func weekdayName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    public var body: some View {
        NavigationView {
            Form {

                // ─── ЗАДАЧА ───────────────────────────────────────────────
                Section(header: Text("ЗАДАЧА")) {
                    TextField("Что нужно сделать?", text: $title)
                        .font(.system(size: 16))

                    TextField("Заметки к задаче (опционально)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 15))
                }

                // ─── ПРЕДМЕТ + БЫСТРОЕ ЗАПОЛНЕНИЕ ────────────────────────
                Section(header: Text("ПРЕДМЕТ")) {
                    Picker("Предмет", selection: $categoryId) {
                        ForEach(taskManager.categories.filter { $0.id != "all" }) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                    .foregroundColor(cat.color)
                                Text(cat.name)
                            }
                            .tag(cat.id)
                        }
                    }
                    .onChange(of: categoryId) { _ in
                        // При смене предмета показываем подсказки снова
                        showQuickFill = true
                    }

                    // Быстрые подсказки: «Занятие» + последние названия по предмету
                    if showQuickFill && !isEditing {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("⚡ Быстрое заполнение")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !title.isEmpty {
                                    Button("Скрыть") { showQuickFill = false }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // «Занятие» — всегда первая кнопка
                                    QuickFillChip(label: "Занятие") {
                                        title = "Занятие"
                                        showQuickFill = false
                                    }
                                    // Последние уникальные названия задач по этому предмету
                                    ForEach(taskManager.recentTitles(for: categoryId), id: \.self) { suggestion in
                                        if suggestion != "Занятие" {
                                            QuickFillChip(label: suggestion) {
                                                title = suggestion
                                                showQuickFill = false
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                // ─── ДАТА И ПОВТОР ────────────────────────────────────────
                Section(header: Text("ДАТА И ПОВТОР")) {
                    DatePicker("Дата", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)

                    // Простой тумблер «повторять каждую неделю»
                    Toggle(isOn: $weeklyRepeat) {
                        HStack(spacing: 10) {
                            Image(systemName: weeklyRepeat ? "repeat.circle.fill" : "repeat.circle")
                                .foregroundColor(weeklyRepeat ? .accentColor : .secondary)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Повторять каждую неделю")
                                    .font(.system(size: 15))
                                if weeklyRepeat {
                                    Text("Каждый \(weekdayName(from: dueDate))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onChange(of: weeklyRepeat) { enabled in
                        recurrence = enabled ? .weekly : .none
                    }
                    .onChange(of: dueDate) { _ in
                        // Когда тумблер включён, recurrence всегда остаётся weekly
                        if weeklyRepeat { recurrence = .weekly }
                    }
                }

                // ─── НАПОМИНАНИЕ ──────────────────────────────────────────
                Section(header: Text("НАПОМИНАНИЕ")) {
                    Toggle(isOn: $hasReminder) {
                        HStack(spacing: 8) {
                            Image(systemName: hasReminder ? "bell.fill" : "bell")
                                .foregroundColor(hasReminder ? .orange : .secondary)
                            Text("Уведомить в срок")
                        }
                    }
                    .onChange(of: hasReminder) { enabled in
                        if enabled {
                            NotificationManager.shared.requestAuthorization()
                            if reminderDate < Date() { reminderDate = dueDate }
                        }
                    }

                    if hasReminder {
                        DatePicker("Время напоминания", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                    }
                }

                // ─── ПОДЗАДАЧИ ────────────────────────────────────────────
                Section(header: Text("ПОДЗАДАЧИ (чек-лист)")) {
                    ForEach(subtasks) { subtask in
                        HStack {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(subtask.isCompleted ? .green : .secondary)
                            Text(subtask.title)
                                .strikethrough(subtask.isCompleted)
                            Spacer()
                            Button(action: {
                                subtasks.removeAll { $0.id == subtask.id }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("Новый пункт...", text: $newSubtaskTitle)
                            .onSubmit { addSubtask() }

                        Button(action: addSubtask) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                        }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                // ─── ПРИОРИТЕТ ────────────────────────────────────────────
                Section(header: Text("ПРИОРИТЕТ")) {
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
                    hasReminder = task.hasReminder
                    reminderDate = task.reminderDate ?? task.dueDate
                    recurrence = task.recurrence
                    weeklyRepeat = (task.recurrence == .weekly)
                    categoryId = task.categoryId
                    subtasks = task.subtasks
                    showQuickFill = false
                } else {
                    let calendar = Calendar.current
                    let now = Date()
                    let hour = calendar.component(.hour, from: now)
                    let minute = calendar.component(.minute, from: now)
                    if let combined = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: initialDate) {
                        dueDate = combined
                        reminderDate = combined
                    } else {
                        dueDate = initialDate
                        reminderDate = initialDate
                    }
                }
            }
        }
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        subtasks.append(SubTask(title: trimmed, isCompleted: false))
        newSubtaskTitle = ""
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        if var task = editingTask {
            task.title = trimmedTitle
            task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            task.dueDate = dueDate
            task.priority = priority
            task.hasReminder = hasReminder
            task.reminderDate = hasReminder ? reminderDate : nil
            task.recurrence = recurrence
            task.categoryId = categoryId
            task.subtasks = subtasks
            taskManager.updateTask(task)
        } else {
            taskManager.addTask(
                title: trimmedTitle,
                notes: notes,
                dueDate: dueDate,
                priority: priority,
                hasReminder: hasReminder,
                reminderDate: hasReminder ? reminderDate : nil,
                recurrence: recurrence,
                categoryId: categoryId,
                subtasks: subtasks
            )
        }
        presentationMode.wrappedValue.dismiss()
    }
}
