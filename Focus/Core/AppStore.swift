import SwiftUI
import Combine
import WidgetKit

/// Global App Store - Single source of truth
@MainActor
final class FocusAppStore: ObservableObject {
    static let shared = FocusAppStore()

    // MARK: - Authentication State
    @Published var isAuthenticated = false
    @Published var authUserId: String?
    @Published var hasCompletedOnboarding = false
    @Published var isCheckingOnboarding = false
    private var hasLoadedInitialData = false
    private var isCurrentlyLoadingData = false  // Prevents concurrent loads

    // MARK: - UserDefaults Keys for Onboarding Cache
    private let onboardingCompletedKey = "volta_onboarding_completed"
    private let onboardingUserIdKey = "volta_onboarding_user_id"

    // MARK: - Published State
    @Published var user: User?
    @Published var todaysSessions: [FocusSession] = []
    @Published var weekSessions: [FocusSession] = []
    @Published var rituals: [DailyRitual] = []
    @Published var quests: [Quest] = []
    @Published var todaysTasks: [CalendarTask] = []
    @Published var morningCheckIn: MorningCheckIn?
    @Published var eveningReview: EveningReview?
    @Published var isLoading = false

    // MARK: - Computed Properties
    var hasDoneMorningCheckIn: Bool {
        morningCheckIn != nil
    }

    var hasDoneEveningReview: Bool {
        eveningReview != nil
    }

    var todaySessionsCount: Int {
        todaysSessions.count
    }

    var todayMinutes: Int {
        // Use actual duration (completed_at - started_at), not planned duration
        stats?.focusedToday ?? todaysSessions.reduce(0) { $0 + $1.actualDurationMinutes }
    }

    var focusedMinutesToday: Int {
        todayMinutes
    }

    var currentStreak: Int {
        streakData?.currentStreak ?? stats?.streakDays ?? user?.currentStreak ?? 0
    }

    var streakStartDateString: String? {
        streakData?.streakStart
    }

    // MARK: - API Data
    @Published var areas: [Area] = placeholderAreas
    @Published var weeklyProgress: [DayProgress] = []
    @Published var stats: DashboardStats?
    @Published var firemodeStats: FiremodeResponse?
    @Published var streakData: StreakResponse?
    @Published var areasLoaded = false

    // MARK: - Data Loading Timestamps (for caching)
    private var lastDashboardLoad: Date?
    private var lastFiremodeLoad: Date?
    private let cacheValiditySeconds: TimeInterval = 60 // 1 minute cache

    // MARK: - Services
    private let dashboardService = DashboardService()
    private let sessionService = FocusSessionService()
    private let questService = QuestService()
    private let routineService = RoutineService()
    private let reflectionService = ReflectionService()
    private let intentionsService = IntentionsService()
    private let areasService = AreasService()
    private let completionsService = CompletionsService()
    private let streakService = StreakService()
    private let onboardingService = OnboardingService()
    private let calendarService = CalendarService()

    // Default area definitions (for creating if none exist)
    private static let defaultAreaDefinitions: [(name: String, slug: String, icon: String)] = [
        ("Health", "health", "💪"),
        ("Career", "career", "💼"),
        ("Learning", "learning", "📚"),
        ("Relationships", "relationships", "❤️"),
        ("Creativity", "creativity", "🎨"),
        ("Finance", "finance", "💰")
    ]

    // Placeholder areas shown before API loads (won't be used for creating routines)
    private static let placeholderAreas: [Area] = [
        Area(id: "placeholder-health", name: "Health", slug: "health", icon: "💪", completeness: nil),
        Area(id: "placeholder-career", name: "Career", slug: "career", icon: "💼", completeness: nil),
        Area(id: "placeholder-learning", name: "Learning", slug: "learning", icon: "📚", completeness: nil),
        Area(id: "placeholder-relationships", name: "Relationships", slug: "relationships", icon: "❤️", completeness: nil),
        Area(id: "placeholder-creativity", name: "Creativity", slug: "creativity", icon: "🎨", completeness: nil),
        Area(id: "placeholder-finance", name: "Finance", slug: "finance", icon: "💰", completeness: nil)
    ]

    private init() {
        // Check if user was previously authenticated
        Task {
            await checkExistingSession()
        }
    }

    // MARK: - Authentication Methods
    private func checkExistingSession() async {
        let hasSession = await AuthService.shared.checkSession()
        if hasSession {
            await handleAuthServiceUpdate()
        }
    }

