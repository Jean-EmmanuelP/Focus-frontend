import Foundation

// MARK: - Day Plan
struct DayPlan: Codable, Identifiable {
    let id: String
    let userId: String
    let date: String
    var idealDayPrompt: String?
    var aiSummary: String?
    var progress: Int
    var status: String
    let createdAt: Date
    var updatedAt: Date
    var tasks: [CalendarTask]?
}

// MARK: - Calendar Task
struct CalendarTask: Codable, Identifiable {
    let id: String
    let userId: String
    var questId: String?
    var areaId: String?
    var title: String
    var description: String?
    var date: String                        // YYYY-MM-DD
    var scheduledStart: String?             // HH:mm
    var scheduledEnd: String?               // HH:mm
    var timeBlock: String                   // morning, afternoon, evening
    var position: Int
    var estimatedMinutes: Int?
    var actualMinutes: Int
    var priority: String
    var status: String
    var dueAt: Date?
    var completedAt: Date?
    var isAiGenerated: Bool
    var aiNotes: String?
    var isPrivate: Bool?                    // If true, task content is hidden from friends
    let createdAt: Date
    var updatedAt: Date
    var questTitle: String?
    var areaName: String?
    var areaIcon: String?
    var photosCount: Int?                   // Number of community photos linked to this task

    var isCompleted: Bool {
        status == "completed"
    }

    var statusEnum: TaskStatus {
        TaskStatus(rawValue: status) ?? .pending
    }

    var priorityEnum: TaskPriority {
        TaskPriority(rawValue: priority) ?? .medium
    }

    // Computed properties for calendar display
    var startDate: Date? {
        guard let start = scheduledStart else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current  // Use local timezone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: "\(date) \(start)")
    }

    var endDate: Date? {
        guard let end = scheduledEnd else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current  // Use local timezone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: "\(date) \(end)")
    }

    var formattedTimeRange: String {
        guard let start = scheduledStart, let end = scheduledEnd else {
            return timeBlock.capitalized
        }
        return "\(start) - \(end)"
    }

    /// Convert date string (YYYY-MM-DD) to Date object
    var dateAsDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

enum TaskStatus: String, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
    case skipped
}

enum TaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case urgent

    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

// MARK: - Calendar Day Response
struct CalendarDayResponse: Codable {
    var dayPlan: DayPlan?
    var tasks: [CalendarTask]
    var progress: Int
}

// MARK: - AI Generation Response
struct GenerateDayPlanResponse: Codable {
    var dayPlan: DayPlan
    var tasks: [CalendarTask]
    var aiSummary: String
}

// MARK: - Request Types
struct CreateDayPlanRequest: Codable {
    var date: String
    var idealDayPrompt: String
}

struct CreateTaskRequest: Codable {
    var questId: String?
    var areaId: String?
    var title: String
    var description: String?
    var date: String                        // YYYY-MM-DD
    var scheduledStart: String?             // HH:mm
    var scheduledEnd: String?               // HH:mm
    var timeBlock: String?                  // morning, afternoon, evening
    var position: Int?
    var estimatedMinutes: Int?
    var priority: String?
    var dueAt: Date?
    var isPrivate: Bool?
}

struct UpdateTaskRequest: Codable {
    var title: String?
    var description: String?
    var date: String?
    var scheduledStart: String?
    var scheduledEnd: String?
    var timeBlock: String?
    var position: Int?
    var estimatedMinutes: Int?
    var actualMinutes: Int?
    var priority: String?
    var status: String?
    var dueAt: Date?
    var questId: String?
    var areaId: String?
    var isPrivate: Bool?
}

struct RescheduleTaskRequest: Codable {
    var date: String
    var scheduledStart: String?
    var scheduledEnd: String?
}

struct GenerateDayPlanRequest: Codable {
    var idealDayPrompt: String
    var date: String
}

// MARK: - Week View Response
struct WeekViewResponse: Codable {
    var startDate: String
    var endDate: String
    var tasks: [CalendarTask]
}
