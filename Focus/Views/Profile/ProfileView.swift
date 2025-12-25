import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var ritualsViewModel = RitualsViewModel()
    @State private var showSettings = false
    @State private var showFlameInfo = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var editingRitual: DailyRitual?

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.xl) {
                // Profile Header
                profileHeader
                    .padding(.top, SpacingTokens.lg)

                // Level & Streak Section
                levelSection

                // Daily Routines Section
                routinesSection

                // Active Quests
                if !activeQuests.isEmpty {
                    questsSection
                }

                // Statistics
                statisticsSection

                Spacer(minLength: 100)
            }
            .padding(.horizontal, SpacingTokens.lg)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                user: store.user,
                selectedPhotoItem: $selectedPhotoItem,
                isUploading: $isUploadingPhoto,
                onPhotoSelected: { _ in },
                onDeletePhoto: { },
                onTakeSelfie: { },
                onSignOut: { FocusAppStore.shared.signOut() }
            )
        }
        .sheet(isPresented: $showFlameInfo) {
            FlameInfoSheet(
                currentStreak: store.streakData?.currentStreak ?? 0,
                flameLevels: store.streakData?.flameLevels ?? [],
                todayValidation: store.streakData?.todayValidation
            )
        }
        .sheet(item: $editingRitual) { ritual in
            EditRitualSheet(viewModel: ritualsViewModel, ritual: ritual)
        }
        .onAppear {
            ritualsViewModel.refresh()
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: SpacingTokens.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                if let avatarUrl = store.user?.avatarURL, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } placeholder: {
                        userInitials
                    }
                } else {
                    userInitials
                }
            }

            // Name
            Text(displayName)
                .font(.satoshi(24, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            // Email or pseudo
            if let email = store.user?.email {
                Text(email)
                    .font(.satoshi(14))
                    .foregroundColor(ColorTokens.textMuted)
            }
        }
    }

    private var userInitials: some View {
        Text(initials)
            .font(.satoshi(36, weight: .bold))
            .foregroundColor(.white)
    }

    // MARK: - Level Section (Simplified)
    private var levelSection: some View {
        Button(action: { showFlameInfo = true }) {
            HStack(spacing: SpacingTokens.md) {
                // Flame icon - compact
                Text("🔥")
                    .font(.system(size: 28))

                // Streak count
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.streakData?.currentStreak ?? 0) jours")
                        .font(.satoshi(18, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text(currentLevel?.name ?? "Spark")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()

                // Chevron to see more
                Image(systemName: "chevron.right")
                    .font(.satoshi(14))
                    .foregroundColor(ColorTokens.textMuted)
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Quests Section
    private var questsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("Quêtes actives")
                    .font(.satoshi(18, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text("\(activeQuests.count)")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textMuted)
            }

            ForEach(activeQuests) { quest in
                questRow(quest)
            }
        }
    }

    private func questRow(_ quest: Quest) -> some View {
        Card {
            HStack(spacing: SpacingTokens.md) {
                // Area emoji
                Text(quest.area.emoji)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)
                }

                Spacer()

                // Progress
                CircularProgressView(progress: quest.progress, size: 40, lineWidth: 4)
            }
            .padding(SpacingTokens.md)
        }
    }

    // MARK: - Daily Routines Section
    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("Mes routines")
                    .font(.satoshi(18, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text("\(ritualsViewModel.rituals.count)")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textMuted)
            }

            if ritualsViewModel.rituals.isEmpty {
                // Empty state
                Card {
                    VStack(spacing: SpacingTokens.md) {
                        Text("✨")
                            .font(.system(size: 40))

                        Text("Aucune routine")
                            .font(.satoshi(16, weight: .medium))
                            .foregroundColor(ColorTokens.textPrimary)

                        Text("Ajoute des routines quotidiennes depuis les paramètres")
                            .font(.satoshi(13))
                            .foregroundColor(ColorTokens.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(SpacingTokens.lg)
                }
            } else {
                // Routines list
                VStack(spacing: SpacingTokens.xs) {
                    ForEach(ritualsViewModel.rituals) { ritual in
                        ProfileRoutineRow(
                            ritual: ritual,
                            onEdit: {
                                editingRitual = ritual
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Statistiques")
                .font(.satoshi(18, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: SpacingTokens.sm) {
                statCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(store.streakData?.currentStreak ?? 0)",
                    label: "Streak actuel"
                )

                statCard(
                    icon: "trophy.fill",
                    iconColor: .yellow,
                    value: "\(store.streakData?.longestStreak ?? 0)",
                    label: "Meilleur streak"
                )

                statCard(
                    icon: "target",
                    iconColor: ColorTokens.primaryStart,
                    value: "\(activeQuests.count)",
                    label: "Quêtes actives"
                )

                statCard(
                    icon: "checkmark.circle.fill",
                    iconColor: ColorTokens.success,
                    value: "\(completedQuestsCount)",
                    label: "Quêtes terminées"
                )
            }
        }
    }

    private func statCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        Card {
            VStack(spacing: SpacingTokens.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)

                Text(value)
                    .font(.satoshi(24, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text(label)
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.md)
        }
    }

    // MARK: - Computed Properties
    private var displayName: String {
        if let pseudo = store.user?.pseudo, !pseudo.isEmpty {
            return pseudo
        }
        if let firstName = store.user?.firstName, !firstName.isEmpty {
            return firstName
        }
        return "Utilisateur"
    }

    private var initials: String {
        let name = displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var currentLevel: FlameLevel? {
        store.streakData?.flameLevels.first(where: { $0.isCurrent })
    }

    private var nextLevel: FlameLevel? {
        guard let current = currentLevel else {
            return store.streakData?.flameLevels.first
        }
        return store.streakData?.flameLevels.first(where: { $0.level == current.level + 1 })
    }

    private var progressToNextLevel: Double {
        guard let current = currentLevel, let next = nextLevel else { return 0 }
        let currentStreak = store.streakData?.currentStreak ?? 0
        let range = next.daysRequired - current.daysRequired
        let progress = currentStreak - current.daysRequired
        return range > 0 ? min(1.0, max(0, Double(progress) / Double(range))) : 0
    }

    private var activeQuests: [Quest] {
        store.quests.filter { $0.status == .active }
    }

    private var completedQuestsCount: Int {
        store.quests.filter { $0.status == .completed }.count
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(ColorTokens.surface, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    LinearGradient(
                        colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.satoshi(10, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Profile Routine Row
struct ProfileRoutineRow: View {
    let ritual: DailyRitual
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: SpacingTokens.md) {
                // Icon
                Text(ritual.icon)
                    .font(.satoshi(24))
                    .frame(width: 40, height: 40)
                    .background(ColorTokens.primarySoft)
                    .cornerRadius(RadiusTokens.sm)

                // Title & frequency
                VStack(alignment: .leading, spacing: 2) {
                    Text(ritual.title)
                        .font(.satoshi(15, weight: .medium))
                        .foregroundColor(ColorTokens.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: SpacingTokens.xs) {
                        Text(ritual.frequency.displayName)
                            .font(.satoshi(12))
                            .foregroundColor(ColorTokens.textMuted)

                        if let time = ritual.scheduledTime {
                            Text("•")
                                .font(.satoshi(12))
                                .foregroundColor(ColorTokens.textMuted)
                            Text(time)
                                .font(.satoshi(12))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                }

                Spacer()

                // Edit chevron
                Image(systemName: "chevron.right")
                    .font(.satoshi(12, weight: .medium))
                    .foregroundColor(ColorTokens.textMuted)
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(FocusAppStore.shared)
    }
}