    /// Handle authentication from AuthService (async version - waits for onboarding check)
    /// Call this after sign-in to check onboarding status before UI updates
    func handleAuthServiceUpdate() async {
        let authService = AuthService.shared

        guard let userId = authService.userId else {
            return
        }

        // Skip if already authenticated with the same user AND onboarding already checked
        if self.isAuthenticated && self.authUserId == userId && self.hasLoadedInitialData && !self.isCheckingOnboarding {
            print("🔄 handleAuthServiceUpdate: Already loaded, skipping")
            return
        }

        print("🔐 handleAuthServiceUpdate: Setting up user \(userId)")
        self.authUserId = userId
        self.isAuthenticated = true

        // CRITICAL: Set isCheckingOnboarding = true IMMEDIATELY to prevent flash of OnboardingView
        self.isCheckingOnboarding = true

        // Create local user object from AuthService data
        self.user = User(
            id: userId,
            pseudo: authService.userName,
            firstName: nil,
            lastName: nil,
            email: authService.userEmail ?? "",
            avatarURL: nil,
            gender: nil,
            age: nil,
            description: nil,
            hobbies: nil,
            lifeGoal: nil,
            dayVisibility: nil,
            currentStreak: 0,
            longestStreak: 0
        )

        // Check onboarding status from cache/API (await - blocks until done)
        await checkOnboardingStatus()

        // Only load initial data if onboarding is completed
        if hasCompletedOnboarding && !hasLoadedInitialData {
            await loadInitialData()
        }
    }

    func signInAsGuest() {
        // Guest mode for testing
        self.authUserId = "guest"
        self.isAuthenticated = true

        self.user = User(
            id: "guest",
            pseudo: "Guest",
            firstName: nil,
            lastName: nil,
            email: "",
            avatarURL: nil,
            gender: nil,
            age: nil,
            description: nil,
            hobbies: nil,
            lifeGoal: nil,
            dayVisibility: nil,
            currentStreak: 0,
            longestStreak: 0
        )

        // Load mock data
        Task {
            await loadInitialData()
        }
    }

    func signOut() {
        Task {
            do {
                try await AuthService.shared.signOut()
            } catch {
                print("Error signing out: \(error)")
            }

            // Clear onboarding cache for this user
            UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
            UserDefaults.standard.removeObject(forKey: onboardingUserIdKey)

            // Reset state regardless of sign out result
            self.authUserId = nil
            self.isAuthenticated = false
            self.hasCompletedOnboarding = false
            self.hasLoadedInitialData = false
            self.isCurrentlyLoadingData = false
            self.lastDashboardLoad = nil
            self.user = nil
            self.todaysSessions = []
            self.weekSessions = []
            self.rituals = []
            self.quests = []
            self.morningCheckIn = nil
            self.eveningReview = nil
            self.areas = Self.placeholderAreas
            self.areasLoaded = false
            self.stats = nil
            self.weeklyProgress = []
            print("🔓 User signed out, state reset (onboarding cache cleared)")
        }
    }

    // MARK: - Onboarding
    /// Check onboarding status - first from local cache, then from backend
    func checkOnboardingStatus() async {
        isCheckingOnboarding = true

        // 1. Check local cache first (for same user)
        let cachedUserId = UserDefaults.standard.string(forKey: onboardingUserIdKey)
        let cachedCompleted = UserDefaults.standard.bool(forKey: onboardingCompletedKey)

        if let currentUserId = authUserId,
           cachedUserId == currentUserId,
           cachedCompleted {
            // User has completed onboarding according to local cache
            hasCompletedOnboarding = true
            isCheckingOnboarding = false
            print("📋 Onboarding status from cache: completed=true (user: \(currentUserId))")
            return
        }

        // 2. Check backend
        print("📋 Checking onboarding status for user: \(authUserId ?? "nil")")
        do {
            let status = try await onboardingService.getStatus()
            hasCompletedOnboarding = status.isCompleted

            // Update local cache if completed
            if status.isCompleted, let currentUserId = authUserId {
                UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
                UserDefaults.standard.set(currentUserId, forKey: onboardingUserIdKey)
            }

            print("📋 Onboarding status from API: completed=\(status.isCompleted), step=\(status.currentStep), completedAt=\(String(describing: status.completedAt))")
        } catch {
            // On error, check if we have local cache for this user
            if let currentUserId = authUserId,
               cachedUserId == currentUserId,
               cachedCompleted {
                hasCompletedOnboarding = true
                print("⚠️ API error but local cache says completed: \(error)")
            } else {
                // No cache, assume not completed (new user)
                hasCompletedOnboarding = false
                print("⚠️ Error checking onboarding status (no cache): \(error)")
            }
        }
        isCheckingOnboarding = false
    }

