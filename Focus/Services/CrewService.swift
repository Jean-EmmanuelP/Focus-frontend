import Foundation

// MARK: - Crew Response Models

/// Day visibility options
enum DayVisibility: String, Codable, CaseIterable {
    case publicVisibility = "public"
    case crewOnly = "crew"
    case privateVisibility = "private"

    var displayName: String {
        switch self {
        case .publicVisibility: return "Public"
        case .crewOnly: return "Crew Only"
        case .privateVisibility: return "Private"
        }
    }

    var description: String {
        switch self {
        case .publicVisibility: return "Anyone can see your day"
        case .crewOnly: return "Only crew members can see"
        case .privateVisibility: return "Nobody can see your day"
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
    let createdAt: Date?

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
        return "User"
    }
}

/// Leaderboard entry
struct LeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let id: String
    let pseudo: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let dayVisibility: String?
    let totalSessions7d: Int
    let totalMinutes7d: Int
    let completedRoutines7d: Int
    let activityScore: Int
    let lastActive: Date?
    let isCrewMember: Bool

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
        return "User"
    }

    var formattedFocusTime: String {
        let hours = totalMinutes7d / 60
        let minutes = totalMinutes7d % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

/// Crew member's day data
struct CrewMemberDayResponse: Codable {
    let user: CrewUserInfo
    let intentions: [CrewIntention]?
    let focusSessions: [CrewFocusSession]?
    let completedRoutines: [CrewCompletedRoutine]?
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
}
