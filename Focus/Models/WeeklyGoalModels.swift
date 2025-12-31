//
//  WeeklyGoalModels.swift
//  Focus
//
//  Models for Weekly Goals feature (like daily intentions but for the week)
//

import Foundation

// MARK: - Weekly Goal (like DailyIntention)
struct WeeklyGoal: Codable, Identifiable {
    let id: String
    let weekStartDate: Date
    var items: [WeeklyGoalItem]
    let createdAt: Date
    let updatedAt: Date

    var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        items.count
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var isComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    /// Formatted week range string (e.g., "Dec 30 - Jan 5")
    var weekRangeString: String {
        let calendar = Calendar.current
        let sunday = calendar.date(byAdding: .day, value: 6, to: weekStartDate)!

        let startFormatter = DateFormatter()
        let endFormatter = DateFormatter()

        if calendar.component(.month, from: weekStartDate) == calendar.component(.month, from: sunday) {
            startFormatter.dateFormat = "MMM d"
            endFormatter.dateFormat = "d"
        } else {
            startFormatter.dateFormat = "MMM d"
            endFormatter.dateFormat = "MMM d"
        }

        return "\(startFormatter.string(from: weekStartDate)) - \(endFormatter.string(from: sunday))"
    }
}

// MARK: - Weekly Goal Item (like Intention)
struct WeeklyGoalItem: Codable, Identifiable {
    let id: String
    let areaId: String?
    let content: String
    let position: Int
    var isCompleted: Bool
    let completedAt: Date?
}

// MARK: - API Response Models
// Note: APIClient uses .convertFromSnakeCase, so no CodingKeys needed
struct WeeklyGoalResponse: Codable {
    let id: String
    let weekStartDate: String
    let items: [WeeklyGoalItemResponse]
    let createdAt: String
    let updatedAt: String
}

struct WeeklyGoalItemResponse: Codable {
    let id: String
    let areaId: String?
    let content: String
    let position: Int
    let isCompleted: Bool
    let completedAt: String?
}

struct NeedsSetupResponse: Codable {
    let needsSetup: Bool
    let weekStartDate: String?
    let reason: String?
}

// MARK: - Request Models
struct UpsertWeeklyGoalRequest: Codable {
    let items: [WeeklyGoalItemInput]
}

struct WeeklyGoalItemInput: Codable {
    let areaId: String?
    let content: String

    enum CodingKeys: String, CodingKey {
        case areaId = "area_id"
        case content
    }
}

struct ToggleWeeklyGoalItemRequest: Codable {
    let isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case isCompleted = "is_completed"
    }
}

// MARK: - Conversions
extension WeeklyGoal {
    init(from response: WeeklyGoalResponse) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"

        self.id = response.id
        self.weekStartDate = dateOnlyFormatter.date(from: response.weekStartDate) ?? Date()
        self.items = response.items.map { WeeklyGoalItem(from: $0) }
        self.createdAt = dateFormatter.date(from: response.createdAt) ?? Date()
        self.updatedAt = dateFormatter.date(from: response.updatedAt) ?? Date()
    }
}

extension WeeklyGoalItem {
    init(from response: WeeklyGoalItemResponse) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        self.id = response.id
        self.areaId = response.areaId
        self.content = response.content
        self.position = response.position
        self.isCompleted = response.isCompleted
        self.completedAt = response.completedAt.flatMap { dateFormatter.date(from: $0) }
    }
}

// MARK: - Draft Goal Item (for creation UI)
struct DraftGoalItem: Identifiable {
    let id = UUID()
    var content: String
    var areaId: String?

    init(content: String = "", areaId: String? = nil) {
        self.content = content
        self.areaId = areaId
    }
}
