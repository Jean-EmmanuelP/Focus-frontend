import Foundation
import Combine
import UserNotifications

// MARK: - Notification Settings

struct NotificationSettings: Codable {
    var morningReminderEnabled: Bool
    var morningReminderTime: Date // Only hour/minute used
    var eveningReminderEnabled: Bool
    var eveningReminderTime: Date // Only hour/minute used
    var taskRemindersEnabled: Bool
    var taskReminderMinutesBefore: Int // 5, 10, 15, 30 minutes
    var routineRemindersEnabled: Bool
    var streakAlertEnabled: Bool

    static var `default`: NotificationSettings {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        var morningComponents = DateComponents()
        morningComponents.hour = 8
        morningComponents.minute = 0
        let defaultMorningTime = calendar.date(from: morningComponents) ?? Date()

        var eveningComponents = DateComponents()
        eveningComponents.hour = 21
        eveningComponents.minute = 0
        let defaultEveningTime = calendar.date(from: eveningComponents) ?? Date()

        return NotificationSettings(
            morningReminderEnabled: true,
            morningReminderTime: defaultMorningTime,
            eveningReminderEnabled: true,
            eveningReminderTime: defaultEveningTime,
            taskRemindersEnabled: true,
            taskReminderMinutesBefore: 15,
            routineRemindersEnabled: true,
            streakAlertEnabled: true
        )
    }
}

