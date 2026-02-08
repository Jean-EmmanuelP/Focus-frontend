import Foundation

// Helper to get user's local date string
private func getUserLocalDateString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

// MARK: - Dashboard Service
@MainActor
class DashboardService {
    private let apiClient = APIClient.shared

    func fetchDashboardData() async throws -> DashboardResponse {
        let dateString = getUserLocalDateString()
        print("📅 Fetching dashboard for date: \(dateString)")
        return try await apiClient.request(
            endpoint: .dashboard(date: dateString),
            method: .get
        )
    }

    func fetchFiremodeData() async throws -> FiremodeResponse {
        return try await apiClient.request(
            endpoint: .firemode,
            method: .get
        )
    }

    func fetchQuestsTabData() async throws -> QuestsTabResponse {
        return try await apiClient.request(
            endpoint: .questsTab,
            method: .get
        )
    }
}

// MARK: - User Service
@MainActor
class UserService {
    private let apiClient = APIClient.shared

    func fetchMe() async throws -> UserResponse {
        return try await apiClient.request(
            endpoint: .me,
            method: .get
        )
    }

    /// Update user profile with any combination of fields
    func updateProfile(
        pseudo: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        gender: String? = nil,
        age: Int? = nil,
        birthday: String? = nil,  // Format: YYYY-MM-DD
        description: String? = nil,
        hobbies: String? = nil,
        lifeGoal: String? = nil,
        avatarUrl: String? = nil,
        companionName: String? = nil,
        companionGender: String? = nil,
        avatarStyle: String? = nil
    ) async throws -> UserResponse {
        struct UpdateUserRequest: Encodable {
            let pseudo: String?
            let firstName: String?
            let lastName: String?
            let gender: String?
            let age: Int?
            let birthday: String?
            let description: String?
            let hobbies: String?
            let lifeGoal: String?
            let avatarUrl: String?
            let companionName: String?
            let companionGender: String?
            let avatarStyle: String?
        }

        let request = UpdateUserRequest(
            pseudo: pseudo,
            firstName: firstName,
            lastName: lastName,
            gender: gender,
            age: age,
            birthday: birthday,
            description: description,
            hobbies: hobbies,
            lifeGoal: lifeGoal,
            avatarUrl: avatarUrl,
            companionName: companionName,
            companionGender: companionGender,
            avatarStyle: avatarStyle
        )

        return try await apiClient.request(
            endpoint: .me,
            method: .patch,
            body: request
        )
    }

    func uploadAvatar(imageData: Data, contentType: String = "image/jpeg") async throws -> String {
        struct UploadAvatarRequest: Encodable {
            let imageBase64: String
            let contentType: String

            enum CodingKeys: String, CodingKey {
                case imageBase64 = "image_base64"
                case contentType = "content_type"
            }
        }

        struct UploadAvatarResponse: Decodable {
            let avatarUrl: String
            // Note: APIClient uses .convertFromSnakeCase so avatar_url -> avatarUrl automatically
        }

        let base64String = imageData.base64EncodedString()
        let request = UploadAvatarRequest(imageBase64: base64String, contentType: contentType)

        let response: UploadAvatarResponse = try await apiClient.request(
            endpoint: .uploadAvatar,
            method: .post,
            body: request
        )
        return response.avatarUrl
    }

    func deleteAvatar() async throws {
        try await apiClient.request(
            endpoint: .deleteAvatar,
            method: .delete
        )
    }

    func updateProductivityPeak(_ peak: ProductivityPeak) async throws -> UserResponse {
        struct UpdateProductivityRequest: Encodable {
            let productivityPeak: String
        }

        let request = UpdateProductivityRequest(productivityPeak: peak.rawValue)
        print("📊 Sending productivity peak update: \(peak.rawValue)")
        let response: UserResponse = try await apiClient.request(
            endpoint: .me,
            method: .patch,
            body: request
        )
        print("📊 Received productivity peak: \(response.productivityPeak ?? "nil")")
        return response
    }

    /// Update user settings (language, timezone, notifications)
    func updateSettings(
        language: String? = nil,
        timezone: String? = nil,
        notificationsEnabled: Bool? = nil,
        morningReminderTime: String? = nil
    ) async throws -> UserResponse {
        struct UpdateSettingsRequest: Encodable {
            let language: String?
            let timezone: String?
            let notificationsEnabled: Bool?
            let morningReminderTime: String?
        }

        let request = UpdateSettingsRequest(
            language: language,
            timezone: timezone,
            notificationsEnabled: notificationsEnabled,
            morningReminderTime: morningReminderTime
        )

        return try await apiClient.request(
            endpoint: .me,
            method: .patch,
            body: request
        )
    }

    /// Delete user account (GDPR compliant)
    func deleteAccount() async throws {
        try await apiClient.request(
            endpoint: .deleteAccount,
            method: .delete
        )
    }
}

// MARK: - Areas Service
@MainActor
class AreasService {
    private let apiClient = APIClient.shared

    func fetchAreas() async throws -> [Area] {
        return try await apiClient.request(
            endpoint: .areas,
            method: .get
        )
    }

    func createArea(name: String, slug: String, icon: String) async throws -> Area {
        struct CreateAreaRequest: Encodable {
            let name: String
            let slug: String
            let icon: String
        }

        let request = CreateAreaRequest(name: name, slug: slug, icon: icon)

        return try await apiClient.request(
            endpoint: .createArea,
            method: .post,
            body: request
        )
    }

    func updateArea(id: String, name: String?, slug: String?, icon: String?) async throws -> Area {
        struct UpdateAreaRequest: Encodable {
            let name: String?
            let slug: String?
            let icon: String?
        }

        let request = UpdateAreaRequest(name: name, slug: slug, icon: icon)

        return try await apiClient.request(
            endpoint: .updateArea(id),
            method: .patch,
            body: request
        )
    }

