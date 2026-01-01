import Foundation

// MARK: - User
struct User: Codable, Identifiable {
    let id: String
    var pseudo: String?         // Display name / username
    var firstName: String?
    var lastName: String?
    var email: String
    var avatarURL: String?
    var gender: String?         // male, female, other, prefer_not_to_say
    var age: Int?
    var description: String?    // Bio / tagline
    var hobbies: String?
    var lifeGoal: String?       // What they want to achieve
    var dayVisibility: String?  // public, crew, private
    var productivityPeak: ProductivityPeak? // morning, afternoon, evening
    var currentStreak: Int
    var longestStreak: Int

    // Computed display name (pseudo > firstName lastName > email prefix)
    var name: String {
        if let pseudo = pseudo, !pseudo.isEmpty {
            return pseudo
        }
        if let first = firstName, !first.isEmpty {
            if let last = lastName, !last.isEmpty {
                return "\(first) \(last)"
            }
            return first
        }
        return email.components(separatedBy: "@").first ?? "User"
    }
}

// MARK: - Focus Session
struct FocusSession: Codable, Identifiable {
    let id: String
    let userId: String
    let durationMinutes: Int // Planned duration
    let startTime: Date
    let endTime: Date?
    let questId: String?
    let description: String?
    let isManuallyLogged: Bool

    enum Status {
        case inProgress
        case completed
        case cancelled
    }

    var status: Status {
        if let endTime = endTime {
            return endTime > startTime ? .completed : .cancelled
        }
        return .inProgress
    }

    /// Actual duration based on timestamps (completed_at - started_at)
    /// Falls back to planned duration if no end time
    var actualDurationMinutes: Int {
        guard let endTime = endTime else {
            return durationMinutes
        }
        let seconds = endTime.timeIntervalSince(startTime)
        return max(1, Int(seconds / 60))
    }

    /// Formatted actual duration string
    var formattedActualDuration: String {
        let mins = actualDurationMinutes
        if mins >= 60 {
            let hours = mins / 60
            let remainingMins = mins % 60
            if remainingMins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMins)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Quest
struct Quest: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let title: String
    let area: QuestArea
    var progress: Double // 0.0 to 1.0
    let status: QuestStatus
    let createdAt: Date
    let targetDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Quest, rhs: Quest) -> Bool {
        lhs.id == rhs.id
    }
}

enum QuestArea: String, Codable, CaseIterable {
    case health = "Health"
    case learning = "Learning"
    case career = "Career"
    case relationships = "Relationships"
    case creativity = "Creativity"
    case other = "Other"
    
    var emoji: String {
        switch self {
        case .health: return "💪"
        case .learning: return "📚"
        case .career: return "💼"
        case .relationships: return "❤️"
        case .creativity: return "🎨"
        case .other: return "✨"
        }
    }
    
    var color: String {
        switch self {
        case .health: return "#34C759"      // iOS Green
        case .learning: return "#5AC8FA"    // Sky Blue
        case .career: return "#4ECDC4"      // Teal
        case .relationships: return "#FF6B9D" // Soft Pink
        case .creativity: return "#BF5AF2"  // Purple
        case .other: return "#8E8E93"       // Gray
        }
    }

    var localizedName: String {
        switch self {
        case .health: return "area.health".localized
        case .learning: return "area.learning".localized
        case .career: return "area.career".localized
        case .relationships: return "area.relationships".localized
        case .creativity: return "area.creativity".localized
        case .other: return "area.other".localized
        }
    }
}

enum QuestStatus: String, Codable {
    case active = "active"
    case completed = "completed"
    case paused = "paused"
    case archived = "archived"
}

// MARK: - Area Progress
struct AreaProgress: Identifiable {
    let id = UUID()
    let area: QuestArea
    let progress: Double // 0.0 to 1.0
}

