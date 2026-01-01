import SwiftUI

// MARK: - Chat Section Enum
enum ChatSection: Int, CaseIterable {
    case chat = 0
    case calendar = 1
    case add = 2

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .calendar: return "Calendrier"
        case .add: return "+"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "message"
        case .calendar: return "calendar"
        case .add: return "plus"
        }
    }
}

struct ChatView: View {
    @EnvironmentObject var store: FocusAppStore
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var calendarViewModel = CalendarViewModel()
    @State private var scrollProxy: ScrollViewProxy?
    @State private var selectedSection: ChatSection = .chat

    // Add menu state
    @State private var showAddTaskSheet = false
    @State private var showAddRitualSheet = false
    @State private var showRecordReflection = false

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Minimal header with segmented control
                chatHeader

                // Content based on section
                Group {
                    switch selectedSection {
                    case .chat:
                        chatContent
                    case .calendar:
                        embeddedCalendarView
                    case .add:
                        addMenuView
                    }
                }
            }

            // Recording overlay (only for chat section)
            if selectedSection == .chat {
                VoiceRecordingOverlay(
                    isRecording: viewModel.isRecording,
                    onCancel: {
                        viewModel.stopRecording()
                    }
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setStore(store)
            viewModel.checkForDailyGreeting()
            Task {
                await calendarViewModel.loadWeekData()
            }
        }
        .sheet(isPresented: $viewModel.showPlanDay) {
            PlanYourDayView()
                .onDisappear {
                    viewModel.addToolCompletionMessage(
                        tool: .planDay,
                        summary: "Ta journée est planifiée. Go ! 💪"
                    )
                }
        }
        .sheet(isPresented: $viewModel.showWeeklyGoals) {
            NavigationStack {
                WeeklyGoalsView()
            }
            .onDisappear {
                viewModel.addToolCompletionMessage(
                    tool: .weeklyGoals,
                    summary: "Objectifs définis. Focus sur ce qui compte."
                )
            }
        }
        .sheet(isPresented: $viewModel.showDailyReflection) {
            NavigationStack {
                EndOfDayView()
            }
            .onDisappear {
                viewModel.addToolCompletionMessage(
                    tool: .dailyReflection,
                    summary: "Réflexion enregistrée. Repose-toi bien."
                )
            }
        }
        .sheet(isPresented: $viewModel.showMoodPicker) {
            moodPickerSheet
        }
        .sheet(isPresented: $showAddTaskSheet) {
            QuickCreateTaskSheet(viewModel: calendarViewModel)
        }
        .sheet(isPresented: $showRecordReflection) {
            JournalRecorderView { entry in
                viewModel.addToolCompletionMessage(
                    tool: .dailyReflection,
                    summary: "Réflexion enregistrée ! \(entry.transcript?.prefix(50) ?? "")"
                )
            }
        }
        .alert("Erreur", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Une erreur est survenue")
        }
    }

    // MARK: - Header with Segmented Control

    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: SpacingTokens.md) {
                // Coach avatar + name (minimal)
                HStack(spacing: SpacingTokens.sm) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.surface)
                            .frame(width: 36, height: 36)

                        Image(systemName: CoachPersona.avatarIcon)
                            .font(.system(size: 18))
                            .foregroundColor(ColorTokens.primaryStart)
                    }

                    Text(CoachPersona.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)
                }

                Spacer()

                // Streak badge
                if store.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 14))
                        Text("\(store.currentStreak)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ColorTokens.primaryStart)
                    }
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(ColorTokens.primarySoft)
                    )
                }

                // Menu
                Menu {
                    Button(role: .destructive) {
                        viewModel.clearChat()
                    } label: {
                        Label("Effacer la conversation", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(ColorTokens.textSecondary)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)

            // Segmented Control
            HStack(spacing: 0) {
                ForEach(ChatSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if section == .add {
                                // Show add menu instead of switching tab
                                showAddTaskSheet = true
                            } else {
                                selectedSection = section
                            }
                        }
                        HapticFeedback.light()
                    } label: {
                        VStack(spacing: 4) {
                            if section == .add {
                                Image(systemName: section.icon)
                                    .font(.system(size: 18, weight: .medium))
                            } else {
                                Text(section.title)
                                    .font(.system(size: 14, weight: selectedSection == section ? .semibold : .regular))
                            }
                        }
                        .foregroundColor(selectedSection == section ? ColorTokens.primaryStart : ColorTokens.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.sm)
                        .background(
                            selectedSection == section ?
                            ColorTokens.primarySoft.cornerRadius(8) :
                            Color.clear.cornerRadius(8)
                        )
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.bottom, SpacingTokens.sm)
        }
        .background(ColorTokens.background)
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            // Messages
            messagesScrollView

            // Quick actions (when no text input)
            if viewModel.inputText.isEmpty && !viewModel.isLoading {
                quickActions
            }

            // Input bar
            ChatInputBar(
                text: $viewModel.inputText,
                isRecording: viewModel.isRecording,
                isLoading: viewModel.isLoading,
                onSend: {
                    viewModel.sendMessage()
                    scrollToBottom()
                },
                onMicTap: {
                    viewModel.startRecording()
                },
                onMicRelease: {
                    viewModel.stopRecording()
                }
            )
        }
    }

    // MARK: - Messages ScrollView

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: SpacingTokens.md) {
                    ForEach(viewModel.messages) { message in
                        ChatMessageBubble(
                            message: message,
                            onToolTap: { tool in
                                viewModel.handleToolAction(tool)
                            }
                        )
                        .id(message.id)
                    }

                    // Loading indicator
                    if viewModel.isLoading {
                        loadingIndicator
                    }

                    // Bottom spacer for scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, SpacingTokens.md)
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom()
            }
        }
    }

    private var loadingIndicator: some View {
        HStack(spacing: SpacingTokens.sm) {
            ZStack {
                Circle()
                    .fill(ColorTokens.surface)
                    .frame(width: 32, height: 32)

                Image(systemName: CoachPersona.avatarIcon)
                    .font(.system(size: 16))
                    .foregroundColor(ColorTokens.primaryStart)
            }

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(ColorTokens.textMuted)
                        .frame(width: 8, height: 8)
                        .opacity(0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: viewModel.isLoading
                        )
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTokens.surface)
            )

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        ChatQuickActions(
            suggestedTools: suggestedToolsForContext(),
            onToolTap: { tool in
                viewModel.handleToolAction(tool)
            }
        )
        .padding(.vertical, SpacingTokens.sm)
    }

    private func suggestedToolsForContext() -> [ChatTool] {
        let context = viewModel.buildContext()

        switch context.timeOfDay {
        case .morning:
            return [.planDay, .startFocus, .weeklyGoals]
        case .afternoon:
            return [.startFocus, .viewStats, .planDay]
        case .evening, .night:
            return [.dailyReflection, .viewStats, .logMood]
        }
    }

    // MARK: - Embedded Calendar View

    private var embeddedCalendarView: some View {
        VStack(spacing: 0) {
            // Mini week selector
            miniWeekSelector

            // Today's tasks list
            ScrollView {
                VStack(spacing: SpacingTokens.md) {
                    // Progress card
                    if !calendarViewModel.tasks.isEmpty {
                        dayProgressCard
                    }

                    // Tasks by time block
                    ForEach(["morning", "afternoon", "evening"], id: \.self) { block in
                        let blockTasks = calendarViewModel.tasks.filter { $0.timeBlock == block }
                        if !blockTasks.isEmpty {
                            taskBlockSection(block: block, tasks: blockTasks)
                        }
                    }

                    // Empty state
                    if calendarViewModel.tasks.isEmpty {
                        emptyCalendarState
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.top, SpacingTokens.md)
            }
        }
    }

    private var miniWeekSelector: some View {
        let calendar = Calendar.current
        let today = Date()
        let weekDays = (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sm) {
                ForEach(weekDays, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: calendarViewModel.selectedDate)
                    let isToday = calendar.isDateInToday(date)

                    Button {
                        calendarViewModel.selectDate(date)
                        HapticFeedback.light()
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayName(date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isSelected ? ColorTokens.primaryStart : ColorTokens.textMuted)

                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                        }
                        .frame(width: 44, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? ColorTokens.primarySoft : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isToday && !isSelected ? ColorTokens.primaryStart : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)
        }
        .background(ColorTokens.surface)
    }

    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayProgressCard: some View {
        let completed = calendarViewModel.tasks.filter { $0.status == "completed" }.count
        let total = calendarViewModel.tasks.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0

        return HStack(spacing: SpacingTokens.md) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(ColorTokens.surface, lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ColorTokens.primaryStart, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(completed)/\(total) tâches")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text(progressMessage(completed: completed, total: total))
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    private func progressMessage(completed: Int, total: Int) -> String {
        let ratio = total > 0 ? Double(completed) / Double(total) : 0
        if ratio >= 1.0 { return "🎉 Journée validée !" }
        if ratio >= 0.7 { return "Presque là !" }
        if ratio >= 0.3 { return "Continue comme ça" }
        return "C'est parti !"
    }

    private func taskBlockSection(block: String, tasks: [CalendarTask]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text(blockTitle(block))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()
            }

            ForEach(tasks) { task in
                embeddedTaskRow(task)
            }
        }
    }

    private func blockTitle(_ block: String) -> String {
        switch block {
        case "morning": return "MATIN"
        case "afternoon": return "APRÈS-MIDI"
        case "evening": return "SOIR"
        default: return block.uppercased()
        }
    }

    private func embeddedTaskRow(_ task: CalendarTask) -> some View {
        HStack(spacing: SpacingTokens.md) {
            // Checkbox
            Button {
                toggleTask(task)
            } label: {
                Image(systemName: task.status == "completed" ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(task.status == "completed" ? ColorTokens.success : ColorTokens.textMuted)
            }

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(task.status == "completed" ? ColorTokens.textMuted : ColorTokens.textPrimary)
                    .strikethrough(task.status == "completed")

                if let start = task.scheduledStart, let end = task.scheduledEnd {
                    Text("\(start) - \(end)")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTokens.textMuted)
                }
            }

            Spacer()

            // Priority indicator
            if task.priority == "high" || task.priority == "urgent" {
                Circle()
                    .fill(task.priority == "urgent" ? Color.red : Color.orange)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }

    private func toggleTask(_ task: CalendarTask) {
        Task {
            await calendarViewModel.toggleTask(task.id)
        }
        HapticFeedback.light()
    }

    private var emptyCalendarState: some View {
        VStack(spacing: SpacingTokens.lg) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.textMuted)

            Text("Aucune tâche aujourd'hui")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ColorTokens.textSecondary)

            Button {
                showAddTaskSheet = true
            } label: {
                Text("Ajouter une tâche")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.vertical, SpacingTokens.md)
                    .background(ColorTokens.primaryStart)
                    .cornerRadius(RadiusTokens.full)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.xxl)
    }

    // MARK: - Add Menu View

    private var addMenuView: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            // Add task
            addMenuItem(
                icon: "checkmark.circle",
                title: "Nouvelle tâche",
                subtitle: "Ajouter une tâche à ton calendrier"
            ) {
                showAddTaskSheet = true
            }

            // Record reflection
            addMenuItem(
                icon: "waveform.circle",
                title: "Réflexion audio",
                subtitle: "Enregistre ta réflexion du jour"
            ) {
                showRecordReflection = true
            }

            // Start focus
            addMenuItem(
                icon: "flame",
                title: "Session Focus",
                subtitle: "Lance une session de concentration"
            ) {
                router.navigateToFireMode()
            }

            Spacer()

            // Back to chat button
            Button {
                selectedSection = .chat
            } label: {
                Text("Retour au chat")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .padding(.bottom, SpacingTokens.xl)
        }
        .padding(.horizontal, SpacingTokens.lg)
    }

    private func addMenuItem(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.md) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.primarySoft)
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(ColorTokens.primaryStart)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTokens.textMuted)
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
    }

    // MARK: - Mood Picker Sheet

    private var moodPickerSheet: some View {
        VStack(spacing: SpacingTokens.xl) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ColorTokens.textMuted)
                .frame(width: 40, height: 4)
                .padding(.top, SpacingTokens.md)

            ChatMoodPicker(
                selectedMood: .constant(nil),
                onSelect: { mood in
                    viewModel.showMoodPicker = false
                    viewModel.addToolCompletionMessage(
                        tool: .logMood,
                        summary: getMoodResponse(mood)
                    )
                }
            )
            .padding(.horizontal, SpacingTokens.lg)

            Spacer()
        }
        .background(ColorTokens.background)
        .presentationDetents([.height(250)])
    }

    private func getMoodResponse(_ mood: Int) -> String {
        switch mood {
        case 1: return "Les jours difficiles font partie du chemin. Je suis là si tu veux en parler."
        case 2: return "Pas la meilleure journée. C'est ok. Qu'est-ce qui pourrait t'aider ?"
        case 3: return "Neutre. Parfois c'est comme ça. On continue ?"
        case 4: return "Bien ! Continue sur cette lancée."
        case 5: return "Super ! J'adore cette énergie. 🔥"
        default: return "Merci de partager."
        }
    }

    // MARK: - Helpers

    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
        .environmentObject(FocusAppStore.shared)
        .environmentObject(AppRouter.shared)
}
