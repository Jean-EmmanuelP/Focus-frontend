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
    var levelProgress: Double {
        store.levelProgress
    }

    var currentStreak: Int {
        store.currentStreak
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

    var hasSessionsThisWeek: Bool {
        !weeklyProgress.isEmpty && weeklyProgress.contains { $0.minutes > 0 }
    }

    var adaptiveCTA: AdaptiveCTA {
        if !store.hasDoneMorningCheckIn {
            return .startTheDay
        } else if store.todaySessionsCount == 0 {
            return .startFireMode
        } else if !store.hasDoneEveningReview {
            return .endOfDay
        } else {
            return .allCompleted
        }
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
            _ = try await sessionService.editSession(id: id, description: description, durationMinutes: durationMinutes)
            // Refresh to get updated sessions
            await store.refresh()
        } catch {
            print("❌ Failed to edit session: \(error)")
        }
    }

    func deleteSession(id: String) async {
        do {
            try await sessionService.deleteSession(id: id)
            // Refresh to get updated sessions
            await store.refresh()
        } catch {
            print("❌ Failed to delete session: \(error)")
        }
    }

    // MARK: - Avatar Actions
    private let userService = UserService()

    func uploadAvatar(imageData: Data) async {
        do {
            let avatarUrl = try await userService.uploadAvatar(imageData: imageData)
            // Update local user with new avatar URL
            if var updatedUser = user {
                updatedUser.avatarURL = avatarUrl
                user = updatedUser
            }
            // Refresh to get updated user from server
            await store.refresh()
        } catch {
            print("❌ Failed to upload avatar: \(error)")
        }
    }

    func deleteAvatar() async {
        do {
            try await userService.deleteAvatar()
            // Update local user to remove avatar URL
            if var updatedUser = user {
                updatedUser.avatarURL = nil
                user = updatedUser
            }
            // Refresh to get updated user from server
            await store.refresh()
        } catch {
            print("❌ Failed to delete avatar: \(error)")
        }
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
            // Update local user with response
            user = User(from: response)
            // Refresh to sync with store
            await store.refresh()
        } catch {
            print("❌ Failed to update profile: \(error)")
        }
    }
}

// MARK: - Adaptive CTA Model
enum AdaptiveCTA {
    case startTheDay
    case startFireMode
    case endOfDay
    case allCompleted

    var title: String {
        switch self {
        case .startTheDay:
            return "Start your day right"
        case .startFireMode:
            return "Start a FireMode session"
        case .endOfDay:
            return "Complete your End of Day review"
        case .allCompleted:
            return "You're all set for today 🔥"
        }
    }

    var subtitle: String {
        switch self {
        case .startTheDay:
            return "Complete your morning check-in"
        case .startFireMode:
            return "Launch your first focus session"
        case .endOfDay:
            return "Reflect and close your day"
        case .allCompleted:
            return "Great work. Rest and prepare for tomorrow."
        }
    }

    var buttonTitle: String {
        switch self {
        case .startTheDay:
            return "Start the Day"
        case .startFireMode:
            return "Enter FireMode"
        case .endOfDay:
            return "End of Day Review"
        case .allCompleted:
            return "View Progress"
        }
    }

    var icon: String? {
        switch self {
        case .startTheDay:
            return "☀️"
        case .startFireMode:
            return "🔥"
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
