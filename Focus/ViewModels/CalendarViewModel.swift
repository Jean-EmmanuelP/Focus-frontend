import Foundation
import Combine

@MainActor
class CalendarViewModel: ObservableObject {
    private var store: FocusAppStore { FocusAppStore.shared }
    private let calendarService = CalendarService()
    private let voiceService = VoiceService()
    private let completionsService = CompletionsService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State
    @Published var selectedDate: Date = Date()
    @Published var weekStartDate: Date = Date().startOfWeek
    @Published var dayPlan: DayPlan?
    @Published var tasks: [CalendarTask] = []
    @Published var weekTasks: [CalendarTask] = []
    @Published var dayProgress: Int = 0

    /// Ritual completions for the current week: [routineId: [completedDates]]
    @Published var ritualCompletionsByDate: [String: Set<String>] = [:]

    @Published var isLoading = false
    @Published var isGeneratingPlan = false
    @Published var errorMessage: String?
    @Published var showError = false

    // AI Generation
    @Published var idealDayPrompt: String = ""
    @Published var showAIGenerationSheet = false

    // Voice conversation
    @Published var conversationHistory: [ConversationMessage] = []

    // MARK: - Computed Properties
    var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: selectedDate)
    }

    var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    var weekTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let start = weekStartDate.formatted(.dateTime.day())
        let end = weekEndDate.formatted(.dateTime.day().month())
        return "\(start) - \(end)"
    }

    var weekEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
    }

    var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStartDate) }
    }

    var isCurrentWeek: Bool {
        let today = Date()
        return today >= weekStartDate && today <= weekEndDate
    }

    var hasDayPlan: Bool {
        dayPlan != nil
    }

    var completedTasksCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    var totalTasksCount: Int {
        tasks.count
    }

    var areas: [Area] {
        store.areas
    }

    var quests: [Quest] {
        store.quests.filter { $0.status == .active }
    }

    /// All rituals (for week view indicators)
    var allRituals: [DailyRitual] {
        store.rituals
    }

    /// Rituals with scheduled time for calendar display
    var scheduledRituals: [DailyRitual] {
        let ritualsWithTime = store.rituals.filter { $0.scheduledTime != nil }
        print("📅 Calendar - All rituals: \(store.rituals.count), with scheduledTime: \(ritualsWithTime.count)")
        for ritual in store.rituals {
            print("  - \(ritual.title): scheduledTime=\(ritual.scheduledTime ?? "nil"), frequency=\(ritual.frequency.rawValue)")
        }
        return ritualsWithTime
    }

    /// Check if a ritual is completed on a specific date
    func isRitualCompleted(_ ritualId: String, on date: Date) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current  // Use local timezone consistently
        let dateStr = dateFormatter.string(from: date)

        return ritualCompletionsByDate[ritualId]?.contains(dateStr) ?? false
    }

    /// Load quests from store if needed
    func loadQuestsIfNeeded() async {
        await store.loadQuestsIfNeeded()
    }

    /// Toggle ritual completion for the selected date
    func toggleRitual(_ ritual: DailyRitual) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current  // Use local timezone consistently
        let dateStr = dateFormatter.string(from: selectedDate)

        // Check current completion status for this date
        let wasCompleted = ritualCompletionsByDate[ritual.id]?.contains(dateStr) ?? false
        let isCompleting = !wasCompleted // We want to mark as completed if it wasn't

        // Optimistic update of local completion map
        if wasCompleted {
            ritualCompletionsByDate[ritual.id]?.remove(dateStr)
        } else {
            if ritualCompletionsByDate[ritual.id] == nil {
                ritualCompletionsByDate[ritual.id] = []
            }
            ritualCompletionsByDate[ritual.id]?.insert(dateStr)
        }

        // Sync with server via store (handles API call) - pass the selected date and action!
        await store.toggleRitual(ritual, forDate: dateStr, isCompleting: isCompleting)
    }

    // Group tasks by hour for display
    var tasksByHour: [Int: [CalendarTask]] {
        var grouped: [Int: [CalendarTask]] = [:]
        for task in tasks {
            guard let startDate = task.startDate else { continue }
            let hour = Calendar.current.component(.hour, from: startDate)
            if grouped[hour] == nil {
                grouped[hour] = []
            }
            grouped[hour]?.append(task)
        }
        return grouped
    }

    // Tasks for current selected date
    var tasksForSelectedDate: [CalendarTask] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let selectedDateStr = dateFormatter.string(from: selectedDate)
        return tasks.filter { $0.date == selectedDateStr }
    }

    // MARK: - Init
    init() {
        setupBindings()
        // Set week start to current week
        weekStartDate = Date().startOfWeek
    }

    private func setupBindings() {
        store.$areas
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        store.$quests
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        store.$rituals
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Listen for task updates from the store (e.g., after task completion from FireMode)
        store.$todaysTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedTasks in
                guard let self = self else { return }
                // Refresh week data if today's tasks changed
                Task {
                    await self.loadWeekData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Week Navigation
    func goToPreviousWeek() {
        if let newStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: weekStartDate) {
            weekStartDate = newStart
            Task { await loadWeekData() }
        }
    }

    func goToNextWeek() {
        if let newStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStartDate) {
            weekStartDate = newStart
            Task { await loadWeekData() }
        }
    }

    func goToCurrentWeek() {
        weekStartDate = Date().startOfWeek
        selectedDate = Date()
        Task { await loadWeekData() }
    }

    func dayIndexForTask(_ task: CalendarTask) -> Int {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: task.date) else { return 0 }
        let dayOfWeek = calendar.component(.weekday, from: date)
        // Adjust for week starting on Monday (if needed)
        return (dayOfWeek + 5) % 7 // Monday = 0, Sunday = 6
    }

    // MARK: - Overlap Detection

    /// Check if a time slot overlaps with existing tasks on a given date
    func hasOverlap(date: String, startTime: String, endTime: String, excludingTaskId: String? = nil) -> Bool {
        let tasksOnDate = weekTasks.filter { $0.date == date && $0.id != excludingTaskId }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let newStart = formatter.date(from: startTime),
              let newEnd = formatter.date(from: endTime) else {
            return false
        }

        for task in tasksOnDate {
            guard let taskStart = task.scheduledStart,
                  let taskEnd = task.scheduledEnd,
                  let existingStart = formatter.date(from: taskStart),
                  let existingEnd = formatter.date(from: taskEnd) else {
                continue
            }

            // Check for overlap: new task starts before existing ends AND new task ends after existing starts
            if newStart < existingEnd && newEnd > existingStart {
                return true
            }
        }

        return false
    }

    /// Find the next available time slot on a given date
    func findNextAvailableSlot(date: String, preferredStart: String, duration: Int) -> (start: String, end: String)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard var startTime = formatter.date(from: preferredStart) else { return nil }

        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: startTime) ?? startTime

        while startTime < endOfDay {
            let endTime = startTime.addingTimeInterval(TimeInterval(duration * 60))
            let startStr = formatter.string(from: startTime)
            let endStr = formatter.string(from: endTime)

            if !hasOverlap(date: date, startTime: startStr, endTime: endStr) {
                return (startStr, endStr)
            }

            // Try next hour
            startTime = startTime.addingTimeInterval(3600)
        }

        return nil
    }

    // MARK: - Data Loading
    func loadWeekData() async {
        isLoading = true
        defer { isLoading = false }

        // Load quests in parallel for quick access
        async let questsLoad: () = store.loadQuestsIfNeeded()

        // Use the new week endpoint
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDateStr = dateFormatter.string(from: weekStartDate)
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        let endDateStr = dateFormatter.string(from: endDate)

        print("[CalendarViewModel] Loading week data for start: \(startDateStr)")

        do {
            // Load tasks and completions in parallel
            async let tasksResponse = calendarService.getWeekView(startDate: startDateStr)
            async let completionsResponse = completionsService.fetchCompletions(routineId: nil, from: startDateStr, to: endDateStr)

            let response = try await tasksResponse
            print("[CalendarViewModel] Got \(response.tasks.count) tasks from API")
            weekTasks = response.tasks

            // Filter tasks for current day separately
            let selectedDateStr = dateFormatter.string(from: selectedDate)
            tasks = weekTasks.filter { $0.date == selectedDateStr }
            print("[CalendarViewModel] Filtered to \(tasks.count) tasks for \(selectedDateStr)")

            // Process ritual completions for the week
            let completions = try await completionsResponse
            var completionMap: [String: Set<String>] = [:]
            let completionDateFormatter = DateFormatter()
            completionDateFormatter.dateFormat = "yyyy-MM-dd"
            completionDateFormatter.timeZone = TimeZone.current  // Use local timezone consistently

            for completion in completions {
                let completedDateStr = completionDateFormatter.string(from: completion.completedAt)
                if completionMap[completion.routineId] == nil {
                    completionMap[completion.routineId] = []
                }
                completionMap[completion.routineId]?.insert(completedDateStr)
            }
            ritualCompletionsByDate = completionMap
            print("[CalendarViewModel] Loaded \(completions.count) ritual completions for the week")

        } catch {
            print("[CalendarViewModel] ERROR loading week data: \(error)")
            weekTasks = []
            tasks = []
            ritualCompletionsByDate = [:]
        }

        // Wait for quests to load
        await questsLoad
    }

    func loadDayData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await calendarService.getDayPlan(date: selectedDateString)
            dayPlan = response.dayPlan
            tasks = response.tasks
            dayProgress = response.progress
        } catch {
            dayPlan = nil
            tasks = []
            dayProgress = 0
        }
    }

    // Convenience method to reload all data
    func reloadAllData() async {
        await loadWeekData()
    }

    // Legacy method - kept for compatibility but now empty
    func loadDailyGoals() async {
        // Goals are now tasks - no separate loading needed
    }


    func refreshData() async {
        await loadWeekData()
    }

    // MARK: - Date Navigation
    func selectDate(_ date: Date) {
        selectedDate = date
        Task {
            await loadDayData()
        }
    }

    func goToPreviousDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectDate(newDate)
        }
    }

    func goToNextDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectDate(newDate)
        }
    }

    func goToToday() {
        selectDate(Date())
    }

    // MARK: - Voice Processing
    func processVoiceInput(_ text: String) async throws -> VoiceProcessResponse {
        let response = try await voiceService.processVoice(text: text, date: selectedDateString)

        // Add to conversation history
        conversationHistory.append(ConversationMessage(role: "user", content: text))
        conversationHistory.append(ConversationMessage(role: "assistant", content: response.ttsResponse))

        // Reload data if goals were added
        if response.intentType == "ADD_GOAL" {
            await loadDayData()
            await loadWeekData()
        }

        return response
    }

    func clearConversation() {
        conversationHistory = []
    }

    // MARK: - AI Day Plan Generation
    func generateDayPlan() async {
        guard !idealDayPrompt.isEmpty else { return }

        isGeneratingPlan = true
        defer { isGeneratingPlan = false }

        do {
            let response = try await calendarService.generateDayPlan(
                idealDayPrompt: idealDayPrompt,
                date: selectedDateString
            )

            dayPlan = response.dayPlan
            tasks = response.tasks
            dayProgress = 0

            idealDayPrompt = ""
            showAIGenerationSheet = false

            // Reload week data
            await loadWeekData()

        } catch {
            handleError(error, context: "generating day plan")
        }
    }

    // MARK: - Task Actions
    func createTask(
        title: String,
        description: String? = nil,
        date: String? = nil,
        scheduledStart: String? = nil,
        scheduledEnd: String? = nil,
        timeBlock: String = "morning",
        questId: String? = nil,
        areaId: String? = nil,
        estimatedMinutes: Int? = nil,
        priority: String = "medium"
    ) async {
        let taskDate = date ?? selectedDateString

        // If no scheduled times provided, assign default times based on timeBlock
        var finalStart = scheduledStart
        var finalEnd = scheduledEnd
        let duration = estimatedMinutes ?? 60

        if finalStart == nil {
            switch timeBlock {
            case "morning":
                finalStart = "09:00"
            case "afternoon":
                finalStart = "14:00"
            case "evening":
                finalStart = "19:00"
            default:
                finalStart = "09:00"
            }
        }

        if finalEnd == nil, let start = finalStart {
            // Calculate end time based on start + duration
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            if let startDate = formatter.date(from: start) {
                let endDate = startDate.addingTimeInterval(TimeInterval(duration * 60))
                finalEnd = formatter.string(from: endDate)
            }
        }

        do {
            print("[CalendarViewModel] Creating task: \(title), date: \(taskDate), start: \(finalStart ?? "nil"), end: \(finalEnd ?? "nil"), timeBlock: \(timeBlock)")
            let createdTask = try await calendarService.createTask(
                questId: questId,
                areaId: areaId,
                title: title,
                description: description,
                date: taskDate,
                scheduledStart: finalStart,
                scheduledEnd: finalEnd,
                timeBlock: timeBlock,
                estimatedMinutes: estimatedMinutes ?? duration,
                priority: priority
            )
            print("[CalendarViewModel] Task created successfully: id=\(createdTask.id)")

            // Add to AppStore for Dashboard sync
            store.upcomingWeekTasks.append(createdTask)

            // Check if it's today's task
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayStr = dateFormatter.string(from: Date())
            if createdTask.date == todayStr {
                store.todaysTasks.append(createdTask)
            }

            // Reload week data to get proper task with all fields from server
            await loadWeekData()
        } catch {
            print("[CalendarViewModel] ERROR creating task: \(error)")
            handleError(error, context: "creating task")
        }
    }

    func toggleTask(_ taskId: String) async {
        // Try to find task in both arrays
        guard let task = tasks.first(where: { $0.id == taskId }) ?? weekTasks.first(where: { $0.id == taskId }) else { return }

        let wasCompleted = task.isCompleted
        let newStatus = wasCompleted ? "pending" : "completed"
        let newCompletedAt: Date? = wasCompleted ? nil : Date()

        // Optimistic update - change UI immediately (local CalendarViewModel)
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].status = newStatus
            tasks[index].completedAt = newCompletedAt
        }
        if let index = weekTasks.firstIndex(where: { $0.id == taskId }) {
            weekTasks[index].status = newStatus
            weekTasks[index].completedAt = newCompletedAt
        }
        updateDayProgress()

        // Optimistic update - sync with AppStore for Dashboard
        if let index = store.todaysTasks.firstIndex(where: { $0.id == taskId }) {
            store.todaysTasks[index].status = newStatus
            store.todaysTasks[index].completedAt = newCompletedAt
        }
        if let index = store.upcomingWeekTasks.firstIndex(where: { $0.id == taskId }) {
            store.upcomingWeekTasks[index].status = newStatus
            store.upcomingWeekTasks[index].completedAt = newCompletedAt
        }

        // Sync with server via SyncManager (handles offline queue and retry)
        if wasCompleted {
            await SyncManager.shared.uncompleteTask(id: taskId)
        } else {
            await SyncManager.shared.completeTask(id: taskId)
        }
    }

    func rescheduleTask(_ taskId: String, date: String, scheduledStart: String?, scheduledEnd: String?) async {
        do {
            let updated = try await calendarService.rescheduleTask(
                id: taskId,
                date: date,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd
            )

            // Update local CalendarViewModel
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index] = updated
            }
            if let index = weekTasks.firstIndex(where: { $0.id == taskId }) {
                weekTasks[index] = updated
            }

            // Update AppStore for Dashboard sync
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayStr = dateFormatter.string(from: Date())

            // Update or remove from todaysTasks based on new date
            if updated.date == todayStr {
                if let index = store.todaysTasks.firstIndex(where: { $0.id == taskId }) {
                    store.todaysTasks[index] = updated
                } else {
                    store.todaysTasks.append(updated)
                }
            } else {
                store.todaysTasks.removeAll { $0.id == taskId }
            }

            // Update upcomingWeekTasks
            if let index = store.upcomingWeekTasks.firstIndex(where: { $0.id == taskId }) {
                store.upcomingWeekTasks[index] = updated
            }
        } catch {
            handleError(error, context: "rescheduling task")
        }
    }

    func deleteTask(_ taskId: String) async {
        do {
            try await calendarService.deleteTask(id: taskId)

            // Remove from local CalendarViewModel
            tasks.removeAll { $0.id == taskId }
            weekTasks.removeAll { $0.id == taskId }
            updateDayProgress()

            // Remove from AppStore for Dashboard sync
            store.todaysTasks.removeAll { $0.id == taskId }
            store.upcomingWeekTasks.removeAll { $0.id == taskId }
        } catch {
            handleError(error, context: "deleting task")
        }
    }

    // MARK: - Helpers
    private func updateDayProgress() {
        if tasks.isEmpty {
            dayProgress = 0
        } else {
            dayProgress = (completedTasksCount * 100) / totalTasksCount
        }
    }

    private func handleError(_ error: Error, context: String) {
        print("❌ Calendar error (\(context)): \(error.localizedDescription)")

        if let apiError = error as? APIError {
            errorMessage = apiError.errorDescription
        } else {
            errorMessage = "Failed \(context): \(error.localizedDescription)"
        }

        showError = true
    }
}

// MARK: - Date Extension
extension Date {
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
}

// MARK: - Conversation Message
struct ConversationMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}
