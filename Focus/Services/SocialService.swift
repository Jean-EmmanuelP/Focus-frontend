import Foundation
import CoreLocation

@MainActor
class SocialService {
    private let apiClient = APIClient.shared
    private let discoverService = DiscoverService()

    // MARK: - Friends (backend not ready yet — returns empty)

    func fetchFriends() async throws -> [Friend] {
        // TODO: Uncomment when backend /friends endpoint is ready
        // return try await apiClient.request(endpoint: .friends, method: .get)
        return []
    }

    func fetchFriendRequests() async throws -> [FriendRequest] {
        // TODO: Uncomment when backend /friends/requests endpoint is ready
        // return try await apiClient.request(endpoint: .friendRequests, method: .get)
        return []
    }

    func sendFriendRequest(toUserId: String) async throws {
        // TODO: Uncomment when backend is ready
        // try await apiClient.request(endpoint: .sendFriendRequest(userId: toUserId), method: .post)
        print("[Social] Friend request sent to \(toUserId)")
    }

    func respondToRequest(id: String, accept: Bool) async throws {
        // TODO: Uncomment when backend is ready
        // try await apiClient.request(endpoint: .respondFriendRequest(id: id), method: .patch, body: ["accept": accept])
        print("[Social] Request \(id) \(accept ? "accepted" : "declined")")
    }

    func removeFriend(id: String) async throws {
        // TODO: Uncomment when backend is ready
        // try await apiClient.request(endpoint: .removeFriend(id: id), method: .delete)
        print("[Social] Friend \(id) removed")
    }

    func searchUsers(query: String) async throws -> [Friend] {
        // TODO: Uncomment when backend /users/search endpoint is ready
        // return try await apiClient.request(endpoint: .searchUsers(query: query), method: .get)
        guard !query.isEmpty else { return [] }

        // For now, search among nearby users (real data from discover API)
        let suggestions = try await fetchSuggestedUsers()
        return suggestions.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    /// Fetches nearby real users as friend suggestions using the discover API.
    func fetchSuggestedUsers() async throws -> [Friend] {
        let locationService = LocationService.shared

        // Wait for location if not yet available (same pattern as DiscoverMapViewModel)
        if locationService.currentLocation == nil {
            locationService.startUpdating()
            // Wait up to 3s for location
            for _ in 0..<6 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if locationService.currentLocation != nil { break }
            }
        }

        guard let location = locationService.currentLocation else { return [] }

        let currentUserId = FocusAppStore.shared.user?.id

        let nearbyUsers = try await discoverService.fetchNearbyUsers(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            radiusKm: 500
        )

        // Convert NearbyUser → Friend, excluding current user
        return nearbyUsers
            .filter { $0.id != currentUserId }
            .map { user in
                let score = computeProductivityScore(
                    totalFocusMinutes: user.totalMinutesToday,
                    currentStreak: user.currentStreak ?? 0,
                    isInFocusSession: user.isInFocusSession
                )
                return Friend(
                    id: "suggest_\(user.id)",
                    userId: user.id,
                    pseudo: user.pseudo,
                    firstName: user.firstName,
                    avatarUrl: user.avatarUrl,
                    currentStreak: user.currentStreak,
                    productivityScore: score
                )
            }
    }

    // MARK: - Leaderboard (uses REAL data from /discover/users)

    /// Builds a real leaderboard from nearby users + current user stats.
    /// Score formula: 60% streak consistency + 40% daily focus volume, normalized to 0-100.
    func fetchLeaderboard(scope: LeaderboardScope) async throws -> [LeaderboardEntry] {
        switch scope {
        case .global:
            return try await buildGlobalLeaderboard()
        case .friends:
            // Friends leaderboard needs backend — show empty for now
            return []
        }
    }

    // MARK: - Real Leaderboard Builder

