import Foundation
import CoreLocation

// MARK: - Nearby User

struct NearbyUser: Codable, Identifiable {
    let id: String
    let pseudo: String?
    let firstName: String?
    let avatarUrl: String?
    let lifeGoal: String?
    let hobbies: String?
    let productivityPeak: String?
    let currentStreak: Int?
    let city: String?
    let country: String?
    let latitude: Double
    let longitude: Double

    // Client-side enrichment (not from API)
    var todaySteps: Int?
    var isFake: Bool = false

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        if let pseudo = pseudo, !pseudo.isEmpty { return pseudo }
        if let first = firstName, !first.isEmpty { return first }
        return "User"
    }

    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case id, pseudo, firstName, avatarUrl, lifeGoal, hobbies
        case productivityPeak, currentStreak, city, country, latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        pseudo = try container.decodeIfPresent(String.self, forKey: .pseudo)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        lifeGoal = try container.decodeIfPresent(String.self, forKey: .lifeGoal)
        hobbies = try container.decodeIfPresent(String.self, forKey: .hobbies)
        productivityPeak = try container.decodeIfPresent(String.self, forKey: .productivityPeak)
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        todaySteps = nil
        isFake = false
    }

    init(
        id: String, pseudo: String?, firstName: String?, avatarUrl: String?,
        lifeGoal: String?, hobbies: String?, productivityPeak: String?,
        currentStreak: Int?, city: String?, country: String?,
        latitude: Double, longitude: Double,
        todaySteps: Int? = nil, isFake: Bool = false
    ) {
        self.id = id
        self.pseudo = pseudo
        self.firstName = firstName
        self.avatarUrl = avatarUrl
        self.lifeGoal = lifeGoal
        self.hobbies = hobbies
        self.productivityPeak = productivityPeak
        self.currentStreak = currentStreak
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.todaySteps = todaySteps
        self.isFake = isFake
    }
}

// MARK: - Match Result

struct MatchResult {
    let score: Int             // 0-4
    let commonPoints: [String] // e.g. ["Morning person tous les deux", "Objectif similaire"]
}
