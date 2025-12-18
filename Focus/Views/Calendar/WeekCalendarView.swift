import SwiftUI

// MARK: - Week Calendar View (Modern Design)
struct WeekCalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var questsViewModel = QuestsViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showVoiceInput = false
    @State private var showCreateTaskSheet = false
    @State private var showQuickCreateSheet = false
    @State private var showAddRitualSheet = false
    @State private var showAddQuestSheet = false
    @State private var showAddMenu = false
    @State private var selectedTask: CalendarTask?
    @State private var draggedTask: CalendarTask?

    // Quick create state
    @State private var quickCreateDate: Date = Date()
    @State private var quickCreateStartHour: Int = 9
    @State private var quickCreateEndHour: Int = 10

    // Scroll state
    @State private var scrollPosition: Int?

    // Ellie-style sidebar state
    @State private var showSidebar = true
    @State private var draggedTaskId: String?

    // Hours to display (6am to 11pm)
    private let hours = Array(6...23)
    private let hourHeight: CGFloat = 60

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact header with week navigation + day selector
                ellieHeader

                // Main content: Sidebar + Calendar (Ellie-style split)
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Left: Task sidebar (unscheduled tasks)
                        if showSidebar {
                            taskSidebar
                                .frame(width: min(geometry.size.width * 0.35, 160))
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        // Right: Time blocking calendar
                        timeBlockingCalendar
                            .frame(maxWidth: .infinity)
                    }
                }
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
        .sheet(isPresented: $showAddRitualSheet) {
            AddRitualFromCalendarSheet(
                questsViewModel: questsViewModel,
                areas: questsViewModel.areas,
                selectedDate: viewModel.selectedDate
            )
        }
        .sheet(isPresented: $showAddQuestSheet) {
            AddQuestSheet(viewModel: questsViewModel, areas: questsViewModel.areas)
        }
        .onAppear {
            Task {
                await viewModel.loadWeekData()
            }
        }
        .onChange(of: router.calendarTargetDate) { _, targetDate in
            if let date = targetDate {
                // Navigate to the target date
                viewModel.selectDate(date)
                // Update week if target date is in a different week
                let targetWeekStart = date.startOfWeek
                if targetWeekStart != viewModel.weekStartDate {
                    viewModel.weekStartDate = targetWeekStart
                    Task {
                        await viewModel.loadWeekData()
                    }
                }
                // Clear the target date after navigation
                router.calendarTargetDate = nil
            }
        }
    }

    // MARK: - Tappable Grid for Quick Create
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        Button(action: {
            HapticFeedback.medium()
            showAddMenu = true
        }) {
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
                    .font(.satoshi(24, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(showAddMenu ? 45 : 0))
                    .animation(.spring(response: 0.3), value: showAddMenu)
            }
        }
        .confirmationDialog("calendar.add_new".localized, isPresented: $showAddMenu, titleVisibility: .visible) {
            Button(action: {
                showCreateTaskSheet = true
            }) {
                Label("calendar.add_task".localized, systemImage: "checkmark.circle")
            }

            Button(action: {
                showAddRitualSheet = true
            }) {
                Label("calendar.add_routine".localized, systemImage: "arrow.triangle.2.circlepath")
            }

            Button(action: {
                showAddQuestSheet = true
            }) {
                Label("calendar.add_quest".localized, systemImage: "target")
            }

            Button("common.cancel".localized, role: .cancel) { }
        } message: {
            Text("calendar.add_new_description".localized)
        }
    }

    // MARK: - Ellie-Style Header
    private var ellieHeader: some View {
        VStack(spacing: 0) {
            // Top row: Sidebar toggle + Date info + Actions
            HStack(spacing: 12) {
                // Sidebar toggle button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showSidebar.toggle()
                    }
                }) {
                    Image(systemName: showSidebar ? "sidebar.left" : "sidebar.leading")
                        .font(.satoshi(18))
                        .foregroundColor(ColorTokens.textSecondary)
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.formattedSelectedDate)
                        .font(.satoshi(16, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    // Task count summary
                    let scheduled = viewModel.scheduledTasks.count
                    let unscheduled = viewModel.unscheduledTasks.count
                    Text("\(scheduled) scheduled • \(unscheduled) to plan")
                        .font(.satoshi(12))
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()

                // Today button
                if !Calendar.current.isDateInToday(viewModel.selectedDate) {
                    Button(action: { viewModel.goToCurrentWeek(); viewModel.selectDate(Date()) }) {
                        Text("Today")
                            .font(.satoshi(13, weight: .semibold))
                            .foregroundColor(ColorTokens.primaryStart)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ColorTokens.primaryStart.opacity(0.15))
                            .cornerRadius(RadiusTokens.full)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Week days row
            HStack(spacing: 0) {
                // Previous week button
                Button(action: { viewModel.goToPreviousWeek() }) {
                    Image(systemName: "chevron.left")
                        .font(.satoshi(12, weight: .semibold))
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(width: 28, height: 40)
                }

                // Week days
                HStack(spacing: 0) {
                    ForEach(viewModel.weekDays, id: \.self) { date in
                        let isToday = Calendar.current.isDateInToday(date)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                        let itemCounts = totalItemsForDate(date)
                        let totalCount = itemCounts.total
                        let completedCount = itemCounts.completed

                        Button(action: { viewModel.selectDate(date) }) {
                            VStack(spacing: 2) {
                                Text(date.formatted(.dateTime.weekday(.narrow)).uppercased())
                                    .font(.satoshi(10, weight: .medium))
                                    .foregroundColor(isToday ? ColorTokens.primaryStart : ColorTokens.textMuted)

                                ZStack {
                                    if isToday {
                                        Circle()
                                            .fill(LinearGradient(colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 28, height: 28)
                                    } else if isSelected {
                                        Circle()
                                            .fill(ColorTokens.primaryStart.opacity(0.2))
                                            .frame(width: 28, height: 28)
                                    }

                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.system(size: 13, weight: isToday ? .bold : .medium))
                                        .foregroundColor(isToday ? .white : ColorTokens.textPrimary)
                                }

                                // Progress dot
                                if totalCount > 0 {
                                    Circle()
                                        .fill(completedCount == totalCount ? Color.green : ColorTokens.primaryStart.opacity(0.5))
                                        .frame(width: 4, height: 4)
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
                        .font(.satoshi(12, weight: .semibold))
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(width: 28, height: 40)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            // Divider
            Rectangle()
                .fill(ColorTokens.border.opacity(0.3))
                .frame(height: 0.5)
        }
        .background(ColorTokens.background)
    }

    // MARK: - Task Sidebar (Unscheduled Tasks)
    private var taskSidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack {
                Text("Tasks")
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Button(action: { showCreateTaskSheet = true }) {
                    Image(systemName: "plus")
                        .font(.satoshi(14, weight: .semibold))
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().opacity(0.3)

            // Unscheduled tasks list
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.unscheduledTasks.isEmpty {
                        // Empty state
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.satoshi(24))
                                .foregroundColor(ColorTokens.textMuted)
                            Text("All planned!")
                                .font(.satoshi(12, weight: .medium))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(viewModel.unscheduledTasks) { task in
                            SidebarTaskCard(
                                task: task,
                                onTap: { selectedTask = task },
                                onSchedule: { hour in
                                    Task {
                                        await viewModel.scheduleTaskAtHour(task, hour: hour)
                                    }
                                }
                            )
                            .draggable(task.id) {
                                // Drag preview
                                SidebarTaskCard(task: task, onTap: {}, onSchedule: { _ in })
                                    .frame(width: 140)
                                    .opacity(0.8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .background(ColorTokens.surface)
        .overlay(
            Rectangle()
                .fill(ColorTokens.border.opacity(0.3))
                .frame(width: 0.5),
            alignment: .trailing
        )
    }

    // MARK: - Time Blocking Calendar
    private var timeBlockingCalendar: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    dayViewTappableGrid
                    hourGrid
                    scheduledTasksOverlay

                    // Current time indicator only for today
                    if Calendar.current.isDateInToday(viewModel.selectedDate) {
                        dayViewCurrentTimeIndicator
                    }
                }
                .frame(height: CGFloat(hours.count) * hourHeight)
                .dropDestination(for: String.self) { items, location in
                    guard let taskId = items.first else { return false }
                    // Calculate hour from drop location
                    let hour = Int(location.y / hourHeight) + hours.first!
                    if let task = viewModel.weekTasks.first(where: { $0.id == taskId }) {
                        Task {
                            await viewModel.scheduleTaskAtHour(task, hour: max(hours.first!, min(hour, hours.last! - 1)))
                        }
                    }
                    return true
                }

                Spacer().frame(height: 80)
            }
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollPosition, anchor: .top)
        .onAppear { scrollToCurrentHour() }
        .onChange(of: viewModel.selectedDate) { _, _ in scrollToCurrentHour() }
    }

    // MARK: - Scheduled Tasks Overlay (for time blocking view)
    private var scheduledTasksOverlay: some View {
        let timeColumnWidth: CGFloat = 28

        return GeometryReader { geometry in
            let dayWidth = geometry.size.width - timeColumnWidth

            ForEach(viewModel.scheduledTasks) { task in
                let times = getDisplayTimes(for: task)

                DayTaskBlockView(
                    task: task,
                    onTap: { selectedTask = task },
                    onStartFocus: {
                        router.startFocusSession(
                            task: task,
                            questId: task.questId,
                            questTitle: task.questTitle
                        )
                    },
                    onComplete: { Task { await viewModel.toggleTask(task.id) } },
                    onUncomplete: { Task { await viewModel.toggleTask(task.id) } }
                )
                .frame(width: dayWidth - 8, height: calculateTaskHeight(startTime: times.start, endTime: times.end))
                .offset(x: timeColumnWidth + 4, y: calculateYOffset(startTime: times.start))
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await viewModel.unscheduleTask(task) }
                    } label: {
                        Label("Remove from calendar", systemImage: "calendar.badge.minus")
                    }
                }
            }

            // Rituals overlay
            ForEach(viewModel.scheduledRituals.filter { shouldShowRitual($0, on: viewModel.selectedDate) }) { ritual in
                if let times = getRitualDisplayTimes(for: ritual) {
                    DayRitualBlockView(
                        ritual: ritual,
                        isCompletedOnDate: viewModel.isRitualCompleted(ritual.id, on: viewModel.selectedDate),
                        onToggle: { Task { await viewModel.toggleRitual(ritual) } },
                        onStartFocus: {
                            router.navigate(to: .fire)
                        }
                    )
                    .frame(width: dayWidth - 8, height: calculateTaskHeight(startTime: times.start, endTime: times.end))
                    .offset(x: timeColumnWidth + 4, y: calculateYOffset(startTime: times.start))
                }
            }
        }
    }

    // MARK: - Modern Compact Header (Legacy - kept for reference)
    private var modernHeader: some View {
        VStack(spacing: 0) {
            // Combined: Navigation arrows + Week days in one row
            HStack(spacing: 0) {
                // Previous week button
                Button(action: { viewModel.goToPreviousWeek() }) {
                    Image(systemName: "chevron.left")
                        .font(.satoshi(14, weight: .semibold))
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(width: 32, height: 44)
                }

                // Week days
                HStack(spacing: 0) {
                    ForEach(viewModel.weekDays, id: \.self) { date in
                        let isToday = Calendar.current.isDateInToday(date)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                        // Use totalItemsForDate to include both tasks AND rituals
                        let itemCounts = totalItemsForDate(date)
                        let totalCount = itemCounts.total
                        let completedCount = itemCounts.completed
                        let allCompleted = totalCount > 0 && completedCount == totalCount

                        Button(action: { viewModel.selectDate(date) }) {
                            VStack(spacing: 3) {
                                // Day name
                                Text(date.formatted(.dateTime.weekday(.narrow)).uppercased())
                                    .font(.satoshi(11, weight: .medium))
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

                                // Items indicator dots - green when completed (tasks + rituals)
                                if totalCount > 0 {
                                    HStack(spacing: 2) {
                                        ForEach(0..<min(totalCount, 3), id: \.self) { index in
                                            Circle()
                                                .fill(index < completedCount ? Color.green : ColorTokens.primaryStart)
                                                .frame(width: 4, height: 4)
                                        }
                                        // Show checkmark if all completed
                                        if allCompleted && totalCount <= 3 {
                                            Image(systemName: "checkmark")
                                                .font(.satoshi(6, weight: .bold))
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
                        .font(.satoshi(14, weight: .semibold))
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

    // Helper to get rituals for a specific date (based on frequency)
    private func ritualsForDate(_ date: Date) -> [DailyRitual] {
        return viewModel.allRituals.filter { shouldShowRitual($0, on: date) }
    }

    // Combined count of tasks + rituals for week view indicators
    private func totalItemsForDate(_ date: Date) -> (total: Int, completed: Int) {
        let tasks = tasksForDate(date)
        let rituals = ritualsForDate(date)

        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.isCompleted }.count

        let totalRituals = rituals.count
        // Use per-date completion tracking instead of global isCompleted flag
        let completedRituals = rituals.filter { viewModel.isRitualCompleted($0.id, on: date) }.count

        return (totalTasks + totalRituals, completedTasks + completedRituals)
    }

    // MARK: - Hour Grid
    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Time label - compact, aligned at top of hour
                        Text(String(format: "%02d", hour))
                            .font(.satoshi(10, weight: .regular))
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
                .id(hour) // ID for ScrollViewReader
            }
        }
    }

    // MARK: - Scroll to Current Time
    private func scrollToCurrentHour() {
        let currentHour = Calendar.current.component(.hour, from: Date())

        // Determine target hour
        let targetHour: Int
        if Calendar.current.isDateInToday(viewModel.selectedDate) {
            // For today: scroll to 2 hours before current hour to center the current time indicator
            // Clamp to our visible range (6-23)
            targetHour = max(hours.first!, min(hours.last!, currentHour - 2))
        } else {
            // For other days: scroll to 8am (typical start of day)
            targetHour = 8
        }

        // Set scroll position after a small delay to ensure view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollPosition = targetHour
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
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")

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
                    let height = calculateTaskHeight(startTime: displayTimes.start, endTime: displayTimes.end)
                    // Check completion status for the selected date specifically
                    let isCompletedOnDate = viewModel.isRitualCompleted(ritual.id, on: viewModel.selectedDate)

                    DayRitualBlockView(
                        ritual: ritual,
                        isCompletedOnDate: isCompletedOnDate,
                        onToggle: {
                            Task {
                                await viewModel.toggleRitual(ritual)
                            }
                        },
                        onStartFocus: {
                            startFocusForRitual(ritual)
                        }
                    )
                    .padding(.leading, timeColumnWidth + 4)
                    .padding(.trailing, horizontalPadding)
                    .frame(height: max(44, height))
                    .offset(y: yOffset)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Get display times for a ritual based on selected date
    private func getRitualDisplayTimes(for ritual: DailyRitual) -> (start: Date, end: Date)? {
        guard let scheduledTime = ritual.scheduledTime else { return nil }

        // Check if ritual should show on the selected date based on frequency
        guard shouldShowRitual(ritual, on: viewModel.selectedDate) else { return nil }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: viewModel.selectedDate)

        // Parse the scheduled time (HH:mm format)
        let timeParts = scheduledTime.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else { return nil }

        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let startDate = calendar.date(from: components) else { return nil }
        let durationInSeconds = TimeInterval(ritual.displayDuration * 60)
        let endDate = startDate.addingTimeInterval(durationInSeconds)

        return (startDate, endDate)
    }

    // Check if ritual should show on a specific date
    private func shouldShowRitual(_ ritual: DailyRitual, on date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday

        switch ritual.frequency {
        case .daily:
            return true
        case .weekdays:
            return weekday >= 2 && weekday <= 6 // Monday to Friday
        case .weekends:
            return weekday == 1 || weekday == 7 // Sunday or Saturday
        case .weekly:
            return true // Show weekly rituals every day
        case .monday:
            return weekday == 2
        case .tuesday:
            return weekday == 3
        case .wednesday:
            return weekday == 4
        case .thursday:
            return weekday == 5
        case .friday:
            return weekday == 6
        case .saturday:
            return weekday == 7
        case .sunday:
            return weekday == 1
        }
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
        // Calculate duration based on task's estimated time or scheduled time
        var duration: Int? = nil
        if let estimatedMinutes = task.estimatedMinutes, estimatedMinutes > 0 {
            duration = estimatedMinutes
        } else if let startDate = task.startDate, let endDate = task.endDate {
            let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
            if minutes > 0 {
                duration = minutes
            }
        }

        // Navigate to fire mode with task data including taskId for post-session validation
        router.navigateToFireMode(
            duration: duration,
            questId: task.questId,
            description: task.title,
            taskId: task.id
        )
    }

    private func startFocusForRitual(_ ritual: DailyRitual) {
        // Use ritual duration or default to 25 minutes
        let duration = ritual.durationMinutes ?? 25

        // Navigate to fire mode with ritual data including ritualId for post-session validation
        router.navigateToFireMode(
            duration: duration,
            questId: nil,
            description: ritual.title,
            taskId: nil,
            ritualId: ritual.id  // Pass ritual ID for validation after focus session
        )
    }
}

// MARK: - Sidebar Task Card (for unscheduled tasks in Ellie-style sidebar)
struct SidebarTaskCard: View {
    let task: CalendarTask
    let onTap: () -> Void
    let onSchedule: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Task title
            Text(task.title)
                .font(.satoshi(13, weight: .medium))
                .foregroundColor(task.isCompleted ? ColorTokens.textMuted : ColorTokens.textPrimary)
                .strikethrough(task.isCompleted)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Quest tag if available
            if let questTitle = task.questTitle {
                Text(questTitle)
                    .font(.satoshi(10, weight: .medium))
                    .foregroundColor(taskColor.opacity(0.8))
                    .lineLimit(1)
            }

            // Time block indicator
            HStack(spacing: 4) {
                Image(systemName: timeBlockIcon)
                    .font(.satoshi(9))
                Text(task.timeBlock.capitalized)
                    .font(.satoshi(10))
            }
            .foregroundColor(ColorTokens.textMuted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(taskColor.opacity(0.15))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(taskColor.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.light()
            onTap()
        }
        .contextMenu {
            // Quick schedule options
            Menu {
                ForEach([9, 10, 11, 12, 14, 15, 16, 17, 18, 19], id: \.self) { hour in
                    Button(action: { onSchedule(hour) }) {
                        Label(String(format: "%02d:00", hour), systemImage: "clock")
                    }
                }
            } label: {
                Label("Schedule at...", systemImage: "calendar.badge.clock")
            }
        }
    }

    private var timeBlockIcon: String {
        switch task.timeBlock {
        case "morning": return "sunrise.fill"
        case "afternoon": return "sun.max.fill"
        case "evening": return "moon.fill"
        default: return "clock"
        }
    }

    private var taskColor: Color {
        if task.isCompleted { return .green }
        if let areaName = task.areaName?.lowercased() {
            switch areaName {
            case "health", "santé": return Color(hex: "#4CAF50") ?? .green
            case "learning", "apprentissage": return Color(hex: "#2196F3") ?? .blue
            case "career", "carrière": return Color(hex: "#FF9800") ?? .orange
            case "relationships", "relations": return Color(hex: "#E91E63") ?? .pink
            case "creativity", "créativité": return Color(hex: "#9C27B0") ?? .purple
            default: return Color(hex: "#607D8B") ?? .gray
            }
        }
        return ColorTokens.primaryStart
    }
}

// MARK: - Day Task Block View (with checkbox to complete/uncomplete)
struct DayTaskBlockView: View {
    let task: CalendarTask
    let onTap: () -> Void
    let onStartFocus: () -> Void
    var onComplete: (() -> Void)? = nil
    var onUncomplete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Left: Checkbox to toggle completion
            Button(action: {
                if task.isCompleted {
                    HapticFeedback.medium()
                    onUncomplete?()
                } else {
                    HapticFeedback.success()
                    onComplete?()
                }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.satoshi(24))
                    .foregroundColor(task.isCompleted ? .white : .white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Center: Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.satoshi(15, weight: .semibold))
                    .foregroundColor(.white)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Time range
                    Text(task.formattedTimeRange)
                        .font(.satoshi(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    // Quest name if available
                    if let questTitle = task.questTitle {
                        Text("• \(questTitle)")
                            .font(.satoshi(12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    // Photo indicator if task has photos
                    if let photosCount = task.photosCount, photosCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "camera.fill")
                                .font(.satoshi(10))
                            Text("\(photosCount)")
                                .font(.satoshi(10, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(RadiusTokens.full)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Focus button (only if not completed)
            if !task.isCompleted {
                Button(action: {
                    HapticFeedback.medium()
                    onStartFocus()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.satoshi(14))
                        Text("Focus")
                            .font(.satoshi(12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.25))
                    .cornerRadius(RadiusTokens.full)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(taskColor)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.light()
            onTap()
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

// MARK: - Ritual Block View for Calendar (with checkbox to complete/uncomplete)
struct DayRitualBlockView: View {
    let ritual: DailyRitual
    let isCompletedOnDate: Bool  // Per-date completion status
    let onToggle: () -> Void
    var onStartFocus: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            // Left: Checkbox to toggle completion
            Button(action: {
                if isCompletedOnDate {
                    HapticFeedback.medium()
                } else {
                    HapticFeedback.success()
                }
                onToggle()
            }) {
                Image(systemName: isCompletedOnDate ? "checkmark.circle.fill" : "circle")
                    .font(.satoshi(22))
                    .foregroundColor(isCompletedOnDate ? .white : .white.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Icon
            Text(ritual.icon)
                .font(.satoshi(18))

            // Ritual info
            VStack(alignment: .leading, spacing: 2) {
                Text(ritual.title)
                    .font(.satoshi(14, weight: .semibold))
                    .foregroundColor(.white)
                    .strikethrough(isCompletedOnDate)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let time = ritual.formattedScheduledTime {
                        Text(time)
                            .font(.satoshi(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Text("• \(ritual.frequency.displayName)")
                        .font(.satoshi(11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            // Focus button (only if not completed)
            if !isCompletedOnDate, let onFocus = onStartFocus {
                Button(action: {
                    HapticFeedback.medium()
                    onFocus()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.satoshi(12))
                        Text("Focus")
                            .font(.satoshi(11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.25))
                    .cornerRadius(RadiusTokens.full)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(ritualColor)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if let onTap = onTap {
                HapticFeedback.light()
                onTap()
            }
        }
    }

    private var ritualColor: Color {
        if isCompletedOnDate {
            return Color.green
        }
        // Purple/violet color for rituals to differentiate from tasks
        return Color(hex: "#7C3AED") ?? .purple
    }
}

// MARK: - Task Detail Sheet
struct TaskDetailSheet: View {
    let task: CalendarTask
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: AppRouter
    @State private var showPhotosSheet = false
    @State private var taskPhotos: [CommunityPostResponse] = []
    @State private var isLoadingPhotos = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.lg) {
                    // Task header
                    VStack(alignment: .leading, spacing: SpacingTokens.md) {
                        HStack(alignment: .top, spacing: SpacingTokens.md) {
                            if let areaIcon = task.areaIcon {
                                Text(areaIcon)
                                    .font(.satoshi(40))
                                    .frame(width: 56, height: 56)
                                    .background(ColorTokens.surface)
                                    .cornerRadius(RadiusTokens.md)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.satoshi(22, weight: .bold))
                                    .foregroundColor(ColorTokens.textPrimary)

                                // Time
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.satoshi(12))
                                    Text(task.formattedTimeRange)
                                        .font(.satoshi(14))
                                }
                                .foregroundColor(ColorTokens.textSecondary)
                            }

                            Spacer()
                        }

                        // Priority & Status badges
                        HStack(spacing: SpacingTokens.sm) {
                            Text(priorityLabel)
                                .font(.satoshi(12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(priorityColor)
                                .cornerRadius(12)

                            if task.isCompleted {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.satoshi(10))
                                    Text("common.completed".localized)
                                }
                                .font(.satoshi(12, weight: .medium))
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

                    // Description (if any)
                    if let description = task.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("task.description".localized)
                                .font(.satoshi(12, weight: .semibold))
                                .foregroundColor(ColorTokens.textMuted)
                                .textCase(.uppercase)

                            Text(description)
                                .font(.satoshi(14))
                                .foregroundColor(ColorTokens.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.lg)
                    }

                    // Associated Quest (if any)
                    if let questTitle = task.questTitle {
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("task.linked_quest".localized)
                                .font(.satoshi(12, weight: .semibold))
                                .foregroundColor(ColorTokens.textMuted)
                                .textCase(.uppercase)

                            HStack(spacing: SpacingTokens.md) {
                                Image(systemName: "target")
                                    .font(.satoshi(18))
                                    .foregroundColor(ColorTokens.primaryStart)
                                    .frame(width: 36, height: 36)
                                    .background(ColorTokens.primarySoft)
                                    .cornerRadius(RadiusTokens.sm)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(questTitle)
                                        .font(.satoshi(15, weight: .semibold))
                                        .foregroundColor(ColorTokens.textPrimary)

                                    if let areaName = task.areaName {
                                        Text(areaName)
                                            .font(.satoshi(12))
                                            .foregroundColor(ColorTokens.textMuted)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.satoshi(12))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.lg)
                    }

                    // Community Photos section
                    if let photosCount = task.photosCount, photosCount > 0 {
                        Button(action: { showPhotosSheet = true }) {
                            HStack(spacing: SpacingTokens.md) {
                                Image(systemName: "photo.stack.fill")
                                    .font(.satoshi(18))
                                    .foregroundColor(ColorTokens.primaryStart)
                                    .frame(width: 36, height: 36)
                                    .background(ColorTokens.primarySoft)
                                    .cornerRadius(RadiusTokens.sm)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("community.view_photos".localized)
                                        .font(.satoshi(15, weight: .semibold))
                                        .foregroundColor(ColorTokens.textPrimary)

                                    Text(String(format: "community.photos_count".localized, photosCount))
                                        .font(.satoshi(12))
                                        .foregroundColor(ColorTokens.textMuted)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.satoshi(12))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.lg)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer(minLength: SpacingTokens.xl)

                    // Actions
                    VStack(spacing: SpacingTokens.md) {
                        // Start Focus button
                        if !task.isCompleted {
                            PrimaryButton("calendar.start_focus".localized, icon: "flame.fill") {
                                dismiss()
                                router.navigateToFireMode(questId: task.questId, description: task.title, taskId: task.id)
                            }
                        }

                        // Complete/Uncomplete button
                        Button(action: {
                            Task {
                                await viewModel.toggleTask(task.id)
                                dismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: task.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
                                Text(task.isCompleted ? "task.mark_incomplete".localized : "calendar.mark_complete".localized)
                            }
                            .foregroundColor(task.isCompleted ? ColorTokens.textSecondary : Color.green)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(task.isCompleted ? ColorTokens.surface : Color.green.opacity(0.1))
                            .cornerRadius(RadiusTokens.md)
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
            }
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
        .sheet(isPresented: $showPhotosSheet) {
            TaskPhotosSheet(taskId: task.id)
        }
    }

    private var priorityColor: Color {
        switch task.priorityEnum {
        case .urgent: return Color.red
        case .high: return Color.red.opacity(0.8)
        case .medium: return Color.orange
        case .low: return Color.blue
        }
    }

    private var priorityLabel: String {
        switch task.priorityEnum {
        case .urgent: return "calendar.priority.urgent".localized
        case .high: return "calendar.priority.high".localized
        case .medium: return "calendar.priority.medium".localized
        case .low: return "calendar.priority.low".localized
        }
    }
}

// MARK: - Task Photos Sheet
struct TaskPhotosSheet: View {
    let taskId: String
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [CommunityPostResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let communityService = CommunityService()

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    VStack(spacing: SpacingTokens.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(ColorTokens.textSecondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                } else if photos.isEmpty {
                    VStack(spacing: SpacingTokens.md) {
                        Image(systemName: "photo.stack")
                            .font(.largeTitle)
                            .foregroundColor(ColorTokens.textSecondary)
                        Text("community.empty_feed".localized)
                            .font(.subheadline)
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: SpacingTokens.md) {
                            ForEach(photos) { post in
                                TaskPhotoCard(post: post)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("community.view_photos".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .task {
                await loadPhotos()
            }
        }
    }

    private func loadPhotos() async {
        isLoading = true
        do {
            photos = try await communityService.getTaskPosts(taskId: taskId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Task Photo Card
struct TaskPhotoCard: View {
    let post: CommunityPostResponse

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            // Header
            HStack(spacing: SpacingTokens.sm) {
                AsyncImage(url: URL(string: post.authorAvatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorPseudo ?? "User")
                        .font(.satoshi(14, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)
                    Text(post.createdAt.timeAgoDisplay())
                        .font(.satoshi(12))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()
            }

            // Image
            AsyncImage(url: URL(string: post.imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .clipped()
                        .cornerRadius(RadiusTokens.md)
                case .failure:
                    Rectangle()
                        .fill(ColorTokens.surface)
                        .frame(height: 250)
                        .cornerRadius(RadiusTokens.md)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(ColorTokens.textSecondary)
                        )
                default:
                    Rectangle()
                        .fill(ColorTokens.surface)
                        .frame(height: 250)
                        .cornerRadius(RadiusTokens.md)
                        .overlay(ProgressView())
                }
            }

            // Caption
            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.satoshi(14))
                    .foregroundColor(ColorTokens.textPrimary)
                    .lineLimit(3)
            }

            // Likes
            if post.likesCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.satoshi(12))
                        .foregroundColor(.red)
                    Text(String(format: "community.liked_by".localized, post.likesCount))
                        .font(.satoshi(12))
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }
        }
        .padding()
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
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
                        .font(.satoshi(64))
                        .foregroundColor(ColorTokens.primaryStart)

                    Text("voice.assistant_title".localized)
                        .font(.satoshi(20, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("voice.assistant_subtitle".localized)
                        .font(.satoshi(14))
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, SpacingTokens.xl)

                // AI Response (if any)
                if let response = aiResponse {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        HStack {
                            Text("voice.ai_response".localized)
                                .font(.satoshi(12, weight: .semibold))
                                .foregroundColor(ColorTokens.textMuted)
                        }

                        Text(response)
                            .font(.satoshi(14))
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
                        .font(.satoshi(16))
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
                    .font(.satoshi(18))
                    .padding()
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
                    .focused($isTitleFocused)

                // Time picker
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("Horaire")
                        .font(.satoshi(14, weight: .semibold))
                        .foregroundColor(ColorTokens.textSecondary)

                    HStack(spacing: SpacingTokens.md) {
                        // Start time
                        VStack(spacing: 4) {
                            Text("Debut")
                                .font(.satoshi(12))
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
                            .font(.satoshi(20, weight: .medium))
                            .foregroundColor(ColorTokens.textMuted)

                        // End time
                        VStack(spacing: 4) {
                            Text("Fin")
                                .font(.satoshi(12))
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
                        .font(.satoshi(20, weight: .medium))
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
                            .font(.satoshi(16))
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
                                .font(.satoshi(16, weight: .medium))
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
                                .font(.satoshi(16, weight: .medium))
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
                            .font(.satoshi(13, weight: .medium))
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
                            .font(.satoshi(16))
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
                                        .font(.satoshi(16))
                                    Text(quest.title)
                                        .font(.satoshi(15))
                                        .foregroundColor(ColorTokens.textPrimary)
                                        .lineLimit(1)
                                } else {
                                    Text("Lier à une quête")
                                        .font(.satoshi(15))
                                        .foregroundColor(ColorTokens.textMuted)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.satoshi(12))
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
                                .font(.satoshi(16))
                                .foregroundColor(ColorTokens.textMuted)
                                .frame(width: 24)

                            HStack(spacing: SpacingTokens.sm) {
                                Text(quest.area.emoji)
                                    .font(.satoshi(14))
                                Text(quest.area.localizedName)
                                    .font(.satoshi(14))
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
                                        .font(.satoshi(20))
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

// MARK: - Add Ritual From Calendar Sheet
struct AddRitualFromCalendarSheet: View {
    let questsViewModel: QuestsViewModel
    let areas: [Area]
    let selectedDate: Date
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var selectedIcon = "🌟"
    @State private var selectedAreaId: String?
    @State private var selectedFrequency = "daily"
    @State private var hasScheduledTime = true  // Default to true since we're in calendar
    @State private var scheduledTime: Date
    @State private var isLoading = false
    @State private var errorMessage: String?

    let frequencies = ["daily", "weekdays", "weekends", "weekly"]
    var frequencyLabels: [String] {
        ["routines.frequency.daily".localized, "routines.frequency.weekdays".localized, "routines.frequency.weekends".localized, "routines.frequency.weekly".localized]
    }
    let iconOptions = ["🌟", "💪", "📚", "🧘", "🏃", "💧", "🍎", "😴", "📝", "🎯", "💡", "🔥"]

    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    /// Convert Date to "HH:mm" string for API
    private var scheduledTimeString: String? {
        guard hasScheduledTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: scheduledTime)
    }

    init(questsViewModel: QuestsViewModel, areas: [Area], selectedDate: Date) {
        self.questsViewModel = questsViewModel
        self.areas = areas
        self.selectedDate = selectedDate
        // Default time based on current hour or 9 AM
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let defaultHour = currentHour >= 6 && currentHour < 22 ? currentHour + 1 : 9
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = defaultHour
        components.minute = 0
        _scheduledTime = State(initialValue: calendar.date(from: components) ?? now)
    }

    // Filter out placeholder areas
    private var validAreas: [Area] {
        areas.filter { !$0.id.hasPrefix("placeholder-") }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.xl) {
                        // Icon selector - Compact
                        iconSection

                        // Title input
                        titleSection

                        // Area selector
                        areaSection

                        // Frequency selector
                        frequencySection

                        // Scheduled time picker (important for calendar)
                        scheduledTimeSection

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .caption()
                                .foregroundColor(ColorTokens.error)
                        }

                        // Save button
                        PrimaryButton(
                            "routines.create".localized,
                            isLoading: isLoading,
                            isDisabled: title.isEmpty || selectedAreaId == nil
                        ) {
                            Task {
                                guard let areaId = selectedAreaId else { return }
                                isLoading = true
                                errorMessage = nil
                                let success = await questsViewModel.createRitual(
                                    areaId: areaId,
                                    title: title,
                                    frequency: selectedFrequency,
                                    icon: selectedIcon,
                                    scheduledTime: scheduledTimeString
                                )
                                isLoading = false
                                if success {
                                    HapticFeedback.success()
                                    dismiss()
                                } else {
                                    errorMessage = questsViewModel.errorMessage
                                }
                            }
                        }
                    }
                    .padding(SpacingTokens.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("calendar.new_routine".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
            .onAppear {
                hapticGenerator.prepare()
            }
        }
    }

    private func triggerHaptic() {
        hapticGenerator.impactOccurred()
        hapticGenerator.prepare()
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("routines.choose_icon".localized)
                    .subtitle()
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text(selectedIcon)
                    .font(.satoshi(32))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: SpacingTokens.sm) {
                ForEach(iconOptions, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        triggerHaptic()
                    }) {
                        Text(icon)
                            .font(.satoshi(24))
                            .frame(width: 44, height: 44)
                            .background(selectedIcon == icon ? ColorTokens.primarySoft : ColorTokens.surface)
                            .cornerRadius(RadiusTokens.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.md)
                                    .stroke(selectedIcon == icon ? ColorTokens.primaryStart : Color.clear, lineWidth: 2)
                            )
                    }
                }
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("routines.ritual_name".localized)
                .subtitle()
                .foregroundColor(ColorTokens.textPrimary)

            CustomTextField(
                placeholder: "routines.ritual_placeholder".localized,
                text: $title
            )
        }
    }

    private var areaSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("routines.life_area".localized)
                .subtitle()
                .foregroundColor(ColorTokens.textPrimary)

            if validAreas.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("routines.loading_areas".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
            } else {
                FlowLayout(spacing: SpacingTokens.sm) {
                    ForEach(validAreas) { area in
                        Button(action: {
                            selectedAreaId = area.id
                            triggerHaptic()
                        }) {
                            HStack(spacing: SpacingTokens.xs) {
                                Text(area.icon)
                                    .font(.satoshi(14))
                                Text(area.name)
                                    .font(.satoshi(13))
                            }
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.sm)
                            .background(selectedAreaId == area.id ? ColorTokens.primarySoft : ColorTokens.surface)
                            .foregroundColor(selectedAreaId == area.id ? ColorTokens.primaryStart : ColorTokens.textSecondary)
                            .cornerRadius(RadiusTokens.full)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.full)
                                    .stroke(selectedAreaId == area.id ? ColorTokens.primaryStart : ColorTokens.border, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("routines.frequency".localized)
                .subtitle()
                .foregroundColor(ColorTokens.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.sm) {
                    ForEach(Array(zip(frequencies, frequencyLabels)), id: \.0) { freq, label in
                        Button(action: {
                            selectedFrequency = freq
                            triggerHaptic()
                        }) {
                            Text(label)
                                .font(.satoshi(13, weight: selectedFrequency == freq ? .semibold : .regular))
                                .padding(.horizontal, SpacingTokens.md)
                                .padding(.vertical, SpacingTokens.sm)
                                .background(selectedFrequency == freq ? ColorTokens.primarySoft : ColorTokens.surface)
                                .foregroundColor(selectedFrequency == freq ? ColorTokens.primaryStart : ColorTokens.textSecondary)
                                .cornerRadius(RadiusTokens.sm)
                        }
                    }
                }
            }
        }
    }

    private var scheduledTimeSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("routines.scheduled_time".localized)
                    .subtitle()
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Toggle("", isOn: $hasScheduledTime)
                    .toggleStyle(SwitchToggleStyle(tint: ColorTokens.primaryStart))
                    .labelsHidden()
            }

            if hasScheduledTime {
                DatePicker(
                    "",
                    selection: $scheduledTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxHeight: 100)
                .padding(SpacingTokens.sm)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
            }

            Text("calendar.routine_time_hint".localized)
                .font(.satoshi(12))
                .foregroundColor(ColorTokens.textMuted)
        }
    }
}
