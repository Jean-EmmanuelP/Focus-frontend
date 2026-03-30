import Foundation
import Combine
import SwiftUI

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var entries: [LeaderboardEntry] = []
    @Published var scope: LeaderboardScope = .global
    @Published var isLoading = false

    private let socialService = SocialService()

    var currentUserEntry: LeaderboardEntry? {
        guard let userId = FocusAppStore.shared.user?.id else { return nil }
        return entries.first { $0.id == userId }
    }

    var podiumEntries: [LeaderboardEntry] {
        Array(entries.prefix(3))
    }

    var remainingEntries: [LeaderboardEntry] {
        Array(entries.dropFirst(3))
    }

    func loadLeaderboard() async {
        isLoading = true
        do {
            entries = try await socialService.fetchLeaderboard(scope: scope)
        } catch {
            print("[Leaderboard] Error: \(error)")
        }
        isLoading = false
    }

    func switchScope(to newScope: LeaderboardScope) {
        guard newScope != scope else { return }
        scope = newScope
        Task { await loadLeaderboard() }
    }
}
