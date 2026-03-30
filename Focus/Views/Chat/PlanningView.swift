import SwiftUI

// MARK: - Full-Screen Planning View

struct PlanningView: View {
    @EnvironmentObject var store: FocusAppStore
    @Environment(\.dismiss) private var dismiss

    @State private var tasks: [CalendarTask] = []
    @State private var rituals: [DailyRitual] = []
    @State private var isInitialLoading = true
    @State private var showAddTask = false
    @State private var showAddRitual = false
    @State private var taskToDelete: CalendarTask?
    @State private var ritualToDelete: DailyRitual?
    @State private var isSyncing = false
    @State private var syncFeedback: String?
    @State private var selectedDate: Date = Date()
    @State private var tasksCache: [String: [CalendarTask]] = [:]
    @State private var ritualsCache: [DailyRitual]? = nil
    @State private var showVoicePlanningSheet = false
    @State private var showVoiceCall = false
    @State private var voicePlanningScope: String = "today"

    // Background color matching chat screen avatar background
    private let bgColor = Color(red: 0.10, green: 0.12, blue: 0.20)

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    private var selectedDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: selectedDate)
    }

    private var completedTasks: Int { tasks.filter { $0.isCompleted }.count }
    private var completedRituals: Int { rituals.filter { $0.isCompleted }.count }
    private var totalItems: Int { tasks.count + (isToday ? rituals.count : 0) }
    private var completedItems: Int { completedTasks + (isToday ? completedRituals : 0) }
    private var progress: Double {
        totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0
    }

    // Group tasks by time block
    private var morningTasks: [CalendarTask] { tasks.filter { $0.timeBlock == "morning" } }
    private var afternoonTasks: [CalendarTask] { tasks.filter { $0.timeBlock == "afternoon" } }
    private var eveningTasks: [CalendarTask] { tasks.filter { $0.timeBlock == "evening" } }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if isInitialLoading {
                ProgressView()
                    .tint(.white)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        progressHeader

                        dateStrip

                        // Tasks by time block
                        if !morningTasks.isEmpty {
                            timeBlockSection(title: "Matin", icon: "sunrise.fill", color: .orange, blockTasks: morningTasks)
                        }
                        if !afternoonTasks.isEmpty {
                            timeBlockSection(title: "Après-midi", icon: "sun.max.fill", color: .yellow, blockTasks: afternoonTasks)
                        }
                        if !eveningTasks.isEmpty {
                            timeBlockSection(title: "Soir", icon: "moon.fill", color: .indigo, blockTasks: eveningTasks)
                        }

                        let unscheduled = tasks.filter { !["morning", "afternoon", "evening"].contains($0.timeBlock) }
                        if !unscheduled.isEmpty {
                            timeBlockSection(title: "Autres", icon: "tray.fill", color: .gray, blockTasks: unscheduled)
                        }

                        addButton(title: "Ajouter une tâche") {
                            showAddTask = true
                        }

                        if isToday {
                            ritualsSection

                            addButton(title: "Ajouter un rituel") {
                                showAddRitual = true
                            }
                        }

                        if tasks.isEmpty && (isToday ? rituals.isEmpty : true) {
                            emptyState
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 8)
                }
                .transition(.opacity)
            }

            // Top bar overlay
            VStack {
                topBar
                Spacer()
            }

            // Sync feedback toast
            if let feedback = syncFeedback {
                VStack {
                    Spacer()
                    Text(feedback)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                )
                        )
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: syncFeedback)
            }
        }
        .task {
            await loadData()
            await preloadWeekDots()
        }
        .alert("Supprimer cette tâche ?", isPresented: Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            Button("Annuler", role: .cancel) { taskToDelete = nil }
            Button("Supprimer", role: .destructive) {
                if let task = taskToDelete {
                    performDeleteTask(task)
                    taskToDelete = nil
                }
            }
        } message: {
            if let task = taskToDelete {
                Text("« \(task.title) » sera supprimée définitivement.")
            }
        }
        .alert("Supprimer ce rituel ?", isPresented: Binding(
            get: { ritualToDelete != nil },
            set: { if !$0 { ritualToDelete = nil } }
        )) {
            Button("Annuler", role: .cancel) { ritualToDelete = nil }
            Button("Supprimer", role: .destructive) {
                if let ritual = ritualToDelete {
                    performDeleteRitual(ritual)
                    ritualToDelete = nil
                }
            }
        } message: {
            if let ritual = ritualToDelete {
                Text("« \(ritual.title) » sera supprimé définitivement.")
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(bgColor: bgColor) { title, timeBlock, scheduledStart, estimatedMinutes in
                await createTask(title: title, timeBlock: timeBlock, scheduledStart: scheduledStart, estimatedMinutes: estimatedMinutes)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddRitual) {
            AddRitualSheet(
                bgColor: bgColor,
                areas: store.areas.filter { !$0.id.hasPrefix("placeholder-") }
            ) { title, icon, areaId, scheduledTime in
                await createRitual(title: title, icon: icon, areaId: areaId, scheduledTime: scheduledTime)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showVoicePlanningSheet) {
            VoicePlanningScopeSheet(bgColor: bgColor) { scope in
                voicePlanningScope = scope
                showVoicePlanningSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showVoiceCall = true
                }
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showVoiceCall) {
            VoiceCallView(mode: "planning", planningScope: voicePlanningScope)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }

            Spacer()

            Text("Planning")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 8) {
                // Voice planning button
                Button {
                    showVoicePlanningSheet = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }

                // Sync Google Calendar button
                Button {
                    syncCalendar()
                } label: {
                    if isSyncing {
                        ProgressView()
                            .tint(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                }
                .disabled(isSyncing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            bgColor.opacity(0.85)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 52)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.white.opacity(0.9),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)

                VStack(spacing: 2) {
                    Text("\(completedItems)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("/ \(totalItems)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(width: 90, height: 90)

            Text(selectedDateFormatted)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let dayNameFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "fr_FR")
            f.dateFormat = "EEE"
            return f
        }()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let isDayToday = calendar.isDateInToday(day)

                    Button {
                        selectedDate = day
                        // Show cached data instantly
                        let dateKey = {
                            let f = DateFormatter()
                            f.dateFormat = "yyyy-MM-dd"
                            return f.string(from: day)
                        }()
                        if let cached = tasksCache[dateKey] {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                tasks = cached
                            }
                        }
                        if Calendar.current.isDateInToday(day), let cachedRituals = ritualsCache {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                rituals = cachedRituals
                            }
                        } else if !Calendar.current.isDateInToday(day) {
                            rituals = []
                        }
                        Task { await loadData() }
                    } label: {
                        VStack(spacing: 2) {
                            VStack(spacing: 4) {
                                Text(isDayToday ? "Auj." : dayNameFormatter.string(from: day).capitalized)
                                    .font(.system(size: 11, weight: .medium))
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.system(size: 17, weight: isSelected ? .bold : .semibold, design: .rounded))
                            }
                            .foregroundColor(isSelected ? bgColor : .white.opacity(isDayToday ? 0.9 : 0.5))
                            .frame(width: 48, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.06))
                            )

                            // Task indicator dot
                            let dateKey = {
                                let f = DateFormatter()
                                f.dateFormat = "yyyy-MM-dd"
                                return f.string(from: day)
                            }()
                            if let cached = tasksCache[dateKey], !cached.isEmpty {
                                let allDone = cached.allSatisfy { $0.isCompleted }
                                Circle()
                                    .fill(allDone ? Color.green : Color.orange)
                                    .frame(width: 5, height: 5)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Time Block Section

    private func timeBlockSection(title: String, icon: String, color: Color, blockTasks: [CalendarTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                let done = blockTasks.filter { $0.isCompleted }.count
                Text("\(done)/\(blockTasks.count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(blockTasks) { task in
                    taskRow(task)

                    if task.id != blockTasks.last?.id {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 54)
                    }
                }
            }
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Task Row

    private func taskRow(_ task: CalendarTask) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleTask(task)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(task.isCompleted ? Color.clear : Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if task.isCompleted {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(bgColor)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 15, weight: task.isCompleted ? .regular : .medium))
                    .foregroundColor(task.isCompleted ? .white.opacity(0.3) : .white.opacity(0.9))
                    .strikethrough(task.isCompleted, color: .white.opacity(0.2))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let start = task.scheduledStart {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(start)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.35))
                    }
                    if let est = task.estimatedMinutes, est > 0 {
                        Text("\(est) min")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    if task.priority == "high" {
                        Text("!")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.23))
                    }
                }
            }

            Spacer()

            Button {
                taskToDelete = task
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
    }

    // MARK: - Rituals Section

    private var ritualsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "repeat")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.31, green: 0.80, blue: 0.77))
                Text("Rituels")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if !rituals.isEmpty {
                    let done = rituals.filter { $0.isCompleted }.count
                    Text("\(done)/\(rituals.count)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 20)

            if !rituals.isEmpty {
                VStack(spacing: 0) {
                    ForEach(rituals) { ritual in
                        ritualRow(ritual)

                        if ritual.id != rituals.last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.leading, 54)
                        }
                    }
                }
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Ritual Row

    private func ritualRow(_ ritual: DailyRitual) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleRitual(ritual)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ritual.isCompleted ? Color.clear : Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if ritual.isCompleted {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.31, green: 0.80, blue: 0.77))
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            Text(ritual.icon)
                .font(.system(size: 16))

            Text(ritual.title)
                .font(.system(size: 15, weight: ritual.isCompleted ? .regular : .medium))
                .foregroundColor(ritual.isCompleted ? .white.opacity(0.3) : .white.opacity(0.9))
                .strikethrough(ritual.isCompleted, color: .white.opacity(0.2))
                .lineLimit(2)

            Spacer()

            if let time = ritual.scheduledTime {
                Text(time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }

            Button {
                ritualToDelete = ritual
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
    }

    // MARK: - Add Button

    private func addButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)

            Image(systemName: "checklist")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))

            Text(isToday ? "Aucune tâche pour aujourd'hui" : "Aucune tâche prévue")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            let companion = store.user?.companionName ?? "Kai"
            Text(isToday
                 ? "Demande à \(companion) de planifier ta journée !"
                 : "Ajoute des tâches ou demande à \(companion) de planifier !")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private var selectedDateFormatted: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: selectedDate).capitalized
    }

    private func loadData() async {
        let dateKey = selectedDateString
        let isFirst = isInitialLoading

        // Show cached data instantly if available
        if let cached = tasksCache[dateKey] {
            withAnimation(.easeInOut(duration: 0.15)) {
                tasks = cached
                if isToday, let cachedRituals = ritualsCache {
                    rituals = cachedRituals
                } else if !isToday {
                    rituals = []
                }
            }
        }

        await store.ensureAreasExist()
        do {
            let calendarService = CalendarService()
            let fetched = try await calendarService.getTasks(date: dateKey)
            // Only update if still on the same date
            if selectedDateString == dateKey {
                withAnimation(.easeInOut(duration: 0.15)) {
                    tasks = fetched
                }
                tasksCache[dateKey] = fetched
            }
        } catch {
            print("⚠️ Failed to load tasks for \(dateKey): \(error)")
            if selectedDateString == dateKey && tasksCache[dateKey] == nil {
                tasks = []
            }
        }
        if Calendar.current.isDateInToday(selectedDate) && selectedDateString == dateKey {
            await store.loadRituals()
            withAnimation(.easeInOut(duration: 0.15)) {
                rituals = store.rituals
            }
            ritualsCache = store.rituals
        } else if selectedDateString == dateKey {
            rituals = []
        }
        if isFirst {
            isInitialLoading = false
        }
    }

    /// Preload task counts for all 7 days to show indicator dots immediately
    private func preloadWeekDots() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let calendarService = CalendarService()
        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: i, to: today) else { continue }
            let dateKey = formatter.string(from: day)
            if tasksCache[dateKey] != nil { continue } // already cached
            do {
                let fetched = try await calendarService.getTasks(date: dateKey)
                tasksCache[dateKey] = fetched
            } catch {
                // Silently skip — dots just won't show for this day
            }
        }
    }

    private func syncCalendar() {
        isSyncing = true
        Task {
            do {
                let result = try await GoogleCalendarService.shared.syncNow()
                let calendarService = CalendarService()
                let fetched = try await calendarService.getTasks(date: selectedDateString)
                tasks = fetched
                tasksCache[selectedDateString] = fetched
                syncFeedback = "\(result.tasksSynced) tâches synchronisées"
            } catch {
                syncFeedback = "Échec de la synchronisation"
            }
            isSyncing = false

            // Dismiss toast after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { syncFeedback = nil }
        }
    }

    private func toggleTask(_ task: CalendarTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let wasCompleted = task.isCompleted
        let previousStatus = task.status
        tasks[index].status = wasCompleted ? "pending" : "completed"

        Task {
            do {
                try await store.toggleTask(taskId: task.id, completed: !wasCompleted)
                let calendarService = CalendarService()
                let fetched = try await calendarService.getTasks(date: selectedDateString)
                tasks = fetched
                tasksCache[selectedDateString] = fetched
            } catch {
                tasks[index].status = previousStatus
            }
        }
    }

    private func toggleRitual(_ ritual: DailyRitual) {
        guard let index = rituals.firstIndex(where: { $0.id == ritual.id }) else { return }
        rituals[index].isCompleted = !ritual.isCompleted

        Task {
            await store.toggleRitual(ritual)
            rituals = store.rituals
        }
    }

    private func performDeleteTask(_ task: CalendarTask) {
        withAnimation(.easeInOut(duration: 0.25)) {
            tasks.removeAll { $0.id == task.id }
        }
        tasksCache[selectedDateString] = tasks
        Task {
            do {
                let calendarService = CalendarService()
                try await calendarService.deleteTask(id: task.id)
                let fetched = try await calendarService.getTasks(date: selectedDateString)
                tasks = fetched
                tasksCache[selectedDateString] = fetched
            } catch {
                print("⚠️ Failed to delete task: \(error)")
            }
        }
    }

    private func performDeleteRitual(_ ritual: DailyRitual) {
        withAnimation(.easeInOut(duration: 0.25)) {
            rituals.removeAll { $0.id == ritual.id }
        }
        Task {
            do {
                try await store.deleteRitual(id: ritual.id)
                rituals = store.rituals
            } catch {
                rituals = store.rituals
            }
        }
    }

    private func createTask(title: String, timeBlock: String, scheduledStart: String?, estimatedMinutes: Int?) async {
        do {
            let calendarService = CalendarService()
            let newTask = try await calendarService.createTask(
                title: title,
                date: selectedDateString,
                scheduledStart: scheduledStart,
                timeBlock: timeBlock,
                estimatedMinutes: estimatedMinutes
            )
            withAnimation(.easeInOut(duration: 0.25)) {
                tasks.append(newTask)
            }
        } catch {
            print("⚠️ Failed to create task: \(error)")
        }
    }

    private func createRitual(title: String, icon: String, areaId: String, scheduledTime: String?) async {
        do {
            try await store.createRitual(areaId: areaId, title: title, frequency: "daily", icon: icon, scheduledTime: scheduledTime)
            await store.loadRituals()
            withAnimation(.easeInOut(duration: 0.25)) {
                rituals = store.rituals
            }
        } catch {
            print("⚠️ Failed to create ritual: \(error)")
        }
    }
}

