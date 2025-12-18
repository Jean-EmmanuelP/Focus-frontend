import Foundation

// MARK: - API Logger
final class APILogger {
    static let shared = APILogger()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private var requestCounter: Int = 0

    private init() {}

    // MARK: - Log Request
    func logRequest(
        id: Int,
        method: String,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) {
        let timestamp = dateFormatter.string(from: Date())

        var log = """

        ╔══════════════════════════════════════════════════════════════════════════════
        ║ 📤 REQUEST #\(id) @ \(timestamp)
        ╠══════════════════════════════════════════════════════════════════════════════
        ║ \(method) \(url.absoluteString)
        """

        // Log headers (excluding sensitive data)
        if let headers = headers, !headers.isEmpty {
            log += "\n╠──────────────────────────────────────────────────────────────────────────────"
            log += "\n║ Headers:"
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                if key.lowercased() == "authorization" {
                    log += "\n║   \(key): Bearer ***[REDACTED]***"
                } else {
                    log += "\n║   \(key): \(value)"
                }
            }
        }

        // Log body
        if let body = body, !body.isEmpty {
            log += "\n╠──────────────────────────────────────────────────────────────────────────────"
            log += "\n║ Body:"
            if let jsonString = prettyPrintJSON(body) {
                for line in jsonString.components(separatedBy: "\n") {
                    log += "\n║   \(line)"
                }
            } else if let string = String(data: body, encoding: .utf8) {
                log += "\n║   \(string)"
            }
        }

        log += "\n╚══════════════════════════════════════════════════════════════════════════════"

        print(log)
    }

    // MARK: - Log Response
    func logResponse(
        id: Int,
        method: String,
        url: URL,
        statusCode: Int,
        duration: TimeInterval,
        headers: [AnyHashable: Any]?,
        body: Data?
    ) {
        let timestamp = dateFormatter.string(from: Date())
        let statusEmoji = statusEmoji(for: statusCode)
        let durationMs = String(format: "%.0f", duration * 1000)

        var log = """

        ╔══════════════════════════════════════════════════════════════════════════════
        ║ \(statusEmoji) RESPONSE #\(id) @ \(timestamp) [\(durationMs)ms]
        ╠══════════════════════════════════════════════════════════════════════════════
        ║ \(method) \(url.absoluteString)
        ║ Status: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode).uppercased())
        """

        // Log response body
        if let body = body, !body.isEmpty {
            log += "\n╠──────────────────────────────────────────────────────────────────────────────"
            log += "\n║ Body (\(body.count) bytes):"
            if let jsonString = prettyPrintJSON(body) {
                let lines = jsonString.components(separatedBy: "\n")
                let maxLines = 50
                for line in lines.prefix(maxLines) {
                    log += "\n║   \(line)"
                }
                if lines.count > maxLines {
                    log += "\n║   ... (\(lines.count - maxLines) more lines)"
                }
            } else if let string = String(data: body, encoding: .utf8) {
                let truncated = String(string.prefix(1000))
                log += "\n║   \(truncated)"
                if string.count > 1000 {
                    log += "\n║   ... (truncated, \(string.count) total chars)"
                }
            }
        }

        log += "\n╚══════════════════════════════════════════════════════════════════════════════"

        print(log)
    }

    // MARK: - Log Error
    func logError(
        id: Int,
        method: String,
        url: URL,
        error: Error,
        duration: TimeInterval,
        responseBody: Data? = nil
    ) {
        let timestamp = dateFormatter.string(from: Date())
        let durationMs = String(format: "%.0f", duration * 1000)

        var log = """

        ╔══════════════════════════════════════════════════════════════════════════════
        ║ ❌ ERROR #\(id) @ \(timestamp) [\(durationMs)ms]
        ╠══════════════════════════════════════════════════════════════════════════════
        ║ \(method) \(url.absoluteString)
        ╠──────────────────────────────────────────────────────────────────────────────
        ║ Error Type: \(type(of: error))
        ║ Description: \(error.localizedDescription)
        """

        // Add detailed error info for APIError
        if let apiError = error as? APIError {
            log += "\n║ API Error: \(apiError.errorDescription ?? "Unknown")"
        }

        // Log response body if available (useful for server errors)
        if let body = responseBody, !body.isEmpty {
            log += "\n╠──────────────────────────────────────────────────────────────────────────────"
            log += "\n║ Response Body:"
            if let jsonString = prettyPrintJSON(body) {
                for line in jsonString.components(separatedBy: "\n") {
                    log += "\n║   \(line)"
                }
            } else if let string = String(data: body, encoding: .utf8) {
                log += "\n║   \(string)"
            }
        }

        log += "\n╚══════════════════════════════════════════════════════════════════════════════"

        print(log)
    }

    // MARK: - Helpers
    func nextRequestId() -> Int {
        requestCounter += 1
        return requestCounter
    }

    private func statusEmoji(for statusCode: Int) -> String {
        switch statusCode {
        case 200..<300: return "✅"
        case 300..<400: return "↪️"
        case 400..<500: return "⚠️"
        case 500..<600: return "🔥"
        default: return "❓"
        }
    }

    private func prettyPrintJSON(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString
    }
}

