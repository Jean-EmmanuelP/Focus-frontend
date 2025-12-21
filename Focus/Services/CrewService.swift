import Foundation
import Combine

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
    let isSelf: Bool?

    // Live focus session data
    let isLive: Bool?
    let liveSessionStartedAt: String?  // ISO date when live session started
    let liveSessionDuration: Int?       // Total planned duration in minutes

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

    /// Calculate live elapsed time in seconds since session started
    var liveElapsedSeconds: Int? {
        guard let startedAt = liveSessionStartedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        if let startDate = formatter.date(from: startedAt) {
            return Int(Date().timeIntervalSince(startDate))
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let startDate = formatter.date(from: startedAt) {
            return Int(Date().timeIntervalSince(startDate))
        }

        return nil
    }

    /// Format live elapsed time as "Xm" or "Xh Ym"
    var formattedLiveTime: String? {
        guard let seconds = liveElapsedSeconds else { return nil }
        let minutes = seconds / 60
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }

    var safeRank: Int { rank ?? 0 }
    var safeActivityScore: Int { activityScore ?? 0 }
    var safeCurrentStreak: Int { currentStreak ?? 0 }
    var safeIsCrewMember: Bool { isCrewMember ?? false }
    var safeHasPendingRequest: Bool { hasPendingRequest ?? false }
    var safeIsSelf: Bool { isSelf ?? false }
    var safeIsLive: Bool { isLive ?? false }
}

/// Crew task (calendar task)
struct CrewTask: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let scheduledStart: String?
    let scheduledEnd: String?
    let timeBlock: String
    let priority: String
    let status: String
    let areaName: String?
    let areaIcon: String?
    let isPrivate: Bool?
}

/// Crew member's day data
struct CrewMemberDayResponse: Codable {
    let user: CrewUserInfo
    let intentions: [CrewIntention]?
    let focusSessions: [CrewFocusSession]?
    var completedRoutines: [CrewCompletedRoutine]?
    var routines: [CrewRoutine]?
    let tasks: [CrewTask]?
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

// MARK: - Crew Group Models

/// A custom group created by the user to organize their crew members
struct CrewGroup: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let icon: String
    let color: String
    let memberCount: Int
    let members: [CrewGroupMember]?
    let createdAt: Date
    let updatedAt: Date
}

/// A member within a crew group
struct CrewGroupMember: Codable, Identifiable {
    let id: String
    let memberId: String
    let pseudo: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let addedAt: Date?
    let isOwner: Bool?

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

    var safeIsOwner: Bool { isOwner ?? false }
}

/// DTO for creating a new crew group
struct CreateCrewGroupDTO: Encodable {
    let name: String
    let description: String?
    let icon: String?
    let color: String?
    let memberIds: [String]
}

/// DTO for updating an existing crew group
struct UpdateCrewGroupDTO: Encodable {
    let name: String?
    let description: String?
    let icon: String?
    let color: String?
}

/// DTO for adding members to a crew group
struct AddCrewGroupMembersDTO: Encodable {
    let memberIds: [String]
}

// MARK: - Group Routine Models (Shared Routines)

/// A routine shared with a group for accountability
struct GroupRoutine: Codable, Identifiable {
    let id: String
    let groupId: String
    let routineId: String
    let title: String
    let icon: String?
    let frequency: String
    let scheduledTime: String?
    let sharedBy: CrewUserInfo?
    let memberCompletions: [GroupRoutineMemberCompletion]?
    let completionCount: Int?
    let totalMembers: Int?
    let createdAt: Date

    var safeCompletionCount: Int { completionCount ?? 0 }
    var safeTotalMembers: Int { totalMembers ?? 0 }
    var safeCompletions: [GroupRoutineMemberCompletion] { memberCompletions ?? [] }
    // Note: APIClient uses .convertFromSnakeCase so no CodingKeys needed
}

/// Completion status for a group member on a shared routine
struct GroupRoutineMemberCompletion: Codable, Identifiable {
    let userId: String
    let pseudo: String?
    let firstName: String?
    let avatarUrl: String?
    let completed: Bool
    let completedAt: Date?

    var id: String { userId }

