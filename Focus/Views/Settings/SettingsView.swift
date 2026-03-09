import SwiftUI
import SceneKit
import GLTFKit2
import Combine
import AVFoundation

// MARK: - UserDefaults Keys for Settings Preferences
enum SettingsPrefsKeys {
    static let avatarHerited = "pref_avatarHerited"
    static let showFocusInChat = "pref_showFocusInChat"
    static let showLevel = "pref_showLevel"
    static let backgroundMusic = "pref_backgroundMusic"
    static let sounds = "pref_sounds"
    static let faceID = "pref_faceID"
    static let voltaVoiceId = "pref_voltaVoiceId"
}

// MARK: - Replika Settings Colors

private enum ReplicaColors {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.15, green: 0.18, blue: 0.45),  // Dark blue top
            Color(red: 0.18, green: 0.22, blue: 0.52),  // Mid blue
            Color(red: 0.20, green: 0.25, blue: 0.58)   // Lighter blue bottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let backgroundSolid = Color(red: 0.16, green: 0.19, blue: 0.48)
    static let rowDivider = Color.white.opacity(0.08)
    static let sectionHeader = Color.white.opacity(0.5)
    static let chevron = Color.white.opacity(0.4)
    static let toggleBlue = Color(red: 0.25, green: 0.50, blue: 1.0)
    static let closeButton = Color.white.opacity(0.15)
}

// MARK: - Main Replika Settings View

struct SettingsView: View {
    var onDismiss: () -> Void
    @EnvironmentObject var store: FocusAppStore
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    private var companionName: String {
        store.user?.companionName ?? "ton coach"
    }

    // Settings state (persisted in UserDefaults)
    @State private var avatarHerited = true
    @State private var showFocusInChat = true
    @State private var selfieMode = true
    @State private var showLevel = false
    @State private var backgroundMusic = false
    @State private var sounds = true
    @State private var notificationsEnabled = true
    @State private var coachHarshMode = false
    @State private var faceID = false
    @State private var selectedVoiceId: String = "b35yykvVppLXyw_l"

    // Tracks whether initial load is done (to avoid saving defaults on appear)
    @State private var didLoadSettings = false

    // Sub-page navigation (fade overlays)
    @State private var showAccount = false
    @State private var showVoicePicker = false
    @State private var showEditName = false
    @State private var showEditPronouns = false
    @State private var showChangeEmail = false
    @State private var showChangePassword = false
    @State private var showDeleteAccount = false
    @State private var showSubscription = false
    @State private var showOnboarding = false
    @State private var showAvatarTest = false
    @State private var showAppBlocker = false
    @State private var showEditCoachName = false

    private let userService = UserService()

    /// Combined hash of all local preferences to trigger a single onChange
    private var preferencesHash: Int {
        var hasher = Hasher()
        hasher.combine(avatarHerited)
        hasher.combine(showFocusInChat)
        hasher.combine(showLevel)
        hasher.combine(backgroundMusic)
        hasher.combine(sounds)
        hasher.combine(faceID)
        hasher.combine(selectedVoiceId)
        return hasher.finalize()
    }

