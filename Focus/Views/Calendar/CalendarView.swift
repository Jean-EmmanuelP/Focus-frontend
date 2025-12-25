import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showCreateTaskSheet = false
    @State private var selectedTimeBlock: String = "morning"

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.tasks.isEmpty {
                LoadingView(message: "calendar.loading".localized)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        headerSection
                            .padding(.horizontal, SpacingTokens.lg)
                            .padding(.top, SpacingTokens.lg)
                            .padding(.bottom, SpacingTokens.md)

                        // Date Navigation
                        dateNavigationSection
                            .padding(.horizontal, SpacingTokens.lg)
                            .padding(.bottom, SpacingTokens.lg)

                        // Progress Card (if day plan exists)
                        if viewModel.hasDayPlan {
                            progressCard
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.lg)
                        }

                        // AI Summary (if available)
                        if let summary = viewModel.dayPlan?.aiSummary, !summary.isEmpty {
                            aiSummaryCard(summary)
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.bottom, SpacingTokens.lg)
                        }

                        // Tasks by Time Block
                        tasksSection
                            .padding(.horizontal, SpacingTokens.lg)
                            .padding(.bottom, SpacingTokens.lg)

                        // Empty State / Start Day CTA
                        if !viewModel.hasDayPlan && viewModel.tasks.isEmpty {
                            startDayCTA
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.vertical, SpacingTokens.xxl)
                        }

                        // Bottom spacing for tab bar
                        Spacer()
                            .frame(height: 120)
                    }
                }
                .refreshable {
                    await viewModel.refreshData()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showAIGenerationSheet) {
            AIGenerateDaySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showCreateTaskSheet) {
            CreateTaskSheet(viewModel: viewModel, timeBlock: selectedTimeBlock)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .task {
            await viewModel.loadDayData()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("📅")
                    .font(.inter(28))
                +
                Text(" " + "calendar.title".localized)
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("calendar.subtitle".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()

            // Add task button
            Button(action: {
                selectedTimeBlock = "morning"
                showCreateTaskSheet = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.inter(28))
                    .foregroundColor(ColorTokens.primaryStart)
            }
        }
    }

    // MARK: - Date Navigation
    private var dateNavigationSection: some View {
        HStack {
            Button(action: { viewModel.goToPreviousDay() }) {
                Image(systemName: "chevron.left")
                    .font(.inter(16, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.formattedSelectedDate)
                    .font(.inter(16, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)

                if Calendar.current.isDateInToday(viewModel.selectedDate) {
                    Text("calendar.today".localized)
                        .font(.inter(12))
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }
            .onTapGesture {
                viewModel.goToToday()
            }

            Spacer()

            Button(action: { viewModel.goToNextDay() }) {
                Image(systemName: "chevron.right")
                    .font(.inter(16, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
            }
        }
    }

    // MARK: - Progress Card
    private var progressCard: some View {
        Card {
            VStack(spacing: SpacingTokens.md) {
                HStack {
                    Text("🔥")
                        .font(.inter(24))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("calendar.day_progress".localized)
                            .font(.inter(14, weight: .semibold))
                            .foregroundColor(ColorTokens.textPrimary)

                        Text("\(viewModel.completedTasksCount)/\(viewModel.totalTasksCount) " + "calendar.tasks_completed".localized)
                            .font(.inter(12))
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    Spacer()

                    Text("\(viewModel.dayProgress)%")
                        .font(.inter(28, weight: .bold))
                        .foregroundColor(ColorTokens.primaryStart)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.surface)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.fireGradient)
                            .frame(width: geometry.size.width * CGFloat(viewModel.dayProgress) / 100, height: 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.dayProgress)
                    }
                }
                .frame(height: 8)
            }
            .padding(SpacingTokens.md)
        }
    }

    // MARK: - AI Summary Card
    private func aiSummaryCard(_ summary: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: SpacingTokens.md) {
                Text("✨")
                    .font(.inter(20))

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("calendar.ai_summary".localized)
                        .font(.inter(12, weight: .semibold))
                        .foregroundColor(ColorTokens.textMuted)

                    Text(summary)
                        .font(.inter(14))
                        .foregroundColor(ColorTokens.textPrimary)
                }

                Spacer()
            }
            .padding(SpacingTokens.md)
        }
    }

    // MARK: - Tasks Section (grouped by time block)
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            // Morning tasks
            TimeBlockSection(
                title: "calendar.morning".localized,
                emoji: "🌅",
                timeBlock: "morning",
                tasks: viewModel.tasks.filter { $0.timeBlock == "morning" },
                onToggleTask: { taskId in
                    Task { await viewModel.toggleTask(taskId) }
                },
                onAddTask: {
                    selectedTimeBlock = "morning"
                    showCreateTaskSheet = true
                },
                onDeleteTask: { taskId in
                    Task { await viewModel.deleteTask(taskId) }
                }
            )

            // Afternoon tasks
            TimeBlockSection(
                title: "calendar.afternoon".localized,
                emoji: "☀️",
                timeBlock: "afternoon",
                tasks: viewModel.tasks.filter { $0.timeBlock == "afternoon" },
                onToggleTask: { taskId in
                    Task { await viewModel.toggleTask(taskId) }
                },
                onAddTask: {
                    selectedTimeBlock = "afternoon"
                    showCreateTaskSheet = true
                },
                onDeleteTask: { taskId in
                    Task { await viewModel.deleteTask(taskId) }
                }
            )

            // Evening tasks
            TimeBlockSection(
                title: "calendar.evening".localized,
                emoji: "🌙",
                timeBlock: "evening",
                tasks: viewModel.tasks.filter { $0.timeBlock == "evening" },
                onToggleTask: { taskId in
                    Task { await viewModel.toggleTask(taskId) }
                },
                onAddTask: {
                    selectedTimeBlock = "evening"
                    showCreateTaskSheet = true
                },
                onDeleteTask: { taskId in
                    Task { await viewModel.deleteTask(taskId) }
                }
            )
        }
    }

    // MARK: - Start Day CTA
    private var startDayCTA: some View {
        VStack(spacing: SpacingTokens.xl) {
            Image(systemName: "calendar.badge.plus")
                .font(.inter(64))
                .foregroundColor(ColorTokens.textMuted)

            VStack(spacing: SpacingTokens.sm) {
                Text("calendar.no_plan_title".localized)
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("calendar.no_plan_subtitle".localized)
                    .font(.inter(14))
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton("calendar.plan_your_day".localized, icon: "✨") {
                viewModel.showAIGenerationSheet = true
            }
        }
        .padding(SpacingTokens.xl)
    }
}