    var displayName: String {
        if let pseudo = pseudo, !pseudo.isEmpty { return pseudo }
        if let first = firstName, !first.isEmpty { return first }
        return "User"
    }
    // Note: APIClient uses .convertFromSnakeCase so no CodingKeys needed
}

/// Response wrapper for group routines list
struct GroupRoutinesResponse: Codable {
    let routines: [GroupRoutine]
}

/// DTO for sharing a routine with a group
struct ShareRoutineWithGroupDTO: Encodable {
    let routineId: String
}

// MARK: - Group Invitation Models

/// Brief info about a group (for invitations)
struct GroupInfoBrief: Codable {
    let id: String
    let name: String
    let icon: String?
    let color: String?
}

/// A group invitation
struct GroupInvitation: Codable, Identifiable {
    let id: String
    let groupId: String
    let fromUserId: String
    let toUserId: String
    let status: String
    let message: String?
    let createdAt: Date
    let updatedAt: Date?
    let fromUser: CrewUserInfo?
    let toUser: CrewUserInfo?
    let group: GroupInfoBrief?
}

/// DTO for inviting a user to a group
struct InviteToGroupDTO: Encodable {
    let toUserId: String
    let message: String?
}

// MARK: - Crew Service

@MainActor
class CrewService {
    private let apiClient = APIClient.shared

    // MARK: - Friends

    /// Fetch all friends (accepted connections)
    func fetchCrewMembers() async throws -> [CrewMemberResponse] {
        return try await apiClient.request(
            endpoint: .friends,
            method: .get
        )
    }

    /// Remove a friend
    func removeCrewMember(memberId: String) async throws {
        try await apiClient.request(
            endpoint: .removeFriend(memberId),
            method: .delete
        )
    }

    // MARK: - Friend Requests

    /// Fetch received friend requests (pending)
    func fetchReceivedRequests() async throws -> [CrewRequestResponse] {
        return try await apiClient.request(
            endpoint: .friendRequestsReceived,
            method: .get
        )
    }

    /// Fetch sent friend requests
    func fetchSentRequests() async throws -> [CrewRequestResponse] {
        return try await apiClient.request(
            endpoint: .friendRequestsSent,
            method: .get
        )
    }

    /// Send a friend request to another user
    func sendCrewRequest(toUserId: String, message: String? = nil) async throws -> CrewRequestResponse {
        struct SendRequestBody: Encodable {
            let toUserId: String
            let message: String?
        }

        let body = SendRequestBody(toUserId: toUserId, message: message)

        return try await apiClient.request(
            endpoint: .sendFriendRequest,
            method: .post,
            body: body
        )
    }

    /// Accept a received friend request
    func acceptCrewRequest(requestId: String) async throws {
        try await apiClient.request(
            endpoint: .acceptFriendRequest(requestId),
            method: .post
        )
    }

    /// Reject a received friend request
    func rejectCrewRequest(requestId: String) async throws {
        try await apiClient.request(
            endpoint: .rejectFriendRequest(requestId),
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
            endpoint: .friendsLeaderboard(limit: limit),
            method: .get
        )
    }

    // MARK: - Friend Day

    /// Fetch a friend's day data (if they allow visibility)
    func fetchCrewMemberDay(userId: String, date: Date) async throws -> CrewMemberDayResponse? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current // Use user's local timezone
        let dateString = dateFormatter.string(from: date)