    func deleteArea(id: String) async throws {
        try await apiClient.request(
            endpoint: .deleteArea(id),
            method: .delete
        )
    }
}

// MARK: - Quest Service
@MainActor
class QuestService {
    private let apiClient = APIClient.shared

    func fetchQuests(areaId: String? = nil) async throws -> [QuestResponse] {
        return try await apiClient.request(
            endpoint: .quests(areaId: areaId),
            method: .get
        )
    }

    func createQuest(areaId: String, title: String, targetValue: Int, targetDate: Date? = nil) async throws -> QuestResponse {
        struct CreateQuestRequest: Encodable {
            let areaId: String
            let title: String
            let targetValue: Int
            let targetDate: String?
        }

        // Convert date to ISO string if provided
        var targetDateString: String? = nil
        if let date = targetDate {
            let formatter = ISO8601DateFormatter()
            targetDateString = formatter.string(from: date)
        }

        let request = CreateQuestRequest(areaId: areaId, title: title, targetValue: targetValue, targetDate: targetDateString)

        // Debug: log what we're sending
        print("🎯 Creating quest:")
        print("   - area_id: \(areaId)")
        print("   - title: \(title)")
        print("   - target_value: \(targetValue)")
        print("   - target_date: \(targetDateString ?? "none")")

        return try await apiClient.request(
            endpoint: .createQuest,
            method: .post,
            body: request
        )
    }

    func updateQuest(id: String, title: String?, status: String?, currentValue: Int?, targetValue: Int?, targetDate: Date? = nil) async throws -> QuestResponse {
        struct UpdateQuestRequest: Encodable {
            let title: String?
            let status: String?
            let currentValue: Int?
            let targetValue: Int?
            let targetDate: String?
        }

        // Convert date to ISO string if provided
        var targetDateString: String? = nil
        if let date = targetDate {
            let formatter = ISO8601DateFormatter()
            targetDateString = formatter.string(from: date)
        }

        let request = UpdateQuestRequest(title: title, status: status, currentValue: currentValue, targetValue: targetValue, targetDate: targetDateString)

        return try await apiClient.request(
            endpoint: .updateQuest(id),
            method: .patch,
            body: request
        )
    }

    func updateQuestProgress(questId: String, progress: Double) async throws -> QuestResponse {
        // Convert progress (0-1) to currentValue based on targetValue
        let currentValue = Int(progress * 100)
        return try await updateQuest(id: questId, title: nil, status: nil, currentValue: currentValue, targetValue: 100)
    }

    func deleteQuest(id: String) async throws {
        try await apiClient.request(
            endpoint: .deleteQuest(id),
            method: .delete
        )
    }
}

// MARK: - Routine Service (formerly Ritual)
@MainActor
class RoutineService {
    private let apiClient = APIClient.shared

    func fetchRoutines(areaId: String? = nil) async throws -> [RoutineResponse] {
        return try await apiClient.request(
            endpoint: .routines(areaId: areaId),
            method: .get
        )
    }

    func createRoutine(areaId: String, title: String, frequency: String, icon: String, scheduledTime: String? = nil) async throws -> RoutineResponse {
        struct CreateRoutineRequest: Encodable {
            let areaId: String
            let title: String
            let frequency: String
            let icon: String
            let scheduledTime: String?
        }

        let request = CreateRoutineRequest(areaId: areaId, title: title, frequency: frequency, icon: icon, scheduledTime: scheduledTime)

        return try await apiClient.request(
            endpoint: .createRoutine,
            method: .post,
            body: request
        )
    }

    func updateRoutine(id: String, areaId: String? = nil, title: String?, frequency: String?, icon: String?, scheduledTime: String? = nil, durationMinutes: Int? = nil) async throws -> RoutineResponse {
        struct UpdateRoutineRequest: Encodable {
            let areaId: String?
            let title: String?
            let frequency: String?
            let icon: String?
            let scheduledTime: String?
            let durationMinutes: Int?
        }

        let request = UpdateRoutineRequest(areaId: areaId, title: title, frequency: frequency, icon: icon, scheduledTime: scheduledTime, durationMinutes: durationMinutes)

        return try await apiClient.request(
            endpoint: .updateRoutine(id),
            method: .patch,
            body: request
        )
    }

    func completeRoutine(id: String, date: String? = nil) async throws {
        print("✅ Completing routine: \(id) for date: \(date ?? "today")")
        print("   Endpoint: POST /routines/\(id)/complete")

        if let date = date {
            struct CompleteRequest: Encodable {
                let date: String
            }
            try await apiClient.request(
                endpoint: .completeRoutine(id),
                method: .post,
                body: CompleteRequest(date: date)
            )
        } else {
            try await apiClient.request(
                endpoint: .completeRoutine(id),
                method: .post
            )
        }
        print("✅ Routine completed successfully")
    }

    func uncompleteRoutine(id: String, date: String? = nil) async throws {
        print("↩️ Uncompleting routine: \(id) for date: \(date ?? "most recent")")
        print("   Endpoint: DELETE /routines/\(id)/complete")

        if let date = date {
            struct UncompleteRequest: Encodable {
                let date: String
            }
            try await apiClient.request(
                endpoint: .uncompleteRoutine(id),
                method: .delete,
                body: UncompleteRequest(date: date)
            )
        } else {
            try await apiClient.request(
                endpoint: .uncompleteRoutine(id),
                method: .delete
            )
        }
        print("↩️ Routine uncompleted successfully")
    }

