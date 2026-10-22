import SwiftUI

public struct WeeklyExportView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var taskManager: TaskManager
    @State private var referenceDate: Date = Date()
    @State private var renderedImage: UIImage? = nil
    @State private var showingShareSheet: Bool = false
    @State private var savedAlert: Bool = false

    private let calendar = Calendar.current

    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    private var weekDays: [Date] {
        taskManager.weekDays(for: referenceDate)
    }

    private var weekRangeTitle: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "Неделя" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        let str1 = formatter.string(from: first)
        let str2 = formatter.string(from: last)
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let yearStr = yearFormatter.string(from: last)
        return "\(str1) – \(str2) \(yearStr)"
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Week Switcher
                HStack {
                    Button(action: {
                        if let prev = calendar.date(byAdding: .day, value: -7, to: referenceDate) {
                            referenceDate = prev
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(weekRangeTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))

                    Spacer()

                    Button(action: {
                        if let next = calendar.date(byAdding: .day, value: 7, to: referenceDate) {
                            referenceDate = next
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                // Preview Card
                ScrollView {
                    WeeklyScheduleCard(weekDays: weekDays, taskManager: taskManager, rangeTitle: weekRangeTitle)
                        .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))

                // Bottom Export Buttons
                VStack(spacing: 10) {
                    Button(action: exportSchedule) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .bold))
                            Text("Поделиться расписанием")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button(action: saveToPhotoLibrary) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.badge.arrow.down")
                                .font(.system(size: 15))
                            Text("Сохранить картинку в Галерею")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle("Экспорт расписания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let img = renderedImage {
                    ShareActivityView(items: [img])
                }
            }
            .alert("Сохранено в Фото!", isPresented: $savedAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func renderImage() -> UIImage? {
        let card = WeeklyScheduleCard(weekDays: weekDays, taskManager: taskManager, rangeTitle: weekRangeTitle)
            .frame(width: 440)
            .background(Color(UIColor.systemBackground))

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0 // High Retina resolution for crisp text
        return renderer.uiImage
    }

    private func exportSchedule() {
        if let image = renderImage() {
            renderedImage = image
            showingShareSheet = true
        }
    }

    private func saveToPhotoLibrary() {
        if let image = renderImage() {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            savedAlert = true
        }
    }
}

private struct WeeklyScheduleCard: View {
    let weekDays: [Date]
    let taskManager: TaskManager
    let rangeTitle: String

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("План подготовки на неделю")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(rangeTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                }

                Spacer()

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.accentColor)
            }
            .padding(.bottom, 6)

            Divider()

            // 7 Days
            ForEach(weekDays, id: \.self) { date in
                let dayTasks = taskManager.tasks(for: date)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dayHeaderString(date))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(calendar.isDateInToday(date) ? .accentColor : .primary)

                        Spacer()

                        Text("\(dayTasks.filter { $0.isCompleted }.count)/\(dayTasks.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    if dayTasks.isEmpty {
                        Text("— нет задач")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.leading, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(dayTasks) { task in
                                HStack(spacing: 6) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(task.isCompleted ? .green : .secondary)

                                    if let cat = taskManager.categories.first(where: { $0.id == task.categoryId }), cat.id != "all" {
                                        Text(cat.name)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(cat.color)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(cat.color.opacity(0.12))
                                            .clipShape(Capsule())
                                    }

                                    Text(task.title)
                                        .font(.system(size: 12, weight: task.isCompleted ? .regular : .medium))
                                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                                        .strikethrough(task.isCompleted)
                                        .lineLimit(1)
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                if date != weekDays.last {
                    Divider()
                        .opacity(0.6)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }

    private func dayHeaderString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        let str = formatter.string(from: date)
        return str.prefix(1).capitalized + str.dropFirst()
    }
}

private struct ShareActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
