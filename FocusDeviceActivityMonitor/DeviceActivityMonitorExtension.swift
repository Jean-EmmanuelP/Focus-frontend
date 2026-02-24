//
//  DeviceActivityMonitorExtension.swift
//  FocusDeviceActivityMonitor
//
//  Created by Jean-Emmanuel on 21/02/2026.
//

import DeviceActivity
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
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.log("🔴 intervalDidEnd: \(activity.rawValue)")
        sharedDefaults?.set("intervalDidEnd: \(activity.rawValue) at \(Date())", forKey: debugKey)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        logger.log("🔔 eventDidReachThreshold: event=\(event.rawValue) activity=\(activity.rawValue)")
        sharedDefaults?.set("eventDidReachThreshold: \(event.rawValue) at \(Date())", forKey: debugKey)

        // Send the notification (no rate limiting — this only fires once per day per event)
        sendDistractionNotification()
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        logger.log("⚠️ eventWillReachThresholdWarning: \(event.rawValue)")
        sharedDefaults?.set("eventWillReachThresholdWarning: \(event.rawValue) at \(Date())", forKey: debugKey)
    }

    // MARK: - Notification

    private func sendDistractionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Ton coach pense a toi"
        content.body = "Viens discuter avec moi"
        content.sound = .default
        content.userInfo = ["deepLink": "focus://chat"]

        let request = UNNotificationRequest(
            identifier: "distraction.alert.\(UUID().uuidString)",
            content: content,
            trigger: nil // Fire immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logger.error("❌ Failed to send notification: \(error.localizedDescription)")
                self.sharedDefaults?.set("notif FAILED: \(error.localizedDescription) at \(Date())", forKey: self.debugKey)
            } else {
                logger.log("✅ Distraction notification sent")
                self.sharedDefaults?.set("notif SENT at \(Date())", forKey: self.debugKey)
            }
        }
    }
}