    var body: some View {
        settingsContent
            .onAppear { loadSettings() }
            .onChange(of: notificationsEnabled) { _, _ in if didLoadSettings { saveNotificationSettings() } }
            .onChange(of: coachHarshMode) { _, _ in if didLoadSettings { saveCoachHarshMode() } }
            .onChange(of: preferencesHash) { _, _ in if didLoadSettings { savePreferences() } }
            .overlay { accountOverlays }
            .overlay { editOverlays }
            .overlay { miscOverlays }
            .fullScreenCover(isPresented: $showOnboarding) {
                NewOnboardingView()
                    .environmentObject(store)
                    .environmentObject(SubscriptionManager.shared)
            }
            .animation(.easeInOut(duration: 0.3), value: showEditCoachName)
            .animation(.easeInOut(duration: 0.3), value: showVoicePicker)
            .animation(.easeInOut(duration: 0.3), value: showAppBlocker)
            .animation(.easeInOut(duration: 0.3), value: showAvatarTest)
            .animation(.easeInOut(duration: 0.3), value: showSubscription)
            .animation(.easeInOut(duration: 0.3), value: showAccount)
            .animation(.easeInOut(duration: 0.3), value: showEditName)
            .animation(.easeInOut(duration: 0.3), value: showEditPronouns)
            .animation(.easeInOut(duration: 0.3), value: showChangeEmail)
            .animation(.easeInOut(duration: 0.3), value: showChangePassword)
            .animation(.easeInOut(duration: 0.3), value: showDeleteAccount)
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        ZStack {
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                replicaHeader(title: "Paramètres", showBack: false, onClose: onDismiss)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        promoBanner
                            .padding(.top, 8)
                        accountSection
                            .padding(.top, 24)
                        preferencesSection
                            .padding(.top, 24)
                        resourcesSection
                            .padding(.top, 24)
                        communitySection
                            .padding(.top, 24)
                        signOutButton
                            .padding(.top, 32)
                            .padding(.horizontal, 40)
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                        #if DEBUG
                        debugSection
                            .padding(.bottom, 32)
                        #endif
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Account Overlays

    @ViewBuilder
    private var accountOverlays: some View {
        if showAccount {
            ReplicaAccountView(
                onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showAccount = false } },
                onShowEditName: { withAnimation(.easeInOut(duration: 0.3)) { showEditName = true } },
                onShowEditPronouns: { withAnimation(.easeInOut(duration: 0.3)) { showEditPronouns = true } },
                onShowChangeEmail: { withAnimation(.easeInOut(duration: 0.3)) { showChangeEmail = true } },
                onShowChangePassword: { withAnimation(.easeInOut(duration: 0.3)) { showChangePassword = true } },
                onShowDeleteAccount: { withAnimation(.easeInOut(duration: 0.3)) { showDeleteAccount = true } }
            )
            .environmentObject(store)
            .transition(.opacity)
        } else if showSubscription {
            FocusPaywallView(
                companionName: companionName,
                onComplete: {
                    withAnimation(.easeInOut(duration: 0.3)) { showSubscription = false }
                },
                onSkip: {
                    withAnimation(.easeInOut(duration: 0.3)) { showSubscription = false }
                }
            )
            .environmentObject(subscriptionManager)
            .transition(.opacity)
        } else if showDeleteAccount {
            ReplicaDeleteAccountView(
                userName: store.user?.firstName ?? store.user?.name ?? "Utilisateur",
                onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showDeleteAccount = false } },
                onConfirm: { deleteAccount() }
            )
            .transition(.opacity)
        }
    }

    // MARK: - Edit Overlays

    @ViewBuilder
    private var editOverlays: some View {
        if showEditName {
            ReplicaEditNameView(
                currentName: store.user?.firstName ?? store.user?.name ?? "",
                onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showEditName = false } },
                onSave: { name in
                    store.user?.firstName = name
                    withAnimation(.easeInOut(duration: 0.3)) { showEditName = false }
                    Task { await updateName(name) }
                }
            )
            .transition(.opacity)
        } else if showEditPronouns {
            ReplicaEditPronounsView(
                currentPronouns: store.user?.gender ?? "male",
                onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showEditPronouns = false } },
                onSave: { pronouns in
                    store.user?.gender = pronouns
                    withAnimation(.easeInOut(duration: 0.3)) { showEditPronouns = false }
                    Task { await updatePronouns(pronouns) }
                }
            )
            .transition(.opacity)
        } else if showChangeEmail {
            ReplicaChangeEmailView(
                currentEmail: store.user?.email ?? "",
                onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showChangeEmail = false } },
                onSave: { email, password in
                    Task {
                        do {
                            try await AuthService.shared.updateEmail(newEmail: email)
                            await MainActor.run {
                                store.user?.email = email
                                withAnimation(.easeInOut(duration: 0.3)) { showChangeEmail = false }
                            }
                        } catch {
                            print("Failed to update email: \(error)")
                        }
                    }
                }
            )
            .transition(.opacity)
        } else if showChangePassword {
            ReplicaChangePasswordView(
                onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showChangePassword = false } }
            )
            .transition(.opacity)
        } else if showEditCoachName {
            ReplicaEditNameView(
                currentName: companionName,
                onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showEditCoachName = false } },
                onSave: { name in
                    withAnimation(.easeInOut(duration: 0.3)) { showEditCoachName = false }
                    Task { await updateCoachName(name) }
                }
            )
            .transition(.opacity)
        }
    }

    // MARK: - Misc Overlays

    @ViewBuilder
    private var miscOverlays: some View {
        if showAvatarTest {
            AvatarTestView(onDismiss: {
                withAnimation(.easeInOut(duration: 0.3)) { showAvatarTest = false }
            })
            .transition(.opacity)
        } else if showAppBlocker {
            AppBlockerSettingsView(onDismiss: {
                withAnimation(.easeInOut(duration: 0.3)) { showAppBlocker = false }
            })
            .transition(.opacity)
        } else if showVoicePicker {
            VoltaVoicePickerView(
                currentVoiceId: selectedVoiceId,
                onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showVoicePicker = false } },
                onSave: { voiceId in
                    selectedVoiceId = voiceId
                    withAnimation(.easeInOut(duration: 0.3)) { showVoicePicker = false }
                    Task {
                        do {
                            let updated = try await userService.updateSettings(voiceId: voiceId)
                            await MainActor.run { store.user = User(from: updated) }
                        } catch {
                            print("Failed to save voice_id: \(error)")
                        }
                    }
                }
            )
            .transition(.opacity)
        }
    }

    // MARK: - Promo Banner

    private var promoBanner: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showSubscription = true
            }
        }) {
            HStack(spacing: 16) {
                // 3D Avatar preview
                Avatar3DView(
                    avatarURL: AvatarURLs.forGender(store.user?.companionGender),
                    backgroundColor: .clear,
                    enableRotation: false,
                    autoRotate: false
                )
                .frame(width: 100, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Débloquez toutes les fonctionnalités")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Text("Messages vocaux illimités, génération d'images, activités, et plus encore.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.25, blue: 0.65),
                                Color(red: 0.20, green: 0.35, blue: 0.75),
                                Color(red: 0.15, green: 0.30, blue: 0.70)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 0) {
            // Compte
            Button(action: { withAnimation(.easeInOut(duration: 0.3)) { showAccount = true } }) {
                settingsRow(title: "Compte", showChevron: true)
            }

            replicaDivider

            // Historique des versions
            Button(action: {}) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Historique des versions")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Advanced")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReplicaColors.chevron)
                }
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(spacing: 0) {
            sectionLabel("Préférences")

            toggleRow(title: "Avatar hérité", isOn: $avatarHerited)
            replicaDivider
            toggleRow(title: "Afficher Replika dans le chat", isOn: $showFocusInChat)
            replicaDivider
            toggleRow(title: "Mode selfie pour appel vidéo", isOn: $selfieMode)
            replicaDivider
            toggleRow(title: "Afficher le niveau", isOn: $showLevel)
            replicaDivider
            toggleRow(title: "Musique de fond", isOn: $backgroundMusic)
            replicaDivider
            toggleRow(title: "Sons", isOn: $sounds)
            replicaDivider
            Button(action: { withAnimation(.easeInOut(duration: 0.3)) { showVoicePicker = true } }) {
                HStack {
                    Text("Voix de Volta")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                    Text(VoltaVoicePickerView.voiceName(for: selectedVoiceId))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReplicaColors.chevron)
                }
                .padding(.vertical, 14)
            }
            replicaDivider
            Button(action: { withAnimation(.easeInOut(duration: 0.3)) { showEditCoachName = true } }) {
                HStack {
                    Text("Nom du coach")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                    Text(companionName)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReplicaColors.chevron)
                }
                .padding(.vertical, 14)
            }
            replicaDivider
            toggleRow(title: "Notifications", isOn: $notificationsEnabled)
            replicaDivider
            toggleRow(title: "Mode coach dur", isOn: $coachHarshMode)
            replicaDivider
            toggleRow(title: "Face ID", isOn: $faceID)
            replicaDivider
            Button(action: { withAnimation(.easeInOut(duration: 0.3)) { showAppBlocker = true } }) {
                settingsRow(title: "Bloquer les apps", showChevron: true)
            }
        }
    }

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(spacing: 0) {
            sectionLabel("Ressources")

            externalLinkRow(title: "Centre d'aide", url: "https://firelevel.app/help")
            replicaDivider
            externalLinkRow(title: "Évaluez-nous", url: "https://apps.apple.com/app/id123456789")
            replicaDivider
            externalLinkRow(title: "Conditions d'utilisation", url: "https://firelevel.app/terms")
            replicaDivider
            externalLinkRow(title: "Politique de confidentialité", url: "https://firelevel.app/privacy")
            replicaDivider
            externalLinkRow(title: "Crédits", url: "https://firelevel.app/credits")
        }
    }

    // MARK: - Community Section

    private var communitySection: some View {
        VStack(spacing: 0) {
            sectionLabel("Rejoignez notre communauté")

            communityRow(iconName: "reddit", title: "Reddit", url: "https://reddit.com/r/focus")
            replicaDivider
            communityRow(iconName: "discord", title: "Discord", url: "https://discord.gg/focus")
            replicaDivider
            communityRow(iconName: "facebook", title: "Facebook", url: "https://facebook.com/focusapp")
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button(action: {
            AppRouter.shared.showSettings = false
            FocusAppStore.shared.signOut()
            onDismiss()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text("Se déconnecter")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
            )
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        VStack(spacing: 0) {
            sectionLabel("Développeur")

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showOnboarding = true
                }
            }) {
                settingsRow(title: "Debug Onboarding", showChevron: true)
            }

            replicaDivider

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAvatarTest = true
                }
            }) {
                settingsRow(title: "Test Avatar 3D", showChevron: true)
            }

        }
        .padding(.horizontal, 16)
    }
    #endif

    // MARK: - Row Components

    private func settingsRow(title: String, showChevron: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ReplicaColors.chevron)
            }
        }
        .padding(.vertical, 14)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ReplicaColors.toggleBlue)
        }
        .padding(.vertical, 10)
    }

    private func externalLinkRow(title: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ReplicaColors.chevron)
            }
            .padding(.vertical, 14)
        }
    }

    private func communityRow(iconName: String, title: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                // Real brand logos
                Group {
                    switch iconName {
                    case "reddit":
                        RedditLogoView()
                    case "discord":
                        DiscordLogoView()
                    case "facebook":
                        FacebookLogoView()
                    default:
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "link")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 28, height: 28)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ReplicaColors.chevron)
            }
            .padding(.vertical, 14)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(ReplicaColors.sectionHeader)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var replicaDivider: some View {
        Divider()
            .background(ReplicaColors.rowDivider)
    }

    // MARK: - Helper Functions

    private func loadSettings() {
        let defaults = UserDefaults.standard

        // Load persisted preferences
        if defaults.object(forKey: SettingsPrefsKeys.avatarHerited) != nil {
            avatarHerited = defaults.bool(forKey: SettingsPrefsKeys.avatarHerited)
        }
        if defaults.object(forKey: SettingsPrefsKeys.showFocusInChat) != nil {
            showFocusInChat = defaults.bool(forKey: SettingsPrefsKeys.showFocusInChat)
        }
        if defaults.object(forKey: SettingsPrefsKeys.showLevel) != nil {
            showLevel = defaults.bool(forKey: SettingsPrefsKeys.showLevel)
        }
        if defaults.object(forKey: SettingsPrefsKeys.backgroundMusic) != nil {
            backgroundMusic = defaults.bool(forKey: SettingsPrefsKeys.backgroundMusic)
        }
        if defaults.object(forKey: SettingsPrefsKeys.sounds) != nil {
            sounds = defaults.bool(forKey: SettingsPrefsKeys.sounds)
        }
        if defaults.object(forKey: SettingsPrefsKeys.faceID) != nil {
            faceID = defaults.bool(forKey: SettingsPrefsKeys.faceID)
        }
        if let voiceId = defaults.string(forKey: SettingsPrefsKeys.voltaVoiceId) {
            selectedVoiceId = voiceId
        }

        // Load from user profile (backend takes precedence)
        if let user = store.user {
            notificationsEnabled = user.notificationsEnabled ?? true
            coachHarshMode = user.coachHarshMode ?? false
            if let backendVoiceId = user.voiceId, !backendVoiceId.isEmpty {
                selectedVoiceId = backendVoiceId
                defaults.set(backendVoiceId, forKey: SettingsPrefsKeys.voltaVoiceId)
            }
        }

        // Mark loading complete so onChange handlers can now save
        didLoadSettings = true
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(avatarHerited, forKey: SettingsPrefsKeys.avatarHerited)
        defaults.set(showFocusInChat, forKey: SettingsPrefsKeys.showFocusInChat)
        defaults.set(showLevel, forKey: SettingsPrefsKeys.showLevel)
        defaults.set(backgroundMusic, forKey: SettingsPrefsKeys.backgroundMusic)
        defaults.set(sounds, forKey: SettingsPrefsKeys.sounds)
        defaults.set(faceID, forKey: SettingsPrefsKeys.faceID)
        defaults.set(selectedVoiceId, forKey: SettingsPrefsKeys.voltaVoiceId)
    }

    private func saveNotificationSettings() {
        Task {
            do {
                let updated = try await userService.updateSettings(
                    notificationsEnabled: notificationsEnabled,
                    morningReminderTime: nil
                )
                await MainActor.run {
                    store.user = User(from: updated)
                }
            } catch {
                print("Failed to save notification settings: \(error)")
            }
        }
    }

    private func saveCoachHarshMode() {
        Task {
            do {
                let updated = try await userService.updateSettings(
                    coachHarshMode: coachHarshMode
                )
                await MainActor.run {
                    store.user = User(from: updated)
                }
            } catch {
                print("Failed to save coach harsh mode: \(error)")
            }
        }
    }

    private func updateName(_ name: String) async {
        do {
            let updated = try await userService.updateProfile(firstName: name)
            await MainActor.run {
                FocusAppStore.shared.user = User(from: updated)
            }
        } catch {
            print("Failed to update name: \(error)")
        }
    }

    private func updateCoachName(_ name: String) async {
        do {
            let updated = try await userService.updateProfile(companionName: name)
            await MainActor.run {
                FocusAppStore.shared.user = User(from: updated)
            }
            // Recreate assistant so the new companion name is reflected in the system prompt
            await BackboardService.shared.recreateAssistant()
        } catch {
            print("Failed to update coach name: \(error)")
        }
    }

    private func updatePronouns(_ pronouns: String) async {
        do {
            let updated = try await userService.updateProfile(
                pseudo: nil, firstName: nil, lastName: nil,
                gender: pronouns, age: nil, birthday: nil, description: nil,
                hobbies: nil, lifeGoal: nil
            )
            await MainActor.run {
                FocusAppStore.shared.user = User(from: updated)
            }
        } catch {
            print("Failed to update pronouns: \(error)")
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await userService.deleteAccount()
                await MainActor.run {
                    AppRouter.shared.showSettings = false
                    FocusAppStore.shared.signOut()
                    onDismiss()
                }
            } catch {
                print("Failed to delete account: \(error)")
            }
        }
    }
}

