import SwiftUI

// MARK: - Full-Screen Planning View

struct PlanningView: View {
    @EnvironmentObject var store: FocusAppStore
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
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
    @State private var quests: [QuestResponse] = []
    @State private var showAddQuest = false
    @State private var questToDelete: QuestResponse?
    @State private var objectivesExpanded = false
    @State private var showCompleted = true
    @State private var aiSuggestions: [AISuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var showSuggestions = false
    @State private var challenges: [Challenge] = []
    @State private var showCreateChallenge = false
    @State private var showVerification: Challenge?

    // Background color matching chat screen avatar background
    private let bgColor = Color(red: 0.10, green: 0.12, blue: 0.20)

    // Cached formatters (avoid re-creating on every render)
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()
    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE"
        return f
    }()

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    private var isMorning: Bool { Calendar.current.component(.hour, from: Date()) < 12 }
    private var isAfternoon: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 12 && h < 18
    }

    private var selectedDateString: String {
        Self.isoFormatter.string(from: selectedDate)
    }

    private var completedTasks: Int { tasks.filter { $0.isCompleted }.count }
    private var completedRituals: Int { rituals.filter { $0.isCompleted }.count }
    private var totalItems: Int { tasks.count + (isToday ? rituals.count : 0) }
    private var completedItems: Int { completedTasks + (isToday ? completedRituals : 0) }
    private var progress: Double {
        totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if isInitialLoading {
                ProgressView()
                    .tint(.white)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        progressHeader
                        dateStrip

                        // Active challenges
                        if !challenges.isEmpty {
                            challengesSection
                        }

                        unifiedList

                        if !quests.isEmpty || objectivesExpanded {
                            objectivesSection
                        }


                        if tasks.isEmpty && (isToday ? rituals.isEmpty : true) && quests.isEmpty {
                            emptyState
                        }

                        Spacer().frame(height: 80)
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

            // Floating add button
            floatingAddButton

            // Sync feedback toast
            syncToast
        }
        .task {
            await loadData()
            await loadQuests()
            await preloadWeekDots()
        }
        .onReceive(NotificationCenter.default.publisher(for: .calendarNeedsRefresh)) { _ in
            Task { await loadData() }
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
        .alert("Supprimer cet objectif ?", isPresented: Binding(
            get: { questToDelete != nil },
            set: { if !$0 { questToDelete = nil } }
        )) {
            Button("Annuler", role: .cancel) { questToDelete = nil }
            Button("Supprimer", role: .destructive) {
                if let quest = questToDelete {
                    performDeleteQuest(quest)
                    questToDelete = nil
                }
            }
        } message: {
            if let quest = questToDelete {
                Text("« \(quest.title) » sera supprimé définitivement.")
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
                areas: store.areas.filter { !$0.id.hasPrefix("placeholder-") },
                existingRitualTitles: Set(rituals.map { $0.title.lowercased() }),
                onAddRecommended: { rec in
                    addRecommendedRitual(rec)
                }
            ) { title, icon, areaId, scheduledTime in
                await createRitual(title: title, icon: icon, areaId: areaId, scheduledTime: scheduledTime)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCreateChallenge) {
            CreateChallengeView { type, alarmTime, duration, customTitle in
                createChallenge(type: type, alarmTime: alarmTime, duration: duration, customTitle: customTitle)
                showCreateChallenge = false
            }
        }
        .fullScreenCover(item: $showVerification) { challenge in
            ChallengeVerificationView(
                challenge: challenge,
                onVerified: { photoUrl in
                    checkInChallenge(challenge, photoUrl: photoUrl)
                    showVerification = nil
                },
                onDismiss: { showVerification = nil }
            )
        }
        .sheet(isPresented: $showVoicePlanningSheet) {
            VoicePlanningScopeSheet(bgColor: bgColor) { scope in
                let selectedScope = scope
                showVoicePlanningSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    voicePlanningScope = selectedScope
                    showVoiceCall = true
                }
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showVoiceCall) {
            VoiceCallView(mode: "planning", planningScope: voicePlanningScope)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            FocusPaywallView(
                onComplete: { showPaywall = false },
                onSkip: { showPaywall = false }
            )
            .environmentObject(SubscriptionManager.shared)
        }
        .onChange(of: showVoiceCall) { newValue in
            if !newValue {
                // Voice planning ended — refresh after a short delay for task creation
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await loadData()
                    await loadQuests()
                }
            }
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

            // AI suggestions button
            Button {
                fetchAISuggestions()
            } label: {
                if isLoadingSuggestions {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(showSuggestions ? Color(red: 1.0, green: 0.8, blue: 0.2) : .white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
            }

            // Voice planning button (pro only)
            Button {
                if SubscriptionManager.shared.isProUser {
                    showVoicePlanningSheet = true
                } else {
                    showPaywall = true
                }
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

    // MARK: - Motivational Progress Header

    private var progressRingColor: Color {
        switch progress {
        case 0..<0.3: return .orange
        case 0.3..<0.7: return .yellow
        default: return .green
        }
    }

    private var motivationalGreeting: String {
        let name = store.user?.firstName ?? store.user?.pseudo ?? ""
        let prefix = name.isEmpty ? "" : " \(name)"

        if !isToday {
            return selectedDateFormatted
        }
        if progress >= 1.0 {
            return "Journée parfaite !"
        }
        if isMorning {
            return "Bonjour\(prefix) !"
        }
        if isAfternoon {
            let remaining = totalItems - completedItems
            return remaining > 0 ? "Plus que \(remaining) !" : "Tu gères !"
        }
        let remaining = totalItems - completedItems
        return remaining > 0 ? "Dernière ligne droite" : "Belle soirée !"
    }

    private var motivationalSubtitle: String {
        if !isToday {
            return "\(tasks.count) tâche\(tasks.count > 1 ? "s" : "") prévue\(tasks.count > 1 ? "s" : "")"
        }
        if totalItems == 0 {
            return "Aucune tâche — ajoute en une !"
        }
        if progress >= 1.0 {
            return "Tout est complété"
        }
        return "\(completedItems)/\(totalItems) terminés"
    }

    private var progressHeader: some View {
        HStack(spacing: 14) {
            // Progress ring with dynamic color
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressRingColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)

                if progress >= 1.0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text("\(Int(progress * 100))")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(motivationalGreeting)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text(motivationalSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 4)
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let isDayToday = calendar.isDateInToday(day)
                    let dateKey = Self.isoFormatter.string(from: day)

                    Button {
                        selectedDate = day
                        if let cached = tasksCache[dateKey] {
                            withAnimation(.easeInOut(duration: 0.15)) { tasks = cached }
                        }
                        if calendar.isDateInToday(day), let cachedRituals = ritualsCache {
                            withAnimation(.easeInOut(duration: 0.15)) { rituals = cachedRituals }
                        } else if !calendar.isDateInToday(day) {
                            rituals = []
                        }
                        Task { await loadData() }
                    } label: {
                        VStack(spacing: 2) {
                            VStack(spacing: 4) {
                                Text(isDayToday ? "Auj." : Self.dayNameFormatter.string(from: day).capitalized)
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

                            // Task indicator
                            if let cached = tasksCache[dateKey], !cached.isEmpty {
                                if cached.allSatisfy({ $0.isCompleted }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                } else if isDayToday {
                                    // Pulsing dot for today
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: .orange.opacity(0.6), radius: 3)
                                } else {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 5, height: 5)
                                }
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

    // MARK: - Unified Task + Ritual List

    private var unifiedList: some View {
        let pendingTasks = tasks.filter { !$0.isCompleted }.sorted { t1, t2 in
            let order = ["morning": 0, "afternoon": 1, "evening": 2]
            return (order[t1.timeBlock] ?? 3) < (order[t2.timeBlock] ?? 3)
        }
        let doneTasks = tasks.filter { $0.isCompleted }
        let pendingRituals = isToday ? rituals.filter { !$0.isCompleted } : []
        let doneRituals = isToday ? rituals.filter { $0.isCompleted } : []

        let hasPending = !pendingTasks.isEmpty || !pendingRituals.isEmpty
        let hasDone = !doneTasks.isEmpty || !doneRituals.isEmpty
        let hasContent = !tasks.isEmpty || (isToday && !rituals.isEmpty)

        return Group {
            if hasContent {
                VStack(spacing: 12) {
                    // AI Suggestions section
                    if showSuggestions && !aiSuggestions.isEmpty {
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.2))
                                Text("Suggestions IA")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.2))
                                    .textCase(.uppercase)
                                    .kerning(1)
                                Spacer()
                                Button {
                                    withAnimation { showSuggestions = false; aiSuggestions = [] }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color.white.opacity(0.1)))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                            VStack(spacing: 1) {
                                ForEach(aiSuggestions) { suggestion in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(suggestion.title)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.white.opacity(0.9))
                                            HStack(spacing: 6) {
                                                timeBlockIndicator(for: suggestion.timeBlock)
                                                if !suggestion.reason.isEmpty {
                                                    Text(suggestion.reason)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.35))
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                        Spacer()
                                        // Accept button
                                        Button {
                                            acceptSuggestion(suggestion)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.4))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.04))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.bottom, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Active items
                    if hasPending {
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Text("À faire")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                    .kerning(1)
                                Spacer()
                                Text("\(pendingTasks.count + pendingRituals.count)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                            List {
                                ForEach(pendingTasks) { task in
                                    taskRow(task)
                                        .listRowBackground(Color.white.opacity(0.06))
                                        .listRowInsets(EdgeInsets())
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                performDeleteTask(task)
                                            } label: {
                                                Label("Supprimer", systemImage: "trash")
                                            }
                                        }
                                }

                                if !pendingRituals.isEmpty {
                                    // Ritual divider
                                    HStack(spacing: 8) {
                                        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                                        Text("Rituels")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.35))
                                            .textCase(.uppercase)
                                            .kerning(0.5)
                                        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                    .listRowSeparator(.hidden)

                                    ForEach(pendingRituals) { ritual in
                                        ritualRow(ritual)
                                            .listRowBackground(Color.white.opacity(0.06))
                                            .listRowInsets(EdgeInsets())
                                            .listRowSeparator(.hidden)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    performDeleteRitual(ritual)
                                                } label: {
                                                    Label("Supprimer", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .frame(minHeight: CGFloat(pendingTasks.count + pendingRituals.count + (pendingRituals.isEmpty ? 0 : 1)) * 56)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                        }
                    }

                    // Completed items (collapsable)
                    if hasDone {
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCompleted.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green.opacity(0.5))
                                    Text("Terminé")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white.opacity(0.3))
                                        .textCase(.uppercase)
                                        .kerning(1)
                                    Text("\(doneTasks.count + doneRituals.count)")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.2))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.2))
                                        .rotationEffect(.degrees(showCompleted ? 90 : 0))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                            if showCompleted {
                            List {
                                ForEach(doneTasks) { task in
                                    taskRow(task)
                                        .listRowBackground(Color.white.opacity(0.03))
                                        .listRowInsets(EdgeInsets())
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                performDeleteTask(task)
                                            } label: {
                                                Label("Supprimer", systemImage: "trash")
                                            }
                                        }
                                }
                                ForEach(doneRituals) { ritual in
                                    ritualRow(ritual)
                                        .listRowBackground(Color.white.opacity(0.03))
                                        .listRowInsets(EdgeInsets())
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                performDeleteRitual(ritual)
                                            } label: {
                                                Label("Supprimer", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .frame(minHeight: CGFloat(doneTasks.count + doneRituals.count) * 56)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                            } // end if showCompleted
                        }
                    }

                    // Motivational message
                    motivationalMessage
                }
            }
        }
    }

    // MARK: - Motivational Message

    private var motivationalMessage: some View {
        Group {
            if isToday && totalItems > 0 {
                let msg: (String, String) = {
                    switch progress {
                    case 0: return ("rocket", "C'est parti ! Commence par une tâche simple")
                    case 0..<0.5: return ("figure.run", "Bon début, continue !")
                    case 0.5..<1.0: return ("star.fill", "Plus que \(totalItems - completedItems) — tu y es presque !")
                    default: return ("party.popper.fill", "Bravo ! Journée accomplie")
                    }
                }()

                HStack(spacing: 8) {
                    Image(systemName: msg.0)
                        .font(.system(size: 13))
                        .foregroundColor(progress >= 1.0 ? .green : .white.opacity(0.4))
                    Text(msg.1)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(progress >= 1.0 ? .green.opacity(0.8) : .white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
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
                    .font(.system(size: 16, weight: task.isCompleted ? .regular : .medium))
                    .foregroundColor(task.isCompleted ? .white.opacity(0.3) : .white.opacity(0.9))
                    .strikethrough(task.isCompleted, color: .white.opacity(0.2))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    // Time block indicator
                    timeBlockIndicator(for: task.timeBlock)

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

            // App blocking toggle — clearly visible
            Button {
                toggleBlockApps(task)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: task.blockApps == true ? "shield.lefthalf.filled" : "shield")
                        .font(.system(size: 14))
                    if task.blockApps == true {
                        Text("ON")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .foregroundColor(task.blockApps == true ? Color(red: 0.3, green: 0.8, blue: 1.0) : .white.opacity(0.35))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(task.blockApps == true ? Color(red: 0.3, green: 0.8, blue: 1.0).opacity(0.15) : Color.white.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Challenges Section

    private var challengesSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
                Text("Challenges")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .kerning(1)
                Spacer()
                Button {
                    showCreateChallenge = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 20)

            ForEach(challenges.filter { $0.isActive }) { challenge in
                ChallengeCardView(
                    challenge: challenge,
                    currentUserId: store.user?.id ?? "",
                    onValidate: { showVerification = challenge }
                )
                .padding(.horizontal, 16)
            }
        }
    }

    private func loadChallenges() {
        Task {
            do {
                let result: [Challenge] = try await APIClient.shared.request(
                    endpoint: .custom("/challenges/wakeup"),
                    method: .get
                )
                await MainActor.run { challenges = result }
            } catch {
                print("Load challenges error: \(error)")
            }
        }
    }

    private func createChallenge(type: ChallengeType, alarmTime: String, duration: Int, customTitle: String?) {
        Task {
            do {
                var body: [String: Any] = [
                    "challenge_type": type.rawValue,
                    "alarm_time": alarmTime,
                    "duration_days": duration,
                ]
                if let title = customTitle {
                    body["custom_title"] = title
                }
                let _: [String: Any]? = try await APIClient.shared.request(
                    endpoint: .custom("/challenges/wakeup"),
                    method: .post,
                    body: body
                )
                loadChallenges()
            } catch {
                print("Create challenge error: \(error)")
            }
        }
    }

    private func checkInChallenge(_ challenge: Challenge, photoUrl: String?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: Date())

        Task {
            do {
                var body: [String: Any] = ["wake_up_time": timeStr]
                if let photo = photoUrl {
                    body["photo_url"] = photo
                }
                let _: [String: Any]? = try await APIClient.shared.request(
                    endpoint: .custom("/challenges/wakeup/\(challenge.id)/checkin"),
                    method: .post,
                    body: body
                )
                loadChallenges()
            } catch {
                print("Check-in error: \(error)")
            }
        }
    }

    // MARK: - AI Suggestions

    private func fetchAISuggestions() {
        guard !isLoadingSuggestions else { return }
        isLoadingSuggestions = true

        Task {
            do {
                let dateStr = Self.isoFormatter.string(from: selectedDate)
                let prompt = "Suggère 3-4 tâches pour \(dateStr). Contexte: tâches existantes: \(tasks.map { $0.title }.joined(separator: ", ")). Rituels: \(rituals.map { $0.title }.joined(separator: ", ")). Réponds UNIQUEMENT en JSON: [{\"title\": \"...\", \"time_block\": \"morning|afternoon|evening\", \"reason\": \"...\"}]"

                let (reply, _) = try await ChatV2Service.shared.sendMessage(prompt)

                // Parse JSON from AI response
                if let jsonStart = reply.firstIndex(of: "["),
                   let jsonEnd = reply.lastIndex(of: "]") {
                    let jsonStr = String(reply[jsonStart...jsonEnd])
                    if let data = jsonStr.data(using: .utf8),
                       let parsed = try? JSONDecoder().decode([AISuggestionResponse].self, from: data) {
                        await MainActor.run {
                            aiSuggestions = parsed.map { AISuggestion(title: $0.title, timeBlock: $0.time_block ?? "morning", reason: $0.reason ?? "") }
                            showSuggestions = true
                        }
                    }
                }
            } catch {
                print("AI suggestions error: \(error)")
            }
            await MainActor.run { isLoadingSuggestions = false }
        }
    }

    private func acceptSuggestion(_ suggestion: AISuggestion) {
        let dateStr = Self.isoFormatter.string(from: selectedDate)
        Task {
            do {
                let _: CalendarTask? = try await APIClient.shared.request(
                    endpoint: .createCalendarTask,
                    method: .post,
                    body: CreateTaskBody(title: suggestion.title, date: dateStr, timeBlock: suggestion.timeBlock, priority: "medium")
                )
                // Remove from suggestions
                await MainActor.run {
                    aiSuggestions.removeAll { $0.id == suggestion.id }
                    if aiSuggestions.isEmpty { showSuggestions = false }
                }
                // Refresh tasks
                await loadData()
            } catch {
                print("Accept suggestion error: \(error)")
            }
        }
    }

    private func toggleBlockApps(_ task: CalendarTask) {
        let newValue = !(task.blockApps ?? false)
        Task {
            do {
                let _: CalendarTask? = try await APIClient.shared.request(
                    endpoint: .updateCalendarTask(task.id),
                    method: .patch,
                    body: ["block_apps": newValue]
                )
                await store.refreshTodaysTasks()
                // Reschedule blocking for updated tasks
                await ScheduledBlockingService.shared.scheduleBlockingForTasks(store.todaysTasks)
            } catch {
                print("Failed to toggle block_apps: \(error)")
            }
        }
    }

    // MARK: - Time Block Indicator

    private func timeBlockIndicator(for block: String) -> some View {
        let (icon, color): (String, Color) = {
            switch block {
            case "morning": return ("sunrise.fill", .orange)
            case "afternoon": return ("sun.max.fill", .yellow)
            case "evening": return ("moon.fill", .indigo)
            default: return ("tray.fill", .gray)
            }
        }()
        return Image(systemName: icon)
            .font(.system(size: 10))
            .foregroundColor(color.opacity(0.6))
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

            Image(systemName: ritual.icon.isEmpty ? "star" : ritual.icon)
                .font(.system(size: 14))
                .foregroundColor(ritual.isCompleted ? .white.opacity(0.3) : Color(red: 0.31, green: 0.80, blue: 0.77))
                .frame(width: 20)

            Text(ritual.title)
                .font(.system(size: 16, weight: ritual.isCompleted ? .regular : .medium))
                .foregroundColor(ritual.isCompleted ? .white.opacity(0.3) : .white.opacity(0.9))
                .strikethrough(ritual.isCompleted, color: .white.opacity(0.2))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let time = ritual.scheduledTime {
                Text(time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Floating Add Button

    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Menu {
                    Button {
                        showAddTask = true
                    } label: {
                        Label("Tâche", systemImage: "checklist")
                    }
                    if isToday {
                        Button {
                            showAddRitual = true
                        } label: {
                            Label("Rituel", systemImage: "repeat")
                        }
                    }
                    Button {
                        showAddQuest = true
                    } label: {
                        Label("Objectif", systemImage: "target")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(bgColor)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color.white))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Sync Toast

    private var syncToast: some View {
        Group {
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
                        .padding(.bottom, 90)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: syncFeedback)
            }
        }
    }

    // MARK: - Objectives Section (Collapsed)

    private var objectivesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    objectivesExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Objectifs")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .kerning(1)

                    if !quests.isEmpty {
                        Text("\(quests.filter { $0.status == "completed" }.count)/\(quests.count)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                        .rotationEffect(.degrees(objectivesExpanded ? 90 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            if objectivesExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if quests.isEmpty {
                        Text("Aucun objectif pour l'instant")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    } else {
                        let shortTerm = quests.filter { ($0.term ?? "short") == "short" }
                        let mediumTerm = quests.filter { $0.term == "medium" }
                        let longTerm = quests.filter { $0.term == "long" }

                        if !shortTerm.isEmpty {
                            objectiveTermGroup(label: "Court terme", icon: "bolt.fill", color: .orange, items: shortTerm)
                        }
                        if !mediumTerm.isEmpty {
                            objectiveTermGroup(label: "Moyen terme", icon: "calendar", color: .blue, items: mediumTerm)
                        }
                        if !longTerm.isEmpty {
                            objectiveTermGroup(label: "Long terme", icon: "star.fill", color: .purple, items: longTerm)
                        }
                    }
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .padding(.horizontal, 16)
        .sheet(isPresented: $showAddQuest) {
            AddQuestSheet(bgColor: bgColor) { title, term, area in
                performCreateQuest(title: title, term: term, area: area)
            }
            .presentationDetents([.height(480)])
            .presentationDragIndicator(.visible)
        }
    }

    private func objectiveTermGroup(label: String, icon: String, color: Color, items: [QuestResponse]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 24)

            ForEach(items) { quest in
                let isCompleted = quest.status == "completed"
                HStack(spacing: 10) {
                    Button(action: { toggleQuest(quest) }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isCompleted ? Color.clear : color.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            if isCompleted {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(color)
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    let questIcon = quest.areaIcon ?? "star.fill"
                    Image(systemName: questIcon.hasSuffix(".fill") ? questIcon : "\(questIcon).fill")
                        .font(.system(size: 12))
                        .foregroundColor(color.opacity(isCompleted ? 0.3 : 0.6))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(quest.title)
                            .font(.system(size: 15, weight: isCompleted ? .regular : .medium))
                            .foregroundColor(isCompleted ? .white.opacity(0.3) : .white.opacity(0.85))
                            .strikethrough(isCompleted, color: .white.opacity(0.2))
                            .lineLimit(1)

                        if let areaName = quest.areaName, areaName != "Autre" {
                            Text(areaName)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(isCompleted ? 0.2 : 0.35))
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                )
                .padding(.horizontal, 16)
                .contextMenu {
                    Button(role: .destructive) {
                        questToDelete = quest
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - End of Day Check-In



    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 30)

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 80, height: 80)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.15))
            }

            Text(isToday ? "Ta journée est libre" : "Rien de prévu")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            // CTA buttons
            VStack(spacing: 10) {
                Button {
                    showAddTask = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Ajouter une tâche")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(bgColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if isToday {
                    Button {
                        if SubscriptionManager.shared.isProUser {
                            showVoicePlanningSheet = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                            Text("Planifier par la voix")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private var selectedDateFormatted: String {
        Self.displayFormatter.string(from: selectedDate).capitalized
    }

    // MARK: - Ritual Recommendations (used by AddRitualSheet)

    static let recommendedRituals: [(title: String, icon: String, time: String?)] = [
        ("Aller à la salle", "dumbbell.fill", "07:00"),
        ("Douche froide", "snowflake", "07:30"),
        ("Lire 30 minutes", "book.fill", "21:00"),
        ("Dormir à 23h", "moon.fill", "23:00"),
        ("Méditer 10 min", "leaf.fill", "08:00"),
        ("Boire 2L d'eau", "drop.fill", nil),
    ]

    private func addRecommendedRitual(_ rec: (title: String, icon: String, time: String?)) {
        Task {
            do {
                struct CreateRitualBody: Encodable {
                    let title: String
                    let icon: String
                    let frequency: String
                    let scheduledTime: String?
                }
                let _: RoutineResponse = try await APIClient.shared.request(
                    endpoint: .createRoutine,
                    method: .post,
                    body: CreateRitualBody(title: rec.title, icon: rec.icon, frequency: "daily", scheduledTime: rec.time)
                )
                await store.loadRituals()
                withAnimation(.easeInOut(duration: 0.25)) {
                    rituals = store.rituals
                    ritualsCache = rituals
                }
            } catch {
                print("⚠️ Failed to add recommended ritual: \(error)")
            }
        }
    }

    // MARK: - Data Loading

    private func loadQuests() async {
        do {
            let result: [QuestResponse] = try await APIClient.shared.request(
                endpoint: .quests,
                method: .get
            )
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    quests = result
                }
            }
        } catch {
            print("Failed to load quests: \(error)")
        }
    }

    private func loadData() async {
        let dateKey = selectedDateString
        let isFirst = isInitialLoading
        defer { if isFirst { isInitialLoading = false } }

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
        loadChallenges()
        do {
            let calendarService = CalendarService()
            let fetched = try await calendarService.getTasks(date: dateKey)
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
    }

    private func preloadWeekDots() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let calendarService = CalendarService()
        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: i, to: today) else { continue }
            let dateKey = Self.isoFormatter.string(from: day)
            if tasksCache[dateKey] != nil { continue }
            do {
                let fetched = try await calendarService.getTasks(date: dateKey)
                tasksCache[dateKey] = fetched
            } catch {
                // Silently skip
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

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { syncFeedback = nil }
        }
    }

    // MARK: - Actions

    private func toggleTask(_ task: CalendarTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let wasCompleted = task.isCompleted
        let previousStatus = task.status
        HapticFeedback.light()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            tasks[index].status = wasCompleted ? "pending" : "completed"
        }

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
        HapticFeedback.light()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            rituals[index].isCompleted = !ritual.isCompleted
        }

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

    private func performCreateQuest(title: String, term: String, area: String = "other") {
        Task {
            do {
                struct CreateQuestBody: Encodable {
                    let title: String
                    let area: String
                    let term: String
                }
                let _: QuestResponse = try await APIClient.shared.request(
                    endpoint: .quests,
                    method: .post,
                    body: CreateQuestBody(title: title, area: area, term: term)
                )
                await loadQuests()
            } catch {
                print("Failed to create quest: \(error)")
            }
        }
    }

    private func toggleQuest(_ quest: QuestResponse) {
        let wasCompleted = quest.status == "completed"
        let newStatus = wasCompleted ? "active" : "completed"

        if let index = quests.firstIndex(where: { $0.id == quest.id }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                quests[index] = QuestResponse(
                    id: quest.id, areaId: quest.areaId, areaName: quest.areaName, areaIcon: quest.areaIcon,
                    title: quest.title, status: newStatus,
                    currentValue: wasCompleted ? 0 : quest.targetValue, targetValue: quest.targetValue,
                    targetDate: quest.targetDate, term: quest.term
                )
            }
        }
        Task {
            do {
                try await APIClient.shared.request(
                    endpoint: .completeQuest(quest.id),
                    method: .post
                )
            } catch {
                print("Failed to toggle quest: \(error)")
                await loadQuests()
            }
        }
    }

    private func performDeleteQuest(_ quest: QuestResponse) {
        Task {
            do {
                try await APIClient.shared.request(
                    endpoint: .deleteQuest(quest.id),
                    method: .delete
                )
                withAnimation {
                    quests.removeAll { $0.id == quest.id }
                }
            } catch {
                print("Failed to delete quest: \(error)")
            }
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
    var existingRitualTitles: Set<String> = []
    var onAddRecommended: (((title: String, icon: String, time: String?)) -> Void)?
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

    private var filteredSuggestions: [(title: String, icon: String, time: String?)] {
        PlanningView.recommendedRituals.filter { !existingRitualTitles.contains($0.title.lowercased()) }
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Quick suggestions
                    if !filteredSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggestions rapides")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                                .textCase(.uppercase)
                                .tracking(0.5)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(filteredSuggestions, id: \.title) { rec in
                                        Button(action: {
                                            onAddRecommended?(rec)
                                            dismiss()
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: rec.icon)
                                                    .font(.system(size: 12))
                                                Text(rec.title)
                                                    .font(.system(size: 13, weight: .medium))
                                            }
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                            .background(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

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

// MARK: - Add Quest Sheet

struct AddQuestSheet: View {
    let bgColor: Color
    var onCreate: (String, String, String) -> Void // title, term, area

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedTerm = "short"
    @State private var selectedArea = "other"
    @FocusState private var isFocused: Bool

    private let terms = [
        ("short", "Court terme", "bolt.fill", Color.orange),
        ("medium", "Moyen terme", "calendar", Color.blue),
        ("long", "Long terme", "star.fill", Color.purple),
    ]

    private let areas = [
        ("career", "Carrière", "briefcase.fill", Color.blue),
        ("health", "Santé", "heart.fill", Color.red),
        ("relationships", "Relations", "person.2.fill", Color.pink),
        ("learning", "Apprentissage", "book.fill", Color.green),
        ("creativity", "Créativité", "paintbrush.fill", Color.purple),
        ("other", "Autre", "star.fill", Color.gray),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Nouvel objectif")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.top, 20)

            // Title input
            TextField("", text: $title, prompt: Text("Ex: Courir un semi-marathon").foregroundColor(.white.opacity(0.3)))
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
                .focused($isFocused)

            // Area selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Domaine")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(areas, id: \.0) { area, label, icon, color in
                        Button(action: { selectedArea = area }) {
                            HStack(spacing: 4) {
                                Image(systemName: icon)
                                    .font(.system(size: 11))
                                Text(label)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(selectedArea == area ? bgColor : color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(selectedArea == area ? color : color.opacity(0.15))
                            )
                        }
                    }
                }
            }

            // Term selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Horizon")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                HStack(spacing: 8) {
                    ForEach(terms, id: \.0) { term, label, icon, color in
                        Button(action: { selectedTerm = term }) {
                            HStack(spacing: 4) {
                                Image(systemName: icon)
                                    .font(.system(size: 11))
                                Text(label)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(selectedTerm == term ? bgColor : color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedTerm == term ? color : color.opacity(0.15))
                            )
                        }
                    }
                }
            }

            Spacer()

            // Create button
            Button(action: {
                let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                onCreate(t, selectedTerm, selectedArea)
                dismiss()
            }) {
                Text("Créer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(bgColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 0.9))
                    )
            }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .background(bgColor.ignoresSafeArea())
        .onAppear { isFocused = true }
    }
}

// MARK: - AI Suggestion Models

struct AISuggestion: Identifiable {
    let id = UUID()
    let title: String
    let timeBlock: String
    let reason: String
}

private struct AISuggestionResponse: Codable {
    let title: String
    let time_block: String?
    let reason: String?
}

private struct CreateTaskBody: Codable {
    let title: String
    let date: String
    let timeBlock: String
    let priority: String

    enum CodingKeys: String, CodingKey {
        case title, date, priority
        case timeBlock = "time_block"
    }
}
