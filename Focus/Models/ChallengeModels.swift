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
    var challengeType: String?
    var alarmTime: String?
    var durationDays: Int?
    var status: String?
    var creatorId: String?
    var opponentId: String?
    var creatorName: String?
    var opponentName: String?
    var creatorScore: Int?
    var opponentScore: Int?
    var creatorStreak: Int?
    var opponentStreak: Int?
    var startDate: String?
    var customTitle: String?
    var inviteCode: String?
    var mantra: String?
    var title: String?

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
        case inviteCode = "invite_code"
        case mantra
        case title
    }

    var type: ChallengeType {
        ChallengeType(rawValue: challengeType ?? "wakeup") ?? .custom
    }

    var displayTitle: String {
        title ?? customTitle ?? type.title
    }

    var effectiveStatus: String { status ?? "pending" }

    private static let dayNumberFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    var dayNumber: Int {
        guard let start = startDate else { return 0 }
        guard let startDate = Self.dayNumberFormatter.date(from: start) else { return 0 }
        return max(1, Int(Date().timeIntervalSince(startDate) / 86400) + 1)
    }

    var isActive: Bool { effectiveStatus == "active" }
    var isPending: Bool { effectiveStatus == "pending" }

    var isSolo: Bool {
        opponentId == nil || opponentId?.isEmpty == true
    }

    /// Partner name from the current user's perspective
    func partnerName(myId: String) -> String {
        if myId == creatorId {
            return opponentName ?? "En attente"
        }
        return creatorName ?? "Inconnu"
    }

    /// My score from the current user's perspective
    func myScore(myId: String) -> Int {
        (myId == creatorId ? creatorScore : opponentScore) ?? 0
    }

    func partnerScore(myId: String) -> Int {
        (myId == creatorId ? opponentScore : creatorScore) ?? 0
    }

    func myStreak(myId: String) -> Int {
        (myId == creatorId ? creatorStreak : opponentStreak) ?? 0
    }

    func partnerStreak(myId: String) -> Int {
        (myId == creatorId ? opponentStreak : creatorStreak) ?? 0
    }
}

// MARK: - Challenge Entry

struct ChallengeEntry: Codable, Identifiable {
    let id: String?
    let userId: String
    let dayNumber: Int
    let wakeUpTime: String?
    let photoUrl: String?
    let isOnTime: Bool
    var mantraValidated: Bool?
    var exercisesDone: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dayNumber = "day_number"
        case wakeUpTime = "wake_up_time"
        case photoUrl = "photo_url"
        case isOnTime = "is_on_time"
        case mantraValidated = "mantra_validated"
        case exercisesDone = "exercises_done"
    }
}

// MARK: - Taunt

struct ChallengeTaunt: Codable, Identifiable {
    let id: String
    let challengeId: String
    let senderId: String
    let senderName: String?
    let message: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case challengeId = "challenge_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case message
        case createdAt = "created_at"
    }
}

// MARK: - Challenge Detail Response

struct ChallengeDetailResponse: Codable {
    let id: String
    let alarmTime: String?
    let status: String?
    let durationDays: Int?
    let creatorId: String?
    let opponentId: String?
    let creatorName: String?
    let opponentName: String?
    let creatorScore: Int?
    let opponentScore: Int?
    let creatorStreak: Int?
    let opponentStreak: Int?
    let startDate: String?
    let inviteCode: String?
    let title: String?
    let mantra: String?
    let entries: [ChallengeEntry]?

    enum CodingKeys: String, CodingKey {
        case id
        case alarmTime = "alarm_time"
        case status
        case durationDays = "duration_days"
        case creatorId = "creator_id"
        case opponentId = "opponent_id"
        case creatorName = "creator_name"
        case opponentName = "opponent_name"
        case creatorScore = "creator_score"
        case opponentScore = "opponent_score"
        case creatorStreak = "creator_streak"
        case opponentStreak = "opponent_streak"
        case startDate = "start_date"
        case inviteCode = "invite_code"
        case title, mantra, entries
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
    let alarmTime: String
    let durationDays: Int
    let title: String?
    let mantra: String?

    enum CodingKeys: String, CodingKey {
        case alarmTime = "alarm_time"
        case durationDays = "duration_days"
        case title, mantra
    }
}

struct ChallengeCheckInRequest: Encodable {
    let wakeUpTime: String
    let photoUrl: String?
    let mantraValidated: Bool?
    let exercisesDone: Bool?

    enum CodingKeys: String, CodingKey {
        case wakeUpTime = "wake_up_time"
        case photoUrl = "photo_url"
        case mantraValidated = "mantra_validated"
        case exercisesDone = "exercises_done"
    }
}

struct JoinByCodeRequest: Encodable {
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
    }
}

struct SendTauntRequest: Encodable {
    let message: String
}
