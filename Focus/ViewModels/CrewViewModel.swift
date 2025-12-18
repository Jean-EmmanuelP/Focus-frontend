import Foundation
import SwiftUI
import Combine

@MainActor
class CrewViewModel: ObservableObject {
    // MARK: - Published Properties

    // Crew Members
    @Published var crewMembers: [CrewMemberResponse] = []
    @Published var isLoadingMembers = false

    // Requests
    @Published var receivedRequests: [CrewRequestResponse] = []
    @Published var sentRequests: [CrewRequestResponse] = []
    @Published var isLoadingRequests = false

    // Search
    @Published var searchQuery = ""
    @Published var searchResults: [SearchUserResult] = []
    @Published var suggestedUsers: [SearchUserResult] = []
    @Published var isSearching = false
    @Published var isLoadingSuggestions = false

    // Leaderboard
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoadingLeaderboard = false

    // Crew Groups
    @Published var crewGroups: [CrewGroup] = []
    @Published var isLoadingGroups = false
    @Published var showingCreateGroup = false
    @Published var showingGroupDetail = false
    @Published var selectedGroup: CrewGroup?
    @Published var selectedMembersForGroup: Set<String> = []

    // Group Invitations
    @Published var receivedGroupInvitations: [GroupInvitation] = []
    @Published var sentGroupInvitations: [GroupInvitation] = []
    @Published var isLoadingGroupInvitations = false
    @Published var showingInviteToGroup = false
    @Published var groupToInviteTo: CrewGroup?

    // Group Routines (shared routines)
    @Published var groupRoutines: [GroupRoutine] = []
    @Published var isLoadingGroupRoutines = false
    @Published var showingShareRoutine = false
    @Published var userRoutines: [RoutineResponse] = []  // User's own routines for sharing

    // Selected member's day
    @Published var selectedMember: CrewMemberResponse?
    @Published var selectedMemberDay: CrewMemberDayResponse?
    @Published var isLoadingMemberDay = false
    @Published var selectedDate = Date()

    // UI State
    @Published var activeTab: CrewTab = .leaderboard
    @Published var showingMemberDetail = false
    @Published var showingSettings = false
    @Published var showingSearch = false

    // Error handling
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Private Properties

    private let crewService = CrewService()
    private var searchTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var pendingRequestsCount: Int {
        receivedRequests.filter { $0.status == "pending" }.count
    }

    var pendingGroupInvitationsCount: Int {
        receivedGroupInvitations.filter { $0.status == "pending" }.count
    }

    var hasNewRequests: Bool {
        pendingRequestsCount > 0 || pendingGroupInvitationsCount > 0
    }

    var totalPendingCount: Int {
        pendingRequestsCount + pendingGroupInvitationsCount
    }

