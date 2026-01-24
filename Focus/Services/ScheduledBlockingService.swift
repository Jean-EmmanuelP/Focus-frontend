import Foundation
import UserNotifications
import Combine

/// Service that manages automatic app blocking based on scheduled calendar tasks
@MainActor
final class ScheduledBlockingService: ObservableObject {
    static let shared = ScheduledBlockingService()

    private let appBlocker = ScreenTimeAppBlockerService.shared
    private let notificationCenter = UNUserNotificationCenter.current()

    // UserDefaults key for global auto-blocking toggle
    @Published var autoBlockingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoBlockingEnabled, forKey: "scheduledBlocking.enabled")
        }
    }

    // Track currently active blocking task
    @Published var activeBlockingTaskId: String?
    @Published var activeBlockingTaskTitle: String?
    @Published var blockingEndTime: Date?

    private init() {
        self.autoBlockingEnabled = UserDefaults.standard.bool(forKey: "scheduledBlocking.enabled")
    }

    // MARK: - Schedule Blocking for Tasks

    /// Schedule app blocking for all tasks that have blockApps enabled
    func scheduleBlockingForTasks(_ tasks: [CalendarTask]) async {
        guard autoBlockingEnabled else { return }
        guard appBlocker.hasSelectedApps else {
            print("⚠️ ScheduledBlocking: No apps selected to block")
            return
        }

        // Cancel existing scheduled blocking notifications
        await cancelAllScheduledBlocking()

        // Filter tasks that have blocking enabled and are scheduled for today
        let today = Calendar.current.startOfDay(for: Date())
        let blockingTasks = tasks.filter { task in
            guard task.blockApps == true,
                  task.scheduledStart != nil,
                  task.scheduledEnd != nil,
                  let taskDate = task.dateAsDate,
                  Calendar.current.isDate(taskDate, inSameDayAs: today),
                  task.status != "completed" && task.status != "skipped" else {
                return false
            }
            return true
        }

        for task in blockingTasks {
            await scheduleBlockingForTask(task)
        }

        print("📅 ScheduledBlocking: Scheduled blocking for \(blockingTasks.count) tasks")
    }

    /// Schedule start and end blocking for a single task
    private func scheduleBlockingForTask(_ task: CalendarTask) async {
        guard let startDate = task.startDate,
              let endDate = task.endDate else { return }

        let now = Date()

        // If task has already started, start blocking immediately
        if startDate <= now && endDate > now {
            startBlockingForTask(task, until: endDate)
            // Schedule end notification
            await scheduleBlockingEndNotification(taskId: task.id, endDate: endDate)
        }
        // If task is in the future, schedule start notification
        else if startDate > now {
            await scheduleBlockingStartNotification(task: task, startDate: startDate)
            await scheduleBlockingEndNotification(taskId: task.id, endDate: endDate)
        }
        // If task has ended, do nothing
    }

    /// Schedule a notification to start blocking
    private func scheduleBlockingStartNotification(task: CalendarTask, startDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Focus Time"
        content.body = "Starting: \(task.title) - Apps blocked"
        content.sound = .default
        content.userInfo = [
            "action": "startBlocking",
            "taskId": task.id,
            "taskTitle": task.title,
            "endTime": task.endDate?.timeIntervalSince1970 ?? 0
        ]
        content.categoryIdentifier = "SCHEDULED_BLOCKING"

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "blocking.start.\(task.id)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("📅 Scheduled blocking start for '\(task.title)' at \(startDate)")
        } catch {
            print("❌ Failed to schedule blocking start: \(error)")
        }
    }

    /// Schedule a notification to stop blocking
    private func scheduleBlockingEndNotification(taskId: String, endDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Focus Complete"
        content.body = "Task finished - Apps unblocked"
        content.sound = .default
        content.userInfo = [
            "action": "stopBlocking",
            "taskId": taskId
        ]
        content.categoryIdentifier = "SCHEDULED_BLOCKING"

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: endDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "blocking.end.\(taskId)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("📅 Scheduled blocking end at \(endDate)")
        } catch {
            print("❌ Failed to schedule blocking end: \(error)")
        }
    }

    // MARK: - Blocking Control

    /// Start blocking immediately for a task
    func startBlockingForTask(_ task: CalendarTask, until endDate: Date) {
        guard appBlocker.hasSelectedApps else { return }

        activeBlockingTaskId = task.id
        activeBlockingTaskTitle = task.title
        blockingEndTime = endDate

        appBlocker.startBlocking()
        print("🔒 Auto-blocking started for: \(task.title)")
    }

    /// Stop blocking
    func stopBlocking() {
        activeBlockingTaskId = nil
        activeBlockingTaskTitle = nil
        blockingEndTime = nil

        appBlocker.stopBlocking()
        print("🔓 Auto-blocking stopped")
    }

    /// Handle notification actions (called from AppDelegate)
    func handleNotificationAction(_ userInfo: [AnyHashable: Any]) {
        guard let action = userInfo["action"] as? String else { return }

        switch action {
        case "startBlocking":
            if let taskId = userInfo["taskId"] as? String,
               let taskTitle = userInfo["taskTitle"] as? String,
               let endTimeInterval = userInfo["endTime"] as? TimeInterval {
                let endDate = Date(timeIntervalSince1970: endTimeInterval)

                // Only start if end time hasn't passed
                if endDate > Date() {
                    activeBlockingTaskId = taskId
                    activeBlockingTaskTitle = taskTitle
                    blockingEndTime = endDate
                    appBlocker.startBlocking()
                    print("🔒 Auto-blocking started via notification: \(taskTitle)")
                }
            }

        case "stopBlocking":
            stopBlocking()

        default:
            break
        }
    }

    // MARK: - Cancellation

    /// Cancel all scheduled blocking notifications
    func cancelAllScheduledBlocking() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let blockingIds = pendingRequests
            .filter { $0.identifier.hasPrefix("blocking.") }
            .map { $0.identifier }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: blockingIds)
        print("📅 Cancelled \(blockingIds.count) scheduled blocking notifications")
    }

    /// Cancel blocking for a specific task
    func cancelBlockingForTask(_ taskId: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "blocking.start.\(taskId)",
            "blocking.end.\(taskId)"
        ])

        // If this is the active blocking task, stop blocking
        if activeBlockingTaskId == taskId {
            stopBlocking()
        }
    }

    // MARK: - Check Active Blocking

    /// Check if any scheduled task should currently be blocking
    func checkAndUpdateBlockingState(tasks: [CalendarTask]) {
        guard autoBlockingEnabled, appBlocker.hasSelectedApps else { return }

        let now = Date()

        // Find any task that should be blocking right now
        let activeTask = tasks.first { task in
            guard task.blockApps == true,
                  let startDate = task.startDate,
                  let endDate = task.endDate,
                  task.status != "completed" && task.status != "skipped" else {
                return false
            }
            return startDate <= now && now < endDate
        }

        if let task = activeTask {
            // Should be blocking
            if activeBlockingTaskId != task.id {
                startBlockingForTask(task, until: task.endDate!)
            }
        } else {
            // Should not be blocking
            if activeBlockingTaskId != nil {
                stopBlocking()
            }
        }
    }
}
