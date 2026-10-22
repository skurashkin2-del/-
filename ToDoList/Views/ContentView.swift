import SwiftUI

public enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case pending = "В процессе"
    case completed = "Готово"

    public var id: String { rawValue }
}

public struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var taskManager = TaskManager()
    @State private var selectedDate: Date = Date()
    @State private var filter: TaskFilter = .all
    @State private var selectedCategoryId: String = "all"
    @State private var isShowingAddTask: Bool = false
    @State private var isShowingStats: Bool = false
    @State private var isShowingSearch: Bool = false
    @State private var isShowingExams: Bool = false
    @State private var isShowingWeeklyExport: Bool = false
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
        let dayTasks = taskManager.tasks(for: selectedDate, categoryId: selectedCategoryId)
        switch filter {
        case .all:
            return dayTasks
        case .pending:
            return dayTasks.filter { !$0.isCompleted }
        case .completed:
            return dayTasks.filter { $0.isCompleted }
        }
    }

    private var overdueTasksList: [TaskItem] {
        taskManager.overdueTasks()
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
                    // Overdue Rollover Banner
                    if !overdueTasksList.isEmpty {
                        overdueBannerView
                    }

                    // Week Calendar Strip
                    WeekCalendarView(selectedDate: $selectedDate, taskManager: taskManager)
                        .padding(.bottom, 4)
                        .background(Color(UIColor.systemBackground))

                    // Categories Horizontal Bar
                    categorySelectorView
                        .background(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)

                    // Subheader with progress & Streak
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(formattedDateTitle)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)

                                    if taskManager.streakCount > 0 {
                                        HStack(spacing: 3) {
                                            Image(systemName: "flame.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(.orange)
                                            Text("\(taskManager.streakCount)")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                }

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

                            // Progress ring
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
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                    // Task List or Empty View
                    if tasksForSelectedDate.isEmpty {
                        emptyStateView
                    } else {
                        List {
                            ForEach(tasksForSelectedDate) { task in
                                TaskRowView(
                                    task: task,
                                    taskManager: taskManager,
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
                                Text("Добавить")
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
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: { isShowingExams = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 15, weight: .semibold))
                                if let nearest = taskManager.upcomingExams.first {
                                    Text("\(nearest.daysRemaining) дн")
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                        }

                        Button(action: { isShowingStats = true }) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 15, weight: .semibold))
                        }

                        Button(action: { isShowingWeeklyExport = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button(action: {
                            isShowingSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                        }

                        Button(action: {
                            isShowingAddTask = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingAddTask) {
                AddTaskView(taskManager: taskManager, initialDate: selectedDate)
            }
            .sheet(item: $taskToEdit) { task in
                AddTaskView(taskManager: taskManager, initialDate: task.dueDate, editingTask: task)
            }
            .sheet(isPresented: $isShowingStats) {
                StatsView(taskManager: taskManager)
            }
            .sheet(isPresented: $isShowingSearch) {
                SearchView(taskManager: taskManager)
            }
            .sheet(isPresented: $isShowingExams) {
                ExamsView(taskManager: taskManager)
            }
            .sheet(isPresented: $isShowingWeeklyExport) {
                WeeklyExportView(taskManager: taskManager)
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    taskManager.syncToWidget()
                }
            }
        }
    }

    private var overdueBannerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.arrow.circlepath")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.orange)

            Text("Есть \(overdueTasksList.count) невыполненных дел с прошлых дней")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Button(action: {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    taskManager.rolloverOverdueTasksToToday()
                }
            }) {
                Text("На сегодня")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    private var categorySelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(taskManager.categories) { cat in
                    let isSelected = selectedCategoryId == cat.id
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedCategoryId = cat.id
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 11))
                            Text(cat.name)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ?
                            cat.color :
                            Color(UIColor.secondarySystemBackground)
                        )
                        .foregroundColor(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
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

                Text(filter == .completed ? "Отметьте задачи в списке, чтобы они появились здесь." : "Нажмите кнопку «Добавить», чтобы запланировать дело.")
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
