import SwiftUI
import PhotosUI
import AVFoundation

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showCelebration = false
    @State private var celebrationCount = 0
    @State private var showProfileSheet = false
    @State private var showEditProfile = false
    @State private var showImageEditor = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploadingPhoto = false
    @State private var showFireModeModal = false
    @State private var showEditSession = false
    @State private var sessionToEdit: FocusSession?
    @State private var showDeleteSessionConfirm = false
    @State private var sessionToDelete: FocusSession?
    @State private var showAllTodaySessions = false
    @State private var showYesterdaySessions = false
    @State private var showAllYesterdaySessions = false

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            if viewModel.isLoading {
                LoadingView(message: "dashboard.loading".localized)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            headerSection
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.top, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.xl)

                            // Level Widget (Hero)
                            levelSection
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.xl)

                            // Adaptive CTA - Most important action
                            adaptiveCTASection
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.xl)

                            // Quick Stats Row
                            quickStatsSection
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.xl)

                            // Quick FireMode Button
                            quickFireModeSection
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.xl)

                            // Section Divider for Morning Intentions
                            if viewModel.hasMorningCheckIn {
                                sectionDivider(title: "dashboard.todays_intentions".localized)
                                    .id(DashboardSection.intentions)

                                // Morning Intentions
                                morningIntentionsSection
                                    .padding(.horizontal, SpacingTokens.lg)
                                    .padding(.bottom, SpacingTokens.xl)
                            }

                            // Section Divider
                            sectionDivider(title: "dashboard.daily_habits".localized)
                                .id(DashboardSection.rituals)

                            // Daily Rituals
                            ritualsSection
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.xl)

                            // Section Divider for Reflections
                            if viewModel.hasReflection {
                                sectionDivider(title: "dashboard.evening_reflection".localized)
                                    .id(DashboardSection.reflection)

                                // Daily Reflection
                                reflectionSection
                                    .padding(.horizontal, SpacingTokens.lg)
                                    .padding(.bottom, SpacingTokens.xl)
                            }

                            // Section Divider for Week Sessions
                            if !viewModel.thisWeekSessions.isEmpty {
                                sectionDivider(title: "\("dashboard.sessions_this_week".localized) (\(viewModel.weekRangeString))")
                                    .id(DashboardSection.sessions)

                                // Week Sessions grouped by day
                                weekSessionsSection
                                    .padding(.horizontal, SpacingTokens.lg)
                                    .padding(.bottom, SpacingTokens.xl)
                            }

                            // Motivational Message
                            motivationalSection
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.xxl)
                        }
                    }
                    .refreshable {
                        await viewModel.refreshDashboard()
                    }
                    .onChange(of: router.dashboardScrollTarget) { _, target in
                        if let section = target {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollProxy.scrollTo(section, anchor: .top)
                            }
                            // Clear the target after scrolling
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                router.dashboardScrollTarget = nil
                            }
                        }
                    }
                }
            }

            // Full screen celebration overlay
            if showCelebration {
                FullScreenCelebration(
                    completedCount: celebrationCount,
                    totalCount: viewModel.totalRitualsCount,
                    isShowing: $showCelebration
                )
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showFireModeModal) {
            StartFireModeSheet(
                quests: viewModel.quests,
                onStart: { duration, questId, description in
                    showFireModeModal = false
                    router.navigateToFireMode(duration: duration, questId: questId, description: description)
                }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Section Divider
    private func sectionDivider(title: String) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Rectangle()
                .fill(ColorTokens.border)
                .frame(height: 1)

            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ColorTokens.textMuted)
                .tracking(1.2)

            Rectangle()
                .fill(ColorTokens.border)
                .frame(height: 1)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.lg)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("🔥")
                    .font(.system(size: 28))

                Text("dashboard.title".localized)
                    .label()
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                if let user = viewModel.user {
                    Button(action: {
                        showProfileSheet = true
                    }) {
                        AvatarView(name: user.name, avatarURL: user.avatarURL, size: 40)
                    }
                }
            }

            Text("dashboard.subtitle".localized)
                .caption()
                .foregroundColor(ColorTokens.textSecondary)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfilePhotoSheet(
                user: viewModel.user,
                selectedPhotoItem: $selectedPhotoItem,
                isUploading: $isUploadingPhoto,
                onPhotoSelected: { image in
                    Task {
                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                            await viewModel.uploadAvatar(imageData: imageData)
                        }
                    }
                },
                onDeletePhoto: {
                    Task {
                        await viewModel.deleteAvatar()
                    }
                },
                onEditProfile: {
                    showEditProfile = true
                },
                onTakeSelfie: {
                    showCamera = true
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(
                user: viewModel.user,
                onSave: { pseudo, firstName, lastName, gender, age, description, hobbies, lifeGoal in
                    Task {
                        await viewModel.updateProfile(
                            pseudo: pseudo,
                            firstName: firstName,
                            lastName: lastName,
                            gender: gender,
                            age: age,
                            description: description,
                            hobbies: hobbies,
                            lifeGoal: lifeGoal
                        )
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            ZStack {
                Color.black.ignoresSafeArea()
                CameraPicker(image: $selectedImage)
            }
        }
        .fullScreenCover(isPresented: $showImageEditor) {
            if let image = selectedImage {
                ImageEditorSheet(image: image) { croppedImage in
                    Task {
                        isUploadingPhoto = true
                        if let imageData = croppedImage.jpegData(compressionQuality: 0.8) {
                            await viewModel.uploadAvatar(imageData: imageData)
                        }
                        isUploadingPhoto = false
                        selectedImage = nil
                    }
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let newValue = newValue,
                   let data = try? await newValue.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                    showImageEditor = true
                    selectedPhotoItem = nil
                }
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            // When camera captures an image, show the editor
            if newImage != nil && !showCamera {
                showImageEditor = true
            }
        }
    }

    // MARK: - Level Section
    private var levelSection: some View {
        VStack(spacing: SpacingTokens.md) {
            if let user = viewModel.user {
                LevelBadge(
                    level: user.level,
                    progress: viewModel.levelProgress,
                    size: 140
                )

                Text("\(Int(viewModel.levelProgress * 100))% to next level")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)

                Text("Your flame grows.")
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.lg)
    }

    // MARK: - Adaptive CTA Section
    private var adaptiveCTASection: some View {
        let cta = viewModel.adaptiveCTA

        return ActionCard(
            title: cta.title,
            subtitle: cta.subtitle,
            icon: cta.icon,
            buttonTitle: cta.buttonTitle,
            isCompleted: cta.isCompleted,
            action: {
                handleCTAAction(cta)
            }
        )
    }

    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        HStack(spacing: SpacingTokens.md) {
            // Streak
            QuickStatCard(
                icon: "🔥",
                value: "\(viewModel.currentStreak)",
                label: "dashboard.day_streak".localized,
                color: ColorTokens.primaryStart
            )

            // Today's Focus
            QuickStatCard(
                icon: "⏱️",
                value: "\(viewModel.focusedMinutesToday)m",
                label: "dashboard.focused_today".localized,
                color: Color.blue
            )

            // Rituals Done
            QuickStatCard(
                icon: "✅",
                value: "\(viewModel.completedRitualsCount)/\(viewModel.totalRitualsCount)",
                label: "stats.routines".localized,
                color: ColorTokens.success
            )
        }
    }

    // MARK: - Quick FireMode Section
    private var quickFireModeSection: some View {
        Button(action: {
            // Preload quests before showing modal
            Task {
                await FocusAppStore.shared.loadQuestsIfNeeded()
            }
            showFireModeModal = true
        }) {
            HStack(spacing: SpacingTokens.md) {
                // Fire icon with glow effect
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [ColorTokens.primaryStart.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)

                    Text("🔥")
                        .font(.system(size: 32))
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("fire.start_firemode".localized)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("fire.launch_session".localized)
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(RadiusTokens.full)
            }
            .padding(SpacingTokens.lg)
            .background(
                LinearGradient(
                    colors: [ColorTokens.surface, ColorTokens.primarySoft.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(RadiusTokens.lg)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .stroke(ColorTokens.primaryStart.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Rituals Section
    private var ritualsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            // Header with progress
            HStack {
                Text("routines.title".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                // Progress indicator
                if !viewModel.todaysRituals.isEmpty {
                    Text("\(viewModel.completedRitualsCount)/\(viewModel.totalRitualsCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.primaryStart)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xs)
                        .background(ColorTokens.primarySoft)
                        .cornerRadius(RadiusTokens.full)
                }

                Button(action: {
                    router.dashboardPath.append(NavigationDestination.manageRituals)
                }) {
                    Text("common.manage".localized)
                        .bodyText()
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }

            if viewModel.todaysRituals.isEmpty {
                EmptyStateView(
                    icon: "✨",
                    title: "routines.no_routines".localized,
                    subtitle: "routines.no_routines_hint".localized,
                    actionTitle: "routines.add_routine".localized,
                    action: {
                        router.dashboardPath.append(NavigationDestination.manageRituals)
                    }
                )
            } else {
                VStack(spacing: SpacingTokens.sm) {
                    ForEach(viewModel.todaysRituals) { ritual in
                        SwipeableRitualCard(
                            ritual: ritual,
                            completedCount: viewModel.completedRitualsCount,
                            totalCount: viewModel.totalRitualsCount,
                            onComplete: {
                                Task {
                                    await viewModel.toggleRitual(ritual)
                                }
                            },
                            onUndo: {
                                Task {
                                    await viewModel.toggleRitual(ritual)
                                }
                            },
                            onCelebrate: {
                                // Calculate count at the moment of celebration
                                let newCount = viewModel.todaysRituals.filter { $0.isCompleted }.count + 1
                                celebrationCount = newCount
                                showCelebration = true
                            }
                        )
                    }
                }

                // Swipe hint for first-time users
                if viewModel.completedRitualsCount == 0 {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 12))
                        Text("routines.swipe_hint".localized)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ColorTokens.textMuted)
                    .padding(.top, SpacingTokens.xs)
                }
            }
        }
    }

    // MARK: - Morning Intentions Section
    private var morningIntentionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            // Header with feeling
            HStack {
                if let feeling = viewModel.morningFeeling {
                    Text(feeling.rawValue)
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("start_day.feeling".localized + " \(feeling.label.lowercased())")
                            .subtitle()
                            .foregroundColor(ColorTokens.textPrimary)
                        Text("start_day.focus_areas".localized)
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                    }
                } else {
                    Text("🎯")
                        .font(.system(size: 28))
                    Text("dashboard.todays_intentions".localized)
                        .subtitle()
                        .foregroundColor(ColorTokens.textPrimary)
                }
                Spacer()

                Button(action: {
                    router.navigateToStartTheDay()
                }) {
                    Text("common.edit".localized)
                        .caption()
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }

            // Intentions list
            VStack(spacing: SpacingTokens.sm) {
                ForEach(viewModel.morningIntentions) { intention in
                    IntentionCard(intention: intention)
                }
            }
        }
    }

    // MARK: - Reflection Section
    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            // Header with edit action
            SectionHeader(
                title: "end_day.daily_rituals".localized,
                action: {
                    router.navigateToEndOfDay()
                },
                actionTitle: "common.edit".localized
            )

            // Reflection cards
            VStack(spacing: SpacingTokens.sm) {
                if let biggestWin = viewModel.reflectionBiggestWin, !biggestWin.isEmpty {
                    ReflectionCard(emoji: "🏆", title: "end_day.biggest_win".localized, content: biggestWin)
                }

                if let bestMoment = viewModel.reflectionBestMoment, !bestMoment.isEmpty {
                    ReflectionCard(emoji: "✨", title: "end_day.best_moment".localized, content: bestMoment)
                }

                if let tomorrowGoal = viewModel.reflectionTomorrowGoal, !tomorrowGoal.isEmpty {
                    ReflectionCard(emoji: "🎯", title: "end_day.tomorrow_goal".localized, content: tomorrowGoal, highlighted: true)
                }
            }
        }
    }

    // MARK: - Week Sessions Section
    private var weekSessionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            // Header with stats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("stats.focus_sessions".localized)
                        .subtitle()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Text("\(viewModel.totalSessionsThisWeek) \("crew.sessions".localized) · \(viewModel.totalActualMinutesThisWeek)m total")
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()

                Button(action: {
                    router.navigateToFireMode()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("common.new".localized)
                    }
                    .caption()
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }

            // Sessions grouped by day with collapsible sections
            VStack(spacing: SpacingTokens.lg) {
                ForEach(viewModel.sessionsByDay, id: \.date) { dayGroup in
                    let isToday = Calendar.current.isDateInToday(dayGroup.date)
                    let isYesterday = Calendar.current.isDateInYesterday(dayGroup.date)

                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        // Day header (clickable for Yesterday and older)
                        if isToday {
                            // Today: always visible header
                            Text(formatDayHeader(dayGroup.date))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTokens.textMuted)
                                .textCase(.uppercase)
                        } else {
                            // Yesterday & older: collapsible header
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isYesterday {
                                        showYesterdaySessions.toggle()
                                    }
                                }
                            }) {
                                HStack {
                                    Text(formatDayHeader(dayGroup.date))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(ColorTokens.textMuted)
                                        .textCase(.uppercase)

                                    Text("(\(dayGroup.sessions.count))")
                                        .font(.system(size: 12))
                                        .foregroundColor(ColorTokens.textMuted)

                                    Spacer()

                                    Image(systemName: (isYesterday && showYesterdaySessions) ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(ColorTokens.textMuted)
                                }
                            }
                        }

                        // Sessions for this day
                        if isToday {
                            // Today: show first 3, then "See more"
                            let sessionsToShow = showAllTodaySessions ? dayGroup.sessions : Array(dayGroup.sessions.prefix(3))

                            ForEach(sessionsToShow) { session in
                                SwipeableSessionCard(
                                    session: session,
                                    onEdit: {
                                        sessionToEdit = session
                                        showEditSession = true
                                    },
                                    onDelete: {
                                        sessionToDelete = session
                                        showDeleteSessionConfirm = true
                                    }
                                )
                            }

                            // "See more" button if more than 3 sessions
                            if dayGroup.sessions.count > 3 {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showAllTodaySessions.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text(showAllTodaySessions ? "common.show_less".localized : "common.see_more".localized(with: dayGroup.sessions.count - 3))
                                            .font(.system(size: 13, weight: .medium))
                                        Image(systemName: showAllTodaySessions ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(ColorTokens.primaryStart)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SpacingTokens.sm)
                                }
                            }
                        } else if isYesterday && showYesterdaySessions {
                            // Yesterday: collapsible, show first 3, then "See more"
                            let sessionsToShow = showAllYesterdaySessions ? dayGroup.sessions : Array(dayGroup.sessions.prefix(3))

                            ForEach(sessionsToShow) { session in
                                SwipeableSessionCard(
                                    session: session,
                                    onEdit: {
                                        sessionToEdit = session
                                        showEditSession = true
                                    },
                                    onDelete: {
                                        sessionToDelete = session
                                        showDeleteSessionConfirm = true
                                    }
                                )
                            }

                            // "See more" button if more than 3 sessions
                            if dayGroup.sessions.count > 3 {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showAllYesterdaySessions.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text(showAllYesterdaySessions ? "common.show_less".localized : "common.see_more".localized(with: dayGroup.sessions.count - 3))
                                            .font(.system(size: 13, weight: .medium))
                                        Image(systemName: showAllYesterdaySessions ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(ColorTokens.primaryStart)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SpacingTokens.sm)
                                }
                            }
                        }
                        // Older days are hidden (only Today and Yesterday shown)
                    }
                }
            }

            // Swipe hint for first-time users
            if viewModel.thisWeekSessions.count > 0 && viewModel.thisWeekSessions.count <= 3 {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 12))
                    Text("dashboard.swipe_hint".localized)
                        .font(.system(size: 12))
                }
                .foregroundColor(ColorTokens.textMuted)
                .padding(.top, SpacingTokens.xs)
            }
        }
        .sheet(isPresented: $showEditSession) {
            if let session = sessionToEdit {
                EditSessionSheet(
                    session: session,
                    onSave: { description, duration in
                        Task {
                            await viewModel.editSession(id: session.id, description: description, durationMinutes: duration)
                        }
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteSession(id: session.id)
                        }
                    }
                )
            }
        }
        .alert("fire.delete_session".localized, isPresented: $showDeleteSessionConfirm) {
            Button("common.cancel".localized, role: .cancel) {
                sessionToDelete = nil
            }
            Button("common.delete".localized, role: .destructive) {
                if let session = sessionToDelete {
                    Task {
                        await viewModel.deleteSession(id: session.id)
                    }
                }
                sessionToDelete = nil
            }
        } message: {
            Text("fire.delete_session_confirm".localized)
        }
    }

    private func formatDayHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "time.today".localized
        } else if calendar.isDateInYesterday(date) {
            return "time.yesterday".localized
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, d MMM"
            return formatter.string(from: date)
        }
    }

    // MARK: - Motivational Section
    private var motivationalSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            Text("dashboard.motivational".localized)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .italic()
        }
        .padding(.vertical, SpacingTokens.xl)
    }

    // MARK: - Actions
    private func handleCTAAction(_ cta: AdaptiveCTA) {
        switch cta {
        case .startTheDay:
            router.navigateToStartTheDay()
        case .startFireMode:
            // Preload quests before navigating
            Task {
                await FocusAppStore.shared.loadQuestsIfNeeded()
            }
            router.navigateToFireMode()
        case .endOfDay:
            router.navigateToEndOfDay()
        case .allCompleted:
            // Already completed - could show stats
            break
        }
    }
}