    func completeRoutinesBatch(routineIds: [String]) async throws {
        struct BatchCompleteRequest: Encodable {
            let routineIds: [String]
        }

        let request = BatchCompleteRequest(routineIds: routineIds)

        try await apiClient.request(
            endpoint: .completeRoutinesBatch,
            method: .post,
            body: request
        )
    }

    func deleteRoutine(id: String) async throws {
        try await apiClient.request(
            endpoint: .deleteRoutine(id),
            method: .delete
        )
    }

    // Legacy method for compatibility
    func toggleRitual(ritualId: String, isCompleted: Bool) async throws -> DailyRitual {
        if isCompleted {
            try await completeRoutine(id: ritualId)
        } else {
            try await uncompleteRoutine(id: ritualId)
        }
        // Return a mock ritual for now - the view should refresh from the API
        return DailyRitual(id: ritualId, title: "", icon: "", isCompleted: isCompleted, category: .health)
    }
}

// Alias for backward compatibility
typealias RitualService = RoutineService

// MARK: - Focus Session Service
@MainActor
class FocusSessionService {
    private let apiClient = APIClient.shared

    func fetchSessions(questId: String? = nil, status: String? = nil, limit: Int? = nil) async throws -> [FocusSessionResponse] {
        print("📊 Fetching sessions: status=\(status ?? "all"), questId=\(questId ?? "all"), limit=\(limit ?? 0)")
        let sessions: [FocusSessionResponse] = try await apiClient.request(
            endpoint: .focusSessions(questId: questId, status: status, limit: limit),
            method: .get
        )
        print("📊 Fetched \(sessions.count) sessions")
        return sessions
    }

    /// Start a new focus session (status = active)
    func createSession(durationMinutes: Int, questId: String?, description: String?) async throws -> FocusSessionResponse {
        struct CreateSessionRequest: Encodable {
            let questId: String?
            let description: String?
            let durationMinutes: Int

            enum CodingKeys: String, CodingKey {
                case questId = "quest_id"
                case description
                case durationMinutes = "duration_minutes"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(durationMinutes, forKey: .durationMinutes)
                try container.encode(questId, forKey: .questId)
                try container.encode(description, forKey: .description)
            }
        }

        let request = CreateSessionRequest(
            questId: questId,
            description: description,
            durationMinutes: durationMinutes
        )

        print("🔥 Starting focus session:")
        print("   - planned duration: \(durationMinutes) min")
        print("   - quest_id: \(questId ?? "null")")
        print("   - description: \(description ?? "null")")

        return try await apiClient.request(
            endpoint: .createFocusSession,
            method: .post,
            body: request
        )
    }

    func logManualSession(durationMinutes: Int, startTime: Date, questId: String?, description: String?) async throws -> FocusSessionResponse {
        // For manual logging, create and immediately complete
        let session = try await createSession(durationMinutes: durationMinutes, questId: questId, description: description)
        return try await completeSession(sessionId: session.id)
    }

    func updateSession(id: String, status: String) async throws -> FocusSessionResponse {
        struct UpdateSessionRequest: Encodable {
            let status: String
        }

        let request = UpdateSessionRequest(status: status)

        return try await apiClient.request(
            endpoint: .updateFocusSession(id),
            method: .patch,
            body: request
        )
    }

    /// Edit session details (description, duration)
    func editSession(id: String, description: String?, durationMinutes: Int?) async throws -> FocusSessionResponse {
        struct EditSessionRequest: Encodable {
            let description: String?
            let durationMinutes: Int?

            enum CodingKeys: String, CodingKey {
                case description
                case durationMinutes = "duration_minutes"
            }
        }

        let request = EditSessionRequest(
            description: description,
            durationMinutes: durationMinutes
        )

        return try await apiClient.request(
            endpoint: .updateFocusSession(id),
            method: .patch,
            body: request
        )
    }

    func completeSession(sessionId: String) async throws -> FocusSessionResponse {
        return try await updateSession(id: sessionId, status: "completed")
    }

    func cancelSession(sessionId: String) async throws -> FocusSessionResponse {
        return try await updateSession(id: sessionId, status: "cancelled")
    }

    func deleteSession(id: String) async throws {
        try await apiClient.request(
            endpoint: .deleteFocusSession(id),
            method: .delete
        )
    }
}

// MARK: - Reflection Service (formerly Check-in)
@MainActor
class ReflectionService {
    private let apiClient = APIClient.shared

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func fetchReflections(from: Date? = nil, to: Date? = nil, limit: Int? = nil) async throws -> [ReflectionResponse] {
        let fromString = from.map { dateFormatter.string(from: $0) }
        let toString = to.map { dateFormatter.string(from: $0) }

        return try await apiClient.request(
            endpoint: .reflections(from: fromString, to: toString, limit: limit),
            method: .get
        )
    }

    func fetchReflection(date: Date) async throws -> ReflectionResponse? {
        let dateString = dateFormatter.string(from: date)
        do {
            return try await apiClient.request(
                endpoint: .reflection(date: dateString),
                method: .get
            )
        } catch APIError.notFound {
            return nil
        }
    }

    func upsertReflection(
        date: Date,
        biggestWin: String?,
        challenges: String?,
        bestMoment: String?,
        goalForTomorrow: String?
    ) async throws -> ReflectionResponse {
        struct UpsertReflectionRequest: Encodable {
            let biggestWin: String?
            let challenges: String?
            let bestMoment: String?
            let goalForTomorrow: String?
        }

        let dateString = dateFormatter.string(from: date)
        let request = UpsertReflectionRequest(
            biggestWin: biggestWin,
            challenges: challenges,
            bestMoment: bestMoment,
            goalForTomorrow: goalForTomorrow
        )

        return try await apiClient.request(
            endpoint: .upsertReflection(date: dateString),
            method: .put,
            body: request
        )
    }

