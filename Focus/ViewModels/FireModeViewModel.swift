import SwiftUI
import Combine

@MainActor
class FireModeViewModel: ObservableObject {
    // Reference to the shared store
    private var store: FocusAppStore { FocusAppStore.shared }
    private var cancellables = Set<AnyCancellable>()

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
    private var timer: Timer?

    // MARK: - Published UI State
    @Published var selectedDuration: Int = 25
    @Published var customDuration: Double = 25
    @Published var selectedQuestId: String?
    @Published var sessionDescription: String = ""
    @Published var showingLogManualSession = false
    @Published var isLoading = false

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
        }
    }

    /// Apply preset values from router and auto-start if all required fields are set
    func applyPresets(duration: Int?, questId: String?, description: String?) {
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

        // End Live Activity
        LiveActivityManager.shared.endLiveActivity(completed: false)

        // End widget session
        store.endWidgetSession()

        // Complete the session in backend (sets completed_at = now)
        if let sessionId = currentSessionId {
            Task {
                await completeSessionInBackend(sessionId: sessionId)
                store.syncWidgetData()
            }
        }

        resetTimerState()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    func completeSession() {
        timer?.invalidate()
        timer = nil
        timerState = .completed

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
            // Keep completed state briefly before resetting
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            resetTimerState()
        }
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
        resetForm()
    }

    // MARK: - Actions
    func refreshData() async {
        await store.refreshFiremode()
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

    // Reset form
    func resetForm() {
        sessionDescription = ""
        selectedQuestId = nil
    }
}
