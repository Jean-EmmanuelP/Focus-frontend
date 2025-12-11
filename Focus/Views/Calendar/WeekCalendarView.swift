import SwiftUI

// MARK: - Week Calendar View (Modern Design)
struct WeekCalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showVoiceInput = false
    @State private var showCreateTaskSheet = false
    @State private var showQuickCreateSheet = false
    @State private var selectedTask: CalendarTask?
    @State private var draggedTask: CalendarTask?

    // Quick create state
    @State private var quickCreateDate: Date = Date()
    @State private var quickCreateStartHour: Int = 9
    @State private var quickCreateEndHour: Int = 10

    // Hours to display (6am to 11pm)
    private let hours = Array(6...23)
    private let hourHeight: CGFloat = 60

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact header with week navigation + day selector
                modernHeader

                // Calendar grid - Day view only
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        dayViewTappableGrid
                        hourGrid
                        dayTasksOverlay

                        // Current time indicator only for today
                        if Calendar.current.isDateInToday(viewModel.selectedDate) {
                            dayViewCurrentTimeIndicator
                        }
                    }
                    .frame(height: CGFloat(hours.count) * hourHeight)

                    // Reduced bottom padding for tab bar
                    Spacer().frame(height: 60)
                }
                .scrollIndicators(.hidden)
            }

            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingActionButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 80)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showVoiceInput) {
            VoiceInputSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showCreateTaskSheet) {
            QuickCreateTaskSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showQuickCreateSheet) {
            QuickCreateTaskSheetWithTime(
                viewModel: viewModel,
                date: quickCreateDate,
                startHour: quickCreateStartHour,
                endHour: quickCreateEndHour
            )
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task, viewModel: viewModel)
                .environmentObject(router)
        }
        .onAppear {
            Task {
                await viewModel.loadWeekData()
            }
        }
    }

    // MARK: - Tappable Grid for Quick Create
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        Menu {
            Button(action: { showCreateTaskSheet = true }) {
                Label("calendar.add_task".localized, systemImage: "plus.circle")
            }
            Button(action: { showVoiceInput = true }) {
                Label("calendar.voice_input".localized, systemImage: "mic.fill")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: ColorTokens.primaryStart.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Modern Compact Header
    private var modernHeader: some View {
        VStack(spacing: 0) {
            // Combined: Navigation arrows + Week days in one row
            HStack(spacing: 0) {
                // Previous week button
                Button(action: { viewModel.goToPreviousWeek() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(width: 32, height: 44)
                }

                // Week days
                HStack(spacing: 0) {
                    ForEach(viewModel.weekDays, id: \.self) { date in
                        let isToday = Calendar.current.isDateInToday(date)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                        let tasksCount = tasksForDate(date).count

                        Button(action: { viewModel.selectDate(date) }) {
                            VStack(spacing: 3) {
                                // Day name
                                Text(date.formatted(.dateTime.weekday(.narrow)).uppercased())
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isToday ? ColorTokens.primaryStart : ColorTokens.textMuted)

                                // Day number with indicator
                                ZStack {
                                    if isToday {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 32, height: 32)
                                    } else if isSelected {
                                        Circle()
                                            .fill(ColorTokens.primaryStart.opacity(0.3))
                                            .frame(width: 32, height: 32)
                                    }

                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.system(size: 15, weight: isToday ? .bold : .medium))
                                        .foregroundColor(isToday ? .white : ColorTokens.textPrimary)
                                }

                                // Tasks indicator dots
                                if tasksCount > 0 {
                                    HStack(spacing: 2) {
                                        ForEach(0..<min(tasksCount, 3), id: \.self) { _ in
                                            Circle()
                                                .fill(ColorTokens.primaryStart)
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                } else {
                                    Spacer().frame(height: 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // Next week button
                Button(action: { viewModel.goToNextWeek() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(width: 32, height: 44)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Thin divider
            Rectangle()
                .fill(ColorTokens.border.opacity(0.3))
                .frame(height: 0.5)
        }
        .background(ColorTokens.background)
    }

    // Helper to get tasks for a specific date
    private func tasksForDate(_ date: Date) -> [CalendarTask] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)
        return viewModel.weekTasks.filter { $0.date == dateStr }
    }

    // MARK: - Hour Grid
    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    // Time label - compact
                    Text(String(format: "%02d", hour))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(ColorTokens.textMuted.opacity(0.6))
                        .frame(width: 24, alignment: .trailing)
                        .padding(.trailing, 4)

                    // Grid line - subtle
                    Rectangle()
                        .fill(ColorTokens.border.opacity(0.15))
                        .frame(height: 0.5)
                }
                .frame(height: hourHeight)
            }
        }
    }

    // MARK: - Tasks Overlay
    // Calculate Y offset for a task based on start time
    private func calculateYOffset(startTime: Date) -> CGFloat {
        let startHour = Calendar.current.component(.hour, from: startTime)
        let startMinute = Calendar.current.component(.minute, from: startTime)
        return CGFloat(startHour - hours.first!) * hourHeight + CGFloat(startMinute) / 60.0 * hourHeight
    }

    // Calculate height for a task
    private func calculateTaskHeight(startTime: Date, endTime: Date) -> CGFloat {
        let startHour = Calendar.current.component(.hour, from: startTime)
        let startMinute = Calendar.current.component(.minute, from: startTime)
        let endHour = Calendar.current.component(.hour, from: endTime)
        let endMinute = Calendar.current.component(.minute, from: endTime)

        let startOffset = CGFloat(startHour - hours.first!) * hourHeight + CGFloat(startMinute) / 60.0 * hourHeight
        let endOffset = CGFloat(endHour - hours.first!) * hourHeight + CGFloat(endMinute) / 60.0 * hourHeight
        return max(endOffset - startOffset, 30)
    }

    // Get display times for a task - use scheduled times or defaults based on timeBlock
    private func getDisplayTimes(for task: CalendarTask) -> (start: Date, end: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        // If task has scheduled times, use them
        if let startDate = task.startDate, let endDate = task.endDate {
            return (startDate, endDate)
        }

        // Otherwise, create default times based on timeBlock
        let defaultStart: String
        switch task.timeBlock {
        case "morning":
            defaultStart = "09:00"
        case "afternoon":
            defaultStart = "14:00"
        case "evening":
            defaultStart = "19:00"
        default:
            defaultStart = "09:00"
        }

        let duration = task.estimatedMinutes ?? 60
        let startDateStr = "\(task.date) \(defaultStart)"

        if let start = formatter.date(from: startDateStr) {
            let end = start.addingTimeInterval(TimeInterval(duration * 60))
            return (start, end)
        }

        // Fallback - today at 9am for 1 hour
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let end = start.addingTimeInterval(3600)
        return (start, end)
    }

    // MARK: - Day View Components

    // Tappable grid for day view (single column)
    private var dayViewTappableGrid: some View {
        GeometryReader { geometry in
            dayViewTappableGridContent(geometry: geometry)
        }
    }

    private func dayViewTappableGridContent(geometry: GeometryProxy) -> some View {
        let timeColumnWidth: CGFloat = 28
        let dayWidth = geometry.size.width - timeColumnWidth

        return ForEach(hours, id: \.self) { hour in
            Rectangle()
                .fill(Color.clear)
                .frame(width: dayWidth, height: hourHeight)
                .contentShape(Rectangle())
                .offset(x: timeColumnWidth, y: CGFloat(hour - (hours.first ?? 6)) * hourHeight)
                .onTapGesture {
                    handleDayViewTap(hour: hour)
                }
        }
    }

    private func handleDayViewTap(hour: Int) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: viewModel.selectedDate)
        let startTime = String(format: "%02d:00", hour)
        let endTime = String(format: "%02d:00", hour + 1)

        if !viewModel.hasOverlap(date: dateString, startTime: startTime, endTime: endTime) {
            quickCreateDate = viewModel.selectedDate
            quickCreateStartHour = hour
            quickCreateEndHour = hour + 1
            showQuickCreateSheet = true
        }
    }

    // Tasks overlay for day view (full width)
    private var dayTasksOverlay: some View {
        GeometryReader { geometry in
            dayTasksOverlayContent(geometry: geometry)
        }
    }

    private func dayTasksOverlayContent(geometry: GeometryProxy) -> some View {
        let timeColumnWidth: CGFloat = 28
        let dayWidth = geometry.size.width - timeColumnWidth
        let selectedDayTasks = tasksForDate(viewModel.selectedDate)

        return ZStack(alignment: .top) {
            Color.clear

            ForEach(selectedDayTasks) { task in
                dayTaskBlock(task: task, dayWidth: dayWidth, timeColumnWidth: timeColumnWidth)
            }
        }
    }

    private func dayTaskBlock(task: CalendarTask, dayWidth: CGFloat, timeColumnWidth: CGFloat) -> some View {
        let displayTimes = getDisplayTimes(for: task)
        let yOffset = calculateYOffset(startTime: displayTimes.start)
        let height = calculateTaskHeight(startTime: displayTimes.start, endTime: displayTimes.end)

        return DayTaskBlockView(
            task: task,
            onTap: { selectedTask = task },
            onStartFocus: { startFocusForTask(task) }
        )
        .frame(width: dayWidth - 16)
        .frame(height: height)
        .offset(x: timeColumnWidth + 8, y: yOffset)
    }

    // Current time indicator for day view
    private var dayViewCurrentTimeIndicator: some View {
        GeometryReader { geometry in
            let now = Date()
            let hour = Calendar.current.component(.hour, from: now)
            let minute = Calendar.current.component(.minute, from: now)
            let timeColumnWidth: CGFloat = 28

            if hour >= hours.first! && hour <= hours.last! {
                let yOffset = CGFloat(hour - hours.first!) * hourHeight + CGFloat(minute) / 60.0 * hourHeight

                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Rectangle()
                        .fill(Color.red.opacity(0.8))
                        .frame(height: 2)
                }
                .offset(x: timeColumnWidth - 4, y: yOffset)
            }
        }
    }

    // MARK: - Helpers
    private func calculateTaskPosition(startTime: Date, endTime: Date, dayWidth: CGFloat, dayIndex: Int, timeColumnWidth: CGFloat) -> (x: CGFloat, y: CGFloat, height: CGFloat) {
        let startHour = Calendar.current.component(.hour, from: startTime)
        let startMinute = Calendar.current.component(.minute, from: startTime)
        let endHour = Calendar.current.component(.hour, from: endTime)
        let endMinute = Calendar.current.component(.minute, from: endTime)

        let startOffset = CGFloat(startHour - hours.first!) * hourHeight + CGFloat(startMinute) / 60.0 * hourHeight
        let endOffset = CGFloat(endHour - hours.first!) * hourHeight + CGFloat(endMinute) / 60.0 * hourHeight
        let height = max(endOffset - startOffset, 30)

        let x = timeColumnWidth + CGFloat(dayIndex) * dayWidth + dayWidth / 2
        let y = startOffset + height / 2

        return (x: x, y: y, height: height)
    }

    private func handleTaskDrop(task: CalendarTask, translation: CGSize, geometry: GeometryProxy) {
        let timeColumnWidth: CGFloat = 28
        let dayWidth = (geometry.size.width - timeColumnWidth) / 7

        // Calculate new day index based on horizontal translation
        let dayDelta = Int(round(translation.width / dayWidth))
        let hourDelta = Int(round(translation.height / hourHeight))

        guard dayDelta != 0 || hourDelta != 0 else { return }
        guard let startTime = task.startDate, let endTime = task.endDate else { return }

        let currentDayIndex = viewModel.dayIndexForTask(task)
        let newDayIndex = max(0, min(6, currentDayIndex + dayDelta))

        // Calculate new date
        let newDate = viewModel.weekDays[newDayIndex]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let newDateStr = dateFormatter.string(from: newDate)

        // Calculate new times
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        var endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        startComponents.hour = max(6, min(23, (startComponents.hour ?? 0) + hourDelta))
        endComponents.hour = max(6, min(23, (endComponents.hour ?? 0) + hourDelta))

        let newStartTime = String(format: "%02d:%02d", startComponents.hour ?? 9, startComponents.minute ?? 0)
        let newEndTime = String(format: "%02d:%02d", endComponents.hour ?? 10, endComponents.minute ?? 0)

        Task {
            await viewModel.rescheduleTask(task.id, date: newDateStr, scheduledStart: newStartTime, scheduledEnd: newEndTime)
        }
    }

    private func startFocusForTask(_ task: CalendarTask) {
        // Navigate to fire mode with this task's quest
        router.navigateToFireMode(questId: task.questId, description: task.title)
    }
}

// MARK: - Day Task Block View
struct DayTaskBlockView: View {
    let task: CalendarTask
    let onTap: () -> Void
    let onStartFocus: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Left: Area icon
            if let areaIcon = task.areaIcon {
                Text(areaIcon)
                    .font(.system(size: 20))
            }

            // Center: Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Time range
                    Text(task.formattedTimeRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    // Quest name if available
                    if let questTitle = task.questTitle {
                        Text("• \(questTitle)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Right: Status icon or Focus button
            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            } else {
                Button(action: onStartFocus) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(taskColor)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private var taskColor: Color {
        if task.isCompleted {
            return Color.green
        }

        switch task.priorityEnum {
        case .urgent:
            return Color.red
        case .high:
            return Color.orange
        case .medium:
            return ColorTokens.primaryStart
        case .low:
            return Color.gray
        }
    }
}

// MARK: - Task Detail Sheet
struct TaskDetailSheet: View {
    let task: CalendarTask
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: AppRouter

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.lg) {
                // Task info
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    HStack {
                        if let areaIcon = task.areaIcon {
                            Text(areaIcon)
                                .font(.system(size: 32))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ColorTokens.textPrimary)

                            if let questTitle = task.questTitle {
                                Text(questTitle)
                                    .font(.system(size: 14))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(ColorTokens.textMuted)
                        Text(task.formattedTimeRange)
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    if let description = task.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Priority badge
                    HStack {
                        Text(task.priority.capitalized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(priorityColor)
                            .cornerRadius(12)

                        if task.isCompleted {
                            Text("common.completed".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.lg)

                Spacer()

                // Actions
                VStack(spacing: SpacingTokens.md) {
                    // Start Focus button
                    PrimaryButton("calendar.start_focus".localized, icon: "flame.fill") {
                        dismiss()
                        router.navigateToFireMode(questId: task.questId, description: task.title)
                    }

                    // Complete button
                    if !task.isCompleted {
                        Button(action: {
                            Task {
                                await viewModel.toggleTask(task.id)
                                dismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("calendar.mark_complete".localized)
                            }
                            .foregroundColor(Color.green)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(RadiusTokens.md)
                        }
                    }

                    // Delete button
                    Button(action: {
                        Task {
                            await viewModel.deleteTask(task.id)
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("common.delete".localized)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(RadiusTokens.md)
                    }
                }
            }
            .padding()
            .background(ColorTokens.background)
            .navigationTitle("calendar.task_detail".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var priorityColor: Color {
        switch task.priorityEnum {
        case .urgent: return Color.red
        case .high: return Color.red.opacity(0.8)
        case .medium: return Color.orange
        case .low: return Color.blue
        }
    }
}

// MARK: - Voice Input Sheet
struct VoiceInputSheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var userInput = ""
    @State private var isProcessing = false
    @State private var aiResponse: String?
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.xl) {
                // AI Assistant Header
                VStack(spacing: SpacingTokens.md) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(ColorTokens.primaryStart)

                    Text("voice.assistant_title".localized)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("voice.assistant_subtitle".localized)
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, SpacingTokens.xl)

                // AI Response (if any)
                if let response = aiResponse {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        HStack {
                            Text("voice.ai_response".localized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTokens.textMuted)
                        }

                        Text(response)
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.textPrimary)
                    }
                    .padding()
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
                }

                Spacer()

                // Text Input
                VStack(spacing: SpacingTokens.md) {
                    TextField("voice.input_placeholder".localized, text: $userInput, axis: .vertical)
                        .font(.system(size: 16))
                        .padding()
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.md)
                        .lineLimit(3...6)

                    // Send button
                    PrimaryButton(
                        isProcessing ? "voice.processing".localized : "voice.send".localized,
                        icon: isProcessing ? nil : "paperplane.fill",
                        isLoading: isProcessing
                    ) {
                        processVoiceInput()
                    }
                    .disabled(userInput.isEmpty || isProcessing)
                }
                .padding(.bottom, SpacingTokens.xl)
            }
            .padding(.horizontal, SpacingTokens.lg)
            .background(ColorTokens.background)
            .navigationTitle("voice.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func processVoiceInput() {
        guard !userInput.isEmpty else { return }

        isProcessing = true

        Task {
            do {
                let response = try await viewModel.processVoiceInput(userInput)
                aiResponse = response.ttsResponse

                if response.intentType == "ADD_GOAL" {
                    // Tasks created successfully
                    showConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                } else if response.intentType == "NEED_CLARIFICATION" {
                    // AI needs more info - keep sheet open
                    userInput = ""
                }
            } catch {
                aiResponse = "Une erreur s'est produite. Réessaie."
            }

            isProcessing = false
        }
    }
}

// MARK: - Quick Create Task Sheet
struct QuickCreateTaskSheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var startHour = 9
    @State private var endHour = 10
    @State private var selectedPriority = "medium"
    @State private var isCreating = false
    @FocusState private var isTitleFocused: Bool

    private let hours = Array(6...23)

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.lg) {
                // Title input
                TextField("calendar.task_title_placeholder".localized, text: $title)
                    .font(.system(size: 18))
                    .padding()
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
                    .focused($isTitleFocused)

                // Time picker
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("Horaire")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.textSecondary)

                    HStack(spacing: SpacingTokens.md) {
                        // Start time
                        VStack(spacing: 4) {
                            Text("Debut")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTokens.textMuted)
                            Picker("", selection: $startHour) {
                                ForEach(hours, id: \.self) { hour in
                                    Text(String(format: "%02d:00", hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                            .clipped()
                        }
                        .frame(maxWidth: .infinity)

                        Text("-")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(ColorTokens.textMuted)

                        // End time
                        VStack(spacing: 4) {
                            Text("Fin")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTokens.textMuted)
                            Picker("", selection: $endHour) {
                                ForEach(hours.filter { $0 > startHour }, id: \.self) { hour in
                                    Text(String(format: "%02d:00", hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                            .clipped()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
                }

                Spacer()

                // Create button
                PrimaryButton(
                    isCreating ? "common.creating".localized : "calendar.create_task".localized,
                    icon: isCreating ? nil : "plus",
                    isLoading: isCreating
                ) {
                    createTask()
                }
                .disabled(title.isEmpty || isCreating)
            }
            .padding()
            .background(ColorTokens.background)
            .navigationTitle("calendar.new_task".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isTitleFocused = true
                // Set default to current hour if within range
                let currentHour = Calendar.current.component(.hour, from: Date())
                if hours.contains(currentHour) {
                    startHour = currentHour
                    endHour = min(currentHour + 1, 23)
                }
            }
            .onChange(of: startHour) { _, newValue in
                if endHour <= newValue {
                    endHour = min(newValue + 1, 23)
                }
            }
        }
        .presentationDetents([.height(420)])
    }

    private func createTask() {
        guard !title.isEmpty else { return }
        isCreating = true

        let startTime = String(format: "%02d:00", startHour)
        let endTime = String(format: "%02d:00", endHour)

        Task {
            await viewModel.createTask(
                title: title,
                scheduledStart: startTime,
                scheduledEnd: endTime,
                priority: selectedPriority
            )
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

// MARK: - Quick Create Task Sheet with Time
struct QuickCreateTaskSheetWithTime: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let startHour: Int
    let endHour: Int

    @State private var title = ""
    @State private var isCreating = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.lg) {
                // Date & Time info
                VStack(spacing: SpacingTokens.sm) {
                    Text(date.formatted(.dateTime.weekday(.wide).day().month()))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("\(String(format: "%02d:00", startHour)) - \(String(format: "%02d:00", endHour))")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.textMuted)
                }
                .padding(.top, SpacingTokens.md)

                // Title input - simple and focused
                TextField("calendar.task_title_placeholder".localized, text: $title)
                    .font(.system(size: 18))
                    .padding()
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
                    .focused($isTitleFocused)

                Spacer()

                // Create button
                PrimaryButton(
                    isCreating ? "common.creating".localized : "common.add".localized,
                    icon: isCreating ? nil : "plus",
                    isLoading: isCreating
                ) {
                    createTask()
                }
                .disabled(title.isEmpty || isCreating)
            }
            .padding()
            .background(ColorTokens.background)
            .navigationTitle("calendar.quick_create".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
        .presentationDetents([.height(280)])
    }

    private func createTask() {
        guard !title.isEmpty else { return }
        isCreating = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)

        let scheduledStart = String(format: "%02d:00", startHour)
        let scheduledEnd = String(format: "%02d:00", endHour)

        // Determine time block from hour
        let timeBlock: String
        if startHour < 12 {
            timeBlock = "morning"
        } else if startHour < 18 {
            timeBlock = "afternoon"
        } else {
            timeBlock = "evening"
        }

        Task {
            await viewModel.createTask(
                title: title,
                date: dateStr,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
                timeBlock: timeBlock
            )
            // Wait for data to reload before dismissing
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}
