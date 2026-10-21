import SwiftUI

public struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    @ObservedObject var taskManager: TaskManager
    @State private var showingDatePicker: Bool = false

    private let calendar = Calendar.current

    public init(selectedDate: Binding<Date>, taskManager: TaskManager) {
        self._selectedDate = selectedDate
        self.taskManager = taskManager
    }

    private var currentWeekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start)
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        let string = formatter.string(from: selectedDate)
        return string.prefix(1).capitalized + string.dropFirst()
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Month navigation header
            HStack {
                Button(action: {
                    showingDatePicker.toggle()
                }) {
                    HStack(spacing: 6) {
                        Text(monthYearString)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .sheet(isPresented: $showingDatePicker) {
                    DatePickerSheet(selectedDate: $selectedDate)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: moveToPreviousWeek) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }

                    Button("Сегодня") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedDate = Date()
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())

                    Button(action: moveToNextWeek) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal)

            // 7 Days strip
            HStack(spacing: 8) {
                ForEach(currentWeekDays, id: \.self) { date in
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        pendingCount: taskManager.pendingTasksCount(for: date),
                        hasCompletedOnly: taskManager.hasTasks(for: date) && taskManager.pendingTasksCount(for: date) == 0,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
    }

    private func moveToPreviousWeek() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let newDate = calendar.date(byAdding: .day, value: -7, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }

    private func moveToNextWeek() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let newDate = calendar.date(byAdding: .day, value: 7, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let pendingCount: Int
    let hasCompletedOnly: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var weekdaySymbol: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).capitalized
    }

    private var dayNumberString: String {
        "\(calendar.component(.day, from: date))"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(weekdaySymbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)

                Text(dayNumberString)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : (isToday ? .accentColor : .primary))

                // Task indicator
                ZStack {
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isSelected ? .accentColor : .white)
                            .frame(width: 16, height: 16)
                            .background(isSelected ? Color.white : Color.accentColor)
                            .clipShape(Circle())
                    } else if hasCompletedOnly {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(isSelected ? .white : .green)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(UIColor.secondarySystemBackground).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isToday && !isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DatePickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedDate: Date

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Выберите дату",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Календарь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
