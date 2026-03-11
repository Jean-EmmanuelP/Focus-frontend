import Foundation
import CoreLocation

/// Generates deterministic fake users around a given location for demo/debug purposes.
/// Uses a seeded random based on the grid cell so the same fakes appear at the same place.
struct FakeUserGenerator {

    // MARK: - Data Pools

    private static let firstNames = [
        "Amine", "Sofia", "Youssef", "Lina", "Karim", "Nadia", "Rayan", "Amira",
        "Mehdi", "Yasmine", "Samir", "Leila", "Omar", "Inès", "Adam", "Salma",
        "Bilal", "Hana", "Malik", "Nora"
    ]

    private static let lifeGoals = [
        "Devenir développeur senior",
        "Lancer mon business en ligne",
        "Courir un marathon",
        "Apprendre 3 langues",
        "Écrire un livre",
        "Atteindre la liberté financière",
        "Méditer chaque jour pendant 1 an",
        "Perdre 10kg et tenir",
        "Décrocher un CDI dans la tech",
        "Créer une app à succès",
        "Voyager dans 20 pays",
        "Obtenir mon diplôme",
        "Devenir coach sportif",
        "Lire 50 livres cette année",
        "Maîtriser le piano"
    ]

    private static let hobbiesList = [
        "Running, Lecture, Méditation",
        "Musculation, Code, Podcasts",
        "Yoga, Cuisine, Photographie",
        "Football, Gaming, Musique",
        "Natation, Écriture, Dessin",
        "Boxe, Entrepreneuriat, Voyage",
        "Danse, Jardinage, Randonnée",
        "CrossFit, Lecture, Cinéma",
        "Tennis, Piano, Langues",
        "Escalade, Design, Bénévolat"
    ]

    private static let cities = [
        "Paris", "Lyon", "Marseille", "Bordeaux", "Toulouse",
        "Nantes", "Lille", "Strasbourg", "Montpellier", "Nice"
    ]

    private static let peaks = ["morning", "afternoon", "evening"]

    // MARK: - Generation

    /// Generate ~20 fake users within a 5km radius of the given location.
    /// The output is deterministic for a given grid cell (same lat/lon area = same fakes).
    func generate(around center: CLLocationCoordinate2D, count: Int = 20) -> [NearbyUser] {
        // Grid cell: round to 0.05 degree (~5km) to make it deterministic per zone
        let gridLat = (center.latitude * 20).rounded() / 20
        let gridLon = (center.longitude * 20).rounded() / 20
        let seed = UInt64(abs(gridLat * 10000 + gridLon * 1000))

        var rng = SeededRNG(seed: seed)
        var users: [NearbyUser] = []

        for i in 0..<count {
            // Random offset within ~5km (0.045 degrees ≈ 5km)
            let latOffset = Double.random(in: -0.045...0.045, using: &rng)
            let lonOffset = Double.random(in: -0.045...0.045, using: &rng)

            let nameIndex = Int.random(in: 0..<Self.firstNames.count, using: &rng)
            let goalIndex = Int.random(in: 0..<Self.lifeGoals.count, using: &rng)
            let hobbyIndex = Int.random(in: 0..<Self.hobbiesList.count, using: &rng)
            let cityIndex = Int.random(in: 0..<Self.cities.count, using: &rng)
            let peakIndex = Int.random(in: 0..<Self.peaks.count, using: &rng)
            let streak = Int.random(in: 3...90, using: &rng)
            let steps = Int.random(in: 2000...14000, using: &rng)

            let user = NearbyUser(
                id: "fake-\(seed)-\(i)",
                pseudo: nil,
                firstName: Self.firstNames[nameIndex],
                avatarUrl: nil,
                lifeGoal: Self.lifeGoals[goalIndex],
                hobbies: Self.hobbiesList[hobbyIndex],
                productivityPeak: Self.peaks[peakIndex],
                currentStreak: streak,
                city: Self.cities[cityIndex],
                country: "France",
                latitude: center.latitude + latOffset,
                longitude: center.longitude + lonOffset,
                todaySteps: steps,
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
