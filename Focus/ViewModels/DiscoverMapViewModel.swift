import Foundation
import Combine
import CoreLocation
import SwiftUI

@MainActor
class DiscoverMapViewModel: ObservableObject {
    @Published var nearbyUsers: [NearbyUser] = []
    @Published var selectedUser: NearbyUser? = nil
    @Published var matchResult: MatchResult? = nil
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var todaySteps: Int?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Fake users ON by default — 10 taps on title disables them
    @Published var fakeUsersEnabled = true

    private let discoverService = DiscoverService()
    private let locationService = LocationService.shared
    private let healthKitService = HealthKitService.shared
    private let fakeUserGenerator = FakeUserGenerator()

    // Easter egg tap counter
    private var debugTapCount = 0
    private var lastTapTime = Date.distantPast

    var userCount: Int { nearbyUsers.count }

    // MARK: - Load Data

    func loadData() async {
        isLoading = true
        errorMessage = nil

        // 1. Get location
        if let location = locationService.currentLocation {
            userLocation = location.coordinate
        } else {
            locationService.startUpdating()
            // Wait briefly for location
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if let location = locationService.currentLocation {
                userLocation = location.coordinate
            }
        }

        guard let coordinate = userLocation else {
            errorMessage = "Localisation indisponible"
            isLoading = false
            return
        }

        // 2. Fetch real users from API
        var realUsers: [NearbyUser] = []
        do {
            realUsers = try await discoverService.fetchNearbyUsers(
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                radiusKm: 50
            )
        } catch {
            print("[DiscoverMap] API error: \(error)")
            // Continue — we may still show fake users
        }

        // 3. Merge with fake users if enabled
        if fakeUsersEnabled {
            let fakeUsers = fakeUserGenerator.generate(around: coordinate)
            nearbyUsers = realUsers + fakeUsers
        } else {
            nearbyUsers = realUsers
        }

        // 4. Fetch HealthKit steps
        todaySteps = await healthKitService.fetchTodaySteps()

        isLoading = false
    }

    // MARK: - Select User

    func selectUser(_ user: NearbyUser) {
        selectedUser = user
        if let currentUser = FocusAppStore.shared.user {
            matchResult = computeMatch(for: user, currentUser: currentUser)
        } else {
            matchResult = nil
        }
    }

    func deselectUser() {
        selectedUser = nil
        matchResult = nil
    }

    // MARK: - AI Matching (Client-side)

    func computeMatch(for user: NearbyUser, currentUser: User) -> MatchResult {
        var points: [String] = []

        // 1. Productivity peak match
        if let userPeak = user.productivityPeak,
           let myPeak = currentUser.productivityPeak?.rawValue,
           userPeak == myPeak {
            let peakLabel: String
            switch userPeak {
            case "morning": peakLabel = "du matin"
            case "afternoon": peakLabel = "de l'après-midi"
            default: peakLabel = "du soir"
            }
            points.append("Early birds \(peakLabel) tous les deux")
        }

        // 2. Hobbies match (keyword split)
        if let userHobbies = user.hobbies?.lowercased(),
           let myHobbies = currentUser.hobbies?.lowercased() {
            let userSet = Set(userHobbies.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            let mySet = Set(myHobbies.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            let common = userSet.intersection(mySet).filter { !$0.isEmpty }
            if !common.isEmpty {
                let joined = common.prefix(2).joined(separator: " et ")
                points.append("Passion commune : \(joined)")
            }
        }

        // 3. Life goal similarity (keyword match)
        if let userGoal = user.lifeGoal?.lowercased(),
           let myGoal = currentUser.lifeGoal?.lowercased() {
            let userWords = Set(userGoal.components(separatedBy: .whitespaces).filter { $0.count > 3 })
            let myWords = Set(myGoal.components(separatedBy: .whitespaces).filter { $0.count > 3 })
            let common = userWords.intersection(myWords)
            if !common.isEmpty {
                points.append("Objectif de vie similaire")
            }
        }

        // 4. Streak proximity (within 20%)
        if let userStreak = user.currentStreak, userStreak > 0,
           let myStreak = currentUser.currentStreak, myStreak > 0 {
            let diff = abs(userStreak - myStreak)
            let avg = (userStreak + myStreak) / 2
            if avg > 0 && diff <= avg / 5 {
                points.append("Streak similaire (\(userStreak) jours)")
            }
        }

        return MatchResult(score: min(4, points.count), commonPoints: points)
    }

    // MARK: - Easter Egg (10 taps to toggle fake users)

    func handleDebugTap() {
        let now = Date()
        // Reset counter if more than 3s since last tap
        if now.timeIntervalSince(lastTapTime) > 3 {
            debugTapCount = 0
        }
        lastTapTime = now
        debugTapCount += 1

        if debugTapCount >= 10 {
            debugTapCount = 0
            fakeUsersEnabled.toggle()
            HapticFeedback.heavy()

            // Reload data
            Task {
                await loadData()
            }
        }
    }
}
