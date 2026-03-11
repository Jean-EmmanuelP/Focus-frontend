import Foundation
import Combine
import DeviceActivity
import FamilyControls
import ManagedSettings

/// Service that manages automatic morning app blocking via DeviceActivitySchedule.
/// Uses a named ManagedSettingsStore ("morningAutoBlock") to avoid conflicts with
/// the manual blocking in ScreenTimeAppBlockerService (which uses the default store).
@MainActor
final class MorningBlockService: ObservableObject {
    static let shared = MorningBlockService()

    private let center = DeviceActivityCenter()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta")
    private let activityName = DeviceActivityName("morning.autoblock")

    // MARK: - Published State

    @Published var isEnabled: Bool {
        didSet {
            sharedDefaults?.set(isEnabled, forKey: "morningBlock.enabled")
            if isEnabled {
                updateSchedule()
            } else {
                stopSchedule()
            }
        }
    }

    @Published var startHour: Int {
        didSet {
            sharedDefaults?.set(startHour, forKey: "morningBlock.startHour")
            if isEnabled { updateSchedule() }
        }
    }

    @Published var startMinute: Int {
        didSet {
            sharedDefaults?.set(startMinute, forKey: "morningBlock.startMinute")
            if isEnabled { updateSchedule() }
        }
    }

    @Published var endHour: Int {
        didSet {
            sharedDefaults?.set(endHour, forKey: "morningBlock.endHour")
            if isEnabled { updateSchedule() }
        }
    }

    @Published var endMinute: Int {
        didSet {
            sharedDefaults?.set(endMinute, forKey: "morningBlock.endMinute")
            if isEnabled { updateSchedule() }
        }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults(suiteName: "group.com.jep.volta")

        // Default to enabled if never explicitly set by the user
        let hasBeenSet = defaults?.bool(forKey: "morningBlock.enabled.hasBeenSet") ?? false
        if hasBeenSet {
            self.isEnabled = defaults?.bool(forKey: "morningBlock.enabled") ?? true
        } else {
            self.isEnabled = true
            defaults?.set(true, forKey: "morningBlock.enabled")
            defaults?.set(true, forKey: "morningBlock.enabled.hasBeenSet")
        }

        self.startHour = defaults?.object(forKey: "morningBlock.startHour") as? Int ?? 6
        self.startMinute = defaults?.object(forKey: "morningBlock.startMinute") as? Int ?? 0
        self.endHour = defaults?.object(forKey: "morningBlock.endHour") as? Int ?? 9
        self.endMinute = defaults?.object(forKey: "morningBlock.endMinute") as? Int ?? 0
    }

    // MARK: - Schedule Management

    /// Start or update the morning auto-block schedule.
    func updateSchedule() {
        // Need apps selected for shields to work
        let selection = ScreenTimeAppBlockerService.shared.selectedApps
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            print("⚠️ MorningBlock: no apps selected, skipping schedule")
            return
        }

        // Stop existing monitoring first
        center.stopMonitoring([activityName])

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: startHour, minute: startMinute),
            intervalEnd: DateComponents(hour: endHour, minute: endMinute),
            repeats: true
        )

        do {
            try center.startMonitoring(activityName, during: schedule)
            print("✅ MorningBlock: scheduled \(startHour):\(String(format: "%02d", startMinute)) - \(endHour):\(String(format: "%02d", endMinute))")
        } catch {
            print("❌ MorningBlock: failed to start monitoring - \(error)")
        }
    }

    /// Stop the morning auto-block schedule.
    func stopSchedule() {
        center.stopMonitoring([activityName])
        print("🔓 MorningBlock: schedule stopped")
    }

    /// Configure the morning block from external callers (e.g. Backboard tool).
    func configure(enabled: Bool, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = enabled
    }

    // MARK: - Immediate Shield Check

    /// Check if we're currently in the morning block window and apply shields if needed.
    /// Call this on app launch as a safety net — DeviceActivitySchedule callbacks can be missed.
    func applyShieldsIfInWindow() {
        guard isEnabled else { return }

        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        guard currentMinutes >= startMinutes && currentMinutes < endMinutes else {
            // Outside the window — make sure shields are cleared
            removeMorningShields()
            return
        }

        // We're in the window — apply shields from the main app as safety net
        let selection = ScreenTimeAppBlockerService.shared.selectedApps
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            print("⚠️ MorningBlock: in window but no apps selected")
            return
        }

        let store = ManagedSettingsStore(named: .init("morningAutoBlock"))
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
        print("🔒 MorningBlock: shields applied from main app (safety net)")
    }

    /// Remove morning shields (called when outside the window).
    private func removeMorningShields() {
        let store = ManagedSettingsStore(named: .init("morningAutoBlock"))
        // Only clear if something was set
        if store.shield.applications != nil {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
            print("🔓 MorningBlock: shields removed (outside window)")
        }
    }
}
