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
    @Published var isSearching = false

    // Leaderboard
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoadingLeaderboard = false

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

    var hasNewRequests: Bool {
        pendingRequestsCount > 0
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Data Loading

    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadLeaderboard() }
            group.addTask { await self.loadCrewMembers() }
            group.addTask { await self.loadReceivedRequests() }
        }
    }

    func loadCrewMembers() async {
        isLoadingMembers = true
        defer { isLoadingMembers = false }

        do {
            crewMembers = try await crewService.fetchCrewMembers()
        } catch {
            handleError(error, context: "loading crew members")
        }
    }

    func loadReceivedRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }

        do {
            receivedRequests = try await crewService.fetchReceivedRequests()
        } catch {
            handleError(error, context: "loading requests")
        }
    }

    func loadSentRequests() async {
        do {
            sentRequests = try await crewService.fetchSentRequests()
        } catch {
            handleError(error, context: "loading sent requests")
        }
    }

    func loadLeaderboard() async {
        isLoadingLeaderboard = true
        defer { isLoadingLeaderboard = false }

        do {
            leaderboard = try await crewService.fetchLeaderboard(limit: 50)
        } catch {
            handleError(error, context: "loading leaderboard")
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

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        print("❌ Crew error (\(context)): \(error.localizedDescription)")

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
    case leaderboard = "Leaderboard"
    case myCrew = "My Crew"
    case requests = "Requests"

    var icon: String {
        switch self {
        case .leaderboard: return "chart.bar.fill"
        case .myCrew: return "person.2.fill"
        case .requests: return "envelope.fill"
        }
    }
}
