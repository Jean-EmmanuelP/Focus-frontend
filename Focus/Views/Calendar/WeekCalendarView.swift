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
                        let dayTasks = tasksForDate(date)
                        let tasksCount = dayTasks.count
                        let completedCount = dayTasks.filter { $0.isCompleted }.count
                        let allCompleted = tasksCount > 0 && completedCount == tasksCount
                        let hasCompletedTasks = completedCount > 0

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

                                // Tasks indicator dots - green when completed
                                if tasksCount > 0 {
                                    HStack(spacing: 2) {
                                        ForEach(0..<min(tasksCount, 3), id: \.self) { index in
                                            Circle()
                                                .fill(index < completedCount ? Color.green : ColorTokens.primaryStart)
                                                .frame(width: 4, height: 4)
                                        }
                                        // Show checkmark if all completed
                                        if allCompleted && tasksCount <= 3 {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 6, weight: .bold))
                                                .foregroundColor(Color.green)
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
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Time label - compact, aligned at top of hour
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
                    Spacer()
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
        // Minimum height of 56 to fit content (icon + title + time + button)
        return max(endOffset - startOffset, 56)
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

        // Check if slot is already occupied
        if viewModel.hasOverlap(date: dateString, startTime: startTime, endTime: endTime) {
            // Slot is occupied - give feedback
            HapticFeedback.error()
            return
        }

        quickCreateDate = viewModel.selectedDate
        quickCreateStartHour = hour
        quickCreateEndHour = hour + 1
        showQuickCreateSheet = true
    }

    // Tasks overlay for day view (full width)
    private var dayTasksOverlay: some View {
        let selectedDayTasks = tasksForDate(viewModel.selectedDate)
        let timeColumnWidth: CGFloat = 28
        let horizontalPadding: CGFloat = 16

        return ZStack(alignment: .topLeading) {
            // Tasks
            ForEach(selectedDayTasks) { task in
                let displayTimes = getDisplayTimes(for: task)
                let yOffset = calculateYOffset(startTime: displayTimes.start)
                let height = calculateTaskHeight(startTime: displayTimes.start, endTime: displayTimes.end)

                DayTaskBlockView(
                    task: task,
                    onTap: { selectedTask = task },
                    onStartFocus: { startFocusForTask(task) },
                    onComplete: {
                        Task {
                            await viewModel.toggleTask(task.id)
                        }
                    },
                    onUncomplete: {
                        Task {
                            await viewModel.toggleTask(task.id)
                        }
                    }
                )
                .padding(.leading, timeColumnWidth + 4)
                .padding(.trailing, horizontalPadding)
                .frame(height: height)
                .offset(y: yOffset)
            }

            // Rituals with scheduled time
            ForEach(viewModel.scheduledRituals) { ritual in
                if let displayTimes = getRitualDisplayTimes(for: ritual) {
                    let yOffset = calculateYOffset(startTime: displayTimes.start)

                    DayRitualBlockView(
                        ritual: ritual,
                        onToggle: {
                            Task {
                                await viewModel.toggleRitual(ritual)
                            }
                        }
                    )
                    .padding(.leading, timeColumnWidth + 4)
                    .padding(.trailing, horizontalPadding)
                    .frame(height: 44)
                    .offset(y: yOffset)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Get display times for a ritual
    private func getRitualDisplayTimes(for ritual: DailyRitual) -> (start: Date, end: Date)? {
        guard let scheduledTime = ritual.scheduledTime else { return nil }

        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)

        // Parse the scheduled time (HH:mm format)
        let timeParts = scheduledTime.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else { return nil }

        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let startDate = calendar.date(from: components) else { return nil }
        let endDate = startDate.addingTimeInterval(30 * 60) // 30 minute duration

        return (startDate, endDate)
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

// MARK: - Day Task Block View (with swipe to complete/uncomplete)
struct DayTaskBlockView: View {
    let task: CalendarTask
    let onTap: () -> Void
    let onStartFocus: () -> Void
    var onComplete: (() -> Void)? = nil
    var onUncomplete: (() -> Void)? = nil

    @State private var swipeOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            // Background action - left side (undo) for completed tasks
            if swipeOffset > 0 && task.isCompleted {
                HStack {
                    ZStack(alignment: .leading) {
                        Color.orange
                            .cornerRadius(12)
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("Annuler")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 20)
                    }
                    .frame(width: max(100, swipeOffset + 20))
                    Spacer()
                }
            }

            // Background action - right side (complete) for incomplete tasks
            if swipeOffset < 0 && !task.isCompleted {
                HStack {
                    Spacer()
                    ZStack(alignment: .trailing) {
                        Color.green
                            .cornerRadius(12)
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("Valider")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 20)
                    }
                    .frame(width: max(100, -swipeOffset + 20))
                }
            }

            // Main task card
            HStack(spacing: 12) {
                // Left: Area icon (emoji when completed, area emoji otherwise)
                if task.isCompleted {
                    Text("✅")
                        .font(.system(size: 20))
                } else if let areaIcon = task.areaIcon {
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

                // Right: Focus button (only if not completed)
                if !task.isCompleted {
                    Button(action: {
                        HapticFeedback.medium()
                        onStartFocus()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                            Text("Focus")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(RadiusTokens.full)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(taskColor)
            .cornerRadius(12)
            .offset(x: swipeOffset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            if task.isCompleted {
                                // Completed task: allow right swipe to undo
                                if value.translation.width > 0 {
                                    swipeOffset = min(value.translation.width, 150)
                                }
                            } else {
                                // Incomplete task: allow left swipe to complete
                                if value.translation.width < 0 {
                                    swipeOffset = max(value.translation.width, -150)
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        if task.isCompleted && swipeOffset > swipeThreshold {
                            // Undo completion
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                swipeOffset = 0
                            }
                            HapticFeedback.medium()
                            onUncomplete?()
                        } else if !task.isCompleted && swipeOffset < -swipeThreshold {
                            // Complete task
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                swipeOffset = 0
                            }
                            HapticFeedback.success()
                            onComplete?()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                swipeOffset = 0
                            }
                        }
                    }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if swipeOffset == 0 {
                    onTap()
                }
            }
        }
    }

    // Task color based on area or green if completed
    private var taskColor: Color {
        // Green for completed tasks
        if task.isCompleted {
            return Color.green
        }

        // Color based on area
        if let areaName = task.areaName?.lowercased() {
            switch areaName {
            case "health", "santé":
                return Color(hex: "#4CAF50") ?? .green // Green
            case "learning", "apprentissage":
                return Color(hex: "#2196F3") ?? .blue // Blue
            case "career", "carrière":
                return Color(hex: "#FF9800") ?? .orange // Orange
            case "relationships", "relations":
                return Color(hex: "#E91E63") ?? .pink // Pink
            case "creativity", "créativité":
                return Color(hex: "#9C27B0") ?? .purple // Purple
            default:
                return Color(hex: "#607D8B") ?? .gray // Gray for other
            }
        }

        // Default color if no area
        return ColorTokens.primaryStart
    }
}

// MARK: - Ritual Block View for Calendar
struct DayRitualBlockView: View {
    let ritual: DailyRitual
    let onToggle: () -> Void

    @State private var swipeOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            // Background action - left side (undo) for completed rituals
            if swipeOffset > 0 && ritual.isCompleted {
                HStack {
                    ZStack(alignment: .leading) {
                        Color.orange
                            .cornerRadius(12)
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("Annuler")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 12)
                    }
                    .frame(width: max(80, swipeOffset + 16))
                    Spacer()
                }
            }

            // Background action - right side (complete) for incomplete rituals
            if swipeOffset < 0 && !ritual.isCompleted {
                HStack {
                    Spacer()
                    ZStack(alignment: .trailing) {
                        Color.green
                            .cornerRadius(12)
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("Fait")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 12)
                    }
                    .frame(width: max(80, -swipeOffset + 16))
                }
            }

            // Main ritual card
            HStack(spacing: 10) {
                // Icon
                Text(ritual.isCompleted ? "✅" : ritual.icon)
                    .font(.system(size: 18))

                // Ritual info
                VStack(alignment: .leading, spacing: 2) {
                    Text(ritual.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let time = ritual.scheduledTime {
                        Text(time)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // "Routine" label to differentiate from tasks
                Text("Routine")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(RadiusTokens.full)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(ritualColor)
            .cornerRadius(10)
            .offset(x: swipeOffset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            if ritual.isCompleted {
                                if value.translation.width > 0 {
                                    swipeOffset = min(value.translation.width, 120)
                                }
                            } else {
                                if value.translation.width < 0 {
                                    swipeOffset = max(value.translation.width, -120)
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        if (ritual.isCompleted && swipeOffset > swipeThreshold) ||
                           (!ritual.isCompleted && swipeOffset < -swipeThreshold) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                swipeOffset = 0
                            }
                            HapticFeedback.success()
                            onToggle()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                swipeOffset = 0
                            }
                        }
                    }
            )
        }
    }

    private var ritualColor: Color {
        if ritual.isCompleted {
            return Color.green.opacity(0.8)
        }

        // Color based on category
        switch ritual.category {
        case .health:
            return Color(hex: "#4CAF50").opacity(0.85)
        case .learning:
            return Color(hex: "#2196F3").opacity(0.85)
        case .career:
            return Color(hex: "#FF9800").opacity(0.85)
        case .relationships:
            return Color(hex: "#E91E63").opacity(0.85)
        case .creativity:
            return Color(hex: "#9C27B0").opacity(0.85)
        case .other:
            return Color(hex: "#607D8B").opacity(0.85)
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

// MARK: - Quick Create Task Sheet with Time (Improved UX)
struct QuickCreateTaskSheetWithTime: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let startHour: Int
    let endHour: Int

    @State private var title = ""
    @State private var selectedQuestId: String?
    @State private var selectedStartHour: Int
    @State private var selectedEndHour: Int
    @State private var isCreating = false
    @State private var showQuestPicker = false
    @FocusState private var isTitleFocused: Bool

    private let hours = Array(6...23)

    init(viewModel: CalendarViewModel, date: Date, startHour: Int, endHour: Int) {
        self.viewModel = viewModel
        self.date = date
        self.startHour = startHour
        self.endHour = endHour
        _selectedStartHour = State(initialValue: startHour)
        _selectedEndHour = State(initialValue: endHour)
    }

    // Get area from selected quest
    private var selectedQuest: Quest? {
        guard let questId = selectedQuestId else { return nil }
        return viewModel.quests.first { $0.id == questId }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title input at top - big and focused
                VStack(spacing: SpacingTokens.sm) {
                    TextField("Que vas-tu faire ?", text: $title)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(ColorTokens.textPrimary)
                        .focused($isTitleFocused)
                        .submitLabel(.done)

                    Rectangle()
                        .fill(isTitleFocused ? ColorTokens.primaryStart : ColorTokens.border)
                        .frame(height: isTitleFocused ? 2 : 1)
                }
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.top, SpacingTokens.lg)
                .padding(.bottom, SpacingTokens.xl)

                // Quick options
                VStack(spacing: SpacingTokens.md) {
                    // Time selector - compact
                    HStack(spacing: SpacingTokens.md) {
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                            .foregroundColor(ColorTokens.textMuted)
                            .frame(width: 24)

                        // Start time picker
                        Menu {
                            ForEach(hours, id: \.self) { hour in
                                Button(String(format: "%02d:00", hour)) {
                                    selectedStartHour = hour
                                    if selectedEndHour <= hour {
                                        selectedEndHour = min(hour + 1, 23)
                                    }
                                }
                            }
                        } label: {
                            Text(String(format: "%02d:00", selectedStartHour))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ColorTokens.textPrimary)
                                .padding(.horizontal, SpacingTokens.md)
                                .padding(.vertical, SpacingTokens.sm)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.sm)
                        }

                        Text("-")
                            .foregroundColor(ColorTokens.textMuted)

                        // End time picker
                        Menu {
                            ForEach(hours.filter { $0 > selectedStartHour }, id: \.self) { hour in
                                Button(String(format: "%02d:00", hour)) {
                                    selectedEndHour = hour
                                }
                            }
                        } label: {
                            Text(String(format: "%02d:00", selectedEndHour))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ColorTokens.textPrimary)
                                .padding(.horizontal, SpacingTokens.md)
                                .padding(.vertical, SpacingTokens.sm)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.sm)
                        }

                        Spacer()

                        // Duration badge
                        let duration = selectedEndHour - selectedStartHour
                        Text("\(duration)h")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ColorTokens.primaryStart)
                            .padding(.horizontal, SpacingTokens.sm)
                            .padding(.vertical, 4)
                            .background(ColorTokens.primarySoft)
                            .cornerRadius(RadiusTokens.full)
                    }
                    .padding(.horizontal, SpacingTokens.lg)

                    // Quest selector
                    HStack(spacing: SpacingTokens.md) {
                        Image(systemName: "target")
                            .font(.system(size: 16))
                            .foregroundColor(ColorTokens.textMuted)
                            .frame(width: 24)

                        Button(action: {
                            // Load quests before showing picker
                            Task {
                                await viewModel.loadQuestsIfNeeded()
                            }
                            showQuestPicker = true
                        }) {
                            HStack {
                                if let quest = selectedQuest {
                                    Text(quest.area.emoji)
                                        .font(.system(size: 16))
                                    Text(quest.title)
                                        .font(.system(size: 15))
                                        .foregroundColor(ColorTokens.textPrimary)
                                        .lineLimit(1)
                                } else {
                                    Text("Lier à une quête")
                                        .font(.system(size: 15))
                                        .foregroundColor(ColorTokens.textMuted)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.sm)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.sm)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.lg)

                    // Show area if quest selected
                    if let quest = selectedQuest {
                        HStack(spacing: SpacingTokens.md) {
                            Image(systemName: "folder")
                                .font(.system(size: 16))
                                .foregroundColor(ColorTokens.textMuted)
                                .frame(width: 24)

                            HStack(spacing: SpacingTokens.sm) {
                                Text(quest.area.emoji)
                                    .font(.system(size: 14))
                                Text(quest.area.localizedName)
                                    .font(.system(size: 14))
                                    .foregroundColor(ColorTokens.textSecondary)
                            }
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.sm)
                            .background(ColorTokens.surfaceElevated)
                            .cornerRadius(RadiusTokens.sm)

                            Spacer()
                        }
                        .padding(.horizontal, SpacingTokens.lg)
                    }
                }

                Spacer()

                // Create button - always visible
                PrimaryButton(
                    isCreating ? "Création..." : "Ajouter",
                    icon: isCreating ? nil : "plus",
                    isLoading: isCreating
                ) {
                    createTask()
                }
                .disabled(title.isEmpty || isCreating)
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.bottom, SpacingTokens.lg)
            }
            .background(ColorTokens.background)
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).day().month()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
            }
            .sheet(isPresented: $showQuestPicker) {
                QuestPickerSheet(
                    quests: viewModel.quests,
                    selectedQuestId: $selectedQuestId
                )
                .presentationDetents([.medium])
            }
        }
        .presentationDetents([.height(380)])
    }

    private func createTask() {
        guard !title.isEmpty else { return }
        isCreating = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)

        let scheduledStart = String(format: "%02d:00", selectedStartHour)
        let scheduledEnd = String(format: "%02d:00", selectedEndHour)

        // Determine time block from hour
        let timeBlock: String
        if selectedStartHour < 12 {
            timeBlock = "morning"
        } else if selectedStartHour < 18 {
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
                timeBlock: timeBlock,
                questId: selectedQuestId
            )
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

