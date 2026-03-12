import Foundation
import CoreLocation

/// Generates deterministic fake users around a given location for demo/debug purposes.
/// Uses a seeded random based on the grid cell so the same fakes appear at the same place.
struct FakeUserGenerator {

    // MARK: - Data Pools

    private static let firstNames = [
        "Amine", "Sofia", "Youssef", "Lina", "Karim", "Nadia", "Rayan", "Amira",
        "Mehdi", "Yasmine", "Samir", "Leila", "Omar", "Ines", "Adam", "Salma",
        "Bilal", "Hana", "Malik", "Nora", "Zara", "Amir", "Dina", "Sami",
        "Lila", "Rami", "Sara", "Walid", "Mona", "Tarek"
    ]

    private static let focusDescriptions = [
        "Deep Work", "Lecture", "Code", "Etude", "Revision",
        "Meditation", "Projet perso", "Ecriture", "Design", "Recherche"
    ]

    private static let focusDurations = [25, 50, 90]

    private static let cities = [
        "Paris", "Lyon", "Marseille", "Bordeaux", "Toulouse",
        "Nantes", "Lille", "Strasbourg", "Montpellier", "Nice"
    ]

    private static let peaks = ["morning", "afternoon", "evening"]

    // MARK: - Generation

    /// Generate ~28 fake users within a 5km radius of the given location.
    /// 60-80% are in a focus session. Output is deterministic per grid cell.
    func generate(around center: CLLocationCoordinate2D, count: Int = 28) -> [NearbyUser] {
        // Grid cell: round to 0.05 degree (~5km) to make it deterministic per zone
        let gridLat = (center.latitude * 20).rounded() / 20
        let gridLon = (center.longitude * 20).rounded() / 20
        let seed = UInt64(abs(gridLat * 10000 + gridLon * 1000))

        var rng = SeededRNG(seed: seed)
        var users: [NearbyUser] = []

        // 60-80% focusing
        let focusPercent = Double.random(in: 0.60...0.80, using: &rng)

        for i in 0..<count {
            // Random offset within ~5km (0.045 degrees ~ 5km)
            let latOffset = Double.random(in: -0.045...0.045, using: &rng)
            let lonOffset = Double.random(in: -0.045...0.045, using: &rng)

            let nameIndex = Int.random(in: 0..<Self.firstNames.count, using: &rng)
            let cityIndex = Int.random(in: 0..<Self.cities.count, using: &rng)
            let peakIndex = Int.random(in: 0..<Self.peaks.count, using: &rng)
            let streak = Int.random(in: 0...90, using: &rng)

            let isFocusing = Double(i) / Double(count) < focusPercent

            // Focus session data
            let minutesAgo = Int.random(in: 5...85, using: &rng)
            let durationIndex = Int.random(in: 0..<Self.focusDurations.count, using: &rng)
            let descIndex = Int.random(in: 0..<Self.focusDescriptions.count, using: &rng)

            // Total minutes today: accumulated effort (current session + past sessions)
            // Creates visual diversity — some grinders at 200+, some just started at 25
            let pastSessionsMinutes = isFocusing ? Int.random(in: 0...180, using: &rng) : Int.random(in: 0...50, using: &rng)
            let totalToday = pastSessionsMinutes + (isFocusing ? minutesAgo : 0)

            let user = NearbyUser(
                id: "fake-\(seed)-\(i)",
                pseudo: nil,
                firstName: Self.firstNames[nameIndex],
                avatarUrl: nil,
                lifeGoal: nil,
                hobbies: nil,
                productivityPeak: Self.peaks[peakIndex],
                currentStreak: streak,
                city: Self.cities[cityIndex],
                country: "France",
                latitude: center.latitude + latOffset,
                longitude: center.longitude + lonOffset,
                isInFocusSession: isFocusing,
                focusSessionStartedAt: isFocusing ? Date().addingTimeInterval(-Double(minutesAgo * 60)) : nil,
                focusSessionDurationMin: isFocusing ? Self.focusDurations[durationIndex] : nil,
                focusSessionDescription: isFocusing ? Self.focusDescriptions[descIndex] : nil,
                totalMinutesToday: totalToday,
                isFake: true
            )
            users.append(user)
        }
        return users
    }
}

// MARK: - Seeded Random Number Generator

/// Simple xorshift64 PRNG for deterministic fake user generation
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
