import SwiftUI
import Combine

@MainActor
class FireModeViewModel: ObservableObject {
    // Reference to the shared store
    private var store: FocusAppStore { FocusAppStore.shared }
    private var cancellables = Set<AnyCancellable>()

    // App Blocker service
    private let appBlockerService = ScreenTimeAppBlockerService.shared

    // UserDefaults for blocking toggle (same as in AppBlockerViewModel)
    @AppStorage("appBlocker.enableDuringFocus") private var enableBlockingDuringFocus: Bool = true

    // UserDefaults key for last used quest
    private let lastUsedQuestKey = "firemode.lastUsedQuestId"

    // MARK: - Timer State
    enum TimerState {
        case idle
        case running
        case paused
        case completed
    }

    @Published var timerState: TimerState = .idle
    @Published var timeRemaining: Int = 0 // in seconds
    @Published var sessionStartTime: Date?
    @Published var currentSessionId: String? // Track current session for completion
    @Published var linkedTaskId: String? // Track linked task for post-session validation
    @Published var linkedRitualId: String? // Track linked ritual for post-session validation
    @Published var showTaskValidationPrompt = false // Show validation prompt after focus completion (task or ritual)
    @Published var shouldDismissModal = false // Signal to dismiss the modal after task validation
    private var timer: Timer?

    // MARK: - Published UI State
    @Published var selectedDuration: Int = 25
    @Published var customDuration: Double = 25
    @Published var selectedQuestId: String? {
        didSet {
            // Save last used quest to UserDefaults when changed
            if let questId = selectedQuestId {
                UserDefaults.standard.set(questId, forKey: lastUsedQuestKey)
            }
        }
    }
    @Published var sessionDescription: String = ""
    @Published var showingLogManualSession = false
    @Published var isLoading = false

    // Stale session handling
    @Published var showingStaleSessionAlert = false
    @Published var staleSession: FocusSessionResponse?

    // MARK: - Published Data (from store)
    @Published var quests: [Quest] = []
    @Published var firemodeStats: FiremodeResponse?
    @Published var todaysSessions: [FocusSession] = []

    // Preset durations
    let presetDurations = [25, 50, 90]

    init() {
        setupBindings()
        // Load firemode data and quests on init
        Task {
            await store.loadFiremodeData()
            // Ensure quests are loaded for "Link to Quest" feature
            if store.quests.isEmpty {
                await store.loadQuestsIfNeeded()
            }
            // Set default quest to last used (after quests are loaded)
            selectLastUsedQuest()
            // Check for stale sessions
            await checkForStaleSessions()
        }
    }

    /// Select the last used quest if it exists and is still active
    private func selectLastUsedQuest() {
        guard selectedQuestId == nil else { return } // Don't override if already set

        if let lastQuestId = UserDefaults.standard.string(forKey: lastUsedQuestKey) {
            // Check if the quest still exists and is active
            if availableQuests.contains(where: { $0.id == lastQuestId }) {
                selectedQuestId = lastQuestId
            }
        }
    }

    /// Apply preset values from router and auto-start if all required fields are set
    func applyPresets(duration: Int?, questId: String?, description: String?, taskId: String? = nil, ritualId: String? = nil) {
        if let duration = duration {
            selectedDuration = duration
            customDuration = Double(duration)
        }
        if let questId = questId {
            selectedQuestId = questId
        }
        if let description = description {
            sessionDescription = description
        }
        if let taskId = taskId {
            linkedTaskId = taskId
        }
        if let ritualId = ritualId {
            linkedRitualId = ritualId
        }

        // If duration is set, auto-start the session
        if duration != nil {
            Task {
                await startFocusSession()
            }
        }
    }

    private func setupBindings() {
        store.$quests
            .receive(on: DispatchQueue.main)
            .assign(to: &$quests)

        store.$firemodeStats
            .receive(on: DispatchQueue.main)
            .assign(to: &$firemodeStats)

        store.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        store.$todaysSessions
            .receive(on: DispatchQueue.main)
            .assign(to: &$todaysSessions)
    }

    // MARK: - Computed Properties (use firemodeStats when available)
    var totalSessionsThisWeek: Int {
        firemodeStats?.sessionsWeek ?? 0
    }

    var totalMinutesToday: Int {
        firemodeStats?.minutesToday ?? store.focusedMinutesToday
    }

    var totalSessionsToday: Int {
        firemodeStats?.sessionsToday ?? 0
    }

    var minutesLast7Days: Int {
        firemodeStats?.minutesLast7 ?? 0
    }

    var sessionsLast7Days: Int {
        firemodeStats?.sessionsLast7 ?? 0
    }

    var availableQuests: [Quest] {
        quests.filter { $0.status == .active }
    }

