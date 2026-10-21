import SwiftUI

public struct StatsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var taskManager: TaskManager
    @State private var showingExportShareSheet: Bool = false
    @State private var exportText: String = ""

    private var weeklyStats: [(dayName: String, count: Int, date: Date)] {
        taskManager.completedStatsForLast7Days()
    }

    private var maxCountInWeek: Int {
        max(1, weeklyStats.map { $0.count }.max() ?? 1)
    }

    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Streak Card
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 56, height: 56)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(taskManager.streakCount) \(streakDeclension(taskManager.streakCount)) подряд")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text(taskManager.streakCount > 0 ? "Отличный темп! Продолжайте в том же духе." : "Выполните задачу сегодня, чтобы запустить серию.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                    )
                    .padding(.horizontal)

                    // Summary Stats Row
                    HStack(spacing: 12) {
                        StatCounterBox(
                            title: "Завершено",
                            value: "\(taskManager.totalCompletedEver)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )

                        StatCounterBox(
                            title: "Успешность",
                            value: "\(Int(taskManager.overallCompletionRate * 100))%",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .blue
                        )

                        StatCounterBox(
                            title: "Всего задач",
                            value: "\(taskManager.tasks.count)",
                            icon: "list.bullet.clipboard.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)

                    // Weekly Bar Chart
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Активность за последние 7 дней")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(weeklyStats, id: \.date) { item in
                                VStack(spacing: 8) {
                                    Text("\(item.count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(item.count > 0 ? .primary : .secondary.opacity(0.6))

                                    // Bar
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(item.count > 0 ? Color.accentColor : Color.secondary.opacity(0.15))
                                        .frame(height: max(10, CGFloat(item.count) / CGFloat(maxCountInWeek) * 110))

                                    Text(item.dayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 160)
                        .padding(.top, 10)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                    )
                    .padding(.horizontal)

                    // Export section
                    VStack(spacing: 12) {
                        Button(action: {
                            exportText = taskManager.exportTasksJSON()
                            showingExportShareSheet = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Экспортировать резервную копию (JSON)")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 10)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Продуктивность")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportShareSheet) {
                ShareSheet(items: [exportText])
            }
        }
    }

    private func streakDeclension(_ count: Int) -> String {
        let n = count % 100
        let n1 = n % 10
        if n > 10 && n < 20 { return "дней" }
        if n1 > 1 && n1 < 5 { return "дня" }
        if n1 == 1 { return "день" }
        return "дней"
    }
}

private struct StatCounterBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        )
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