// MARK: - Daily Ritual
struct DailyRitual: Codable, Identifiable {
    let id: String
    var areaId: String?
    var title: String
    var icon: String
    var isCompleted: Bool
    var category: RitualCategory
    var frequency: RitualFrequency
    var scheduledTime: String? // Time in "HH:mm" format (e.g., "07:30")
    var durationMinutes: Int? // Duration in minutes (default 30)

    // Simplified initializer for API conversion
    init(id: String, areaId: String? = nil, title: String, icon: String, isCompleted: Bool, category: RitualCategory, frequency: RitualFrequency = .daily, scheduledTime: String? = nil, durationMinutes: Int? = nil) {
        self.id = id
        self.areaId = areaId
        self.title = title
        self.icon = icon
        self.isCompleted = isCompleted
        self.category = category
        self.frequency = frequency
        self.scheduledTime = scheduledTime
        self.durationMinutes = durationMinutes
    }

    /// Check if this ritual should be shown today based on frequency
    var shouldShowToday: Bool {
        frequency.isActiveToday
    }

    /// Formatted scheduled time for display
    var formattedScheduledTime: String? {
        guard let time = scheduledTime else { return nil }
        // Convert "HH:mm" to localized time format
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let date = formatter.date(from: time) else { return time }
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Duration for calendar display (defaults to 30 minutes if not set)
    var displayDuration: Int {
        durationMinutes ?? 30
    }
}

enum RitualFrequency: String, Codable {
    case daily = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case weekly = "weekly"
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    case sunday = "sunday"

    /// Check if this frequency is active today
    var isActiveToday: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday

        switch self {
        case .daily:
            return true
        case .weekdays:
            return weekday >= 2 && weekday <= 6 // Monday to Friday
        case .weekends:
            return weekday == 1 || weekday == 7 // Sunday or Saturday
        case .weekly:
            return true // Show weekly rituals every day (or could pick a specific day)
        case .monday:
            return weekday == 2
        case .tuesday:
            return weekday == 3
        case .wednesday:
            return weekday == 4
        case .thursday:
            return weekday == 5
        case .friday:
            return weekday == 6
        case .saturday:
            return weekday == 7
        case .sunday:
            return weekday == 1
        }
    }

    var displayName: String {
        switch self {
        case .daily: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .weekly: return "Weekly"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }
}

enum RitualCategory: String, Codable {
    case health
    case learning
    case career
    case relationships
    case creativity
    case other
}

// MARK: - Daily Intention
struct DailyIntention: Codable, Identifiable {
    let id: String
    let userId: String
    let date: Date
    let intention: String
    let area: QuestArea
    var isCompleted: Bool
}

// MARK: - Morning Check-in
struct MorningCheckIn: Codable, Identifiable {
    let id: String
    let userId: String
    let date: Date
    let feeling: Feeling
    let feelingNote: String?
    let sleepQuality: Int // 1-10
    let sleepNote: String?
    let intentions: [DailyIntention]
}

// MARK: - Productivity Peak
enum ProductivityPeak: String, Codable, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"

    var displayName: String {
        switch self {
        case .morning: return "productivity.morning".localized
        case .afternoon: return "productivity.afternoon".localized
        case .evening: return "productivity.evening".localized
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        }
    }

    var description: String {
        switch self {
        case .morning: return "productivity.morning.description".localized
        case .afternoon: return "productivity.afternoon.description".localized
        case .evening: return "productivity.evening.description".localized
        }
    }

    /// Time range for high concentration tasks
    var peakHours: ClosedRange<Int> {
        switch self {
        case .morning: return 6...11
        case .afternoon: return 12...17
        case .evening: return 18...22
        }
    }
}

enum Feeling: String, Codable, CaseIterable {
    // Ordered from worst to best mood
    case sad = "😔"
    case anxious = "😰"
    case frustrated = "😤"
    case tired = "🥱"
    case neutral = "😐"
    case calm = "😌"
    case happy = "😊"
    case excited = "🤩"

    var label: String {
        switch self {
        case .sad: return "Sad"
        case .anxious: return "Anxious"
        case .frustrated: return "Frustrated"
        case .tired: return "Tired"
        case .neutral: return "Neutral"
        case .calm: return "Calm"
        case .happy: return "Happy"
        case .excited: return "Excited"
        }
    }
}