// MARK: - Replika Header Component

private func replicaHeader(title: String, showBack: Bool, onClose: @escaping () -> Void) -> some View {
    ZStack {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)

        HStack {
            if showBack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(ReplicaColors.closeButton))
                }
            }

            Spacer()

            if !showBack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(ReplicaColors.closeButton))
                }
            }
        }
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 8)
}

// MARK: - Account View

struct ReplicaAccountView: View {
    var onDismiss: () -> Void
    var onShowEditName: () -> Void
    var onShowEditPronouns: () -> Void
    var onShowChangeEmail: () -> Void
    var onShowChangePassword: () -> Void
    var onShowDeleteAccount: () -> Void

    @EnvironmentObject var store: FocusAppStore

    private var pronounsDisplay: String {
        switch store.user?.gender {
        case "elle_la", "she", "female": return "Elle / La"
        case "il_lui", "he", "male": return "Il / Lui"
        case "iel_iels", "they", "other": return "Iel / Iels"
        default: return "Non défini"
        }
    }

    private var accountAgeDisplay: String {
        guard let createdAt = store.user?.createdAt else {
            return "Récemment"
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: createdAt, to: Date())
        if let years = components.year, years > 0 {
            return years == 1 ? "1 an" : "\(years) ans"
        } else if let months = components.month, months > 0 {
            return months == 1 ? "1 mois" : "\(months) mois"
        } else if let days = components.day, days > 0 {
            return days == 1 ? "1 jour" : "\(days) jours"
        } else {
            return "Aujourd'hui"
        }
    }

    var body: some View {
        ZStack {
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with back button
                replicaHeader(title: "Compte", showBack: true, onClose: onDismiss)

                VStack(spacing: 0) {
                    // Nom
                    Button(action: onShowEditName) {
                        accountRow(label: "Nom", value: store.user?.firstName ?? store.user?.name ?? "Non défini")
                    }

                    Divider().background(ReplicaColors.rowDivider)

                    // Membre depuis (non-editable)
                    accountRow(label: "Membre depuis", value: accountAgeDisplay, showChevron: false)

                    Divider().background(ReplicaColors.rowDivider)

                    // Pronoms
                    Button(action: onShowEditPronouns) {
                        accountRow(label: "Pronoms", value: pronounsDisplay)
                    }

                    Divider().background(ReplicaColors.rowDivider)

                    // Changer l'email
                    Button(action: onShowChangeEmail) {
                        accountRow(label: "Changer l'email", value: store.user?.email ?? "")
                    }

                    Divider().background(ReplicaColors.rowDivider)

                    // Changer le mot de passe
                    Button(action: onShowChangePassword) {
                        HStack {
                            Text("Changer le mot de passe")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ReplicaColors.chevron)
                        }
                        .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer().frame(height: 32)

                // Delete account link
                Button(action: onShowDeleteAccount) {
                    Text("Supprimer le compte")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
        }
    }

    private func accountRow(label: String, value: String, showChevron: Bool = true) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ReplicaColors.chevron)
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Edit Name View

struct ReplicaEditNameView: View {
    let currentName: String
    var onDismiss: () -> Void
    var onSave: (String) -> Void

    @State private var name: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                replicaHeader(title: "Nom", showBack: true, onClose: onDismiss)

                // Text field
                TextField("", text: $name, prompt: Text("Votre nom").foregroundColor(.gray))
                    .font(.system(size: 17))
                    .foregroundColor(ReplicaColors.backgroundSolid)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(28)
                    .focused($isInputFocused)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                Spacer()

                // Save button
                Button(action: { onSave(name) }) {
                    Text("Sauvegarder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ReplicaColors.backgroundSolid)
                        .frame(width: 200, height: 56)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                        )
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            name = currentName
            isInputFocused = true
        }
    }
}

// MARK: - Change Password View

struct ReplicaChangePasswordView: View {
    var onDismiss: () -> Void

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case newPassword, confirmPassword
    }

