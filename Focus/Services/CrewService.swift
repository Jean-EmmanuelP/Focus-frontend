import Foundation

// MARK: - Crew Response Models

/// Day visibility options
enum DayVisibility: String, Codable, CaseIterable {
    case publicVisibility = "public"
    case crewOnly = "crew"
    case privateVisibility = "private"

    var displayName: String {
        switch self {
        case .publicVisibility: return "visibility.public".localized
        case .crewOnly: return "visibility.crew".localized
        case .privateVisibility: return "visibility.private".localized
        }
    }

    var description: String {
        switch self {
        case .publicVisibility: return "visibility.public_desc".localized
        case .crewOnly: return "visibility.crew_desc".localized
        case .privateVisibility: return "visibility.private_desc".localized
        }
    }

    var icon: String {
        switch self {
        case .publicVisibility: return "globe"
        case .crewOnly: return "person.2"
        case .privateVisibility: return "lock"
        }
    }
}

/// Crew request status
enum CrewRequestStatus: String, Codable {
    case pending
    case accepted
    case rejected
}

/// Crew member response
struct CrewMemberResponse: Codable, Identifiable {
    let id: String
    let memberId: String
    let pseudo: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let dayVisibility: String?
    let totalSessions7d: Int?
    let totalMinutes7d: Int?
    let activityScore: Int?
    let createdAt: String?
    let email: String?

    var displayName: String {
        if let pseudo = pseudo, !pseudo.isEmpty {
            return pseudo
        }
        if let first = firstName, !first.isEmpty {
            if let last = lastName, !last.isEmpty {
                return "\(first) \(last)"
            }
            return first
        }
        // Fallback to email username
        if let email = email, let atIndex = email.firstIndex(of: "@") {
            return String(email[..<atIndex])
        }
        return "User"
    }
}

/// Crew request response
struct CrewRequestResponse: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let status: String
    let message: String?
    let createdAt: Date
    let updatedAt: Date?

    // User info (populated for incoming/outgoing requests)
    let fromUser: CrewUserInfo?
    let toUser: CrewUserInfo?
}

/// Minimal user info for crew requests
struct CrewUserInfo: Codable {
    let id: String
    let pseudo: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let email: String?

    var displayName: String {
        if let pseudo = pseudo, !pseudo.isEmpty {
            return pseudo
        }
        if let first = firstName, !first.isEmpty {
            if let last = lastName, !last.isEmpty {
                return "\(first) \(last)"
            }
            return first
        }
        // Fallback to email username
        if let email = email, let atIndex = email.firstIndex(of: "@") {
            return String(email[..<atIndex])
        }
        return "User"
    }
}

/// Search user result
struct SearchUserResult: Codable, Identifiable {
    let id: String
    let pseudo: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let dayVisibility: String?
    let totalSessions7d: Int?
    let totalMinutes7d: Int?
    let activityScore: Int?
    let isCrewMember: Bool
    let hasPendingRequest: Bool
    let requestDirection: String?  // "outgoing" or "incoming"
    let email: String?

    var displayName: String {
        if let pseudo = pseudo, !pseudo.isEmpty {
            return pseudo
        }
        if let first = firstName, !first.isEmpty {
            if let last = lastName, !last.isEmpty {
                return "\(first) \(last)"
            }
            return first
        }
        // Fallback to email username
        if let email = email, let atIndex = email.firstIndex(of: "@") {
            return String(email[..<atIndex])
        }
        return "User"
    }
}

/// Leaderboard entry
struct LeaderboardEntry: Codable, Identifiable {
    let rank: Int?
    let id: String
    let pseudo: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let dayVisibility: String?
    let totalSessions7d: Int?
    let totalMinutes7d: Int?
    let completedRoutines7d: Int?
    let activityScore: Int?
    let currentStreak: Int?
    let lastActive: String?
    let isCrewMember: Bool?
    let hasPendingRequest: Bool?
    let requestDirection: String?  // "outgoing" or "incoming"
    let email: String?

    var displayName: String {
        if let pseudo = pseudo, !pseudo.isEmpty {
            return pseudo
        }
        if let first = firstName, !first.isEmpty {
            if let last = lastName, !last.isEmpty {
                return "\(first) \(last)"
            }
            return first
        }
        // Fallback to email username
        if let email = email, let atIndex = email.firstIndex(of: "@") {
            return String(email[..<atIndex])
        }
        return "User"
    }

    var formattedFocusTime: String {
        let minutes = totalMinutes7d ?? 0
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var safeRank: Int { rank ?? 0 }
    var safeActivityScore: Int { activityScore ?? 0 }
    var safeCurrentStreak: Int { currentStreak ?? 0 }
    var safeIsCrewMember: Bool { isCrewMember ?? false }
    var safeHasPendingRequest: Bool { hasPendingRequest ?? false }
}

/// Crew member's day data
struct CrewMemberDayResponse: Codable {
    let user: CrewUserInfo
    let intentions: [CrewIntention]?
    let focusSessions: [CrewFocusSession]?
    var completedRoutines: [CrewCompletedRoutine]?
    var routines: [CrewRoutine]?
    let stats: CrewMemberStats?
}

/// Stats for a crew member
struct CrewMemberStats: Codable {
    let weeklyFocusMinutes: [DailyStat]?
    let weeklyRoutinesDone: [DailyStat]?
    let weeklyTotalFocus: Int?
    let weeklyTotalRoutines: Int?
    let weeklyAvgFocus: Int?
    let weeklyRoutineRate: Int?

    let monthlyFocusMinutes: [DailyStat]?
    let monthlyRoutinesDone: [DailyStat]?
    let monthlyTotalFocus: Int?
    let monthlyTotalRoutines: Int?
}

struct DailyStat: Codable, Identifiable {
    let date: String
    let value: Int

