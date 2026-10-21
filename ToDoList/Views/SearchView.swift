import SwiftUI

public struct SearchView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var taskManager: TaskManager
    @State private var searchText: String = ""
    @State private var taskToEdit: TaskItem? = nil

    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    private var searchResults: [TaskItem] {
        taskManager.searchTasks(query: searchText)
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar input
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Поиск по всем задачам и заметкам...", text: $searchText)
                        .font(.system(size: 16))

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding()

                if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Начните вводить текст")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Поиск работает по названию, заметкам и подзадачам за все дни.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "questionmark.folder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Ничего не найдено")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Попробуйте изменить поисковый запрос.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(searchResults) { task in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(formattedDate(task.dueDate))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.accentColor)
                                    Spacer()
                                }
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
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(item: $taskToEdit) { task in
                AddTaskView(taskManager: taskManager, initialDate: task.dueDate, editingTask: task)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}
