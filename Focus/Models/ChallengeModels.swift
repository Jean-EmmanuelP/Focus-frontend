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

struct Challenge: Codable, Identifiable, Equatable {
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
    var creatorAvatarUrl: String?
    var opponentAvatarUrl: String?

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
        case creatorAvatarUrl = "creator_avatar_url"
        case opponentAvatarUrl = "opponent_avatar_url"
    }

    var type: ChallengeType {
        ChallengeType(rawValue: challengeType ?? "wakeup") ?? .wakeup
    }

    var displayTitle: String {
        title ?? customTitle ?? type.title
    }

    var effectiveStatus: String { status ?? "pending" }

    private static let dayNumberFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone.current
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

    // MARK: - Validation Window

    /// Whether the current time is within the allowed validation window for this challenge type
    func isInValidationWindow() -> Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let minute = cal.component(.minute, from: Date())
        let nowMinutes = hour * 60 + minute

        switch type {
        case .wakeup:
            guard let alarmStr = alarmTime, !alarmStr.isEmpty else { return false }
            let parts = alarmStr.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return false }
            let alarmMinutes = parts[0] * 60 + parts[1]
            let windowEnd = alarmMinutes + 60
            if windowEnd > 1440 {
                // Midnight wraparound (e.g. 23:30 → 00:30)
                return nowMinutes >= alarmMinutes || nowMinutes <= (windowEnd - 1440)
            }
            return nowMinutes >= alarmMinutes && nowMinutes <= windowEnd
        case .meditation:
            return hour >= 5 && hour < 10
        case .gym:
            return hour >= 5 && hour < 23
        case .reading:
            return hour >= 18 || hour < 1
        case .custom:
            return true
        }
    }

    /// Human-readable description of the validation window
    var validationWindowText: String {
        switch type {
        case .wakeup:
            guard let alarmStr = alarmTime else { return "Valide maintenant" }
            let parts = alarmStr.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return "Valide maintenant" }
            let endHour = parts[0] + 1
            let endMinute = parts[1]
            return "Valide de \(alarmStr) a \(String(format: "%02d:%02d", endHour % 24, endMinute))"
        case .meditation:
            return "Valide de 5h a 10h"
        case .gym:
            return "Valide de 5h a 23h"
        case .reading:
            return "Valide de 18h a 1h"
        case .custom:
            return "Valide a tout moment"
        }
    }

    /// Quick check: has the user likely validated today (approximation based on score vs dayNumber)
    func hasLikelyValidatedToday(myId: String) -> Bool {
        let score = myScore(myId: myId)
        let day = dayNumber
        guard day > 0 && score > 0 else { return false }
        return score >= day
    }

    /// Minutes remaining in the validation window (nil if no window or outside)
    var minutesRemainingInWindow: Int? {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let minute = cal.component(.minute, from: Date())
        let nowMinutes = hour * 60 + minute

        switch type {
        case .wakeup:
            guard let alarmStr = alarmTime else { return nil }
            let parts = alarmStr.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            let windowEnd = parts[0] * 60 + parts[1] + 60
            let remaining = windowEnd - nowMinutes
            return remaining > 0 && remaining <= 60 ? remaining : nil
        case .meditation:
            let end = 10 * 60 // 10:00
            let remaining = end - nowMinutes
            return remaining > 0 && remaining <= 120 ? remaining : nil
        case .gym:
            let end = 23 * 60
            let remaining = end - nowMinutes
            return remaining > 0 && remaining <= 120 ? remaining : nil
        default:
            return nil
        }
    }

    /// Urgency text for display (e.g. "Plus que 45min!")
    var urgencyText: String? {
        guard let mins = minutesRemainingInWindow, mins <= 60 else { return nil }
        if mins <= 5 { return "Derniere chance !" }
        if mins <= 15 { return "Plus que \(mins)min !" }
        if mins <= 30 { return "Plus que \(mins)min" }
        return nil
    }

    /// Whether today's validation window has already passed (= failed day)
    func hasWindowPassedToday() -> Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let minute = cal.component(.minute, from: Date())
        let nowMinutes = hour * 60 + minute

        switch type {
        case .wakeup:
            guard let alarmStr = alarmTime else { return false }
            let parts = alarmStr.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return false }
            let windowEnd = parts[0] * 60 + parts[1] + 60
            if windowEnd > 1440 {
                // Midnight wraparound: window passed only after the wrap portion
                let wrappedEnd = windowEnd - 1440
                return nowMinutes > wrappedEnd && nowMinutes < parts[0] * 60 + parts[1]
            }
            return nowMinutes > windowEnd
        case .meditation:
            return hour >= 10
        case .gym:
            return hour >= 23
        case .reading:
            return hour >= 1 && hour < 18
        case .custom:
            return false
        }
    }

    /// When the next validation window opens (e.g. "Demain a 07:00", "Dans 3h")
    var nextWindowText: String? {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let minute = cal.component(.minute, from: Date())
        let nowMinutes = hour * 60 + minute

        switch type {
        case .wakeup:
            guard let alarmStr = alarmTime else { return nil }
            let parts = alarmStr.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            let alarmMinutes = parts[0] * 60 + parts[1]

            if nowMinutes > alarmMinutes + 60 {
                // Window passed today → next is tomorrow
                let hoursUntil = (1440 - nowMinutes + alarmMinutes) / 60
                if hoursUntil <= 1 {
                    return "Dans \(1440 - nowMinutes + alarmMinutes)min"
                }
                return "Demain a \(alarmStr)"
            } else if nowMinutes < alarmMinutes {
                // Before window today
                let minsUntil = alarmMinutes - nowMinutes
                if minsUntil <= 60 {
                    return "Dans \(minsUntil)min"
                }
                return "Aujourd'hui a \(alarmStr)"
            }
            return nil
        case .meditation:
            if hour >= 10 {
                return "Demain des 5h"
            } else if hour < 5 {
                let minsUntil = 5 * 60 - nowMinutes
                return minsUntil <= 60 ? "Dans \(minsUntil)min" : "A 5h"
            }
            return nil
        case .gym:
            if hour >= 23 {
                return "Demain des 5h"
            }
            return nil
        case .reading:
            if hour >= 1 && hour < 18 {
                let hoursUntil = 18 - hour
                return hoursUntil <= 2 ? "Dans \(hoursUntil)h" : "Ce soir a 18h"
            }
            return nil
        case .custom:
            return nil
        }
    }

    /// Clear description of what this challenge validates
    var ruleDescription: String {
        switch type {
        case .wakeup:
            guard let alarm = alarmTime else { return "Photo entre ton heure de reveil et +1h" }
            let parts = alarm.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return "Photo le matin" }
            let end = String(format: "%02d:%02d", (parts[0] + 1) % 24, parts[1])
            return "Photo entre \(alarm) et \(end)"
        case .gym:
            return "Photo a la salle chaque jour"
        case .meditation:
            return "Photo de meditation entre 5h et 10h"
        case .reading:
            return "Photo de lecture le soir"
        case .custom:
            return "Photo quotidienne"
        }
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
    let challengeType: String?
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
    let creatorAvatarUrl: String?
    let opponentAvatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case challengeType = "challenge_type"
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
        case creatorAvatarUrl = "creator_avatar_url"
        case opponentAvatarUrl = "opponent_avatar_url"
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

