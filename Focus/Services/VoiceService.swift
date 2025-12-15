import Foundation

@MainActor
class VoiceService {
    private let apiClient = APIClient.shared

    // MARK: - Process Voice Input
    func processVoice(text: String, date: String? = nil) async throws -> VoiceProcessResponse {
        let request = ProcessVoiceRequest(text: text, date: date)
        return try await apiClient.request(
            endpoint: .voiceProcess,
            method: .post,
            body: request
        )
    }

    // MARK: - Voice Assistant (with TTS audio response)
    func voiceAssistant(text: String, date: String? = nil, voiceId: String = "b35yykvVppLXyw_l", audioFormat: String = "wav") async throws -> VoiceAssistantResponse {
        let request = VoiceAssistantRequest(text: text, date: date, voiceId: voiceId, audioFormat: audioFormat)
        return try await apiClient.request(
            endpoint: .voiceAssistant,
            method: .post,
            body: request
        )
    }

    // MARK: - Analyze Voice (STT -> AI -> Proposals, NO DB write)
    // Used for Start My Day flow: user validates before creating tasks
    func analyzeVoice(text: String, date: String? = nil) async throws -> AnalyzeVoiceResponse {
        let request = AnalyzeVoiceRequest(text: text, date: date)
        return try await apiClient.request(
            endpoint: .voiceAnalyze,
            method: .post,
            body: request
        )
    }
}

// MARK: - Request Types
struct ProcessVoiceRequest: Codable {
    let text: String
    let date: String?
}

struct VoiceAssistantRequest: Codable {
    let text: String
    let date: String?
    let voiceId: String?
    let audioFormat: String?
}

// MARK: - Response Types
struct VoiceProcessResponse: Codable {
    let intentLog: IntentLog
    let tasks: [CalendarTask]?
    let message: String
    let ttsResponse: String

    var intentType: String {
        intentLog.intentType
    }

    // Legacy field mapping
    private enum CodingKeys: String, CodingKey {
        case intentLog, tasks, message, ttsResponse
        case goals // Legacy field
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intentLog = try container.decode(IntentLog.self, forKey: .intentLog)
        message = try container.decode(String.self, forKey: .message)
        ttsResponse = try container.decode(String.self, forKey: .ttsResponse)
        // Try tasks first, then fall back to goals (legacy)
        if let tasksArray = try? container.decode([CalendarTask].self, forKey: .tasks) {
            tasks = tasksArray
        } else {
            tasks = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(intentLog, forKey: .intentLog)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(message, forKey: .message)
        try container.encode(ttsResponse, forKey: .ttsResponse)
    }
}

struct VoiceAssistantResponse: Codable {
    let intentLog: IntentLog
    let tasks: [CalendarTask]?
    let goals: [VoiceDailyGoal]?
    let replyText: String
    let audioFormat: String
    let audioBase64: String?

    var intentType: String {
        intentLog.intentType
    }

    // Decode base64 audio to Data for playback
    var audioData: Data? {
        guard let base64 = audioBase64 else { return nil }
        return Data(base64Encoded: base64)
    }
}

// MARK: - Voice Daily Goal (from backend)
struct VoiceDailyGoal: Codable, Identifiable {
    let id: String
    let title: String
    let date: String
    let priority: String
    let timeBlock: String
    let scheduledStart: String?
    let scheduledEnd: String?
    let status: String
    let isAiScheduled: Bool?
}

struct IntentLog: Codable, Identifiable {
    let id: String
    let userId: String
    let rawUserText: String
    let intentType: String
    let notes: String?
    let followUpQuestion: String?
    let processedAt: Date?
    let createdAt: Date
}

// MARK: - Analyze Voice Request/Response (STT -> AI -> Proposals)
struct AnalyzeVoiceRequest: Codable {
    let text: String
    let date: String?
}

struct AnalyzeVoiceResponse: Codable {
    let success: Bool
    let intentType: String
    let proposedGoals: [ProposedGoal]
    let summary: String
    let rawUserText: String
}

// ProposedGoal represents an AI-suggested goal (not yet saved to DB)
struct ProposedGoal: Codable, Identifiable {
    var id: String { title + (scheduledStart ?? "") } // Computed ID
    let title: String
    let date: String
    let priority: String
    let timeBlock: String
    let scheduledStart: String?
    let scheduledEnd: String?
    let estimatedMinutes: Int?
    let status: String
    let questId: String?

    enum CodingKeys: String, CodingKey {
        case title, date, priority, timeBlock, scheduledStart, scheduledEnd
        case estimatedMinutes = "estimated_minutes"
        case status, questId = "quest_id"
    }
}