    private func buildGlobalLeaderboard() async throws -> [LeaderboardEntry] {
        let store = FocusAppStore.shared
        let locationService = LocationService.shared

        // 1. Get user location for discover API
        guard let location = locationService.currentLocation else {
            // No location — return just the current user
            return buildCurrentUserOnly(store: store)
        }

        // 2. Fetch real nearby users from backend (radius 500km for wider leaderboard)
        let nearbyUsers = try await discoverService.fetchNearbyUsers(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            radiusKm: 500
        )

        // 3. Convert nearby users to leaderboard entries with computed scores
        var entries: [LeaderboardEntry] = nearbyUsers.map { user in
            let score = computeProductivityScore(
                totalFocusMinutes: user.totalMinutesToday,
                currentStreak: user.currentStreak ?? 0,
                isInFocusSession: user.isInFocusSession
            )
            return LeaderboardEntry(
                id: user.id,
                pseudo: user.pseudo,
                firstName: user.firstName,
                avatarUrl: user.avatarUrl,
                productivityScore: score,
                tasksCompleted: 0,  // Not available from discover API
                tasksCreated: 0,
                completionRate: 0,
                totalFocusMinutes: user.totalMinutesToday,
                currentStreak: user.currentStreak ?? 0,
                rank: 0,  // Will be set after sorting
                isFriend: false
            )
        }

        // 4. Add current user with their real stats
        if let user = store.user {
            let todayMinutes = store.todayMinutes
            let streak = store.currentStreak
            let todaysTasks = store.todaysTasks
            let completedTasks = todaysTasks.filter { $0.isCompleted }.count
            let totalTasks = todaysTasks.count
            let rituals = store.rituals
            let completedRituals = rituals.filter { $0.isCompleted }.count
            let totalRituals = rituals.count

            // Combined task completion (tasks + rituals)
            let totalItems = totalTasks + totalRituals
            let completedItems = completedTasks + completedRituals
            let completionRate = totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0

            let score = computeProductivityScore(
                totalFocusMinutes: todayMinutes,
                currentStreak: streak,
                isInFocusSession: todayMinutes > 0,
                completionRate: completionRate
            )

            // Remove duplicate if current user is already in nearby list
            entries.removeAll { $0.id == user.id }

            entries.append(LeaderboardEntry(
                id: user.id,
                pseudo: user.pseudo,
                firstName: user.firstName,
                avatarUrl: user.avatarURL,
                productivityScore: score,
                tasksCompleted: completedItems,
                tasksCreated: totalItems,
                completionRate: completionRate,
                totalFocusMinutes: todayMinutes,
                currentStreak: streak,
                rank: 0,
                isFriend: false
            ))
        }

        // 5. Sort by score descending and assign ranks
        entries.sort { $0.productivityScore > $1.productivityScore }
        entries = entries.enumerated().map { index, entry in
            LeaderboardEntry(
                id: entry.id,
                pseudo: entry.pseudo,
                firstName: entry.firstName,
                avatarUrl: entry.avatarUrl,
                productivityScore: entry.productivityScore,
                tasksCompleted: entry.tasksCompleted,
                tasksCreated: entry.tasksCreated,
                completionRate: entry.completionRate,
                totalFocusMinutes: entry.totalFocusMinutes,
                currentStreak: entry.currentStreak,
                rank: index + 1,
                isFriend: entry.isFriend
            )
        }

        return entries
    }

    private func buildCurrentUserOnly(store: FocusAppStore) -> [LeaderboardEntry] {
        guard let user = store.user else { return [] }

        let todayMinutes = store.todayMinutes
        let streak = store.currentStreak
        let todaysTasks = store.todaysTasks
        let completedTasks = todaysTasks.filter { $0.isCompleted }.count
        let totalTasks = todaysTasks.count
        let rituals = store.rituals
        let completedRituals = rituals.filter { $0.isCompleted }.count
        let totalRituals = rituals.count
        let totalItems = totalTasks + totalRituals
        let completedItems = completedTasks + completedRituals
        let completionRate = totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0

        let score = computeProductivityScore(
            totalFocusMinutes: todayMinutes,
            currentStreak: streak,
            isInFocusSession: todayMinutes > 0,
            completionRate: completionRate
        )

        return [LeaderboardEntry(
            id: user.id,
            pseudo: user.pseudo,
            firstName: user.firstName,
            avatarUrl: user.avatarURL,
            productivityScore: score,
            tasksCompleted: completedItems,
            tasksCreated: totalItems,
            completionRate: completionRate,
            totalFocusMinutes: todayMinutes,
            currentStreak: streak,
            rank: 1,
            isFriend: false
        )]
    }

    // MARK: - Productivity Score Formula

    /// Computes a 0-100 score based on:
    /// - Streak consistency (40%): longer streak = higher score, capped at 30 days
    /// - Focus volume today (30%): minutes focused today, capped at 120 min
    /// - Task completion rate (20%): ratio of completed tasks/rituals
    /// - Active bonus (10%): bonus if currently in a focus session
    private func computeProductivityScore(
        totalFocusMinutes: Int,
        currentStreak: Int,
        isInFocusSession: Bool,
        completionRate: Double = 0
    ) -> Double {
        // Streak component: 0-40 pts (capped at 30 days)
        let streakScore = min(Double(currentStreak) / 30.0, 1.0) * 40.0

        // Focus volume component: 0-30 pts (capped at 120 min)
        let focusScore = min(Double(totalFocusMinutes) / 120.0, 1.0) * 30.0

        // Task completion component: 0-20 pts
        let taskScore = completionRate * 20.0

        // Active bonus: 0 or 10 pts
        let activeBonus: Double = isInFocusSession ? 10.0 : 0.0

        let total = streakScore + focusScore + taskScore + activeBonus
        return min(round(total * 10) / 10, 100.0)  // Round to 1 decimal, cap at 100
    }
}