    private var isValid: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    var body: some View {
        ZStack {
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                replicaHeader(title: "Changer le mot de passe", showBack: true, onClose: onDismiss)

                // Subtitle
                Text("Choisissez un nouveau mot de passe. Il doit contenir au moins 6 caractères.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // New password field
                SecureField("", text: $newPassword, prompt: Text("Nouveau mot de passe").foregroundColor(.gray))
                    .font(.system(size: 17))
                    .foregroundColor(ReplicaColors.backgroundSolid)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(28)
                    .focused($focusedField, equals: .newPassword)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                // Confirm password field
                SecureField("", text: $confirmPassword, prompt: Text("Confirmer le mot de passe").foregroundColor(.gray))
                    .font(.system(size: 17))
                    .foregroundColor(ReplicaColors.backgroundSolid)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(28)
                    .focused($focusedField, equals: .confirmPassword)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                // Validation messages
                if !newPassword.isEmpty && newPassword.count < 6 {
                    Text("Le mot de passe doit contenir au moins 6 caractères")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                    Text("Les mots de passe ne correspondent pas")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if showSuccess {
                    Text("Mot de passe mis à jour avec succès")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                // Save button
                Button(action: changePassword) {
                    if isSaving {
                        ProgressView()
                            .tint(ReplicaColors.backgroundSolid)
                            .frame(width: 200, height: 56)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.9))
                            )
                    } else {
                        Text("Sauvegarder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ReplicaColors.backgroundSolid)
                            .frame(width: 200, height: 56)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.9))
                            )
                    }
                }
                .disabled(!isValid || isSaving)
                .opacity(!isValid || isSaving ? 0.4 : 1)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            focusedField = .newPassword
        }
    }

    private func changePassword() {
        isSaving = true
        errorMessage = nil
        showSuccess = false

        Task {
            do {
                try await AuthService.shared.updatePassword(newPassword: newPassword)
                await MainActor.run {
                    isSaving = false
                    showSuccess = true
                    newPassword = ""
                    confirmPassword = ""
                    // Auto-dismiss after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onDismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Edit Pronouns View

struct ReplicaEditPronounsView: View {
    let currentPronouns: String
    var onDismiss: () -> Void
    var onSave: (String) -> Void

    @State private var selectedPronouns: String = "male"

    private let options = [
        ("Elle / La", "female"),
        ("Il / Lui", "male"),
        ("Iel / Iels", "other")
    ]

    var body: some View {
        ZStack {
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                replicaHeader(title: "Vos pronoms", showBack: true, onClose: onDismiss)

                // Subtitle
                Text("Nous devons le savoir pour garantir une génération de contenu appropriée.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Spacer()

                // Pronouns picker
                VStack(spacing: 0) {
                    ForEach(options, id: \.1) { (label, value) in
                        Button(action: { selectedPronouns = value }) {
                            Text(label)
                                .font(.system(size: 20, weight: selectedPronouns == value ? .semibold : .regular))
                                .foregroundColor(selectedPronouns == value ? .white : .white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    selectedPronouns == value
                                        ? Capsule().fill(Color.white.opacity(0.15))
                                        : nil
                                )
                        }
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Save button
                Button(action: { onSave(selectedPronouns) }) {
                    Text("Sauvegarder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ReplicaColors.backgroundSolid)
                        .frame(width: 200, height: 56)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                        )
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            selectedPronouns = currentPronouns
        }
    }
}

// MARK: - Gradium Voice Model

struct GradiumVoice: Identifiable {
    let id: String // voice_id
    let name: String
    let lang: String // "fr", "en", "es", "de", "pt"
    let gender: String // "Feminine", "Masculine", "Neutral"
    let description: String

    static let allVoices: [GradiumVoice] = [
        // MARK: French (fr)
        GradiumVoice(id: "b35yykvVppLXyw_l", name: "Elise", lang: "fr", gender: "Feminine", description: "Chaleureuse et douce"),
        GradiumVoice(id: "axlOaUiFyOZhy4nv", name: "Leo", lang: "fr", gender: "Masculine", description: "Chaleureux et doux"),
        GradiumVoice(id: "vMYQUSzm6GRkJX6d", name: "Olivier", lang: "fr", gender: "Masculine", description: "Amical et accueillant"),
        GradiumVoice(id: "p1fSBpcmVWngBqVd", name: "Manon", lang: "fr", gender: "Feminine", description: "Douce et posée"),
        GradiumVoice(id: "3mM3xaoFjNMQa22C", name: "Jade", lang: "fr", gender: "Feminine", description: "Claire et limpide"),
        GradiumVoice(id: "J4XbCGPYNMigXcfZ", name: "Amélie", lang: "fr", gender: "Feminine", description: "Amicale et agréable"),
        GradiumVoice(id: "0LMAi0x_YVG_GLeM", name: "Adrien", lang: "fr", gender: "Masculine", description: "Clair et chaleureux"),
        GradiumVoice(id: "-dOnYAX4N4GqSOee", name: "Sarah", lang: "fr", gender: "Feminine", description: "Chaleureuse et accueillante"),
        GradiumVoice(id: "N8xxxD_d-ZinGVI4", name: "Jennifer", lang: "fr", gender: "Feminine", description: "Douce et bienveillante"),
        GradiumVoice(id: "zba0owtqy4Gnewn9", name: "Élodie", lang: "fr", gender: "Feminine", description: "Confiante et professionnelle"),
        GradiumVoice(id: "TJv-kucMsUo24VQe", name: "Justine", lang: "fr", gender: "Feminine", description: "Dynamique et pétillante"),
        GradiumVoice(id: "YE0-JPiElafJrZaC", name: "Océane", lang: "fr", gender: "Feminine", description: "Professionnelle et posée"),
        GradiumVoice(id: "QY_BJKHMElKDO12-", name: "Léa", lang: "fr", gender: "Feminine", description: "Formelle et précise"),
        GradiumVoice(id: "D-IpHY1UI0iX9xQD", name: "Mathieu", lang: "fr", gender: "Masculine", description: "Énergique et assertif"),
        GradiumVoice(id: "twLGV8mrH_ycNpUn", name: "Clément", lang: "fr", gender: "Masculine", description: "Sincère et confiant"),
        GradiumVoice(id: "k1wgs3k8-wRxTJO6", name: "Julie", lang: "fr", gender: "Feminine", description: "Joyeuse et enthousiaste"),
        GradiumVoice(id: "Hdf5cdfaGrLDTD63", name: "Dylan", lang: "fr", gender: "Masculine", description: "Sincère et émotionnel"),
        GradiumVoice(id: "1VAVLmmbQFDw7TMn", name: "Marion", lang: "fr", gender: "Feminine", description: "Chaleureuse et narrative"),
        GradiumVoice(id: "2AtP1urAQkZaeI2U", name: "Pauline", lang: "fr", gender: "Feminine", description: "Professionnelle et articulée"),
        GradiumVoice(id: "B09t5S64xLaKwXeW", name: "Vincent", lang: "fr", gender: "Masculine", description: "Sage et bienveillant"),
        GradiumVoice(id: "AroCL6f1qizjiZ_a", name: "Pierre", lang: "fr", gender: "Masculine", description: "Énergique et journalistique"),
        GradiumVoice(id: "qTA0lxFpynJdoxx7", name: "Guillaume", lang: "fr", gender: "Masculine", description: "Joyeux et aventurier"),
        GradiumVoice(id: "zpmn3GOfiU_i5QGo", name: "Romain", lang: "fr", gender: "Masculine", description: "Chaleureux et posé"),
        GradiumVoice(id: "IB53xJtufx1sbfbt", name: "Kévin", lang: "fr", gender: "Masculine", description: "Sincère et profond"),
        GradiumVoice(id: "kw_VWSocR7vyA9Ty", name: "Florian", lang: "fr", gender: "Masculine", description: "Joyeux et accessible"),
        GradiumVoice(id: "hx1RAC4Lqd9xyTAr", name: "Antoine", lang: "fr", gender: "Masculine", description: "Confiant et intense"),
        GradiumVoice(id: "pdcyd1mLmo0fcg3O", name: "Quentin", lang: "fr", gender: "Masculine", description: "Sincère et connecté"),
        GradiumVoice(id: "xynYWquoAsrvM7UY", name: "Mélanie", lang: "fr", gender: "Feminine", description: "Claire et chaleureuse (Québec)"),
        GradiumVoice(id: "aNiSRZ0BhQxO1FPx", name: "Adam", lang: "fr", gender: "Masculine", description: "Formel et professionnel"),
        GradiumVoice(id: "ImBVnxSeLsdCfNIV", name: "Anaïs", lang: "fr", gender: "Feminine", description: "Distinctive et affirmée"),
        GradiumVoice(id: "GmGF_3ETsY2Zq7_w", name: "Marine", lang: "fr", gender: "Feminine", description: "Chaleureuse et maternelle"),
        GradiumVoice(id: "s0PhgjzOTRD5wo5L", name: "Maxime", lang: "fr", gender: "Masculine", description: "Joyeux et instructif (Québec)"),
        GradiumVoice(id: "HBfu9XA3QfzAG1MN", name: "Alexandre", lang: "fr", gender: "Masculine", description: "Énergique et assertif (Québec)"),
        GradiumVoice(id: "w9V1722uEmTkWqnR", name: "Camille", lang: "fr", gender: "Feminine", description: "Joyeuse et professionnelle"),
        GradiumVoice(id: "BbLb4TxdlrldgpHI", name: "Marie", lang: "fr", gender: "Feminine", description: "Professionnelle et calme"),
        GradiumVoice(id: "8nsAoui8Y5RK9PYw", name: "Thomas", lang: "fr", gender: "Masculine", description: "Confiant et sincère"),
        GradiumVoice(id: "rIYDMY3dLccdauWA", name: "Chloé", lang: "fr", gender: "Feminine", description: "Lumineuse et polyvalente"),
        GradiumVoice(id: "mxcKXLymdLQCdlEq", name: "Nicolas", lang: "fr", gender: "Masculine", description: "Assertif et charismatique"),
        GradiumVoice(id: "Jlh1B0PKQJyup0sQ", name: "Laura", lang: "fr", gender: "Feminine", description: "Claire et pédagogique"),
        GradiumVoice(id: "NvHEAMGiPT4u8iT-", name: "Amandine", lang: "fr", gender: "Feminine", description: "Polyvalente et joyeuse"),
        GradiumVoice(id: "WWHSNJCSTm77dyGd", name: "Valentin", lang: "fr", gender: "Masculine", description: "Chaleureux et enthousiaste"),
        GradiumVoice(id: "L6OaiBybqikfCBk0", name: "Manu", lang: "fr", gender: "Masculine", description: "Agréable et détendu"),
        GradiumVoice(id: "QkmUhBH4hIV2_BkY", name: "Sarah M.", lang: "fr", gender: "Feminine", description: "Confiante et compatissante"),

        // MARK: English (en)
        GradiumVoice(id: "YTpq7expH9539ERJ", name: "Emma", lang: "en", gender: "Feminine", description: "Pleasant and smooth"),
        GradiumVoice(id: "LFZvm12tW_z0xfGo", name: "Kent", lang: "en", gender: "Masculine", description: "Relaxed and authentic"),
        GradiumVoice(id: "ubuXFxVQwVYnZQhy", name: "Eva", lang: "en", gender: "Feminine", description: "Joyful and dynamic (British)"),
        GradiumVoice(id: "m86j6D7UZpGzHsNu", name: "Jack", lang: "en", gender: "Masculine", description: "Pleasant British voice"),
        GradiumVoice(id: "jtEKaLYNn6iif5PR", name: "Sydney", lang: "en", gender: "Feminine", description: "Clear and engaging"),
        GradiumVoice(id: "KWJiFWu2O9nMPYcR", name: "John", lang: "en", gender: "Masculine", description: "Warm and professional"),
        GradiumVoice(id: "NoJdNY6JTz-VJLwz", name: "Max", lang: "en", gender: "Masculine", description: "Clear and calm (Canadian)"),
        GradiumVoice(id: "Lxc7YlPC8ckLJA8H", name: "Kelly", lang: "en", gender: "Feminine", description: "Clear and soft (British)"),
        GradiumVoice(id: "-_aUUFZaJ0CT1gks", name: "Arjun", lang: "en", gender: "Masculine", description: "Warm and smooth (Indian)"),
        GradiumVoice(id: "W5htOuyiFI4Fwhxs", name: "Hunter", lang: "en", gender: "Masculine", description: "Joyful and smooth (Australian)"),
        GradiumVoice(id: "Eu9iL_CYe8N-Gkx_", name: "Tiffany", lang: "en", gender: "Feminine", description: "Warm and friendly"),
        GradiumVoice(id: "2H4HY2CBNyJHBCrP", name: "Christina", lang: "en", gender: "Feminine", description: "Joyful and efficient"),
        GradiumVoice(id: "KNYHZTB8ZqdAZv5Q", name: "Maria", lang: "en", gender: "Feminine", description: "Joyful and energetic"),
        GradiumVoice(id: "dh0EzP6jCroK6prq", name: "Mark", lang: "en", gender: "Masculine", description: "Warm and professional"),
        GradiumVoice(id: "XJc-Y9tkSd1UA7s4", name: "Logan", lang: "en", gender: "Masculine", description: "Joyful and energetic"),
        GradiumVoice(id: "78zAgQK6xmExb8wS", name: "Juan", lang: "en", gender: "Masculine", description: "Joyful and welcoming"),
        GradiumVoice(id: "56DcpvEI0Gawpidh", name: "Kaitlyn", lang: "en", gender: "Feminine", description: "Warm and kind"),
        GradiumVoice(id: "lt88kyLfD8Mqemla", name: "Michelle", lang: "en", gender: "Feminine", description: "Warm and friendly (Indian)"),
        GradiumVoice(id: "wPx6HPbUQkaUHGhq", name: "Mary", lang: "en", gender: "Feminine", description: "Joyful and youthful"),
        GradiumVoice(id: "c8BzreHTk1GG2R4z", name: "Cameron", lang: "en", gender: "Masculine", description: "Steady and casual"),
        GradiumVoice(id: "9QHzSiOYUD-RzEzM", name: "Jeremy", lang: "en", gender: "Masculine", description: "Composed and tech-savvy"),
        GradiumVoice(id: "P0GYBrxlhTy5CC87", name: "Charles", lang: "en", gender: "Masculine", description: "Classic British radio"),
        GradiumVoice(id: "kr-Om35JRqmA3Hzq", name: "Olivia", lang: "en", gender: "Feminine", description: "Calm and soothing"),
        GradiumVoice(id: "Z5GIOZR45ieZ8M-W", name: "Patrick", lang: "en", gender: "Masculine", description: "Joyful and clear"),
        GradiumVoice(id: "Abqwk2RWxlBEyv0j", name: "Kimberly", lang: "en", gender: "Feminine", description: "Cheerful British voice"),
        GradiumVoice(id: "4NU5PqxX2BdMEtWe", name: "Nathan", lang: "en", gender: "Masculine", description: "Warm and neighborly"),
        GradiumVoice(id: "EbIA5CIcQoa6NNd2", name: "Adam", lang: "en", gender: "Masculine", description: "Joyful and energetic"),
        GradiumVoice(id: "KRo-uwfno-KcEgBM", name: "Abigail", lang: "en", gender: "Feminine", description: "Warm and empathetic"),
        GradiumVoice(id: "yU6yxQ3e8LKRwU84", name: "Allison", lang: "en", gender: "Feminine", description: "Joyful and high-energy"),
        GradiumVoice(id: "MQC0U1yWvZXrppaF", name: "Kelsey", lang: "en", gender: "Feminine", description: "Balanced and realistic"),
        GradiumVoice(id: "aq7ltaIQ6ZJUY0jR", name: "Haley", lang: "en", gender: "Feminine", description: "Confident British voice"),
        GradiumVoice(id: "PS7enm5lVZiIvEKV", name: "Anna", lang: "en", gender: "Feminine", description: "Warm and supportive"),
        GradiumVoice(id: "bvNlBZ3DWDoVy_Yc", name: "Katherine", lang: "en", gender: "Feminine", description: "Professional and kind"),
        GradiumVoice(id: "zyLIanWKViHkc6Wp", name: "Steven", lang: "en", gender: "Masculine", description: "Steady British voice"),
        GradiumVoice(id: "91EdXxJDbWICDBgz", name: "Alex", lang: "en", gender: "Neutral", description: "High-energy and fun"),
        GradiumVoice(id: "fggSYM_FGJ30QTTl", name: "Brianna", lang: "en", gender: "Feminine", description: "Warm and smooth"),
        GradiumVoice(id: "J2qsArcdozbto5Hn", name: "Kevin", lang: "en", gender: "Masculine", description: "Joyful Australian voice"),
        GradiumVoice(id: "8dBmiTurwb7KcxLY", name: "Victoria", lang: "en", gender: "Feminine", description: "Warm and reliable"),
        GradiumVoice(id: "T7UL6gmeDqqYiVe1", name: "Nicole", lang: "en", gender: "Feminine", description: "Sarcastic and fun"),
        GradiumVoice(id: "auZu0iT-fniQ4cJd", name: "Jennifer", lang: "en", gender: "Feminine", description: "Warm and helpful"),
        GradiumVoice(id: "ikbJkd83GvuyoSLb", name: "Stephanie", lang: "en", gender: "Feminine", description: "Joyful and relatable"),
        GradiumVoice(id: "SG3KnxbSOkkrY097", name: "Lauren", lang: "en", gender: "Feminine", description: "Assertive and modern"),
        GradiumVoice(id: "mn5sS7D8kYKETZXA", name: "Samantha", lang: "en", gender: "Feminine", description: "Warm and professional"),
        GradiumVoice(id: "i1kmq28cO60ia35K", name: "Emily", lang: "en", gender: "Feminine", description: "Warm and modern"),
        GradiumVoice(id: "MZWrEHL2Fe_uc2Rv", name: "James", lang: "en", gender: "Masculine", description: "Warm and resonant"),
        GradiumVoice(id: "gTAO-3xLZ8_WSfbm", name: "Robert", lang: "en", gender: "Masculine", description: "Professional and polished"),
        GradiumVoice(id: "8sWSyTC7byLsbHkr", name: "Alexander", lang: "en", gender: "Masculine", description: "Motivating and deep"),

        // MARK: Spanish (es)
        GradiumVoice(id: "B36pbz5_UoWn4BDl", name: "Valentina", lang: "es", gender: "Feminine", description: "Cálida y envolvente (México)"),
        GradiumVoice(id: "xu7iJ_fn2ElcWp2s", name: "Sergio", lang: "es", gender: "Masculine", description: "Cálido y profesional"),
        GradiumVoice(id: "s4CzgVHP5cEkB9LD", name: "Sofia", lang: "es", gender: "Feminine", description: "Suave y pausada"),
        GradiumVoice(id: "aCWBiYUiQ4VwW8_b", name: "Pablo", lang: "es", gender: "Masculine", description: "Cálido y autoritario"),
        GradiumVoice(id: "yPxeHKlCzaHeKd_V", name: "Carlos", lang: "es", gender: "Masculine", description: "Cálido y versátil"),
        GradiumVoice(id: "r5WB0b126tlHSrku", name: "Adrián", lang: "es", gender: "Masculine", description: "Cálido y fluido (México)"),
        GradiumVoice(id: "PqjKPYFyGNsg1YU-", name: "Elena", lang: "es", gender: "Feminine", description: "Cálida y accesible"),
        GradiumVoice(id: "wGhY_zZCoQ5gB0ce", name: "Javier", lang: "es", gender: "Masculine", description: "Suave y encantador (Argentina)"),
        GradiumVoice(id: "ynR4CAbXMiOv-vGC", name: "Ana", lang: "es", gender: "Feminine", description: "Cálida y versátil"),
        GradiumVoice(id: "lPCVUcicz2XRaLE3", name: "Sara", lang: "es", gender: "Feminine", description: "Cálida y periodística"),
        GradiumVoice(id: "R3L8t75ZEoZCPUA9", name: "Daniel", lang: "es", gender: "Masculine", description: "Confiado y profesional"),
        GradiumVoice(id: "zhH3lPUo-JxmlOJT", name: "Carmen", lang: "es", gender: "Feminine", description: "Energética (Colombia)"),
        GradiumVoice(id: "k2B3TJiffePxjeBn", name: "María", lang: "es", gender: "Feminine", description: "Cálida y amigable (Colombia)"),

        // MARK: German (de)
        GradiumVoice(id: "-uP9MuGtBqAvEyxI", name: "Mia", lang: "de", gender: "Feminine", description: "Fröhlich und energisch"),
        GradiumVoice(id: "0y1VZjPabOBU3rWy", name: "Maximilian", lang: "de", gender: "Masculine", description: "Warm und sanft"),
        GradiumVoice(id: "IIZIkBSZAmb9nFZb", name: "Moritz", lang: "de", gender: "Masculine", description: "Klar und ruhig"),
        GradiumVoice(id: "kAoOc9Yb5EQDzA-N", name: "Lisa", lang: "de", gender: "Feminine", description: "Weich und klar"),
        GradiumVoice(id: "VXA4-0_ZN4o8q3vK", name: "Franziska", lang: "de", gender: "Feminine", description: "Warm und unterstützend"),
        GradiumVoice(id: "lSVEPWl_N_7MtcHe", name: "Lea", lang: "de", gender: "Feminine", description: "Warm und freundlich"),
        GradiumVoice(id: "hXjVvZ6oDDGQAQFj", name: "Stefanie", lang: "de", gender: "Feminine", description: "Selbstbewusst und klar"),
        GradiumVoice(id: "xq0vDziADfAmg6Uh", name: "Tom", lang: "de", gender: "Masculine", description: "Formell und klar"),
        GradiumVoice(id: "-qKylkN2UPxd7Mmg", name: "Niklas", lang: "de", gender: "Masculine", description: "Fröhlich und freundlich"),
        GradiumVoice(id: "fJDF4lEH590XplFv", name: "Michelle", lang: "de", gender: "Feminine", description: "Fröhlich und motivierend"),
        GradiumVoice(id: "ZOiGbnYdgKSBM_rH", name: "Dominik", lang: "de", gender: "Masculine", description: "Professionell und klar"),

        // MARK: Portuguese (pt)
        GradiumVoice(id: "pYcGZz9VOo4n2ynh", name: "Alice", lang: "pt", gender: "Feminine", description: "Calorosa e suave (Brasil)"),
        GradiumVoice(id: "M-FvVo9c-jGR4PgP", name: "Davi", lang: "pt", gender: "Masculine", description: "Envolvente e suave (Brasil)"),
        GradiumVoice(id: "L7890s1B44FqSiGC", name: "Frederico", lang: "pt", gender: "Masculine", description: "Claro e suave (Brasil)"),
        GradiumVoice(id: "Du_Dcv4fgXBDdubR", name: "Bruna", lang: "pt", gender: "Feminine", description: "Energética e profissional (Portugal)"),
        GradiumVoice(id: "EzmLkNorEpZG_oNv", name: "Rodrigo", lang: "pt", gender: "Masculine", description: "Calmo e confiante (Portugal)"),
        GradiumVoice(id: "QZtWUy8jmIroWiOu", name: "Thiago", lang: "pt", gender: "Masculine", description: "Caloroso e versátil (Brasil)"),
    ]

    static func voices(for languageCode: String) -> [GradiumVoice] {
        let lang = String(languageCode.prefix(2))
        let filtered = allVoices.filter { $0.lang == lang }
        return filtered.isEmpty ? allVoices.filter { $0.lang == "en" } : filtered
    }

    static func defaultVoiceId(for languageCode: String) -> String {
        let lang = String(languageCode.prefix(2))
        switch lang {
        case "fr": return "b35yykvVppLXyw_l" // Elise
        case "en": return "YTpq7expH9539ERJ" // Emma
        case "es": return "B36pbz5_UoWn4BDl" // Valentina
        case "de": return "-uP9MuGtBqAvEyxI" // Mia
        case "pt": return "pYcGZz9VOo4n2ynh" // Alice
        default: return "YTpq7expH9539ERJ" // Emma
        }
    }
}

// MARK: - Voice Picker View

struct VoltaVoicePickerView: View {
    let currentVoiceId: String
    var onDismiss: () -> Void
    var onSave: (String) -> Void

    @State private var selectedVoiceId: String = "b35yykvVppLXyw_l"
    @State private var filterGender: String? = nil
    @StateObject private var previewPlayer = VoicePreviewPlayer()

    private var userLang: String {
        Locale.current.language.languageCode?.identifier ?? "fr"
    }

    private var availableVoices: [GradiumVoice] {
        let voices = GradiumVoice.voices(for: userLang)
        if let gender = filterGender {
            return voices.filter { $0.gender == gender }
        }
        return voices
    }

    private var genders: [String] {
        let voices = GradiumVoice.voices(for: userLang)
        return Array(Set(voices.map { $0.gender })).sorted()
    }

    static func voiceName(for voiceId: String) -> String {
        GradiumVoice.allVoices.first(where: { $0.id == voiceId })?.name ?? "Elise"
    }

    /// Sample phrase per language for voice preview
    private var sampleText: String {
        switch String(userLang.prefix(2)) {
        case "fr": return "Salut ! Je suis Volta, ton coach de productivité."
        case "es": return "Hola, soy Volta, tu coach de productividad."
        case "de": return "Hallo! Ich bin Volta, dein Produktivitätscoach."
        case "pt": return "Olá! Eu sou o Volta, seu coach de produtividade."
        default: return "Hey! I'm Volta, your productivity coach."
        }
    }

    var body: some View {
        ZStack {
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                replicaHeader(title: "Voix de Volta", showBack: true, onClose: {
                    previewPlayer.stop()
                    onDismiss()
                })

                Text("Choisissez la voix de Volta pour les appels vocaux.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // Gender filter pills
                HStack(spacing: 10) {
                    genderPill(label: "Tous", value: nil)
                    ForEach(genders, id: \.self) { gender in
                        genderPill(label: gender == "Feminine" ? "Féminin" : gender == "Masculine" ? "Masculin" : "Neutre", value: gender)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 24)

                // Error message
                if let error = previewPlayer.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.9))
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                // Voice list
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(availableVoices) { voice in
                            Button(action: { selectedVoiceId = voice.id }) {
                                HStack(spacing: 12) {
                                    // Play preview button
                                    Button {
                                        if previewPlayer.playingVoiceId == voice.id {
                                            previewPlayer.stop()
                                        } else {
                                            previewPlayer.play(voiceId: voice.id, text: sampleText)
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.12))
                                                .frame(width: 36, height: 36)

                                            if previewPlayer.loadingVoiceId == voice.id {
                                                ProgressView()
                                                    .tint(.white.opacity(0.7))
                                                    .scaleEffect(0.7)
                                            } else {
                                                Image(systemName: previewPlayer.playingVoiceId == voice.id ? "stop.fill" : "play.fill")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(voice.name)
                                            .font(.system(size: 16, weight: selectedVoiceId == voice.id ? .semibold : .regular))
                                            .foregroundColor(selectedVoiceId == voice.id ? .white : .white.opacity(0.5))
                                        Text(voice.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(selectedVoiceId == voice.id ? .white.opacity(0.6) : .white.opacity(0.25))
                                    }
                                    Spacer()
                                    if selectedVoiceId == voice.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedVoiceId == voice.id ? Color.white.opacity(0.1) : Color.clear)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                .padding(.top, 12)

                Spacer(minLength: 0)

                Button(action: {
                    previewPlayer.stop()
                    onSave(selectedVoiceId)
                }) {
                    Text("Sauvegarder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ReplicaColors.backgroundSolid)
                        .frame(width: 200, height: 56)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                        )
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            selectedVoiceId = currentVoiceId
        }
        .onDisappear {
            previewPlayer.stop()
        }
    }

    private func genderPill(label: String, value: String?) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { filterGender = value } }) {
            Text(label)
                .font(.system(size: 13, weight: filterGender == value ? .semibold : .regular))
                .foregroundColor(filterGender == value ? ReplicaColors.backgroundSolid : .white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(filterGender == value ? Color.white.opacity(0.9) : Color.white.opacity(0.08))
                )
        }
    }
}

// MARK: - Voice Preview Player

@MainActor
class VoicePreviewPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playingVoiceId: String?
    @Published var loadingVoiceId: String?
    @Published var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private let apiClient = APIClient.shared

    struct TTSRequest: Encodable {
        let text: String
        let voiceId: String

        enum CodingKeys: String, CodingKey {
            case text
            case voiceId = "voice_id"
        }
    }

    struct TTSResponse: Decodable {
        let audioBase64: String

        enum CodingKeys: String, CodingKey {
            case audioBase64 = "audio_base64"
        }
    }

    func play(voiceId: String, text: String) {
        stop()
        errorMessage = nil
        loadingVoiceId = voiceId

        Task {
            do {
                let response: TTSResponse = try await apiClient.request(
                    endpoint: .chatTts,
                    method: .post,
                    body: TTSRequest(text: text, voiceId: voiceId)
                )

                guard let audioData = Data(base64Encoded: response.audioBase64) else {
                    loadingVoiceId = nil
                    errorMessage = "Impossible de décoder l'audio"
                    return
                }

                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)

                audioPlayer = try AVAudioPlayer(data: audioData)
                audioPlayer?.delegate = self
                audioPlayer?.play()

                loadingVoiceId = nil
                playingVoiceId = voiceId
            } catch {
                loadingVoiceId = nil
                errorMessage = "Aperçu indisponible"
                print("Voice preview error: \(error)")
            }
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingVoiceId = nil
        loadingVoiceId = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            playingVoiceId = nil
        }
    }
}

// MARK: - Change Email View

struct ReplicaChangeEmailView: View {
    let currentEmail: String
    var onDismiss: () -> Void
    var onSave: (String, String) -> Void

    @State private var newEmail: String = ""
    @State private var password: String = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        ZStack {
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                replicaHeader(title: "Changer l'email", showBack: true, onClose: onDismiss)

                // Subtitle
                Text("Gardez votre adresse email à jour. Entrez le nouvel email et votre mot de passe pour changer l'email actuel \(currentEmail) par un nouveau.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // Email field
                TextField("", text: $newEmail, prompt: Text("Nouvel email").foregroundColor(.gray))
                    .font(.system(size: 17))
                    .foregroundColor(ReplicaColors.backgroundSolid)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(28)
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                // Password field
                HStack {
                    if showPassword {
                        TextField("", text: $password, prompt: Text("Mot de passe").foregroundColor(.gray))
                            .font(.system(size: 17))
                            .foregroundColor(ReplicaColors.backgroundSolid)
                    } else {
                        SecureField("", text: $password, prompt: Text("Mot de passe").foregroundColor(.gray))
                            .font(.system(size: 17))
                            .foregroundColor(ReplicaColors.backgroundSolid)
                    }

                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(28)
                .focused($focusedField, equals: .password)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Forgot password link
                Button(action: {}) {
                    Text("Mot de passe oublié ?")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                Spacer()

                // Continue button
                Button(action: { onSave(newEmail, password) }) {
                    Text("Continuer")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 56)
                        .background(
                            Capsule()
                                .fill(ReplicaColors.toggleBlue)
                        )
                }
                .disabled(newEmail.isEmpty || password.isEmpty)
                .opacity(newEmail.isEmpty || password.isEmpty ? 0.4 : 1)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            focusedField = .email
        }
    }
}

// MARK: - Delete Account View

struct ReplicaDeleteAccountView: View {
    let userName: String
    var onDismiss: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            // Background with avatar placeholder
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Supprimer votre compte")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(ReplicaColors.closeButton))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Avatar placeholder
                Spacer()

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.5))
                    )

                Spacer()

                // Message card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bonjour \(userName), Nous sommes désolés d'apprendre que vous souhaitez supprimer votre compte.")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Si vous êtes préoccupé par la confidentialité de vos informations, nous avons clarifié certaines des questions que les gens ont posées sur ")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    + Text("cette page")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .underline()
                    + Text(".")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Si vous avez d'autres préoccupations ou questions, veuillez nous contacter via ")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    + Text("Contactez le support")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .underline()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )
                .padding(.horizontal, 16)

                // Buttons
                HStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("Retour")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                    }

                    Button(action: onConfirm) {
                        Text("Continuer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ReplicaColors.backgroundSolid)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.9))
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Avatar Debug View

struct AvatarTestView: View {
    var onDismiss: () -> Void
    @StateObject private var debugInfo = AvatarDebugInfo()
    @State private var showControls = true

    var body: some View {
        ZStack {
            // Full screen 3D Avatar with debug callback
            AvatarDebugView(
                avatarURL: AvatarURLs.cesiumMan,
                debugInfo: debugInfo
            )
            .ignoresSafeArea()

            // Overlay with controls
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Debug Avatar")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { showControls.toggle() }) {
                        Image(systemName: showControls ? "slider.horizontal.3" : "eye")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()

                if showControls {
                    // Control panel with sliders
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Camera section
                            Text("📷 CAMERA")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)

                            sliderRow("Cam X", value: $debugInfo.cameraX, range: -3...3)
                            sliderRow("Cam Y", value: $debugInfo.cameraY, range: 0...2.5)
                            sliderRow("Cam Z", value: $debugInfo.cameraZ, range: 1...8)
                            sliderRow("FOV", value: Binding(
                                get: { Float(debugInfo.fieldOfView) },
                                set: { debugInfo.fieldOfView = Double($0) }
                            ), range: 20...90)

                            Divider().background(Color.white.opacity(0.3))

                            // Avatar section
                            Text("🧍 AVATAR")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)

                            sliderRow("Scale", value: $debugInfo.avatarScale, range: 0.001...0.02)
                            sliderRow("Pos Y", value: $debugInfo.avatarY, range: -1...1)
                            sliderRow("Rot Y", value: $debugInfo.avatarRotationY, range: 0...Float.pi * 2)

                            Divider().background(Color.white.opacity(0.3))

                            // Model info
                            Text("📐 MODEL INFO")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)

                            Text(debugInfo.modelInfo)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white)

                            Divider().background(Color.white.opacity(0.3))

                            // Current values (copy-paste ready)
                            Text("📋 VALEURS ACTUELLES")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)

                            Text("cameraPosition: (\(String(format: "%.2f", debugInfo.cameraX)), \(String(format: "%.2f", debugInfo.cameraY)), \(String(format: "%.2f", debugInfo.cameraZ)))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)

                            Text("fieldOfView: \(String(format: "%.0f", debugInfo.fieldOfView))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)

                            Text("avatarScale: \(String(format: "%.4f", debugInfo.avatarScale))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)

                            Text("avatarY: \(String(format: "%.2f", debugInfo.avatarY))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)

                            Text("avatarRotY: \(String(format: "%.2f", debugInfo.avatarRotationY))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)

                            // Reset button
                            Button(action: resetValues) {
                                Text("Reset par défaut")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color.red.opacity(0.5)))
                            }
                            .padding(.top, 8)
                        }
                        .padding(16)
                    }
                    .frame(maxHeight: 400)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.85))
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private func sliderRow(_ label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 50, alignment: .leading)

            Slider(value: value, in: range)
                .tint(.blue)

            Text(String(format: "%.3f", value.wrappedValue))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.green)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private func resetValues() {
        debugInfo.cameraX = 0
        debugInfo.cameraY = 0.5
        debugInfo.cameraZ = 2.5
        debugInfo.fieldOfView = 50
        debugInfo.avatarScale = 0.005
        debugInfo.avatarY = 0
        debugInfo.avatarRotationY = 0
    }
}

// MARK: - Avatar Debug Info (Observable)

class AvatarDebugInfo: ObservableObject {
    @Published var cameraX: Float = 0
    @Published var cameraY: Float = 0.5
    @Published var cameraZ: Float = 2.5
    @Published var rotationX: Float = 0
    @Published var rotationY: Float = 0
    @Published var rotationZ: Float = 0
    @Published var fieldOfView: Double = 50
    @Published var avatarScale: Float = 0.005
    @Published var avatarY: Float = 0
    @Published var avatarRotationY: Float = 0
    @Published var modelInfo: String = "Chargement..."
}

// MARK: - Avatar Debug View (SceneKit with live updates)

struct AvatarDebugView: UIViewRepresentable {
    let avatarURL: String
    @ObservedObject var debugInfo: AvatarDebugInfo

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1.0)
        sceneView.allowsCameraControl = true  // Allow manual rotation
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode = .multisampling4X

        // Create scene
        let scene = SCNScene()
        sceneView.scene = scene

        // Add camera - positioned for human-scale avatar (after 0.01 scale)
        let cameraNode = SCNNode()
        cameraNode.name = "debugCamera"
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = CGFloat(debugInfo.fieldOfView)
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(x: debugInfo.cameraX, y: debugInfo.cameraY, z: debugInfo.cameraZ)
        scene.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode

        // Store reference to coordinator
        context.coordinator.sceneView = sceneView
        context.coordinator.cameraNode = cameraNode
        context.coordinator.debugInfo = debugInfo

        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor.white
        ambientLight.light?.intensity = 400
        scene.rootNode.addChildNode(ambientLight)

        // Add directional light from front-top
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 800
        directionalLight.light?.color = UIColor.white
        directionalLight.eulerAngles = SCNVector3(x: -.pi / 4, y: 0, z: 0)
        scene.rootNode.addChildNode(directionalLight)

        // Load avatar
        context.coordinator.loadAvatar(url: avatarURL, into: sceneView, debugInfo: debugInfo)

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update camera position from sliders
        if let cameraNode = context.coordinator.cameraNode {
            cameraNode.position = SCNVector3(x: debugInfo.cameraX, y: debugInfo.cameraY, z: debugInfo.cameraZ)
            cameraNode.camera?.fieldOfView = CGFloat(debugInfo.fieldOfView)
        }

        // Update avatar from sliders
        if let avatarNode = context.coordinator.avatarNode {
            let scale = debugInfo.avatarScale
            avatarNode.scale = SCNVector3(x: scale, y: scale, z: scale)
            avatarNode.position = SCNVector3(x: 0, y: debugInfo.avatarY, z: 0)
            avatarNode.eulerAngles = SCNVector3(x: 0, y: debugInfo.avatarRotationY, z: 0)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var sceneView: SCNView?
        var cameraNode: SCNNode?
        var avatarNode: SCNNode?
        var debugInfo: AvatarDebugInfo?

        func loadAvatar(url: String, into sceneView: SCNView, debugInfo: AvatarDebugInfo) {
            guard let avatarURL = URL(string: url) else { return }

            URLSession.shared.downloadTask(with: avatarURL) { [weak self] localURL, _, error in
                guard let self = self, let localURL = localURL, error == nil else {
                    print("❌ Download error: \(error?.localizedDescription ?? "unknown")")
                    DispatchQueue.main.async {
                        debugInfo.modelInfo = "Erreur téléchargement"
                    }
                    return
                }

                do {
                    let asset = try GLTFAsset(url: localURL)
                    let sceneSource = GLTFSCNSceneSource(asset: asset)
                    guard let loadedScene = sceneSource.defaultScene else {
                        print("❌ No default scene")
                        return
                    }

                    let animations = sceneSource.animations

                    DispatchQueue.main.async {
                        let avatarNode = loadedScene.rootNode.clone()

                        // Calculate bounding box
                        let (minBound, maxBound) = avatarNode.boundingBox
                        let width = maxBound.x - minBound.x
                        let height = maxBound.y - minBound.y
                        let depth = maxBound.z - minBound.z

                        print("📏 Model size (original): \(width) x \(height) x \(depth)")
                        debugInfo.modelInfo = "Original: \(Int(width))x\(Int(height))x\(Int(depth)) → Scaled: \(String(format: "%.2f", width * debugInfo.avatarScale))x\(String(format: "%.2f", height * debugInfo.avatarScale))"

                        // Apply scale (model is in cm, 0.01 converts to meters)
                        let scale = debugInfo.avatarScale
                        avatarNode.scale = SCNVector3(x: scale, y: scale, z: scale)
                        avatarNode.eulerAngles = SCNVector3(x: 0, y: debugInfo.avatarRotationY, z: 0)
                        avatarNode.position = SCNVector3(x: 0, y: debugInfo.avatarY, z: 0)
                        avatarNode.name = "avatar"

                        self.avatarNode = avatarNode
                        sceneView.scene?.rootNode.addChildNode(avatarNode)

                        // Play animations
                        if !animations.isEmpty {
                            for (index, animation) in animations.enumerated() {
                                animation.animationPlayer.animation.usesSceneTimeBase = false
                                animation.animationPlayer.animation.repeatCount = .greatestFiniteMagnitude
                                avatarNode.addAnimationPlayer(animation.animationPlayer, forKey: "anim_\(index)")
                                animation.animationPlayer.play()
                            }
                        }

                        print("✅ Avatar loaded! Scale=\(scale)")
                    }
                } catch {
                    print("❌ GLTFKit2 error: \(error)")
                    DispatchQueue.main.async {
                        debugInfo.modelInfo = "Erreur chargement GLB"
                    }
                }
            }.resume()
        }
    }
}

// MARK: - Social Media Logo Views

/// Facebook logo - blue circle with white "f"
struct FacebookLogoView: View {
    var body: some View {
        Circle()
            .fill(Color(red: 0.02, green: 0.40, blue: 1.0)) // #0866ff
            .overlay(
                Text("f")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .offset(y: 1)
            )
    }
}

/// Reddit logo - orange circle with Snoo face
struct RedditLogoView: View {
    var body: some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.27, blue: 0.0)) // #ff4500
            .overlay(
                // Simplified Snoo face
                GeometryReader { geo in
                    let size = geo.size.width
                    ZStack {
                        // Ears (two small circles on top)
                        Circle()
                            .fill(Color.white)
                            .frame(width: size * 0.22, height: size * 0.22)
                            .offset(x: -size * 0.22, y: -size * 0.18)

                        Circle()
                            .fill(Color.white)
                            .frame(width: size * 0.22, height: size * 0.22)
                            .offset(x: size * 0.22, y: -size * 0.18)

                        // Face (white oval)
                        Ellipse()
                            .fill(Color.white)
                            .frame(width: size * 0.65, height: size * 0.55)
                            .offset(y: size * 0.08)

                        // Eyes (two black dots)
                        Circle()
                            .fill(Color(red: 1.0, green: 0.27, blue: 0.0))
                            .frame(width: size * 0.12, height: size * 0.12)
                            .offset(x: -size * 0.12, y: size * 0.02)

                        Circle()
                            .fill(Color(red: 1.0, green: 0.27, blue: 0.0))
                            .frame(width: size * 0.12, height: size * 0.12)
                            .offset(x: size * 0.12, y: size * 0.02)

                        // Smile (arc)
                        Path { path in
                            path.addArc(
                                center: CGPoint(x: size * 0.5, y: size * 0.58),
                                radius: size * 0.15,
                                startAngle: .degrees(0),
                                endAngle: .degrees(180),
                                clockwise: false
                            )
                        }
                        .stroke(Color(red: 1.0, green: 0.27, blue: 0.0), lineWidth: 1.5)
                    }
                }
            )
    }
}

