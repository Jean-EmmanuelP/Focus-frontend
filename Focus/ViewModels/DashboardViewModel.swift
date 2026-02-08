import SwiftUI
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    // Reference to the shared store
    private var store: FocusAppStore { FocusAppStore.shared }
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State (mirror from store)
    @Published var isLoading: Bool = false
    @Published var user: User?
    @Published var rituals: [DailyRitual] = []
    @Published var weeklyProgress: [DayProgress] = []
    @Published var eveningReview: EveningReview?
    @Published var morningCheckIn: MorningCheckIn?
    @Published var todaysSessions: [FocusSession] = []
    @Published var weekSessions: [FocusSession] = []
    @Published var quests: [Quest] = []
    @Published var todaysTasks: [CalendarTask] = []
    @Published var upcomingWeekTasks: [CalendarTask] = []

    // MARK: - Journal State
    @Published var todayJournalEntry: JournalEntryResponse?
    @Published var recentJournalEntries: [JournalEntryResponse] = []
    @Published var journalStreak: Int = 0
    @Published var isLoadingJournal: Bool = false

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Sync with store
        store.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        store.$user
            .receive(on: DispatchQueue.main)
            .assign(to: &$user)

        store.$rituals
            .receive(on: DispatchQueue.main)
            .assign(to: &$rituals)

        store.$weeklyProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$weeklyProgress)

        store.$eveningReview
            .receive(on: DispatchQueue.main)
            .assign(to: &$eveningReview)

        store.$morningCheckIn
            .receive(on: DispatchQueue.main)
            .assign(to: &$morningCheckIn)

        store.$todaysSessions
            .receive(on: DispatchQueue.main)
            .assign(to: &$todaysSessions)

        store.$weekSessions
            .receive(on: DispatchQueue.main)
            .assign(to: &$weekSessions)

        store.$quests
            .receive(on: DispatchQueue.main)
            .assign(to: &$quests)

        store.$todaysTasks
            .receive(on: DispatchQueue.main)
            .assign(to: &$todaysTasks)

        store.$upcomingWeekTasks
            .receive(on: DispatchQueue.main)
            .assign(to: &$upcomingWeekTasks)
    }

    // MARK: - Week Properties
    /// Get the start of the current week (Monday)
    var weekStartDate: Date {
        let calendar = Calendar(identifier: .iso8601) // ISO8601 starts week on Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? Date()
    }

    /// Get the end of the current week (Sunday)
    var weekEndDate: Date {
        let calendar = Calendar(identifier: .iso8601)
        return calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? Date()
    }

    /// Formatted week range string
    var weekRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: weekStartDate)
        let end = formatter.string(from: weekEndDate)
        return "\(start) - \(end)"
    }

    /// Sessions filtered for the current week (Monday to Sunday)
    var thisWeekSessions: [FocusSession] {
        let calendar = Calendar(identifier: .iso8601)
        return weekSessions.filter { session in
            session.startTime >= weekStartDate && session.startTime <= calendar.date(byAdding: .day, value: 7, to: weekStartDate)!
        }.sorted { $0.startTime > $1.startTime } // Most recent first
    }

    /// Group sessions by day
    var sessionsByDay: [(date: Date, sessions: [FocusSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: thisWeekSessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, sessions: $0.value) }
    }

    /// Total planned minutes this week
    var totalMinutesThisWeek: Int {
        thisWeekSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Total actual minutes this week (based on completed_at - started_at)
    var totalActualMinutesThisWeek: Int {
        thisWeekSessions.reduce(0) { $0 + $1.actualDurationMinutes }
    }

    /// Total sessions this week
    var totalSessionsThisWeek: Int {
        thisWeekSessions.count
    }

    // MARK: - Morning Check-In Properties
    var hasMorningCheckIn: Bool {
        morningCheckIn != nil
    }

    var morningFeeling: Feeling? {
        morningCheckIn?.feeling
    }

    var morningIntentions: [DailyIntention] {
        morningCheckIn?.intentions ?? []
    }

    // Aliases for Dashboard display
    var todaysIntentions: [DailyIntention] {
        morningIntentions
    }

    var todaysFeeling: Feeling? {
        morningFeeling
    }

    // MARK: - Reflection Properties (Evening Review)
    var hasReflection: Bool {
        eveningReview != nil
    }

    var reflectionBiggestWin: String? {
        eveningReview?.biggestWin
    }

    var reflectionBestMoment: String? {
        eveningReview?.bestMoment
    }

    var reflectionTomorrowGoal: String? {
        eveningReview?.tomorrowGoal
    }

    // MARK: - Computed Properties
    var currentStreak: Int {
        store.currentStreak
    }

    var flameLevels: [FlameLevel] {
        store.streakData?.flameLevels ?? []
    }

    var currentFlameLevel: Int {
        store.streakData?.currentFlameLevel ?? 1
    }

    var todayValidation: DayValidationResponse? {
        store.streakData?.todayValidation
    }

    var streakStartDate: String {
        // Use streak start date from API if available
        if let streakStart = store.streakStartDateString {
            // Convert from "YYYY-MM-DD" to "dd/MM"
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "yyyy-MM-dd"
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd/MM"

            if let date = inputFormatter.date(from: streakStart) {
                return outputFormatter.string(from: date)
            }
        }

        // Fallback: calculate from current streak
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"

        if currentStreak > 0 {
            let startDate = calendar.date(byAdding: .day, value: -(currentStreak - 1), to: Date()) ?? Date()
            return formatter.string(from: startDate)
        }
        // If streak is 0, show today's date
        return formatter.string(from: Date())
    }

    var focusedMinutesToday: Int {
        store.focusedMinutesToday
    }

    /// Rituals for today (already filtered by backend via todays_routines)
    /// Note: The backend already returns only the routines that should be shown today
    var todaysRituals: [DailyRitual] {
        rituals // Backend already filters by today's date and frequency
    }

    var completedRitualsCount: Int {
        todaysRituals.filter { $0.isCompleted }.count
    }

    var totalRitualsCount: Int {
        todaysRituals.count
    }

    // MARK: - Tasks Progress
    var completedTasksCount: Int {
        todaysTasks.filter { $0.isCompleted }.count
    }

    var totalTasksCount: Int {
        todaysTasks.count
    }

    // MARK: - Active Quests (top 3 by progress)
    var activeQuests: [Quest] {
        quests
            .filter { $0.status == .active }
            .sorted { $0.progress > $1.progress }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Daily Progress (Tasks + Rituals combined)
    var totalDailyItems: Int {
        totalRitualsCount + totalTasksCount
    }

    var completedDailyItems: Int {
        completedRitualsCount + completedTasksCount
    }

    var dailyProgressPercentage: Double {
        guard totalDailyItems > 0 else { return 0 }
        return Double(completedDailyItems) / Double(totalDailyItems)
    }

    var dailyProgressDisplay: String {
        "\(completedDailyItems)/\(totalDailyItems)"
    }

    /// Accountability check: User is accountable if they set intentions AND completed at least 40% of rituals
    var isTodayAccountable: Bool {
        // Must have done morning check-in (set intentions)
        guard store.hasDoneMorningCheckIn else { return false }

        // If no rituals, just having intentions is enough
        guard totalRitualsCount > 0 else { return true }

        // Must complete at least 40% of rituals
        let completionRate = Double(completedRitualsCount) / Double(totalRitualsCount)
        return completionRate >= 0.4
    }

    var hasSessionsThisWeek: Bool {
        !weeklyProgress.isEmpty && weeklyProgress.contains { $0.minutes > 0 }
    }

    var adaptiveCTA: AdaptiveCTA {
        if !store.hasDoneMorningCheckIn {
            return .startTheDay
        } else if !store.hasDoneEveningReview {
            return .endOfDay
        } else {
            return .allCompleted
        }
    }

    // MARK: - Upcoming Tasks
    /// Get all uncompleted tasks from today onwards, sorted by date then time
    /// - For today: only show tasks that haven't ended yet
    /// - For future days: show all uncompleted tasks
    var upcomingTasks: [CalendarTask] {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeString = String(format: "%02d:%02d", currentHour, currentMinute)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: now)

        return upcomingWeekTasks
            .filter { task in
                // Filter out completed tasks
                guard !task.isCompleted else { return false }

                // For today's tasks: filter by time (only show tasks that haven't ended yet)
                if task.date == todayStr {
                    // If task has no scheduled end, include it
                    guard let scheduledEnd = task.scheduledEnd else { return true }
                    // Include tasks that haven't ended yet
                    return scheduledEnd > currentTimeString
                }

                // For future tasks: include all uncompleted tasks
                return true
            }
            .sorted { task1, task2 in
                // First sort by date
                if task1.date != task2.date {
                    return task1.date < task2.date
                }
                // Then by start time
                guard let start1 = task1.scheduledStart,
                      let start2 = task2.scheduledStart else {
                    return task1.scheduledStart != nil
                }
                return start1 < start2
            }
    }

    // MARK: - Next Task
    /// Get the next uncompleted task based on scheduled time
    var nextTask: CalendarTask? {
        upcomingTasks.first
    }

    /// Check if user has done morning check-in
    var hasStartedDay: Bool {
        store.hasDoneMorningCheckIn
    }

    // MARK: - Actions
    func refreshDashboard() async {
        await store.refresh()
    }

    func toggleRitual(_ ritual: DailyRitual) async {
        await store.toggleRitual(ritual)
    }

    // MARK: - Session Actions
    private let sessionService = FocusSessionService()

    func editSession(id: String, description: String?, durationMinutes: Int?) async {
        do {
            let response = try await sessionService.editSession(id: id, description: description, durationMinutes: durationMinutes)
            // Optimistic update - update session in store directly
            if let index = store.weekSessions.firstIndex(where: { $0.id == id }) {
                store.weekSessions[index] = FocusSession(from: response)
            }
            if let index = store.todaysSessions.firstIndex(where: { $0.id == id }) {
                store.todaysSessions[index] = FocusSession(from: response)
            }
        } catch {
            print("❌ Failed to edit session: \(error)")
        }
    }

    func deleteSession(id: String) async {
        // Store original sessions for rollback
        let originalWeekSessions = store.weekSessions
        let originalTodaysSessions = store.todaysSessions

        // Optimistic delete
        store.weekSessions.removeAll { $0.id == id }
        store.todaysSessions.removeAll { $0.id == id }

        do {
            try await sessionService.deleteSession(id: id)
        } catch {
            // Rollback on error
            store.weekSessions = originalWeekSessions
            store.todaysSessions = originalTodaysSessions
            print("❌ Failed to delete session: \(error)")
        }
    }

    // MARK: - Avatar Actions
    private let userService = UserService()

    func uploadAvatar(imageData: Data) async {
        do {
            let avatarUrl = try await userService.uploadAvatar(imageData: imageData)
            // Update local user with new avatar URL + cache-bust parameter to force refresh
            if var updatedUser = store.user {
                // Add timestamp to bust AsyncImage cache
                let cacheBustUrl = avatarUrl.contains("?")
                    ? "\(avatarUrl)&v=\(Int(Date().timeIntervalSince1970))"
                    : "\(avatarUrl)?v=\(Int(Date().timeIntervalSince1970))"
                updatedUser.avatarURL = cacheBustUrl
                store.user = updatedUser
            }
        } catch {
            print("❌ Failed to upload avatar: \(error)")
        }
    }

    func deleteAvatar() async {
        do {
            try await userService.deleteAvatar()
            // Update local user to remove avatar URL (no full refresh needed)
            if var updatedUser = store.user {
                updatedUser.avatarURL = nil
                store.user = updatedUser
            }
        } catch {
            print("❌ Failed to delete avatar: \(error)")
        }
    }

    // MARK: - Journal Actions
    private let journalService = JournalService()

    /// Load journal data (today's entry, recent entries, streak)
    func loadJournalData() async {
        isLoadingJournal = true

        async let todayTask: () = loadTodayEntry()
        async let recentTask: () = loadRecentEntries()
        async let streakTask: () = loadJournalStreak()

        _ = await (todayTask, recentTask, streakTask)

        isLoadingJournal = false
    }

    private func loadTodayEntry() async {
        do {
            todayJournalEntry = try await journalService.fetchTodayEntry()
        } catch {
            // 404 is expected if no entry today
            todayJournalEntry = nil
        }
    }

    private func loadRecentEntries() async {
        do {
            let response = try await journalService.fetchEntries(limit: 7, offset: 0)
            recentJournalEntries = response.entries
        } catch {
            print("❌ Failed to load recent journal entries: \(error)")
        }
    }

    private func loadJournalStreak() async {
        do {
            journalStreak = try await journalService.fetchStreak()
        } catch {
            print("❌ Failed to load journal streak: \(error)")
        }
    }

    /// Called when a new journal entry is saved
    func onJournalEntrySaved(_ entry: JournalEntryResponse) {
        todayJournalEntry = entry
        // Add to recent entries if not already present
        if !recentJournalEntries.contains(where: { $0.id == entry.id }) {
            recentJournalEntries.insert(entry, at: 0)
            // Keep only last 7
            if recentJournalEntries.count > 7 {
                recentJournalEntries = Array(recentJournalEntries.prefix(7))
            }
        }
        // Refresh streak
        Task {
            await loadJournalStreak()
        }
    }

    /// Delete today's journal entry
    func deleteTodayJournalEntry() async {
        guard let entry = todayJournalEntry else { return }

        do {
            try await journalService.deleteEntry(id: entry.id)
            todayJournalEntry = nil
            recentJournalEntries.removeAll { $0.id == entry.id }
            await loadJournalStreak()
        } catch {
            print("❌ Failed to delete journal entry: \(error)")
        }
    }

    /// Check if user has journaled today
    var hasJournaledToday: Bool {
        todayJournalEntry != nil
    }

    /// Get mood data points for graph
    var journalMoodData: [MoodDataPoint] {
        recentJournalEntries.compactMap { entry -> MoodDataPoint? in
            guard let score = entry.moodScore else { return nil }
            return MoodDataPoint(date: entry.entryDate, score: score, mood: entry.mood)
        }.reversed()
    }

    // MARK: - Profile Update
    func updateProfile(
        pseudo: String?,
        firstName: String?,
        lastName: String?,
        gender: String?,
        age: Int?,
        description: String?,
        hobbies: String?,
        lifeGoal: String?
    ) async {
        do {
            let response = try await userService.updateProfile(
                pseudo: pseudo,
                firstName: firstName,
                lastName: lastName,
                gender: gender,
                age: age,
                description: description,
                hobbies: hobbies,
                lifeGoal: lifeGoal
            )
            // Update store user directly (no full refresh needed)
            store.user = User(from: response)
        } catch {
            print("❌ Failed to update profile: \(error)")
        }
    }

    // MARK: - Intentions Update
    private let intentionsService = IntentionsService()

    func updateIntentions(_ edits: [(id: String, text: String, area: QuestArea)]) async {
        guard let checkIn = store.morningCheckIn else { return }

        // Build new intentions array
        let intentionInputs = edits.compactMap { edit -> IntentionInput? in
            guard !edit.text.isEmpty else { return nil }
            return IntentionInput(
                areaId: nil,
                content: "\(edit.area.emoji) \(edit.text)"
            )
        }

        // Re-save with updated intentions
        do {
            _ = try await intentionsService.saveIntentions(
                date: Date(),
                moodRating: feelingToMoodRating(checkIn.feeling),
                moodEmoji: checkIn.feeling.rawValue,
                sleepRating: (checkIn.sleepQuality + 1) / 2,
                sleepEmoji: sleepEmoji(for: checkIn.sleepQuality),
                intentions: intentionInputs
            )

            // Update local store (include emoji prefix for display consistency)
            let updatedIntentions = edits.enumerated().compactMap { index, edit -> DailyIntention? in
                guard !edit.text.isEmpty else { return nil }
                return DailyIntention(
                    id: edit.id,
                    userId: store.authUserId ?? "",
                    date: Date(),
                    intention: "\(edit.area.emoji) \(edit.text)",
                    area: edit.area,
                    isCompleted: checkIn.intentions.first(where: { $0.id == edit.id })?.isCompleted ?? false
                )
            }

            store.morningCheckIn = MorningCheckIn(
                id: checkIn.id,
                userId: checkIn.userId,
                date: checkIn.date,
                feeling: checkIn.feeling,
                feelingNote: checkIn.feelingNote,
                sleepQuality: checkIn.sleepQuality,
                sleepNote: checkIn.sleepNote,
                intentions: updatedIntentions
            )

            print("✅ Intentions updated successfully")
        } catch {
            print("❌ Failed to update intentions: \(error)")
        }
    }

    private func feelingToMoodRating(_ feeling: Feeling) -> Int {
        switch feeling {
        case .happy, .excited: return 5
        case .calm: return 4
        case .neutral: return 3
        case .tired, .anxious: return 2
        case .sad, .frustrated: return 1
        }
    }

    private func sleepEmoji(for quality: Int) -> String {
        switch quality {
        case 1...3: return "😴"
        case 4...5: return "😐"
        case 6...7: return "🙂"
        case 8...9: return "😊"
        case 10: return "🌟"
        default: return "😴"
        }
    }
}

// MARK: - Adaptive CTA Model
enum AdaptiveCTA {
    case startTheDay
    case endOfDay
    case allCompleted

    var title: String {
        switch self {
        case .startTheDay:
            return "cta.start_day.title".localized
        case .endOfDay:
            return "cta.end_day.title".localized
        case .allCompleted:
            return "cta.completed.title".localized
        }
    }

    var subtitle: String {
        switch self {
        case .startTheDay:
            return "cta.start_day.subtitle".localized
        case .endOfDay:
            return "cta.end_day.subtitle".localized
        case .allCompleted:
            return "cta.completed.subtitle".localized
        }
    }

    var buttonTitle: String {
        switch self {
        case .startTheDay:
            return "cta.start_day.button".localized
        case .endOfDay:
            return "cta.end_day.button".localized
        case .allCompleted:
            return "cta.completed.button".localized
        }
    }

    var icon: String? {
        switch self {
        case .startTheDay:
            return "☀️"
        case .endOfDay:
            return "🌙"
        case .allCompleted:
            return nil
        }
    }

    var isCompleted: Bool {
        self == .allCompleted
    }
}
