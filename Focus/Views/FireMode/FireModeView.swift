import SwiftUI

struct FireModeView: View {
    @StateObject private var viewModel = FireModeViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showingQuestPicker = false
    @State private var hasAppliedPresets = false

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            if viewModel.isTimerActive || viewModel.timerState == .completed {
                // Active Timer View
                timerActiveView
            } else {
                // Setup View
                setupView
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showingLogManualSession) {
            LogManualSessionSheet(viewModel: viewModel)
        }
        .onAppear {
            // Apply presets from router (from Calendar task, ritual, or Dashboard)
            if !hasAppliedPresets,
               let duration = router.fireModePresetDuration {
                hasAppliedPresets = true
                viewModel.applyPresets(
                    duration: duration,
                    questId: router.fireModePresetQuestId,
                    description: router.fireModePresetDescription,
                    taskId: router.fireModePresetTaskId,
                    ritualId: router.fireModePresetRitualId
                )
                router.clearFireModePresets()
            }
        }
        .alert("fire.task_completed_question".localized, isPresented: $viewModel.showTaskValidationPrompt) {
            Button("fire.yes_validate".localized) {
                Task {
                    await viewModel.validateLinkedTask()
                }
            }
            Button("fire.not_yet".localized, role: .cancel) {
                viewModel.skipTaskValidation()
            }
        } message: {
            Text("fire.task_validation_message".localized)
        }
        .alert("Session de focus non terminée", isPresented: $viewModel.showingStaleSessionAlert) {
            Button("Valider la session") {
                Task {
                    await viewModel.completeStaleSession()
                }
            }
            Button("Annuler la session", role: .destructive) {
                Task {
                    await viewModel.cancelStaleSession()
                }
            }
        } message: {
            if let session = viewModel.staleSession {
                Text("Tu avais une session de \(session.durationMinutes) minutes qui n'a pas été terminée. Que veux-tu faire ?")
            } else {
                Text("Tu avais une session qui n'a pas été terminée.")
            }
        }
        .onChange(of: viewModel.shouldDismissModal) { _, shouldDismiss in
            if shouldDismiss {
                router.dismissFireMode()
            }
        }
    }

    // MARK: - Setup View (Before Timer Starts)
    private var setupView: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Header with compact stats
                headerWithStatsSection

                // Main focus configuration card
                focusConfigurationCard

                // Actions
                actionsSection

                // Today's Sessions Log
                if !viewModel.todaysSessions.isEmpty {
                    sessionsLogSection
                }
            }
            .padding(SpacingTokens.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            hideKeyboard()
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }

    // MARK: - Header with Compact Stats
    private var headerWithStatsSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // Title row
            HStack {
                // Close button
                Button(action: {
                    router.dismissFireMode()
                }) {
                    Image(systemName: "xmark")
                        .font(.satoshi(16, weight: .medium))
                        .foregroundColor(ColorTokens.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.full)
                }

                Text("🔥")
                    .font(.satoshi(28))

                Text("fire.title".localized)
                    .font(.satoshi(20, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                // Compact stats inline
                if viewModel.hasAnySessions {
                    HStack(spacing: SpacingTokens.md) {
                        CompactStat(icon: "flame.fill", value: "\(viewModel.totalSessionsThisWeek)", color: ColorTokens.primaryStart)
                        CompactStat(icon: "clock.fill", value: "\(viewModel.totalMinutesToday)m", color: .blue)
                    }
                }
            }

            Text("fire.subtitle".localized)
                .caption()
                .foregroundColor(ColorTokens.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Focus Configuration Card
    private var focusConfigurationCard: some View {
        Card(elevated: true) {
            VStack(spacing: SpacingTokens.lg) {
                // Duration Section
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    Text("fire.duration".localized)
                        .caption()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textMuted)

                    // Preset buttons
                    HStack(spacing: SpacingTokens.sm) {
                        ForEach(viewModel.presetDurations, id: \.self) { duration in
                            DurationChip(
                                duration: duration,
                                isSelected: viewModel.selectedDuration == duration
                            ) {
                                viewModel.selectDuration(duration)
                            }
                        }
                    }

                    // Custom slider
                    CustomSlider(
                        value: $viewModel.customDuration,
                        range: 5...180,
                        step: 5,
                        label: "fire.custom".localized
                    )
                    .onChange(of: viewModel.customDuration) { _, newValue in
                        viewModel.updateCustomDuration(newValue)
                    }
                }

                Divider()
                    .background(ColorTokens.border)

                // Quest Link Section
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("fire.link_quest".localized)
                        .caption()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textMuted)

                    questSelector
                }

                Divider()
                    .background(ColorTokens.border)

                // Description Section
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("fire.description".localized)
                        .caption()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textMuted)

                    CustomTextArea(
                        placeholder: "fire.description_placeholder".localized,
                        text: $viewModel.sessionDescription,
                        minHeight: 60
                    )
                }
            }
            .padding(SpacingTokens.sm)
        }
    }

    // MARK: - Quest Selector
    private var questSelector: some View {
        Group {
            if viewModel.availableQuests.isEmpty {
                HStack {
                    Text("fire.no_active_quests".localized)
                        .bodyText()
                        .foregroundColor(ColorTokens.textMuted)
                    Spacer()
                }
                .padding(SpacingTokens.sm)
                .background(ColorTokens.surfaceElevated)
                .cornerRadius(RadiusTokens.sm)
            } else {
                Menu {
                    Button(action: {
                        viewModel.selectedQuestId = nil
                    }) {
                        Label("common.none".localized, systemImage: "xmark.circle")
                    }

                    ForEach(viewModel.availableQuests) { quest in
                        Button(action: {
                            viewModel.selectedQuestId = quest.id
                        }) {
                            Text("\(quest.area.emoji) \(quest.title)")
                        }
                    }
                } label: {
                    HStack {
                        if let selectedId = viewModel.selectedQuestId,
                           let quest = viewModel.quests.first(where: { $0.id == selectedId }) {
                            Text(quest.area.emoji)
                                .font(.satoshi(16))
                            Text(quest.title)
                                .bodyText()
                                .foregroundColor(ColorTokens.textPrimary)
                                .lineLimit(1)
                        } else {
                            Image(systemName: "link")
                                .font(.satoshi(14))
                                .foregroundColor(ColorTokens.textMuted)
                            Text("fire.select_quest".localized)
                                .bodyText()
                                .foregroundColor(ColorTokens.textMuted)
                        }

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.satoshi(10, weight: .medium))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                    .padding(SpacingTokens.sm)
                    .background(ColorTokens.surfaceElevated)
                    .cornerRadius(RadiusTokens.sm)
                }
            }
        }
    }

    // MARK: - Sessions Log Section
    private var sessionsLogSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🔥")
                    .font(.satoshi(20))
                Text("fire.sessions_today".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
                Text("\(viewModel.todaysSessions.count)")
                    .caption()
                    .fontWeight(.bold)
                    .foregroundColor(ColorTokens.primaryStart)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, 4)
                    .background(ColorTokens.primarySoft)
                    .cornerRadius(RadiusTokens.sm)
            }

            VStack(spacing: SpacingTokens.sm) {
                ForEach(viewModel.todaysSessions) { session in
                    SessionLogCard(session: session)
                }
            }
        }
        .padding(.top, SpacingTokens.lg)
    }

    // MARK: - Timer Active View
    private var timerActiveView: some View {
        VStack(spacing: 0) {
            // Minimal header
            HStack {
                Text("🔥")
                    .font(.satoshi(24))

                Text("fire.title".localized)
                    .font(.satoshi(16, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                if viewModel.timerState == .completed {
                    // Close button when completed
                    Button(action: {
                        router.dismissFireMode()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.satoshi(28))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                } else {
                    // Stop button (top right)
                    Button(action: {
                        viewModel.stopTimer()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.satoshi(28))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.top, SpacingTokens.lg)

            Spacer()

            // Timer Circle
            timerCircleView

            Spacer()

            // Session Info
            if let quest = viewModel.quests.first(where: { $0.id == viewModel.selectedQuestId }) {
                VStack(spacing: SpacingTokens.sm) {
                    Text(quest.area.emoji)
                        .font(.satoshi(24))

                    Text(quest.title)
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, SpacingTokens.xl)
            }

            if !viewModel.sessionDescription.isEmpty {
                Text(viewModel.sessionDescription)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, SpacingTokens.xl)
                    .padding(.top, SpacingTokens.md)
            }

            Spacer()

            // Timer Controls
            timerControlsView
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.bottom, SpacingTokens.xxl)
        }
    }

    // MARK: - Timer Circle View
    private var timerCircleView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(ColorTokens.border, lineWidth: 12)
                .frame(width: 280, height: 280)

            // Progress circle
            Circle()
                .trim(from: 0, to: viewModel.timerProgress)
                .stroke(
                    LinearGradient(
                        colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: viewModel.timerProgress)

            // Glow effect
            Circle()
                .fill(ColorTokens.primaryGlow)
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .opacity(viewModel.timerState == .running ? 0.6 : 0.3)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: viewModel.timerState)

            // Center content
            VStack(spacing: SpacingTokens.sm) {
                if viewModel.timerState == .completed {
                    Text("🎉")
                        .font(.satoshi(48))

                    Text("fire.complete".localized)
                        .heading1()
                        .foregroundColor(ColorTokens.success)
                } else {
                    Text(viewModel.formattedTimeRemaining)
                        .font(.satoshi(64, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text(viewModel.timerState == .paused ? "fire.paused".localized : "fire.focus".localized)
                        .caption()
                        .foregroundColor(viewModel.timerState == .paused ? ColorTokens.warning : ColorTokens.textMuted)
                }
            }
        }
    }

    // MARK: - Timer Controls View
    private var timerControlsView: some View {
        Group {
            if viewModel.timerState == .completed {
                // Completed state - just show a message
                Text("fire.great_work".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
            } else {
                // Pause/Resume button
                HStack(spacing: SpacingTokens.lg) {
                    if viewModel.timerState == .paused {
                        PrimaryButton("fire.resume".localized, icon: "▶️") {
                            viewModel.resumeTimer()
                        }
                    } else {
                        SecondaryButton("fire.pause".localized) {
                            viewModel.pauseTimer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: SpacingTokens.md) {
            PrimaryButton(
                "fire.start_session".localized,
                icon: "🔥",
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.startFocusSession()
                }
            }

        }
        .padding(.top, SpacingTokens.md)
    }
}

// MARK: - Log Manual Session Sheet
struct LogManualSessionSheet: View {
    @ObservedObject var viewModel: FireModeViewModel
    @Environment(\.dismiss) var dismiss

    @State private var durationMinutes: Double = 25
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.lg) {
                        // Date picker
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("fire.when".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            DatePicker(
                                "fire.session_time".localized,
                                selection: $selectedDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(SpacingTokens.md)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.md)
                        }

                        // Duration
                        CustomSlider(
                            value: $durationMinutes,
                            range: 5...180,
                            step: 5,
                            label: "fire.duration".localized
                        )

                        // Quest link
                        if !viewModel.availableQuests.isEmpty {
                            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                                Text("fire.link_quest".localized)
                                    .subtitle()
                                    .foregroundColor(ColorTokens.textPrimary)

                                Menu {
                                    Button(action: {
                                        viewModel.selectedQuestId = nil
                                    }) {
                                        Text("common.none".localized)
                                    }

                                    ForEach(viewModel.availableQuests) { quest in
                                        Button(action: {
                                            viewModel.selectedQuestId = quest.id
                                        }) {
                                            Text("\(quest.area.emoji) \(quest.title)")
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let selectedId = viewModel.selectedQuestId,
                                           let quest = viewModel.quests.first(where: { $0.id == selectedId }) {
                                            Text(quest.area.emoji)
                                                .font(.satoshi(18))
                                            Text(quest.title)
                                                .bodyText()
                                                .foregroundColor(ColorTokens.textPrimary)
                                                .lineLimit(1)
                                        } else {
                                            Text("fire.select_quest".localized)
                                                .bodyText()
                                                .foregroundColor(ColorTokens.textMuted)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.satoshi(12, weight: .medium))
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
                        }

                        // Description
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("fire.what_worked_on".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            CustomTextArea(
                                placeholder: "fire.description_placeholder".localized,
                                text: $viewModel.sessionDescription,
                                minHeight: 80
                            )
                        }

                        // Action
                        PrimaryButton(
                            "fire.log_session".localized,
                            isLoading: viewModel.isLoading
                        ) {
                            Task {
                                await viewModel.logManualSession(
                                    durationMinutes: Int(durationMinutes),
                                    startTime: selectedDate
                                )
                                dismiss()
                            }
                        }
                        .padding(.top, SpacingTokens.md)
                    }
                    .padding(SpacingTokens.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .navigationTitle("fire.log_past_session".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
    }
}

// MARK: - Session Log Card
struct SessionLogCard: View {
    let session: FocusSession

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Time and duration
            VStack(alignment: .center, spacing: 4) {
                Text(timeFormatter.string(from: session.startTime))
                    .font(.satoshi(12, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)

                ZStack {
                    Circle()
                        .fill(ColorTokens.primaryGlow)
                        .frame(width: 40, height: 40)

                    Text("🔥")
                        .font(.satoshi(18))
                }

                Text(session.formattedActualDuration)
                    .font(.satoshi(11, weight: .bold))
                    .foregroundColor(ColorTokens.primaryStart)
            }
            .frame(width: 50)

            // Session details
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                if let description = session.description, !description.isEmpty {
                    Text(description)
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)
                        .lineLimit(2)
                } else {
                    Text("fire.focus_session".localized)
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                        .italic()
                }

                HStack(spacing: SpacingTokens.sm) {
                    // Duration badge (actual duration)
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.satoshi(10))
                        Text(session.formattedActualDuration)
                            .font(.satoshi(11, weight: .medium))
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, 4)
                    .background(ColorTokens.primarySoft)
                    .cornerRadius(RadiusTokens.sm)

                    // Status badge
                    if session.status == .completed {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.satoshi(10))
                            Text("common.done".localized)
                                .font(.satoshi(10))
                        }
                        .foregroundColor(ColorTokens.success)
                    }

                    if session.isManuallyLogged {
                        Text("fire.manual".localized)
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
        .cornerRadius(RadiusTokens.lg)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }
}

// MARK: - Compact Stat Component
struct CompactStat: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.satoshi(10))
                .foregroundColor(color)

            Text(value)
                .font(.satoshi(12, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(RadiusTokens.sm)
    }
}

// MARK: - Duration Chip Component
struct DurationChip: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            HapticFeedback.selection()
        }) {
            Text("\(duration)m")
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : ColorTokens.textSecondary)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.sm)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected
                        ? ColorTokens.fireGradient
                        : LinearGradient(colors: [ColorTokens.surface, ColorTokens.surface], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(RadiusTokens.md)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    FireModeView()
}
