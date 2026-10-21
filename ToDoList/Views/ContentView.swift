import SwiftUI

public enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case pending = "В процессе"
    case completed = "Готово"

    public var id: String { rawValue }
}

public struct ContentView: View {
    @StateObject private var taskManager = TaskManager()
    @State private var selectedDate: Date = Date()
    @State private var filter: TaskFilter = .all
    @State private var isShowingAddTask: Bool = false
    @State private var taskToEdit: TaskItem? = nil

    private let calendar = Calendar.current

    private var formattedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        let str = formatter.string(from: selectedDate)
        return str.prefix(1).capitalized + str.dropFirst()
    }

    private var tasksForSelectedDate: [TaskItem] {
        let dayTasks = taskManager.tasks(for: selectedDate)
        switch filter {
        case .all:
            return dayTasks
        case .pending:
            return dayTasks.filter { !$0.isCompleted }
        case .completed:
            return dayTasks.filter { $0.isCompleted }
        }
    }

    private var totalCount: Int {
        taskManager.totalTasksCount(for: selectedDate)
    }

    private var completedCount: Int {
        taskManager.completedTasksCount(for: selectedDate)
    }

    private var progressRatio: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Week Strip
                    WeekCalendarView(selectedDate: $selectedDate, taskManager: taskManager)
                        .padding(.bottom, 6)
                        .background(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)

                    // Subheader with progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formattedDateTitle)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)

                                if totalCount > 0 {
                                    Text("\(completedCount) из \(totalCount) завершено")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Дел не запланировано")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Progress ring/badge
                            if totalCount > 0 {
                                ZStack {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                                        .frame(width: 36, height: 36)
                                    Circle()
                                        .trim(from: 0, to: CGFloat(progressRatio))
                                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 36, height: 36)
                                        .animation(.easeInOut, value: progressRatio)

                                    Text("\(Int(progressRatio * 100))%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                            }
                        }

                        // Filter Picker
                        Picker("Фильтр", selection: $filter) {
                            ForEach(TaskFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    // Task List or Empty View
                    if tasksForSelectedDate.isEmpty {
                        emptyStateView
                    } else {
                        List {
                            ForEach(tasksForSelectedDate) { task in
                                TaskRowView(
                                    task: task,
                                    onToggle: {
                                        taskManager.toggleTaskCompletion(task)
                                    },
                                    onEdit: {
                                        taskToEdit = task
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            taskManager.deleteTask(task)
                                        }
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }

                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowingAddTask = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Добавить задачу")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                                    .shadow(color: Color.accentColor.opacity(0.35), radius: 10, x: 0, y: 6)
                            )
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Мой План")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddTask = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $isShowingAddTask) {
                AddTaskView(taskManager: taskManager, initialDate: selectedDate)
            }
            .sheet(item: $taskToEdit) { task in
                AddTaskView(taskManager: taskManager, initialDate: task.dueDate, editingTask: task)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: filter == .completed ? "checklist.checked" : "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 6) {
                Text(filter == .completed ? "Нет завершенных задач" : "На этот день задач нет")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text(filter == .completed ? "Отметьте задачи в списке, чтобы они появились здесь." : "Нажмите кнопку ниже, чтобы запланировать первое дело на этот день.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}
