import SwiftUI

public struct ExamsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var taskManager: TaskManager
    @State private var isShowingAddExam: Bool = false
    @State private var examToEdit: ExamEvent? = nil

    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    private var sortedExams: [ExamEvent] {
        taskManager.exams.sorted { $0.date < $1.date }
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                if sortedExams.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("Нет добавленных экзаменов")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Добавьте даты ЕГЭ, Олимпиад или дедлайнов, чтобы отслеживать обратный отсчёт.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button(action: { isShowingAddExam = true }) {
                            Text("Добавить экзамен")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                        Spacer()
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(sortedExams) { exam in
                            ExamCardView(
                                exam: exam,
                                category: taskManager.categories.first { $0.id == exam.categoryId },
                                onTap: {
                                    examToEdit = exam
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        taskManager.deleteExam(exam)
                                    }
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Экзамены и дедлайны")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { isShowingAddExam = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $isShowingAddExam) {
                AddExamSheet(taskManager: taskManager)
            }
            .sheet(item: $examToEdit) { exam in
                AddExamSheet(taskManager: taskManager, editingExam: exam)
            }
        }
    }
}

private struct ExamCardView: View {
    let exam: ExamEvent
    let category: TaskCategory?
    let onTap: () -> Void

    private var daysLeftText: String {
        let days = exam.daysRemaining
        if days == 0 {
            return "СЕГОДНЯ!"
        } else if days < 0 {
            return "Прошёл (\(-days) дн. назад)"
        } else {
            return "\(days) \(daysDeclension(days))"
        }
    }

    private var badgeColor: Color {
        let days = exam.daysRemaining
        if days < 0 { return .secondary }
        if days <= 7 { return .red }
        if days <= 30 { return .orange }
        return .blue
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let cat = category {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10))
                                Text(cat.name)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(cat.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(cat.color.opacity(0.12))
                            .clipShape(Capsule())
                        }

                        Text(exam.title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    // Countdown pill
                    VStack(spacing: 2) {
                        Text(daysLeftText)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(badgeColor)
                        if exam.daysRemaining > 0 {
                            Text("осталось")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badgeColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(exam.formattedDate)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    if !exam.targetScore.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.system(size: 11))
                            Text("Цель: \(exam.targetScore)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.green)
                    }
                }

                if !exam.notes.isEmpty {
                    Text(exam.notes)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private func daysDeclension(_ count: Int) -> String {
        let n = count % 100
        let n1 = n % 10
        if n > 10 && n < 20 { return "дней" }
        if n1 > 1 && n1 < 5 { return "дня" }
        if n1 == 1 { return "день" }
        return "дней"
    }
}

private struct AddExamSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var taskManager: TaskManager
    var editingExam: ExamEvent?

    @State private var title: String = ""
    @State private var date: Date = Date().addingTimeInterval(86400 * 30)
    @State private var categoryId: String = "russian"
    @State private var targetScore: String = ""
    @State private var notes: String = ""

    private var isEditing: Bool { editingExam != nil }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Событие")) {
                    TextField("Название (например: ЕГЭ Русский язык)", text: $title)
                        .font(.system(size: 16))

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
                }

                Section(header: Text("Дата проведения")) {
                    DatePicker("Дата события", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                }

                Section(header: Text("Цель и заметки")) {
                    TextField("Желаемый балл / цель (например: 90+)", text: $targetScore)
                    TextField("Заметки или место проведения", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Редактировать событие" : "Новый экзамен / олимпиада")
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
                if let exam = editingExam {
                    title = exam.title
                    date = exam.date
                    categoryId = exam.categoryId
                    targetScore = exam.targetScore
                    notes = exam.notes
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        if var exam = editingExam {
            exam.title = trimmedTitle
            exam.date = date
            exam.categoryId = categoryId
            exam.targetScore = targetScore.trimmingCharacters(in: .whitespacesAndNewlines)
            exam.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            taskManager.updateExam(exam)
        } else {
            taskManager.addExam(
                title: trimmedTitle,
                date: date,
                categoryId: categoryId,
                targetScore: targetScore,
                notes: notes
            )
        }
        presentationMode.wrappedValue.dismiss()
    }
}
