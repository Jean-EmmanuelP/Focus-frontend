import SwiftUI
import PhotosUI
import AVFoundation

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showCelebration = false
    @State private var celebrationCount = 0
    @State private var showProfileSheet = false
    @State private var showImageEditor = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploadingPhoto = false

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
                                .padding(.bottom, SpacingTokens.md)

                            // Streak Card with Progress Bar (Hero)
                            streakCardSection
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.xl)

                            // Main CTA: Start the Day OR Next Task with Focus
                            mainCTASection
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.xl)

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
    }

    // MARK: - Section Divider
    private func sectionDivider(title: String, icon: String? = nil) -> some View {
        HStack(spacing: SpacingTokens.md) {
            if let icon = icon {
                Text(icon)
                    .font(.satoshi(18))
            }

            Text(title)
                .font(.satoshi(14, weight: .semibold))
                .foregroundColor(ColorTokens.textSecondary)

            Spacer()

            Rectangle()
                .fill(ColorTokens.border)
                .frame(height: 1)
                .frame(maxWidth: 80)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.md)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("🔥")
                    .font(.satoshi(28))

                Text("dashboard.title".localized)
                    .label()
                    .font(.satoshi(20, weight: .bold))
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
            SettingsView(
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
                onTakeSelfie: {
                    showProfileSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showCamera = true
                    }
                },
                onSignOut: {
                    FocusAppStore.shared.signOut()
                }
            )
            .presentationDetents([.large])
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
                    print("📷 Editor: Save pressed, cropped image size: \(croppedImage.size)")
                    Task {
                        isUploadingPhoto = true
                        if let imageData = croppedImage.jpegData(compressionQuality: 0.8) {
                            print("📷 Editor: JPEG data created, size: \(imageData.count) bytes")
                            print("📷 Editor: Starting upload...")
                            await viewModel.uploadAvatar(imageData: imageData)
                            print("📷 Editor: Upload completed")
                        } else {
                            print("❌ Editor: Failed to create JPEG data")
                        }
                        isUploadingPhoto = false
                        selectedImage = nil
                    }
                }
            } else {
                // Debug: this should not happen
                Color.clear.onAppear {
                    print("❌ Editor: fullScreenCover opened but selectedImage is NIL!")
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue = newValue else { return }

            print("📷 Gallery: Photo item selected")
            Task {
                do {
                    print("📷 Gallery: Loading transferable data...")
                    if let data = try await newValue.loadTransferable(type: Data.self) {
                        print("📷 Gallery: Got data, size: \(data.count) bytes")
                        if let uiImage = UIImage(data: data) {
                            print("📷 Gallery: UIImage created successfully, size: \(uiImage.size)")
                            await MainActor.run {
                                selectedImage = uiImage
                                selectedPhotoItem = nil
                                // Dismiss profile sheet first, then show editor after delay
                                showProfileSheet = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    showImageEditor = true
                                }
                            }
                        } else {
                            print("❌ Gallery: Failed to create UIImage from data")
                            await MainActor.run {
                                selectedPhotoItem = nil
                            }
                        }
                    } else {
                        print("❌ Gallery: loadTransferable returned nil")
                        await MainActor.run {
                            selectedPhotoItem = nil
                        }
                    }
                } catch {
                    print("❌ Failed to load image from gallery: \(error)")
                    await MainActor.run {
                        selectedPhotoItem = nil
                    }
                }
            }
        }
        .onChange(of: showCamera) { _, isShowing in
            // When camera closes and we have an image, show the editor
            if !isShowing && selectedImage != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showImageEditor = true
                }
            }
        }
    }

    // MARK: - Streak Card Section with Progress Bar
    @State private var isStreakCardPressed = false
    @State private var flameScale: CGFloat = 1.0
    @State private var showValidationDetails = false

    // Current and next flame level helpers
    private var currentLevel: FlameLevel? {
        viewModel.flameLevels.first(where: { $0.isCurrent })
    }

    private var nextLevel: FlameLevel? {
        guard let current = currentLevel else { return viewModel.flameLevels.first }
        return viewModel.flameLevels.first(where: { $0.level == current.level + 1 })
    }

    private var progressToNextLevel: Double {
        guard let current = currentLevel, let next = nextLevel else { return 0 }
        let daysInRange = next.daysRequired - current.daysRequired
        guard daysInRange > 0 else { return 1.0 }
        let progress = viewModel.currentStreak - current.daysRequired
        return min(1.0, max(0, Double(progress) / Double(daysInRange)))
    }

    private var streakCardSection: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Main streak display with current level
            VStack(spacing: SpacingTokens.sm) {
                // Current flame icon with glow
                Text(currentLevel?.icon ?? "🔥")
                    .font(.system(size: 64))
                    .scaleEffect(flameScale)
                    .shadow(color: ColorTokens.primaryStart.opacity(0.6), radius: 20, x: 0, y: 0)

                // Streak text - "Jour 0" / "Day 0" format
                Text("streak.day_count".localized(with: viewModel.currentStreak))
                    .font(.satoshi(42, weight: .bold))
                    .foregroundColor(.white)

                // Current flame level name badge
                if let level = currentLevel {
                    Text(level.name.uppercased())
                        .font(.satoshi(12, weight: .bold))
                        .foregroundColor(ColorTokens.primaryStart)
                        .tracking(2)
                        .padding(.horizontal, SpacingTokens.md)
                        .padding(.vertical, SpacingTokens.xs)
                        .background(ColorTokens.primaryStart.opacity(0.15))
                        .cornerRadius(RadiusTokens.sm)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    flameScale = 1.08
                }
            }

            // Level progression bar (current -> next)
            levelProgressionBar

            // Today's validation requirements (collapsible)
            todayValidationSection

            // Daily task/ritual progress
            dailyProgressBar
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.lg)
    }

    // MARK: - Level Progression Bar
    private var levelProgressionBar: some View {
        VStack(spacing: SpacingTokens.sm) {
            // Level names on each side
            HStack {
                // Current level (left side - majority)
                HStack(spacing: SpacingTokens.xs) {
                    Text(currentLevel?.icon ?? "🔥")
                        .font(.system(size: 20))
                    Text(currentLevel?.name ?? "Spark")
                        .font(.satoshi(14, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Next level (right side - small preview)
                if let next = nextLevel {
                    HStack(spacing: SpacingTokens.xs) {
                        Text(next.name)
                            .font(.satoshi(12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text(next.icon)
                            .font(.system(size: 16))
                            .opacity(0.5)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.lg)

            // Progress bar showing current level fill + progress to next
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background (next level territory)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTokens.surface.opacity(0.2))
                        .frame(height: 12)

                    // Current level territory (filled)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTokens.fireGradient)
                        .frame(width: calculateLevelBarWidth(geometry: geometry), height: 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progressToNextLevel)

                    // Divider line between current and next level at ~90%
                    if nextLevel != nil {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 2, height: 16)
                            .offset(x: geometry.size.width * 0.85 - 1)
                    }
                }
            }
            .frame(height: 16)
            .padding(.horizontal, SpacingTokens.lg)

            // Days info
            HStack {
                if let next = nextLevel {
                    let daysToNext = next.daysRequired - viewModel.currentStreak
                    Text("streak.days_to_next".localized(with: daysToNext))
                        .font(.satoshi(11))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                if let next = nextLevel {
                    Text("\(next.daysRequired) " + "streak.days_needed".localized)
                        .font(.satoshi(11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
        }
    }

    private func calculateLevelBarWidth(geometry: GeometryProxy) -> CGFloat {
        // Base width is 85% (current level territory)
        // Plus progress within the remaining 15% towards next level
        let baseWidth = geometry.size.width * 0.85
        let progressWidth = geometry.size.width * 0.15 * CGFloat(progressToNextLevel)
        return baseWidth + progressWidth
    }

    // MARK: - Today Validation Section
    private var todayValidationSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            // Toggle button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showValidationDetails.toggle()
                }
            }) {
                HStack {
                    // Quick status indicators
                    if let validation = viewModel.todayValidation {
                        HStack(spacing: SpacingTokens.xs) {
                            Circle()
                                .fill(validation.meetsCompletionRate ? ColorTokens.success : ColorTokens.warning)
                                .frame(width: 6, height: 6)
                            Circle()
                                .fill(validation.meetsFocusSessions ? ColorTokens.success : ColorTokens.warning)
                                .frame(width: 6, height: 6)
                            Circle()
                                .fill(validation.meetsMinTasks ? ColorTokens.success : ColorTokens.warning)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text("streak.requirements".localized)
                        .font(.satoshi(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    Image(systemName: showValidationDetails ? "chevron.up" : "chevron.down")
                        .font(.satoshi(10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, SpacingTokens.lg)
            }

            if showValidationDetails {
                if let validation = viewModel.todayValidation {
                    VStack(spacing: SpacingTokens.xs) {
                        ValidationRequirementRow(
                            icon: "checkmark.circle.fill",
                            text: "streak.requirement_completion".localized(with: validation.requiredCompletionRate),
                            current: "\(validation.overallRate)%",
                            isMet: validation.meetsCompletionRate
                        )

                        ValidationRequirementRow(
                            icon: "flame.fill",
                            text: "streak.requirement_sessions".localized(with: validation.requiredFocusSessions),
                            current: "\(validation.focusSessions)",
                            isMet: validation.meetsFocusSessions
                        )

                        ValidationRequirementRow(
                            icon: "calendar",
                            text: "streak.requirement_tasks".localized(with: validation.requiredMinTasks),
                            current: "\(validation.totalTasks)",
                            isMet: validation.meetsMinTasks
                        )
                    }
                    .padding(.horizontal, SpacingTokens.lg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Daily Progress Bar
    private var dailyProgressBar: some View {
        VStack(spacing: SpacingTokens.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 5)
                        .fill(ColorTokens.surface.opacity(0.2))
                        .frame(height: 8)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            viewModel.dailyProgressPercentage >= 0.6
                                ? ColorTokens.successGradient
                                : ColorTokens.fireGradient
                        )
                        .frame(width: max(0, geometry.size.width * CGFloat(viewModel.dailyProgressPercentage)), height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.dailyProgressPercentage)

                    // 60% marker
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 1.5, height: 12)
                        .offset(x: geometry.size.width * 0.6 - 0.75)
                }
            }
            .frame(height: 12)
            .padding(.horizontal, SpacingTokens.lg)

            // Progress details
            HStack(spacing: SpacingTokens.sm) {
                Text("\(viewModel.completedTasksCount)/\(viewModel.totalTasksCount) " + "tasks".localized)
                    .font(.satoshi(11))
                    .foregroundColor(.white.opacity(0.4))

                Text("•")
                    .foregroundColor(.white.opacity(0.2))

                Text("\(viewModel.completedRitualsCount)/\(viewModel.totalRitualsCount) " + "rituals".localized)
                    .font(.satoshi(11))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                Text("\(Int(viewModel.dailyProgressPercentage * 100))%")
                    .font(.satoshi(13, weight: .bold))
                    .foregroundColor(
                        viewModel.dailyProgressPercentage >= 0.6
                            ? ColorTokens.success
                            : ColorTokens.primaryStart
                    )
            }
            .padding(.horizontal, SpacingTokens.lg)
        }
    }

    // MARK: - Main CTA Section (Add Events + Upcoming Task)
    private var mainCTASection: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Always show add events button
            addEventsButton

            // Show next upcoming task if any
            if let nextTask = viewModel.nextTask {
                upcomingTaskSection(task: nextTask)
            } else if viewModel.totalTasksCount > 0 && viewModel.completedTasksCount == viewModel.totalTasksCount {
                // All tasks completed
                allTasksCompletedCard
            }
        }
    }

    // MARK: - Add Events Button (Compact)
    private var addEventsButton: some View {
        Button(action: {
            HapticFeedback.medium()
            router.navigateToStartTheDay()
        }) {
            HStack(spacing: SpacingTokens.md) {
                Image(systemName: "mic.fill")
                    .font(.satoshi(18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(ColorTokens.fireGradient)
                    .cornerRadius(RadiusTokens.md)

                VStack(alignment: .leading, spacing: 2) {
                    Text("dashboard.start_day_title".localized)
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)
                    Text("dashboard.start_day_subtitle".localized)
                        .font(.satoshi(12))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.satoshi(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textMuted)
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Upcoming Task Section (Single Task)
    private func upcomingTaskSection(task: CalendarTask) -> some View {
        let isToday = isTaskToday(task)

        return VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            // Section header
            HStack {
                Text("dashboard.upcoming_task".localized)
                    .font(.satoshi(12, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                // Day badge for future tasks
                if !isToday, let taskDate = task.dateAsDate {
                    Text(formatDayName(taskDate))
                        .font(.satoshi(11, weight: .bold))
                        .foregroundColor(ColorTokens.primaryEnd)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorTokens.primaryEnd.opacity(0.15))
                        .cornerRadius(RadiusTokens.sm)
                }
            }

            // Task card
            Button(action: {
                HapticFeedback.light()
                if let taskDate = task.dateAsDate {
                    router.navigateToCalendar(date: taskDate)
                } else {
                    router.selectedTab = .calendar
                }
            }) {
                HStack(spacing: SpacingTokens.md) {
                    // Time badge
                    if let startTime = task.scheduledStart {
                        Text(startTime)
                            .font(.satoshi(16, weight: .bold))
                            .foregroundColor(ColorTokens.primaryStart)
                            .frame(width: 55)
                    }

                    // Task info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.satoshi(16, weight: .semibold))
                            .foregroundColor(ColorTokens.textPrimary)
                            .lineLimit(1)

                        if let end = task.scheduledEnd, let start = task.scheduledStart {
                            Text("\(start) - \(end)")
                                .font(.satoshi(12))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Focus button (only for today's tasks)
                    if isToday {
                        Button(action: {
                            HapticFeedback.medium()
                            var duration = 25
                            if let start = task.scheduledStart, let end = task.scheduledEnd {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "HH:mm"
                                if let startDate = formatter.date(from: start),
                                   let endDate = formatter.date(from: end) {
                                    let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
                                    if minutes > 0 { duration = minutes }
                                }
                            }
                            router.navigateToFireMode(duration: duration, questId: task.questId, description: task.title, taskId: task.id)
                        }) {
                            Image(systemName: "flame.fill")
                                .font(.satoshi(16))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(ColorTokens.fireGradient)
                                .cornerRadius(RadiusTokens.md)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.satoshi(14, weight: .semibold))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.lg)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // Helper: Check if task is for today
    private func isTaskToday(_ task: CalendarTask) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())
        return task.date == todayStr
    }

    // Helper: Format day name (Lun, Mar, Mer, etc.)
    private func formatDayName(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInTomorrow(date) {
            return "Demain"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }

    // MARK: - Next Task Card
    private func nextTaskCard(task: CalendarTask) -> some View {
        VStack(spacing: SpacingTokens.md) {
            // Header
            HStack {
                Text("⏭️")
                    .font(.satoshi(16))
                Text("dashboard.coming_next".localized)
                    .font(.satoshi(12, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                if let startTime = task.scheduledStart {
                    Text(startTime)
                        .font(.satoshi(14, weight: .medium))
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }

            // Task info
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text(task.title)
                    .font(.satoshi(18, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
                    .lineLimit(2)

                if let start = task.scheduledStart, let end = task.scheduledEnd {
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "clock")
                            .font(.satoshi(12))
                        Text("\(start) - \(end)")
                            .font(.satoshi(13))
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Focus button
            Button(action: {
                HapticFeedback.medium()
                // Calculate duration from task times
                var duration = 25 // Default
                if let start = task.scheduledStart, let end = task.scheduledEnd {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    if let startDate = formatter.date(from: start),
                       let endDate = formatter.date(from: end) {
                        let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
                        if minutes > 0 { duration = minutes }
                    }
                }
                router.navigateToFireMode(duration: duration, questId: task.questId, description: task.title)
            }) {
                HStack(spacing: SpacingTokens.sm) {
                    Image(systemName: "flame.fill")
                        .font(.satoshi(14, weight: .semibold))
                    Text("dashboard.start_focus".localized)
                        .font(.satoshi(16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.md)
                .background(ColorTokens.fireGradient)
                .cornerRadius(RadiusTokens.lg)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
    }

    // MARK: - No Tasks Card
    private var noTasksCard: some View {
        VStack(spacing: SpacingTokens.md) {
            Text("📅")
                .font(.satoshi(40))

            Text("dashboard.no_tasks_title".localized)
                .font(.satoshi(16, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)

            Text("dashboard.no_tasks_subtitle".localized)
                .font(.satoshi(14))
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                router.selectedTab = .calendar
            }) {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "calendar.badge.plus")
                    Text("dashboard.plan_day".localized)
                }
                .font(.satoshi(14, weight: .semibold))
                .foregroundColor(ColorTokens.primaryStart)
            }
        }
        .padding(SpacingTokens.xl)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
    }

    // MARK: - All Tasks Completed Card
    private var allTasksCompletedCard: some View {
        VStack(spacing: SpacingTokens.md) {
            Text("🎉")
                .font(.satoshi(48))

            Text("dashboard.all_done_title".localized)
                .font(.satoshi(18, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            Text("dashboard.all_done_subtitle".localized)
                .font(.satoshi(14))
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.xl)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
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
                .font(.satoshi(24))
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

                Text(intention.area.localizedName)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            Spacer()

            // Completion indicator
            if intention.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ColorTokens.success)
                    .font(.satoshi(20))
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
                .font(.satoshi(24))

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
                    .font(.satoshi(12, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)

                Rectangle()
                    .fill(ColorTokens.primaryStart)
                    .frame(width: 2, height: 16)
                    .cornerRadius(1)

                Text(session.formattedActualDuration)
                    .font(.satoshi(11, weight: .bold))
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
                            .font(.satoshi(10))
                        Text(session.formattedActualDuration)
                            .font(.satoshi(11, weight: .medium))
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, 4)
                    .background(ColorTokens.primarySoft)
                    .cornerRadius(RadiusTokens.sm)

                    if session.isManuallyLogged {
                        Text("Manual")
                            .font(.satoshi(10))
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
                    .font(.satoshi(12, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text("\(totalMinutes)m")
                    .font(.satoshi(11, weight: .medium))
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
                    .font(.satoshi(9))
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                Text("12:00")
                    .font(.satoshi(9))
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                Text("18:00")
                    .font(.satoshi(9))
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                Text("24:00")
                    .font(.satoshi(9))
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
    let presetDuration: Int?
    let presetDescription: String?
    @Environment(\.dismiss) private var dismiss

    // Step 1: Duration
    @State private var selectedDuration: Int = 25
    let durationOptions = [15, 25, 45, 60, 90]

    // Step 2: Quest
    @State private var selectedQuestId: String?

    // Step 3: Description
    @State private var focusDescription: String = ""
    @FocusState private var isDescriptionFocused: Bool

    // Current step - start at step 2 if preset provided
    @State private var currentStep: Int = 1

    // Track if using preset (simplified flow)
    private var hasPreset: Bool { presetDuration != nil }

    init(quests: [Quest], onStart: @escaping (Int, String?, String?) -> Void, presetDuration: Int? = nil, presetDescription: String? = nil) {
        self.quests = quests
        self.onStart = onStart
        self.presetDuration = presetDuration
        self.presetDescription = presetDescription
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator - show only relevant steps
                if !hasPreset {
                    HStack(spacing: SpacingTokens.sm) {
                        ForEach(1...3, id: \.self) { step in
                            Circle()
                                .fill(step <= currentStep ? ColorTokens.primaryStart : ColorTokens.surface)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.top, SpacingTokens.md)
                }

                // Step content
                TabView(selection: $currentStep) {
                    // Step 1: Choose Duration (skip if preset)
                    if !hasPreset {
                        step1DurationView
                            .tag(1)
                    }

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
                    if currentStep > (hasPreset ? 2 : 1) {
                        Button(action: {
                            isDescriptionFocused = false
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
            .onAppear {
                // Apply presets if provided
                if let duration = presetDuration {
                    selectedDuration = duration
                    currentStep = 2  // Skip step 1
                }
                if let description = presetDescription {
                    focusDescription = description
                }
            }
        }
    }

    // MARK: - Step 1: Duration
    private var step1DurationView: some View {
        VStack(spacing: SpacingTokens.xl) {
            Spacer()

            Text("🔥")
                .font(.satoshi(64))

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
                                .font(.satoshi(24, weight: .bold))
                            Text("min")
                                .font(.satoshi(12))
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
                .font(.satoshi(64))

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
        VStack(spacing: SpacingTokens.md) {
            // Compact header - smaller when keyboard is shown
            VStack(spacing: SpacingTokens.sm) {
                Text("✍️")
                    .font(.system(size: isDescriptionFocused ? 32 : 48))

                Text("What will you work on?")
                    .font(.system(size: isDescriptionFocused ? 18 : 22, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
            }
            .padding(.top, SpacingTokens.lg)
            .animation(.easeInOut(duration: 0.2), value: isDescriptionFocused)

            // Description input - takes main focus
            TextField("e.g., Finish the report, Study chapter 5...", text: $focusDescription, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .stroke(isDescriptionFocused ? ColorTokens.primaryStart : ColorTokens.border, lineWidth: isDescriptionFocused ? 2 : 1)
                )
                .lineLimit(2...4)
                .focused($isDescriptionFocused)

            // Inline summary - compact
            HStack(spacing: SpacingTokens.md) {
                // Duration badge
                HStack(spacing: SpacingTokens.xs) {
                    Text("🔥")
                        .font(.satoshi(14))
                    Text("\(selectedDuration)min")
                        .font(.satoshi(14, weight: .medium))
                        .foregroundColor(ColorTokens.textPrimary)
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.sm)

                // Quest badge (if selected)
                if let questId = selectedQuestId,
                   let quest = quests.first(where: { $0.id == questId }) {
                    HStack(spacing: SpacingTokens.xs) {
                        Text(quest.area.emoji)
                            .font(.satoshi(14))
                        Text(quest.title)
                            .font(.satoshi(14, weight: .medium))
                            .foregroundColor(ColorTokens.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, SpacingTokens.xs)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.sm)
                }

                Spacer()
            }

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.lg)
        .contentShape(Rectangle())
        .onTapGesture {
            isDescriptionFocused = false
        }
        .onAppear {
            // Auto-focus the text field when this step appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isDescriptionFocused = true
            }
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
    let onSignOut: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var showingSignOutAlert = false
    @State private var showingLanguageChangeAlert = false
    @State private var pendingLanguage: AppLanguage?

    var body: some View {
        NavigationView {
            ScrollView {
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
                            onTakeSelfie()
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
                            .font(.satoshi(20))
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
                                if LocalizationManager.shared.currentLanguage != language {
                                    pendingLanguage = language
                                    showingLanguageChangeAlert = true
                                }
                            } label: {
                                HStack {
                                    Text(language.flag)
                                        .font(.satoshi(20))

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

                // Sign Out button
                Button(action: {
                    showingSignOutAlert = true
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.satoshi(14))
                        Text("profile.sign_out".localized)
                            .bodyText()
                    }
                    .foregroundColor(ColorTokens.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.md)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .stroke(ColorTokens.error.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.top, SpacingTokens.md)

                Spacer()
                    .frame(height: SpacingTokens.xl)
            }
            .padding(.top, SpacingTokens.xl)
            }
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
            .alert("profile.sign_out_title".localized, isPresented: $showingSignOutAlert) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("profile.sign_out".localized, role: .destructive) {
                    dismiss()
                    onSignOut()
                }
            } message: {
                Text("profile.sign_out_confirm".localized)
            }
            .alert("profile.language_change_title".localized, isPresented: $showingLanguageChangeAlert) {
                Button("common.cancel".localized, role: .cancel) {
                    pendingLanguage = nil
                }
                Button("profile.restart_app".localized, role: .destructive) {
                    if let language = pendingLanguage {
                        LocalizationManager.shared.currentLanguage = language
                        // Force app restart by exiting
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            exit(0)
                        }
                    }
                }
            } message: {
                Text("profile.language_change_message".localized)
            }
        }
        .id(localization.currentLanguage)
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

    /// Calculate image display size to maintain aspect ratio and fill the crop area
    private var imageDisplaySize: CGSize {
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio > 1 {
            // Landscape: fit height to cropSize, width extends
            return CGSize(width: cropSize * aspectRatio, height: cropSize)
        } else {
            // Portrait: fit width to cropSize, height extends
            return CGSize(width: cropSize, height: cropSize / aspectRatio)
        }
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    // Image with gestures - maintain aspect ratio
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: imageDisplaySize.width * scale,
                            height: imageDisplaySize.height * scale
                        )
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

            // Calculate the scaled image size maintaining aspect ratio
            let aspectRatio = image.size.width / image.size.height
            var imageWidth: CGFloat
            var imageHeight: CGFloat

            if aspectRatio > 1 {
                // Landscape: fit height, width extends
                imageHeight = cropSize * scale
                imageWidth = imageHeight * aspectRatio
            } else {
                // Portrait: fit width, height extends
                imageWidth = cropSize * scale
                imageHeight = imageWidth / aspectRatio
            }

            let imageRect = CGRect(
                x: (cropSize - imageWidth) / 2 + offset.width,
                y: (cropSize - imageHeight) / 2 + offset.height,
                width: imageWidth,
                height: imageHeight
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
                                    .font(.satoshi(16, weight: .semibold))
                                Text("Edit")
                                    .font(.satoshi(10, weight: .medium))
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
                                    .font(.satoshi(16, weight: .semibold))
                                Text("Delete")
                                    .font(.satoshi(10, weight: .medium))
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
                        .font(.satoshi(12, weight: .medium))
                        .foregroundColor(ColorTokens.textSecondary)

                    Rectangle()
                        .fill(ColorTokens.primaryStart)
                        .frame(width: 2, height: 16)
                        .cornerRadius(1)

                    Text(session.formattedActualDuration)
                        .font(.satoshi(11, weight: .bold))
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
                                .font(.satoshi(10))
                            Text(session.formattedActualDuration)
                                .font(.satoshi(11, weight: .medium))
                        }
                        .foregroundColor(ColorTokens.primaryStart)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, 4)
                        .background(ColorTokens.primarySoft)
                        .cornerRadius(RadiusTokens.sm)

                        if session.isManuallyLogged {
                            Text("Manual")
                                .font(.satoshi(10))
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
                            .font(.satoshi(10, weight: .medium))
                            .opacity(0.3)
                        Image(systemName: "chevron.left")
                            .font(.satoshi(10, weight: .medium))
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
                                    .font(.satoshi(28))
                                    .foregroundColor(ColorTokens.textMuted)
                            }

                            Text("\(durationMinutes) minutes")
                                .font(.satoshi(18, weight: .semibold))
                                .foregroundColor(ColorTokens.textPrimary)
                                .frame(width: 120)

                            Button(action: {
                                if durationMinutes < 180 {
                                    durationMinutes += 5
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.satoshi(28))
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

// MARK: - Validation Requirement Row
struct ValidationRequirementRow: View {
    let icon: String
    let text: String
    let current: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: icon)
                .font(.satoshi(14))
                .foregroundColor(isMet ? ColorTokens.success : ColorTokens.warning)
                .frame(width: 20)

            Text(text)
                .font(.satoshi(12))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(current)
                .font(.satoshi(12, weight: .semibold))
                .foregroundColor(isMet ? ColorTokens.success : ColorTokens.warning)

            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.satoshi(14))
                .foregroundColor(isMet ? ColorTokens.success : .white.opacity(0.3))
        }
        .padding(.vertical, SpacingTokens.xs)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject(AppRouter.shared)
    }
}
