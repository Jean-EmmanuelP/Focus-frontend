import Foundation
import Combine
import UserNotifications

/// Service that manages automatic app blocking based on calendar events
/// Uses UNNotification-based scheduling (same pattern as ScheduledBlockingService
/// but with "calendarBlocking.*" identifiers to avoid conflicts)
@MainActor
final class CalendarEventBlockingService: ObservableObject {
    static let shared = CalendarEventBlockingService()

    private let appBlocker = ScreenTimeAppBlockerService.shared
    private let notificationCenter = UNUserNotificationCenter.current()

    @Published var activeBlockingEventId: String?
    @Published var activeBlockingEventTitle: String?
    @Published var blockingEndTime: Date?

    private init() {}

    // MARK: - Schedule Blocking for Calendar Events

    /// Schedule app blocking for all calendar events that have blockApps enabled
    func scheduleBlockingForEvents(_ events: [ExternalCalendarEvent]) async {
        guard appBlocker.hasSelectedApps else { return }

        // Cancel existing calendar blocking notifications
        await cancelAllScheduledBlocking()

        let blockingEvents = events.filter { event in
            event.blockApps &&
            event.eventStatus == "confirmed" &&
            !event.isAllDay &&
            event.startDate != nil &&
            event.endDate != nil
        }

        for event in blockingEvents {
            await scheduleBlockingForEvent(event)
        }

        if !blockingEvents.isEmpty {
            print("[CalendarBlocking] Scheduled blocking for \(blockingEvents.count) events")
        }
    }

    /// Schedule start and end blocking for a single event
    private func scheduleBlockingForEvent(_ event: ExternalCalendarEvent) async {
        guard let startDate = event.startDate,
              let endDate = event.endDate else { return }

        let now = Date()

        if startDate <= now && endDate > now {
            // Event is happening now — block immediately
            startBlockingForEvent(event, until: endDate)
            await scheduleBlockingEndNotification(eventId: event.id, endDate: endDate)
        } else if startDate > now {
            // Event is in the future — schedule notifications
            await scheduleBlockingStartNotification(event: event, startDate: startDate)
            await scheduleBlockingEndNotification(eventId: event.id, endDate: endDate)
        }
    }

    // MARK: - Notification Scheduling

    private func scheduleBlockingStartNotification(event: ExternalCalendarEvent, startDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Focus Time"
        content.body = "\(event.title) — Apps bloquées"
        content.sound = .default
        content.userInfo = [
            "action": "startCalendarBlocking",
            "eventId": event.id,
            "eventTitle": event.title,
            "endTime": event.endDate?.timeIntervalSince1970 ?? 0
        ]
        content.categoryIdentifier = "CALENDAR_BLOCKING"

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: startDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "calendarBlocking.start.\(event.id)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[CalendarBlocking] Failed to schedule start: \(error)")
        }
    }

    private func scheduleBlockingEndNotification(eventId: String, endDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Focus terminé"
        content.body = "Événement terminé — Apps débloquées"
        content.sound = .default
        content.userInfo = [
            "action": "stopCalendarBlocking",
            "eventId": eventId
        ]
        content.categoryIdentifier = "CALENDAR_BLOCKING"

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: endDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "calendarBlocking.end.\(eventId)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[CalendarBlocking] Failed to schedule end: \(error)")
        }
    }

    // MARK: - Blocking Control

    func startBlockingForEvent(_ event: ExternalCalendarEvent, until endDate: Date) {
        guard appBlocker.hasSelectedApps else { return }

        activeBlockingEventId = event.id
        activeBlockingEventTitle = event.title
        blockingEndTime = endDate

        appBlocker.startBlocking()
        print("[CalendarBlocking] Started for: \(event.title)")
    }

    func stopBlocking() {
        activeBlockingEventId = nil
        activeBlockingEventTitle = nil
        blockingEndTime = nil

        appBlocker.stopBlocking()
        print("[CalendarBlocking] Stopped")
    }

    /// Handle notification actions (called from AppDelegate)
    func handleNotificationAction(_ userInfo: [AnyHashable: Any]) {
        guard let action = userInfo["action"] as? String else { return }

        switch action {
        case "startCalendarBlocking":
            if let eventId = userInfo["eventId"] as? String,
               let eventTitle = userInfo["eventTitle"] as? String,
               let endTimeInterval = userInfo["endTime"] as? TimeInterval {
                let endDate = Date(timeIntervalSince1970: endTimeInterval)

                if endDate > Date() {
                    activeBlockingEventId = eventId
                    activeBlockingEventTitle = eventTitle
                    blockingEndTime = endDate
                    appBlocker.startBlocking()
                }
            }

        case "stopCalendarBlocking":
            stopBlocking()

        default:
            break
        }
    }

    // MARK: - Cancellation

    func cancelAllScheduledBlocking() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let calendarBlockingIds = pendingRequests
            .filter { $0.identifier.hasPrefix("calendarBlocking.") }
            .map { $0.identifier }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: calendarBlockingIds)
    }
}
