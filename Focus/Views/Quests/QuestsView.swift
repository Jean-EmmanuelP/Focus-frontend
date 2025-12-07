import SwiftUI
import Combine

@MainActor
class QuestsViewModel: ObservableObject {
    // Reference to store
    private var store: FocusAppStore { FocusAppStore.shared }
    private var cancellables = Set<AnyCancellable>()

    // Published properties - synced from store
    @Published var isLoading = false
    @Published var selectedTab: QuestTab = .quests
    @Published var quests: [Quest] = []
    @Published var areas: [Area] = []
    @Published var areaProgress: [AreaProgress] = []
    @Published var rituals: [DailyRitual] = []
    @Published var errorMessage: String?
    @Published var showingAddRitualSheet = false
    @Published var ritualToEdit: DailyRitual?

    enum QuestTab: CaseIterable {
        case areas
        case quests
        case routines

        var displayName: String {
            switch self {
            case .areas: return "quests.areas".localized
            case .quests: return "quests.quests".localized
            case .routines: return "routines.title".localized
            }
        }
    }

    init() {
        setupBindings()
        // Sync initial data from store immediately
        syncFromStore()
        // Load quests from API if not already loaded
        Task {
            await loadQuestsIfNeeded()
        }
    }

    /// Load quests from API if the store doesn't have any
    private func loadQuestsIfNeeded() async {
        await store.loadQuestsIfNeeded()
    }

    private func setupBindings() {
        // Observe store changes - all data comes from store
        store.$rituals
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rituals in
                self?.rituals = rituals
            }
            .store(in: &cancellables)

        store.$areas
            .receive(on: DispatchQueue.main)
            .sink { [weak self] areas in
                self?.areas = areas
            }
            .store(in: &cancellables)

        store.$quests
            .receive(on: DispatchQueue.main)
            .sink { [weak self] quests in
                guard let self = self else { return }
                self.quests = quests
                self.areaProgress = self.calculateAreaProgress(from: quests)
            }
            .store(in: &cancellables)

