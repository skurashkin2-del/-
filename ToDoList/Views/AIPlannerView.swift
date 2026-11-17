import SwiftUI

public struct AIPlannerView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var taskManager: TaskManager
    @StateObject private var geminiService = GeminiService.shared

    @State private var selectedTab: Int = 0 // 0 = Chat, 1 = Smart Paste
    @State private var messages: [AIChatMessage] = [
        AIChatMessage(
            isUser: false,
            text: "Привет! Я твой личный AI-куратор на базе Gemini. Напиши мне, какие у тебя занятия, курсы или темы для подготовки на эту неделю — я сам составлю расписание и в один клик перенесу всё в твой календарь!"
        )
    ]
    @State private var inputText: String = ""
    @State private var pastedText: String = ""
    @State private var isThinking: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSettings: Bool = false
    @State private var apiKeyInput: String = ""
    @State private var parsedFromPaste: [AITaskProposal] = []
    @State private var pasteImportSuccess: Bool = false

    private let suggestions = [
        "📅 Составь сбалансированный план на неделю",
        "⚡ Во вт и чт курсы по обществу в 18:00, распланируй неделю",
        "✍️ Накидай задачи по сочинению ЕГЭ и литературе",
        "🔥 Жесткий план на выходные: русский и математика"
    ]

    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented control: Chat vs Paste
                Picker("Режим", selection: $selectedTab) {
                    Text("💬 AI-Чат").tag(0)
                    Text("📋 Умная вставка").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))

                if selectedTab == 0 {
                    chatView
                } else {
                    smartPasteView
                }
            }
            .navigationTitle("✨ Gemini Планировщик")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        apiKeyInput = geminiService.apiKey
                        showSettings = true
                    }) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                apiKeySheet
            }
        }
    }

    // MARK: - CHAT VIEW
    private var chatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(messages) { message in
                            chatMessageBubble(message)
                                .id(message.id)
                        }

                        if isThinking {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.85)
                                Text("Gemini планирует задачи...")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .id("thinking_indicator")
                        }

                        if let err = errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isThinking) {
                    if isThinking {
                        withAnimation {
                            proxy.scrollTo("thinking_indicator", anchor: .bottom)
                        }
                    }
                }
            }

            // Quick Suggestions Chips
            if messages.count <= 2 && !isThinking {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: {
                                inputText = suggestion
                                sendMessage()
                            }) {
                                Text(suggestion)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 8) {
                TextField("Опиши курсы или задачи...", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(18)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking ? .secondary : .accentColor)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
        }
    }

    // MARK: - Chat Bubble
    private func chatMessageBubble(_ message: AIChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if message.isUser {
                Spacer()
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .cornerRadius(18)
                    .padding(.leading, 40)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(18)

                    // If message contains generated tasks
                    if !message.proposedTasks.isEmpty {
                        proposedTasksCard(for: message)
                    }
                }
                .padding(.trailing, 24)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Proposed Tasks Card
    private func proposedTasksCard(for message: AIChatMessage) -> some View {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
            return AnyView(EmptyView())
        }

        let tasks = messages[index].proposedTasks
        let isImported = messages[index].isImported

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.purple)
                        .font(.system(size: 14, weight: .bold))
                    Text("Сформировано задач: \(tasks.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    if isImported {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Добавлено")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.bottom, 2)

                // List of tasks
                ForEach(tasks.indices, id: \.self) { i in
                    let item = tasks[i]
                    let cat = taskManager.categories.first(where: { $0.id == item.categoryId }) ?? TaskCategory.defaults[1]

                    HStack(spacing: 8) {
                        if !isImported {
                            Button(action: {
                                messages[index].proposedTasks[i].isSelected.toggle()
                            }) {
                                Image(systemName: messages[index].proposedTasks[i].isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(messages[index].proposedTasks[i].isSelected ? .accentColor : .secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text(cat.name)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(cat.color.opacity(0.15))
                                    .foregroundColor(cat.color)
                                    .clipShape(Capsule())
                            }

                            HStack(spacing: 8) {
                                Text(formatProposalDate(item.parsedDate))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                if let time = item.timeString, !time.isEmpty {
                                    Text("⏰ \(time)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                if !item.subtasks.isEmpty {
                                    Text("• \(item.subtasks.count) подзадач")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                }

                // Import Button
                if !isImported {
                    let selected = tasks.filter { $0.isSelected }
                    Button(action: {
                        importTasks(from: index)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("📥 Добавить в расписание (\(selected.count))")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .disabled(selected.isEmpty)
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color.purple.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.purple.opacity(0.25), lineWidth: 1)
            )
        )
    }

    // MARK: - SMART PASTE VIEW
    private var smartPasteView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Вставь текст из Gemini")
                        .font(.system(size: 16, weight: .bold))
                    Text("Если ты уже составил план в браузере или приложении Gemini — просто скопируй его целиком и вставь сюда. Приложение само извлечёт задачи.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                TextEditor(text: $pastedText)
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .overlay(
                        Group {
                            if pastedText.isEmpty {
                                Text("Нажми и вставь текст расписания сюда...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .padding(.leading, 24)
                                    .padding(.top, 16)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )

                HStack(spacing: 10) {
                    Button(action: parsePastedText) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Распознать через AI")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                    }
                    .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(action: {
                        if let clip = UIPasteboard.general.string {
                            pastedText = clip
                            parsePastedText()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Вставить")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)

                // Parsed results
                if !parsedFromPaste.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Найдено задач: \(parsedFromPaste.count)")
                                .font(.system(size: 15, weight: .bold))
                            Spacer()
                            if pasteImportSuccess {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Добавлено в план")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        ForEach(parsedFromPaste.indices, id: \.self) { i in
                            let item = parsedFromPaste[i]
                            let cat = taskManager.categories.first(where: { $0.id == item.categoryId }) ?? TaskCategory.defaults[1]

                            HStack(spacing: 10) {
                                if !pasteImportSuccess {
                                    Button(action: {
                                        parsedFromPaste[i].isSelected.toggle()
                                    }) {
                                        Image(systemName: parsedFromPaste[i].isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(parsedFromPaste[i].isSelected ? .accentColor : .secondary)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(item.title)
                                            .font(.system(size: 14, weight: .semibold))
                                        Spacer()
                                        Text(cat.name)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(cat.color.opacity(0.15))
                                            .foregroundColor(cat.color)
                                            .clipShape(Capsule())
                                    }

                                    HStack(spacing: 8) {
                                        Text(formatProposalDate(item.parsedDate))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                        if let time = item.timeString, !time.isEmpty {
                                            Text("⏰ \(time)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        }

                        if !pasteImportSuccess {
                            let selected = parsedFromPaste.filter { $0.isSelected }
                            Button(action: importPastedTasks) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("📥 Добавить все выбранные (\(selected.count))")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(selected.isEmpty)
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - API Key Sheet
    private var apiKeySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Gemini API Ключ"), footer: Text("Ключ привязан к твоему Google-аккаунту и используется для составления и парсинга расписания.")) {
                    SecureField("Введи ключ...", text: $apiKeyInput)
                        .font(.system(size: 14, design: .monospaced))

                    Button("Вставить из буфера") {
                        if let str = UIPasteboard.general.string {
                            apiKeyInput = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
            }
            .navigationTitle("Настройки Gemini")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { showSettings = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        geminiService.apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        showSettings = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    // MARK: - Actions
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }

        errorMessage = nil
        inputText = ""

        // Append user message
        let userMsg = AIChatMessage(isUser: true, text: text)
        messages.append(userMsg)
        isThinking = true

        geminiService.sendMessage(
            history: messages,
            userPrompt: text,
            categories: taskManager.categories
        ) { result in
            isThinking = false
            switch result {
            case .success(let data):
                let aiMsg = AIChatMessage(
                    isUser: false,
                    text: data.reply.isEmpty ? "Вот составленное расписание:" : data.reply,
                    proposedTasks: data.tasks
                )
                messages.append(aiMsg)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

            case .failure(let err):
                // If API call fails (e.g. network/VPN issue), fallback to local parsing!
                let localTasks = GeminiService.parsePastedTextLocally(text: text)
                if !localTasks.isEmpty {
                    let aiMsg = AIChatMessage(
                        isUser: false,
                        text: "Распознал задачи из твоего текста локально:",
                        proposedTasks: localTasks
                    )
                    messages.append(aiMsg)
                } else {
                    errorMessage = "Ошибка подключения: \(err.localizedDescription). Проверь VPN или интернет."
                }
            }
        }
    }

    private func parsePastedText() {
        let text = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        pasteImportSuccess = false

        // Extract tasks directly or via GeminiService
        let (_, extracted) = GeminiService.extractTasks(from: text)
        if !extracted.isEmpty {
            parsedFromPaste = extracted
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            parsedFromPaste = GeminiService.parsePastedTextLocally(text: text)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private func importTasks(from messageIndex: Int) {
        let proposals = messages[messageIndex].proposedTasks.filter { $0.isSelected }
        guard !proposals.isEmpty else { return }

        for p in proposals {
            let subtasks = p.subtasks.map { SubTask(title: $0, isCompleted: false) }
            taskManager.addTask(
                title: p.title,
                notes: p.notes,
                dueDate: p.parsedDate,
                priority: p.taskPriority,
                hasReminder: false,
                reminderDate: nil,
                recurrence: .none,
                categoryId: p.categoryId,
                subtasks: subtasks
            )
        }

        messages[messageIndex].isImported = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func importPastedTasks() {
        let selected = parsedFromPaste.filter { $0.isSelected }
        guard !selected.isEmpty else { return }

        for p in selected {
            let subtasks = p.subtasks.map { SubTask(title: $0, isCompleted: false) }
            taskManager.addTask(
                title: p.title,
                notes: p.notes,
                dueDate: p.parsedDate,
                priority: p.taskPriority,
                hasReminder: false,
                reminderDate: nil,
                recurrence: .none,
                categoryId: p.categoryId,
                subtasks: subtasks
            )
        }

        pasteImportSuccess = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func formatProposalDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE, d MMMM"
        return formatter.string(from: date)
    }
}
