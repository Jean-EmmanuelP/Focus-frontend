import Foundation
import Combine
import UserNotifications

// MARK: - Notification Models

struct MorningPhraseResponse: Codable {
    let phrase: String
    let language: String
    let type: String
}

struct TaskReminderResponse: Codable {
    let phrase: String
    let taskName: String
    let language: String
    let type: String
}

// MARK: - Notification Settings

struct NotificationSettings: Codable {
    var morningReminderEnabled: Bool
    var morningReminderTime: Date // Only hour/minute used
    var taskRemindersEnabled: Bool
    var taskReminderMinutesBefore: Int // 5, 10, 15, 30 minutes

    static var `default`: NotificationSettings {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        let defaultMorningTime = calendar.date(from: components) ?? Date()

        return NotificationSettings(
            morningReminderEnabled: true,
            morningReminderTime: defaultMorningTime,
            taskRemindersEnabled: true,
            taskReminderMinutesBefore: 15
        )
    }
}

// MARK: - Notification Service

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    private let apiClient = APIClient.shared
    private let notificationCenter = UNUserNotificationCenter.current()

    @Published var isAuthorized: Bool = false
    @Published var settings: NotificationSettings {
        didSet {
            saveSettings()
        }
    }

    // Notification identifiers
    private let morningNotificationId = "focus.morning.reminder"
    private let taskNotificationPrefix = "focus.task."

    private init() {
        self.settings = NotificationSettings.default
        loadSettings()
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }

            if granted {
                await scheduleMorningNotification()
            }

            return granted
        } catch {
            print("❌ Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Settings Persistence

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "notification_settings")
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "notification_settings"),
           let decoded = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            self.settings = decoded
        }
    }

    // MARK: - Morning Notification

    /// Schedule morning notifications for the next 7 days with different phrases
    func scheduleMorningNotification() async {
        guard settings.morningReminderEnabled else {
            cancelMorningNotification()
            return
        }

        // Cancel existing before scheduling new
        cancelMorningNotification()

        // Get user's first name for personalization
        let firstName = FocusAppStore.shared.user?.firstName ?? nil

        // Schedule notifications for the next 7 days with different phrases
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: settings.morningReminderTime)
        let minute = calendar.component(.minute, from: settings.morningReminderTime)

        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }

            // Fetch a fresh motivational phrase for each day
            let phrase = await fetchMorningPhrase()

            // Create notification content with personalized title
            let content = UNMutableNotificationContent()
            if let name = firstName, !name.isEmpty {
                content.title = "Bonjour \(name) !"
            } else {
                content.title = "notification.morning.title".localized
            }
            content.body = phrase
            content.sound = .default
            content.userInfo = ["deepLink": "focus://starttheday"]

            // Set up trigger for specific day
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: futureDate)
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(morningNotificationId).\(dayOffset)",
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM"
                print("✅ Morning notification scheduled for \(dateFormatter.string(from: futureDate)) at \(hour):\(minute)")
            } catch {
                print("❌ Failed to schedule morning notification for day \(dayOffset): \(error)")
            }
        }
    }

    func cancelMorningNotification() {
        // Cancel all 7 days of morning notifications
        let identifiers = (1...7).map { "\(morningNotificationId).\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Task Reminder Notifications

    func scheduleTaskReminder(for task: CalendarTask) async {
        guard settings.taskRemindersEnabled else { return }
        guard let scheduledStart = task.scheduledStart else { return }
        guard task.status != "completed" && task.status != "skipped" else { return }
        guard let taskDate = task.dateAsDate else { return }

        // Parse the scheduled time
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let time = formatter.date(from: scheduledStart) else { return }

        // Combine task date with scheduled time
        let calendar = Calendar.current

        var components = calendar.dateComponents([.year, .month, .day], from: taskDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        guard let taskDateTime = calendar.date(from: components) else { return }

        // Calculate reminder time (X minutes before)
        let reminderTime = taskDateTime.addingTimeInterval(-Double(settings.taskReminderMinutesBefore * 60))

        // Don't schedule if reminder time is in the past
        guard reminderTime > Date() else { return }

        // Fetch motivational phrase
        let phrase = await fetchTaskReminderPhrase(taskName: task.title)

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = phrase
        content.sound = .default
        content.userInfo = [
            "deepLink": "focus://calendar",
            "taskId": task.id
        ]

        // Set up trigger
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "\(taskNotificationPrefix)\(task.id)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("✅ Task reminder scheduled for \(task.title) at \(reminderTime)")
        } catch {
            print("❌ Failed to schedule task reminder: \(error)")
        }
    }

    func cancelTaskReminder(taskId: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["\(taskNotificationPrefix)\(taskId)"])
    }

    func scheduleAllTaskReminders(tasks: [CalendarTask]) async {
        // Cancel all existing task reminders
        cancelAllTaskReminders()

        // Schedule reminders for today's pending tasks with scheduled times
        let today = Calendar.current.startOfDay(for: Date())
        let todayTasks = tasks.filter { task in
            guard let taskDate = task.dateAsDate else { return false }
            return Calendar.current.isDate(taskDate, inSameDayAs: today) &&
            task.scheduledStart != nil &&
            task.status != "completed" &&
            task.status != "skipped"
        }

        for task in todayTasks {
            await scheduleTaskReminder(for: task)
        }
    }

    func cancelAllTaskReminders() {
        notificationCenter.getPendingNotificationRequests { requests in
            let taskNotificationIds = requests
                .filter { $0.identifier.hasPrefix(self.taskNotificationPrefix) }
                .map { $0.identifier }

            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: taskNotificationIds)
        }
    }

    // MARK: - API Calls

    private func fetchMorningPhrase() async -> String {
        let lang = currentLanguageCode()

        do {
            let response: MorningPhraseResponse = try await apiClient.request(
                endpoint: .motivationMorning(lang: lang),
                method: .get
            )
            return response.phrase
        } catch {
            print("❌ Failed to fetch morning phrase: \(error)")
            // Fallback phrase
            if lang == "fr" {
                return "Bonjour ! C'est le moment de planifier ta journee et d'atteindre tes objectifs."
            }
            return "Good morning! Time to plan your day and crush your goals."
        }
    }

    private func fetchTaskReminderPhrase(taskName: String) async -> String {
        let lang = currentLanguageCode()

        do {
            let response: TaskReminderResponse = try await apiClient.request(
                endpoint: .motivationTask(lang: lang, taskName: taskName),
                method: .get
            )
            return response.phrase
        } catch {
            print("❌ Failed to fetch task reminder phrase: \(error)")
            // Fallback phrase
            if lang == "fr" {
                return "C'est l'heure de te concentrer sur '\(taskName)' !"
            }
            return "Time to focus on '\(taskName)'!"
        }
    }

    private func currentLanguageCode() -> String {
        // Use the app's localization manager for consistency
        return LocalizationManager.shared.effectiveLanguageCode
    }

    // MARK: - Update Settings

    func updateMorningReminderEnabled(_ enabled: Bool) async {
        settings.morningReminderEnabled = enabled
        if enabled {
            await scheduleMorningNotification()
        } else {
            cancelMorningNotification()
        }
    }

    func updateMorningReminderTime(_ time: Date) async {
        settings.morningReminderTime = time
        if settings.morningReminderEnabled {
            await scheduleMorningNotification()
        }
    }

    func updateTaskRemindersEnabled(_ enabled: Bool) {
        settings.taskRemindersEnabled = enabled
        if !enabled {
            cancelAllTaskReminders()
        }
    }

    func updateTaskReminderMinutesBefore(_ minutes: Int) {
        settings.taskReminderMinutesBefore = minutes
    }
}