    // Morning check-in specific method
    func upsertReflection(
        date: Date,
        morningFeeling: String?,
        sleepQuality: Int?,
        intentions: String?,
        morningNote: String?
    ) async throws -> ReflectionResponse {
        struct MorningReflectionRequest: Encodable {
            let morningFeeling: String?
            let sleepQuality: Int?
            let intentions: String?
            let morningNote: String?
        }

        let dateString = dateFormatter.string(from: date)
        let request = MorningReflectionRequest(
            morningFeeling: morningFeeling,
            sleepQuality: sleepQuality,
            intentions: intentions,
            morningNote: morningNote
        )

        return try await apiClient.request(
            endpoint: .upsertReflection(date: dateString),
            method: .put,
            body: request
        )
    }
}

// Alias for backward compatibility
typealias CheckInService = ReflectionService

// MARK: - Intentions Service (Start Your Day / Morning Check-in)
@MainActor
class IntentionsService {
    private let apiClient = APIClient.shared

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// Get today's intentions
    func fetchTodayIntentions() async throws -> DailyIntentionsResponse {
        let dateString = dateFormatter.string(from: Date())
        print("📅 Fetching today's intentions for date: \(dateString)")
        return try await apiClient.request(
            endpoint: .intentionsToday(date: dateString),
            method: .get
        )
    }

    /// Get intentions for a specific date
    func fetchIntentions(date: Date) async throws -> DailyIntentionsResponse {
        let dateString = dateFormatter.string(from: date)
        return try await apiClient.request(
            endpoint: .intentions(date: dateString),
            method: .get
        )
    }

    /// Check if user has started their day (intentions exist for today)
    func hasStartedDay() async -> Bool {
        do {
            _ = try await fetchTodayIntentions()
            return true
        } catch {
            return false
        }
    }

    /// Save morning intentions
    func saveIntentions(
        date: Date,
        moodRating: Int,
        moodEmoji: String,
        sleepRating: Int,
        sleepEmoji: String,
        intentions: [IntentionInput]
    ) async throws -> DailyIntentionsResponse {
        struct SaveIntentionsRequest: Encodable {
            let moodRating: Int
            let moodEmoji: String
            let sleepRating: Int
            let sleepEmoji: String
            let intentions: [IntentionInput]
        }

        let dateString = dateFormatter.string(from: date)
        let request = SaveIntentionsRequest(
            moodRating: moodRating,
            moodEmoji: moodEmoji,
            sleepRating: sleepRating,
            sleepEmoji: sleepEmoji,
            intentions: intentions
        )

        print("📝 Saving intentions for \(dateString)")
        print("   - mood: \(moodRating) \(moodEmoji)")
        print("   - sleep: \(sleepRating) \(sleepEmoji)")
        print("   - intentions: \(intentions.count)")
        for (index, intention) in intentions.enumerated() {
            print("   - intention[\(index)]: area_id=\(intention.areaId ?? "null"), content=\(intention.content)")
        }

        // Debug: print the actual JSON being sent
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let jsonData = try? encoder.encode(request),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Request JSON: \(jsonString)")
        }

        return try await apiClient.request(
            endpoint: .upsertIntentions(date: dateString),
            method: .put,
            body: request
        )
    }
}

// Intention input for creating/updating
struct IntentionInput: Encodable {
    let areaId: String?
    let content: String

    enum CodingKeys: String, CodingKey {
        case areaId = "area_id"
        case content
    }

    // Explicitly encode null for area_id (Swift skips nil by default)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(areaId, forKey: .areaId) // This encodes null explicitly
        try container.encode(content, forKey: .content)
    }
}

// Response model for daily intentions
struct DailyIntentionsResponse: Codable, Identifiable {
    let id: String
    let date: String
    let moodRating: Int
    let moodEmoji: String
    let sleepRating: Int
    let sleepEmoji: String
    let intentions: [IntentionResponse]
}

struct IntentionResponse: Codable, Identifiable {
    let id: String
    let areaId: String?
    let content: String
    let position: Int
}

// MARK: - Completions Service
@MainActor
class CompletionsService {
    private let apiClient = APIClient.shared

    func fetchCompletions(routineId: String? = nil, from: String? = nil, to: String? = nil) async throws -> [CompletionResponse] {
        return try await apiClient.request(
            endpoint: .completions(routineId: routineId, from: from, to: to),
            method: .get
        )
    }
}

// MARK: - Stats Service
@MainActor
class StatsService {
    private let apiClient = APIClient.shared

    func fetchFocusStats() async throws -> FocusStatsResponse {
        return try await apiClient.request(
            endpoint: .statsFocus,
            method: .get
        )
    }

    func fetchRoutineStats() async throws -> RoutineStatsResponse {
        return try await apiClient.request(
            endpoint: .statsRoutines,
            method: .get
        )
    }
}

// MARK: - API Response Models

struct UserResponse: Codable {
    let id: String
    let email: String?
    let pseudo: String?
    let firstName: String?
    let lastName: String?
    let gender: String?
    let age: Int?
    let birthday: Date?
    let description: String?
    let hobbies: String?
    let lifeGoal: String?
    let avatarUrl: String?
    let dayVisibility: String?
    let productivityPeak: String?
    // V1 Settings
    let language: String?
    let timezone: String?
    let notificationsEnabled: Bool?
    let morningReminderTime: String?
    // Companion settings
    let companionName: String?
    let companionGender: String?
    let avatarStyle: String?
}

struct Area: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let icon: String
    let completeness: Int?
}

struct QuestResponse: Codable, Identifiable {
    let id: String
    let areaId: String
    let title: String
    let status: String
    let currentValue: Int
    let targetValue: Int
    let targetDate: String? // ISO date string

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return Double(currentValue) / Double(targetValue)
    }
}

