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
        description: String? = nil,
        hobbies: String? = nil,
        lifeGoal: String? = nil,
        avatarUrl: String? = nil
    ) async throws -> UserResponse {
        struct UpdateUserRequest: Encodable {
            let pseudo: String?
            let firstName: String?
            let lastName: String?
            let gender: String?
            let age: Int?
            let description: String?
            let hobbies: String?
            let lifeGoal: String?
            let avatarUrl: String?
        }

        let request = UpdateUserRequest(
            pseudo: pseudo,
            firstName: firstName,
            lastName: lastName,
            gender: gender,
            age: age,
            description: description,
            hobbies: hobbies,
            lifeGoal: lifeGoal,
            avatarUrl: avatarUrl
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

    func updateRoutine(id: String, title: String?, frequency: String?, icon: String?, scheduledTime: String? = nil, durationMinutes: Int? = nil) async throws -> RoutineResponse {
        struct UpdateRoutineRequest: Encodable {
            let title: String?
            let frequency: String?
            let icon: String?
            let scheduledTime: String?
            let durationMinutes: Int?
        }

        let request = UpdateRoutineRequest(title: title, frequency: frequency, icon: icon, scheduledTime: scheduledTime, durationMinutes: durationMinutes)

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
    let description: String?
    let hobbies: String?
    let lifeGoal: String?
    let avatarUrl: String?
    let dayVisibility: String?
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
    let focusSessions: Int
    let totalItems: Int
    let completedItems: Int
    let overallRate: Int
    let isValid: Bool
    // Requirements
    let requiredCompletionRate: Int
    let requiredFocusSessions: Int
    let requiredMinTasks: Int
    let meetsCompletionRate: Bool
    let meetsFocusSessions: Bool
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
