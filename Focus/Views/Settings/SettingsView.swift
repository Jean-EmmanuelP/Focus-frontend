import SwiftUI
import PhotosUI

// MARK: - Settings View (V1 Minimal)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: FocusAppStore

    let user: User?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isUploading: Bool
    let onPhotoSelected: (UIImage) -> Void
    let onDeletePhoto: () -> Void
    let onTakeSelfie: () -> Void
    let onSignOut: () -> Void

    // Settings state
    @State private var notificationsEnabled = true
    @State private var morningReminderTime = Date()
    @State private var selectedLanguage = "fr"
    @State private var selectedTimezone = TimeZone.current.identifier
    @State private var showDeleteAccountAlert = false
    @State private var showEditName = false
    @State private var editedName = ""

    private let userService = UserService()

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Section
                Section {
                    // Photo de profil
                    HStack {
                        ZStack(alignment: .bottomTrailing) {
                            if let user = user {
                                AvatarView(name: user.name, avatarURL: user.avatarURL, size: 60)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 24, height: 24)
                                    .overlay(Image(systemName: "camera.fill").font(.system(size: 11)).foregroundColor(.white))
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user?.name ?? "Utilisateur")
                                .font(.headline)
                            if let email = user?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 12)

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    // Nom d'utilisateur
                    Button {
                        editedName = user?.pseudo ?? user?.firstName ?? ""
                        showEditName = true
                    } label: {
                        HStack {
                            Label("Nom d'affichage", systemImage: "person")
                            Spacer()
                            Text(user?.pseudo ?? user?.firstName ?? "Non défini")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    // Langue
                    Picker(selection: $selectedLanguage) {
                        Text("Français").tag("fr")
                        Text("English").tag("en")
                    } label: {
                        Label("Langue", systemImage: "globe")
                    }

                    // Fuseau horaire
                    NavigationLink {
                        TimezonePickerView(selectedTimezone: $selectedTimezone)
                    } label: {
                        HStack {
                            Label("Fuseau horaire", systemImage: "clock")
                            Spacer()
                            Text(formatTimezone(selectedTimezone))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Profil")
                }

                // MARK: - Notifications Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notifications", systemImage: "bell")
                    }

                    if notificationsEnabled {
                        DatePicker(selection: $morningReminderTime, displayedComponents: .hourAndMinute) {
                            Label("Rappel du matin", systemImage: "sun.max")
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Kai t'enverra tes objectifs du jour à l'heure choisie.")
                }

                // MARK: - Account Section
                Section {
                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        Label("Supprimer mon compte", systemImage: "trash")
                    }

                    Button {
                        onSignOut()
                        dismiss()
                    } label: {
                        Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Compte")
                }

                // MARK: - Legal Section
                Section {
                    Link(destination: URL(string: "https://firelevel.app/privacy")!) {
                        HStack {
                            Label("Politique de confidentialité", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Link(destination: URL(string: "https://firelevel.app/terms")!) {
                        HStack {
                            Label("Conditions d'utilisation", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("Légal")
                }

                // Version
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .alert("Supprimer le compte", isPresented: $showDeleteAccountAlert) {
                Button("Annuler", role: .cancel) {}
                Button("Supprimer", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Cette action est irréversible. Toutes tes données seront supprimées définitivement.")
            }
            .sheet(isPresented: $showEditName) {
                EditNameSheet(name: $editedName) { newName in
                    Task {
                        await updateName(newName)
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
            .onChange(of: notificationsEnabled) { _, _ in
                saveNotificationSettings()
            }
            .onChange(of: morningReminderTime) { _, _ in
                saveNotificationSettings()
            }
            .onChange(of: selectedLanguage) { _, newValue in
                saveLanguage(newValue)
            }
            .onChange(of: selectedTimezone) { _, newValue in
                saveTimezone(newValue)
            }
        }
    }

    // MARK: - Helpers

    private func formatTimezone(_ identifier: String) -> String {
        let tz = TimeZone(identifier: identifier)
        let abbreviation = tz?.abbreviation() ?? ""
        let offset = tz?.secondsFromGMT() ?? 0
        let hours = offset / 3600
        let sign = hours >= 0 ? "+" : ""
        return "\(abbreviation) (UTC\(sign)\(hours))"
    }

    private func loadSettings() {
        // Load from user profile if available
        if let user = store.user {
            // Use stored values or defaults
            selectedLanguage = user.language ?? "fr"
            selectedTimezone = user.timezone ?? TimeZone.current.identifier
            notificationsEnabled = user.notificationsEnabled ?? true

            // Parse morning reminder time (stored as "HH:MM")
            if let timeString = user.morningReminderTime {
                let parts = timeString.split(separator: ":")
                if parts.count == 2,
                   let hour = Int(parts[0]),
                   let minute = Int(parts[1]) {
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    components.hour = hour
                    components.minute = minute
                    morningReminderTime = Calendar.current.date(from: components) ?? Date()
                }
            } else {
                // Default to 8:00 AM
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 8
                components.minute = 0
                morningReminderTime = Calendar.current.date(from: components) ?? Date()
            }
        }
    }

    private func saveNotificationSettings() {
        // Format time as "HH:MM"
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: morningReminderTime)

        Task {
            do {
                let updated = try await userService.updateSettings(
                    notificationsEnabled: notificationsEnabled,
                    morningReminderTime: timeString
                )
                await MainActor.run {
                    store.user = User(from: updated)
                }
            } catch {
                print("Failed to save notification settings: \(error)")
            }
        }
    }

    private func updateName(_ newName: String) async {
        do {
            let updatedUser = try await userService.updateProfile(
                pseudo: newName,
                firstName: nil,
                lastName: nil,
                gender: nil,
                age: nil,
                description: nil,
                hobbies: nil,
                lifeGoal: nil
            )
            await MainActor.run {
                FocusAppStore.shared.user = User(from: updatedUser)
            }
        } catch {
            print("Failed to update name: \(error)")
        }
    }

    private func saveLanguage(_ language: String) {
        Task {
            do {
                let updated = try await userService.updateSettings(language: language)
                await MainActor.run {
                    store.user = User(from: updated)
                }
            } catch {
                print("Failed to save language: \(error)")
            }
        }
    }

    private func saveTimezone(_ timezone: String) {
        Task {
            do {
                let updated = try await userService.updateSettings(timezone: timezone)
                await MainActor.run {
                    store.user = User(from: updated)
                }
            } catch {
                print("Failed to save timezone: \(error)")
            }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await userService.deleteAccount()
                await MainActor.run {
                    onSignOut()
                    dismiss()
                }
            } catch {
                print("Failed to delete account: \(error)")
            }
        }
    }
}

// MARK: - Edit Name Sheet
struct EditNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom d'affichage", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Ce nom sera visible par tes amis.")
                }
            }
            .navigationTitle("Modifier le nom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Timezone Picker
struct TimezonePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTimezone: String

    private let commonTimezones = [
        "Europe/Paris",
        "Europe/London",
        "Europe/Berlin",
        "Europe/Brussels",
        "Europe/Rome",
        "Europe/Madrid",
        "America/New_York",
        "America/Los_Angeles",
        "America/Chicago",
        "America/Toronto",
        "America/Montreal",
        "Asia/Tokyo",
        "Asia/Shanghai",
        "Asia/Dubai",
        "Australia/Sydney",
        "Pacific/Auckland"
    ]

    var body: some View {
        List {
            ForEach(commonTimezones, id: \.self) { tz in
                Button {
                    selectedTimezone = tz
                    UserDefaults.standard.set(tz, forKey: "user_timezone")
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(cityName(from: tz))
                                .foregroundColor(.primary)
                            Text(formatOffset(tz))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedTimezone == tz {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Fuseau horaire")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cityName(from identifier: String) -> String {
        identifier.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? identifier
    }

    private func formatOffset(_ identifier: String) -> String {
        guard let tz = TimeZone(identifier: identifier) else { return "" }
        let offset = tz.secondsFromGMT() / 3600
        let sign = offset >= 0 ? "+" : ""
        return "UTC\(sign)\(offset)"
    }
}

// MARK: - Preview
#Preview {
    SettingsView(
        user: nil,
        selectedPhotoItem: .constant(nil),
        isUploading: .constant(false),
        onPhotoSelected: { _ in },
        onDeletePhoto: {},
        onTakeSelfie: {},
        onSignOut: {}
    )
    .environmentObject(FocusAppStore.shared)
}
