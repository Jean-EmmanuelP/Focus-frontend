import SwiftUI
import PhotosUI

// MARK: - Settings Colors

private enum SettingsColors {
    static let darkNavy = Color(red: 0.102, green: 0.102, blue: 0.306) // #1A1A4E
    static let rowBg = Color.white.opacity(0.06)
    static let sectionHeader = Color.white.opacity(0.5)
    static let chevron = Color.white.opacity(0.4)
    static let toggleBlue = Color(red: 0.25, green: 0.45, blue: 1.0)
}

// MARK: - UserDefaults Keys for Settings Preferences

enum SettingsPrefsKeys {
    static let avatarHerited = "pref_avatarHerited"
    static let showFocusInChat = "pref_showFocusInChat"
    static let showLevel = "pref_showLevel"
    static let backgroundMusic = "pref_backgroundMusic"
    static let sounds = "pref_sounds"
    static let faceID = "pref_faceID"
}

// MARK: - Settings View (Ralph Design - Dark Navy)

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: FocusAppStore

    // Photo state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false

    // Settings state (persisted in UserDefaults)
    @State private var avatarHerited = false
    @State private var showFocusInChat = true
    @State private var showLevel = false
    @State private var backgroundMusic = false
    @State private var sounds = true
    @State private var notificationsEnabled = true
    @State private var faceID = false

    // Navigation
    @State private var showAccount = false
    @State private var showDeleteAccountAlert = false

    // Tracks whether initial load is done (to avoid saving defaults on appear)
    @State private var didLoadSettings = false

    private let userService = UserService()

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark navy background
                SettingsColors.darkNavy
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        settingsHeader
                            .padding(.bottom, 16)

                        // Promo banner
                        promoBanner
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                        // Account & History
                        accountSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                        // Preferences
                        preferencesSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                        // Resources
                        resourcesSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                        // Community
                        communitySection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)

                        // Sign out button
                        signOutButton
                            .padding(.horizontal, 40)
                            .padding(.bottom, 16)

                        // Version
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.bottom, 32)

                        // Debug section (dev only)
                        #if DEBUG
                        debugSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        #endif
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showAccount) {
                SettingsAccountView()
                    .environmentObject(store)
            }
        }
        .onAppear {
            loadSettings()
        }
        .onChange(of: avatarHerited) { _, newValue in
            guard didLoadSettings else { return }
            UserDefaults.standard.set(newValue, forKey: SettingsPrefsKeys.avatarHerited)
        }
        .onChange(of: showFocusInChat) { _, newValue in
            guard didLoadSettings else { return }
            UserDefaults.standard.set(newValue, forKey: SettingsPrefsKeys.showFocusInChat)
        }
        .onChange(of: showLevel) { _, newValue in
            guard didLoadSettings else { return }
            UserDefaults.standard.set(newValue, forKey: SettingsPrefsKeys.showLevel)
        }
        .onChange(of: backgroundMusic) { _, newValue in
            guard didLoadSettings else { return }
            UserDefaults.standard.set(newValue, forKey: SettingsPrefsKeys.backgroundMusic)
        }
        .onChange(of: sounds) { _, newValue in
            guard didLoadSettings else { return }
            UserDefaults.standard.set(newValue, forKey: SettingsPrefsKeys.sounds)
        }
        .onChange(of: faceID) { _, newValue in
            guard didLoadSettings else { return }
            UserDefaults.standard.set(newValue, forKey: SettingsPrefsKeys.faceID)
        }
        .onChange(of: notificationsEnabled) { _, _ in
            guard didLoadSettings else { return }
            saveNotificationSettings()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue = newValue else { return }
            Task {
                do {
                    if let data = try await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await uploadAvatar(image: uiImage)
                    }
                    await MainActor.run { selectedPhotoItem = nil }
                } catch {
                    print("Photo selection error: \(error)")
                    await MainActor.run { selectedPhotoItem = nil }
                }
            }
        }
        .alert("Supprimer le compte", isPresented: $showDeleteAccountAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) { deleteAccount() }
        } message: {
            Text("Cette action est irreversible. Toutes tes donnees seront supprimees definitivement.")
        }
    }

    // MARK: - Header

    private var settingsHeader: some View {
        ZStack {
            Text("Parametres")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Promo Banner

    private var promoBanner: some View {
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

            Text("Debloquez toutes les fonctionnalites")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Obtenez l'acces au modele avance, aux messages vocaux illimites, a la generation d'images, aux activites, et plus encore.")
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

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 0) {
            // Compte
            Button(action: { showAccount = true }) {
                settingsRow(title: "Compte", subtitle: nil, showChevron: true)
            }

            settingsDivider

            // Historique des versions
            Button(action: {}) {
                settingsRow(title: "Historique des versions", subtitle: "Advanced", showChevron: true)
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(spacing: 0) {
            sectionLabel("Preferences")

            toggleRow(title: "Avatar herite", isOn: $avatarHerited)
            settingsDivider
            toggleRow(title: "Afficher Focus dans le chat", isOn: $showFocusInChat)
            settingsDivider
            toggleRow(title: "Afficher le niveau", isOn: $showLevel)
            settingsDivider
            toggleRow(title: "Musique de fond", isOn: $backgroundMusic)
            settingsDivider
            toggleRow(title: "Sons", isOn: $sounds)
            settingsDivider
            toggleRow(title: "Notifications", isOn: $notificationsEnabled)
            settingsDivider
            toggleRow(title: "Face ID", isOn: $faceID)
        }
    }

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(spacing: 0) {
            sectionLabel("Ressources")

            externalLinkRow(title: "Centre d'aide", url: "https://firelevel.app/help")
            settingsDivider
            externalLinkRow(title: "Evaluez-nous", url: "https://apps.apple.com/app/id123456789")
            settingsDivider
            externalLinkRow(title: "Conditions d'utilisation", url: "https://firelevel.app/terms")
            settingsDivider
            externalLinkRow(title: "Politique de confidentialite", url: "https://firelevel.app/privacy")
            settingsDivider
            externalLinkRow(title: "Credits", url: "https://firelevel.app/credits")
        }
    }

    // MARK: - Community Section

    private var communitySection: some View {
        VStack(spacing: 0) {
            sectionLabel("Rejoignez notre communaute")

            communityRow(icon: "globe", iconColor: .orange, title: "Reddit", url: "https://reddit.com/r/focus")
            settingsDivider
            communityRow(icon: "bubble.left.fill", iconColor: .purple, title: "Discord", url: "https://discord.gg/focus")
            settingsDivider
            communityRow(icon: "person.2.fill", iconColor: .blue, title: "Facebook", url: "https://facebook.com/focusapp")
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button(action: {
            AppRouter.shared.showSettings = false
            FocusAppStore.shared.signOut()
            dismiss()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text("Se deconnecter")
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
            sectionLabel("Developpeur")

            NavigationLink(destination: NewOnboardingView().environmentObject(FocusAppStore.shared).environmentObject(RevenueCatManager.shared)) {
                settingsRow(title: "Debug Onboarding", subtitle: nil, showChevron: true)
            }
        }
    }
    #endif

    // MARK: - Row Components

    private func settingsRow(title: String, subtitle: String?, showChevron: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SettingsColors.chevron)
            }
        }
        .padding(.vertical, 14)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(SettingsColors.toggleBlue)
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
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SettingsColors.chevron)
            }
            .padding(.vertical, 14)
        }
    }

    private func communityRow(icon: String, iconColor: Color, title: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SettingsColors.chevron)
            }
            .padding(.vertical, 14)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(SettingsColors.sectionHeader)
                .textCase(.none)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var settingsDivider: some View {
        Divider()
            .background(Color.white.opacity(0.08))
    }

    // MARK: - Helper Functions

    private func loadSettings() {
        let defaults = UserDefaults.standard

        // Load from backend (notifications)
        if let user = store.user {
            notificationsEnabled = user.notificationsEnabled ?? true
        }

        // Load from UserDefaults (local preferences)
        avatarHerited = defaults.bool(forKey: SettingsPrefsKeys.avatarHerited)
        // Default true for showFocusInChat and sounds if never set
        showFocusInChat = defaults.object(forKey: SettingsPrefsKeys.showFocusInChat) as? Bool ?? true
        showLevel = defaults.bool(forKey: SettingsPrefsKeys.showLevel)
        backgroundMusic = defaults.bool(forKey: SettingsPrefsKeys.backgroundMusic)
        sounds = defaults.object(forKey: SettingsPrefsKeys.sounds) as? Bool ?? true
        faceID = defaults.bool(forKey: SettingsPrefsKeys.faceID)

        // Mark loading done so onChange handlers start saving
        didLoadSettings = true
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

    private func uploadAvatar(image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        await MainActor.run { isUploadingPhoto = true }

        do {
            let avatarUrl = try await userService.uploadAvatar(imageData: imageData)
            await MainActor.run {
                if var updatedUser = store.user {
                    let cacheBustUrl = avatarUrl.contains("?")
                        ? "\(avatarUrl)&v=\(Int(Date().timeIntervalSince1970))"
                        : "\(avatarUrl)?v=\(Int(Date().timeIntervalSince1970))"
                    updatedUser.avatarURL = cacheBustUrl
                    store.user = updatedUser
                }
                isUploadingPhoto = false
            }
        } catch {
            print("Avatar upload error: \(error)")
            await MainActor.run { isUploadingPhoto = false }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await userService.deleteAccount()
                await MainActor.run {
                    AppRouter.shared.showSettings = false
                    FocusAppStore.shared.signOut()
                }
            } catch {
                print("Failed to delete account: \(error)")
            }
        }
    }
}