/// Discord logo - blurple circle with controller face
struct DiscordLogoView: View {
    var body: some View {
        Circle()
            .fill(Color(red: 0.345, green: 0.396, blue: 0.949)) // #5865f2
            .overlay(
                // Simplified Discord logo (game controller face)
                GeometryReader { geo in
                    let size = geo.size.width
                    ZStack {
                        // Main body shape (simplified)
                        Path { path in
                            let w = size * 0.7
                            let h = size * 0.45
                            let x = (size - w) / 2
                            let y = (size - h) / 2 + size * 0.05

                            path.move(to: CGPoint(x: x + w * 0.15, y: y))
                            path.addLine(to: CGPoint(x: x + w * 0.85, y: y))
                            path.addQuadCurve(
                                to: CGPoint(x: x + w, y: y + h * 0.4),
                                control: CGPoint(x: x + w, y: y)
                            )
                            path.addLine(to: CGPoint(x: x + w * 0.85, y: y + h))
                            path.addLine(to: CGPoint(x: x + w * 0.15, y: y + h))
                            path.addQuadCurve(
                                to: CGPoint(x: x, y: y + h * 0.4),
                                control: CGPoint(x: x, y: y + h)
                            )
                            path.addLine(to: CGPoint(x: x, y: y + h * 0.4))
                            path.addQuadCurve(
                                to: CGPoint(x: x + w * 0.15, y: y),
                                control: CGPoint(x: x, y: y)
                            )
                        }
                        .fill(Color.white)

                        // Left eye
                        Ellipse()
                            .fill(Color(red: 0.345, green: 0.396, blue: 0.949))
                            .frame(width: size * 0.15, height: size * 0.18)
                            .offset(x: -size * 0.12, y: size * 0.05)

                        // Right eye
                        Ellipse()
                            .fill(Color(red: 0.345, green: 0.396, blue: 0.949))
                            .frame(width: size * 0.15, height: size * 0.18)
                            .offset(x: size * 0.12, y: size * 0.05)
                    }
                }
            )
    }
}

// MARK: - Preview

#Preview {
    SettingsView(onDismiss: {})
        .environmentObject(FocusAppStore.shared)
        .environmentObject(SubscriptionManager.shared)
}

#Preview("Social Logos") {
    HStack(spacing: 20) {
        FacebookLogoView()
            .frame(width: 40, height: 40)
        RedditLogoView()
            .frame(width: 40, height: 40)
        DiscordLogoView()
            .frame(width: 40, height: 40)
    }
    .padding()
    .background(Color(red: 0.16, green: 0.19, blue: 0.48))
}