// MARK: - API Configuration
enum APIConfiguration {
    // Load from Config.plist
    private static var config: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return [:]
        }
        return dict
    }()

    static var baseURL: String {
        (config["API_BASE_URL"] as? String) ?? "https://firelevel-api.onrender.com"
    }

    static let timeout: TimeInterval = 30

    enum Endpoint {
        // Health
        case health

        // User
        case me
        case uploadAvatar
        case deleteAvatar

        // Areas
        case areas
        case createArea
        case updateArea(String)
        case deleteArea(String)

        // Quests
        case quests(areaId: String?)
        case createQuest
        case updateQuest(String)
        case deleteQuest(String)

        // Routines (formerly rituals)
        case routines(areaId: String?)
        case createRoutine
        case updateRoutine(String)
        case deleteRoutine(String)
        case completeRoutine(String)
        case uncompleteRoutine(String)
        case completeRoutinesBatch

        // Completions
        case completions(routineId: String?, from: String?, to: String?)

        // Focus Sessions
        case focusSessions(questId: String?, status: String?, limit: Int?)
        case createFocusSession
        case updateFocusSession(String)
        case deleteFocusSession(String)

        // Reflections (evening review)
        case reflections(from: String?, to: String?, limit: Int?)
        case reflection(date: String)
        case upsertReflection(date: String)

        // Intentions (morning check-in / start the day)
        case intentionsToday(date: String)
        case intentions(date: String)
        case intentionsList(limit: Int?)
        case upsertIntentions(date: String)

        // Dashboard & Stats
        case dashboard(date: String)
        case firemode
        case questsTab
        case statsFocus
        case statsRoutines

        // Streak
        case streak(date: String)
        case streakDay(date: String)
        case streakRecalculate(date: String)

        // Friends
        case friends
        case removeFriend(String)
        case friendDay(userId: String, date: String)
        case friendsLeaderboard(limit: Int?)

        // Friend Requests
        case friendRequestsReceived
        case friendRequestsSent
        case sendFriendRequest
        case acceptFriendRequest(String)
        case rejectFriendRequest(String)

        // Users Search & Suggestions
        case searchUsers(query: String, limit: Int?)
        case suggestedUsers(limit: Int?)

        // Profile
        case updateDayVisibility
        case myStats

        // Social Actions
        case likeRoutineCompletion(completionId: String)
        case unlikeRoutineCompletion(completionId: String)

        // Friend Groups
        case friendGroups
        case createFriendGroup
        case friendGroup(String)
        case updateFriendGroup(String)
        case deleteFriendGroup(String)
        case addFriendGroupMembers(String)
        case removeFriendGroupMember(groupId: String, memberId: String)
        case inviteToGroup(String)
        case leaveGroup(String)

        // Group Routines (shared routines for accountability)
        case groupRoutines(groupId: String, date: String?)
        case shareRoutineWithGroup(groupId: String)
        case removeGroupRoutine(groupId: String, groupRoutineId: String)

        // Group Invitations
        case groupInvitationsReceived
        case groupInvitationsSent
        case acceptGroupInvitation(String)
        case rejectGroupInvitation(String)
        case cancelGroupInvitation(String)

        // Onboarding
        case onboardingStatus
        case onboardingProgress
        case onboardingComplete
        case onboardingReset

        // Calendar - Day Plans
        case calendarDay(date: String)
        case createDayPlan
        case updateDayPlan(String)

        // Calendar - Tasks
        case calendarTasks(date: String?)
        case createCalendarTask
        case updateCalendarTask(String)
        case completeCalendarTask(String)
        case uncompleteCalendarTask(String)
        case deleteCalendarTask(String)
        case rescheduleTask(String)

        // Calendar - AI
        case generateDayPlan

        // Calendar - Week View
        case calendarWeek(startDate: String)

        // Voice
        case voiceProcess
        case voiceAssistant  // New endpoint with Gradium TTS
        case voiceAnalyze    // New: analyze only, return proposals (no DB write)
        case voiceIntentions

        // Google Calendar
        case googleCalendarConfig
        case googleCalendarSaveTokens
        case googleCalendarUpdateConfig
        case googleCalendarDisconnect
        case googleCalendarSync
        case googleCalendarCheckWeekly

        // Community Feed
        case communityFeed(limit: Int?, offset: Int?)
        case communityMyPosts(limit: Int?, offset: Int?)
        case createCommunityPost
        case communityPost(String)
        case deleteCommunityPost(String)
        case likeCommunityPost(String)
        case unlikeCommunityPost(String)
        case reportCommunityPost(String)
        case taskPosts(taskId: String)
        case routinePosts(routineId: String)

        // Journal - Audio/Video Progress Journal
        case journalEntries(limit: Int?, offset: Int?, dateFrom: String?, dateTo: String?)
        case journalEntryToday
        case journalEntry(String)
        case createJournalEntry
        case deleteJournalEntry(String)
        case journalStreak
        case journalStats(days: Int?)
        case journalBilans
        case generateWeeklyBilan
        case generateMonthlyBilan

        var path: String {
            switch self {
            // Health
            case .health:
                return "/health"

            // User
            case .me:
                return "/me"
            case .uploadAvatar:
                return "/me/avatar"
            case .deleteAvatar:
                return "/me/avatar"

            // Areas
            case .areas, .createArea:
                return "/areas"
            case .updateArea(let id), .deleteArea(let id):
                return "/areas/\(id)"

            // Quests
            case .quests(let areaId):
                if let areaId = areaId {
                    return "/quests?area_id=\(areaId)"
                }
                return "/quests"
            case .createQuest:
                return "/quests"
            case .updateQuest(let id), .deleteQuest(let id):
                return "/quests/\(id)"

            // Routines
            case .routines(let areaId):
                if let areaId = areaId {
                    return "/routines?area_id=\(areaId)"
                }
                return "/routines"
            case .createRoutine:
                return "/routines"
            case .updateRoutine(let id), .deleteRoutine(let id):
                return "/routines/\(id)"
            case .completeRoutine(let id):
                return "/routines/\(id)/complete"
            case .uncompleteRoutine(let id):
                return "/routines/\(id)/complete"
            case .completeRoutinesBatch:
                return "/routines/complete-batch"

            // Completions
            case .completions(let routineId, let from, let to):
                var query: [String] = []
                if let routineId = routineId { query.append("routine_id=\(routineId)") }
                if let from = from { query.append("from=\(from)") }
                if let to = to { query.append("to=\(to)") }
                let queryString = query.isEmpty ? "" : "?\(query.joined(separator: "&"))"
                return "/completions\(queryString)"

            // Focus Sessions
            case .focusSessions(let questId, let status, let limit):
                var query: [String] = []
                if let questId = questId { query.append("quest_id=\(questId)") }
                if let status = status { query.append("status=\(status)") }
                if let limit = limit { query.append("limit=\(limit)") }
                let queryString = query.isEmpty ? "" : "?\(query.joined(separator: "&"))"
                return "/focus-sessions\(queryString)"
            case .createFocusSession:
                return "/focus-sessions"
            case .updateFocusSession(let id), .deleteFocusSession(let id):
                return "/focus-sessions/\(id)"

            // Reflections (evening review)
            case .reflections(let from, let to, let limit):
                var query: [String] = []
                if let from = from { query.append("from=\(from)") }
                if let to = to { query.append("to=\(to)") }
                if let limit = limit { query.append("limit=\(limit)") }
                let queryString = query.isEmpty ? "" : "?\(query.joined(separator: "&"))"
                return "/reflections\(queryString)"
            case .reflection(let date), .upsertReflection(let date):
                return "/reflections/\(date)"

            // Intentions (morning check-in / start the day)
            case .intentionsToday(let date):
                return "/intentions/today?date=\(date)"
            case .intentions(let date), .upsertIntentions(let date):
                return "/intentions/\(date)"
            case .intentionsList(let limit):
                if let limit = limit {
                    return "/intentions?limit=\(limit)"
                }
                return "/intentions"

            // Dashboard & Stats
            case .dashboard(let date):
                return "/dashboard?date=\(date)"
            case .firemode:
                return "/firemode"
            case .questsTab:
                return "/quests-tab"
            case .statsFocus:
                return "/stats/focus"
            case .statsRoutines:
                return "/stats/routines"

            // Streak
            case .streak(let date):
                return "/streak?date=\(date)"
            case .streakDay(let date):
                return "/streak/day?date=\(date)"
            case .streakRecalculate(let date):
                return "/streak/recalculate?date=\(date)"

            // Friends
            case .friends:
                return "/friends"
            case .removeFriend(let id):
                return "/friends/\(id)"
            case .friendDay(let userId, let date):
                return "/friends/\(userId)/day?date=\(date)"
            case .friendsLeaderboard(let limit):
                if let limit = limit {
                    return "/friends/leaderboard?limit=\(limit)"
                }
                return "/friends/leaderboard"

            // Friend Requests
            case .friendRequestsReceived:
                return "/friend-requests/received"
            case .friendRequestsSent:
                return "/friend-requests/sent"
            case .sendFriendRequest:
                return "/friend-requests"
            case .acceptFriendRequest(let id):
                return "/friend-requests/\(id)/accept"
            case .rejectFriendRequest(let id):
                return "/friend-requests/\(id)/reject"

            // Users Search & Suggestions
            case .searchUsers(let query, let limit):
                var queryString = "q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
                if let limit = limit {
                    queryString += "&limit=\(limit)"
                }
                return "/users/search?\(queryString)"
            case .suggestedUsers(let limit):
                if let limit = limit {
                    return "/users/suggestions?limit=\(limit)"
                }
                return "/users/suggestions"

            // Profile
            case .updateDayVisibility:
                return "/me/visibility"
            case .myStats:
                return "/me/stats"

            // Social Actions
            case .likeRoutineCompletion(let completionId):
                return "/completions/\(completionId)/like"
            case .unlikeRoutineCompletion(let completionId):
                return "/completions/\(completionId)/like"

            // Friend Groups
            case .friendGroups, .createFriendGroup:
                return "/friend-groups"
            case .friendGroup(let id), .updateFriendGroup(let id), .deleteFriendGroup(let id):
                return "/friend-groups/\(id)"
            case .addFriendGroupMembers(let id):
                return "/friend-groups/\(id)/members"
            case .removeFriendGroupMember(let groupId, let memberId):
                return "/friend-groups/\(groupId)/members/\(memberId)"
            case .inviteToGroup(let id):
                return "/friend-groups/\(id)/invite"
            case .leaveGroup(let id):
                return "/friend-groups/\(id)/leave"

            // Group Routines
            case .groupRoutines(let groupId, let date):
                if let date = date {
                    return "/friend-groups/\(groupId)/routines?date=\(date)"
                }
                return "/friend-groups/\(groupId)/routines"
            case .shareRoutineWithGroup(let groupId):
                return "/friend-groups/\(groupId)/routines"
            case .removeGroupRoutine(let groupId, let groupRoutineId):
                return "/friend-groups/\(groupId)/routines/\(groupRoutineId)"

            // Group Invitations
            case .groupInvitationsReceived:
                return "/group-invitations/received"
            case .groupInvitationsSent:
                return "/group-invitations/sent"
            case .acceptGroupInvitation(let id):
                return "/group-invitations/\(id)/accept"
            case .rejectGroupInvitation(let id):
                return "/group-invitations/\(id)/reject"
            case .cancelGroupInvitation(let id):
                return "/group-invitations/\(id)"

            // Onboarding
            case .onboardingStatus:
                return "/onboarding/status"
            case .onboardingProgress:
                return "/onboarding/progress"
            case .onboardingComplete:
                return "/onboarding/complete"
            case .onboardingReset:
                return "/onboarding"

            // Calendar - Day Plans
            case .calendarDay(let date):
                return "/calendar/day?date=\(date)"
            case .createDayPlan:
                return "/calendar/day"
            case .updateDayPlan(let id):
                return "/calendar/day/\(id)"

            // Calendar - Tasks
            case .calendarTasks(let date):
                if let date = date {
                    return "/calendar/tasks?date=\(date)"
                }
                return "/calendar/tasks"
            case .createCalendarTask:
                return "/calendar/tasks"
            case .updateCalendarTask(let id):
                return "/calendar/tasks/\(id)"
            case .completeCalendarTask(let id):
                return "/calendar/tasks/\(id)/complete"
            case .uncompleteCalendarTask(let id):
                return "/calendar/tasks/\(id)/uncomplete"
            case .deleteCalendarTask(let id):
                return "/calendar/tasks/\(id)"
            case .rescheduleTask(let id):
                return "/calendar/tasks/\(id)/reschedule"

            // Calendar - AI
            case .generateDayPlan:
                return "/calendar/ai/generate-day"

            // Calendar - Week View
            case .calendarWeek(let startDate):
                return "/calendar/week?startDate=\(startDate)"

            // Voice
            case .voiceProcess:
                return "/voice/process"
            case .voiceAssistant:
                return "/assistant/voice"
            case .voiceAnalyze:
                return "/assistant/analyze"
            case .voiceIntentions:
                return "/voice/intentions"

            // Google Calendar
            case .googleCalendarConfig, .googleCalendarUpdateConfig, .googleCalendarDisconnect:
                return "/google-calendar/config"
            case .googleCalendarSaveTokens:
                return "/google-calendar/tokens"
            case .googleCalendarSync:
                return "/google-calendar/sync"
            case .googleCalendarCheckWeekly:
                return "/google-calendar/check-weekly"

            // Community Feed
            case .communityFeed(let limit, let offset):
                var query: [String] = []
                if let limit = limit { query.append("limit=\(limit)") }
                if let offset = offset { query.append("offset=\(offset)") }
                let queryString = query.isEmpty ? "" : "?\(query.joined(separator: "&"))"
                return "/community/feed\(queryString)"
            case .communityMyPosts(let limit, let offset):
                var query: [String] = []
                if let limit = limit { query.append("limit=\(limit)") }
                if let offset = offset { query.append("offset=\(offset)") }
                let queryString = query.isEmpty ? "" : "?\(query.joined(separator: "&"))"
                return "/community/my-posts\(queryString)"
            case .createCommunityPost:
                return "/community/posts"
            case .communityPost(let id), .deleteCommunityPost(let id):
                return "/community/posts/\(id)"
            case .likeCommunityPost(let id), .unlikeCommunityPost(let id):
                return "/community/posts/\(id)/like"
            case .reportCommunityPost(let id):
                return "/community/posts/\(id)/report"
            case .taskPosts(let taskId):
                return "/tasks/\(taskId)/posts"
            case .routinePosts(let routineId):
                return "/routines/\(routineId)/posts"

            // Journal
            case .journalEntries(let limit, let offset, let dateFrom, let dateTo):
                var query: [String] = []
                if let limit = limit { query.append("limit=\(limit)") }
                if let offset = offset { query.append("offset=\(offset)") }
                if let dateFrom = dateFrom { query.append("date_from=\(dateFrom)") }
                if let dateTo = dateTo { query.append("date_to=\(dateTo)") }
                let queryString = query.isEmpty ? "" : "?\(query.joined(separator: "&"))"
                return "/journal/entries\(queryString)"
            case .journalEntryToday:
                return "/journal/entries/today"
            case .journalEntry(let id), .deleteJournalEntry(let id):
                return "/journal/entries/\(id)"
            case .createJournalEntry:
                return "/journal/entries"
            case .journalStreak:
                return "/journal/entries/streak"
            case .journalStats(let days):
                if let days = days {
                    return "/journal/stats?days=\(days)"
                }
                return "/journal/stats"
            case .journalBilans:
                return "/journal/bilans"
            case .generateWeeklyBilan:
                return "/journal/bilans/weekly"
            case .generateMonthlyBilan:
                return "/journal/bilans/monthly"
            }
        }

        var url: URL {
            URL(string: APIConfiguration.baseURL + path)!
        }
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized
    case notFound
    case conflict

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .unauthorized:
            return "Unauthorized - Please log in again"
        case .notFound:
            return "Resource not found"
        case .conflict:
            return "Conflict - Resource already exists"
        }
    }
}