// MARK: - Time Block Section
struct TimeBlockSection: View {
    let title: String
    let emoji: String
    let timeBlock: String
    let tasks: [CalendarTask]
    let onToggleTask: (String) -> Void
    let onAddTask: () -> Void
    let onDeleteTask: (String) -> Void

    @State private var isExpanded = true

    var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(emoji)
                        .font(.inter(18))
                    Text(title)
                        .font(.inter(14, weight: .semibold))
                        .foregroundColor(ColorTokens.textSecondary)

                    Spacer()

                    if !tasks.isEmpty {
                        Text("\(completedCount)/\(tasks.count)")
                            .font(.inter(12, weight: .bold))
                            .foregroundColor(completedCount == tasks.count ? ColorTokens.success : ColorTokens.textMuted)
                            .padding(.horizontal, SpacingTokens.sm)
                            .padding(.vertical, 4)
                            .background(completedCount == tasks.count ? ColorTokens.success.opacity(0.15) : ColorTokens.surface)
                            .cornerRadius(RadiusTokens.sm)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.inter(12, weight: .medium))
                        .foregroundColor(ColorTokens.textMuted)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                if tasks.isEmpty {
                    // Empty state
                    Button(action: onAddTask) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.inter(14))
                            Text("calendar.add_task".localized)
                                .font(.inter(13))
                        }
                        .foregroundColor(ColorTokens.textMuted)
                        .padding(SpacingTokens.md)
                        .frame(maxWidth: .infinity)
                        .background(ColorTokens.surface.opacity(0.5))
                        .cornerRadius(RadiusTokens.md)
                    }
                } else {
                    // Tasks list
                    ForEach(tasks) { task in
                        TaskRowCard(
                            task: task,
                            onToggle: { onToggleTask(task.id) },
                            onDelete: { onDeleteTask(task.id) }
                        )
                    }

                    // Add button
                    Button(action: onAddTask) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.inter(12))
                            Text("calendar.add_task".localized)
                                .font(.inter(12))
                        }
                        .foregroundColor(ColorTokens.textMuted)
                    }
                    .padding(.top, SpacingTokens.xs)
                }
            }
        }
    }
}

// MARK: - Task Row Card
struct TaskRowCard: View {
    let task: CalendarTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.inter(22))
                    .foregroundColor(task.isCompleted ? ColorTokens.success : ColorTokens.textMuted)
            }

            // Task content
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(task.isCompleted ? ColorTokens.textMuted : ColorTokens.textPrimary)
                    .strikethrough(task.isCompleted)

                HStack(spacing: SpacingTokens.sm) {
                    if let start = task.scheduledStart, let end = task.scheduledEnd {
                        Text("\(start) - \(end)")
                            .font(.inter(11))
                            .foregroundColor(ColorTokens.textMuted)
                    } else if let minutes = task.estimatedMinutes {
                        Text("\(minutes)min")
                            .font(.inter(11))
                            .foregroundColor(ColorTokens.textMuted)
                    }

                    if let questTitle = task.questTitle {
                        Text("• \(questTitle)")
                            .font(.inter(11))
                            .foregroundColor(ColorTokens.primaryStart)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // AI badge
            if task.isAiGenerated {
                Text("✨")
                    .font(.inter(12))
            }

            // Priority indicator
            Circle()
                .fill(priorityColor(task.priorityEnum))
                .frame(width: 8, height: 8)
        }
        .padding(SpacingTokens.sm)
        .background(task.isCompleted ? ColorTokens.surface.opacity(0.5) : ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: return Color.gray
        case .medium: return Color.blue
        case .high: return Color.orange
        case .urgent: return Color.red
        }
    }
}

// MARK: - Preview
#Preview {
    CalendarView()
        .environmentObject(AppRouter.shared)
        .environmentObject(FocusAppStore.shared)
}