struct RoutineResponse: Codable, Identifiable {
    let id: String
    let areaId: String?  // Optional - not always returned by dashboard
    let title: String
    let frequency: String
    let icon: String?
    var completed: Bool?
    let scheduledTime: String? // Time in "HH:mm" format (e.g., "07:30")
}

struct FocusSessionResponse: Codable, Identifiable {
    let id: String
    let questId: String?
    let description: String?
    let durationMinutes: Int
    let status: String
    let startedAt: Date
    let completedAt: Date?
}

struct ReflectionResponse: Codable, Identifiable {
    let id: String
    let date: String
    let biggestWin: String?
    let challenges: String?
    let bestMoment: String?
    let goalForTomorrow: String?
}

struct CompletionResponse: Codable, Identifiable {
    let id: String
    let routineId: String
    let completedAt: Date
}

struct DashboardResponse: Codable {
    let user: UserResponse
    let areas: [Area]
    let todaysRoutines: [RoutineResponse]
    let todayIntentions: DashboardIntentions?
    let stats: DashboardStats
    let weekSessions: WeekSessionsData

    // Optional fields that may or may not be present
    let activeQuests: [QuestResponse]?
}

// Intentions included in dashboard response
struct DashboardIntentions: Codable {
    let id: String
    let moodRating: Int
    let moodEmoji: String
    let sleepRating: Int
    let sleepEmoji: String
    let intentions: [DashboardIntentionItem]
}

struct DashboardIntentionItem: Codable {
    let id: String
    let areaId: String?
    let content: String
    let position: Int
}

// Week sessions structure from dashboard
struct WeekSessionsData: Codable {
    let totalMinutes: Int
    let totalSessions: Int
    let days: [DailySessionStat]
    let sessions: [FocusSessionResponse]?  // Individual sessions (optional)
}

struct DashboardStats: Codable {
    let focusedToday: Int
    let streakDays: Int
}

struct DailySessionStat: Codable {
    let date: String
    let minutes: Int
    let sessions: Int
}

struct FiremodeResponse: Codable {
    let minutesToday: Int
    let sessionsToday: Int
    let sessionsWeek: Int
    let minutesLast7: Int
    let sessionsLast7: Int
    let activeQuests: [QuestResponse]?  // Optional - not returned by /firemode endpoint
}

struct QuestsTabResponse: Codable {
    let areas: [Area]
    let quests: [QuestResponse]
    let routines: [RoutineResponse]
}

struct FocusStatsResponse: Codable {
    // Add fields based on actual API response
}

struct RoutineStatsResponse: Codable {
    // Add fields based on actual API response
}

// MARK: - Streak Response
struct FlameLevel: Codable, Identifiable {
    let level: Int
    let name: String
    let icon: String
    let daysRequired: Int
    let isUnlocked: Bool
    let isCurrent: Bool

    var id: Int { level }
}

struct StreakResponse: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let lastValidDate: String?
    let streakStart: String?
    let todayValidation: DayValidationResponse?
    let flameLevels: [FlameLevel]
    let currentFlameLevel: Int
}

struct DayValidationResponse: Codable {
    let date: String
    let hasIntention: Bool
    let totalRoutines: Int
    let completedRoutines: Int
    let routineRate: Int
    let totalTasks: Int
    let completedTasks: Int
    let taskRate: Int
    let totalItems: Int
    let completedItems: Int
    let overallRate: Int
    let isValid: Bool
    // Requirements (simplified: 60% completion + at least 1 task)
    let requiredCompletionRate: Int
    let requiredMinTasks: Int
    let meetsCompletionRate: Bool
    let meetsMinTasks: Bool
}

// MARK: - Streak Service
@MainActor
class StreakService {
    private let apiClient = APIClient.shared

    func fetchStreak() async throws -> StreakResponse {
        let dateString = getUserLocalDateString()
        return try await apiClient.request(
            endpoint: .streak(date: dateString),
            method: .get
        )
    }

    func fetchDayValidation(date: String? = nil) async throws -> DayValidationResponse {
        let dateString = date ?? getUserLocalDateString()
        return try await apiClient.request(
            endpoint: .streakDay(date: dateString),
            method: .get
        )
    }

    func recalculateStreak() async throws -> StreakResponse {
        let dateString = getUserLocalDateString()
        return try await apiClient.request(
            endpoint: .streakRecalculate(date: dateString),
            method: .post
        )
    }

    private func getUserLocalDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Onboarding Service
@MainActor
class OnboardingService {
    private let apiClient = APIClient.shared

    /// Get current onboarding status
    func getStatus() async throws -> OnboardingStatusResponse {
        return try await apiClient.request(
            endpoint: .onboardingStatus,
            method: .get
        )
    }

    /// Save onboarding progress
    func saveProgress(
        projectStatus: String?,
        timeAvailable: String?,
        goals: [String],
        currentStep: Int,
        isComplete: Bool
    ) async throws -> OnboardingStatusResponse {
        struct SaveProgressRequest: Encodable {
            let projectStatus: String?
            let timeAvailable: String?
            let goals: [String]
            let currentStep: Int
            let isComplete: Bool
        }

        let request = SaveProgressRequest(
            projectStatus: projectStatus,
            timeAvailable: timeAvailable,
            goals: goals,
            currentStep: currentStep,
            isComplete: isComplete
        )

        return try await apiClient.request(
            endpoint: .onboardingProgress,
            method: .put,
            body: request
        )
    }

    /// Mark onboarding as complete
    func completeOnboarding() async throws -> OnboardingStatusResponse {
        return try await apiClient.request(
            endpoint: .onboardingComplete,
            method: .post
        )
    }