    var totalReceivedCount: Int {
        receivedRequests.count + receivedGroupInvitations.count
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Data Loading

    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadLeaderboard() }
            group.addTask { await self.loadCrewMembers() }
            group.addTask { await self.loadReceivedRequests() }
            group.addTask { await self.loadCrewGroups() }
            group.addTask { await self.loadReceivedGroupInvitations() }
        }
    }

    func loadCrewMembers() async {
        isLoadingMembers = true
        defer { isLoadingMembers = false }

        do {
            crewMembers = try await crewService.fetchCrewMembers()
        } catch {
            // Silent error - don't show alert for refresh failures
            handleError(error, context: "loading crew members", silent: true)
        }
    }

    func loadReceivedRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }

        do {
            receivedRequests = try await crewService.fetchReceivedRequests()
        } catch {
            // Silent error - don't show alert for refresh failures
            handleError(error, context: "loading requests", silent: true)
        }
    }

    func loadSentRequests() async {
        do {
            sentRequests = try await crewService.fetchSentRequests()
        } catch {
            // Silent error - don't show alert for refresh failures
            handleError(error, context: "loading sent requests", silent: true)
        }
    }

    func loadLeaderboard() async {
        isLoadingLeaderboard = true
        defer { isLoadingLeaderboard = false }

        do {
            leaderboard = try await crewService.fetchLeaderboard(limit: 50)
        } catch {
            // Silent error - don't show alert for refresh failures
            handleError(error, context: "loading leaderboard", silent: true)
        }
    }

    func loadSuggestedUsers() async {
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }

        do {
            suggestedUsers = try await crewService.fetchSuggestedUsers(limit: 10)
        } catch {
            // Silently fail - suggestions are optional
            print("⚠️ Could not load suggestions: \(error.localizedDescription)")
            suggestedUsers = []
        }
    }

    // MARK: - Search

    func searchUsers() {
        // Cancel previous search task
        searchTask?.cancel()

        let query = searchQuery.trimmingCharacters(in: .whitespaces)

        if query.isEmpty {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled else { return }

            isSearching = true
            defer { isSearching = false }

            do {
                let results = try await crewService.searchUsers(query: query, limit: 20)
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    handleError(error, context: "searching users")
                }
            }
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchTask?.cancel()
    }

    // MARK: - Crew Requests

    func sendRequest(to userId: String, message: String? = nil) async -> Bool {
        do {
            _ = try await crewService.sendCrewRequest(toUserId: userId, message: message)

            // Refresh search results to update request status
            if !searchQuery.isEmpty {
                searchUsers()
            }

            // Refresh sent requests
            await loadSentRequests()

            return true
        } catch {
            handleError(error, context: "sending request")
            return false
        }
    }

    func acceptRequest(_ request: CrewRequestResponse) async -> Bool {
        do {
            try await crewService.acceptCrewRequest(requestId: request.id)

            // Remove from pending and refresh crew members
            receivedRequests.removeAll { $0.id == request.id }
            await loadCrewMembers()
            await loadLeaderboard()

            return true
        } catch {
            handleError(error, context: "accepting request")
            return false
        }
    }

    func rejectRequest(_ request: CrewRequestResponse) async -> Bool {
        do {
            try await crewService.rejectCrewRequest(requestId: request.id)

            // Remove from pending
            receivedRequests.removeAll { $0.id == request.id }

            return true
        } catch {
            handleError(error, context: "rejecting request")
            return false
        }
    }

    // MARK: - Crew Member Management

    func removeMember(_ member: CrewMemberResponse) async -> Bool {
        do {
            try await crewService.removeCrewMember(memberId: member.memberId)

            // Remove from local list
            crewMembers.removeAll { $0.memberId == member.memberId }

            // Refresh leaderboard to update crew status
            await loadLeaderboard()

            return true
        } catch {
            handleError(error, context: "removing member")
            return false
        }
    }

    // MARK: - View Member Day

    func selectMember(_ member: CrewMemberResponse) {
        selectedMember = member
        selectedDate = Date()
        showingMemberDetail = true
        Task {
            await loadMemberDay()
        }
    }

    func loadMemberDay() async {
        guard let member = selectedMember else { return }

        isLoadingMemberDay = true
        defer { isLoadingMemberDay = false }

        do {
            selectedMemberDay = try await crewService.fetchCrewMemberDay(
                userId: member.memberId,
                date: selectedDate
            )
        } catch {
            handleError(error, context: "loading member's day")
            selectedMemberDay = nil
        }
    }

    func changeSelectedDate(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }

        // Don't allow future dates
        if newDate > Date() {
            return
        }

        selectedDate = newDate
        Task {
            await loadMemberDay()
        }
    }

    func closeMemberDetail() {
        showingMemberDetail = false
        selectedMember = nil
        selectedMemberDay = nil
    }

    // MARK: - Routine Likes

    /// Toggle like on a completed routine
    func toggleRoutineLike(completionId: String, isCurrentlyLiked: Bool) async {
        do {
            if isCurrentlyLiked {
                try await crewService.unlikeRoutineCompletion(completionId: completionId)
            } else {
                try await crewService.likeRoutineCompletion(completionId: completionId)
            }

            // Update local state optimistically
            if var dayData = selectedMemberDay {
                // Update in completedRoutines
                if let index = dayData.completedRoutines?.firstIndex(where: { $0.id == completionId }) {
                    let currentLiked = dayData.completedRoutines?[index].isLikedByMe ?? false
                    let currentCount = dayData.completedRoutines?[index].likeCount ?? 0
                    dayData.completedRoutines?[index].isLikedByMe = !currentLiked
                    dayData.completedRoutines?[index].likeCount = currentLiked ? max(0, currentCount - 1) : currentCount + 1
                }

                // Update in allRoutines
                if let index = dayData.routines?.firstIndex(where: { $0.id == completionId }) {
                    let currentLiked = dayData.routines?[index].isLikedByMe ?? false
                    let currentCount = dayData.routines?[index].likeCount ?? 0
                    dayData.routines?[index].isLikedByMe = !currentLiked
                    dayData.routines?[index].likeCount = currentLiked ? max(0, currentCount - 1) : currentCount + 1
                }

                selectedMemberDay = dayData
            }
        } catch {
            handleError(error, context: "toggling like")
        }
    }

    // MARK: - Visibility

    func updateVisibility(_ visibility: DayVisibility) async throws {
        try await crewService.updateDayVisibility(visibility)
    }

    // MARK: - Crew Groups

    func loadCrewGroups() async {
        isLoadingGroups = true
        defer { isLoadingGroups = false }

        do {
            crewGroups = try await crewService.fetchCrewGroups()
        } catch {
            handleError(error, context: "loading groups", silent: true)
        }
    }

    func createGroup(name: String, description: String? = nil, icon: String? = nil, color: String? = nil) async -> Bool {
        let memberIds = Array(selectedMembersForGroup)
        guard !memberIds.isEmpty else {
            errorMessage = "crew.groups.select_members".localized
            showError = true
            return false
        }

        do {
            let newGroup = try await crewService.createCrewGroup(
                name: name,
                description: description,
                icon: icon,
                color: color,
                memberIds: memberIds
            )
            crewGroups.insert(newGroup, at: 0)
            selectedMembersForGroup.removeAll()
            return true
        } catch {
            handleError(error, context: "creating group")
            return false
        }
    }

    func selectGroup(_ group: CrewGroup) {
        Task {
            do {
                let fullGroup = try await crewService.fetchCrewGroup(groupId: group.id)
                selectedGroup = fullGroup
                showingGroupDetail = true
            } catch {
                handleError(error, context: "loading group details")
            }
        }
    }

    func updateGroup(groupId: String, name: String? = nil, description: String? = nil, icon: String? = nil, color: String? = nil) async -> Bool {
        do {
            let updatedGroup = try await crewService.updateCrewGroup(
                groupId: groupId,
                name: name,
                description: description,
                icon: icon,
                color: color
            )
            if let index = crewGroups.firstIndex(where: { $0.id == groupId }) {
                crewGroups[index] = updatedGroup
            }
            selectedGroup = updatedGroup
            return true
        } catch {
            handleError(error, context: "updating group")
            return false
        }
    }

    func deleteGroup(_ group: CrewGroup) async -> Bool {
        do {
            try await crewService.deleteCrewGroup(groupId: group.id)
            crewGroups.removeAll { $0.id == group.id }
            if selectedGroup?.id == group.id {
                selectedGroup = nil
                showingGroupDetail = false
            }
            return true
        } catch {
            handleError(error, context: "deleting group")
            return false
        }
    }

    func addMembersToGroup(groupId: String, memberIds: [String]) async -> Bool {
        do {
            let updatedGroup = try await crewService.addMembersToGroup(groupId: groupId, memberIds: memberIds)
            if let index = crewGroups.firstIndex(where: { $0.id == groupId }) {
                crewGroups[index] = updatedGroup
            }
            selectedGroup = updatedGroup
            return true
        } catch {
            handleError(error, context: "adding members to group")
            return false
        }
    }

    func removeMemberFromGroup(groupId: String, memberId: String) async -> Bool {
        do {
            try await crewService.removeMemberFromGroup(groupId: groupId, memberId: memberId)
            // Update local state
            if let group = selectedGroup, group.id == groupId {
                var updatedMembers = group.members ?? []
                updatedMembers.removeAll { $0.memberId == memberId }
                // Re-fetch to get updated member count
                let updatedGroup = try await crewService.fetchCrewGroup(groupId: groupId)
                selectedGroup = updatedGroup
                if let index = crewGroups.firstIndex(where: { $0.id == groupId }) {
                    crewGroups[index] = updatedGroup
                }
            }
            return true
        } catch {
            handleError(error, context: "removing member from group")
            return false
        }
    }

    func toggleMemberSelection(_ memberId: String) {
        if selectedMembersForGroup.contains(memberId) {
            selectedMembersForGroup.remove(memberId)
        } else {
            selectedMembersForGroup.insert(memberId)
        }
    }

    func closeGroupDetail() {
        showingGroupDetail = false
        selectedGroup = nil
    }

    func leaveGroup(_ group: CrewGroup) async -> Bool {
        do {
            try await crewService.leaveGroup(groupId: group.id)
            crewGroups.removeAll { $0.id == group.id }
            if selectedGroup?.id == group.id {
                selectedGroup = nil
                showingGroupDetail = false
            }
            return true
        } catch {
            handleError(error, context: "leaving group")
            return false
        }
    }

    // MARK: - Group Invitations

    func loadReceivedGroupInvitations() async {
        isLoadingGroupInvitations = true
        defer { isLoadingGroupInvitations = false }

        do {
            receivedGroupInvitations = try await crewService.fetchReceivedGroupInvitations()
        } catch {
            handleError(error, context: "loading group invitations", silent: true)
        }
    }

    func loadSentGroupInvitations() async {
        do {
            sentGroupInvitations = try await crewService.fetchSentGroupInvitations()
        } catch {
            handleError(error, context: "loading sent group invitations", silent: true)
        }
    }

    func inviteToGroup(groupId: String, userId: String, message: String? = nil) async -> Bool {
        do {
            _ = try await crewService.inviteToGroup(groupId: groupId, userId: userId, message: message)
            await loadSentGroupInvitations()
            return true
        } catch {
            handleError(error, context: "inviting to group")
            return false
        }
    }

    func acceptGroupInvitation(_ invitation: GroupInvitation) async -> Bool {
        do {
            try await crewService.acceptGroupInvitation(invitationId: invitation.id)
            receivedGroupInvitations.removeAll { $0.id == invitation.id }
            await loadCrewGroups() // Refresh groups to include the newly joined one
            return true
        } catch {
            handleError(error, context: "accepting group invitation")
            return false
        }
    }

    func rejectGroupInvitation(_ invitation: GroupInvitation) async -> Bool {
        do {
            try await crewService.rejectGroupInvitation(invitationId: invitation.id)
            receivedGroupInvitations.removeAll { $0.id == invitation.id }
            return true
        } catch {
            handleError(error, context: "rejecting group invitation")
            return false
        }
    }

    func cancelGroupInvitation(_ invitation: GroupInvitation) async -> Bool {
        do {
            try await crewService.cancelGroupInvitation(invitationId: invitation.id)
            sentGroupInvitations.removeAll { $0.id == invitation.id }
            return true
        } catch {
            handleError(error, context: "canceling group invitation")
            return false
        }
    }

    func startInviteToGroup(_ group: CrewGroup) {
        groupToInviteTo = group
        showingInviteToGroup = true
    }

    func closeInviteToGroup() {
        showingInviteToGroup = false
        groupToInviteTo = nil
    }

    // MARK: - Group Routines (Shared Routines)

    func loadGroupRoutines(groupId: String) async {
        isLoadingGroupRoutines = true
        defer { isLoadingGroupRoutines = false }

        do {
            groupRoutines = try await crewService.fetchGroupRoutines(groupId: groupId)
        } catch {
            handleError(error, context: "loading group routines", silent: true)
        }
    }

    func loadUserRoutinesForSharing() async {
        do {
            let routineService = RoutineService()
            userRoutines = try await routineService.fetchRoutines()
        } catch {
            handleError(error, context: "loading routines", silent: true)
        }
    }

    func shareRoutineWithGroup(groupId: String, routineId: String) async -> Bool {
        do {
            let newRoutine = try await crewService.shareRoutineWithGroup(groupId: groupId, routineId: routineId)
            groupRoutines.append(newRoutine)
            return true
        } catch {
            handleError(error, context: "sharing routine with group")
            return false
        }
    }

    func removeRoutineFromGroup(groupId: String, groupRoutineId: String) async -> Bool {
        do {
            try await crewService.removeRoutineFromGroup(groupId: groupId, groupRoutineId: groupRoutineId)
            groupRoutines.removeAll { $0.id == groupRoutineId }
            return true
        } catch {
            handleError(error, context: "removing routine from group")
            return false
        }
    }

    func startShareRoutine() {
        showingShareRoutine = true
        Task {
            await loadUserRoutinesForSharing()
        }
    }

    func closeShareRoutine() {
        showingShareRoutine = false
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String, silent: Bool = false) {
        // Ignore cancelled requests (happens when navigating away quickly)
        let errorString = error.localizedDescription.lowercased()
        let isCancelled = (error as? URLError)?.code == .cancelled || errorString.contains("cancel") || errorString.contains("annul")

        if isCancelled {
            return // Silently ignore cancelled requests
        }

        print("❌ Crew error (\(context)): \(error.localizedDescription)")

        // Don't show error alert for silent errors (like refresh failures)
        guard !silent else { return }

        if let apiError = error as? APIError {
            errorMessage = apiError.errorDescription
        } else {
            errorMessage = "Failed \(context): \(error.localizedDescription)"
        }

        showError = true
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }
}

// MARK: - Tab Enum

enum CrewTab: String, CaseIterable {
    case leaderboard
    case myCrew
    case groups
    case requests

    var displayName: String {
        switch self {
        case .leaderboard: return "crew.leaderboard".localized
        case .myCrew: return "crew.my_crew".localized
        case .groups: return "crew.groups".localized
        case .requests: return "crew.requests".localized
        }
    }

    var icon: String {
        switch self {
        case .leaderboard: return "chart.bar.fill"
        case .myCrew: return "person.2.fill"
        case .groups: return "person.3.fill"
        case .requests: return "envelope.fill"
        }
    }
}
