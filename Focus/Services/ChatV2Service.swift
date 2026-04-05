import Foundation

// MARK: - Chat V2 API Types (Backend-powered Backboard)

/// Request body for POST /chat/v2/message
struct ChatV2MessageRequest: Codable {
    let content: String
    let source: String?
    let deviceContext: ChatV2DeviceContext?

    enum CodingKeys: String, CodingKey {
        case content, source
        case deviceContext = "device_context"
    }
}

/// Device-only state sent to backend so tools can access it
struct ChatV2DeviceContext: Codable {
    let appsBlocked: Bool
    let appBlockingAvailable: Bool
    let morningBlockEnabled: Bool
    let morningBlockStart: String
    let morningBlockEnd: String

    enum CodingKeys: String, CodingKey {
        case appsBlocked = "apps_blocked"
        case appBlockingAvailable = "app_blocking_available"
        case morningBlockEnabled = "morning_block_enabled"
        case morningBlockStart = "morning_block_start"
        case morningBlockEnd = "morning_block_end"
    }
}

/// Response from POST /chat/v2/message
struct ChatV2MessageResponse: Codable {
    let reply: String
    let messageId: String?
    let sideEffects: [ChatV2SideEffect]?

    enum CodingKeys: String, CodingKey {
        case reply
        case messageId = "message_id"
        case sideEffects = "side_effects"
    }
}

/// A side effect from the backend (JSON: {"type": "...", "data": {...}})
struct ChatV2SideEffect: Codable {
    let type: String
    let data: [String: AnyCodableJSON]?
}

/// Response from GET /chat/v2/history
struct ChatV2HistoryResponse: Codable {
    let messages: [ChatV2HistoryMessage]
}

struct ChatV2HistoryMessage: Codable {
    let messageId: String?
    let role: String
    let content: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case role, content
        case createdAt = "created_at"
    }
}

// MARK: - Side Effect Conversion

extension ChatV2SideEffect {
    /// Convert backend JSON side effect to the existing BackboardSideEffect enum
    func toBackboardSideEffect() -> BackboardSideEffect? {
        switch type {
        case "refresh_tasks":
            return .refreshTasks
        case "refresh_rituals":
            return .refreshRituals
        case "refresh_reflection":
            return .refreshReflection
        case "refresh_weekly_goals":
            return .refreshWeeklyGoals
        case "calendar_needs_refresh":
            return .calendarNeedsRefresh
        case "refresh_settings":
            return .refreshSettings
        case "refresh_calendar_events":
            return .refreshCalendarEvents
        case "show_card":
            let cardType = data?["card_type"]?.stringValue ?? "tasks"
            return .showCard(cardType)
        case "show_video":
            let url = data?["url"]?.stringValue ?? ""
            let title = data?["title"]?.stringValue ?? ""
            return .showVideo(url: url, title: title)
        case "show_video_suggestions":
            let category = data?["category"]?.stringValue ?? "meditation"
            return .showVideoSuggestions(category: category)
        case "block_apps":
            let duration = data?["duration_minutes"]?.intValue
            return .blockApps(duration)
        case "unblock_apps":
            return .unblockApps
        case "show_force_unblock_card":
            return .showForceUnblockCard
        case "start_focus_session":
            let duration = data?["duration_minutes"]?.intValue
            let taskId = data?["task_id"]?.stringValue
            let taskTitle = data?["task_title"]?.stringValue
            return .startFocusSession(duration: duration, taskId: taskId, taskTitle: taskTitle)
        case "queried_future_date":
            let date = data?["date"]?.stringValue ?? ""
            return .queriedFutureDate(date)
        case "set_morning_block":
            return .refreshSettings
        case "save_favorite_video":
            // Save locally
            if let url = data?["url"]?.stringValue {
                UserDefaults.standard.set(url, forKey: "favorite_video_url")
                if let title = data?["title"]?.stringValue {
                    UserDefaults.standard.set(title, forKey: "favorite_video_title")
                }
            }
            return nil
        default:
            return nil
        }
    }
}

extension Array where Element == ChatV2SideEffect {
    /// Convert all backend side effects to BackboardSideEffect enums
    func toBackboardSideEffects() -> [BackboardSideEffect] {
        compactMap { $0.toBackboardSideEffect() }
    }
}

// MARK: - Flexible JSON Value (for side effect data)

enum AnyCodableJSON: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        if case .double(let v) = self { return Int(v) }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Chat V2 Service

@MainActor
class ChatV2Service {
    static let shared = ChatV2Service()
    private let apiClient = APIClient.shared

    /// Send a message through the backend (which handles Backboard + tools server-side)
    func sendMessage(_ text: String) async throws -> (content: String, sideEffects: [BackboardSideEffect]) {
        let deviceCtx = ChatV2DeviceContext(
            appsBlocked: ScreenTimeAppBlockerService.shared.isBlocking,
            appBlockingAvailable: ScreenTimeAppBlockerService.shared.isBlockingEnabled,
            morningBlockEnabled: MorningBlockService.shared.isEnabled,
            morningBlockStart: "\(MorningBlockService.shared.startHour):\(String(format: "%02d", MorningBlockService.shared.startMinute))",
            morningBlockEnd: "\(MorningBlockService.shared.endHour):\(String(format: "%02d", MorningBlockService.shared.endMinute))"
        )

        let request = ChatV2MessageRequest(
            content: text,
            source: "app",
            deviceContext: deviceCtx
        )

        let response: ChatV2MessageResponse = try await apiClient.request(
            endpoint: .chatV2Message,
            method: .post,
            body: request
        )

        let sideEffects = response.sideEffects?.toBackboardSideEffects() ?? []
        return (response.reply, sideEffects)
    }

    /// Fetch message history from the backend (which reads from Backboard thread)
    func fetchHistory() async throws -> [ChatV2HistoryMessage] {
        let response: ChatV2HistoryResponse = try await apiClient.request(
            endpoint: .chatV2History,
            method: .get
        )
        return response.messages
    }

    /// Delete conversation history (backend deletes Backboard thread)
    func clearHistory() async throws {
        try await apiClient.request(
            endpoint: .chatV2Delete,
            method: .delete
        )
    }
}
