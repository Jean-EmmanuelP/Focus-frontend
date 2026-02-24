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
    var afternoonCheckEnabled: Bool
    var forgottenRitualEnabled: Bool
    var companionNudgesEnabled: Bool

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
            streakAlertEnabled: true,
            afternoonCheckEnabled: true,
            forgottenRitualEnabled: true,
            companionNudgesEnabled: true
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
    private let afternoonCheckId = "focus.afternoon.check"
    private let forgottenRitualId = "focus.ritual.forgotten"
    private let companionNudgePrefix = "focus.companion.nudge"

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

    // MARK: - Afternoon Satisfaction Check

    /// Schedule an afternoon notification at 14:00 to nudge the user based on their satisfaction score
    func scheduleAfternoonCheck() async {
        guard settings.afternoonCheckEnabled else {
            cancelAfternoonCheck()
            return
        }

        cancelAfternoonCheck()

        let score = UserDefaults.standard.object(forKey: "satisfaction_score") as? Int ?? 50
        let firstName = FocusAppStore.shared.user?.firstName

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.badge = 1
        content.userInfo = ["deepLink": "focus://dashboard"]

        // Adapt message to satisfaction score
        if score < 40 {
            content.title = firstName.map { "\($0), il est encore temps" } ?? "Il est encore temps"
            content.body = getAfternoonLowScorePhrase()
        } else if score < 70 {
            content.title = "Mi-journée"
            content.body = getAfternoonMediumScorePhrase()
        } else {
            content.title = "Continue comme ça"
            content.body = getAfternoonHighScorePhrase()
        }

        // Schedule daily at 14:00
        var dateComponents = DateComponents()
        dateComponents.hour = 14
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: afternoonCheckId,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("✅ Afternoon check scheduled daily at 14:00 (score: \(score))")
        } catch {
            print("❌ Failed to schedule afternoon check: \(error)")
        }
    }

    func cancelAfternoonCheck() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [afternoonCheckId])
    }

    // MARK: - Forgotten Ritual Reminder

    /// Schedule a notification at 19:00 to remind about uncompleted rituals
    func scheduleForgottenRitualReminder(uncompletedRituals: [String]) async {
        guard settings.forgottenRitualEnabled else {
            cancelForgottenRitualReminder()
            return
        }

        cancelForgottenRitualReminder()

        // Only schedule if there are uncompleted rituals
        guard !uncompletedRituals.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.badge = 1
        content.userInfo = ["deepLink": "focus://dashboard"]

        if uncompletedRituals.count == 1 {
            content.title = "Rituel oublié"
            content.body = "Tu n'as pas encore fait '\(uncompletedRituals[0])' aujourd'hui."
        } else {
            content.title = "\(uncompletedRituals.count) rituels restants"
            let names = uncompletedRituals.prefix(3).joined(separator: ", ")
            content.body = "Il te reste : \(names). Coche-les avant la fin de journée !"
        }

        // Schedule today at 19:00 if not past, otherwise skip
        let calendar = Calendar.current
        let now = Date()
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
        dateComponents.hour = 19
        dateComponents.minute = 0

        guard let reminderDate = calendar.date(from: dateComponents), reminderDate > now else { return }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: forgottenRitualId,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("✅ Forgotten ritual reminder scheduled for 19:00 (\(uncompletedRituals.count) uncompleted)")
        } catch {
            print("❌ Failed to schedule forgotten ritual reminder: \(error)")
        }
    }

    func cancelForgottenRitualReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [forgottenRitualId])
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

    // MARK: - Companion Nudge Notifications

    /// Schedule 2 companion nudge notifications per day for the next 7 days
    /// These feel like the companion casually checking in, not a robotic reminder
    func scheduleCompanionNudges() async {
        guard settings.companionNudgesEnabled else {
            cancelCompanionNudges()
            return
        }

        cancelCompanionNudges()

        let firstName = FocusAppStore.shared.user?.firstName
        let companionName = FocusAppStore.shared.user?.companionName ?? "ton coach"
        let calendar = Calendar.current

        // 2 nudge slots per day: late morning (~11h) and mid-afternoon (~16h)
        let nudgeSlots: [(baseHour: Int, label: String)] = [
            (11, "morning"),
            (16, "afternoon")
        ]

        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }

            for slot in nudgeSlots {
                let phrase = getCompanionNudgePhrase(slot: slot.label, firstName: firstName, companionName: companionName)

                let content = UNMutableNotificationContent()
                content.title = companionName
                content.body = phrase
                content.sound = .default
                content.userInfo = ["deepLink": "focus://dashboard"]

                // Add a few minutes of variance so it doesn't feel robotic
                let minuteVariance = (dayOffset * 7 + slot.baseHour) % 20 // 0-19 min variance per day
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: futureDate)
                dateComponents.hour = slot.baseHour
                dateComponents.minute = minuteVariance

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

                let identifier = "\(companionNudgePrefix).\(dayOffset).\(slot.label)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                do {
                    try await notificationCenter.add(request)
                } catch {
                    print("❌ Failed to schedule companion nudge: \(error)")
                }
            }
        }
        print("✅ Companion nudges scheduled for next 7 days")
    }

    func cancelCompanionNudges() {
        var identifiers: [String] = []
        for dayOffset in 1...7 {
            identifiers.append("\(companionNudgePrefix).\(dayOffset).morning")
            identifiers.append("\(companionNudgePrefix).\(dayOffset).afternoon")
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func updateCompanionNudgesEnabled(_ enabled: Bool) async {
        settings.companionNudgesEnabled = enabled
        if enabled {
            await scheduleCompanionNudges()
        } else {
            cancelCompanionNudges()
        }
    }

    // MARK: - Phrase Generation (Local)

    private func getMorningPhrase() -> String {
        let lang = currentLanguageCode()

        let frenchPhrases = [
            // Stoïciens
            "Que la force de tes pensées soit le moteur de ta journée. — Marc Aurèle",
            "Ce n'est pas ce qui t'arrive qui compte, mais comment tu y réagis. — Épictète",
            "La vie est courte. Cesse de remettre à demain. — Sénèque",
            "Tu as le pouvoir sur ton esprit, pas sur les événements. Réalise cela, et tu trouveras la force. — Marc Aurèle",
            "Le bonheur de ta vie dépend de la qualité de tes pensées. — Marc Aurèle",
            "Ce qui trouble les hommes, ce ne sont pas les choses, mais les jugements qu'ils portent sur elles. — Épictète",
            "Chaque jour est une petite vie. Vis-la pleinement. — Sénèque",
            // Auteurs français
            "Même la nuit la plus sombre prendra fin et le soleil se lèvera. — Victor Hugo",
            "Au milieu de l'hiver, j'ai découvert en moi un invincible été. — Albert Camus",
            "On ne voit bien qu'avec le cœur. L'essentiel est invisible pour les yeux. — Saint-Exupéry",
            "Fais de ta vie un rêve, et d'un rêve une réalité. — Saint-Exupéry",
            "Il n'y a qu'un héroïsme au monde : c'est de voir le monde tel qu'il est et de l'aimer. — Romain Rolland",
            "La vraie générosité envers l'avenir consiste à tout donner au présent. — Albert Camus",
            "Il faut imaginer Sisyphe heureux. — Albert Camus",
            "Rien n'est petit dans l'amour. Ceux qui attendent les grandes occasions pour prouver leur tendresse ne savent pas aimer. — Laure Conan",
            // Proverbes et sagesse
            "Celui qui déplace une montagne commence par déplacer de petites pierres. — Confucius",
            "Le meilleur moment pour planter un arbre était il y a vingt ans. Le deuxième meilleur moment, c'est maintenant.",
            "Un voyage de mille lieues commence par un seul pas. — Lao Tseu",
            "La discipline est le pont entre tes objectifs et leur réalisation.",
            "Sois le changement que tu veux voir dans le monde. — Gandhi",
            // Affirmations de développement personnel
            "Aujourd'hui, je choisis d'avancer avec courage et détermination.",
            "Je suis capable de grandes choses. Chaque petit pas compte.",
            "Ma concentration est mon super-pouvoir. Je l'utilise avec intention.",
            "Je ne contrôle pas tout, mais je contrôle mes efforts et mon attitude.",
            "Chaque journée est une page blanche. Écris une belle histoire.",
            "La constance bat le talent quand le talent manque de constance.",
            "Progresse, pas la perfection. Un pas à la fois.",
            "Ta seule limite est celle que tu te fixes.",
            "L'action est la clé fondamentale de tout succès. — Pablo Picasso",
            "Ce que tu fais aujourd'hui peut améliorer tous tes lendemains. — Ralph Marston",
        ]

        let englishPhrases = [
            // Stoics
            "Let the strength of your thoughts drive your day. — Marcus Aurelius",
            "It's not what happens to you, but how you react that matters. — Epictetus",
            "Life is short. Stop postponing. — Seneca",
            "You have power over your mind, not outside events. Realize this, and you will find strength. — Marcus Aurelius",
            "The happiness of your life depends on the quality of your thoughts. — Marcus Aurelius",
            "It is not things that disturb us, but our judgments about things. — Epictetus",
            "Every day is a little life. Live it fully. — Seneca",
            // Classic authors
            "Even the darkest night will end and the sun will rise. — Victor Hugo",
            "In the midst of winter, I found there was, within me, an invincible summer. — Albert Camus",
            "It is only with the heart that one can see rightly. What is essential is invisible to the eye. — Saint-Exupéry",
            "Make your life a dream, and a dream a reality. — Saint-Exupéry",
            "There is only one heroism in the world: to see the world as it is and to love it. — Romain Rolland",
            "Real generosity toward the future lies in giving all to the present. — Albert Camus",
            "One must imagine Sisyphus happy. — Albert Camus",
            "We suffer more in imagination than in reality. — Seneca",
            // Proverbs and wisdom
            "The man who moves a mountain begins by carrying away small stones. — Confucius",
            "The best time to plant a tree was twenty years ago. The second best time is now.",
            "A journey of a thousand miles begins with a single step. — Lao Tzu",
            "Discipline is the bridge between your goals and their accomplishment.",
            "Be the change you wish to see in the world. — Gandhi",
            // Personal growth affirmations
            "Today, I choose to move forward with courage and determination.",
            "I am capable of great things. Every small step matters.",
            "My focus is my superpower. I use it with intention.",
            "I can't control everything, but I can control my effort and my attitude.",
            "Every day is a blank page. Write a great story.",
            "Consistency beats talent when talent doesn't show up consistently.",
            "Progress, not perfection. One step at a time.",
            "Your only limit is the one you set for yourself.",
            "Action is the foundational key to all success. — Pablo Picasso",
            "What you do today can improve all your tomorrows. — Ralph Marston",
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

    private func getAfternoonLowScorePhrase() -> String {
        let phrases = [
            "Ta journée n'a pas encore démarré côté productivité. Un seul rituel ou tâche peut tout changer.",
            "Score bas aujourd'hui — c'est le moment de se rattraper. Choisis UNE chose et fais-la.",
            "Il te reste l'après-midi pour remonter. Ouvre Focus et parle à ton coach.",
            "La journée n'est pas finie. Même une petite action compte."
        ]
        return phrases.randomElement() ?? phrases[0]
    }

    private func getAfternoonMediumScorePhrase() -> String {
        let phrases = [
            "Pas mal, mais tu peux encore monter. Qu'est-ce que tu peux cocher cet après-midi ?",
            "Mi-journée. Regarde tes tâches restantes et finis en beauté.",
            "Tu avances bien. Continue sur cette lancée cet après-midi !",
            "Bon rythme. Encore un ou deux rituels et ta journée sera top."
        ]
        return phrases.randomElement() ?? phrases[0]
    }

    private func getAfternoonHighScorePhrase() -> String {
        let phrases = [
            "Tu gères ! Journée excellente. Continue comme ça.",
            "Score au top — profite de cette énergie pour finir ce qu'il reste.",
            "Impressionnant aujourd'hui. Tu mérites cette satisfaction.",
            "Belle journée en cours. Maintiens le cap !"
        ]
        return phrases.randomElement() ?? phrases[0]
    }

    private func getCompanionNudgePhrase(slot: String, firstName: String?, companionName: String) -> String {
        let lang = currentLanguageCode()
        let name = (firstName != nil && !firstName!.isEmpty) ? " \(firstName!)" : ""

        if lang == "fr" {
            let morningPhrases = [
                "Ça va\(name) ? Si t'as besoin, je suis là.",
                "Tu fais quoi de beau ce matin\(name) ?",
                "Hey\(name). Petite pause pour checker comment tu vas.",
                "Juste un coucou\(name). T'avances bien ?",
                "Hey\(name) ! Raconte-moi ta matinée.",
                "Tu tiens le rythme\(name) ? Je pense à toi.",
                "Check rapide\(name) — t'as besoin d'un coup de main ?",
                "Yo\(name). T'es sur quoi là ?",
            ]

            let afternoonPhrases = [
                "Hey\(name). Comment se passe ton aprèm ?",
                "Coucou\(name). Tu gères ?",
                "Petite pensée pour toi\(name). Continue !",
                "Hey\(name), t'as pris une pause aujourd'hui ?",
                "Yo\(name). Tu kiffes ta journée ?",
                "Juste pour dire : t'assures\(name).",
                "Check-in de l'aprèm\(name). Tout roule ?",
                "Hey\(name). On se fait un point rapide ?",
            ]

            let pool = slot == "morning" ? morningPhrases : afternoonPhrases
            return pool.randomElement() ?? pool[0]
        }

        let morningPhrases = [
            "How's it going\(name)? I'm here if you need me.",
            "What are you working on this morning\(name)?",
            "Hey\(name). Quick check — how are you feeling?",
            "Just saying hi\(name). Making progress?",
            "Morning check-in\(name). Need a hand with anything?",
            "Hey\(name)! Tell me about your morning.",
            "Keeping the momentum\(name)? Thinking of you.",
            "Yo\(name). What are you up to?",
        ]

        let afternoonPhrases = [
            "Hey\(name). How's your afternoon going?",
            "Hi\(name). You're doing great.",
            "Just thinking of you\(name). Keep going!",
            "Hey\(name), have you taken a break today?",
            "Yo\(name). Enjoying your day?",
            "Just wanted to say: you're doing well\(name).",
            "Afternoon check-in\(name). Everything good?",
            "Hey\(name). Want to do a quick recap?",
        ]

        let pool = slot == "morning" ? morningPhrases : afternoonPhrases
        return pool.randomElement() ?? pool[0]
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

    func updateAfternoonCheckEnabled(_ enabled: Bool) async {
        settings.afternoonCheckEnabled = enabled
        if enabled {
            await scheduleAfternoonCheck()
        } else {
            cancelAfternoonCheck()
        }
    }

    func updateForgottenRitualEnabled(_ enabled: Bool) {
        settings.forgottenRitualEnabled = enabled
        if !enabled {
            cancelForgottenRitualReminder()
        }
    }
}
