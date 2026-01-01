import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let type: MessageType
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let toolAction: ChatTool?
    let voiceURL: URL?
    let voiceTranscript: String?

    init(
        id: UUID = UUID(),
        type: MessageType = .text,
        content: String,
        isFromUser: Bool,
        timestamp: Date = Date(),
        toolAction: ChatTool? = nil,
        voiceURL: URL? = nil,
        voiceTranscript: String? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.toolAction = toolAction
        self.voiceURL = voiceURL
        self.voiceTranscript = voiceTranscript
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Message Type

enum MessageType: String, Codable {
    case text
    case voice
    case toolCard
    case dailyStats
    case weeklyBilan
    case taskList
    case ritualList
}

// MARK: - Chat Tool

enum ChatTool: String, Codable, CaseIterable {
    case planDay = "plan_day"
    case weeklyGoals = "weekly_goals"
    case dailyReflection = "daily_reflection"
    case startFocus = "start_focus"
    case viewStats = "view_stats"
    case logMood = "log_mood"

    var displayName: String {
        switch self {
        case .planDay: return "Planifier ma journée"
        case .weeklyGoals: return "Objectifs de la semaine"
        case .dailyReflection: return "Réflexion du jour"
        case .startFocus: return "Lancer une session Focus"
        case .viewStats: return "Voir mes stats"
        case .logMood: return "Comment je me sens"
        }
    }

    var icon: String {
        switch self {
        case .planDay: return "calendar.badge.plus"
        case .weeklyGoals: return "target"
        case .dailyReflection: return "text.book.closed"
        case .startFocus: return "flame"
        case .viewStats: return "chart.bar"
        case .logMood: return "heart"
        }
    }

    var description: String {
        switch self {
        case .planDay: return "Organise tes priorités du jour"
        case .weeklyGoals: return "Définis ce que tu veux accomplir"
        case .dailyReflection: return "Prends du recul sur ta journée"
        case .startFocus: return "Lance une session de concentration"
        case .viewStats: return "Regarde ta progression"
        case .logMood: return "Enregistre ton état d'esprit"
        }
    }
}

// MARK: - Chat Context (sent to AI)

struct ChatContext: Codable {
    let userName: String
    let currentStreak: Int
    let todayTasksCount: Int
    let todayTasksCompleted: Int
    let todayRitualsCount: Int
    let todayRitualsCompleted: Int
    let weeklyGoalsCount: Int
    let weeklyGoalsCompleted: Int
    let focusMinutesToday: Int
    let focusMinutesWeek: Int
    let timeOfDay: TimeOfDay
    let lastReflection: String?
    let currentMood: Int?
    let dayOfWeek: String

    enum TimeOfDay: String, Codable {
        case morning    // 5h - 12h
        case afternoon  // 12h - 18h
        case evening    // 18h - 22h
        case night      // 22h - 5h

        static func current() -> TimeOfDay {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12: return .morning
            case 12..<18: return .afternoon
            case 18..<22: return .evening
            default: return .night
            }
        }
    }
}

// MARK: - Coach Persona

struct CoachPersona {
    static let name = "Kai"
    static let avatarIcon = "person.crop.circle.fill"

    static let systemPrompt = """
    Tu es Kai, un ami et compagnon de vie bienveillant qui accompagne l'utilisateur dans sa croissance personnelle.

    QUI TU ES:
    - Un ami sincère, pas juste un coach
    - Tu es là pour le soutenir émotionnellement ET l'aider à avancer
    - Tu comprends que la vie n'est pas que productivité
    - Tu célèbres les petites victoires comme les grandes
    - Tu es présent dans les moments difficiles sans juger

    TON STYLE:
    - Chaleureux et authentique
    - Direct mais jamais froid
    - Tu tutoies toujours
    - Tu poses des questions pour comprendre
    - 2-4 phrases max, naturelles et humaines

    CE QUE TU PEUX FAIRE:
    - Écouter et répondre à tout sujet (vie, émotions, doutes, rêves...)
    - Encourager sans être condescendant
    - Aider à planifier quand demandé
    - Proposer des actions adaptées au contexte

    IMPORTANT:
    - Ne sois JAMAIS robotique ou générique
    - Adapte ton ton à l'émotion de l'utilisateur
    - Si quelqu'un va mal, priorise l'écoute avant l'action
    - Tu es un vrai ami, pas une app de productivité

    CONTEXTE ACTUEL:
    """

    static func greetingForTimeOfDay(_ timeOfDay: ChatContext.TimeOfDay, streak: Int, userName: String) -> String {
        let name = userName.isEmpty ? "" : " \(userName)"

        switch timeOfDay {
        case .morning:
            if streak > 7 {
                return "Hey\(name) ! 🌅 \(streak) jours de streak, c'est impressionnant. Comment tu te sens ce matin ?"
            } else {
                return "Salut\(name) ! Nouvelle journée qui commence. Comment tu vas ?"
            }
        case .afternoon:
            return "Hey\(name) ! Comment se passe ta journée ?"
        case .evening:
            return "Bonsoir\(name). La journée touche à sa fin. Comment tu te sens ?"
        case .night:
            return "Hey\(name), il est tard. Tout va bien ?"
        }
    }
}

// MARK: - Chat Persistence

struct ChatPersistence {
    private static let messagesKey = "chat_messages_v1"
    private static let maxStoredMessages = 100

    static func saveMessages(_ messages: [ChatMessage]) {
        let messagesToSave = Array(messages.suffix(maxStoredMessages))
        if let encoded = try? JSONEncoder().encode(messagesToSave) {
            UserDefaults.standard.set(encoded, forKey: messagesKey)
        }
    }

    static func loadMessages() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: messagesKey),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return []
        }
        return messages
    }

    static func clearMessages() {
        UserDefaults.standard.removeObject(forKey: messagesKey)
    }
}
