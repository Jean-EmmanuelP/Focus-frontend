import Foundation
import Combine
import UserNotifications

// MARK: - Wake-Up Challenge Service

@MainActor
class WakeUpService: ObservableObject {
    static let shared = WakeUpService()

    @Published var challenge: WakeUpChallenge {
        didSet { save() }
    }

    private let storageKey = "wake_up_challenge"
    private let notificationPrefix = "wakeup_alarm_"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(WakeUpChallenge.self, from: data) {
            self.challenge = decoded
        } else {
            self.challenge = .default
        }
        // Reset confirmedToday if it's a new day
        checkNewDay()
    }

    // MARK: - Alarm Scheduling

    func scheduleAlarm() {
        cancelAlarm()
        guard challenge.isEnabled else { return }

        let parts = challenge.alarmTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let hour = parts[0], minute = parts[1]

        // Schedule 3 notifications: on time, +5min, +10min
        let offsets = [0, 5, 10]
        for (index, offset) in offsets.enumerated() {
            let content = UNMutableNotificationContent()
            if index == 0 {
                content.title = "C'est l'heure !"
                content.body = "Ouvre l'app et confirme que tu es réveillé pour garder ton streak."
            } else {
                content.title = "Tu es réveillé ?"
                content.body = "Plus que \(challenge.gracePeriodMinutes - offset) minutes pour confirmer ton réveil !"
            }
            content.sound = .default // iOS doesn't allow true alarm sounds from 3rd party apps
            content.categoryIdentifier = "WAKE_UP_ALARM"
            content.userInfo = [
                "type": "wake_up_alarm",
                "deepLink": "focus://wakeup-confirm",
            ]

            // Use Calendar arithmetic to handle midnight overflow correctly
            var baseComponents = DateComponents()
            baseComponents.hour = hour
            baseComponents.minute = minute
            guard let baseDate = Calendar.current.date(from: baseComponents),
                  let offsetDate = Calendar.current.date(byAdding: .minute, value: offset, to: baseDate) else { continue }
            var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: offsetDate)

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(notificationPrefix)\(index)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("⚠️ WakeUp notification schedule error: \(error)")
                }
            }
        }

        // Register notification actions
        let confirmAction = UNNotificationAction(
            identifier: "WAKEUP_CONFIRM",
            title: "Je suis réveillé !",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: "WAKEUP_SNOOZE",
            title: "5 min de plus",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "WAKE_UP_ALARM",
            actions: [confirmAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        print("⏰ Wake-up alarm scheduled at \(challenge.alarmTime) with \(offsets.count) notifications")
    }

    func cancelAlarm() {
        let ids = (0..<3).map { "\(notificationPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        print("⏰ Wake-up alarm cancelled")
    }

    // MARK: - Wake-Up Confirmation

    func confirmWakeUp() {
        guard !challenge.confirmedToday else { return } // Prevent double confirmation
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: now)

        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: now)

        // Check if within grace period
        let parts = challenge.alarmTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }

        let alarmMinutes = parts[0] * 60 + parts[1]
        let calendar = Calendar.current
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let diff = nowMinutes - alarmMinutes

        let isOnTime = diff >= -5 && diff <= challenge.gracePeriodMinutes

        if isOnTime {
            // Streak continues or starts
            if challenge.lastWakeUpDate == previousDayString() || challenge.wakeUpStreak == 0 {
                challenge.wakeUpStreak += 1
            } else if challenge.lastWakeUpDate != dateStr {
                // Missed yesterday → reset
                challenge.wakeUpStreak = 1
            }
            challenge.longestStreak = max(challenge.longestStreak, challenge.wakeUpStreak)
        } else if diff > challenge.gracePeriodMinutes {
            // Too late → streak broken
            challenge.wakeUpStreak = 0
        }
        // If before alarm (diff < -5), probably just opening the app early — don't count

        challenge.lastWakeUpDate = dateStr
        challenge.lastWakeUpTime = timeStr
        challenge.confirmedToday = true

        print("⏰ Wake-up confirmed at \(timeStr) | On time: \(isOnTime) | Streak: \(challenge.wakeUpStreak)")
    }

    /// Returns the wake-up status message for the coach
    func wakeUpStatusMessage() -> String {
        guard challenge.isEnabled else { return "" }
        guard challenge.confirmedToday, let time = challenge.lastWakeUpTime else {
            return "L'utilisateur ne s'est pas encore réveillé aujourd'hui. Son alarme est à \(challenge.alarmTime)."
        }
        let parts = challenge.alarmTime.split(separator: ":").compactMap { Int($0) }
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, timeParts.count == 2 else { return "" }

        let diff = (timeParts[0] * 60 + timeParts[1]) - (parts[0] * 60 + parts[1])
        if diff <= 0 {
            return "Réveillé à \(time), en avance ! Streak: \(challenge.wakeUpStreak) jours."
        } else if diff <= challenge.gracePeriodMinutes {
            return "Réveillé à \(time), \(diff) min après l'alarme mais dans les temps. Streak: \(challenge.wakeUpStreak) jours."
        } else {
            return "Réveillé à \(time), \(diff) min de retard. Streak perdu."
        }
    }

    // MARK: - Handle Notification Actions

    func handleNotificationAction(_ actionIdentifier: String) {
        switch actionIdentifier {
        case "WAKEUP_CONFIRM", UNNotificationDefaultActionIdentifier:
            confirmWakeUp()
        case "WAKEUP_SNOOZE":
            // The +5min and +10min notifications are already scheduled
            print("⏰ Snooze — next alarm in 5 min")
        default:
            break
        }
    }

    // MARK: - Private Helpers

    private func checkNewDay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        if challenge.lastWakeUpDate != today {
            challenge.confirmedToday = false
        }
    }

    private func previousDayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return formatter.string(from: yesterday)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(challenge) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