// MARK: - API Client
@MainActor
class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfiguration.timeout
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        // Custom date decoding to handle ISO8601 with and without fractional seconds
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let isoWithFractional = ISO8601DateFormatter()
            isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoWithFractional.date(from: dateString) {
                return date
            }

            // Try standard ISO8601 without fractional seconds
            let isoStandard = ISO8601DateFormatter()
            isoStandard.formatOptions = [.withInternetDateTime]
            if let date = isoStandard.date(from: dateString) {
                return date
            }

            // Fallback: try RFC3339 style with timezone offset
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(dateString)"
            )
        }
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Generic Request Method
    func request<T: Decodable>(
        endpoint: APIConfiguration.Endpoint,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil
    ) async throws -> T {
        try await performRequest(endpoint: endpoint, method: method, bodyData: nil, headers: headers)
    }

    func request<T: Decodable, B: Encodable>(
        endpoint: APIConfiguration.Endpoint,
        method: HTTPMethod = .get,
        body: B,
        headers: [String: String]? = nil
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        return try await performRequest(endpoint: endpoint, method: method, bodyData: bodyData, headers: headers)
    }

    // Request without response body
    func request(
        endpoint: APIConfiguration.Endpoint,
        method: HTTPMethod,
        headers: [String: String]? = nil
    ) async throws {
        let _: EmptyResponse = try await performRequest(endpoint: endpoint, method: method, bodyData: nil, headers: headers)
    }

    func request<B: Encodable>(
        endpoint: APIConfiguration.Endpoint,
        method: HTTPMethod,
        body: B,
        headers: [String: String]? = nil
    ) async throws {
        let bodyData = try encoder.encode(body)
        let _: EmptyResponse = try await performRequest(endpoint: endpoint, method: method, bodyData: bodyData, headers: headers)
    }

    private func performRequest<T: Decodable>(
        endpoint: APIConfiguration.Endpoint,
        method: HTTPMethod,
        bodyData: Data?,
        headers: [String: String]?
    ) async throws -> T {
        let logger = APILogger.shared
        let requestId = logger.nextRequestId()
        let startTime = Date()

        var request = URLRequest(url: endpoint.url)
        request.httpMethod = method.rawValue

        // Build headers dictionary for logging
        var allHeaders: [String: String] = ["Content-Type": "application/json"]
        headers?.forEach { allHeaders[$0] = $1 }

        // Add headers to request
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Add authentication token from Supabase session
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            allHeaders["Authorization"] = "Bearer \(token)"
        }

        // Set body if present
        request.httpBody = bodyData

        // Log request
        logger.logRequest(
            id: requestId,
            method: method.rawValue,
            url: endpoint.url,
            headers: allHeaders,
            body: bodyData
        )

        // Perform request
        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = APIError.invalidResponse
                logger.logError(
                    id: requestId,
                    method: method.rawValue,
                    url: endpoint.url,
                    error: error,
                    duration: duration
                )
                throw error
            }

            // Log response
            logger.logResponse(
                id: requestId,
                method: method.rawValue,
                url: endpoint.url,
                statusCode: httpResponse.statusCode,
                duration: duration,
                headers: httpResponse.allHeaderFields,
                body: data
            )

            // Check status code
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode and return
                do {
                    // Handle empty response
                    if data.isEmpty || T.self == EmptyResponse.self {
                        return EmptyResponse() as! T
                    }

                    let decoded = try decoder.decode(T.self, from: data)
                    return decoded
                } catch {
                    logger.logError(
                        id: requestId,
                        method: method.rawValue,
                        url: endpoint.url,
                        error: APIError.decodingError(error),
                        duration: duration,
                        responseBody: data
                    )
                    throw APIError.decodingError(error)
                }

            case 401:
                throw APIError.unauthorized

            case 404:
                throw APIError.notFound

            case 409:
                throw APIError.conflict

            default:
                let message = String(data: data, encoding: .utf8)
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
        } catch let error as APIError {
            let duration = Date().timeIntervalSince(startTime)
            logger.logError(
                id: requestId,
                method: method.rawValue,
                url: endpoint.url,
                error: error,
                duration: duration
            )
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let apiError = APIError.networkError(error)
            logger.logError(
                id: requestId,
                method: method.rawValue,
                url: endpoint.url,
                error: apiError,
                duration: duration
            )
            throw apiError
        }
    }

    // MARK: - Authentication
    private func getAuthToken() async -> String? {
        return await AuthService.shared.getAccessToken()
    }
}

// MARK: - Empty Response
struct EmptyResponse: Decodable {}