// MARK: - Intention Card
struct IntentionCard: View {
    let intention: DailyIntention

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Area emoji
            Text(intention.area.emoji)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
                .background(Color(hex: intention.area.color).opacity(0.15))
                .cornerRadius(RadiusTokens.sm)

            // Intention text
            VStack(alignment: .leading, spacing: 2) {
                Text(intention.intention)
                    .bodyText()
                    .foregroundColor(intention.isCompleted ? ColorTokens.textMuted : ColorTokens.textPrimary)
                    .strikethrough(intention.isCompleted)
                    .lineLimit(2)

                Text(intention.area.rawValue)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            Spacer()

            // Completion indicator
            if intention.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ColorTokens.success)
                    .font(.system(size: 20))
            }
        }
        .padding(SpacingTokens.md)
        .background(intention.isCompleted ? ColorTokens.success.opacity(0.1) : ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .stroke(intention.isCompleted ? ColorTokens.success.opacity(0.3) : ColorTokens.border, lineWidth: 1)
        )
    }
}

// MARK: - Reflection Card
struct ReflectionCard: View {
    let emoji: String
    let title: String
    let content: String
    var highlighted: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.md) {
            Text(emoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text(title)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)

                Text(content)
                    .bodyText()
                    .foregroundColor(ColorTokens.textPrimary)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(SpacingTokens.md)
        .background(highlighted ? ColorTokens.primarySoft : ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .stroke(highlighted ? ColorTokens.primaryStart.opacity(0.3) : ColorTokens.border, lineWidth: 1)
        )
    }
}

