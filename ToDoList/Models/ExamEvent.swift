import Foundation

public struct ExamEvent: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var date: Date
    public var categoryId: String
    public var targetScore: String
    public var notes: String

    public init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        categoryId: String = "russian",
        targetScore: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.categoryId = categoryId
        self.targetScore = targetScore
        self.notes = notes
    }

    public var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        return components.day ?? 0
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

public struct WidgetExamItem: Codable, Identifiable {
    public var id: String
    public var title: String
    public var daysRemaining: Int
    public var dateString: String
    public var categoryId: String

    public init(id: String, title: String, daysRemaining: Int, dateString: String, categoryId: String) {
        self.id = id
        self.title = title
        self.daysRemaining = daysRemaining
        self.dateString = dateString
        self.categoryId = categoryId
    }
}
