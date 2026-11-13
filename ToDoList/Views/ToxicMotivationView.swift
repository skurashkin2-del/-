import SwiftUI

public struct ToxicQuote: Identifiable {
    public let id = UUID()
    public let emoji: String
    public let title: String
    public let subtitle: String
    public let message: String
    public let brutalQuote: String
    public let advice: String
    public let imageName: String?
}

public struct ToxicMotivationView: View {
    @Environment(\.presentationMode) var presentationMode
    public var taskCount: Int
    public var onAddTask: () -> Void
    public var onDismiss: () -> Void

    @State private var currentIndex: Int = 0
    @State private var isPulsing: Bool = false

    public static let quotes: [ToxicQuote] = [
        ToxicQuote(
            emoji: "💀",
            title: "С ТАКИМИ ТЕМПАМИ ТЫ НИЧЕГО НЕ ДОБЬЁШЬСЯ",
            subtitle: "«Ещё чуть-чуть и я точно что-то сделаю...»",
            message: "Ты зашёл в планер ради одной задачки? Бюджетные места в топовых вузах прямо сейчас забирают те, кто ботал без перерыва. А ты запланировал полторы калеки-задачи и думаешь, что день удался? Быстро добавляй дела!",
            brutalQuote: "«Мама, я не поступил, потому что мне было лень поставить 3 задачи в планер»",
            advice: "Быстро накинь минимум 3 задачи: теорию, практику и тест!",
            imageName: "meme_sun"
        ),
        ToxicQuote(
            emoji: "🐹",
            title: "ГРАФИК МИЛЛИОНЕРА НА ПЕНСИИ?",
            subtitle: "LET'S GET THIS DEGREE...",
            message: "Посмотри на свой список задач. Тебе самому не стыдно? Твой хомяк уже в шоке. Конкуренты прорешали вариант ЕГЭ и выучили блок терминов, пока ты лежишь в направлении диплома.",
            brutalQuote: "«Зато я сохранил ментальное здоровье» — скажут те, кто пойдёт учиться платно за миллион в год.",
            advice: "Хватит жалеть себя. Нагрузи мозг реальными делами!",
            imageName: "meme_hamster"
        ),
        ToxicQuote(
            emoji: "😭",
            title: "ПЛАН НА ДЕНЬ: ДЕГРАДАЦИЯ",
            subtitle: "STU(DYING) ВО ВСЕЙ КРАСЕ",
            message: "Экзаменаторам на ЕГЭ будет глубоко плевать на твои слёзы и «не было настроения». Напомнить средний проходной балл на бюджет? Добавляй русский, математику или обществознание прямо сейчас!",
            brutalQuote: "Дворники тоже нужны стране. Но ты вроде целился намного выше?",
            advice: "Поставь минимум 3 полноценных дела на сегодня.",
            imageName: "meme_studying"
        ),
        ToxicQuote(
            emoji: "⏰",
            title: "04:31 — НАДЕЕШЬСЯ НА ЧУДО?",
            subtitle: "«УСПЕЮ» В ПОСЛЕДНЮЮ НОЧЬ?",
            message: "Если планировать по одной задаче в день, ты тоже будешь сидеть в 04:31 утра в слезах перед экзаменом с мыслью «УСПЕЮ». Спойлер: не успеешь. Распредели нагрузку прямо сейчас!",
            brutalQuote: "Каждая недописанная задача сегодня — это бессонная ночь и паника перед экзаменом.",
            advice: "Добавь задачи заранее, не доводи до ночного ада.",
            imageName: "meme_0431"
        ),
        ToxicQuote(
            emoji: "🍺",
            title: "САМООБМАН ГОДА",
            subtitle: "«НЕ СЕЙЧАС, Я ПЫТАЮСЬ УЧИТЬСЯ»",
            message: "Ты думаешь, что если зашёл в приложение и поставил одну галочку, ты заслужил отдых? Это иллюзия продуктивности. Нужно реально пахать, а не делать вид для галочки!",
            brutalQuote: "«Я начну нормально готовиться с понедельника» — главная ложь человечества.",
            advice: "Сначала закрой минимум 3 задачи, потом будешь чиллить!",
            imageName: "meme_beer"
        ),
        ToxicQuote(
            emoji: "📖",
            title: "ПОЩЁЧИНА РЕАЛЬНОСТИ",
            subtitle: "IT'S NOT HARD, IT'S JUST NEW",
            message: "Тебе кажется, что программа сложная? Нет, тебе просто лень сесть и разобраться. Каждый пустой день отдаляет тебя от профессии мечты. Встань и начни ботать!",
            brutalQuote: "Удача улыбается подготовленным, а лентяев она безжалостно топит.",
            advice: "Подними планку: минимум 3 задачи каждый день!",
            imageName: "meme_not_hard"
        ),
        ToxicQuote(
            emoji: "🌲",
            title: "ПОСТОВ НЕ БУДЕТ",
            subtitle: "Всё-таки пришлось начать учиться",
            message: "Отложи соцсети, закрой рилсы и тиктоки. Твоя лента подождёт, а дедлайн экзаменов — нет. Заполни планер 3 нормальными задачами и иди ботать!",
            brutalQuote: "«Я просто перегорел» — оправдание номер один в списке провалившихся.",
            advice: "Выйди из соцсетей и наполни планер задачами!",
            imageName: "meme_forest"
        )
    ]