// MARK: - Settings Account View (settings_02)

struct SettingsAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: FocusAppStore

    @State private var showEditName = false
    @State private var showEditPronouns = false
    @State private var showEditEmail = false
    @State private var showEditPassword = false
    @State private var showDeleteAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var showDeleteError = false

    private let userService = UserService()

    var body: some View {
        ZStack {
            SettingsColors.darkNavy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Compte")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)

                // Fields
                VStack(spacing: 0) {
                    // Nom
                    Button(action: { showEditName = true }) {
                        accountRow(label: "Nom", value: store.user?.firstName ?? store.user?.name ?? "Non defini")
                    }

                    accountDivider

                    // Membre depuis (Account age)
                    accountRow(label: "Membre depuis", value: accountAgeDisplay)

                    accountDivider

                    // Pronoms
                    Button(action: { showEditPronouns = true }) {
                        accountRow(label: "Pronoms", value: pronounsDisplay)
                    }

                    accountDivider

                    // Email
                    Button(action: { showEditEmail = true }) {
                        accountRow(label: "Email", value: store.user?.email ?? "Non defini")
                    }

                    accountDivider

                    // Password
                    Button(action: { showEditPassword = true }) {
                        accountRow(label: "Mot de passe", value: "Modifier")
                    }
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 32)

                // Delete account link
                Button(action: { showDeleteAlert = true }) {
                    if isDeletingAccount {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.red)
                            Text("Suppression en cours...")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("Supprimer le compte")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                }
                .disabled(isDeletingAccount)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditName) {
            SettingsEditNameView(
                currentName: store.user?.firstName ?? "",
                onSave: { newName in
                    Task { await updateName(newName) }
                }
            )
        }
        .sheet(isPresented: $showEditPronouns) {
            SettingsEditPronounsView(
                currentPronouns: store.user?.gender ?? "male",
                onSave: { newPronouns in
                    Task { await updatePronouns(newPronouns) }
                }
            )
        }
        .sheet(isPresented: $showEditEmail) {
            SettingsEditEmailView(currentEmail: store.user?.email ?? "")
        }
        .sheet(isPresented: $showEditPassword) {
            SettingsEditPasswordView()
        }
        .alert("Supprimer le compte", isPresented: $showDeleteAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) { deleteAccount() }
        } message: {
            Text("Cette action est irreversible. Toutes tes donnees seront supprimees definitivement.")
        }
        .alert("Erreur", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "Une erreur est survenue lors de la suppression du compte.")
        }
    }

    // MARK: - Computed Properties

    private var pronounsDisplay: String {
        switch store.user?.gender {
        case "elle_la", "she", "female": return "Elle / La"
        case "il_lui", "he", "male": return "Il / Lui"
        case "iel_iels", "they", "other": return "Iel / Iels"
        default: return "Non defini"
        }
    }

    private var accountAgeDisplay: String {
        guard let createdAt = store.user?.createdAt else {
            return "Recemment"
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

    // MARK: - Row Components

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
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 16)
    }

    private var accountDivider: some View {
        Divider().background(Color.white.opacity(0.08))
    }

    // MARK: - API Actions

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
        isDeletingAccount = true
        Task {
            do {
                try await userService.deleteAccount()
                await MainActor.run {
                    isDeletingAccount = false
                    AppRouter.shared.showSettings = false
                    FocusAppStore.shared.signOut()
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteError = error.localizedDescription
                    showDeleteError = true
                }
                print("Failed to delete account: \(error)")
            }
        }
    }
}