    /// Reset onboarding (for testing)
    func resetOnboarding() async throws {
        try await apiClient.request(
            endpoint: .onboardingReset,
            method: .delete
        )
    }

    /// Check if user has completed onboarding
    func hasCompletedOnboarding() async -> Bool {
        do {
            let status = try await getStatus()
            return status.isCompleted
        } catch {
            return false
        }
    }
}

// MARK: - Onboarding Response Models
struct OnboardingStatusResponse: Codable {
    let isCompleted: Bool
    let currentStep: Int
    let totalSteps: Int
    let projectStatus: String?
    let timeAvailable: String?
    let goals: [String]?
    let completedAt: Date?
}

// MARK: - Community Post Models

/// User info embedded in community posts
struct PostUser: Codable {
    let id: String
    let pseudo: String?
    let avatarUrl: String?
}

struct CommunityPostResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let taskId: String?
    let routineId: String?
    let imageUrl: String
    let caption: String?
    let likesCount: Int
    let createdAt: Date

    // Author info (nested user object from backend)
    let user: PostUser?

    // Task/Routine info (joined)
    let taskTitle: String?
    let routineTitle: String?

    // Current user like status
    let isLikedByMe: Bool

    // Computed properties for easier access
    var authorPseudo: String? { user?.pseudo }
    var authorAvatarUrl: String? { user?.avatarUrl }
}

struct CommunityFeedResponse: Codable {
    let posts: [CommunityPostResponse]
    let hasMore: Bool
    let nextOffset: Int
}

// MARK: - Community Service
@MainActor
class CommunityService {
    private let apiClient = APIClient.shared

    /// Fetch public community feed
    func fetchFeed(limit: Int = 20, offset: Int = 0) async throws -> CommunityFeedResponse {
        return try await apiClient.request(
            endpoint: .communityFeed(limit: limit, offset: offset),
            method: .get
        )
    }

    /// Fetch current user's posts
    func fetchMyPosts(limit: Int = 20, offset: Int = 0) async throws -> CommunityFeedResponse {
        return try await apiClient.request(
            endpoint: .communityMyPosts(limit: limit, offset: offset),
            method: .get
        )
    }

    /// Create a new community post
    func createPost(imageData: Data, caption: String?, taskId: String?, routineId: String?, contentType: String = "image/jpeg") async throws -> CommunityPostResponse {
        struct CreatePostRequest: Encodable {
            let imageBase64: String
            let caption: String?
            let taskId: String?
            let routineId: String?
            let contentType: String
        }

        let base64String = imageData.base64EncodedString()
        let request = CreatePostRequest(
            imageBase64: base64String,
            caption: caption,
            taskId: taskId,
            routineId: routineId,
            contentType: contentType
        )

        return try await apiClient.request(
            endpoint: .createCommunityPost,
            method: .post,
            body: request
        )
    }

    /// Get a single post by ID
    func getPost(id: String) async throws -> CommunityPostResponse {
        return try await apiClient.request(
            endpoint: .communityPost(id),
            method: .get
        )
    }

    /// Delete a post (own posts only)
    func deletePost(id: String) async throws {
        try await apiClient.request(
            endpoint: .deleteCommunityPost(id),
            method: .delete
        )
    }

    /// Like a post
    func likePost(id: String) async throws {
        try await apiClient.request(
            endpoint: .likeCommunityPost(id),
            method: .post
        )
    }

    /// Unlike a post
    func unlikePost(id: String) async throws {
        try await apiClient.request(
            endpoint: .unlikeCommunityPost(id),
            method: .delete
        )
    }

    /// Report a post
    func reportPost(id: String, reason: String, details: String?) async throws {
        struct ReportRequest: Encodable {
            let reason: String
            let details: String?
        }

        let request = ReportRequest(reason: reason, details: details)
        try await apiClient.request(
            endpoint: .reportCommunityPost(id),
            method: .post,
            body: request
        )
    }

    /// Get posts linked to a specific task
    func getTaskPosts(taskId: String) async throws -> [CommunityPostResponse] {
        return try await apiClient.request(
            endpoint: .taskPosts(taskId: taskId),
            method: .get
        )
    }

    /// Get posts linked to a specific routine
    func getRoutinePosts(routineId: String) async throws -> [CommunityPostResponse] {
        return try await apiClient.request(
            endpoint: .routinePosts(routineId: routineId),
            method: .get
        )
    }
}

// MARK: - Journal Models

/// A daily journal entry with audio/video reflection
struct JournalEntryResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let mediaType: String          // "audio" or "video"
    let mediaUrl: String
    let durationSeconds: Int
    let transcript: String?
    let summary: String?
    let title: String?
    let mood: String?              // "great", "good", "neutral", "low", "bad"
    let moodScore: Int?            // 1-10
    let tags: [String]?
    let entryDate: String          // YYYY-MM-DD
    let createdAt: Date
    let updatedAt: Date

    /// Emoji for mood display
    var moodEmoji: String {
        switch mood {
        case "great": return "😊"
        case "good": return "🙂"
        case "neutral": return "😐"
        case "low": return "😕"
        case "bad": return "😢"
        default: return "😐"
        }
    }

    /// Formatted duration string
    var formattedDuration: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
}

/// Paginated list of journal entries
struct JournalEntryListResponse: Codable {
    let entries: [JournalEntryResponse]
    let hasMore: Bool
    let nextOffset: Int
}

/// Weekly or monthly summary bilan
struct JournalBilanResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let bilanType: String          // "weekly" or "monthly"
    let periodStart: String
    let periodEnd: String
    let summary: String
    let wins: [String]?
    let improvements: [String]?
    let moodTrend: String?         // "improving", "stable", "declining"
    let avgMoodScore: Double?
    let suggestedGoals: [String]?  // For monthly only
    let createdAt: Date
}

