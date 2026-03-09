import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var showTimePicker = false
    @State private var testNotificationSent = false

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Authorization Status
                authorizationSection

                if notificationService.isAuthorized {
                    // Morning Reminder Section
                    morningReminderSection

                    // Evening Reminder Section
                    eveningReminderSection

                    // Task Reminders Section
                    taskRemindersSection

                    // Routine Reminders Section
                    routineRemindersSection

                    // Afternoon Check Section
                    afternoonCheckSection

                    // Companion Nudges Section
                    companionNudgesSection

                    // Forgotten Ritual Section
                    forgottenRitualSection

                    // Test Section (DEBUG)
                    #if DEBUG
                    testNotificationSection
                    #endif
                }
            }
            .padding(SpacingTokens.lg)
        }
        .background(ColorTokens.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Authorization Section
    private var authorizationSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🔔")
                    .font(.satoshi(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Autorisation")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text(notificationService.isAuthorized ? "Notifications activées" : "Notifications désactivées")
                        .font(.satoshi(13))
                        .foregroundColor(notificationService.isAuthorized ? ColorTokens.success : ColorTokens.textSecondary)
                }

                Spacer()

                if notificationService.isAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ColorTokens.success)
                        .font(.satoshi(20))
                } else {
                    Button(action: {
                        Task {
                            await notificationService.requestAuthorization()
                        }
                    }) {
                        Text("Activer")
                            .font(.satoshi(14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.sm)
                            .background(ColorTokens.primaryStart)
                            .cornerRadius(RadiusTokens.md)
                    }
                }
            }
            .padding(SpacingTokens.lg)
        }
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Morning Reminder Section
    private var morningReminderSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🌅")
                    .font(.satoshi(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rappel matinal")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Reçois une phrase motivante chaque matin")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { notificationService.settings.morningReminderEnabled },
                    set: { newValue in
                        Task {
                            await notificationService.updateMorningReminderEnabled(newValue)
                        }
                    }
                ))
                .tint(ColorTokens.primaryStart)
            }

            if notificationService.settings.morningReminderEnabled {
                Divider()
                    .background(ColorTokens.border)

                // Time Picker
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(ColorTokens.textMuted)

                    Text("Heure du rappel")
                        .font(.satoshi(14))
                        .foregroundColor(ColorTokens.textSecondary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { notificationService.settings.morningReminderTime },
                            set: { newTime in
                                Task {
                                    await notificationService.updateMorningReminderTime(newTime)
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(ColorTokens.primaryStart)
                }
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Task Reminders Section
    private var taskRemindersSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("📋")
                    .font(.satoshi(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rappels de tâches")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Reçois un rappel avant tes tâches planifiées")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { notificationService.settings.taskRemindersEnabled },
                    set: { newValue in
                        notificationService.updateTaskRemindersEnabled(newValue)
                    }
                ))
                .tint(ColorTokens.primaryStart)
            }

            if notificationService.settings.taskRemindersEnabled {
                Divider()
                    .background(ColorTokens.border)

                // Minutes before picker
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(ColorTokens.textMuted)

                    Text("Rappel avant la tâche")
                        .font(.satoshi(14))
                        .foregroundColor(ColorTokens.textSecondary)

                    Spacer()

                    Picker("", selection: Binding(
                        get: { notificationService.settings.taskReminderMinutesBefore },
                        set: { newValue in
                            notificationService.updateTaskReminderMinutesBefore(newValue)
                        }
                    )) {
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                    }
                    .pickerStyle(.menu)
                    .tint(ColorTokens.primaryStart)
                }
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Evening Reminder Section
    private var eveningReminderSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🌙")
                    .font(.satoshi(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bilan du soir")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Rappel pour faire le point sur ta journée")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { notificationService.settings.eveningReminderEnabled },
                    set: { newValue in
                        Task {
                            await notificationService.updateEveningReminderEnabled(newValue)
                        }
                    }
                ))
                .tint(ColorTokens.primaryStart)
            }

            if notificationService.settings.eveningReminderEnabled {
                Divider()
                    .background(ColorTokens.border)

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(ColorTokens.textMuted)

                    Text("Heure du rappel")
                        .font(.satoshi(14))
                        .foregroundColor(ColorTokens.textSecondary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { notificationService.settings.eveningReminderTime },
                            set: { newTime in
                                Task {
                                    await notificationService.updateEveningReminderTime(newTime)
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(ColorTokens.primaryStart)
                }
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Routine Reminders Section
    private var routineRemindersSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🔁")
                    .font(.satoshi(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rappels de rituels")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Notification à l'heure de chaque rituel")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { notificationService.settings.routineRemindersEnabled },
                    set: { newValue in
                        notificationService.updateRoutineRemindersEnabled(newValue)
                    }
                ))
                .tint(ColorTokens.primaryStart)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Afternoon Check Section
    private var afternoonCheckSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("☀️")
                    .font(.satoshi(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Check après-midi")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Un rappel à 14h adapté à ton score du jour")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { notificationService.settings.afternoonCheckEnabled },
                    set: { newValue in
                        Task {
                            await notificationService.updateAfternoonCheckEnabled(newValue)
                        }
                    }
                ))
                .tint(ColorTokens.primaryStart)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Companion Nudges Section
    private var companionNudgesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("💬")
                    .font(.satoshi(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Messages du companion")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Ton coach te ping de temps en temps pour prendre des nouvelles")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { notificationService.settings.companionNudgesEnabled },
                    set: { newValue in
                        Task {
                            await notificationService.updateCompanionNudgesEnabled(newValue)
                        }
                    }
                ))
                .tint(ColorTokens.primaryStart)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Forgotten Ritual Section
    private var forgottenRitualSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("⏰")
                    .font(.satoshi(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rituels oubliés")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Rappel à 19h si des rituels ne sont pas faits")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { notificationService.settings.forgottenRitualEnabled },
                    set: { newValue in
                        Task {
                            await notificationService.updateForgottenRitualEnabled(newValue)
                        }
                    }
                ))
                .tint(ColorTokens.primaryStart)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Test Notification Section (DEBUG only)
    #if DEBUG
    private var testNotificationSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🧪")
                    .font(.satoshi(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tester les notifications")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Envoie une notification de test dans 5 secondes")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: SpacingTokens.md) {
                // Test Morning Notification
                Button(action: {
                    sendTestMorningNotification()
                }) {
                    HStack {
                        Image(systemName: "sun.rise.fill")
                        Text("Matinale")
                    }
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.sm)
                    .background(ColorTokens.primaryStart)
                    .cornerRadius(RadiusTokens.md)
                }

                // Test Task Notification
                Button(action: {
                    sendTestTaskNotification()
                }) {
                    HStack {
                        Image(systemName: "checklist")
                        Text("Tâche")
                    }
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.sm)
                    .background(ColorTokens.primaryStart)
                    .cornerRadius(RadiusTokens.md)
                }
            }

            if testNotificationSent {
                Text("Notification envoyée ! Elle arrivera dans 5 secondes.")
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.success)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    private func sendTestMorningNotification() {
        let content = UNMutableNotificationContent()
        let firstName = FocusAppStore.shared.user?.firstName
        if let name = firstName, !name.isEmpty {
            content.title = "Bonjour \(name) !"
        } else {
            content.title = "Bonjour !"
        }
        content.body = "C'est le moment de planifier ta journée et d'atteindre tes objectifs. Tu es capable de grandes choses !"
        content.sound = .default
        content.userInfo = ["deepLink": "focus://starttheday"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test.morning", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification error: \(error)")
            } else {
                DispatchQueue.main.async {
                    testNotificationSent = true
                    // Reset after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        testNotificationSent = false
                    }
                }
            }
        }
    }

    private func sendTestTaskNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Rappel de tâche"
        content.body = "C'est l'heure de te concentrer sur 'Tâche de test' ! Tu vas gérer !"
        content.sound = .default
        content.userInfo = ["deepLink": "focus://calendar"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test.task", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification error: \(error)")
            } else {
                DispatchQueue.main.async {
                    testNotificationSent = true
                    // Reset after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        testNotificationSent = false
                    }
                }
            }
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