// MARK: - Challenge Steps (daily checklist)

enum StepInputType {
    case camera
    case toggle
}

struct ChallengeStep: Identifiable {
    let id: String
    let label: String
    let points: Int
    let inputType: StepInputType
}

/// Tracks today's in-progress checklist state (local, not persisted until submit)
struct TodayProgress {
    let challengeId: String
    let challengeType: ChallengeType
    var selfieUrl: String?
    var photoUrl: String?
    var mantraValidated: Bool = false
    var exercisesDone: Bool = false

    var completedStepIds: Set<String> {
        var ids = Set<String>()
        if selfieUrl != nil { ids.insert("selfie") }
        if photoUrl != nil { ids.insert("photo") }
        if mantraValidated { ids.insert("mantra") }
        if exercisesDone { ids.insert("exercises") }
        return ids
    }

    var completedCount: Int { completedStepIds.count }
    var totalCount: Int { challengeType.steps.count }
    var isComplete: Bool { completedCount >= totalCount }
}

// MARK: - API Request Bodies

struct CreateChallengeRequest: Encodable {
    let alarmTime: String
    let durationDays: Int
    let title: String?
    let mantra: String?
    let challengeType: String?

    enum CodingKeys: String, CodingKey {
        case alarmTime = "alarm_time"
        case durationDays = "duration_days"
        case title, mantra
        case challengeType = "challenge_type"
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