    /// Mark onboarding as completed and load initial data
    func completeOnboarding() async {
        print("🚀 completeOnboarding: Starting...")

        // 1. Save to local cache FIRST (ensures we don't get stuck)
        if let currentUserId = authUserId {
            UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
            UserDefaults.standard.set(currentUserId, forKey: onboardingUserIdKey)
            print("💾 Onboarding saved to local cache for user: \(currentUserId)")
        }

        // 2. Mark as complete in memory
        hasCompletedOnboarding = true

        // 3. Try to sync with backend (but don't block on failure)
        do {
            print("🚀 completeOnboarding: Calling API...")
            let response = try await onboardingService.completeOnboarding()
            print("🚀 completeOnboarding: API response - isCompleted=\(response.isCompleted)")
            print("✅ Onboarding marked as complete (API + local)")
        } catch {
            print("⚠️ Error syncing onboarding to API (local cache saved): \(error)")
            // Don't worry - local cache is already saved
        }

        // 4. Load initial data for the dashboard
        print("🚀 completeOnboarding: Loading initial data...")
        await loadInitialData(force: true)
        print("🚀 completeOnboarding: Done!")
    }

    // MARK: - Load Data
    func loadInitialData(force: Bool = false) async {
        // CRITICAL: Prevent concurrent loads (race condition fix)
        if isCurrentlyLoadingData {
            print("📦 loadInitialData: Already loading, skipping duplicate call")
            return
        }

        // Skip if already loaded (unless forced)
        if !force && hasLoadedInitialData {
            print("📦 loadInitialData: Already loaded, skipping (use force: true to reload)")
            return
        }

        // Skip if data is still fresh (unless forced)
        if !force, let lastLoad = lastDashboardLoad,
           Date().timeIntervalSince(lastLoad) < cacheValiditySeconds {
            print("📦 loadInitialData: Cache still valid, skipping")
            return
        }

        // Mark as loading IMMEDIATELY to prevent race conditions
        isCurrentlyLoadingData = true
        print("📦 loadInitialData: Starting data load (force: \(force))")
        isLoading = true

        do {
            let dashboardData = try await dashboardService.fetchDashboardData()
            lastDashboardLoad = Date()
            print("✅ Dashboard data loaded successfully")

            // Convert API responses to frontend models
            print("👤 Dashboard user data: id=\(dashboardData.user.id), email=\(dashboardData.user.email ?? "nil"), pseudo=\(dashboardData.user.pseudo ?? "nil"), avatarUrl=\(dashboardData.user.avatarUrl ?? "nil")")
            self.user = User(from: dashboardData.user)
            self.user?.currentStreak = dashboardData.stats.streakDays
            print("👤 User model created: name=\(self.user?.name ?? "nil"), avatarURL=\(self.user?.avatarURL ?? "nil")")

            // Handle areas - create defaults if none exist
            if dashboardData.areas.isEmpty {
                print("📦 No areas found, creating defaults...")
                await createDefaultAreas()
            } else {
                self.areas = dashboardData.areas
                self.areasLoaded = true
                print("📦 Areas loaded: \(self.areas.count)")
            }

            // Convert quests (optional field)
            if let activeQuests = dashboardData.activeQuests {
                self.quests = activeQuests.map { questResponse in
                    let area = self.areas.first { $0.id == questResponse.areaId }
                    return Quest(from: questResponse, area: area)
                }
                print("🎯 Quests loaded: \(self.quests.count)")
            }

            // Convert routines to rituals
            print("📋 Dashboard todaysRoutines count: \(dashboardData.todaysRoutines.count)")
            for routine in dashboardData.todaysRoutines {
                print("  - Routine: \(routine.title), frequency: \(routine.frequency), completed: \(routine.completed ?? false)")
            }
            self.rituals = dashboardData.todaysRoutines.map { DailyRitual(from: $0) }
            print("📋 Rituals array count after mapping: \(self.rituals.count)")

            // Convert weekly progress from week_sessions.days
            self.weeklyProgress = dashboardData.weekSessions.days.map { DayProgress(from: $0) }
            print("📊 Week sessions: \(dashboardData.weekSessions.totalSessions) sessions, \(dashboardData.weekSessions.totalMinutes) min")

            // Extract individual sessions if available from dashboard
            if let sessions = dashboardData.weekSessions.sessions {
                let calendar = Calendar(identifier: .iso8601)
                let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
                let weekStart = calendar.date(from: weekComponents) ?? Date()
                self.weekSessions = sessions
                    .map { FocusSession(from: $0) }
                    .filter { $0.startTime >= weekStart }
                    .sorted { $0.startTime > $1.startTime }
                self.todaysSessions = self.weekSessions.filter { Calendar.current.isDateInToday($0.startTime) }
                print("📊 Individual sessions loaded: \(self.weekSessions.count) this week, \(self.todaysSessions.count) today")
            } else {
                print("📊 No individual sessions in dashboard (summary only)")
            }

            // Store stats
            self.stats = dashboardData.stats
            print("🔥 Stats: \(dashboardData.stats.focusedToday) min today, \(dashboardData.stats.streakDays) day streak")

            // Load streak data from dedicated endpoint
            do {
                let streakResponse = try await streakService.fetchStreak()
                self.streakData = streakResponse
                print("🔥 Streak loaded: current=\(streakResponse.currentStreak), longest=\(streakResponse.longestStreak), start=\(streakResponse.streakStart ?? "nil")")
            } catch {
                print("⚠️ Failed to load streak data: \(error)")
                // Fallback to dashboard stats
            }

            // Use today_intentions from dashboard if available
            if let todayIntentions = dashboardData.todayIntentions {
                print("📝 Today's intentions loaded from dashboard")
                self.morningCheckIn = MorningCheckIn(
                    id: todayIntentions.id,
                    userId: authUserId ?? "",
                    date: Date(),
                    feeling: moodEmojiToFeeling(todayIntentions.moodEmoji),
                    feelingNote: nil,
                    sleepQuality: todayIntentions.sleepRating,
                    sleepNote: nil,
                    intentions: todayIntentions.intentions.map { item in
                        DailyIntention(
                            id: item.id,
                            userId: authUserId ?? "",
                            date: Date(),
                            intention: item.content,
                            area: areaIdToQuestArea(item.areaId),
                            isCompleted: false
                        )
                    }
                )
            } else {
                print("📝 No intentions for today yet")
                self.morningCheckIn = nil
            }

            // Load today's tasks for progress calculation
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let todayStr = dateFormatter.string(from: Date())
                self.todaysTasks = try await calendarService.getTasks(date: todayStr)
                print("📋 Today's tasks loaded: \(self.todaysTasks.count)")
            } catch {
                print("⚠️ Failed to load today's tasks: \(error)")
                self.todaysTasks = []
            }

            // Note: All data now comes from dashboard - no separate calls needed

            hasLoadedInitialData = true
            isCurrentlyLoadingData = false
            isLoading = false
            print("✅ loadInitialData: Complete")

            // Sync widget data after successful load
            syncWidgetData()
        } catch {
            print("❌ Error loading dashboard data: \(error)")
            print("❌ Error details: \(error.localizedDescription)")

            // No fallback - dashboard is the single source of truth
            hasLoadedInitialData = true
            isCurrentlyLoadingData = false
            isLoading = false
        }
    }

    /// Load firemode-specific stats (optimized endpoint)
    func loadFiremodeData(force: Bool = false) async {
        // Skip if data is still fresh (unless forced)
        if !force, let lastLoad = lastFiremodeLoad,
           Date().timeIntervalSince(lastLoad) < cacheValiditySeconds {
            return
        }

        do {
            let firemodeData = try await dashboardService.fetchFiremodeData()
            lastFiremodeLoad = Date()
            self.firemodeStats = firemodeData

            // Also update quests from firemode response (if available)
            if let activeQuests = firemodeData.activeQuests {
                self.quests = activeQuests.map { questResponse in
                    let area = self.areas.first { $0.id == questResponse.areaId }
                    return Quest(from: questResponse, area: area)
                }
            }
        } catch {
            print("Error loading firemode data: \(error)")
        }
    }

    // MARK: - Areas Management
    private func createDefaultAreas() async {
        var createdAreas: [Area] = []

        for definition in Self.defaultAreaDefinitions {
            do {
                let area = try await areasService.createArea(
                    name: definition.name,
                    slug: definition.slug,
                    icon: definition.icon
                )
                createdAreas.append(area)
                print("✅ Created area: \(definition.name)")
            } catch {
                print("⚠️ Failed to create area \(definition.name): \(error)")
                // Continue with other areas
            }
        }

        if !createdAreas.isEmpty {
            self.areas = createdAreas
            self.areasLoaded = true
        }
    }

    func ensureAreasExist() async {
        guard !areasLoaded else { return }

        do {
            let fetchedAreas = try await areasService.fetchAreas()
            if fetchedAreas.isEmpty {
                await createDefaultAreas()
            } else {
                self.areas = fetchedAreas
                self.areasLoaded = true
            }
        } catch {
            print("Error fetching areas: \(error)")
            // Keep placeholder areas but mark as not loaded
        }
    }

    // MARK: - Rituals
    func toggleRitual(_ ritual: DailyRitual) async {
        print("🔄 toggleRitual called for: \(ritual.title)")

        guard let index = rituals.firstIndex(where: { $0.id == ritual.id }) else {
            print("❌ Ritual not found in array!")
            return
        }

        // Optimistic update - no full refresh needed
        let wasCompleted = rituals[index].isCompleted
        rituals[index].isCompleted.toggle()

        do {
            if rituals[index].isCompleted {
                try await routineService.completeRoutine(id: ritual.id)
                print("✅ Ritual completed: \(ritual.title)")
            } else {
                try await routineService.uncompleteRoutine(id: ritual.id)
                print("✅ Ritual uncompleted: \(ritual.title)")
            }
            // Sync widget data after ritual toggle
            syncWidgetData()
        } catch {
            // Revert on error
            rituals[index].isCompleted = wasCompleted
            print("❌ Error toggling ritual: \(error)")
        }
    }

    func createRitual(areaId: String, title: String, frequency: String, icon: String, scheduledTime: String? = nil) async throws {
        // Ensure areas exist before creating ritual
        if !areasLoaded {
            await ensureAreasExist()
        }

        // Verify the areaId is valid (not a placeholder)
        guard areasLoaded, areas.contains(where: { $0.id == areaId && !$0.id.hasPrefix("placeholder-") }) else {
            throw NSError(domain: "FocusApp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please wait for areas to load or select a valid area"])
        }

        _ = try await routineService.createRoutine(
            areaId: areaId,
            title: title,
            frequency: frequency,
            icon: icon,
            scheduledTime: scheduledTime
        )

        // Refresh dashboard to sync all data after mutation
        await refresh()
    }

    func updateRitual(id: String, title: String?, frequency: String?, icon: String?, scheduledTime: String? = nil) async throws {
        _ = try await routineService.updateRoutine(
            id: id,
            title: title,
            frequency: frequency,
            icon: icon,
            scheduledTime: scheduledTime
        )

        // Refresh dashboard to sync all data after mutation
        await refresh()
    }

    func deleteRitual(id: String) async throws {
        try await routineService.deleteRoutine(id: id)
        // Refresh dashboard to sync all data after mutation
        await refresh()
    }

    func loadRituals() async {
        do {
            print("📋 Fallback: Loading rituals directly from /routines...")
            let routines = try await routineService.fetchRoutines()
            print("📋 Fallback: Loaded \(routines.count) routines")

            // Also fetch today's completions to know which routines are completed
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: Date())

            var completedRoutineIds: Set<String> = []
            do {
                let completions = try await completionsService.fetchCompletions(
                    routineId: nil,
                    from: todayString,
                    to: todayString
                )
                completedRoutineIds = Set(completions.map { $0.routineId })
                print("📋 Today's completions: \(completedRoutineIds.count) routines completed")
            } catch {
                print("⚠️ Could not fetch completions: \(error)")
            }

            // Convert routines to rituals with completion status
            self.rituals = routines.map { routine in
                var ritual = DailyRitual(from: routine)
                ritual.isCompleted = completedRoutineIds.contains(routine.id)
                return ritual
            }

            for routine in routines {
                let isCompleted = completedRoutineIds.contains(routine.id)
                print("  - \(routine.title) (frequency: \(routine.frequency), completed: \(isCompleted))")
            }
            print("📋 Fallback: Rituals array now has \(self.rituals.count) items")
        } catch {
            print("❌ Error loading rituals: \(error)")
        }
    }

    // MARK: - Focus Sessions
    func loadWeekSessions() async {
        do {
            print("📊 Loading week sessions from API...")
            // Fetch completed sessions (limit to recent ones for performance)
            let sessions = try await sessionService.fetchSessions(questId: nil, status: "completed", limit: 50)
            print("📊 Fetched \(sessions.count) sessions from API")

            // Filter for this week (Monday to Sunday)
            let calendar = Calendar(identifier: .iso8601)
            let weekStart = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            guard let weekStartDate = calendar.date(from: weekStart) else { return }

            let weekSessions = sessions
                .map { FocusSession(from: $0) }
                .filter { $0.startTime >= weekStartDate }
                .sorted { $0.startTime > $1.startTime }

            print("📊 Sessions this week: \(weekSessions.count)")
            for session in weekSessions.prefix(5) {
                print("  - \(session.description ?? "Focus") \(session.durationMinutes)min @ \(session.startTime)")
            }

            self.weekSessions = weekSessions
            self.todaysSessions = weekSessions.filter { Calendar.current.isDateInToday($0.startTime) }
            print("📊 Today's sessions: \(self.todaysSessions.count)")
        } catch {
            print("❌ Error loading week sessions: \(error)")
        }
    }

    func createSession(durationMinutes: Int, questId: String?, description: String?) async {
        do {
            _ = try await sessionService.createSession(
                durationMinutes: durationMinutes,
                questId: questId,
                description: description
            )
            // Refresh dashboard to sync all data after mutation
            await refresh()
        } catch {
            print("Error creating session: \(error)")
        }
    }

    func logManualSession(durationMinutes: Int, startTime: Date, questId: String?, description: String?) async {
        do {
            _ = try await sessionService.logManualSession(
                durationMinutes: durationMinutes,
                startTime: startTime,
                questId: questId,
                description: description
            )
            // Refresh dashboard to sync all data after mutation
            await refresh()
        } catch {
            print("Error logging session: \(error)")
        }
    }

    /// Start a new focus session (status = active). Returns the created session.
    func startSession(durationMinutes: Int, questId: String?, description: String?) async throws -> FocusSession {
        let response = try await sessionService.createSession(
            durationMinutes: durationMinutes,
            questId: questId,
            description: description
        )
        return FocusSession(from: response)
    }

    /// Complete a focus session (sets status = completed, completed_at = now)
    func completeSession(sessionId: String) async throws {
        _ = try await sessionService.completeSession(sessionId: sessionId)
        // Refresh dashboard to sync all data after mutation
        await refresh()
    }

    /// Cancel a focus session (sets status = cancelled - user stopped manually)
    func cancelSession(sessionId: String) async throws {
        _ = try await sessionService.cancelSession(sessionId: sessionId)
        // Refresh dashboard to sync all data after mutation
        await refresh()
    }

    // MARK: - Reflections (Check-ins)
    func saveReflection(
        biggestWin: String?,
        challenges: String?,
        bestMoment: String?,
        goalForTomorrow: String?
    ) async {
        do {
            _ = try await reflectionService.upsertReflection(
                date: Date(),
                biggestWin: biggestWin,
                challenges: challenges,
                bestMoment: bestMoment,
                goalForTomorrow: goalForTomorrow
            )
            // Refresh dashboard to sync all data after mutation
            await refresh()
        } catch {
            print("Error saving reflection: \(error)")
        }
    }

    func loadTodayReflection() async {
        do {
            if let reflection = try await reflectionService.fetchReflection(date: Date()) {
                self.eveningReview = EveningReview(
                    id: reflection.id,
                    userId: authUserId ?? "",
                    date: Date(),
                    ritualsCompleted: [],
                    biggestWin: reflection.biggestWin,
                    blockers: reflection.challenges,
                    bestMoment: reflection.bestMoment,
                    tomorrowGoal: reflection.goalForTomorrow
                )
            }
        } catch {
            // 404 = no reflection yet, which is normal
            print("📝 No evening reflection for today yet")
        }
    }

    // MARK: - Intentions (Start Your Day)
    func loadTodayIntentions() async {
        do {
            let intentions = try await intentionsService.fetchTodayIntentions()
            print("📝 Loaded today's intentions: \(intentions.intentions.count) items")

            // Convert to MorningCheckIn model for compatibility
            self.morningCheckIn = MorningCheckIn(
                id: intentions.id,
                userId: authUserId ?? "",
                date: Date(),
                feeling: moodEmojiToFeeling(intentions.moodEmoji),
                feelingNote: nil,
                sleepQuality: intentions.sleepRating,
                sleepNote: nil,
                intentions: intentions.intentions.map { intentionResponse in
                    DailyIntention(
                        id: intentionResponse.id,
                        userId: authUserId ?? "",
                        date: Date(),
                        intention: intentionResponse.content,
                        area: areaIdToQuestArea(intentionResponse.areaId),
                        isCompleted: false
                    )
                }
            )
        } catch {
            // 404 = hasn't started day yet, which is normal
            print("📝 No morning check-in for today yet")
            self.morningCheckIn = nil
        }
    }

    /// Save morning intentions (Start Your Day)
    func saveIntentions(
        moodRating: Int,
        moodEmoji: String,
        sleepRating: Int,
        sleepEmoji: String,
        intentions: [(areaId: String?, content: String)]
    ) async throws {
        let intentionInputs = intentions.map { IntentionInput(areaId: $0.areaId, content: $0.content) }

        _ = try await intentionsService.saveIntentions(
            date: Date(),
            moodRating: moodRating,
            moodEmoji: moodEmoji,
            sleepRating: sleepRating,
            sleepEmoji: sleepEmoji,
            intentions: intentionInputs
        )

        print("✅ Intentions saved successfully")
        // Refresh dashboard to sync all data after mutation
        await refresh()
    }

    private func moodEmojiToFeeling(_ emoji: String) -> Feeling {
        switch emoji {
        case "🤩": return .excited
        case "😊": return .happy
        case "😌": return .calm
        case "😐": return .neutral
        case "😔": return .sad
        case "😢": return .sad
        case "😰": return .anxious
        case "😤": return .frustrated
        case "🥱": return .tired
        default: return .neutral
        }
    }

    private func areaIdToQuestArea(_ areaId: String?) -> QuestArea {
        guard let areaId = areaId,
              let area = areas.first(where: { $0.id == areaId }) else {
            return .other
        }

        switch area.slug.lowercased() {
        case "health": return .health
        case "learning": return .learning
        case "career": return .career
        case "relationships": return .relationships
        case "creativity": return .creativity
        default: return .other
        }
    }

    // MARK: - Quests
    /// Load quests if not already loaded
    func loadQuestsIfNeeded() async {
        guard quests.isEmpty else {
            print("🎯 Quests already loaded (\(quests.count) quests)")
            return
        }
        await loadQuests()
    }

    /// Load quests from API
    func loadQuests() async {
        do {
            print("🎯 Loading quests from API...")
            let questResponses = try await questService.fetchQuests()
            self.quests = questResponses.map { response in
                let area = self.areas.first { $0.id == response.areaId }
                return Quest(from: response, area: area)
            }
            print("🎯 Loaded \(self.quests.count) quests")
        } catch {
            print("❌ Error loading quests: \(error)")
        }
    }

    func createQuest(areaId: String, title: String, targetValue: Int = 1, targetDate: Date? = nil) async throws -> Quest {
        let response = try await questService.createQuest(areaId: areaId, title: title, targetValue: targetValue, targetDate: targetDate)
        let area = areas.first { $0.id == response.areaId }
        let quest = Quest(from: response, area: area)
        quests.append(quest)
        return quest
    }

    func updateQuest(questId: String, title: String? = nil, status: String? = nil, currentValue: Int? = nil, targetValue: Int? = nil, targetDate: Date? = nil) async throws {
        guard let index = quests.firstIndex(where: { $0.id == questId }) else { return }

        let updatedResponse = try await questService.updateQuest(
            id: questId,
            title: title,
            status: status,
            currentValue: currentValue,
            targetValue: targetValue,
            targetDate: targetDate
        )
        let area = areas.first { $0.id == updatedResponse.areaId }
        quests[index] = Quest(from: updatedResponse, area: area)
    }

    func updateQuestProgress(questId: String, progress: Double) async {
        guard let index = quests.firstIndex(where: { $0.id == questId }) else { return }

        // Optimistic update
        let oldProgress = quests[index].progress
        quests[index].progress = progress

        do {
            let updatedResponse = try await questService.updateQuestProgress(
                questId: questId,
                progress: progress
            )
            let area = areas.first { $0.id == updatedResponse.areaId }
            quests[index] = Quest(from: updatedResponse, area: area)
        } catch {
            // Revert on error
            quests[index].progress = oldProgress
            print("Error updating quest: \(error)")
        }
    }

    func incrementQuestProgress(questId: String) async throws {
        guard let index = quests.firstIndex(where: { $0.id == questId }) else { return }
        // Get the quest's current value and increment
        // Since Quest model uses progress (0-1), we need to track current/target values
        // For now, increment by calculating from progress
        let quest = quests[index]
        let newProgress = min(1.0, quest.progress + 0.1) // Increment by 10%
        try await updateQuest(questId: questId, currentValue: Int(newProgress * 100), targetValue: 100)
    }

    func completeQuest(questId: String) async throws {
        try await updateQuest(questId: questId, status: "completed")
    }

    func deleteQuest(questId: String) async throws {
        try await questService.deleteQuest(id: questId)
        quests.removeAll { $0.id == questId }
    }

    /// MARK: - Refresh
    func refresh() async {
        await loadInitialData(force: true)
        syncWidgetData()
    }

    func refreshFiremode() async {
        await loadFiremodeData(force: true)
    }

    // MARK: - Widget Data Sync
    func syncWidgetData() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta") else {
            print("❌ Widget: Failed to access shared UserDefaults")
            return
        }

        // Focus widget data
        sharedDefaults.set(todayMinutes, forKey: "widget_minutes_today")
        sharedDefaults.set(todaySessionsCount, forKey: "widget_sessions_today")
        sharedDefaults.set(currentStreak, forKey: "widget_streak_days")
        print("📱 Widget sync: minutes=\(todayMinutes), sessions=\(todaySessionsCount), streak=\(currentStreak)")

        // Tasks widget data - Rituals
        let widgetRituals = rituals.map { ritual in
            WidgetRitualData(
                id: ritual.id,
                title: ritual.title,
                icon: ritual.icon,
                isCompleted: ritual.isCompleted
            )
        }
        if let ritualsData = try? JSONEncoder().encode(widgetRituals) {
            sharedDefaults.set(ritualsData, forKey: "widget_rituals")
        }
        sharedDefaults.set(rituals.filter { $0.isCompleted }.count, forKey: "widget_completed_rituals")
        sharedDefaults.set(rituals.count, forKey: "widget_total_rituals")

        // Tasks widget data - Intentions
        if let checkIn = morningCheckIn {
            let widgetIntentions = checkIn.intentions.map { intention in
                WidgetIntentionData(
                    id: intention.id,
                    text: intention.intention,
                    area: intention.area.rawValue,
                    areaEmoji: intention.area.emoji,
                    isCompleted: intention.isCompleted
                )
            }
            if let intentionsData = try? JSONEncoder().encode(widgetIntentions) {
                sharedDefaults.set(intentionsData, forKey: "widget_intentions")
            }
            // Store mood emoji (feeling.rawValue is the emoji)
            sharedDefaults.set(checkIn.feeling.rawValue, forKey: "widget_mood_emoji")
        } else {
            sharedDefaults.removeObject(forKey: "widget_intentions")
            sharedDefaults.removeObject(forKey: "widget_mood_emoji")
        }

        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
        print("📱 Widget sync: rituals=\(rituals.count) (\(rituals.filter { $0.isCompleted }.count) completed), intentions=\(morningCheckIn?.intentions.count ?? 0)")
    }

    func setWidgetSessionState(isInSession: Bool) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta") else { return }
        sharedDefaults.set(isInSession, forKey: "widget_is_in_session")

        // Clear session data if not in session
        if !isInSession {
            sharedDefaults.removeObject(forKey: "widget_session_time_remaining")
            sharedDefaults.removeObject(forKey: "widget_session_total_duration")
            sharedDefaults.removeObject(forKey: "widget_session_quest_emoji")
            sharedDefaults.removeObject(forKey: "widget_session_description")
        }

        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Start a widget session with end date for real-time countdown
    func startWidgetSession(durationMinutes: Int, questEmoji: String?, description: String?) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta") else { return }

        let endDate = Date().addingTimeInterval(Double(durationMinutes * 60))

        sharedDefaults.set(true, forKey: "widget_is_in_session")
        sharedDefaults.set(endDate.timeIntervalSince1970, forKey: "widget_session_end_date")
        sharedDefaults.set(durationMinutes, forKey: "widget_session_total_duration")

        if let emoji = questEmoji {
            sharedDefaults.set(emoji, forKey: "widget_session_quest_emoji")
        } else {
            sharedDefaults.removeObject(forKey: "widget_session_quest_emoji")
        }

        if let desc = description {
            sharedDefaults.set(desc, forKey: "widget_session_description")
        } else {
            sharedDefaults.removeObject(forKey: "widget_session_description")
        }

        // Reload widgets to show timer
        WidgetCenter.shared.reloadAllTimelines()
        print("📱 Widget session started: ends at \(endDate)")
    }

    /// End widget session
    func endWidgetSession() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta") else { return }

        sharedDefaults.set(false, forKey: "widget_is_in_session")
        sharedDefaults.set(0, forKey: "widget_session_end_date")
        sharedDefaults.removeObject(forKey: "widget_session_total_duration")
        sharedDefaults.removeObject(forKey: "widget_session_quest_emoji")
        sharedDefaults.removeObject(forKey: "widget_session_description")

        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
        print("📱 Widget session ended")
    }
}

// MARK: - Widget Data Models (for encoding)
struct WidgetRitualData: Codable {
    let id: String
    let title: String
    let icon: String
    let isCompleted: Bool
}

struct WidgetIntentionData: Codable {
    let id: String
    let text: String
    let area: String
    let areaEmoji: String
    let isCompleted: Bool
}