        store.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
    }

    /// Sync data from store without API call
    private func syncFromStore() {
        self.areas = store.areas
        self.rituals = store.rituals
        self.quests = store.quests
        self.areaProgress = calculateAreaProgress(from: store.quests)
        self.isLoading = store.isLoading
    }

    /// Refresh data via store (uses /dashboard endpoint)
    func loadData() async {
        await store.refresh()
    }
    
    private func calculateAreaProgress(from quests: [Quest]) -> [AreaProgress] {
        var progress: [QuestArea: [Double]] = [:]
        
        for quest in quests where quest.status == .active {
            if progress[quest.area] == nil {
                progress[quest.area] = []
            }
            progress[quest.area]?.append(quest.progress)
        }
        
        return QuestArea.allCases.compactMap { area in
            guard let values = progress[area], !values.isEmpty else {
                return AreaProgress(area: area, progress: 0)
            }
            let avgProgress = values.reduce(0, +) / Double(values.count)
            return AreaProgress(area: area, progress: avgProgress)
        }
    }
    
    func refreshData() async {
        await loadData()
    }

    func toggleRitual(_ ritual: DailyRitual) async {
        await store.toggleRitual(ritual)
        rituals = store.rituals
    }

    func createRitual(areaId: String, title: String, frequency: String, icon: String) async -> Bool {
        do {
            try await store.createRitual(areaId: areaId, title: title, frequency: frequency, icon: icon)
            rituals = store.rituals
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateRitual(id: String, title: String?, frequency: String?, icon: String?) async -> Bool {
        do {
            try await store.updateRitual(id: id, title: title, frequency: frequency, icon: icon)
            rituals = store.rituals
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteRitual(id: String) async -> Bool {
        do {
            try await store.deleteRitual(id: id)
            rituals = store.rituals
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Quest CRUD
    @Published var showingAddQuestSheet = false
    @Published var questToEdit: Quest?

    func createQuest(areaId: String, title: String, targetValue: Int) async -> Bool {
        do {
            _ = try await store.createQuest(areaId: areaId, title: title, targetValue: targetValue)
            quests = store.quests
            areaProgress = calculateAreaProgress(from: store.quests)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateQuestProgress(questId: String, progress: Double) async -> Bool {
        // Optimistic update
        if let index = quests.firstIndex(where: { $0.id == questId }) {
            quests[index].progress = progress
            areaProgress = calculateAreaProgress(from: quests)
        }

        do {
            try await store.updateQuest(questId: questId, currentValue: Int(progress * 100), targetValue: 100)
            return true
        } catch {
            // Revert on error
            quests = store.quests
            areaProgress = calculateAreaProgress(from: store.quests)
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateQuest(questId: String, title: String?, status: String?) async -> Bool {
        do {
            try await store.updateQuest(questId: questId, title: title, status: status)
            quests = store.quests
            areaProgress = calculateAreaProgress(from: store.quests)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func incrementQuestProgress(questId: String) async -> Bool {
        do {
            try await store.incrementQuestProgress(questId: questId)
            quests = store.quests
            areaProgress = calculateAreaProgress(from: store.quests)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteQuest(questId: String) async -> Bool {
        do {
            try await store.deleteQuest(questId: questId)
            quests = store.quests
            areaProgress = calculateAreaProgress(from: store.quests)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct QuestsView: View {
    @StateObject private var viewModel = QuestsViewModel()
    
    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.top, SpacingTokens.lg)
                
                // Tab Selector
                tabSelector
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.vertical, SpacingTokens.md)
                
                // Content
                if viewModel.isLoading {
                    LoadingView(message: "common.loading".localized)
                } else {
                    TabView(selection: $viewModel.selectedTab) {
                        areasTab
                            .tag(QuestsViewModel.QuestTab.areas)
                        
                        questsTab
                            .tag(QuestsViewModel.QuestTab.quests)
                        
                        routinesTab
                            .tag(QuestsViewModel.QuestTab.routines)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("🎯")
                    .font(.system(size: 28))

                Text("quests.title".localized)
                    .label()
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()
            }

            Text("quests.subtitle".localized)
                .caption()
                .foregroundColor(ColorTokens.textSecondary)
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(QuestsViewModel.QuestTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation {
                        viewModel.selectedTab = tab
                    }
                }) {
                    Text(tab.displayName)
                        .bodyText()
                        .fontWeight(viewModel.selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(
                            viewModel.selectedTab == tab
                                ? ColorTokens.textPrimary
                                : ColorTokens.textMuted
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.sm)
                        .background(
                            viewModel.selectedTab == tab
                                ? ColorTokens.primarySoft
                                : Color.clear
                        )
                        .cornerRadius(RadiusTokens.sm)
                }
            }
        }
        .padding(SpacingTokens.xs)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }
    
    // MARK: - Areas Tab
    private var areasTab: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.md) {
                if viewModel.areaProgress.isEmpty {
                    EmptyStateView(
                        icon: "🎯",
                        title: "quests.no_areas".localized,
                        subtitle: "quests.no_areas_hint".localized
                    )
                } else {
                    ForEach(viewModel.areaProgress) { progress in
                        ProgressCard(
                            title: "\(progress.area.emoji) \(progress.area.rawValue)",
                            progress: progress.progress,
                            color: Color(hex: progress.area.color)
                        )
                    }
                }
            }
            .padding(SpacingTokens.lg)
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
    
    // MARK: - Quests Tab
    private var questsTab: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.md) {
                // Add button header
                if !viewModel.quests.isEmpty {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.showingAddQuestSheet = true
                        }) {
                            HStack(spacing: SpacingTokens.xs) {
                                Image(systemName: "plus.circle.fill")
                                Text("quests.add_quest".localized)
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTokens.primaryStart)
                        }
                    }
                }

                if viewModel.quests.isEmpty {
                    EmptyStateView(
                        icon: "🎯",
                        title: "quests.no_quests".localized,
                        subtitle: "quests.no_quests_hint".localized,
                        actionTitle: "quests.create_quest".localized,
                        action: {
                            viewModel.showingAddQuestSheet = true
                        }
                    )
                } else {
                    ForEach(viewModel.quests) { quest in
                        SwipeableQuestCard(
                            quest: quest,
                            onProgressChange: { newProgress in
                                Task {
                                    await viewModel.updateQuestProgress(questId: quest.id, progress: newProgress)
                                }
                            },
                            onEdit: {
                                viewModel.questToEdit = quest
                            }
                        )
                    }
                }
            }
            .padding(SpacingTokens.lg)
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .sheet(isPresented: $viewModel.showingAddQuestSheet) {
            AddQuestSheet(viewModel: viewModel, areas: viewModel.areas)
        }
        .sheet(item: $viewModel.questToEdit) { quest in
            EditQuestSheet(viewModel: viewModel, quest: quest)
        }
    }
    
    // MARK: - Routines Tab
    private var routinesTab: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.md) {
                // Add button header
                if !viewModel.rituals.isEmpty {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.showingAddRitualSheet = true
                        }) {
                            HStack(spacing: SpacingTokens.xs) {
                                Image(systemName: "plus.circle.fill")
                                Text("routines.add_routine".localized)
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTokens.primaryStart)
                        }
                    }
                }

                if viewModel.rituals.isEmpty {
                    EmptyStateView(
                        icon: "✨",
                        title: "routines.no_routines".localized,
                        subtitle: "routines.no_routines_hint".localized,
                        actionTitle: "routines.add_routine".localized,
                        action: {
                            viewModel.showingAddRitualSheet = true
                        }
                    )
                } else {
                    ForEach(viewModel.rituals) { ritual in
                        SwipeableRitualCard(
                            ritual: ritual,
                            completedCount: viewModel.rituals.filter { $0.isCompleted }.count,
                            totalCount: viewModel.rituals.count,
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
                            onEdit: {
                                viewModel.ritualToEdit = ritual
                            }
                        )
                    }

                    // Swipe hint
                    if viewModel.rituals.filter({ $0.isCompleted }).count == 0 {
                        HStack(spacing: SpacingTokens.xs) {
                            Image(systemName: "hand.draw")
                                .font(.system(size: 12))
                            Text("quests.swipe_hint".localized)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(ColorTokens.textMuted)
                        .padding(.top, SpacingTokens.xs)
                    }
                }
            }
            .padding(SpacingTokens.lg)
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .sheet(isPresented: $viewModel.showingAddRitualSheet) {
            AddRitualFromQuestsSheet(viewModel: viewModel, areas: viewModel.areas)
        }
        .sheet(item: $viewModel.ritualToEdit) { ritual in
            EditRitualFromQuestsSheet(viewModel: viewModel, ritual: ritual)
        }
    }
}

// MARK: - Add Ritual Sheet (for Quests tab)
struct AddRitualFromQuestsSheet: View {
    // Don't observe viewModel - only use for save action
    let viewModel: QuestsViewModel
    // Pass areas directly to avoid reactive updates
    let areas: [Area]
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var selectedIcon = "🌟"
    @State private var selectedAreaId: String?
    @State private var selectedFrequency = "daily"
    @State private var isLoading = false
    @State private var errorMessage: String?

    let frequencies = ["daily", "weekdays", "weekends", "weekly"]
    var frequencyLabels: [String] {
        ["routines.frequency.daily".localized, "routines.frequency.weekdays".localized, "routines.frequency.weekends".localized, "routines.frequency.weekly".localized]
    }
    let iconOptions = ["🌟", "💪", "📚", "🧘", "🏃", "💧", "🍎", "😴", "📝", "🎯", "💡", "🔥"]

    // Pre-prepared haptic generator for instant feedback
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.xl) {
                        // Icon selector
                        iconSection

                        // Title input
                        titleSection

                        // Area selector
                        areaSection

                        // Frequency selector
                        frequencySection

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
                                let success = await viewModel.createRitual(
                                    areaId: areaId,
                                    title: title,
                                    frequency: selectedFrequency,
                                    icon: selectedIcon
                                )
                                isLoading = false
                                if success {
                                    dismiss()
                                } else {
                                    errorMessage = viewModel.errorMessage
                                }
                            }
                        }
                    }
                    .padding(SpacingTokens.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("routines.new_ritual".localized)
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
            Text("routines.choose_icon".localized)
                .subtitle()
                .foregroundColor(ColorTokens.textPrimary)

            HStack {
                Spacer()
                Text(selectedIcon)
                    .font(.system(size: 64))
                Spacer()
            }
            .padding(.vertical, SpacingTokens.md)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: SpacingTokens.sm) {
                ForEach(iconOptions, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        triggerHaptic()
                    }) {
                        Text(icon)
                            .font(.system(size: 28))
                            .frame(width: 48, height: 48)
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

    // Filter out placeholder areas
    private var validAreas: [Area] {
        areas.filter { !$0.id.hasPrefix("placeholder-") }
    }

    private var areaSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("routines.life_area".localized)
                .subtitle()
                .foregroundColor(ColorTokens.textPrimary)

            if validAreas.isEmpty {
                // No valid areas - show loading or retry
                VStack(spacing: SpacingTokens.md) {
                    Text("routines.loading_areas".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)

                    Button(action: {
                        Task {
                            await viewModel.loadData()
                        }
                    }) {
                        HStack(spacing: SpacingTokens.xs) {
                            Image(systemName: "arrow.clockwise")
                            Text("common.retry".localized)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ColorTokens.primaryStart)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(SpacingTokens.lg)
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
                                    .font(.system(size: 16))
                                Text(area.name)
                                    .caption()
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

            HStack(spacing: SpacingTokens.sm) {
                ForEach(Array(zip(frequencies, frequencyLabels)), id: \.0) { freq, label in
                    Button(action: {
                        selectedFrequency = freq
                        triggerHaptic()
                    }) {
                        Text(label)
                            .caption()
                            .fontWeight(selectedFrequency == freq ? .semibold : .regular)
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

// MARK: - Add Quest Sheet
struct AddQuestSheet: View {
    let viewModel: QuestsViewModel
    let areas: [Area]
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var selectedAreaId: String?
    @State private var targetValue: Double = 1
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

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
                        // Title input
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("quests.quest_title".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            CustomTextField(
                                placeholder: "quests.quest_placeholder".localized,
                                text: $title
                            )
                        }

                        // Area selector
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("routines.life_area".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            if validAreas.isEmpty {
                                Text("routines.loading_areas".localized)
                                    .caption()
                                    .foregroundColor(ColorTokens.textMuted)
                            } else {
                                FlowLayout(spacing: SpacingTokens.sm) {
                                    ForEach(validAreas) { area in
                                        Button(action: {
                                            selectedAreaId = area.id
                                            hapticGenerator.impactOccurred()
                                        }) {
                                            HStack(spacing: SpacingTokens.xs) {
                                                Text(area.icon)
                                                    .font(.system(size: 16))
                                                Text(area.name)
                                                    .caption()
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

                        // Target value
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("quests.target".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            HStack {
                                Text("\(Int(targetValue))")
                                    .heading2()
                                    .foregroundColor(ColorTokens.primaryStart)
                                    .frame(width: 60)

                                Slider(value: $targetValue, in: 1...100, step: 1)
                                    .tint(ColorTokens.primaryStart)
                            }
                            .padding(SpacingTokens.md)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.md)

                            Text("quests.target_hint".localized)
                                .caption()
                                .foregroundColor(ColorTokens.textMuted)
                        }

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .caption()
                                .foregroundColor(ColorTokens.error)
                        }

                        // Save button
                        PrimaryButton(
                            "quests.create_quest".localized,
                            isLoading: isLoading,
                            isDisabled: title.isEmpty || selectedAreaId == nil
                        ) {
                            Task {
                                guard let areaId = selectedAreaId else { return }
                                isLoading = true
                                errorMessage = nil
                                let success = await viewModel.createQuest(
                                    areaId: areaId,
                                    title: title,
                                    targetValue: Int(targetValue)
                                )
                                isLoading = false
                                if success {
                                    dismiss()
                                } else {
                                    errorMessage = viewModel.errorMessage
                                }
                            }
                        }
                    }
                    .padding(SpacingTokens.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("quests.new_quest".localized)
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
}

// MARK: - Edit Quest Sheet
struct EditQuestSheet: View {
    let viewModel: QuestsViewModel
    let quest: Quest
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    init(viewModel: QuestsViewModel, quest: Quest) {
        self.viewModel = viewModel
        self.quest = quest
        self._title = State(initialValue: quest.title)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.xl) {
                        // Quest info header
                        VStack(spacing: SpacingTokens.md) {
                            Text(quest.area.emoji)
                                .font(.system(size: 48))

                            HStack(spacing: SpacingTokens.xs) {
                                Text(quest.area.rawValue)
                                    .caption()
                                    .foregroundColor(ColorTokens.textSecondary)
                            }
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.xs)
                            .background(Color(hex: quest.area.color).opacity(0.2))
                            .cornerRadius(RadiusTokens.full)
                        }

                        // Title input
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("quests.quest_title".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            CustomTextField(
                                placeholder: "quests.quest_placeholder".localized,
                                text: $title
                            )
                        }

                        // Current progress (read-only display)
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("quests.current_progress".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            HStack(spacing: SpacingTokens.md) {
                                ProgressBar(
                                    progress: quest.progress,
                                    color: Color(hex: quest.area.color),
                                    height: 12
                                )

                                Text("\(Int(quest.progress * 100))%")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: quest.area.color))
                            }
                            .padding(SpacingTokens.md)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.md)

                            Text("quests.progress_hint".localized)
                                .caption()
                                .foregroundColor(ColorTokens.textMuted)
                        }

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .caption()
                                .foregroundColor(ColorTokens.error)
                        }

                        // Save button
                        PrimaryButton(
                            "routines.save_changes".localized,
                            isLoading: isLoading,
                            isDisabled: title.isEmpty || title == quest.title
                        ) {
                            Task {
                                isLoading = true
                                errorMessage = nil
                                let success = await viewModel.updateQuest(
                                    questId: quest.id,
                                    title: title,
                                    status: nil
                                )
                                isLoading = false
                                if success {
                                    dismiss()
                                } else {
                                    errorMessage = viewModel.errorMessage
                                }
                            }
                        }

                        // Mark as complete button
                        if quest.status != .completed {
                            SecondaryButton("quests.mark_complete".localized) {
                                Task {
                                    isLoading = true
                                    let success = await viewModel.updateQuest(
                                        questId: quest.id,
                                        title: nil,
                                        status: "completed"
                                    )
                                    isLoading = false
                                    if success {
                                        dismiss()
                                    }
                                }
                            }
                        }

                        // Delete button
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("quests.delete_quest".localized)
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTokens.error)
                        }
                        .padding(.top, SpacingTokens.lg)
                    }
                    .padding(SpacingTokens.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("quests.edit_quest".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
            .alert("quests.delete_quest".localized, isPresented: $showDeleteConfirmation) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("common.delete".localized, role: .destructive) {
                    Task {
                        let success = await viewModel.deleteQuest(questId: quest.id)
                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("quests.delete_confirm".localized)
            }
        }
    }
}

// MARK: - Quest Detail View (Placeholder)
struct QuestDetailView: View {
    let quest: Quest

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: SpacingTokens.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: SpacingTokens.md) {
                        HStack {
                            Text(quest.area.emoji)
                                .font(.system(size: 32))

                            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                                Text(quest.area.rawValue)
                                    .caption()
                                    .foregroundColor(ColorTokens.textSecondary)

                                Text(quest.title)
                                    .heading2()
                                    .foregroundColor(ColorTokens.textPrimary)
                            }

                            Spacer()
                        }
                        
                        // Progress
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            HStack {
                                Text("quests.progress".localized)
                                    .caption()
                                    .foregroundColor(ColorTokens.textMuted)

                                Spacer()

                                Text("\(Int(quest.progress * 100))%")
                                    .heading2()
                                    .foregroundColor(ColorTokens.primaryStart)
                            }
                            
                            ProgressBar(
                                progress: quest.progress,
                                color: Color(hex: quest.area.color),
                                height: 12
                            )
                        }
                    }
                    
                    // Target date
                    if let targetDate = quest.targetDate {
                        Card {
                            HStack {
                                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                                    Text("quests.target_date".localized)
                                        .caption()
                                        .foregroundColor(ColorTokens.textMuted)

                                    Text(targetDate.formatted(date: .long, time: .omitted))
                                        .bodyText()
                                        .foregroundColor(ColorTokens.textPrimary)
                                }

                                Spacer()
                            }
                        }
                    }

                    // Actions
                    VStack(spacing: SpacingTokens.md) {
                        PrimaryButton("quests.update_progress".localized) {
                            // TODO: Update progress
                        }

                        SecondaryButton("quests.edit_quest".localized) {
                            // TODO: Edit quest
                        }
                    }
                }
                .padding(SpacingTokens.lg)
            }
        }
        .navigationTitle("quests.quest_details".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Focus Session View (Placeholder)
struct FocusSessionView: View {
    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            Text("fire.focus_session".localized)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)
        }
        .navigationTitle("fire.focus_session".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Edit Ritual From Quests Sheet
struct EditRitualFromQuestsSheet: View {
    let viewModel: QuestsViewModel
    let ritual: DailyRitual
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var selectedIcon: String
    @State private var selectedFrequency: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    let frequencies = ["daily", "weekdays", "weekends", "weekly"]
    var frequencyLabels: [String] {
        ["routines.frequency.daily".localized, "routines.frequency.weekdays".localized, "routines.frequency.weekends".localized, "routines.frequency.weekly".localized]
    }
    let iconOptions = ["🌟", "💪", "📚", "🧘", "🏃", "💧", "🍎", "😴", "📝", "🎯", "💡", "🔥"]

    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    init(viewModel: QuestsViewModel, ritual: DailyRitual) {
        self.viewModel = viewModel
        self.ritual = ritual
        self._title = State(initialValue: ritual.title)
        self._selectedIcon = State(initialValue: ritual.icon)
        self._selectedFrequency = State(initialValue: ritual.frequency.rawValue)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.xl) {
                        // Icon selector
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("routines.choose_icon".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: SpacingTokens.md) {
                                ForEach(iconOptions, id: \.self) { icon in
                                    Button(action: {
                                        selectedIcon = icon
                                        hapticGenerator.impactOccurred()
                                    }) {
                                        Text(icon)
                                            .font(.system(size: 28))
                                            .frame(width: 48, height: 48)
                                            .background(selectedIcon == icon ? ColorTokens.primarySoft : ColorTokens.surface)
                                            .cornerRadius(RadiusTokens.md)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: RadiusTokens.md)
                                                    .stroke(selectedIcon == icon ? ColorTokens.primaryStart : ColorTokens.border, lineWidth: selectedIcon == icon ? 2 : 1)
                                            )
                                    }
                                }
                            }
                        }

                        // Title input
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("routines.ritual_name".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            CustomTextField(
                                placeholder: "routines.ritual_placeholder".localized,
                                text: $title
                            )
                        }

                        // Frequency selector
                        VStack(alignment: .leading, spacing: SpacingTokens.md) {
                            Text("routines.frequency".localized)
                                .subtitle()
                                .foregroundColor(ColorTokens.textPrimary)

                            HStack(spacing: SpacingTokens.sm) {
                                ForEach(Array(zip(frequencies, frequencyLabels)), id: \.0) { freq, label in
                                    Button(action: {
                                        selectedFrequency = freq
                                        hapticGenerator.impactOccurred()
                                    }) {
                                        Text(label)
                                            .caption()
                                            .fontWeight(selectedFrequency == freq ? .semibold : .regular)
                                            .padding(.horizontal, SpacingTokens.md)
                                            .padding(.vertical, SpacingTokens.sm)
                                            .background(selectedFrequency == freq ? ColorTokens.primarySoft : ColorTokens.surface)
                                            .foregroundColor(selectedFrequency == freq ? ColorTokens.primaryStart : ColorTokens.textSecondary)
                                            .cornerRadius(RadiusTokens.sm)
                                    }
                                }
                            }
                        }

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .caption()
                                .foregroundColor(ColorTokens.error)
                        }

                        // Save button
                        PrimaryButton(
                            "routines.save_changes".localized,
                            isLoading: isLoading,
                            isDisabled: title.isEmpty
                        ) {
                            Task {
                                isLoading = true
                                errorMessage = nil
                                let success = await viewModel.updateRitual(
                                    id: ritual.id,
                                    title: title,
                                    frequency: selectedFrequency,
                                    icon: selectedIcon
                                )
                                isLoading = false
                                if success {
                                    dismiss()
                                } else {
                                    errorMessage = viewModel.errorMessage
                                }
                            }
                        }

                        // Delete button
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("routines.delete_ritual".localized)
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTokens.error)
                        }
                        .padding(.top, SpacingTokens.md)
                    }
                    .padding(SpacingTokens.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("routines.edit_ritual".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
            .alert("routines.delete_confirm".localized, isPresented: $showDeleteConfirmation) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("common.delete".localized, role: .destructive) {
                    Task {
                        let success = await viewModel.deleteRitual(id: ritual.id)
                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("routines.delete_message".localized(with: ritual.title))
            }
            .onAppear {
                hapticGenerator.prepare()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    QuestsView()
}
