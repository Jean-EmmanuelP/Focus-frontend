import SwiftUI
import PhotosUI

// MARK: - Settings View
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

    @State private var showEditProfile = false
    @State private var showQuestsSection = false
    @State private var showRitualsSection = false
    @State private var showStatsSection = false
    @State private var showTutorial = false
    @State private var showGoogleCalendar = false
    @State private var showAppBlocker = false
    @State private var selectedVisibility: DayVisibility = .crewOnly
    @State private var isUpdatingVisibility = false
    @State private var selectedProductivityPeak: ProductivityPeak?
    @State private var isUpdatingProductivity = false

    private let userService = UserService()
    private let crewService = CrewService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.lg) {
                    // Profile Header
                    profileHeader

                    // Menu Items
                    VStack(spacing: SpacingTokens.sm) {
                        // Quests & Areas
                        SettingsMenuItem(
                            icon: "🎯",
                            title: "settings.quests_areas".localized,
                            subtitle: "settings.quests_areas_subtitle".localized
                        ) {
                            showQuestsSection = true
                        }

                        // Daily Rituals
                        SettingsMenuItem(
                            icon: "✅",
                            title: "settings.daily_rituals".localized,
                            subtitle: "settings.daily_rituals_subtitle".localized
                        ) {
                            showRitualsSection = true
                        }

                        // Statistics
                        SettingsMenuItem(
                            icon: "📊",
                            title: "settings.statistics".localized,
                            subtitle: "settings.statistics_subtitle".localized
                        ) {
                            showStatsSection = true
                        }

                        // Google Calendar
                        SettingsMenuItem(
                            icon: "📅",
                            title: "Google Calendar",
                            subtitle: "Synchroniser avec ton calendrier"
                        ) {
                            showGoogleCalendar = true
                        }

                        // App Blocker
                        SettingsMenuItem(
                            icon: "🔒",
                            title: "Blocage d'apps",
                            subtitle: "Bloquer les apps pendant le Focus"
                        ) {
                            showAppBlocker = true
                        }

                        // Day Visibility
                        dayVisibilitySection

                        // Productivity Peak
                        productivityPeakSection

                        // Tutorial
                        SettingsMenuItem(
                            icon: "🎬",
                            title: "settings.watch_tutorial".localized,
                            subtitle: "settings.watch_tutorial_subtitle".localized
                        ) {
                            showTutorial = true
                        }
                    }
                    .padding(.horizontal, SpacingTokens.lg)

                    Spacer(minLength: SpacingTokens.xxl)

                    // Sign Out Button
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSignOut()
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("settings.sign_out".localized)
                        }
                        .font(.inter(16, weight: .medium))
                        .foregroundColor(ColorTokens.error)
                    }
                    .padding(.bottom, SpacingTokens.xxl)
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(
                    user: user,
                    onSave: { pseudo, firstName, lastName, gender, age, description, hobbies, lifeGoal in
                        Task {
                            do {
                                let updatedUser = try await userService.updateProfile(
                                    pseudo: pseudo,
                                    firstName: firstName,
                                    lastName: lastName,
                                    gender: gender,
                                    age: age,
                                    description: description,
                                    hobbies: hobbies,
                                    lifeGoal: lifeGoal
                                )
                                // Update the store with new user data
                                await MainActor.run {
                                    FocusAppStore.shared.user = User(from: updatedUser)
                                }
                            } catch {
                                print("Failed to update profile: \(error)")
                            }
                        }
                    }
                )
            }
            .navigationDestination(isPresented: $showQuestsSection) {
                QuestsView()
            }
            .navigationDestination(isPresented: $showRitualsSection) {
                ManageRitualsView()
            }
            .navigationDestination(isPresented: $showStatsSection) {
                StatisticsView()
            }
            .navigationDestination(isPresented: $showGoogleCalendar) {
                GoogleCalendarSettingsView()
            }
            .navigationDestination(isPresented: $showAppBlocker) {
                AppBlockerSettingsView()
            }
            .sheet(isPresented: $showTutorial) {
                TutorialVideoView()
            }
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Avatar with photo options
            ZStack(alignment: .bottomTrailing) {
                if let user = user {
                    AvatarView(name: user.name, avatarURL: user.avatarURL, size: 100)
                } else {
                    Circle()
                        .fill(ColorTokens.surface)
                        .frame(width: 100, height: 100)
                }

                // Camera button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Circle()
                        .fill(ColorTokens.primaryStart)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.inter(14))
                                .foregroundColor(.white)
                        }
                }
            }

            // User info
            VStack(spacing: SpacingTokens.xs) {
                Text(user?.name ?? "User")
                    .font(.inter(22, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                if let email = user?.email {
                    Text(email)
                        .font(.inter(14))
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }

            // Edit Profile Button
            Button(action: { showEditProfile = true }) {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "pencil")
                    Text("settings.edit_profile".localized)
                }
                .font(.inter(14, weight: .medium))
                .foregroundColor(ColorTokens.primaryStart)
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.vertical, SpacingTokens.sm)
                .background(ColorTokens.primaryStart.opacity(0.1))
                .cornerRadius(RadiusTokens.lg)
            }

            // Streak info
            if let streak = user?.currentStreak, streak > 0 {
                HStack(spacing: SpacingTokens.sm) {
                    Text("🔥")
                    Text("\(streak) " + "settings.day_streak".localized)
                        .font(.inter(14, weight: .semibold))
                        .foregroundColor(ColorTokens.primaryStart)
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.xs)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
            }
        }
        .padding(.vertical, SpacingTokens.xl)
        .onAppear {
            updateSelectedVisibilityFromStore()
            updateSelectedProductivityFromStore()
        }
    }

    // MARK: - Day Visibility Section
    private var dayVisibilitySection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("👁")
                    .font(.inter(24))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("profile.day_visibility".localized)
                            .font(.inter(16, weight: .semibold))
                            .foregroundColor(ColorTokens.textPrimary)
                        Spacer()
                        if isUpdatingVisibility {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    Text("profile.visibility_description".localized)
                        .font(.inter(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.top, SpacingTokens.lg)

            // Visibility options
            VStack(spacing: SpacingTokens.xs) {
                ForEach(DayVisibility.allCases, id: \.self) { visibility in
                    Button {
                        updateVisibility(visibility)
                    } label: {
                        HStack {
                            Image(systemName: visibility.icon)
                                .font(.inter(16))
                                .foregroundColor(selectedVisibility == visibility ? ColorTokens.primaryStart : ColorTokens.textMuted)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(visibility.displayName)
                                    .font(.inter(14))
                                    .foregroundColor(selectedVisibility == visibility ? ColorTokens.textPrimary : ColorTokens.textSecondary)

                                Text(visibility.description)
                                    .font(.inter(11))
                                    .foregroundColor(ColorTokens.textMuted)
                            }

                            Spacer()

                            if selectedVisibility == visibility {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ColorTokens.primaryStart)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                        .padding(SpacingTokens.sm)
                        .background(selectedVisibility == visibility ? ColorTokens.primarySoft : Color.clear)
                        .cornerRadius(RadiusTokens.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isUpdatingVisibility)
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.bottom, SpacingTokens.lg)
        }
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Productivity Peak Section
    private var productivityPeakSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("⚡")
                    .font(.inter(24))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("settings.productivity_peak".localized)
                            .font(.inter(16, weight: .semibold))
                            .foregroundColor(ColorTokens.textPrimary)
                        Spacer()
                        if isUpdatingProductivity {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    Text("settings.productivity_peak_description".localized)
                        .font(.inter(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.top, SpacingTokens.lg)

            // Productivity options
            VStack(spacing: SpacingTokens.xs) {
                ForEach(ProductivityPeak.allCases, id: \.self) { peak in
                    Button {
                        updateProductivityPeak(peak)
                    } label: {
                        HStack {
                            Image(systemName: peak.icon)
                                .font(.inter(16))
                                .foregroundColor(selectedProductivityPeak == peak ? ColorTokens.primaryStart : ColorTokens.textMuted)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(peak.displayName)
                                    .font(.inter(14))
                                    .foregroundColor(selectedProductivityPeak == peak ? ColorTokens.textPrimary : ColorTokens.textSecondary)

                                Text(peak.description)
                                    .font(.inter(11))
                                    .foregroundColor(ColorTokens.textMuted)
                            }

                            Spacer()

                            if selectedProductivityPeak == peak {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ColorTokens.primaryStart)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                        .padding(SpacingTokens.sm)
                        .background(selectedProductivityPeak == peak ? ColorTokens.primarySoft : Color.clear)
                        .cornerRadius(RadiusTokens.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isUpdatingProductivity)
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.bottom, SpacingTokens.lg)
        }
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Visibility Helpers
    private func updateSelectedVisibilityFromStore() {
        if let visibility = store.user?.dayVisibility,
           let dayVis = DayVisibility(rawValue: visibility) {
            if selectedVisibility != dayVis {
                selectedVisibility = dayVis
            }
        }
    }

    private func updateVisibility(_ visibility: DayVisibility) {
        guard visibility != selectedVisibility else { return }

        isUpdatingVisibility = true
        let previousVisibility = selectedVisibility
        selectedVisibility = visibility

        Task {
            do {
                try await crewService.updateDayVisibility(visibility)
                // Update the store's user with the new visibility
                await MainActor.run {
                    if var user = store.user {
                        user.dayVisibility = visibility.rawValue
                        store.user = user
                    }
                }
            } catch {
                // Revert on error
                await MainActor.run {
                    selectedVisibility = previousVisibility
                }
            }
            await MainActor.run {
                isUpdatingVisibility = false
            }
        }
    }

    // MARK: - Productivity Helpers
    private func updateSelectedProductivityFromStore() {
        if let peak = store.user?.productivityPeak {
            if selectedProductivityPeak != peak {
                selectedProductivityPeak = peak
            }
        }
    }

    private func updateProductivityPeak(_ peak: ProductivityPeak) {
        guard peak != selectedProductivityPeak else { return }

        isUpdatingProductivity = true
        let previousPeak = selectedProductivityPeak
        selectedProductivityPeak = peak

        Task {
            do {
                let updatedUser = try await userService.updateProductivityPeak(peak)
                await MainActor.run {
                    store.user = User(from: updatedUser)
                }
            } catch {
                await MainActor.run {
                    selectedProductivityPeak = previousPeak
                }
            }
            await MainActor.run {
                isUpdatingProductivity = false
            }
        }
    }
}

// MARK: - Settings Menu Item
struct SettingsMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.md) {
                Text(icon)
                    .font(.inter(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.inter(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text(subtitle)
                        .font(.inter(13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(ColorTokens.textMuted)
            }
            .padding(SpacingTokens.lg)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
    }
}

// MARK: - Statistics View
struct StatisticsView: View {
    @EnvironmentObject var store: FocusAppStore

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // This Week Summary
                weekSummaryCard

                // Sessions List
                if !store.weekSessions.isEmpty {
                    sessionsListSection
                }
            }
            .padding(SpacingTokens.lg)
        }
        .background(ColorTokens.background)
        .navigationTitle("stats.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Week Summary Card
    private var weekSummaryCard: some View {
        VStack(spacing: SpacingTokens.lg) {
            HStack {
                Text("📊")
                    .font(.inter(20))
                Text("stats.this_week".localized)
                    .font(.inter(16, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
            }

            HStack(spacing: SpacingTokens.xl) {
                StatBox(
                    value: "\(store.weekSessions.count)",
                    label: "stats.sessions".localized,
                    icon: "🔥"
                )

                StatBox(
                    value: "\(totalMinutes)m",
                    label: "stats.focused".localized,
                    icon: "⏱️"
                )

                StatBox(
                    value: "\(completedRituals)/\(totalRituals)",
                    label: "stats.routines".localized,
                    icon: "✅"
                )
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Sessions List Section
    private var sessionsListSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("stats.recent_sessions".localized)
                .font(.inter(14, weight: .semibold))
                .foregroundColor(ColorTokens.textSecondary)

            ForEach(sessionsByDay, id: \.date) { day in
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    // Day header
                    Text(formatDayHeader(day.date))
                        .font(.inter(12, weight: .medium))
                        .foregroundColor(ColorTokens.textMuted)

                    // Sessions for this day
                    ForEach(day.sessions) { session in
                        SessionRow(session: session)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var totalMinutes: Int {
        store.weekSessions.reduce(0) { $0 + $1.actualDurationMinutes }
    }

    private var completedRituals: Int {
        store.rituals.filter { $0.isCompleted }.count
    }

    private var totalRituals: Int {
        store.rituals.count
    }

    private var sessionsByDay: [(date: Date, sessions: [FocusSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.weekSessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, sessions: $0.value) }
    }

    private func formatDayHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "stats.today".localized
        } else if Calendar.current.isDateInYesterday(date) {
            return "stats.yesterday".localized
        } else {
            formatter.dateFormat = "EEEE d MMM"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(icon)
                .font(.inter(20))
            Text(value)
                .font(.inter(20, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)
            Text(label)
                .font(.inter(11))
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Row
struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Time
            Text(formatTime(session.startTime))
                .font(.inter(13, weight: .medium))
                .foregroundColor(ColorTokens.textMuted)
                .frame(width: 50, alignment: .leading)

            // Description or default
            Text(session.description ?? "Focus Session")
                .font(.inter(14))
                .foregroundColor(ColorTokens.textPrimary)
                .lineLimit(1)

            Spacer()

            // Duration
            Text(session.formattedActualDuration)
                .font(.inter(13, weight: .semibold))
                .foregroundColor(ColorTokens.primaryStart)
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.surface.opacity(0.5))
        .cornerRadius(RadiusTokens.sm)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