// MARK: - Edit Name View (settings_03)

struct SettingsEditNameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let onSave: (String) -> Void

    init(currentName: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: currentName)
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            SettingsColors.darkNavy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Nom")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)

                // Text field
                TextField("", text: $name, prompt: Text("Votre nom").foregroundColor(.gray))
                    .font(.system(size: 17))
                    .foregroundColor(SettingsColors.darkNavy)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)

                Spacer()

                // Save button
                Button(action: {
                    onSave(name)
                    dismiss()
                }) {
                    Text("Sauvegarder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 56)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .padding(.bottom, 50)
            }
        }
        .presentationBackground(SettingsColors.darkNavy)
    }
}

// MARK: - Edit Email View

struct SettingsEditEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    init(currentEmail: String) {
        _email = State(initialValue: currentEmail)
    }

    var body: some View {
        ZStack {
            SettingsColors.darkNavy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Changer l'email")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Text("Un email de confirmation sera envoye a la nouvelle adresse.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                // Email field
                TextField("", text: $email, prompt: Text("Nouvel email").foregroundColor(.gray))
                    .font(.system(size: 17))
                    .foregroundColor(SettingsColors.darkNavy)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                if let success = successMessage {
                    Text(success)
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                Spacer()

                // Save button
                Button(action: { updateEmail() }) {
                    if isSaving {
                        ProgressView()
                            .tint(SettingsColors.darkNavy)
                            .frame(width: 200, height: 56)
                            .background(Capsule().fill(Color.white.opacity(0.85)))
                    } else {
                        Text("Sauvegarder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(SettingsColors.darkNavy)
                            .frame(width: 200, height: 56)
                            .background(Capsule().fill(Color.white.opacity(0.85)))
                    }
                }
                .disabled(isSaving || email.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(email.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .padding(.bottom, 50)
            }
        }
        .presentationBackground(SettingsColors.darkNavy)
    }

    private func updateEmail() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await AuthService.shared.updateEmail(newEmail: trimmedEmail)
                await MainActor.run {
                    isSaving = false
                    successMessage = "Un email de confirmation a ete envoye."
                    // Update local user email
                    if var user = FocusAppStore.shared.user {
                        user.email = trimmedEmail
                        FocusAppStore.shared.user = user
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

// MARK: - Edit Password View

struct SettingsEditPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        ZStack {
            SettingsColors.darkNavy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Mot de passe")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Text("Choisissez un nouveau mot de passe (minimum 6 caracteres).")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                VStack(spacing: 16) {
                    SecureField("", text: $newPassword, prompt: Text("Nouveau mot de passe").foregroundColor(.gray))
                        .font(.system(size: 17))
                        .foregroundColor(SettingsColors.darkNavy)
                        .textContentType(.newPassword)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(16)

                    SecureField("", text: $confirmPassword, prompt: Text("Confirmer le mot de passe").foregroundColor(.gray))
                        .font(.system(size: 17))
                        .foregroundColor(SettingsColors.darkNavy)
                        .textContentType(.newPassword)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                if let success = successMessage {
                    Text(success)
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                Spacer()

                // Save button
                Button(action: { updatePassword() }) {
                    if isSaving {
                        ProgressView()
                            .tint(SettingsColors.darkNavy)
                            .frame(width: 200, height: 56)
                            .background(Capsule().fill(Color.white.opacity(0.85)))
                    } else {
                        Text("Sauvegarder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(SettingsColors.darkNavy)
                            .frame(width: 200, height: 56)
                            .background(Capsule().fill(Color.white.opacity(0.85)))
                    }
                }
                .disabled(isSaving || !isFormValid)
                .opacity(!isFormValid ? 0.4 : 1)
                .padding(.bottom, 50)
            }
        }
        .presentationBackground(SettingsColors.darkNavy)
    }

    private var isFormValid: Bool {
        !newPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func updatePassword() {
        guard isFormValid else {
            if newPassword != confirmPassword {
                errorMessage = "Les mots de passe ne correspondent pas."
            } else if newPassword.count < 6 {
                errorMessage = "Le mot de passe doit contenir au moins 6 caracteres."
            }
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await AuthService.shared.updatePassword(newPassword: newPassword)
                await MainActor.run {
                    isSaving = false
                    successMessage = "Mot de passe mis a jour avec succes."
                    newPassword = ""
                    confirmPassword = ""
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

// MARK: - Edit Pronouns View (settings_05)

struct SettingsEditPronounsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPronouns: String
    let onSave: (String) -> Void

    private let options = [
        ("Elle / La", "female"),
        ("Il / Lui", "male"),
        ("Iel / Iels", "other")
    ]

    init(currentPronouns: String, onSave: @escaping (String) -> Void) {
        _selectedPronouns = State(initialValue: currentPronouns)
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            SettingsColors.darkNavy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Vos pronoms")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Subtitle
                Text("Nous devons le savoir pour garantir une generation de contenu appropriee.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                Spacer()

                // Pronouns picker (styled like wheel)
                VStack(spacing: 0) {
                    ForEach(options, id: \.1) { (label, value) in
                        Button(action: {
                            selectedPronouns = value
                        }) {
                            Text(label)
                                .font(.system(size: 20, weight: selectedPronouns == value ? .semibold : .regular))
                                .foregroundColor(selectedPronouns == value ? .white : .white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
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
                Button(action: {
                    onSave(selectedPronouns)
                    dismiss()
                }) {
                    Text("Sauvegarder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(SettingsColors.darkNavy)
                        .frame(width: 200, height: 56)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.85))
                        )
                }
                .padding(.bottom, 50)
            }
        }
        .presentationBackground(SettingsColors.darkNavy)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(FocusAppStore.shared)
}
