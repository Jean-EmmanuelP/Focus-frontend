//
//  DeviceActivityMonitorExtension.swift
//  FocusDeviceActivityMonitor
//
//  Created by Jean-Emmanuel on 21/02/2026.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications
import Foundation
import os.log

private let logger = Logger(subsystem: "com.jep.volta.DeviceActivityMonitor", category: "monitor")

/// DeviceActivityMonitor extension that fires a notification when the user
/// spends too long on selected distractive apps (YouTube, Instagram, etc.)
/// This runs in a separate process — it cannot access main app code.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta")
    private let debugKey = "distraction.debug.lastEvent"

    // MARK: - DeviceActivityMonitor Callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.log("🟢 intervalDidStart: \(activity.rawValue)")
        sharedDefaults?.set("intervalDidStart: \(activity.rawValue) at \(Date())", forKey: debugKey)

        if activity.rawValue == "morning.autoblock" {
            applyMorningShields()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.log("🔴 intervalDidEnd: \(activity.rawValue)")
        sharedDefaults?.set("intervalDidEnd: \(activity.rawValue) at \(Date())", forKey: debugKey)

        if activity.rawValue == "morning.autoblock" {
            removeMorningShields()
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        logger.log("🔔 eventDidReachThreshold: event=\(event.rawValue) activity=\(activity.rawValue)")
        sharedDefaults?.set("eventDidReachThreshold: \(event.rawValue) at \(Date())", forKey: debugKey)

        // Track distraction for satisfaction score
        incrementDistractionCount()

        // Send notification adapted to distraction level
        sendDistractionNotification(level: event.rawValue)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        logger.log("⚠️ eventWillReachThresholdWarning: \(event.rawValue)")
        sharedDefaults?.set("eventWillReachThresholdWarning: \(event.rawValue) at \(Date())", forKey: debugKey)
    }

    // MARK: - Distraction Tracking

    /// Increment daily distraction counter in shared UserDefaults
    private func incrementDistractionCount() {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let lastDate = sharedDefaults?.string(forKey: "distraction.count.date") ?? ""

        if lastDate != today {
            // New day — reset counter
            sharedDefaults?.set(today, forKey: "distraction.count.date")
            sharedDefaults?.set(1, forKey: "distraction.count.today")
        } else {
            let current = sharedDefaults?.integer(forKey: "distraction.count.today") ?? 0
            sharedDefaults?.set(current + 1, forKey: "distraction.count.today")
        }
        logger.log("📊 Distraction count incremented for \(today)")
    }

    // MARK: - Notification

    private func sendDistractionNotification(level: String) {
        let (title, body) = messageForLevel(level)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["deepLink": "focus://chat"]

        let request = UNNotificationRequest(
            identifier: "distraction.alert.\(level)",
            content: content,
            trigger: nil // Fire immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logger.error("❌ Failed to send notification: \(error.localizedDescription)")
                self.sharedDefaults?.set("notif FAILED: \(error.localizedDescription) at \(Date())", forKey: self.debugKey)
            } else {
                logger.log("✅ Distraction notification sent for level \(level)")
                self.sharedDefaults?.set("notif SENT level=\(level) at \(Date())", forKey: self.debugKey)
            }
        }
    }

    // MARK: - Morning Auto-Block Shields

    /// Apply shields via a named store so it doesn't conflict with the default store
    /// used by ScreenTimeAppBlockerService for manual/focus blocking.
    private func applyMorningShields() {
        let store = ManagedSettingsStore(named: .init("morningAutoBlock"))

        guard let data = sharedDefaults?.data(forKey: "appBlocker.selectedApps"),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            logger.warning("⚠️ Morning shields: no saved app selection found")
            return
        }

        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
        logger.log("🔒 Morning auto-block shields applied")
        sharedDefaults?.set("morningShields APPLIED at \(Date())", forKey: debugKey)
    }

    /// Remove morning shields by clearing the named store.
    private func removeMorningShields() {
        let store = ManagedSettingsStore(named: .init("morningAutoBlock"))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        logger.log("🔓 Morning auto-block shields removed")
        sharedDefaults?.set("morningShields REMOVED at \(Date())", forKey: debugKey)
    }

    private func messageForLevel(_ level: String) -> (title: String, body: String) {
        switch level {
        case "distraction.level.1":
            // 1 min — gentle nudge
            return ("Hey 👀", "Tu scrolles là. T'avais pas un truc à faire ?")
        case "distraction.level.2":
            // 15 min
            return ("15 min de scroll", "Ça fait un quart d'heure. Pose ton tel.")
        case "distraction.level.3":
            // 30 min
            return ("30 min perdues", "Une demi-heure sur ton tel. Sérieux, arrête.")
        case "distraction.level.4":
            // 1h
            return ("1h de scroll 🚨", "T'as perdu 1h. Tes objectifs avancent pas tout seuls.")
        case "distraction.level.5":
            // 2h
            return ("2h... 😐", "Deux heures. T'as des rêves non ? Reviens.")
        default:
            return ("Ton coach", "Range ton tel et avance.")
        }
    }
}
