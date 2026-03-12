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

    // Focus session data
    var isInFocusSession: Bool = false
    var focusSessionStartedAt: Date?
    var focusSessionDurationMin: Int?
    var focusSessionDescription: String?
    var totalMinutesToday: Int = 0

    // Client-side enrichment (not from API)
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

    /// Minutes elapsed since focus session started
    var focusMinutesElapsed: Int {
        guard let startedAt = focusSessionStartedAt else { return 0 }
        return max(1, Int(Date().timeIntervalSince(startedAt) / 60))
    }

    enum CodingKeys: String, CodingKey {
        case id, pseudo, firstName, avatarUrl, lifeGoal, hobbies
        case productivityPeak, currentStreak, city, country, latitude, longitude
        case isInFocusSession, focusSessionStartedAt, focusSessionDurationMin, focusSessionDescription, totalMinutesToday
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
        isInFocusSession = try container.decodeIfPresent(Bool.self, forKey: .isInFocusSession) ?? false
        focusSessionStartedAt = try container.decodeIfPresent(Date.self, forKey: .focusSessionStartedAt)
        focusSessionDurationMin = try container.decodeIfPresent(Int.self, forKey: .focusSessionDurationMin)
        focusSessionDescription = try container.decodeIfPresent(String.self, forKey: .focusSessionDescription)
        totalMinutesToday = try container.decodeIfPresent(Int.self, forKey: .totalMinutesToday) ?? 0
        isFake = false
    }

    init(
        id: String, pseudo: String?, firstName: String?, avatarUrl: String?,
        lifeGoal: String?, hobbies: String?, productivityPeak: String?,
        currentStreak: Int?, city: String?, country: String?,
        latitude: Double, longitude: Double,
        isInFocusSession: Bool = false, focusSessionStartedAt: Date? = nil,
        focusSessionDurationMin: Int? = nil, focusSessionDescription: String? = nil,
        totalMinutesToday: Int = 0,
        isFake: Bool = false
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
        self.isInFocusSession = isInFocusSession
        self.focusSessionStartedAt = focusSessionStartedAt
        self.focusSessionDurationMin = focusSessionDurationMin
        self.focusSessionDescription = focusSessionDescription
        self.totalMinutesToday = totalMinutesToday
        self.isFake = isFake
    }
}

// MARK: - Encouragement

struct EncouragementPreset: Identifiable {
    let id = UUID()
    let emoji: String
    let message: String
}

let encouragementPresets: [EncouragementPreset] = [
    EncouragementPreset(emoji: "🔥", message: "Continue !"),
    EncouragementPreset(emoji: "💪", message: "Tu geres !"),
    EncouragementPreset(emoji: "🚀", message: "Focus !"),
    EncouragementPreset(emoji: "⭐", message: "Bravo !"),
    EncouragementPreset(emoji: "🧠", message: "Deep work !"),
    EncouragementPreset(emoji: "👏", message: "Chapeau !"),
]

struct EncouragementToast: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let message: String
    let fromInitial: String
}