// MARK: - Session Card
struct SessionCard: View {
    let session: FocusSession

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Time indicator
            VStack(alignment: .center, spacing: 2) {
                Text(timeFormatter.string(from: session.startTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorTokens.textSecondary)

                Rectangle()
                    .fill(ColorTokens.primaryStart)
                    .frame(width: 2, height: 16)
                    .cornerRadius(1)

                Text(session.formattedActualDuration)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ColorTokens.primaryStart)
            }
            .frame(width: 44)

            // Session details
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                if let description = session.description, !description.isEmpty {
                    Text(description)
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)
                        .lineLimit(2)
                } else {
                    Text("Focus session")
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                        .italic()
                }

                HStack(spacing: SpacingTokens.sm) {
                    // Duration badge - shows actual duration
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text(session.formattedActualDuration)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, 4)
                    .background(ColorTokens.primarySoft)
                    .cornerRadius(RadiusTokens.sm)

                    if session.isManuallyLogged {
                        Text("Manual")
                            .font(.system(size: 10))
                            .foregroundColor(ColorTokens.textMuted)
                            .padding(.horizontal, SpacingTokens.xs)
                            .padding(.vertical, 2)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.sm)
                    }
                }
            }

            Spacer()
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }
}

// MARK: - Day Timeline View (24h visualization)
struct DayTimelineView: View {
    let sessions: [FocusSession]
    let date: Date