    var id: String { date }
}

/// Personal stats response (includes total routines count)
struct MyStatsResponse: Codable {
    let weeklyFocusMinutes: [DailyStat]?
    let weeklyRoutinesDone: [DailyStat]?
    let weeklyTotalFocus: Int?
    let weeklyTotalRoutines: Int?
    let weeklyAvgFocus: Int?
    let weeklyRoutineRate: Int?
    let monthlyFocusMinutes: [DailyStat]?
    let monthlyRoutinesDone: [DailyStat]?
    let monthlyTotalFocus: Int?
    let monthlyTotalRoutines: Int?
    let totalRoutines: Int?
}

struct CrewIntention: Codable, Identifiable {
    let id: String
    let content: String
    let position: Int
}

struct CrewFocusSession: Codable, Identifiable {
    let id: String
    let description: String?
    let durationMinutes: Int
    let startedAt: Date
    let completedAt: Date?
    let status: String

    var formattedDuration: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct CrewCompletedRoutine: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String?
    let completedAt: Date
    var likeCount: Int?
    var isLikedByMe: Bool?
}

struct CrewRoutine: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String?
    let completed: Bool
    let completedAt: Date?
    var likeCount: Int?
    var isLikedByMe: Bool?
}

// MARK: - Crew Service

@MainActor
class CrewService {
    private let apiClient = APIClient.shared

    // MARK: - Crew Members

    /// Fetch all crew members (accepted connections)
    func fetchCrewMembers() async throws -> [CrewMemberResponse] {
        return try await apiClient.request(
            endpoint: .crewMembers,
            method: .get
        )
    }

    /// Remove a crew member
    func removeCrewMember(memberId: String) async throws {
        try await apiClient.request(
            endpoint: .removeCrewMember(memberId),
            method: .delete
        )
    }

    // MARK: - Crew Requests

    /// Fetch received crew requests (pending)
    func fetchReceivedRequests() async throws -> [CrewRequestResponse] {
        return try await apiClient.request(
            endpoint: .crewRequestsReceived,
            method: .get
        )
    }

    /// Fetch sent crew requests
    func fetchSentRequests() async throws -> [CrewRequestResponse] {
        return try await apiClient.request(
            endpoint: .crewRequestsSent,
            method: .get
        )
    }

    /// Send a crew request to another user
    func sendCrewRequest(toUserId: String, message: String? = nil) async throws -> CrewRequestResponse {
        struct SendRequestBody: Encodable {
            let toUserId: String
            let message: String?
        }

        let body = SendRequestBody(toUserId: toUserId, message: message)

        return try await apiClient.request(
            endpoint: .sendCrewRequest,
            method: .post,
            body: body
        )
    }

    /// Accept a received crew request
    func acceptCrewRequest(requestId: String) async throws {
        try await apiClient.request(
            endpoint: .acceptCrewRequest(requestId),
            method: .post
        )
    }

    /// Reject a received crew request
    func rejectCrewRequest(requestId: String) async throws {
        try await apiClient.request(
            endpoint: .rejectCrewRequest(requestId),
            method: .post
        )
    }

    // MARK: - Search & Discovery

    /// Search for users by name or pseudo
    func searchUsers(query: String, limit: Int? = 20) async throws -> [SearchUserResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }

        return try await apiClient.request(
            endpoint: .searchUsers(query: query, limit: limit),
            method: .get
        )
    }

    /// Fetch leaderboard of most active users
    func fetchLeaderboard(limit: Int? = 50) async throws -> [LeaderboardEntry] {
        return try await apiClient.request(
            endpoint: .leaderboard(limit: limit),
            method: .get
        )
    }

    // MARK: - Crew Member Day

    /// Fetch a crew member's day data (if they allow visibility)
    func fetchCrewMemberDay(userId: String, date: Date) async throws -> CrewMemberDayResponse? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current // Use user's local timezone
        let dateString = dateFormatter.string(from: date)

        do {
            return try await apiClient.request(
                endpoint: .crewMemberDay(userId: userId, date: dateString),
                method: .get
            )
        } catch APIError.notFound {
            return nil
        }
    }

    // MARK: - Day Visibility

    /// Update the current user's day visibility setting
    func updateDayVisibility(_ visibility: DayVisibility) async throws {
        struct UpdateVisibilityBody: Encodable {
            let dayVisibility: String
        }

        let body = UpdateVisibilityBody(dayVisibility: visibility.rawValue)

        try await apiClient.request(
            endpoint: .updateDayVisibility,
            method: .patch,
            body: body
        )
    }

    // MARK: - My Stats

    /// Fetch my own stats (weekly and monthly)
    func fetchMyStats() async throws -> MyStatsResponse {
        return try await apiClient.request(
            endpoint: .myStats,
            method: .get
        )
    }

    // MARK: - Routine Likes

    /// Like a crew member's completed routine
    func likeRoutineCompletion(completionId: String) async throws {
        try await apiClient.request(
            endpoint: .likeRoutineCompletion(completionId: completionId),
            method: .post
        )
    }

    /// Unlike a crew member's completed routine
    func unlikeRoutineCompletion(completionId: String) async throws {
        try await apiClient.request(
            endpoint: .unlikeRoutineCompletion(completionId: completionId),
            method: .delete
        )
    }

    // MARK: - User Suggestions

    /// Fetch suggested users to add to crew
    func fetchSuggestedUsers(limit: Int? = 10) async throws -> [SearchUserResult] {
        return try await apiClient.request(
            endpoint: .suggestedUsers(limit: limit),
            method: .get
        )
    }
}
