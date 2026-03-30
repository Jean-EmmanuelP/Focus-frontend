import Foundation
import Combine
import SwiftUI

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var searchResults: [Friend] = []
    @Published var suggestedUsers: [Friend] = []
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var sentRequestUserIds: Set<String> = []

    private let socialService = SocialService()
    private var searchTask: Task<Void, Never>?

    var hasPendingRequests: Bool {
        !pendingRequests.isEmpty
    }

    var hasSuggestions: Bool {
        !suggestedUsers.isEmpty
    }

    func loadData() async {
        isLoading = true

        async let friendsResult = socialService.fetchFriends()
        async let requestsResult = socialService.fetchFriendRequests()
        async let suggestionsResult = socialService.fetchSuggestedUsers()

        do {
            friends = try await friendsResult
            pendingRequests = try await requestsResult
            let suggestions = (try? await suggestionsResult) ?? []
            // Filter out users who are already friends
            let friendIds = Set(friends.map { $0.userId })
            suggestedUsers = suggestions.filter { !friendIds.contains($0.userId) }
        } catch {
            print("[Friends] Error loading: \(error)")
        }
        isLoading = false
    }

    func search() {
        searchTask?.cancel()
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            do {
                searchResults = try await socialService.searchUsers(query: searchQuery)
            } catch {
                print("[Friends] Search error: \(error)")
            }
            isSearching = false
        }
    }

    func sendRequest(to userId: String) async {
        do {
            try await socialService.sendFriendRequest(toUserId: userId)
            sentRequestUserIds.insert(userId)
            searchResults.removeAll { $0.userId == userId }
        } catch {
            print("[Friends] Send request error: \(error)")
        }
    }

    func hasAlreadySentRequest(to userId: String) -> Bool {
        sentRequestUserIds.contains(userId)
    }

    func acceptRequest(_ id: String) async {
        do {
            try await socialService.respondToRequest(id: id, accept: true)
            pendingRequests.removeAll { $0.id == id }
            if let updated = try? await socialService.fetchFriends() {
                friends = updated
            }
        } catch {
            print("[Friends] Accept error: \(error)")
        }
    }

    func declineRequest(_ id: String) async {
        do {
            try await socialService.respondToRequest(id: id, accept: false)
            pendingRequests.removeAll { $0.id == id }
        } catch {
            print("[Friends] Decline error: \(error)")
        }
    }

    func removeFriend(_ id: String) async {
        do {
            try await socialService.removeFriend(id: id)
            friends.removeAll { $0.id == id }
        } catch {
            print("[Friends] Remove error: \(error)")
        }
    }
}
