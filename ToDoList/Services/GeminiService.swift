import Foundation
import Combine

public struct AITaskProposal: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var title: String
    public var notes: String
    public var dateString: String // YYYY-MM-DD
    public var timeString: String? // HH:mm
    public var categoryId: String // russian, math, literature, social, journalism
    public var priorityString: String // low, medium, high
    public var subtasks: [String]
    public var isSelected: Bool = true

    enum CodingKeys: String, CodingKey {
        case title, notes, date, time, categoryId, priority, subtasks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Занятие"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        dateString = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        timeString = try container.decodeIfPresent(String.self, forKey: .time)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId) ?? "russian"
        priorityString = try container.decodeIfPresent(String.self, forKey: .priority) ?? "medium"
        subtasks = try container.decodeIfPresent([String].self, forKey: .subtasks) ?? []
        isSelected = true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(dateString, forKey: .date)
        try container.encodeIfPresent(timeString, forKey: .time)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(priorityString, forKey: .priority)
        try container.encode(subtasks, forKey: .subtasks)
    }

    public var parsedDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var baseDate = formatter.date(from: dateString) ?? Date()

        if let time = timeString, !time.isEmpty {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            if parts.count >= 2 {
                let cal = Calendar.current
                if let withTime = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: baseDate) {
                    baseDate = withTime
                }
            }
        }
        return baseDate
    }

    public var taskPriority: TaskPriority {
        switch priorityString.lowercased() {
        case "high", "высокий", "срочно", "срочный":
            return .high
        case "low", "низкий":
            return .low
        default:
            return .medium
        }
    }
}

public struct AIChatMessage: Identifiable, Equatable {
    public let id = UUID()
    public let isUser: Bool
    public let text: String
    public var proposedTasks: [AITaskProposal] = []
    public var isImported: Bool = false
    public let timestamp = Date()
}

public class GeminiService: ObservableObject {
    public static let shared = GeminiService()

    private static var initialKey: String {
        let b64 = "QVEuQWI4Uk42TEd6eG9QQ0J5V18zaWM2dnFSRy01NWVZWkg0MVpjV3hacXpQdzBKVFFrMlE="
        if let data = Data(base64Encoded: b64), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }
    private let storageKey = "Gemini_API_Key_v1"