        do {
            return try await apiClient.request(
                endpoint: .friendDay(userId: userId, date: dateString),
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

    // MARK: - Friend Groups

    /// Fetch all friend groups for the current user
    func fetchCrewGroups() async throws -> [CrewGroup] {
        return try await apiClient.request(
            endpoint: .friendGroups,
            method: .get
        )
    }

    /// Create a new friend group
    func createCrewGroup(name: String, description: String? = nil, icon: String? = nil, color: String? = nil, memberIds: [String]) async throws -> CrewGroup {
        let body = CreateCrewGroupDTO(
            name: name,
            description: description,
            icon: icon,
            color: color,
            memberIds: memberIds
        )
        return try await apiClient.request(
            endpoint: .createFriendGroup,
            method: .post,
            body: body
        )
    }

    /// Fetch a specific friend group by ID (includes full member list)
    func fetchCrewGroup(groupId: String) async throws -> CrewGroup {
        return try await apiClient.request(
            endpoint: .friendGroup(groupId),
            method: .get
        )
    }

    /// Update an existing friend group
    func updateCrewGroup(groupId: String, name: String? = nil, description: String? = nil, icon: String? = nil, color: String? = nil) async throws -> CrewGroup {
        let body = UpdateCrewGroupDTO(
            name: name,
            description: description,
            icon: icon,
            color: color
        )
        return try await apiClient.request(
            endpoint: .updateFriendGroup(groupId),
            method: .patch,
            body: body
        )
    }

    /// Delete a friend group
    func deleteCrewGroup(groupId: String) async throws {
        try await apiClient.request(
            endpoint: .deleteFriendGroup(groupId),
            method: .delete
        )
    }

    /// Add members to a friend group
    func addMembersToGroup(groupId: String, memberIds: [String]) async throws -> CrewGroup {
        let body = AddCrewGroupMembersDTO(memberIds: memberIds)
        return try await apiClient.request(
            endpoint: .addFriendGroupMembers(groupId),
            method: .post,
            body: body
        )
    }

    /// Remove a member from a friend group
    func removeMemberFromGroup(groupId: String, memberId: String) async throws {
        try await apiClient.request(
            endpoint: .removeFriendGroupMember(groupId: groupId, memberId: memberId),
            method: .delete
        )
    }

    /// Leave a group (removes yourself as a member)
    func leaveGroup(groupId: String) async throws {
        try await apiClient.request(
            endpoint: .leaveGroup(groupId),
            method: .post
        )
    }

    // MARK: - Group Routines (Shared Routines)

    /// Fetch routines shared with a group, including member completion status
    func fetchGroupRoutines(groupId: String, date: Date = Date()) async throws -> [GroupRoutine] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let response: GroupRoutinesResponse = try await apiClient.request(
            endpoint: .groupRoutines(groupId: groupId, date: dateString),
            method: .get
        )
        return response.routines
    }

    /// Share an existing routine with a group
    func shareRoutineWithGroup(groupId: String, routineId: String) async throws -> GroupRoutine {
        let body = ShareRoutineWithGroupDTO(routineId: routineId)
        return try await apiClient.request(
            endpoint: .shareRoutineWithGroup(groupId: groupId),
            method: .post,
            body: body
        )
    }

    /// Remove a routine from a group
    func removeRoutineFromGroup(groupId: String, groupRoutineId: String) async throws {
        try await apiClient.request(
            endpoint: .removeGroupRoutine(groupId: groupId, groupRoutineId: groupRoutineId),
            method: .delete
        )
    }

    // MARK: - Group Invitations

    /// Invite a user to join a group
    func inviteToGroup(groupId: String, userId: String, message: String? = nil) async throws -> GroupInvitation {
        let body = InviteToGroupDTO(toUserId: userId, message: message)
        return try await apiClient.request(
            endpoint: .inviteToGroup(groupId),
            method: .post,
            body: body
        )
    }

    /// Fetch received group invitations (pending)
    func fetchReceivedGroupInvitations() async throws -> [GroupInvitation] {
        return try await apiClient.request(
            endpoint: .groupInvitationsReceived,
            method: .get
        )
    }

    /// Fetch sent group invitations
    func fetchSentGroupInvitations() async throws -> [GroupInvitation] {
        return try await apiClient.request(
            endpoint: .groupInvitationsSent,
            method: .get
        )
    }

    /// Accept a group invitation
    func acceptGroupInvitation(invitationId: String) async throws {
        try await apiClient.request(
            endpoint: .acceptGroupInvitation(invitationId),
            method: .post
        )
    }

    /// Reject a group invitation
    func rejectGroupInvitation(invitationId: String) async throws {
        try await apiClient.request(
            endpoint: .rejectGroupInvitation(invitationId),
            method: .post
        )
    }

    /// Cancel a sent group invitation
    func cancelGroupInvitation(invitationId: String) async throws {
        try await apiClient.request(
            endpoint: .cancelGroupInvitation(invitationId),
            method: .delete
        )
    }
}