/// Mood statistics for graphing
struct JournalMoodStat: Codable {
    let date: String
    let moodScore: Int?
    let mood: String?
}

struct JournalStatsResponse: Codable {
    let stats: [JournalMoodStat]
    let currentStreak: Int
    let totalEntries: Int
}

struct JournalStreakResponse: Codable {
    let streak: Int
}

// MARK: - Journal Service
@MainActor
class JournalService {
    private let apiClient = APIClient.shared

    /// Fetch journal entries with optional filters
    func fetchEntries(limit: Int = 20, offset: Int = 0, dateFrom: String? = nil, dateTo: String? = nil) async throws -> JournalEntryListResponse {
        return try await apiClient.request(
            endpoint: .journalEntries(limit: limit, offset: offset, dateFrom: dateFrom, dateTo: dateTo),
            method: .get
        )
    }

    /// Get today's journal entry
    func fetchTodayEntry() async throws -> JournalEntryResponse {
        return try await apiClient.request(
            endpoint: .journalEntryToday,
            method: .get
        )
    }

    /// Get a specific journal entry
    func fetchEntry(id: String) async throws -> JournalEntryResponse {
        return try await apiClient.request(
            endpoint: .journalEntry(id),
            method: .get
        )
    }

    /// Create a new journal entry with audio/video
    func createEntry(mediaData: Data, mediaType: String, contentType: String, durationSeconds: Int, entryDate: String? = nil) async throws -> JournalEntryResponse {
        struct CreateEntryRequest: Encodable {
            let mediaBase64: String
            let mediaType: String
            let contentType: String
            let durationSeconds: Int
            let entryDate: String?
        }

        let base64String = mediaData.base64EncodedString()
        let request = CreateEntryRequest(
            mediaBase64: base64String,
            mediaType: mediaType,
            contentType: contentType,
            durationSeconds: durationSeconds,
            entryDate: entryDate
        )

        return try await apiClient.request(
            endpoint: .createJournalEntry,
            method: .post,
            body: request
        )
    }

    /// Delete a journal entry
    func deleteEntry(id: String) async throws {
        try await apiClient.request(
            endpoint: .deleteJournalEntry(id),
            method: .delete
        )
    }

    /// Get current journaling streak
    func fetchStreak() async throws -> Int {
        let response: JournalStreakResponse = try await apiClient.request(
            endpoint: .journalStreak,
            method: .get
        )
        return response.streak
    }

    /// Get mood statistics for graphing
    func fetchStats(days: Int = 7) async throws -> JournalStatsResponse {
        return try await apiClient.request(
            endpoint: .journalStats(days: days),
            method: .get
        )
    }

    /// Fetch all bilans
    func fetchBilans() async throws -> [JournalBilanResponse] {
        return try await apiClient.request(
            endpoint: .journalBilans,
            method: .get
        )
    }

    /// Generate or retrieve weekly bilan
    func generateWeeklyBilan() async throws -> JournalBilanResponse {
        return try await apiClient.request(
            endpoint: .generateWeeklyBilan,
            method: .post
        )
    }

    /// Generate or retrieve monthly bilan
    func generateMonthlyBilan() async throws -> JournalBilanResponse {
        return try await apiClient.request(
            endpoint: .generateMonthlyBilan,
            method: .post
        )
    }
}

// MARK: - Weekly Goals Service
@MainActor
class WeeklyGoalsService {
    private let apiClient = APIClient.shared

    /// Get all weekly goals (last 10 weeks)
    func fetchAll() async throws -> [WeeklyGoalResponse] {
        return try await apiClient.request(
            endpoint: .weeklyGoals,
            method: .get
        )
    }

    /// Get current week's goals
    func fetchCurrent() async throws -> WeeklyGoalResponse {
        return try await apiClient.request(
            endpoint: .weeklyGoalsCurrent,
            method: .get
        )
    }

    /// Check if user needs to set up weekly goals
    func checkNeedsSetup() async throws -> NeedsSetupResponse {
        return try await apiClient.request(
            endpoint: .weeklyGoalsNeedsSetup,
            method: .get
        )
    }

    /// Get weekly goals for a specific week
    func fetchByWeek(weekStartDate: String) async throws -> WeeklyGoalResponse {
        return try await apiClient.request(
            endpoint: .weeklyGoalsByWeek(weekStartDate: weekStartDate),
            method: .get
        )
    }

    /// Create or update weekly goals
    func upsert(weekStartDate: String, items: [WeeklyGoalItemInput]) async throws -> WeeklyGoalResponse {
        let request = UpsertWeeklyGoalRequest(items: items)
        return try await apiClient.request(
            endpoint: .upsertWeeklyGoals(weekStartDate: weekStartDate),
            method: .put,
            body: request
        )
    }

    /// Delete weekly goals for a specific week
    func delete(weekStartDate: String) async throws {
        try await apiClient.request(
            endpoint: .deleteWeeklyGoals(weekStartDate: weekStartDate),
            method: .delete
        )
    }

    /// Toggle completion status of a goal item
    func toggleItem(itemId: String, isCompleted: Bool) async throws -> WeeklyGoalItemResponse {
        let request = ToggleWeeklyGoalItemRequest(isCompleted: isCompleted)
        return try await apiClient.request(
            endpoint: .toggleWeeklyGoalItem(itemId: itemId),
            method: .post,
            body: request
        )
    }

    // MARK: - Helper Methods

    /// Get the Monday of the current week
    static func currentWeekStartDate() -> String {
        let today = Date()
        let calendar = Calendar.current
        var weekday = calendar.component(.weekday, from: today)
        // Adjust for Sunday = 1 in Calendar
        if weekday == 1 {
            weekday = 8
        }
        let daysToMonday = weekday - 2
        let monday = calendar.date(byAdding: .day, value: -daysToMonday, to: today)!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }
}