    @Published public var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: storageKey)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: storageKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let key = saved, !key.isEmpty {
            self.apiKey = key
        } else {
            self.apiKey = Self.initialKey
        }
    }

    // MARK: - Send message to Gemini
    public func sendMessage(
        history: [AIChatMessage],
        userPrompt: String,
        categories: [TaskCategory],
        completion: @escaping (Result<(reply: String, tasks: [AITaskProposal]), Error>) -> Void
    ) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            completion(.failure(NSError(domain: "Gemini", code: 400, userInfo: [NSLocalizedDescriptionKey: "API-ключ не настроен"])))
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd, EEEE"
        dateFormatter.locale = Locale(identifier: "ru_RU")
        let todayInfo = dateFormatter.string(from: Date())

        let categoriesList = categories
            .filter { $0.id != "all" }
            .map { "- '\($0.id)': \($0.name)" }
            .joined(separator: "\n")

        let systemInstruction = """
        Ты — умный персональный ассистент и куратор подготовки к экзаменам (ЕГЭ и ДВИ) в приложении 'Мой План'.
        Сегодняшняя дата: \(todayInfo).

        Доступные предметы пользователя и их ID:
        \(categoriesList)

        Инструкции:
        1. Отвечай кратко, чётко, дружелюбно и мотивирующе на русском языке.
        2. Если пользователь просит распланировать задачи, расписание или вносит занятия:
           ОБЯЗАТЕЛЬНО включи в конец ответа блок с задачами в строгом формате JSON внутри тройных кавычек ```json ... ```:
           ```json
           [
             {
               "title": "Название задачи",
               "notes": "Пояснение или домашнее задание",
               "date": "YYYY-MM-DD",
               "time": "HH:mm",
               "categoryId": "russian" | "math" | "literature" | "social" | "journalism",
               "priority": "low" | "medium" | "high",
               "subtasks": ["Пункт 1", "Пункт 2"]
             }
           ]
           ```
        3. Даты ставь в формате YYYY-MM-DD начиная от сегодняшней (\(todayInfo)).
        """

        var contents: [[String: Any]] = []

        // Append recent history (up to last 6 messages)
        let recent = history.suffix(6)
        for msg in recent {
            contents.append([
                "role": msg.isUser ? "user" : "model",
                "parts": [["text": msg.text]]
            ])
        }

        // Current prompt with system context
        let fullUserText = "\(systemInstruction)\n\nЗапрос пользователя:\n\(userPrompt)"
        contents.append([
            "role": "user",
            "parts": [["text": fullUserText]]
        ])

        let payload: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": 0.4,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(NSError(domain: "Gemini", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ошибка создания запроса"])))
            return
        }

        // Try gemini-2.5-flash first, then fallback
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Gemini", code: 400, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 30

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "Пустой ответ от сервера"])))
                }
                return
            }

            // Check HTTP status
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode != 200 {
                let errString = String(data: data, encoding: .utf8) ?? "HTTP \(httpRes.statusCode)"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Gemini", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ошибка Gemini (\(httpRes.statusCode)): \(errString)"])))
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let replyText = parts.first?["text"] as? String {

                    let (cleanText, tasks) = Self.extractTasks(from: replyText)
                    DispatchQueue.main.async {
                        completion(.success((cleanText, tasks)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "Gemini", code: 422, userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить ответ модели"])))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Extract JSON task proposals from text
    public static func extractTasks(from rawText: String) -> (cleanText: String, tasks: [AITaskProposal]) {
        var clean = rawText
        var tasks: [AITaskProposal] = []

        // Look for ```json ... ``` blocks
        let pattern = "```(?:json)?\\s*(\\[[\\s\\S]*?\\])\\s*```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsText = rawText as NSString
            let matches = regex.matches(in: rawText, options: [], range: NSRange(location: 0, length: nsText.length))

            for match in matches {
                if match.numberOfRanges > 1 {
                    let jsonRange = match.range(at: 1)
                    let jsonString = nsText.substring(with: jsonRange)
                    if let jsonData = jsonString.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode([AITaskProposal].self, from: jsonData) {
                        tasks.append(contentsOf: decoded)
                    }
                }
                // Remove the raw code block from the conversational text
                clean = clean.replacingOccurrences(of: nsText.substring(with: match.range), with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // If no code block found, try searching for any standalone JSON array "[ ... ]"
        if tasks.isEmpty {
            let arrayPattern = "(\\[\\s*\\{[\\s\\S]*?\\}\\s*\\])"
            if let arrRegex = try? NSRegularExpression(pattern: arrayPattern, options: []) {
                let nsText = rawText as NSString
                if let match = arrRegex.firstMatch(in: rawText, options: [], range: NSRange(location: 0, length: nsText.length)) {
                    let jsonString = nsText.substring(with: match.range)
                    if let jsonData = jsonString.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode([AITaskProposal].self, from: jsonData) {
                        tasks = decoded
                        clean = clean.replacingOccurrences(of: jsonString, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        return (clean, tasks)
    }

    // MARK: - Local fallback smart parser (works even offline if user pastes text from browser Gemini!)
    public static func parsePastedTextLocally(text: String) -> [AITaskProposal] {
        // First try JSON extraction
        let (_, extracted) = extractTasks(from: text)
        if !extracted.isEmpty {
            return extracted
        }

        // Fallback: parse bullet points / line-by-line schedule
        var results: [AITaskProposal] = []
        let lines = text.components(separatedBy: .newlines)
        let calendar = Calendar.current
        var currentDate = Date()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Check if line indicates a day of week
            let lower = trimmed.lowercased()
            if let targetWeekday = detectWeekday(from: lower) {
                currentDate = nextDate(forWeekday: targetWeekday)
                continue
            }

            // Check if line looks like a task item (starts with -, *, •, 1., etc.)
            let isBullet = trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") || trimmed.range(of: "^\\d+[.)]", options: .regularExpression) != nil
            if isBullet || trimmed.contains("—") || trimmed.contains(":") {
                var cleanTitle = trimmed
                    .replacingOccurrences(of: "^[-•*\\d.)\\s]+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !cleanTitle.isEmpty else { continue }

                // Detect category
                let categoryId = detectCategory(from: cleanTitle)

                // Detect time if any (e.g., 18:00)
                var timeString: String? = nil
                if let timeMatch = cleanTitle.range(of: "\\b([01]?\\d|2[0-3]):[0-5]\\d\\b", options: .regularExpression) {
                    timeString = String(cleanTitle[timeMatch])
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateStr = dateFormatter.string(from: currentDate)

                let json = """
                {
                    "title": "\(cleanTitle)",
                    "notes": "",
                    "date": "\(dateStr)",
                    "time": "\(timeString ?? "")",
                    "categoryId": "\(categoryId)",
                    "priority": "medium",
                    "subtasks": []
                }
                """
                if let data = json.data(using: .utf8),
                   let proposal = try? JSONDecoder().decode(AITaskProposal.self, from: data) {
                    results.append(proposal)
                }
            }
        }

        return results
    }

    private static func detectCategory(from text: String) -> String {
        let l = text.lowercased()
        if l.contains("русск") || l.contains("сочинен") || l.contains("ударен") || l.contains("пароним") || l.contains("изложен") {
            return "russian"
        } else if l.contains("матем") || l.contains("геометр") || l.contains("алгебр") || l.contains("уравнен") || l.contains("задач") {
            return "math"
        } else if l.contains("литератур") || l.contains("книг") || l.contains("читат") || l.contains("стих") || l.contains("произведен") {
            return "literature"
        } else if l.contains("обществ") || l.contains("общаг") || l.contains("термин") || l.contains("конституц") || l.contains("право") || l.contains("эконом") {
            return "social"
        } else if l.contains("журнал") || l.contains("дви") || l.contains("стать") || l.contains("интервь") || l.contains("эссе") || l.contains("репортаж") {
            return "journalism"
        }
        return "russian"
    }

    private static func detectWeekday(from text: String) -> Int? {
        if text.contains("понедельник") || text.contains("пн") { return 2 }
        if text.contains("вторник") || text.contains("вт") { return 3 }
        if text.contains("сред") || text.contains("ср") { return 4 }
        if text.contains("четверг") || text.contains("чт") { return 5 }
        if text.contains("пятниц") || text.contains("пт") { return 6 }
        if text.contains("суббот") || text.contains("сб") { return 7 }
        if text.contains("воскресень") || text.contains("вс") { return 1 }
        return nil
    }

    private static func nextDate(forWeekday targetWeekday: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)

        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd < 0 { daysToAdd += 7 }
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }
}
