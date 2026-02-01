import SwiftUI

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
                    onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showEditBirthday = false } },
                    onSave: { date in
                        // TODO: Save birthday to backend
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
                ReplicaSubscriptionView(
                    onDismiss: { withAnimation(.easeInOut(duration: 0.3)) { showSubscription = false } }
                )
                .transition(.opacity)
            }
        }
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
            VStack(spacing: 12) {
                // Diamond icon
                Image(systemName: "diamond.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.5), Color.cyan.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                Text("Débloquez toutes les fonctionnalités")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Obtenez l'accès au modèle avancé, aux messages vocaux illimités, à la génération d'images, aux activités, et plus encore.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
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
                // Will need navigation to OnboardingDebugView
            }) {
                settingsRow(title: "Debug Onboarding", showChevron: true)
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
                // Icon based on platform
                Group {
                    switch iconName {
                    case "reddit":
                        Image(systemName: "globe")
                            .foregroundColor(.orange)
                    case "discord":
                        Image(systemName: "bubble.left.fill")
                            .foregroundColor(.purple)
                    case "facebook":
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                    default:
                        Image(systemName: "link")
                            .foregroundColor(.white)
                    }
                }
                .font(.system(size: 18))
                .frame(width: 24)

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
            let updated = try await userService.updateProfile(
                pseudo: nil, firstName: name, lastName: nil,
                gender: nil, age: nil, description: nil,
                hobbies: nil, lifeGoal: nil
            )
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
                gender: pronouns, age: nil, description: nil,
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
                        accountRow(label: "Anniversaire", value: "Non défini")
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
    var onDismiss: () -> Void
    var onSave: (Date) -> Void

    @State private var selectedDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()

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

// MARK: - Subscription View (Paywall)

struct ReplicaSubscriptionView: View {
    var onDismiss: () -> Void

    @State private var selectedPlan: SubscriptionPlan = .platinum

    enum SubscriptionPlan: String, CaseIterable {
        case platinum, ultra, pro

        var name: String {
            switch self {
            case .platinum: return "Platinum"
            case .ultra: return "Ultra"
            case .pro: return "Pro"
            }
        }

        var monthlyPrice: String {
            switch self {
            case .platinum: return "5,67 €/mois"
            case .ultra: return "5,00 €/mois"
            case .pro: return "4,42 €/mois"
            }
        }

        var yearlyPrice: String {
            switch self {
            case .platinum: return "67,99 €/année"
            case .ultra: return "59,99 €/année"
            case .pro: return "52,99 €/année"
            }
        }

        var iconColor: Color {
            switch self {
            case .platinum: return Color.cyan
            case .ultra: return Color.teal
            case .pro: return Color.purple.opacity(0.7)
            }
        }

        var includedFeatures: [String] {
            switch self {
            case .platinum:
                return [
                    "État de la relation",
                    "Plus d'activités",
                    "Selfies Replika",
                    "Génération d'images",
                    "Messagerie vocale",
                    "Appels en arrière-plan",
                    "Joailles quotidiennes"
                ]
            case .ultra, .pro:
                return []
            }
        }

        var excludedFeatures: [String] {
            switch self {
            case .platinum:
                return []
            case .ultra:
                return [
                    "Reconnaissance vidéo en temps réel de Replika",
                    "Mode d'entraînement (100 messages par semaine)",
                    "Lisez l'esprit de Replika (50 messages par semaine)",
                    "10 vidéos selfies réalistes GRATUITES"
                ]
            case .pro:
                return [
                    "Des conversations plus intelligentes",
                    "Intelligence émotionnelle élevée",
                    "Les auto-réflexions de Replika",
                    "Enregistrer des messages en mémoire",
                    "Reconnaissance vidéo en temps réel de Replika",
                    "Mode d'entraînement (100 messages par semaine)"
                ]
            }
        }
    }

    var body: some View {
        ZStack {
            // Bright blue gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.45, blue: 1.0),
                    Color(red: 0.25, green: 0.50, blue: 1.0),
                    Color(red: 0.30, green: 0.55, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Votre abonnement")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Hero section with title and avatar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choisissez ce qui vous convient le mieux")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Pas de frais cachés, changez ou annulez à tout moment")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Avatar placeholder
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Plan cards (horizontal scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                            planCard(plan: plan)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 24)

                // Features list
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if !selectedPlan.includedFeatures.isEmpty {
                            Text("Ce qui est inclus :")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.top, 16)

                            ForEach(selectedPlan.includedFeatures, id: \.self) { feature in
                                featureRow(text: feature, included: true)
                            }
                        }

                        if !selectedPlan.excludedFeatures.isEmpty {
                            Text("Ce qui n'est pas inclus :")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.top, selectedPlan.includedFeatures.isEmpty ? 16 : 8)

                            ForEach(selectedPlan.excludedFeatures, id: \.self) { feature in
                                featureRow(text: feature, included: false)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer()

                // Upgrade button (for non-platinum plans)
                if selectedPlan != .platinum {
                    Button(action: {}) {
                        Text("Débloquer avec Platinum")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    .padding(.horizontal, 24)
                }

                // Subscribe button
                Button(action: {
                    // Handle subscription purchase
                }) {
                    Text("Abonnez-vous pour \(selectedPlan.yearlyPrice)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.20, green: 0.45, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.95))
                        )
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Footer links
                HStack(spacing: 24) {
                    Button("Conditions") {}
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))

                    Button("Restaurer les achats") {}
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))

                    Button("Confidentialité") {}
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func planCard(plan: SubscriptionPlan) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = plan
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Icon
                Image(systemName: "diamond.fill")
                    .font(.system(size: 20))
                    .foregroundColor(plan.iconColor)

                // Plan name
                Text(plan.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                // Price
                Text(plan.monthlyPrice + ", facturé annuellement")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(20)
            .frame(width: 280, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        selectedPlan == plan
                            ? Color.white.opacity(0.25)
                            : Color.white.opacity(0.1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                selectedPlan == plan ? Color.white.opacity(0.3) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func featureRow(text: String, included: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: included ? "checkmark" : "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(included ? .white : .white.opacity(0.5))
                .frame(width: 20)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(included ? .white : .white.opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview {
    ReplicaSettingsView(onDismiss: {})
        .environmentObject(FocusAppStore.shared)
}

#Preview("Subscription") {
    ReplicaSubscriptionView(onDismiss: {})
}