    // Hours to show (6am to midnight by default)
    private let startHour = 6
    private let endHour = 24

    private var hoursRange: Int {
        endHour - startHour
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            // Day header
            HStack {
                Text(formatDayLabel(date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text("\(totalMinutes)m")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorTokens.primaryStart)
            }

            // Timeline bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.surface)
                        .frame(height: 24)

                    // Hour markers
                    HStack(spacing: 0) {
                        ForEach(0..<hoursRange, id: \.self) { i in
                            Rectangle()
                                .fill(ColorTokens.border.opacity(0.5))
                                .frame(width: 1, height: 12)
                            if i < hoursRange - 1 {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 24)
                    .padding(.horizontal, 2)

                    // Session blocks
                    ForEach(sessions) { session in
                        sessionBlock(session: session, totalWidth: geometry.size.width)
                    }
                }
            }
            .frame(height: 24)

            // Time labels
            HStack {
                Text("\(startHour):00")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                Text("12:00")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                Text("18:00")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                Text("24:00")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(ColorTokens.textMuted)
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.background)
        .cornerRadius(RadiusTokens.md)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }

    private func sessionBlock(session: FocusSession, totalWidth: CGFloat) -> some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: session.startTime)
        let minute = calendar.component(.minute, from: session.startTime)

        // Calculate position (where session starts)
        let startMinutes = (hour - startHour) * 60 + minute
        let totalMinutesInDay = hoursRange * 60
        let startPosition = max(0, CGFloat(startMinutes) / CGFloat(totalMinutesInDay))

        // Calculate width (duration)
        let durationMinutes = session.actualDurationMinutes
        let widthRatio = min(1.0 - startPosition, CGFloat(durationMinutes) / CGFloat(totalMinutesInDay))

        // Only show if within visible hours
        guard hour >= startHour && hour < endHour else {
            return AnyView(EmptyView())
        }

        return AnyView(
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(4, totalWidth * widthRatio), height: 20)
                .offset(x: totalWidth * startPosition)
                .shadow(color: ColorTokens.primaryStart.opacity(0.3), radius: 2, x: 0, y: 1)
        )
    }

    private var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.actualDurationMinutes }
    }

    private func formatDayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Start FireMode Sheet (3-Step Modal)
struct StartFireModeSheet: View {
    let quests: [Quest]
    let onStart: (Int, String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    // Step 1: Duration
    @State private var selectedDuration: Int = 25
    let durationOptions = [15, 25, 45, 60, 90]

    // Step 2: Quest
    @State private var selectedQuestId: String?

    // Step 3: Description
    @State private var focusDescription: String = ""
    @FocusState private var isDescriptionFocused: Bool

    // Current step
    @State private var currentStep: Int = 1

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: SpacingTokens.sm) {
                    ForEach(1...3, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? ColorTokens.primaryStart : ColorTokens.surface)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, SpacingTokens.md)

