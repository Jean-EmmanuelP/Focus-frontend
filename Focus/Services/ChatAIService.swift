import Foundation

/// Service for AI-powered chat interactions
@MainActor
class ChatAIService {
    static let shared = ChatAIService()
    private let apiClient = APIClient.shared

    private init() {}

    // MARK: - Send Message to Coach

    /// Send a message to the AI coach and get a response
    func sendMessage(
        _ message: String,
        context: ChatContext,
        conversationHistory: [ChatMessage]
    ) async throws -> ChatAIResponse {
        let request = ChatMessageRequest(
            message: message,
            context: context,
            history: conversationHistory.suffix(20).map { msg in
                ChatHistoryMessage(
                    role: msg.isFromUser ? "user" : "assistant",
                    content: msg.content
                )
            },
            persona: CoachPersona.systemPrompt
        )

        return try await apiClient.request(
            endpoint: .chatMessage,
            method: .post,
            body: request
        )
    }

    // MARK: - Get Chat History

    /// Fetch chat history from server (for sync)
    func getChatHistory(limit: Int = 50) async throws -> [ChatMessage] {
        let response: ChatHistoryResponse = try await apiClient.request(
            endpoint: .chatHistory,
            method: .get
        )
        return response.messages.map { msg in
            ChatMessage(
                id: UUID(uuidString: msg.id) ?? UUID(),
                type: MessageType(rawValue: msg.type) ?? .text,
                content: msg.content,
                isFromUser: msg.role == "user",
                timestamp: ISO8601DateFormatter().date(from: msg.timestamp) ?? Date(),
                toolAction: msg.toolAction.flatMap { ChatTool(rawValue: $0) }
            )
        }
    }

    // MARK: - Generate Context-Aware Greeting

    /// Generate a greeting based on current user context
    func generateGreeting(context: ChatContext) -> String {
        let userName = context.userName.isEmpty ? "" : context.userName.components(separatedBy: " ").first ?? ""
        return CoachPersona.greetingForTimeOfDay(context.timeOfDay, streak: context.currentStreak, userName: userName)
    }

    // MARK: - Detect Tool Intent

    /// Analyze message to detect if user wants to use a specific tool
    func detectToolIntent(from message: String) -> ChatTool? {
        let lowercased = message.lowercased()

        // Plan day detection
        if lowercased.contains("planifier") || lowercased.contains("plan") ||
           lowercased.contains("journée") || lowercased.contains("aujourd'hui") ||
           lowercased.contains("tâches") || lowercased.contains("faire aujourd") {
            return .planDay
        }

        // Weekly goals detection
        if lowercased.contains("objectif") || lowercased.contains("semaine") ||
           lowercased.contains("goals") || lowercased.contains("but") {
            return .weeklyGoals
        }

        // Focus session detection
        if lowercased.contains("focus") || lowercased.contains("session") ||
           lowercased.contains("concentrer") || lowercased.contains("travailler") ||
           lowercased.contains("pomodoro") || lowercased.contains("timer") {
            return .startFocus
        }

        // Stats detection
        if lowercased.contains("stat") || lowercased.contains("progress") ||
           lowercased.contains("combien") || lowercased.contains("résultat") {
            return .viewStats
        }

        // Reflection detection
        if lowercased.contains("réflexion") || lowercased.contains("journal") ||
           lowercased.contains("ressens") || lowercased.contains("bilan") {
            return .dailyReflection
        }

        // Mood detection
        if lowercased.contains("humeur") || lowercased.contains("mood") ||
           lowercased.contains("je me sens") || lowercased.contains("ça va") {
            return .logMood
        }

        return nil
    }
}

// MARK: - Request/Response Models

struct ChatMessageRequest: Codable {
    let message: String
    let context: ChatContext
    let history: [ChatHistoryMessage]
    let persona: String
}

struct ChatHistoryMessage: Codable {
    let role: String // "user" or "assistant"
    let content: String
}

struct ChatAIResponse: Codable {
    let reply: String
    let suggestedTool: String?
    let toolData: [String: AnyCodable]?

    var tool: ChatTool? {
        suggestedTool.flatMap { ChatTool(rawValue: $0) }
    }
}

struct ChatHistoryResponse: Codable {
    let messages: [ServerChatMessage]
}

struct ServerChatMessage: Codable {
    let id: String
    let role: String
    let content: String
    let type: String
    let toolAction: String?
    let timestamp: String
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