// MARK: - Knowledge Service (Replika-style Memory System)
@MainActor
class KnowledgeService {
    private let apiClient = APIClient.shared

    // MARK: - User Knowledge Profile

    /// Fetch the user's knowledge profile (what AI knows about user)
    func fetchKnowledge() async throws -> KnowledgeResponse {
        return try await apiClient.request(
            endpoint: .knowledge,
            method: .get
        )
    }

    /// Update user's knowledge profile
    func updateKnowledge(
        name: String? = nil,
        pronouns: String? = nil,
        birthday: String? = nil,
        photoUrl: String? = nil
    ) async throws -> KnowledgeResponse {
        struct UpdateKnowledgeRequest: Encodable {
            let name: String?
            let pronouns: String?
            let birthday: String?
            let photoUrl: String?
        }

        return try await apiClient.request(
            endpoint: .updateKnowledge,
            method: .put,
            body: UpdateKnowledgeRequest(
                name: name,
                pronouns: pronouns,
                birthday: birthday,
                photoUrl: photoUrl
            )
        )
    }

    // MARK: - Known Persons

    /// Fetch all known persons
    func fetchPersons() async throws -> [KnowledgePersonResponse] {
        return try await apiClient.request(
            endpoint: .knowledgePersons,
            method: .get
        )
    }

    /// Create a new known person
    func createPerson(
        name: String,
        category: String,
        relation: String? = nil,
        photoUrl: String? = nil
    ) async throws -> KnowledgePersonResponse {
        struct CreatePersonRequest: Encodable {
            let name: String
            let category: String
            let relation: String?
            let photoUrl: String?
        }

        return try await apiClient.request(
            endpoint: .createKnowledgePerson,
            method: .post,
            body: CreatePersonRequest(
                name: name,
                category: category,
                relation: relation,
                photoUrl: photoUrl
            )
        )
    }

    /// Update a known person
    func updatePerson(
        personId: String,
        name: String? = nil,
        category: String? = nil,
        relation: String? = nil,
        photoUrl: String? = nil
    ) async throws -> KnowledgePersonResponse {
        struct UpdatePersonRequest: Encodable {
            let name: String?
            let category: String?
            let relation: String?
            let photoUrl: String?
        }

        return try await apiClient.request(
            endpoint: .updateKnowledgePerson(personId),
            method: .patch,
            body: UpdatePersonRequest(
                name: name,
                category: category,
                relation: relation,
                photoUrl: photoUrl
            )
        )
    }

    /// Delete a known person
    func deletePerson(personId: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            endpoint: .deleteKnowledgePerson(personId),
            method: .delete
        )
    }

    // MARK: - Life Domains

    /// Fetch all life domains
    func fetchDomains() async throws -> [KnowledgeDomainResponse] {
        return try await apiClient.request(
            endpoint: .knowledgeDomains,
            method: .get
        )
    }

    /// Update a life domain
    func updateDomain(
        domainId: String,
        name: String? = nil,
        imageUrl: String? = nil
    ) async throws -> KnowledgeDomainResponse {
        struct UpdateDomainRequest: Encodable {
            let name: String?
            let imageUrl: String?
        }

        return try await apiClient.request(
            endpoint: .updateKnowledgeDomain(domainId),
            method: .patch,
            body: UpdateDomainRequest(name: name, imageUrl: imageUrl)
        )
    }

    // MARK: - Facts

    /// Fetch facts (optionally filtered by person or domain)
    func fetchFacts(personId: String? = nil, domainId: String? = nil) async throws -> [KnowledgeFactResponse] {
        return try await apiClient.request(
            endpoint: .knowledgeFacts(personId: personId, domainId: domainId),
            method: .get
        )
    }

    /// Create a new fact
    func createFact(
        content: String,
        personId: String? = nil,
        domainId: String? = nil,
        source: String = "user"
    ) async throws -> KnowledgeFactResponse {
        struct CreateFactRequest: Encodable {
            let content: String
            let personId: String?
            let domainId: String?
            let source: String
        }

        return try await apiClient.request(
            endpoint: .createKnowledgeFact,
            method: .post,
            body: CreateFactRequest(
                content: content,
                personId: personId,
                domainId: domainId,
                source: source
            )
        )
    }

    /// Update a fact
    func updateFact(
        factId: String,
        content: String? = nil,
        isVerified: Bool? = nil
    ) async throws -> KnowledgeFactResponse {
        struct UpdateFactRequest: Encodable {
            let content: String?
            let isVerified: Bool?
        }

        return try await apiClient.request(
            endpoint: .updateKnowledgeFact(factId),
            method: .patch,
            body: UpdateFactRequest(content: content, isVerified: isVerified)
        )
    }

    /// Delete a fact
    func deleteFact(factId: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            endpoint: .deleteKnowledgeFact(factId),
            method: .delete
        )
    }
}

// MARK: - Knowledge Response Models

struct KnowledgeResponse: Codable {
    let id: String
    let userId: String
    let name: String?
    let pronouns: String?
    let birthday: String?
    let photoUrl: String?
    let createdAt: Date
    let updatedAt: Date
}

struct KnowledgePersonResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let category: String
    let relation: String?
    let photoUrl: String?
    let factsCount: Int?
    let createdAt: Date
    let updatedAt: Date
}

struct KnowledgeDomainResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let imageUrl: String?
    let factsCount: Int?
    let createdAt: Date
    let updatedAt: Date
}

struct KnowledgeFactResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let personId: String?
    let domainId: String?
    let content: String
    let source: String
    let isVerified: Bool
    let createdAt: Date
    let updatedAt: Date
}