// MARK: - Notification Service

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    @Published var isAuthorized: Bool = false
    @Published var settings: NotificationSettings {
        didSet {
            saveSettings()
        }
    }

    // Notification identifiers
    private let morningNotificationId = "focus.morning.reminder"
    private let eveningNotificationId = "focus.evening.reminder"
    private let taskNotificationPrefix = "focus.task."
    private let routineNotificationPrefix = "focus.routine."
    private let streakAlertId = "focus.streak.danger"

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

            // Get a motivational phrase for each day
            let phrase = getMorningPhrase()

            // Create notification content with personalized title
            let content = UNMutableNotificationContent()
            if let name = firstName, !name.isEmpty {
                content.title = "Bonjour \(name) !"
            } else {
                content.title = "notification.morning.title".localized
            }
            content.body = phrase
            content.sound = .default
            content.badge = 1
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

    // MARK: - Evening Notification

    /// Schedule evening review notifications for the next 7 days
    func scheduleEveningNotification() async {
        guard settings.eveningReminderEnabled else {
            cancelEveningNotification()
            return
        }

        cancelEveningNotification()

        let firstName = FocusAppStore.shared.user?.firstName ?? nil
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: settings.eveningReminderTime)
        let minute = calendar.component(.minute, from: settings.eveningReminderTime)

        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }

            let phrase = getEveningPhrase()

            let content = UNMutableNotificationContent()
            if let name = firstName, !name.isEmpty {
                content.title = "\(name), c'est l'heure du bilan"
            } else {
                content.title = "C'est l'heure du bilan"
            }
            content.body = phrase
            content.sound = .default
            content.badge = 1
            content.userInfo = ["deepLink": "focus://endofday"]

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: futureDate)
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(eveningNotificationId).\(dayOffset)",
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
            } catch {
                print("❌ Failed to schedule evening notification for day \(dayOffset): \(error)")
            }
        }
    }

    func cancelEveningNotification() {
        let identifiers = (1...7).map { "\(eveningNotificationId).\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Routine Reminders

    /// Schedule notifications for routines that have a scheduled time
    func scheduleRoutineReminders(routines: [(id: String, title: String, scheduledTime: String)]) async {
        guard settings.routineRemindersEnabled else {
            cancelAllRoutineReminders()
            return
        }

        cancelAllRoutineReminders()

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        for routine in routines {
            guard let time = formatter.date(from: routine.scheduledTime) else { continue }

            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

            let content = UNMutableNotificationContent()
            content.title = routine.title
            content.body = getRoutineReminderPhrase(routineName: routine.title)
            content.sound = .default
            content.badge = 1
            content.userInfo = ["deepLink": "focus://dashboard"]

            // Schedule daily repeating
            var dateComponents = DateComponents()
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(
                identifier: "\(routineNotificationPrefix)\(routine.id)",
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
                print("✅ Routine reminder scheduled for \(routine.title) at \(routine.scheduledTime)")
            } catch {
                print("❌ Failed to schedule routine reminder: \(error)")
            }
        }
    }

    func cancelAllRoutineReminders() {
        notificationCenter.getPendingNotificationRequests { requests in
            let routineNotificationIds = requests
                .filter { $0.identifier.hasPrefix(self.routineNotificationPrefix) }
                .map { $0.identifier }

            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: routineNotificationIds)
        }
    }

    // MARK: - Streak Danger Alert

    /// Schedule a daily streak danger alert at 20:00
    /// This gets cancelled when the user is active (message, task, routine, focus)
    func scheduleStreakDangerAlert() async {
        guard settings.streakAlertEnabled else {
            cancelStreakDangerAlert()
            return
        }

        cancelStreakDangerAlert()

        let content = UNMutableNotificationContent()
        content.title = "Ta streak est en danger !"
        content.body = getStreakDangerPhrase()
        content.sound = .default
        content.badge = 1
        content.userInfo = ["deepLink": "focus://dashboard"]

        // Schedule daily at 20:00
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: streakAlertId,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("✅ Streak danger alert scheduled daily at 20:00")
        } catch {
            print("❌ Failed to schedule streak danger alert: \(error)")
        }
    }

    /// Cancel today's streak alert (user was active)
    func cancelStreakDangerAlert() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [streakAlertId])
    }

    /// Call this when the user completes an engagement action today
    /// Reschedules the streak alert for the next day only
    func markUserActiveToday() async {
        guard settings.streakAlertEnabled else { return }

        // Remove current alert
        cancelStreakDangerAlert()

        // Reschedule for tomorrow at 20:00 (will trigger only if user is inactive tomorrow)
        await scheduleStreakDangerAlert()
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

        // Get task reminder phrase
        let phrase = getTaskReminderPhrase(taskName: task.title)

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = phrase
        content.sound = .default
        content.badge = 1
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

    // MARK: - Phrase Generation (Local)

    private func getMorningPhrase() -> String {
        let lang = currentLanguageCode()

        // Local motivational phrases
        let frenchPhrases = [
            "C'est le moment de planifier ta journée et d'atteindre tes objectifs.",
            "Une nouvelle journée, de nouvelles opportunités. Tu vas tout déchirer !",
            "Chaque matin est une chance de devenir meilleur. Lance-toi !",
            "Ta journée commence maintenant. Fais-en quelque chose de grand.",
            "Le succès appartient à ceux qui commencent tôt. C'est ton moment."
        ]

        let englishPhrases = [
            "Time to plan your day and crush your goals.",
            "A new day, new opportunities. You've got this!",
            "Every morning is a chance to be better. Let's go!",
            "Your day starts now. Make it count.",
            "Success belongs to those who start early. This is your moment."
        ]

        let phrases = lang == "fr" ? frenchPhrases : englishPhrases
        return phrases.randomElement() ?? phrases[0]
    }

    private func getTaskReminderPhrase(taskName: String) -> String {
        let lang = currentLanguageCode()

        if lang == "fr" {
            return "C'est l'heure de te concentrer sur '\(taskName)' !"
        }
        return "Time to focus on '\(taskName)'!"
    }

    private func getEveningPhrase() -> String {
        let lang = currentLanguageCode()

        let frenchPhrases = [
            "Prends 2 minutes pour faire le point sur ta journee.",
            "Qu'est-ce que tu as accompli aujourd'hui ? Fais ton bilan.",
            "Ta journee se termine. Note ta plus grande victoire.",
            "Avant de dormir, prends un moment pour reflechir a ta journee.",
            "Un bilan rapide t'aidera a mieux demarrer demain."
        ]

        let englishPhrases = [
            "Take 2 minutes to review your day.",
            "What did you accomplish today? Do your review.",
            "Your day is ending. Note your biggest win.",
            "Before sleeping, take a moment to reflect on your day.",
            "A quick review will help you start tomorrow better."
        ]

        let phrases = lang == "fr" ? frenchPhrases : englishPhrases
        return phrases.randomElement() ?? phrases[0]
    }

    private func getRoutineReminderPhrase(routineName: String) -> String {
        let lang = currentLanguageCode()

        if lang == "fr" {
            return "C'est l'heure de '\(routineName)'. Reste constant !"
        }
        return "Time for '\(routineName)'. Stay consistent!"
    }

    private func getStreakDangerPhrase() -> String {
        let lang = currentLanguageCode()

        let frenchPhrases = [
            "Tu n'as pas encore ete actif aujourd'hui. Ne perds pas ta streak !",
            "Ta streak est en danger ! Ouvre Focus et fais au moins une chose.",
            "Il te reste peu de temps. Parle a ton coach ou complete une tache.",
            "Ne laisse pas une journee vide casser ta dynamique."
        ]

        let englishPhrases = [
            "You haven't been active today. Don't lose your streak!",
            "Your streak is at risk! Open Focus and do at least one thing.",
            "Time is running out. Talk to your coach or complete a task.",
            "Don't let an empty day break your momentum."
        ]

        let phrases = lang == "fr" ? frenchPhrases : englishPhrases
        return phrases.randomElement() ?? phrases[0]
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

    func updateEveningReminderEnabled(_ enabled: Bool) async {
        settings.eveningReminderEnabled = enabled
        if enabled {
            await scheduleEveningNotification()
        } else {
            cancelEveningNotification()
        }
    }

    func updateEveningReminderTime(_ time: Date) async {
        settings.eveningReminderTime = time
        if settings.eveningReminderEnabled {
            await scheduleEveningNotification()
        }
    }

    func updateRoutineRemindersEnabled(_ enabled: Bool) {
        settings.routineRemindersEnabled = enabled
        if !enabled {
            cancelAllRoutineReminders()
        }
    }

    func updateStreakAlertEnabled(_ enabled: Bool) async {
        settings.streakAlertEnabled = enabled
        if enabled {
            await scheduleStreakDangerAlert()
        } else {
            cancelStreakDangerAlert()
        }
    }
}
