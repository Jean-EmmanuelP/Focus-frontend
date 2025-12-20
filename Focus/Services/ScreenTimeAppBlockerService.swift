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
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()

    // MARK: - Private Properties
    private let managedSettingsStore = ManagedSettingsStore()
    private let userDefaultsKey = "appBlocker.selectedApps"

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

    /// Start blocking selected apps
    /// Call this when a focus session starts
    func startBlocking() {
        guard authorizationStatus == .approved else {
            print("⚠️ Cannot start blocking: not authorized")
            return
        }

        guard hasSelectedApps else {
            print("⚠️ Cannot start blocking: no apps selected")
            return
        }

        // Apply shield to selected apps
        managedSettingsStore.shield.applications = selectedApps.applicationTokens
        managedSettingsStore.shield.applicationCategories = .specific(selectedApps.categoryTokens)
        managedSettingsStore.shield.webDomains = selectedApps.webDomainTokens

        isBlocking = true
        print("🔒 App blocking started - \(selectedAppsCount) items blocked")
    }

    /// Stop blocking all apps
    /// Call this when a focus session ends
    func stopBlocking() {
        // Remove all shields
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = nil
        managedSettingsStore.shield.webDomains = nil

        isBlocking = false
        print("🔓 App blocking stopped")
    }

    // MARK: - Persistence

    /// Save selected apps to UserDefaults
    private func saveSelection() {
        do {
            let data = try PropertyListEncoder().encode(selectedApps)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("💾 Saved app selection to UserDefaults")
        } catch {
            print("❌ Failed to save app selection: \(error)")
        }
    }

    /// Load saved selection from UserDefaults
    private func loadSavedSelection() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }

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
