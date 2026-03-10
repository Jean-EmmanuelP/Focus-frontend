import Foundation
import Combine
import DeviceActivity
import FamilyControls

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
        self.isEnabled = defaults?.bool(forKey: "morningBlock.enabled") ?? false
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
}
