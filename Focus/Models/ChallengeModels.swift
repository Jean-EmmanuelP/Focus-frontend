import Foundation

// MARK: - Challenge Types

enum ChallengeType: String, Codable, CaseIterable {
    case wakeup = "wakeup"
    case gym = "gym"
    case meditation = "meditation"
    case reading = "reading"
    case custom = "custom"

    var title: String {
        switch self {
        case .wakeup: return "Réveil"
        case .gym: return "Sport"
        case .meditation: return "Méditation"
        case .reading: return "Lecture"
        case .custom: return "Personnalisé"
        }
    }

    var icon: String {
        switch self {
        case .wakeup: return "alarm.fill"
        case .gym: return "dumbbell.fill"
        case .meditation: return "brain.head.profile"
        case .reading: return "book.fill"
        case .custom: return "star.fill"
        }
    }

    var color: String {
        switch self {
        case .wakeup: return "orange"
        case .gym: return "red"
        case .meditation: return "purple"
        case .reading: return "blue"
        case .custom: return "green"
        }
    }
}

// MARK: - Challenge

struct Challenge: Codable, Identifiable {
    let id: String
    var challengeType: String
    var alarmTime: String?
    var durationDays: Int
    var status: String              // pending, active, completed, cancelled
    var creatorId: String
    var opponentId: String?
    var creatorName: String?
    var opponentName: String?
    var creatorScore: Int
    var opponentScore: Int
    var creatorStreak: Int
    var opponentStreak: Int
    var startDate: String?
    var customTitle: String?

    enum CodingKeys: String, CodingKey {
        case id
        case challengeType = "challenge_type"
        case alarmTime = "alarm_time"
        case durationDays = "duration_days"
        case status
        case creatorId = "creator_id"
        case opponentId = "opponent_id"
        case creatorName = "creator_name"
        case opponentName = "opponent_name"
        case creatorScore = "creator_score"
        case opponentScore = "opponent_score"
        case creatorStreak = "creator_streak"
        case opponentStreak = "opponent_streak"
        case startDate = "start_date"
        case customTitle = "custom_title"
    }

    var type: ChallengeType {
        ChallengeType(rawValue: challengeType) ?? .custom
    }

    var displayTitle: String {
        customTitle ?? type.title
    }

    var dayNumber: Int {
        guard let start = startDate else { return 0 }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let startDate = fmt.date(from: start) else { return 0 }
        return max(1, Int(Date().timeIntervalSince(startDate) / 86400) + 1)
    }

    var isActive: Bool { status == "active" }
}

// MARK: - Challenge Entry

struct ChallengeEntry: Codable, Identifiable {
    let id: String?
    let userId: String
    let dayNumber: Int
    let wakeUpTime: String?
    let photoUrl: String?
    let isOnTime: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dayNumber = "day_number"
        case wakeUpTime = "wake_up_time"
        case photoUrl = "photo_url"
        case isOnTime = "is_on_time"
    }
}

// MARK: - Gesture Verification

enum VerificationGesture: String, CaseIterable {
    case thumbsUp = "thumbs_up"
    case peace = "peace"
    case wave = "wave"
    case threeFingers = "three_fingers"
    case pointUp = "point_up"

    var instruction: String {
        switch self {
        case .thumbsUp: return "Fais un pouce en l'air"
        case .peace: return "Fais le signe de paix"
        case .wave: return "Fais un signe de la main"
        case .threeFingers: return "Montre 3 doigts"
        case .pointUp: return "Pointe vers le haut"
        }
    }

    var emoji: String {
        switch self {
        case .thumbsUp: return "👍"
        case .peace: return "✌️"
        case .wave: return "👋"
        case .threeFingers: return "🤟"
        case .pointUp: return "☝️"
        }
    }

    static var random: VerificationGesture {
        allCases.randomElement() ?? .thumbsUp
    }
}

// MARK: - API Request Bodies

struct CreateChallengeRequest: Encodable {
    let challengeType: String
    let alarmTime: String
    let durationDays: Int
    let customTitle: String?

    enum CodingKeys: String, CodingKey {
        case challengeType = "challenge_type"
        case alarmTime = "alarm_time"
        case durationDays = "duration_days"
        case customTitle = "custom_title"
    }
}

struct ChallengeCheckInRequest: Encodable {
    let wakeUpTime: String
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case wakeUpTime = "wake_up_time"
        case photoUrl = "photo_url"
    }
}