    var hasAnySessions: Bool {
        totalSessionsThisWeek > 0 || totalMinutesToday > 0
    }

    var isTimerActive: Bool {
        timerState == .running || timerState == .paused
    }

    var formattedTimeRemaining: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var timerProgress: Double {
        let totalSeconds = selectedDuration * 60
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(timeRemaining) / Double(totalSeconds))
    }

    var elapsedMinutes: Int {
        let totalSeconds = selectedDuration * 60
        let elapsed = totalSeconds - timeRemaining
        return elapsed / 60
    }

    // MARK: - Duration Selection
    func selectDuration(_ duration: Int) {
        guard timerState == .idle else { return }
        selectedDuration = duration
        customDuration = Double(duration)
    }

    func updateCustomDuration(_ duration: Double) {
        guard timerState == .idle else { return }
        customDuration = duration
        selectedDuration = Int(duration)
    }

    // MARK: - Timer Actions
    func startTimer() {
        sessionStartTime = Date()
        timeRemaining = selectedDuration * 60
        timerState = .running

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Start app blocking if enabled
        if enableBlockingDuringFocus && appBlockerService.isBlockingEnabled {
            appBlockerService.startBlocking()
            print("🔒 App blocking started with focus session")
        }

        // Create session in backend (status = active)
        Task {
            await createSessionInBackend()
        }

        // Start Live Activity
        let quest = quests.first { $0.id == selectedQuestId }
        LiveActivityManager.shared.startLiveActivity(
            sessionId: currentSessionId ?? UUID().uuidString,
            totalDuration: selectedDuration,
            description: sessionDescription.isEmpty ? nil : sessionDescription,
            questTitle: quest?.title,
            questEmoji: quest?.area.emoji
        )

        // Update widget with session end date for real-time countdown
        store.startWidgetSession(
            durationMinutes: selectedDuration,
            questEmoji: quest?.area.emoji,
            description: sessionDescription.isEmpty ? nil : sessionDescription
        )

        startTimerLoop()
    }

    private func createSessionInBackend() async {
        do {
            let session = try await store.startSession(
                durationMinutes: selectedDuration,
                questId: selectedQuestId,
                description: sessionDescription.isEmpty ? nil : sessionDescription
            )
            currentSessionId = session.id
            print("✅ Session started in backend: \(session.id)")
        } catch {
            print("❌ Failed to create session in backend: \(error)")
        }
    }

    private func completeSessionInBackend(sessionId: String) async {
        do {
            try await store.completeSession(sessionId: sessionId)
            print("✅ Session completed in backend: \(sessionId)")
        } catch {
            print("❌ Failed to complete session in backend: \(error)")
        }
    }

    func pauseTimer() {
        timerState = .paused
        timer?.invalidate()
        timer = nil

        // Update Live Activity
        LiveActivityManager.shared.updateLiveActivity(
            timeRemaining: timeRemaining,
            progress: timerProgress,
            isPaused: true
        )

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func resumeTimer() {
        timerState = .running
        startTimerLoop()

        // Update Live Activity
        LiveActivityManager.shared.updateLiveActivity(
            timeRemaining: timeRemaining,
            progress: timerProgress,
            isPaused: false
        )

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .completed // Mark as completed to show validation prompt

        // Stop app blocking
        if appBlockerService.isBlocking {
            appBlockerService.stopBlocking()
            print("🔓 App blocking stopped (session cancelled)")
        }

        // End Live Activity
        LiveActivityManager.shared.endLiveActivity(completed: false)

        // End widget session
        store.endWidgetSession()

        // Cancel the session in backend (not complete - user stopped manually)
        if let sessionId = currentSessionId {
            Task {
                await cancelSessionInBackend(sessionId: sessionId)
                store.syncWidgetData()
            }
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // If a task or ritual was linked, show validation prompt
        // Otherwise just reset
        if linkedTaskId != nil || linkedRitualId != nil {
            showTaskValidationPrompt = true
        } else {
            resetTimerState()
        }
    }

    private func cancelSessionInBackend(sessionId: String) async {
        do {
            try await store.cancelSession(sessionId: sessionId)
            print("✅ Session cancelled in backend: \(sessionId)")
        } catch {
            print("❌ Failed to cancel session in backend: \(error)")
        }
    }

    func completeSession() {
        timer?.invalidate()
        timer = nil
        timerState = .completed

        // Stop app blocking
        if appBlockerService.isBlocking {
            appBlockerService.stopBlocking()
            print("🔓 App blocking stopped (session completed)")
        }

        // End Live Activity with completed state
        LiveActivityManager.shared.endLiveActivity(completed: true)

        // End widget session
        store.endWidgetSession()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Complete the session in backend (sets completed_at = now)
        Task {
            if let sessionId = currentSessionId {
                await completeSessionInBackend(sessionId: sessionId)
            }
            store.syncWidgetData()

            // If a task or ritual was linked, show validation prompt
            // Otherwise just reset after a delay
            if linkedTaskId != nil || linkedRitualId != nil {
                // Show task/ritual validation prompt
                showTaskValidationPrompt = true
            } else {
                // No task/ritual linked - keep completed state briefly before resetting
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                resetTimerState()
            }
        }
    }

    /// Validate the linked task or ritual (mark as completed)
    func validateLinkedTask() async {
        // Validate task if linked
        if let taskId = linkedTaskId {
            do {
                try await store.toggleTask(taskId: taskId, completed: true)
                print("✅ Task validated: \(taskId)")
            } catch {
                print("❌ Failed to validate task: \(error)")
            }
        }

        // Validate ritual if linked
        if let ritualId = linkedRitualId {
            do {
                try await store.toggleRitualById(ritualId: ritualId)
                print("✅ Ritual validated: \(ritualId)")
            } catch {
                print("❌ Failed to validate ritual: \(error)")
            }
        }

        showTaskValidationPrompt = false
        resetTimerState()
        // Signal to close the modal
        shouldDismissModal = true
    }

    /// Skip task/ritual validation (don't mark as completed)
    func skipTaskValidation() {
        showTaskValidationPrompt = false
        resetTimerState()
        // Signal to close the modal
        shouldDismissModal = true
    }

    private func startTimerLoop() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard timerState == .running else { return }

        if timeRemaining > 0 {
            timeRemaining -= 1

            // Update Live Activity every 5 seconds to save battery
            if timeRemaining % 5 == 0 {
                LiveActivityManager.shared.updateLiveActivity(
                    timeRemaining: timeRemaining,
                    progress: timerProgress,
                    isPaused: false
                )
            }
            // Note: Widget uses Text(date, style: .timer) for real-time updates
            // No need to manually update widget every tick
        }

        if timeRemaining == 0 {
            completeSession()
        }
    }

    private func resetTimerState() {
        timerState = .idle
        timeRemaining = 0
        sessionStartTime = nil
        currentSessionId = nil
        linkedTaskId = nil
        linkedRitualId = nil
        showTaskValidationPrompt = false
        // Note: Don't reset shouldDismissModal here - it's handled by the view
        resetForm()
    }

    // MARK: - Stale Session Handling

    /// Check if there are any active sessions that should have ended (stale)
    func checkForStaleSessions() async {
        // Don't check if timer is already running
        guard timerState == .idle else { return }

        do {
            let activeSessions = try await store.fetchActiveSessions()

            for session in activeSessions {
                // Check if session has exceeded its planned duration + 5 min buffer
                let expectedEndTime = session.startedAt.addingTimeInterval(Double(session.durationMinutes + 5) * 60)

                if Date() > expectedEndTime {
                    // This is a stale session - show alert to user
                    staleSession = session
                    showingStaleSessionAlert = true
                    print("⚠️ Found stale session: \(session.id), started \(session.startedAt), duration \(session.durationMinutes)min")
                    break // Handle one at a time
                }
            }
        } catch {
            print("❌ Failed to check for stale sessions: \(error)")
        }
    }

    /// Complete the stale session (count it as finished)
    func completeStaleSession() async {
        guard let session = staleSession else { return }

        do {
            try await store.completeSession(sessionId: session.id)
            print("✅ Stale session completed: \(session.id)")
        } catch {
            print("❌ Failed to complete stale session: \(error)")
        }

        staleSession = nil
        showingStaleSessionAlert = false

        // Refresh data
        await store.refreshFiremode()
    }

    /// Cancel the stale session (don't count it)
    func cancelStaleSession() async {
        guard let session = staleSession else { return }

        do {
            try await store.cancelSession(sessionId: session.id)
            print("✅ Stale session cancelled: \(session.id)")
        } catch {
            print("❌ Failed to cancel stale session: \(error)")
        }

        staleSession = nil
        showingStaleSessionAlert = false

        // Refresh data
        await store.refreshFiremode()
    }

    // MARK: - Actions
    func refreshData() async {
        await store.refreshFiremode()
        // Also check for stale sessions on refresh
        await checkForStaleSessions()
    }

    func startFocusSession() async {
        startTimer()
    }

    func logManualSession(durationMinutes: Int, startTime: Date) async {
        isLoading = true
        await store.logManualSession(
            durationMinutes: durationMinutes,
            startTime: startTime,
            questId: selectedQuestId,
            description: sessionDescription.isEmpty ? nil : sessionDescription
        )
        resetForm()
        isLoading = false
    }

    // Reset form - keeps last used quest as default
    func resetForm() {
        sessionDescription = ""
        // Don't clear selectedQuestId - keep last used quest as default for next session
        // User can change it if needed
    }
}
