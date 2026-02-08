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

// MARK: - Settings View (Ralph Design - Dark Navy)

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: FocusAppStore

    // Photo state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false

    // Settings state
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
        .onChange(of: notificationsEnabled) { _, _ in
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
                    FocusAppStore.shared.signOut()
                    dismiss()
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
    @State private var showEditBirthday = false
    @State private var showEditPronouns = false
    @State private var showDeleteAlert = false

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

                    // Anniversaire
                    Button(action: { showEditBirthday = true }) {
                        accountRow(label: "Anniversaire", value: "Non defini")
                    }

                    accountDivider

                    // Pronoms
                    Button(action: { showEditPronouns = true }) {
                        accountRow(label: "Pronoms", value: pronounsDisplay)
                    }

                    accountDivider

                    // Email
                    accountRow(label: "Changer l'email", value: store.user?.email ?? "")

                    accountDivider

                    // Password
                    Button(action: {}) {
                        HStack {
                            Text("Changer le mot de passe")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 32)

                // Delete account link
                Button(action: { showDeleteAlert = true }) {
                    Text("Supprimer le compte")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
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
        .sheet(isPresented: $showEditBirthday) {
            SettingsEditBirthdayView()
        }
        .sheet(isPresented: $showEditPronouns) {
            SettingsEditPronounsView(
                currentPronouns: store.user?.gender ?? "he",
                onSave: { newPronouns in
                    Task { await updatePronouns(newPronouns) }
                }
            )
        }
        .alert("Supprimer le compte", isPresented: $showDeleteAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) { deleteAccount() }
        } message: {
            Text("Cette action est irreversible.")
        }
    }

    private var pronounsDisplay: String {
        switch store.user?.gender {
        case "she": return "Elle / La"
        case "he": return "Il / Lui"
        case "they": return "Iel / Iels"
        default: return "Non defini"
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
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 16)
    }

    private var accountDivider: some View {
        Divider().background(Color.white.opacity(0.08))
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
                }
            } catch {
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

// MARK: - Edit Birthday View (settings_04)

struct SettingsEditBirthdayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()

    var body: some View {
        ZStack {
            SettingsColors.darkNavy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Votre date de naissance")
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
                Text("Nous avons besoin de cette information pour rendre votre experience plus pertinente et securisee.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                Spacer()

                // Date picker (wheel style)
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .padding(.horizontal, 24)

                Spacer()

                // Save button
                Button(action: { dismiss() }) {
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

// MARK: - Edit Pronouns View (settings_05)

struct SettingsEditPronounsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPronouns: String
    let onSave: (String) -> Void

    private let options = [
        ("Elle / La", "she"),
        ("Il / Lui", "he"),
        ("Iel / Iels", "they")
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