// MARK: - Add Task Sheet

struct AddTaskSheet: View {
    let bgColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedTimeBlock = "morning"
    @State private var estimatedMinutes = ""
    @State private var scheduledTime = Date()
    @State private var hasScheduledTime = false
    @State private var isSaving = false

    let onCreate: (String, String, String?, Int?) async -> Void

    private let timeBlocks: [(id: String, label: String, icon: String, color: Color)] = [
        ("morning", "Matin", "sunrise.fill", .orange),
        ("afternoon", "Après-midi", "sun.max.fill", .yellow),
        ("evening", "Soir", "moon.fill", .indigo)
    ]

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Titre")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.5)

                        TextField("", text: $title, prompt: Text("Qu'est-ce que tu dois faire ?").foregroundColor(.white.opacity(0.25)))
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Time block
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Moment")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack(spacing: 8) {
                            ForEach(timeBlocks, id: \.id) { block in
                                Button {
                                    selectedTimeBlock = block.id
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: block.icon)
                                            .font(.system(size: 11))
                                        Text(block.label)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(selectedTimeBlock == block.id ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(selectedTimeBlock == block.id ? block.color.opacity(0.5) : Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Hour
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Heure")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Spacer()
                            Toggle("", isOn: $hasScheduledTime)
                                .labelsHidden()
                                .tint(.white.opacity(0.4))
                        }

                        if hasScheduledTime {
                            DatePicker("", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .clipped()
                        }
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Durée estimée")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack(spacing: 8) {
                            ForEach([15, 30, 60], id: \.self) { mins in
                                Button {
                                    estimatedMinutes = "\(mins)"
                                } label: {
                                    Text("\(mins) min")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(estimatedMinutes == "\(mins)" ? .white : .white.opacity(0.5))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(estimatedMinutes == "\(mins)" ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }

                            TextField("", text: $estimatedMinutes, prompt: Text("Min").foregroundColor(.white.opacity(0.25)))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .keyboardType(.numberPad)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    Spacer().frame(height: 12)

                    // Submit
                    Button {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        isSaving = true
                        let timeStr: String? = hasScheduledTime ? formatTime(scheduledTime) : nil
                        Task {
                            await onCreate(title, selectedTimeBlock, timeStr, Int(estimatedMinutes))
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text("Ajouter")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.3) : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            title.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.white.opacity(0.06)
                                : Color.white.opacity(0.2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                .padding(20)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Add Ritual Sheet

struct AddRitualSheet: View {
    let bgColor: Color
    let areas: [Area]
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedIcon = "star"
    @State private var selectedAreaId: String?
    @State private var scheduledTime = Date()
    @State private var hasScheduledTime = false
    @State private var isSaving = false

    let onCreate: (String, String, String, String?) async -> Void

    private let iconOptions: [(key: String, sfSymbol: String)] = [
        ("star", "star.fill"),
        ("sun", "sun.max.fill"),
        ("drop", "drop.fill"),
        ("leaf", "leaf.fill"),
        ("book", "book.fill"),
        ("figure.run", "figure.run"),
        ("brain", "brain.head.profile"),
        ("heart", "heart.fill"),
        ("moon", "moon.fill"),
        ("cup", "cup.and.saucer.fill")
    ]

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Titre")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.5)

                        TextField("", text: $title, prompt: Text("Nom du rituel").foregroundColor(.white.opacity(0.25)))
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Area picker
                    if !areas.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Catégorie")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.5)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                ForEach(areas) { area in
                                    Button {
                                        selectedAreaId = area.id
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(area.icon)
                                                .font(.system(size: 13))
                                            Text(area.name)
                                                .font(.system(size: 12, weight: .medium))
                                                .lineLimit(1)
                                        }
                                        .foregroundColor(selectedAreaId == area.id ? .white : .white.opacity(0.5))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedAreaId == area.id ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }

                    // Icon
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Icône")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.5)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                            ForEach(iconOptions, id: \.key) { icon in
                                Button {
                                    selectedIcon = icon.key
                                } label: {
                                    Image(systemName: icon.sfSymbol)
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedIcon == icon.key ? .white : .white.opacity(0.4))
                                        .frame(width: 46, height: 46)
                                        .background(selectedIcon == icon.key ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    // Hour
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Heure")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Spacer()
                            Toggle("", isOn: $hasScheduledTime)
                                .labelsHidden()
                                .tint(.white.opacity(0.4))
                        }

                        if hasScheduledTime {
                            DatePicker("", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .clipped()
                        }
                    }

                    Spacer().frame(height: 12)

                    // Submit
                    Button {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty,
                              let areaId = selectedAreaId else { return }
                        isSaving = true
                        let timeStr: String? = hasScheduledTime ? formatTime(scheduledTime) : nil
                        Task {
                            await onCreate(title, selectedIcon, areaId, timeStr)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text("Ajouter")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(canCreate ? .white : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canCreate ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canCreate || isSaving)
                }
                .padding(20)
            }
        }
        .onAppear {
            selectedAreaId = areas.first?.id
        }
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedAreaId != nil
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Voice Planning Scope Sheet

struct VoicePlanningScopeSheet: View {
    let bgColor: Color
    let onSelect: (String) -> Void

    @State private var appeared = false

    private let options: [(scope: String, title: String, subtitle: String, icon: String)] = [
        ("today", "Aujourd'hui", "Planifie ta journée", "sun.max.fill"),
        ("tomorrow", "Demain", "Prépare demain", "sunrise.fill"),
        ("week", "Ma semaine", "Organise ta semaine", "calendar"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("Planifie par la voix")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
                .padding(.bottom, 4)

            Text("Choisis la période à planifier")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element.scope) { index, option in
                    Button {
                        HapticFeedback.selection()
                        onSelect(option.scope)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(option.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.08),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(bgColor.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
    }
}
