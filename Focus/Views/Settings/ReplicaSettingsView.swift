import SwiftUI
import SceneKit
import GLTFKit2
import Combine

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

struct ReplicaSettingsView: View {
    var onDismiss: () -> Void
    @EnvironmentObject var store: FocusAppStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager

    private var companionName: String {
        store.user?.companionName ?? "Kai"
    }

    // Settings state
    @State private var avatarHerited = true
    @State private var showFocusInChat = true
    @State private var selfieMode = true
    @State private var showLevel = false
    @State private var backgroundMusic = false
    @State private var sounds = true
    @State private var notificationsEnabled = true
    @State private var faceID = false

    // Sub-page navigation (fade overlays)
    @State private var showAccount = false
    @State private var showEditName = false
    @State private var showEditBirthday = false
    @State private var showEditPronouns = false
    @State private var showChangeEmail = false
    @State private var showDeleteAccount = false
    @State private var showSubscription = false
    @State private var showOnboarding = false
    @State private var showAvatarTest = false

    private let userService = UserService()

    var body: some View {
        ZStack {
            // Background
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with X button
                replicaHeader(title: "Paramètres", showBack: false, onClose: onDismiss)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Promo banner for subscription
                        promoBanner
                            .padding(.top, 8)

                        // Account Section (Compte, Historique)
                        accountSection
                            .padding(.top, 24)

                        // Preferences Section
                        preferencesSection
                            .padding(.top, 24)

                        // Resources Section
                        resourcesSection
                            .padding(.top, 24)

                        // Community Section
                        communitySection
                            .padding(.top, 24)

                        // Sign out button
                        signOutButton
                            .padding(.top, 32)
                            .padding(.horizontal, 40)

                        // Version
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.top, 16)
                            .padding(.bottom, 40)

                        // Debug section (dev only)
                        #if DEBUG
                        debugSection
                            .padding(.bottom, 32)
                        #endif
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .onAppear { loadSettings() }
        .onChange(of: notificationsEnabled) { _, _ in saveNotificationSettings() }
        // Sub-page overlays with fade transitions
        .overlay {
            if showAccount {
                ReplicaAccountView(
                    onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showAccount = false } },
                    onShowEditName: { withAnimation(.easeInOut(duration: 0.3)) { showEditName = true } },
                    onShowEditBirthday: { withAnimation(.easeInOut(duration: 0.3)) { showEditBirthday = true } },
                    onShowEditPronouns: { withAnimation(.easeInOut(duration: 0.3)) { showEditPronouns = true } },
                    onShowChangeEmail: { withAnimation(.easeInOut(duration: 0.3)) { showChangeEmail = true } },
                    onShowDeleteAccount: { withAnimation(.easeInOut(duration: 0.3)) { showDeleteAccount = true } }
                )
                .environmentObject(store)
                .transition(.opacity)
            }
        }
        .overlay {
            if showEditName {
                ReplicaEditNameView(
                    currentName: store.user?.firstName ?? store.user?.name ?? "",
                    onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showEditName = false } },
                    onSave: { name in
                        Task { await updateName(name) }
                        withAnimation(.easeInOut(duration: 0.3)) { showEditName = false }
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if showEditBirthday {
                ReplicaEditBirthdayView(
                    currentBirthday: store.user?.birthday,
                    onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showEditBirthday = false } },
                    onSave: { date in
                        Task { await updateBirthday(date) }
                        withAnimation(.easeInOut(duration: 0.3)) { showEditBirthday = false }
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if showEditPronouns {
                ReplicaEditPronounsView(
                    currentPronouns: store.user?.gender ?? "he",
                    onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showEditPronouns = false } },
                    onSave: { pronouns in
                        Task { await updatePronouns(pronouns) }
                        withAnimation(.easeInOut(duration: 0.3)) { showEditPronouns = false }
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if showChangeEmail {
                ReplicaChangeEmailView(
                    currentEmail: store.user?.email ?? "",
                    onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showChangeEmail = false } },
                    onSave: { email, password in
                        // TODO: Change email via backend
                        withAnimation(.easeInOut(duration: 0.3)) { showChangeEmail = false }
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if showDeleteAccount {
                ReplicaDeleteAccountView(
                    userName: store.user?.firstName ?? store.user?.name ?? "Utilisateur",
                    onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showDeleteAccount = false } },
                    onConfirm: {
                        deleteAccount()
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if showSubscription {
                FocusPaywallView(
                    companionName: companionName,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSubscription = false
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSubscription = false
                        }
                    }
                )
                .environmentObject(revenueCatManager)
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            NewOnboardingView()
                .environmentObject(store)
                .environmentObject(RevenueCatManager.shared)
        }
        .overlay {
            if showAvatarTest {
                AvatarTestView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAvatarTest = false
                    }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showAvatarTest)
        .animation(.easeInOut(duration: 0.3), value: showSubscription)
        .animation(.easeInOut(duration: 0.3), value: showAccount)
        .animation(.easeInOut(duration: 0.3), value: showEditName)
        .animation(.easeInOut(duration: 0.3), value: showEditBirthday)
        .animation(.easeInOut(duration: 0.3), value: showEditPronouns)
        .animation(.easeInOut(duration: 0.3), value: showChangeEmail)
        .animation(.easeInOut(duration: 0.3), value: showDeleteAccount)
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
            toggleRow(title: "Notifications", isOn: $notificationsEnabled)
            replicaDivider
            toggleRow(title: "Face ID", isOn: $faceID)
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
        if let user = store.user {
            notificationsEnabled = user.notificationsEnabled ?? true
        }
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

    private func updateBirthday(_ date: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        do {
            let updated = try await userService.updateProfile(birthday: dateString)
            await MainActor.run {
                FocusAppStore.shared.user = User(from: updated)
            }
        } catch {
            print("Failed to update birthday: \(error)")
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await userService.deleteAccount()
                await MainActor.run {
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
    var onShowEditBirthday: () -> Void
    var onShowEditPronouns: () -> Void
    var onShowChangeEmail: () -> Void
    var onShowDeleteAccount: () -> Void

    @EnvironmentObject var store: FocusAppStore

    private var pronounsDisplay: String {
        switch store.user?.gender {
        case "she": return "Elle / La"
        case "he": return "Il / Lui"
        case "they": return "Iel / Iels"
        default: return "Non défini"
        }
    }

    private var birthdayDisplay: String {
        guard let birthday = store.user?.birthday else {
            return "Non défini"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: birthday)
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

                    // Anniversaire
                    Button(action: onShowEditBirthday) {
                        accountRow(label: "Anniversaire", value: birthdayDisplay)
                    }

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
                    Button(action: {}) {
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

    private func accountRow(label: String, value: String) -> some View {
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
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ReplicaColors.chevron)
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

// MARK: - Edit Birthday View

struct ReplicaEditBirthdayView: View {
    var currentBirthday: Date?
    var onDismiss: () -> Void
    var onSave: (Date) -> Void

    @State private var selectedDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            ReplicaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                replicaHeader(title: "Votre date de naissance", showBack: true, onClose: onDismiss)

                // Subtitle
                Text("Nous avons besoin de cette information pour rendre votre expérience plus pertinente et sécurisée.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Spacer()

                // Date picker (wheel style)
                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    .padding(.horizontal, 24)

                Spacer()

                // Save button
                Button(action: { onSave(selectedDate) }) {
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
            if !hasAppeared, let birthday = currentBirthday {
                selectedDate = birthday
                hasAppeared = true
            }
        }
    }
}

// MARK: - Edit Pronouns View

struct ReplicaEditPronounsView: View {
    let currentPronouns: String
    var onDismiss: () -> Void
    var onSave: (String) -> Void

    @State private var selectedPronouns: String = "he"

    private let options = [
        ("Elle / La", "she"),
        ("Il / Lui", "he"),
        ("Iel / Iels", "they")
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
    ReplicaSettingsView(onDismiss: {})
        .environmentObject(FocusAppStore.shared)
        .environmentObject(RevenueCatManager.shared)
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
