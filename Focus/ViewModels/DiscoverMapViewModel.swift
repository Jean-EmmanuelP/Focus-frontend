import Foundation
import Combine
import CoreLocation
import SwiftUI

@MainActor
class DiscoverMapViewModel: ObservableObject {
    @Published var nearbyUsers: [NearbyUser] = []
    @Published var selectedUser: NearbyUser? = nil
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Focus Pulse stats
    @Published var localActiveCount: Int = 0
    @Published var localTotalMinutes: Int = 0

    // Encouragement
    @Published var sentEncouragements: Set<String> = []
    @Published var showSentConfirmation = false
    @Published var incomingToast: EncouragementToast?

    // Coach
    @Published var coachMessage: String = ""

    // Fake users ON by default — 10 taps on title disables them
    @Published var fakeUsersEnabled = true

    private let discoverService = DiscoverService()
    private let locationService = LocationService.shared
    private let fakeUserGenerator = FakeUserGenerator()
    private var pollingTimer: Timer?
    private var encouragementTimer: Timer?
    private let pollingInterval: TimeInterval = 30

    // Easter egg tap counter
    private var debugTapCount = 0
    private var lastTapTime = Date.distantPast

    // MARK: - Computed

    var focusingUsers: [NearbyUser] {
        nearbyUsers.filter { $0.isInFocusSession }
    }

    var idleUsers: [NearbyUser] {
        nearbyUsers.filter { !$0.isInFocusSession }
    }

    var isUserCurrentlyFocusing: Bool {
        FocusAppStore.shared.todayMinutes > 0
    }

    // MARK: - Load Data

    func loadData() async {
        isLoading = true
        errorMessage = nil

        // 1. Get location
        if let location = locationService.currentLocation {
            userLocation = location.coordinate
        } else {
            locationService.startUpdating()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if let location = locationService.currentLocation {
                userLocation = location.coordinate
            }
        }

        guard let coordinate = userLocation else {
            errorMessage = "Localisation indisponible"
            isLoading = false
            return
        }

        // 2. Fetch real users from API
        var realUsers: [NearbyUser] = []
        do {
            realUsers = try await discoverService.fetchNearbyUsers(
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                radiusKm: 50
            )
        } catch {
            print("[DiscoverMap] API error: \(error)")
        }

        // 3. Merge with fake users if enabled
        if fakeUsersEnabled {
            let fakeUsers = fakeUserGenerator.generate(around: coordinate)
            nearbyUsers = realUsers + fakeUsers
        } else {
            nearbyUsers = realUsers
        }

        // 4. Compute stats
        updateStats()

        // 5. Generate coach message
        coachMessage = generateCoachMessage()

        isLoading = false
    }

    // MARK: - Stats

    private func updateStats() {
        let focusing = focusingUsers
        withAnimation(.easeOut(duration: 0.6)) {
            localActiveCount = focusing.count
            localTotalMinutes = focusing.reduce(0) { $0 + $1.focusMinutesElapsed }
        }
    }

    // MARK: - Polling

    func startPolling() {
        Task { await loadData() }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadData()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        stopEncouragementSimulation()
    }

    // MARK: - Select User

    func selectUser(_ user: NearbyUser) {
        selectedUser = user
    }

    func deselectUser() {
        selectedUser = nil
    }

    // MARK: - Encouragement

    func sendEncouragement(to userId: String, emoji: String, message: String) {
        sentEncouragements.insert(userId)
        showSentConfirmation = true
        HapticFeedback.success()

        // Auto-dismiss card after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showSentConfirmation = false
            self?.deselectUser()
        }
    }

    func hasAlreadyEncouraged(_ userId: String) -> Bool {
        sentEncouragements.contains(userId)
    }

    // MARK: - Simulated Incoming Encouragement

    func startEncouragementSimulation() {
        guard encouragementTimer == nil else { return }
        scheduleNextEncouragement()
    }

    func stopEncouragementSimulation() {
        encouragementTimer?.invalidate()
        encouragementTimer = nil
    }

    private func scheduleNextEncouragement() {
        let delay = Double.random(in: 30...90)
        encouragementTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.simulateIncomingEncouragement()
                self?.scheduleNextEncouragement()
            }
        }
    }

    private func simulateIncomingEncouragement() {
        guard isUserCurrentlyFocusing else { return }

        let preset = encouragementPresets.randomElement()!
        let names = ["S", "A", "M", "L", "K", "N", "R", "Y", "O", "H"]
        let initial = names.randomElement()!

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            incomingToast = EncouragementToast(
                emoji: preset.emoji,
                message: preset.message,
                fromInitial: initial
            )
        }

        // Auto-dismiss after 3s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.incomingToast = nil
            }
        }
    }

    // MARK: - Coach Message

    private func generateCoachMessage() -> String {
        let store = FocusAppStore.shared
        let hour = Calendar.current.component(.hour, from: Date())
        let focusedToday = store.todayMinutes
        let streak = store.currentStreak
        let count = localActiveCount

        if streak > 0 && focusedToday == 0 && hour >= 18 {
            return "Ta streak de \(streak) jours est en danger. Lance une session maintenant."
        }

        if streak >= 7 {
            return "\(streak) jours de streak. \(count) personnes focus pres de toi. Continue."
        }

        if focusedToday > 0 {
            return "Deja \(focusedToday) min aujourd'hui. \(count) personnes focus pres de toi."
        }

        switch hour {
        case 5..<9:
            return "\(count) personnes focus pres de toi. Le matin, c'est le meilleur moment."
        case 9..<12:
            return "\(count) personnes en focus. La matinee est le pic de productivite."
        case 12..<14:
            return "Pause midi ? \(count) personnes continuent de focus pres de toi."
        case 14..<18:
            return "L'apres-midi avance. \(count) personnes en session. Et toi ?"
        case 18..<22:
            return "Soiree focus. \(count) personnes terminent leur journee en force."
        default:
            return "\(count) personnes focus pres de toi en ce moment."
        }
    }

    // MARK: - Easter Egg (10 taps to toggle fake users)

    func handleDebugTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) > 3 {
            debugTapCount = 0
        }
        lastTapTime = now
        debugTapCount += 1

        if debugTapCount >= 10 {
            debugTapCount = 0
            fakeUsersEnabled.toggle()
            HapticFeedback.heavy()

            Task {
                await loadData()
            }
        }
    }

    // MARK: - Launch Focus Session

    func launchFocusSession() {
        Task {
            do {
                _ = try await FocusAppStore.shared.startSession(durationMinutes: 25, description: "Focus Pulse")
                print("🔥 Focus session started from Focus Pulse")
            } catch {
                print("❌ Failed to start session: \(error)")
            }
        }
    }
}