    public init(taskCount: Int, onAddTask: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.taskCount = taskCount
        self.onAddTask = onAddTask
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: Int.random(in: 0..<Self.quotes.count))
    }

    private var currentQuote: ToxicQuote {
        Self.quotes[currentIndex % Self.quotes.count]
    }

    public var body: some View {
        ZStack {
            // Dark aggressive backdrop
            LinearGradient(
                colors: [Color.black, Color(red: 0.12, green: 0.02, blue: 0.02), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header tag
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("ТОКСИЧНАЯ МОТИВАЦИЯ")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                            .tracking(1.5)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.yellow.opacity(0.4), lineWidth: 1))
                    .padding(.top, 20)

                    // Savage Title
                    VStack(spacing: 4) {
                        Text(currentQuote.title)
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        Text(currentQuote.subtitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                    }

                    // Meme Image (if available)
                    if let imgName = currentQuote.imageName {
                        Image(imgName)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 24)
                    } else {
                        Text(currentQuote.emoji)
                            .font(.system(size: 64))
                            .scaleEffect(isPulsing ? 1.08 : 0.96)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                    }

                    // Progress Tracker Card (x / 3 tasks)
                    VStack(spacing: 8) {
                        HStack {
                            Text("Задач на сегодня:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(taskCount) из 3 (КРИТИЧНО МАЛО)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.red)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 10)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(12, geo.size.width * CGFloat(min(taskCount, 3)) / 3.0), height: 10)
                            }
                        }
                        .frame(height: 10)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Savage Message Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text(currentQuote.message)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(3)

                        // Brutal Quote inside
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentQuote.brutalQuote)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.red.opacity(0.95))
                                .italic()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)

                        // Advice
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            Text(currentQuote.advice)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.yellow.opacity(0.9))
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.16, green: 0.05, blue: 0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                    )
                    .padding(.horizontal, 20)

                    // Action Buttons
                    VStack(spacing: 12) {
                        // Main Action: Add task
                        Button(action: {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.warning)
                            presentationMode.wrappedValue.dismiss()
                            onAddTask()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 17, weight: .bold))
                                Text("🔥 Исправиться! Добавить задачу")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.red, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                        }

                        // Switch to another savage roast / meme
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                currentIndex = (currentIndex + 1) % Self.quotes.count
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .bold))
                                Text("💀 Другой мем / пинок (\(currentIndex + 1)/\(Self.quotes.count))")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        // Dismiss
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                            onDismiss()
                        }) {
                            Text("Позор мне (закрыть)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.45))
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            isPulsing = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}