                // Step content
                TabView(selection: $currentStep) {
                    // Step 1: Choose Duration
                    step1DurationView
                        .tag(1)

                    // Step 2: Link to Quest
                    step2QuestView
                        .tag(2)

                    // Step 3: Description
                    step3DescriptionView
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                // Navigation buttons
                HStack(spacing: SpacingTokens.md) {
                    if currentStep > 1 {
                        Button(action: {
                            withAnimation { currentStep -= 1 }
                        }) {
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SpacingTokens.md)
                                .background(ColorTokens.surface)
                                .foregroundColor(ColorTokens.textPrimary)
                                .cornerRadius(RadiusTokens.md)
                        }
                    }

                    Button(action: {
                        if currentStep < 3 {
                            withAnimation { currentStep += 1 }
                        } else {
                            // Start focus session
                            onStart(selectedDuration, selectedQuestId, focusDescription.isEmpty ? nil : focusDescription)
                        }
                    }) {
                        Text(currentStep < 3 ? "Next" : "Start Focus")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SpacingTokens.md)
                            .background(ColorTokens.fireGradient)
                            .foregroundColor(.white)
                            .cornerRadius(RadiusTokens.md)
                    }
                }
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.bottom, SpacingTokens.xl)
            }
            .background(ColorTokens.background)
            .navigationTitle("Start FireMode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }
            }
        }
    }

    // MARK: - Step 1: Duration
    private var step1DurationView: some View {
        VStack(spacing: SpacingTokens.xl) {
            Spacer()

            Text("🔥")
                .font(.system(size: 64))

            Text("How long will you focus?")
                .heading2()
                .foregroundColor(ColorTokens.textPrimary)

            Text("Choose your focus duration")
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)

            // Duration picker
            HStack(spacing: SpacingTokens.sm) {
                ForEach(durationOptions, id: \.self) { duration in
                    Button(action: {
                        selectedDuration = duration
                    }) {
                        VStack(spacing: SpacingTokens.xs) {
                            Text("\(duration)")
                                .font(.system(size: 24, weight: .bold))
                            Text("min")
                                .font(.system(size: 12))
                        }
                        .frame(width: 60, height: 70)
                        .background(
                            selectedDuration == duration
                                ? ColorTokens.fireGradient
                                : LinearGradient(colors: [ColorTokens.surface, ColorTokens.surface], startPoint: .top, endPoint: .bottom)
                        )
                        .foregroundColor(selectedDuration == duration ? .white : ColorTokens.textPrimary)
                        .cornerRadius(RadiusTokens.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md)
                                .stroke(selectedDuration == duration ? Color.clear : ColorTokens.border, lineWidth: 1)
                        )
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.lg)
    }

    // MARK: - Step 2: Quest Link
    private var step2QuestView: some View {
        VStack(spacing: SpacingTokens.xl) {
            Spacer()

            Text("🎯")
                .font(.system(size: 64))

            Text("Link to a Quest")
                .heading2()
                .foregroundColor(ColorTokens.textPrimary)

            Text("Optional: Track this session under a quest")
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            // Quest list
            ScrollView {
                VStack(spacing: SpacingTokens.sm) {
                    // None option
                    Button(action: {
                        selectedQuestId = nil
                    }) {
                        HStack {
                            Text("No quest")
                                .foregroundColor(ColorTokens.textPrimary)
                            Spacer()
                            if selectedQuestId == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ColorTokens.primaryStart)
                            }
                        }
                        .padding(SpacingTokens.md)
                        .background(selectedQuestId == nil ? ColorTokens.primarySoft : ColorTokens.surface)
                        .cornerRadius(RadiusTokens.md)
                    }

                    ForEach(quests.filter { $0.status == .active }) { quest in
                        Button(action: {
                            selectedQuestId = quest.id
                        }) {
                            HStack {
                                Text(quest.area.emoji)
                                Text(quest.title)
                                    .foregroundColor(ColorTokens.textPrimary)
                                Spacer()
                                if selectedQuestId == quest.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(ColorTokens.primaryStart)
                                }
                            }
                            .padding(SpacingTokens.md)
                            .background(selectedQuestId == quest.id ? ColorTokens.primarySoft : ColorTokens.surface)
                            .cornerRadius(RadiusTokens.md)
                        }
                    }
                }
            }
            .frame(maxHeight: 250)

            // Skip button
            Button(action: {
                selectedQuestId = nil
                withAnimation { currentStep += 1 }
            }) {
                Text("Skip")
                    .foregroundColor(ColorTokens.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.lg)
    }

    // MARK: - Step 3: Description
    private var step3DescriptionView: some View {
        VStack(spacing: SpacingTokens.xl) {
            Spacer()

            Text("✍️")
                .font(.system(size: 64))

            Text("What will you work on?")
                .heading2()
                .foregroundColor(ColorTokens.textPrimary)

            Text("Describe your focus intention")
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)

            // Description input
            TextField("e.g., Finish the report, Study chapter 5...", text: $focusDescription, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
                .lineLimit(3...5)
                .focused($isDescriptionFocused)

            // Summary
            VStack(spacing: SpacingTokens.sm) {
                HStack {
                    Text("Duration:")
                        .foregroundColor(ColorTokens.textMuted)
                    Spacer()
                    Text("\(selectedDuration) minutes")
                        .foregroundColor(ColorTokens.textPrimary)
                        .fontWeight(.medium)
                }

                if let questId = selectedQuestId,
                   let quest = quests.first(where: { $0.id == questId }) {
                    HStack {
                        Text("Quest:")
                            .foregroundColor(ColorTokens.textMuted)
                        Spacer()
                        Text("\(quest.area.emoji) \(quest.title)")
                            .foregroundColor(ColorTokens.textPrimary)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface.opacity(0.5))
            .cornerRadius(RadiusTokens.md)

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.lg)
        .onTapGesture {
            isDescriptionFocused = false
        }
    }
}

// MARK: - Profile Photo Sheet
struct ProfilePhotoSheet: View {
    let user: User?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isUploading: Bool
    let onPhotoSelected: (UIImage) -> Void
    let onDeletePhoto: () -> Void
    let onEditProfile: () -> Void
    let onTakeSelfie: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: SpacingTokens.xl) {
                // Current avatar preview
                if let user = user {
                    AvatarView(name: user.name, avatarURL: user.avatarURL, size: 120)
                        .overlay(
                            Group {
                                if isUploading {
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 120, height: 120)
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                }
                            }
                        )

                    Text(user.name)
                        .subtitle()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)

                    if let desc = user.description, !desc.isEmpty {
                        Text(desc)
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(spacing: SpacingTokens.md) {
                    // Edit Profile button
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onEditProfile()
                        }
                    }) {
                        HStack(spacing: SpacingTokens.sm) {
                            Image(systemName: "pencil")
                            Text("Edit Profile")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.md)
                        .background(ColorTokens.primaryStart)
                        .foregroundColor(.white)
                        .cornerRadius(RadiusTokens.md)
                    }

                    // Photo options in a row
                    HStack(spacing: SpacingTokens.md) {
                        // Take Selfie button
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onTakeSelfie()
                            }
                        }) {
                            HStack(spacing: SpacingTokens.sm) {
                                Image(systemName: "camera")
                                Text("Selfie")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SpacingTokens.md)
                            .background(ColorTokens.surface)
                            .foregroundColor(ColorTokens.textPrimary)
                            .cornerRadius(RadiusTokens.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.md)
                                    .stroke(ColorTokens.border, lineWidth: 1)
                            )
                        }
                        .disabled(isUploading)

                        // Photo picker button
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: SpacingTokens.sm) {
                                Image(systemName: "photo")
                                Text("Gallery")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SpacingTokens.md)
                            .background(ColorTokens.surface)
                            .foregroundColor(ColorTokens.textPrimary)
                            .cornerRadius(RadiusTokens.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.md)
                                    .stroke(ColorTokens.border, lineWidth: 1)
                            )
                        }
                        .disabled(isUploading)
                    }

                    // Delete photo button (only show if user has avatar)
                    if user?.avatarURL != nil {
                        Button(action: {
                            onDeletePhoto()
                            dismiss()
                        }) {
                            HStack(spacing: SpacingTokens.sm) {
                                Image(systemName: "trash")
                                Text("Remove Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SpacingTokens.md)
                            .background(ColorTokens.surface)
                            .foregroundColor(ColorTokens.error)
                            .cornerRadius(RadiusTokens.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.md)
                                    .stroke(ColorTokens.error.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(isUploading)
                    }
                }
                .padding(.horizontal, SpacingTokens.lg)

                // Language Setting
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    HStack {
                        Text("🌐")
                            .font(.system(size: 20))
                        Text("profile.language".localized)
                            .bodyText()
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textPrimary)
                    }
                    .padding(.horizontal, SpacingTokens.lg)

                    // Language options
                    VStack(spacing: SpacingTokens.sm) {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                LocalizationManager.shared.currentLanguage = language
                            } label: {
                                HStack {
                                    Text(language.flag)
                                        .font(.system(size: 20))

                                    Text(language.displayName)
                                        .bodyText()
                                        .foregroundColor(LocalizationManager.shared.currentLanguage == language ? ColorTokens.textPrimary : ColorTokens.textSecondary)

                                    Spacer()

                                    if LocalizationManager.shared.currentLanguage == language {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(ColorTokens.primaryStart)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(ColorTokens.textMuted)
                                    }
                                }
                                .padding(SpacingTokens.sm)
                                .background(LocalizationManager.shared.currentLanguage == language ? ColorTokens.primarySoft : Color.clear)
                                .cornerRadius(RadiusTokens.sm)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, SpacingTokens.lg)
                }
                .padding(.top, SpacingTokens.md)

                Spacer()
            }
            .padding(.top, SpacingTokens.xl)
            .background(ColorTokens.background)
            .navigationTitle("profile.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
    }
}

