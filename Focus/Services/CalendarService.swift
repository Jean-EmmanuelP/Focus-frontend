import Foundation

@MainActor
class CalendarService {
    private let apiClient = APIClient.shared

    // MARK: - Day Plans

    func getDayPlan(date: String) async throws -> CalendarDayResponse {
        return try await apiClient.request(
            endpoint: .calendarDay(date: date),
            method: .get
        )
    }

    func createDayPlan(date: String, idealDayPrompt: String) async throws -> DayPlan {
        let request = CreateDayPlanRequest(date: date, idealDayPrompt: idealDayPrompt)
        return try await apiClient.request(
            endpoint: .createDayPlan,
            method: .post,
            body: request
        )
    }

    func updateDayPlan(id: String, status: String? = nil, aiSummary: String? = nil) async throws -> DayPlan {
        struct UpdateRequest: Codable {
            var status: String?
            var aiSummary: String?
        }
        return try await apiClient.request(
            endpoint: .updateDayPlan(id),
            method: .patch,
            body: UpdateRequest(status: status, aiSummary: aiSummary)
        )
    }

    // MARK: - Tasks

    func getTasks(date: String? = nil) async throws -> [CalendarTask] {
        return try await apiClient.request(
            endpoint: .calendarTasks(date: date),
            method: .get
        )
    }

    func createTask(
        questId: String? = nil,
        areaId: String? = nil,
        title: String,
        description: String? = nil,
        date: String,
        scheduledStart: String? = nil,
        scheduledEnd: String? = nil,
        timeBlock: String = "morning",
        position: Int? = nil,
        estimatedMinutes: Int? = nil,
        priority: String = "medium",
        dueAt: Date? = nil,
        isPrivate: Bool = false
    ) async throws -> CalendarTask {
        let request = CreateTaskRequest(
            questId: questId,
            areaId: areaId,
            title: title,
            description: description,
            date: date,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            timeBlock: timeBlock,
            position: position,
            estimatedMinutes: estimatedMinutes,
            priority: priority,
            dueAt: dueAt,
            isPrivate: isPrivate
        )
        return try await apiClient.request(
            endpoint: .createCalendarTask,
            method: .post,
            body: request
        )
    }

    func rescheduleTask(
        id: String,
        date: String,
        scheduledStart: String?,
        scheduledEnd: String?
    ) async throws -> CalendarTask {
        let request = RescheduleTaskRequest(
            date: date,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd
        )
        return try await apiClient.request(
            endpoint: .rescheduleTask(id),
            method: .patch,
            body: request
        )
    }

    func updateTask(
        id: String,
        title: String? = nil,
        description: String? = nil,
        position: Int? = nil,
        estimatedMinutes: Int? = nil,
        actualMinutes: Int? = nil,
        priority: String? = nil,
        status: String? = nil
    ) async throws -> CalendarTask {
        let request = UpdateTaskRequest(
            title: title,
            description: description,
            position: position,
            estimatedMinutes: estimatedMinutes,
            actualMinutes: actualMinutes,
            priority: priority,
            status: status
        )
        return try await apiClient.request(
            endpoint: .updateCalendarTask(id),
            method: .patch,
            body: request
        )
    }

    func completeTask(id: String) async throws -> CalendarTask {
        return try await apiClient.request(
            endpoint: .completeCalendarTask(id),
            method: .post
        )
    }

    func uncompleteTask(id: String) async throws -> CalendarTask {
        return try await apiClient.request(
            endpoint: .uncompleteCalendarTask(id),
            method: .post
        )
    }

    func deleteTask(id: String) async throws {
        try await apiClient.request(
            endpoint: .deleteCalendarTask(id),
            method: .delete
        )
    }

    // MARK: - AI Generation

    func generateDayPlan(idealDayPrompt: String, date: String) async throws -> GenerateDayPlanResponse {
        let request = GenerateDayPlanRequest(idealDayPrompt: idealDayPrompt, date: date)
        return try await apiClient.request(
            endpoint: .generateDayPlan,
            method: .post,
            body: request
        )
    }

    // MARK: - Week View

    func getWeekView(startDate: String) async throws -> WeekViewResponse {
        return try await apiClient.request(
            endpoint: .calendarWeek(startDate: startDate),
            method: .get
        )
    }

}
