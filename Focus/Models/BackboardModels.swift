import Foundation

// MARK: - Backboard API Response Models

/// Response from POST /threads/{id}/messages and POST submit-tool-outputs
struct BackboardMessageResponse: Decodable {
    let message: String
    let threadId: String
    let content: String?
    let messageId: String?
    let role: String?
    let status: String? // "COMPLETED", "REQUIRES_ACTION", "IN_PROGRESS", "FAILED", "CANCELLED"
    let toolCalls: [BackboardToolCall]?
    let runId: String?
    let memoryOperationId: String?
    let retrievedMemories: [BackboardRetrievedMemory]?
}

/// A tool call requested by the assistant
struct BackboardToolCall: Decodable {
    let id: String
    let type: String?
    let function: BackboardFunction

    struct BackboardFunction: Decodable {
        let name: String
        let arguments: String // JSON string of arguments
    }
}

/// A tool output to submit back to Backboard
struct BackboardToolOutput: Encodable {
    let toolCallId: String
    let output: String

    enum CodingKeys: String, CodingKey {
        case toolCallId = "tool_call_id"
        case output
    }
}

/// Request body for submit-tool-outputs
struct BackboardSubmitToolOutputsRequest: Encodable {
    let toolOutputs: [BackboardToolOutput]

    enum CodingKeys: String, CodingKey {
        case toolOutputs = "tool_outputs"
    }
}

/// Thread created by Backboard
struct BackboardThread: Decodable {
    let threadId: String
    let createdAt: String
}

/// Memory item from Backboard
struct BackboardMemory: Decodable, Identifiable {
    let id: String
    let content: String
    let metadata: [String: AnyCodableValue]?
    let score: Double?
    let createdAt: String?
    let updatedAt: String?
}

/// Response for list memories
struct BackboardMemoriesListResponse: Decodable {
    let memories: [BackboardMemory]
    let totalCount: Int
}

/// Retrieved memory in a message response
struct BackboardRetrievedMemory: Decodable {
    let id: String?
    let memory: String
    let score: Double?
}

/// Request to create a memory
struct BackboardMemoryCreate: Encodable {
    let content: String
    let metadata: [String: String]?
}

// MARK: - Side Effect from Tool Execution

/// Represents a side effect that should be applied after tool execution
enum BackboardSideEffect {
    case refreshTasks
    case refreshRituals
    case refreshReflection
    case refreshWeeklyGoals
    case calendarNeedsRefresh
    case showCard(String) // "tasks", "routines", "planning"
    case showVideo(url: String, title: String)
    case showVideoSuggestions(category: String)
    case blockApps(Int?) // duration in minutes
    case unblockApps
    case startFocusSession(duration: Int?, taskId: String?, taskTitle: String?)
    case refreshSettings
    case refreshCalendarEvents
}

// MARK: - AnyCodableValue (for memory metadata)

struct AnyCodableValue: Codable {
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
        } else if let array = try? container.decode([AnyCodableValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodableValue($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodableValue($0) })
        default: try container.encodeNil()
        }
    }
}