// MARK: - Image Editor Sheet (Zoom/Crop)
struct ImageEditorSheet: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 280

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    // Image with gestures
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSize * scale, height: cropSize * scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        let newScale = scale * delta
                                        scale = min(max(newScale, 1.0), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .clipShape(Circle())
                        .frame(width: cropSize, height: cropSize)

                    // Overlay mask
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .mask(
                            ZStack {
                                Rectangle()
                                Circle()
                                    .frame(width: cropSize, height: cropSize)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        )
                        .allowsHitTesting(false)

                    // Circle border
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropSize, height: cropSize)
                        .allowsHitTesting(false)

                    // Instructions
                    VStack {
                        Spacer()
                        Text("Pinch to zoom • Drag to move")
                            .caption()
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Adjust Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let croppedImage = cropImage()
                        onSave(croppedImage)
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func cropImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        return renderer.image { context in
            // Create circular clipping path
            let rect = CGRect(x: 0, y: 0, width: cropSize, height: cropSize)
            UIBezierPath(ovalIn: rect).addClip()

            // Calculate the scaled and offset image rect
            let imageSize = CGSize(width: cropSize * scale, height: cropSize * scale)
            let imageRect = CGRect(
                x: (cropSize - imageSize.width) / 2 + offset.width,
                y: (cropSize - imageSize.height) / 2 + offset.height,
                width: imageSize.width,
                height: imageSize.height
            )

            image.draw(in: imageRect)
        }
    }
}

// MARK: - Camera Picker (for Selfie)
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo

        // Use front camera if available
        if UIImagePickerController.isCameraDeviceAvailable(.front) {
            picker.cameraDevice = .front
        }
        picker.allowsEditing = false

        // Hide default controls and add custom overlay
        picker.showsCameraControls = false

        // Create custom overlay with capture button
        let overlayView = CameraOverlayView(frame: UIScreen.main.bounds)
        overlayView.picker = picker
        overlayView.onCapture = {
            picker.takePicture()
        }
        overlayView.onCancel = {
            picker.delegate?.imagePickerControllerDidCancel?(picker)
        }
        overlayView.onFlipCamera = {
            picker.cameraDevice = picker.cameraDevice == .front ? .rear : .front
        }
        picker.cameraOverlayView = overlayView

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Custom Camera Overlay
class CameraOverlayView: UIView {
    weak var picker: UIImagePickerController?
    var onCapture: (() -> Void)?
    var onCancel: (() -> Void)?
    var onFlipCamera: (() -> Void)?