// MARK: - Evening Review
struct EveningReview: Codable, Identifiable {
    let id: String
    let userId: String
    let date: Date
    let ritualsCompleted: [String] // Ritual IDs
    let biggestWin: String?
    let blockers: String?
    let bestMoment: String?
    let tomorrowGoal: String?
}

// MARK: - Dashboard Data
struct DashboardData: Codable {
    let user: User
    let todaysSessions: [FocusSession]
    let weekSessions: [FocusSession]
    let rituals: [DailyRitual]
    let morningCheckIn: MorningCheckIn?
    let eveningReview: EveningReview?
    let weeklyProgress: [DayProgress]
}

struct DayProgress: Codable, Identifiable {
    var id: String { "\(day)-\(date.timeIntervalSince1970)" }
    let day: String // "M", "T", "W", "T", "F", "S", "S"
    let minutes: Int
    let date: Date

    enum CodingKeys: String, CodingKey {
        case day, minutes, date
    }
}

// MARK: - API Response Conversions

extension User {
    /// Create User from API response
    init(from response: UserResponse) {
        self.id = response.id
        self.email = response.email ?? ""
        self.pseudo = response.pseudo
        self.firstName = response.firstName
        self.lastName = response.lastName
        self.avatarURL = response.avatarUrl
        self.gender = response.gender
        self.age = response.age
        self.description = response.description
        self.hobbies = response.hobbies
        self.lifeGoal = response.lifeGoal
        self.dayVisibility = response.dayVisibility
        self.productivityPeak = ProductivityPeak(rawValue: response.productivityPeak ?? "")
        self.currentStreak = 0
        self.longestStreak = 0
    }
}

extension DailyRitual {
    /// Create DailyRitual from API RoutineResponse
    init(from response: RoutineResponse) {
        self.id = response.id
        self.areaId = response.areaId
        self.title = response.title
        self.icon = response.icon ?? "✨" // Default icon if none provided
        self.isCompleted = response.completed ?? false
        self.category = .other
        self.frequency = RitualFrequency(rawValue: response.frequency) ?? .daily
        self.scheduledTime = response.scheduledTime
    }
}

extension Quest {
    /// Create Quest from API QuestResponse with area info
    init(from response: QuestResponse, area: Area?) {
        self.id = response.id
        self.userId = ""
        self.title = response.title
        self.area = Quest.mapAreaToQuestArea(slug: area?.slug)
        self.progress = response.progress
        self.status = QuestStatus(rawValue: response.status) ?? .active
        self.createdAt = Date()

        // Parse targetDate from ISO string
        if let dateString = response.targetDate {
            let formatter = ISO8601DateFormatter()
            self.targetDate = formatter.date(from: dateString)
        } else {
            self.targetDate = nil
        }
    }

    private static func mapAreaToQuestArea(slug: String?) -> QuestArea {
        guard let slug = slug else { return .other }
        switch slug.lowercased() {
        case "health": return .health
        case "learning": return .learning
        case "career": return .career
        case "relationships": return .relationships
        case "creativity": return .creativity
        default: return .other
        }
    }
}

extension FocusSession {
    /// Create FocusSession from API response
    init(from response: FocusSessionResponse) {
        self.id = response.id
        self.userId = ""
        self.durationMinutes = response.durationMinutes
        self.startTime = response.startedAt
        self.endTime = response.completedAt
        self.questId = response.questId
        self.description = response.description
        self.isManuallyLogged = false
    }
}

extension DayProgress {
    /// Create DayProgress from API DailySessionStat
    init(from stat: DailySessionStat) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current  // Use local timezone to avoid date shifts
        let date = dateFormatter.date(from: stat.date) ?? Date()

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E"
        let dayString = String(dayFormatter.string(from: date).prefix(1))

        self.day = dayString
        self.minutes = stat.minutes
        self.date = date
    }
}
