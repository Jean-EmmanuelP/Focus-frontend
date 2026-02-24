import SwiftUI
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Service to manage app blocking using Screen Time APIs
/// Handles authorization, app selection, and blocking during focus sessions
@MainActor
final class ScreenTimeAppBlockerService: ObservableObject {
    static let shared = ScreenTimeAppBlockerService()

    // MARK: - Published State
    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published private(set) var isBlocking: Bool = false
    @Published private(set) var blockingEndDate: Date?
    @Published private(set) var blockingRemainingMinutes: Int = 0
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()

    // MARK: - Private Properties
    private let managedSettingsStore = ManagedSettingsStore()
    private let userDefaultsKey = "appBlocker.selectedApps"
    private let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta")
    private var blockingTimer: Timer?

    // MARK: - Authorization Status
    enum AuthorizationStatus {
        case notDetermined
        case approved
        case denied

        var isAuthorized: Bool {
            self == .approved
        }

        var displayText: String {
            switch self {
            case .notDetermined:
                return "Non configuré"
            case .approved:
                return "Autorisé"
            case .denied:
                return "Refusé"
            }
        }
    }

    // MARK: - Initialization
    private init() {
        loadSavedSelection()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Check current authorization status
    func checkAuthorizationStatus() {
        let center = AuthorizationCenter.shared

        Task {
            // Check if we have authorization by trying to access the status
            do {
                // Try to get the authorization status
                switch center.authorizationStatus {
                case .notDetermined:
                    authorizationStatus = .notDetermined
                case .approved:
                    authorizationStatus = .approved
                case .denied:
                    authorizationStatus = .denied
                @unknown default:
                    authorizationStatus = .notDetermined
                }
            }
        }
    }

    /// Request Screen Time authorization
    /// Call this when user first enables app blocking feature
    func requestAuthorization() async -> Bool {
        let center = AuthorizationCenter.shared

        do {
            try await center.requestAuthorization(for: .individual)
            authorizationStatus = .approved
            print("✅ Screen Time authorization granted")
            return true
        } catch {
            print("❌ Screen Time authorization failed: \(error)")
            authorizationStatus = .denied
            return false
        }
    }

    /// Request authorization if not already authorized
    func requestAuthorizationIfNeeded() async -> Bool {
        guard authorizationStatus != .approved else {
            return true
        }
        return await requestAuthorization()
    }

    // MARK: - App Selection

    /// Check if any apps are selected for blocking
    var hasSelectedApps: Bool {
        !selectedApps.applicationTokens.isEmpty ||
        !selectedApps.categoryTokens.isEmpty ||
        !selectedApps.webDomainTokens.isEmpty
    }

    /// Number of selected items (apps + categories + web domains)
    var selectedAppsCount: Int {
        selectedApps.applicationTokens.count +
        selectedApps.categoryTokens.count +
        selectedApps.webDomainTokens.count
    }

    /// Update selected apps (called from FamilyActivityPicker)
    func updateSelectedApps(_ selection: FamilyActivitySelection) {
        selectedApps = selection
        saveSelection()
        print("✅ Updated app selection: \(selectedAppsCount) items")
    }

    /// Clear all selected apps
    func clearSelection() {
        selectedApps = FamilyActivitySelection()
        saveSelection()
        print("✅ Cleared app selection")
    }

    // MARK: - Blocking Control

    /// Start blocking selected apps indefinitely
    func startBlocking() {
        startBlocking(durationMinutes: nil)
    }

    /// Start blocking selected apps for a specific duration (in minutes)
    func startBlocking(durationMinutes: Int?) {
        guard authorizationStatus == .approved else {
            print("⚠️ Cannot start blocking: not authorized")
            return
        }

        guard hasSelectedApps else {
            print("⚠️ Cannot start blocking: no apps selected")
            return
        }

        // Cancel any existing timer
        blockingTimer?.invalidate()
        blockingTimer = nil

        // Apply shield to selected apps
        managedSettingsStore.shield.applications = selectedApps.applicationTokens
        managedSettingsStore.shield.applicationCategories = .specific(selectedApps.categoryTokens)
        managedSettingsStore.shield.webDomains = selectedApps.webDomainTokens

        isBlocking = true

        if let minutes = durationMinutes, minutes > 0 {
            blockingEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
            blockingRemainingMinutes = minutes

            // Update remaining time every 60s
            blockingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateRemainingTime()
                }
            }

            // Schedule auto-stop
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(minutes * 60)) { [weak self] in
                self?.stopBlocking()
            }

            print("🔒 App blocking started for \(minutes) min - \(selectedAppsCount) items blocked")
        } else {
            blockingEndDate = nil
            blockingRemainingMinutes = 0
            print("🔒 App blocking started (indefinite) - \(selectedAppsCount) items blocked")
        }
    }

    private func updateRemainingTime() {
        guard let endDate = blockingEndDate else {
            blockingRemainingMinutes = 0
            return
        }
        let remaining = Int(endDate.timeIntervalSinceNow / 60)
        blockingRemainingMinutes = max(0, remaining)
    }

    /// Stop blocking all apps
    func stopBlocking() {
        // Cancel timer
        blockingTimer?.invalidate()
        blockingTimer = nil

        // Remove all shields
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = nil
        managedSettingsStore.shield.webDomains = nil

        isBlocking = false
        blockingEndDate = nil
        blockingRemainingMinutes = 0
        print("🔓 App blocking stopped")
    }

    // MARK: - Persistence

    /// Save selected apps to both standard and shared UserDefaults
    private func saveSelection() {
        do {
            let data = try PropertyListEncoder().encode(selectedApps)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            // Also save to shared defaults so the DeviceActivityMonitor extension can read them
            sharedDefaults?.set(data, forKey: userDefaultsKey)
            print("💾 Saved app selection to UserDefaults (standard + shared)")
        } catch {
            print("❌ Failed to save app selection: \(error)")
        }

        // Restart distraction monitoring if enabled (selection changed)
        DistractionMonitorService.shared.restartMonitoringIfNeeded()
    }

    /// Load saved selection from UserDefaults (shared first, fallback to standard)
    private func loadSavedSelection() {
        let data = sharedDefaults?.data(forKey: userDefaultsKey)
            ?? UserDefaults.standard.data(forKey: userDefaultsKey)

        guard let data else { return }

        do {
            selectedApps = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
            print("📂 Loaded app selection: \(selectedAppsCount) items")
        } catch {
            print("❌ Failed to load app selection: \(error)")
        }
    }
}

// MARK: - Focus Session Integration

extension ScreenTimeAppBlockerService {
    /// Check if blocking should be enabled for focus sessions
    var isBlockingEnabled: Bool {
        authorizationStatus == .approved && hasSelectedApps
    }

    /// Start blocking if enabled (convenience method for focus sessions)
    func startBlockingIfEnabled() {
        guard isBlockingEnabled else { return }
        startBlocking()
    }
}