    // Bottom control bar background
    private let bottomBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        return view
    }()

    // Circular frame guide overlay
    private let circleGuide: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        view.layer.borderWidth = 2
        view.isUserInteractionEnabled = false
        return view
    }()

    private let captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Outer ring
        let outerRing = UIView()
        outerRing.translatesAutoresizingMaskIntoConstraints = false
        outerRing.backgroundColor = .clear
        outerRing.layer.borderColor = UIColor.white.cgColor
        outerRing.layer.borderWidth = 5
        outerRing.layer.cornerRadius = 40
        outerRing.isUserInteractionEnabled = false
        button.addSubview(outerRing)

        // Inner circle
        let innerCircle = UIView()
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 32
        innerCircle.isUserInteractionEnabled = false
        button.addSubview(innerCircle)

        NSLayoutConstraint.activate([
            outerRing.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            outerRing.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            outerRing.widthAnchor.constraint(equalToConstant: 80),
            outerRing.heightAnchor.constraint(equalToConstant: 80),

            innerCircle.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 64),
            innerCircle.heightAnchor.constraint(equalToConstant: 64),
        ])

        return button
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        return button
    }()

    private let flipButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        button.setImage(UIImage(systemName: "camera.rotate.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 25
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Make circle guide round
        circleGuide.layer.cornerRadius = circleGuide.bounds.width / 2
    }

    private func setupUI() {
        backgroundColor = .clear

        addSubview(circleGuide)
        addSubview(bottomBar)
        addSubview(captureButton)
        addSubview(cancelButton)
        addSubview(flipButton)

        let screenWidth = UIScreen.main.bounds.width
        let circleSize = screenWidth * 0.75 // 75% of screen width

        NSLayoutConstraint.activate([
            // Circle guide in center of screen
            circleGuide.centerXAnchor.constraint(equalTo: centerXAnchor),
            circleGuide.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -100),
            circleGuide.widthAnchor.constraint(equalToConstant: circleSize),
            circleGuide.heightAnchor.constraint(equalToConstant: circleSize),

            // Bottom bar - taller to push buttons higher
            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 220),

            // Capture button higher in bottom bar
            captureButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            captureButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 40),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 80),

            // Cancel button at left
            cancelButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            cancelButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),

            // Flip camera button at right
            flipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            flipButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            flipButton.widthAnchor.constraint(equalToConstant: 50),
            flipButton.heightAnchor.constraint(equalToConstant: 50),
        ])

        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        flipButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)
    }

    @objc private func captureTapped() {
        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = .identity
            }
        }
        onCapture?()
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    @objc private func flipTapped() {
        // Animate flip
        UIView.animate(withDuration: 0.15, animations: {
            self.flipButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                self.flipButton.transform = .identity
            }
        }
        onFlipCamera?()
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileSheet: View {
    let user: User?
    let onSave: (String?, String?, String?, String?, Int?, String?, String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var pseudo: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var gender: String = ""
    @State private var ageString: String = ""
    @State private var description: String = ""
    @State private var hobbies: String = ""
    @State private var lifeGoal: String = ""
    @State private var isSaving = false

    let genderOptions = ["", "male", "female", "other", "prefer_not_to_say"]
    let genderLabels = ["Not specified", "Male", "Female", "Other", "Prefer not to say"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: SpacingTokens.lg) {
                    // Pseudo (Display Name)
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Display Name")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                        CustomTextField(placeholder: "How you want to be called", text: $pseudo)
                    }

                    // First Name & Last Name
                    HStack(spacing: SpacingTokens.md) {
                        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                            Text("First Name")
                                .caption()
                                .foregroundColor(ColorTokens.textMuted)
                            CustomTextField(placeholder: "First name", text: $firstName)
                        }

                        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                            Text("Last Name")
                                .caption()
                                .foregroundColor(ColorTokens.textMuted)
                            CustomTextField(placeholder: "Last name", text: $lastName)
                        }
                    }

                    // Gender
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Gender")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                        Menu {
                            ForEach(0..<genderOptions.count, id: \.self) { index in
                                Button(genderLabels[index]) {
                                    gender = genderOptions[index]
                                }
                            }
                        } label: {
                            HStack {
                                Text(genderLabels[genderOptions.firstIndex(of: gender) ?? 0])
                                    .foregroundColor(gender.isEmpty ? ColorTokens.textMuted : ColorTokens.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                            .padding(SpacingTokens.md)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.md)
                                    .stroke(ColorTokens.border, lineWidth: 1)
                            )
                        }
                    }

                    // Age
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Age")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                        CustomTextField(placeholder: "Your age", text: $ageString)
                            .keyboardType(.numberPad)
                    }

                    // Bio / Description
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Bio")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                        CustomTextArea(placeholder: "A short description about yourself...", text: $description, minHeight: 80)
                    }

                    // Hobbies
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Hobbies")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                        CustomTextField(placeholder: "Reading, coding, fitness...", text: $hobbies)
                    }

                    // Life Goal
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Life Goal")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                        CustomTextArea(placeholder: "What do you want to achieve in life?", text: $lifeGoal, minHeight: 80)
                    }
                }
                .padding(SpacingTokens.lg)
            }
            .background(ColorTokens.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .onAppear {
                loadUserData()
            }
        }
    }

    private func loadUserData() {
        guard let user = user else { return }
        pseudo = user.pseudo ?? ""
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        gender = user.gender ?? ""
        if let age = user.age {
            ageString = "\(age)"
        }
        description = user.description ?? ""
        hobbies = user.hobbies ?? ""
        lifeGoal = user.lifeGoal ?? ""
    }

    private func saveProfile() {
        isSaving = true

        // Convert empty strings to nil for API
        let pseudoValue = pseudo.isEmpty ? nil : pseudo
        let firstNameValue = firstName.isEmpty ? nil : firstName
        let lastNameValue = lastName.isEmpty ? nil : lastName
        let genderValue = gender.isEmpty ? nil : gender
        let ageValue = Int(ageString)
        let descriptionValue = description.isEmpty ? nil : description
        let hobbiesValue = hobbies.isEmpty ? nil : hobbies
        let lifeGoalValue = lifeGoal.isEmpty ? nil : lifeGoal

        onSave(pseudoValue, firstNameValue, lastNameValue, genderValue, ageValue, descriptionValue, hobbiesValue, lifeGoalValue)
        dismiss()
    }
}

// MARK: - Swipeable Session Card
struct SwipeableSessionCard: View {
    let session: FocusSession
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isAnimating = false
    @State private var cardScale: CGFloat = 1.0

    private let swipeThreshold: CGFloat = 80
    private let maxSwipe: CGFloat = 120

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let deleteHaptic = UINotificationFeedbackGenerator()

    private var swipeProgress: CGFloat {
        min(abs(offset) / swipeThreshold, 1.0)
    }

    private var isSwipingLeft: Bool { offset < 0 }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var body: some View {
        ZStack {
            // Background revealed on swipe
            HStack(spacing: 0) {
                Spacer()

                // Right side - Edit/Delete actions (only show when swiping left)
                if isSwipingLeft {
                    HStack(spacing: 0) {
                        // Edit button
                        ZStack {
                            ColorTokens.primaryStart
                            VStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Edit")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .scaleEffect(swipeProgress > 0.5 ? 1.0 : 0.5)
                            .opacity(swipeProgress)
                        }
                        .frame(width: 60)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                            onEdit()
                        }

                        // Delete button
                        ZStack {
                            ColorTokens.error
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Delete")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .scaleEffect(swipeProgress > 0.5 ? 1.0 : 0.5)
                            .opacity(swipeProgress)
                        }
                        .frame(width: 60)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                            onDelete()
                        }
                    }
                    .frame(width: max(0, abs(offset) + 20))
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                }
            }

