import Foundation
import Combine
import DeviceActivity
import FamilyControls

/// Service that monitors distractive app usage via DeviceActivity framework.
/// When the user spends time on selected apps, the extension sends a notification
/// inviting them to chat with their coach instead.
@MainActor
final class DistractionMonitorService: ObservableObject {
    static let shared = DistractionMonitorService()

    private let center = DeviceActivityCenter()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta")

    // Activity & event identifiers
    private let activityName = DeviceActivityName("distraction.monitoring")
    private let eventName = DeviceActivityEvent.Name("distraction.threshold")

    // Threshold: minimum possible (1 minute — Apple's minimum)
    private let thresholdMinutes = 1

    @Published var distractionMonitorEnabled: Bool {
        didSet {
            UserDefaults.standard.set(distractionMonitorEnabled, forKey: "distraction.monitorEnabled")
            if distractionMonitorEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    /// Debug: refreshable diagnostic info
    @Published var debugInfo: String = ""

    private init() {
        self.distractionMonitorEnabled = UserDefaults.standard.bool(forKey: "distraction.monitorEnabled")
    }

    // MARK: - Monitoring Control

    /// Start monitoring distractive app usage for the current day (00:00–23:59, repeats daily).
    func startMonitoring() {
        let selection = ScreenTimeAppBlockerService.shared.selectedApps
        let appCount = selection.applicationTokens.count
        let catCount = selection.categoryTokens.count

        // Need at least some apps selected
        guard appCount > 0 || catCount > 0 else {
            debugInfo = "⚠️ 0 apps selectionnees"
            print("⚠️ DistractionMonitor: no apps selected, skipping")
            return
        }

        // Stop any existing monitoring first
        center.stopMonitoring([activityName])

        // Schedule: midnight to 23:59, repeats daily
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Event: threshold on selected apps
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: thresholdMinutes)
        )

        do {
            try center.startMonitoring(
                activityName,
                during: schedule,
                events: [eventName: event]
            )
            debugInfo = "✅ Actif — \(appCount) apps, \(catCount) cats, seuil \(thresholdMinutes)min"
            print("✅ DistractionMonitor: started (\(appCount) apps, \(catCount) categories)")
        } catch {
            debugInfo = "❌ Erreur: \(error.localizedDescription)"
            print("❌ DistractionMonitor: failed to start - \(error)")
        }
    }

    /// Stop monitoring.
    func stopMonitoring() {
        center.stopMonitoring([activityName])
        debugInfo = ""
        print("🔓 DistractionMonitor: stopped")
    }

    /// Restart monitoring if enabled (call when the app selection changes).
    func restartMonitoringIfNeeded() {
        guard distractionMonitorEnabled else { return }
        startMonitoring()
    }

    /// Get today's distraction count from the DeviceActivity extension (via shared UserDefaults)
    /// Returns 0 if no distractions detected today (or monitoring not active)
    var todayDistractionCount: Int {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let lastDate = sharedDefaults?.string(forKey: "distraction.count.date") ?? ""
        guard lastDate == today else { return 0 }
        return sharedDefaults?.integer(forKey: "distraction.count.today") ?? 0
    }

    /// Refresh debug info by checking actual monitoring state + shared UD
    func refreshDebugInfo() {
        let activities = center.activities
        let isActive = activities.contains(activityName)
        let lastEvent = sharedDefaults?.string(forKey: "distraction.debug.lastEvent") ?? "aucun"
        let status = sharedDefaults?.string(forKey: "distraction.debug.status") ?? "?"

        let appCount = ScreenTimeAppBlockerService.shared.selectedApps.applicationTokens.count
        let catCount = ScreenTimeAppBlockerService.shared.selectedApps.categoryTokens.count

        debugInfo = """
        Monitoring: \(isActive ? "OUI" : "NON") | Apps: \(appCount), Cats: \(catCount)
        Status: \(status)
        Extension: \(lastEvent)
        """
    }
}