// MARK: - Quest Picker Sheet
struct QuestPickerSheet: View {
    let quests: [Quest]
    @Binding var selectedQuestId: String?
    @Environment(\.dismiss) private var dismiss

    // Filter out "Other" area quests
    private var filteredQuests: [Quest] {
        quests.filter { $0.area != .other }
    }

    var body: some View {
        NavigationStack {
            List {
                // No quest option
                Button(action: {
                    selectedQuestId = nil
                    dismiss()
                }) {
                    HStack {
                        Text("Aucune quête")
                            .foregroundColor(ColorTokens.textSecondary)
                        Spacer()
                        if selectedQuestId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(ColorTokens.primaryStart)
                        }
                    }
                }

                // Group quests by area (excluding "Other")
                let questsByArea = Dictionary(grouping: filteredQuests) { $0.area.localizedName }
                ForEach(questsByArea.keys.sorted(), id: \.self) { areaName in
                    Section(header: Text(areaName)) {
                        ForEach(questsByArea[areaName] ?? []) { quest in
                            Button(action: {
                                selectedQuestId = quest.id
                                dismiss()
                            }) {
                                HStack {
                                    Text(quest.area.emoji)
                                        .font(.system(size: 20))
                                    Text(quest.title)
                                        .foregroundColor(ColorTokens.textPrimary)
                                    Spacer()
                                    if selectedQuestId == quest.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(ColorTokens.primaryStart)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choisir une quête")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        dismiss()
                    }
                }
            }
        }
    }
}