            // Main card
            HStack(spacing: SpacingTokens.md) {
                // Time indicator
                VStack(alignment: .center, spacing: 2) {
                    Text(timeFormatter.string(from: session.startTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorTokens.textSecondary)

                    Rectangle()
                        .fill(ColorTokens.primaryStart)
                        .frame(width: 2, height: 16)
                        .cornerRadius(1)

                    Text(session.formattedActualDuration)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ColorTokens.primaryStart)
                }
                .frame(width: 44)

                // Session details
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    if let description = session.description, !description.isEmpty {
                        Text(description)
                            .bodyText()
                            .foregroundColor(ColorTokens.textPrimary)
                            .lineLimit(2)
                    } else {
                        Text("Focus session")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                            .italic()
                    }

                    HStack(spacing: SpacingTokens.sm) {
                        // Duration badge
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text(session.formattedActualDuration)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(ColorTokens.primaryStart)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, 4)
                        .background(ColorTokens.primarySoft)
                        .cornerRadius(RadiusTokens.sm)

                        if session.isManuallyLogged {
                            Text("Manual")
                                .font(.system(size: 10))
                                .foregroundColor(ColorTokens.textMuted)
                                .padding(.horizontal, SpacingTokens.xs)
                                .padding(.vertical, 2)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.sm)
                        }
                    }
                }

                Spacer()

                // Swipe hint
                if !isAnimating && offset == 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.3)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                    }
                    .foregroundColor(ColorTokens.textMuted)
                    .opacity(1 - swipeProgress)
                }
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(ColorTokens.border, lineWidth: 1)
            )
            .scaleEffect(cardScale)
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        guard !isAnimating else { return }
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        // Only handle horizontal swipes (not vertical scrolling)
                        // If vertical movement is greater, let ScrollView handle it
                        guard abs(horizontal) > abs(vertical) * 1.5 else { return }

                        // Only allow swiping left (negative)
                        if horizontal < 0 {
                            offset = horizontal > -maxSwipe
                                ? horizontal
                                : -maxSwipe + (horizontal + maxSwipe) * 0.3
                        }

                        if swipeProgress >= 1.0 {
                            lightHaptic.prepare()
                        }
                    }
                    .onEnded { value in
                        guard !isAnimating else { return }
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        // Only process if it was a horizontal swipe
                        guard abs(horizontal) > abs(vertical) * 1.5 else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset = 0
                            }
                            return
                        }

                        // Show actions if swiped far enough
                        if horizontal < -swipeThreshold {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset = -maxSwipe
                            }
                            lightHaptic.impactOccurred()
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if offset != 0 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        offset = 0
                    }
                }
            }
        }
        .onAppear {
            lightHaptic.prepare()
            deleteHaptic.prepare()
        }
    }
}

// MARK: - Edit Session Sheet
struct EditSessionSheet: View {
    let session: FocusSession
    let onSave: (String?, Int?) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var description: String = ""
    @State private var durationMinutes: Int = 25
    @State private var showDeleteConfirm = false

    let durationOptions = [15, 25, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: SpacingTokens.lg) {
                    // Description
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Description")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                        CustomTextArea(placeholder: "What did you work on?", text: $description, minHeight: 80)
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        Text("Duration")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)

                        // Quick select
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: SpacingTokens.sm) {
                                ForEach(durationOptions, id: \.self) { duration in
                                    Button(action: {
                                        durationMinutes = duration
                                    }) {
                                        Text("\(duration)m")
                                            .font(.system(size: 14, weight: durationMinutes == duration ? .bold : .medium))
                                            .padding(.horizontal, SpacingTokens.md)
                                            .padding(.vertical, SpacingTokens.sm)
                                            .background(
                                                durationMinutes == duration
                                                    ? ColorTokens.fireGradient
                                                    : LinearGradient(colors: [ColorTokens.surface, ColorTokens.surface], startPoint: .top, endPoint: .bottom)
                                            )
                                            .foregroundColor(durationMinutes == duration ? .white : ColorTokens.textPrimary)
                                            .cornerRadius(RadiusTokens.md)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: RadiusTokens.md)
                                                    .stroke(durationMinutes == duration ? Color.clear : ColorTokens.border, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }

                        // Custom stepper
                        HStack {
                            Button(action: {
                                if durationMinutes > 5 {
                                    durationMinutes -= 5
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(ColorTokens.textMuted)
                            }

                            Text("\(durationMinutes) minutes")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(ColorTokens.textPrimary)
                                .frame(width: 120)

                            Button(action: {
                                if durationMinutes < 180 {
                                    durationMinutes += 5
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(ColorTokens.primaryStart)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, SpacingTokens.sm)
                    }

                    // Session info
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        Text("Session Info")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)

                        HStack {
                            Text("Started at")
                                .foregroundColor(ColorTokens.textSecondary)
                            Spacer()
                            Text(formatDateTime(session.startTime))
                                .foregroundColor(ColorTokens.textPrimary)
                        }
                        .bodyText()

                        if let endTime = session.endTime {
                            HStack {
                                Text("Ended at")
                                    .foregroundColor(ColorTokens.textSecondary)
                                Spacer()
                                Text(formatDateTime(endTime))
                                    .foregroundColor(ColorTokens.textPrimary)
                            }
                            .bodyText()
                        }
                    }
                    .padding(SpacingTokens.md)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)

                    // Delete button
                    Button(action: {
                        showDeleteConfirm = true
                    }) {
                        HStack(spacing: SpacingTokens.sm) {
                            Image(systemName: "trash")
                            Text("Delete Session")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.md)
                        .background(ColorTokens.surface)
                        .foregroundColor(ColorTokens.error)
                        .cornerRadius(RadiusTokens.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md)
                                .stroke(ColorTokens.error.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(SpacingTokens.lg)
            }
            .background(ColorTokens.background)
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(description.isEmpty ? nil : description, durationMinutes)
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete Session?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete this focus session.")
            }
            .onAppear {
                description = session.description ?? ""
                durationMinutes = session.actualDurationMinutes
            }
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject(AppRouter.shared)
    }
}
