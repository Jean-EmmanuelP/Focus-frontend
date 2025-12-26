import SwiftUI
import Combine

// MARK: - Rituals ViewModel
@MainActor
class RitualsViewModel: ObservableObject {
    private var store: FocusAppStore { FocusAppStore.shared }
    private var cancellables = Set<AnyCancellable>()

    @Published var rituals: [DailyRitual] = []
    @Published var areas: [Area] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddSheet = false
    @Published var editingRitual: DailyRitual?

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Observe store changes
        store.$rituals
            .receive(on: DispatchQueue.main)
            .assign(to: &$rituals)

        store.$areas
            .receive(on: DispatchQueue.main)
            .assign(to: &$areas)
    }

    func refresh() {
        rituals = store.rituals
        areas = store.areas
    }

    func loadData() async {
        isLoading = true
        await store.refresh()
        isLoading = false
    }

    func toggleRitual(_ ritual: DailyRitual) async {
        await store.toggleRitual(ritual)
        rituals = store.rituals
    }

    func createRitual(areaId: String, title: String, frequency: String, icon: String, scheduledTime: String? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await store.createRitual(areaId: areaId, title: title, frequency: frequency, icon: icon, scheduledTime: scheduledTime)
            rituals = store.rituals
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func updateRitual(id: String, areaId: String? = nil, title: String, frequency: String, icon: String, scheduledTime: String? = nil, durationMinutes: Int? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await store.updateRitual(id: id, areaId: areaId, title: title, frequency: frequency, icon: icon, scheduledTime: scheduledTime, durationMinutes: durationMinutes)
            rituals = store.rituals
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func deleteRitual(_ ritual: DailyRitual) async {
        do {
            try await store.deleteRitual(id: ritual.id)
            rituals = store.rituals
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Manage Rituals View
struct ManageRitualsView: View {
    @StateObject private var viewModel = RitualsViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.rituals.isEmpty {
                LoadingView(message: "routines.loading_areas".localized)
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.lg) {
                        // Header info
                        headerSection

                        // Rituals list
                        if viewModel.rituals.isEmpty {
                            emptyStateView
                        } else {
                            ritualsListSection
                        }
                    }
                    .padding(SpacingTokens.lg)
                }
                .refreshable {
                    await viewModel.loadData()
                }
            }
        }
        .navigationTitle("routines.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.showingAddSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.satoshi(22))
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddRitualSheet(viewModel: viewModel, areas: viewModel.areas)
        }
        .sheet(item: $viewModel.editingRitual) { ritual in
            EditRitualSheet(viewModel: viewModel, ritual: ritual)
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("routines.subtitle".localized)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)

            // Stats row
            HStack(spacing: SpacingTokens.lg) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("\(viewModel.rituals.count)")
                        .heading2()
                        .foregroundColor(ColorTokens.textPrimary)
                    Text("routines.total".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("\(viewModel.rituals.filter { $0.isCompleted }.count)")
                        .heading2()
                        .foregroundColor(ColorTokens.success)
                    Text("routines.done_today".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: SpacingTokens.lg) {
                Spacer()
                    .frame(height: isSmallScreen ? SpacingTokens.xl : 60)

                Text("✨")
                    .font(.system(size: isSmallScreen ? 52 : 64))

                Text("routines.no_routines".localized)
                    .heading2()
                    .foregroundColor(ColorTokens.textPrimary)
                    .minimumScaleFactor(0.8)

                Text("routines.no_routines_hint".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xl)
                    .minimumScaleFactor(0.9)

                PrimaryButton("routines.add_first".localized, icon: "✨") {
                    viewModel.showingAddSheet = true
                }
                .padding(.top, SpacingTokens.md)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Rituals List
    private var ritualsListSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            ForEach(viewModel.rituals) { ritual in
                SimpleRitualRow(
                    ritual: ritual,
                    onToggle: {
                        Task {
                            await viewModel.toggleRitual(ritual)
                        }
                    },
                    onEdit: {
                        viewModel.editingRitual = ritual
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteRitual(ritual)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Simple Ritual Row
struct SimpleRitualRow: View {
    let ritual: DailyRitual
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingActions = false
    @State private var showingDeleteConfirm = false

    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Circle checkbox
            Button(action: {
                hapticGenerator.impactOccurred()
                onToggle()
            }) {
                ZStack {
                    Circle()
                        .stroke(ritual.isCompleted ? ColorTokens.success : ColorTokens.border, lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if ritual.isCompleted {
                        Circle()
                            .fill(ColorTokens.success)
                            .frame(width: 28, height: 28)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Tap to edit - Icon + Title
            Button(action: {
                showingActions = true
            }) {
                HStack(spacing: SpacingTokens.sm) {
                    // Icon
                    if ritual.icon.count <= 2 {
                        Text(ritual.icon)
                            .font(.satoshi(20))
                    } else {
                        Image(systemName: ritual.icon)
                            .font(.satoshi(16))
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Title
                    Text(ritual.title)
                        .font(.satoshi(15, weight: .medium))
                        .foregroundColor(ritual.isCompleted ? ColorTokens.textMuted : ColorTokens.textPrimary)
                        .strikethrough(ritual.isCompleted, color: ColorTokens.textMuted)
                        .lineLimit(1)

                    Spacer()

                    // Scheduled time if any
                    if let time = ritual.scheduledTime {
                        Text(time)
                            .font(.satoshi(12))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm + 2)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
        .confirmationDialog("", isPresented: $showingActions, titleVisibility: .hidden) {
            Button("common.edit".localized) {
                onEdit()
            }
            Button("common.delete".localized, role: .destructive) {
                showingDeleteConfirm = true
            }
            Button("common.cancel".localized, role: .cancel) {}
        }
        .alert("routines.delete_confirm".localized, isPresented: $showingDeleteConfirm) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                onDelete()
            }
        } message: {
            Text("routines.delete_message".localized(with: ritual.title))
        }
        .onAppear {
            hapticGenerator.prepare()
        }
    }
}

// MARK: - Add Ritual Sheet
struct AddRitualSheet: View {
    // Only use viewModel for save action - don't observe changes
    let viewModel: RitualsViewModel
    // Pass areas directly to avoid reactive updates
    let areas: [Area]

    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var selectedIcon = "🌟"
    @State private var selectedAreaId: String?
    @State private var selectedFrequency = "daily"
    @State private var scheduledTime = Date()
    @State private var hasScheduledTime = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    let frequencies = ["daily", "weekdays", "weekends", "weekly"]
    var frequencyLabels: [String] {
        [
            "routines.frequency.daily".localized,
            "routines.frequency.weekdays".localized,
            "routines.frequency.weekends".localized,
            "routines.frequency.weekly".localized
        ]
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

                        // Time picker section
                        timeSection

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

                                // Format time if set
                                var timeString: String? = nil
                                if hasScheduledTime {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "HH:mm"
                                    timeString = formatter.string(from: scheduledTime)
                                }

                                let success = await viewModel.createRitual(
                                    areaId: areaId,
                                    title: title,
                                    frequency: selectedFrequency,
                                    icon: selectedIcon,
                                    scheduledTime: timeString
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

            // Selected icon preview
            HStack {
                Spacer()
                Text(selectedIcon)
                    .font(.satoshi(64))
                Spacer()
            }
            .padding(.vertical, SpacingTokens.md)

            // Icon grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: SpacingTokens.sm) {
                ForEach(iconOptions, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        triggerHaptic()
                    }) {
                        Text(icon)
                            .font(.satoshi(28))
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

    // Filter out placeholder areas - use passed areas, not viewModel
    private var validAreas: [Area] {
        areas.filter { !$0.id.hasPrefix("placeholder-") }
    }

    private var areaSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("routines.life_area".localized)
                .subtitle()
                .foregroundColor(ColorTokens.textPrimary)

            if validAreas.isEmpty {
                // No valid areas - show message
                VStack(spacing: SpacingTokens.md) {
                    Text("routines.no_areas".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
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
                                    .font(.satoshi(16))
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

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("Heure planifiée")
                    .subtitle()
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Toggle("", isOn: $hasScheduledTime)
                    .labelsHidden()
                    .tint(ColorTokens.primaryStart)
            }

            if hasScheduledTime {
                DatePicker(
                    "",
                    selection: $scheduledTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
            } else {
                Text("Active le toggle pour définir une heure")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }
        }
    }
}

// MARK: - Edit Ritual Sheet
struct EditRitualSheet: View {
    // Don't observe viewModel - only use for save
    let viewModel: RitualsViewModel
    let ritual: DailyRitual
    @EnvironmentObject var store: FocusAppStore
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var selectedIcon: String
    @State private var selectedAreaId: String?
    @State private var selectedFrequency: String
    @State private var scheduledTime: Date
    @State private var hasScheduledTime: Bool
    @State private var durationMinutes: Int
    @State private var isLoading = false
    @State private var errorMessage: String?

    let frequencies = ["daily", "weekdays", "weekends", "weekly"]
    let durationOptions = [15, 30, 45, 60, 90, 120]
    var frequencyLabels: [String] {
        [
            "routines.frequency.daily".localized,
            "routines.frequency.weekdays".localized,
            "routines.frequency.weekends".localized,
            "routines.frequency.weekly".localized
        ]
    }

    let iconOptions = ["🌟", "💪", "📚", "🧘", "🏃", "💧", "🍎", "😴", "📝", "🎯", "💡", "🔥"]

    // Pre-prepared haptic generator for instant feedback
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    init(viewModel: RitualsViewModel, ritual: DailyRitual) {
        self.viewModel = viewModel
        self.ritual = ritual
        _title = State(initialValue: ritual.title)
        _selectedIcon = State(initialValue: ritual.icon)
        _selectedAreaId = State(initialValue: ritual.areaId)
        _selectedFrequency = State(initialValue: ritual.frequency.rawValue)

        // Parse existing scheduled time
        if let timeStr = ritual.scheduledTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            if let date = formatter.date(from: timeStr) {
                _scheduledTime = State(initialValue: date)
                _hasScheduledTime = State(initialValue: true)
            } else {
                _scheduledTime = State(initialValue: Date())
                _hasScheduledTime = State(initialValue: false)
            }
        } else {
            _scheduledTime = State(initialValue: Date())
            _hasScheduledTime = State(initialValue: false)
        }

        // Parse existing duration
        _durationMinutes = State(initialValue: ritual.durationMinutes ?? 30)
    }

    // Filter out placeholder areas
    private var validAreas: [Area] {
        store.areas.filter { !$0.id.hasPrefix("placeholder-") }
    }

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

                        // Time picker
                        timeSection

                        // Duration picker (only if time is set)
                        if hasScheduledTime {
                            durationSection
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

                                // Format time if set
                                var timeString: String? = nil
                                if hasScheduledTime {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "HH:mm"
                                    timeString = formatter.string(from: scheduledTime)
                                }

                                let success = await viewModel.updateRitual(
                                    id: ritual.id,
                                    areaId: selectedAreaId,
                                    title: title,
                                    frequency: selectedFrequency,
                                    icon: selectedIcon,
                                    scheduledTime: timeString,
                                    durationMinutes: hasScheduledTime ? durationMinutes : nil
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

            // Selected icon preview
            HStack {
                Spacer()
                Text(selectedIcon)
                    .font(.satoshi(64))
                Spacer()
            }
            .padding(.vertical, SpacingTokens.md)

            // Icon grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: SpacingTokens.sm) {
                ForEach(iconOptions, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        triggerHaptic()
                    }) {
                        Text(icon)
                            .font(.satoshi(28))
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

    private var areaSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Domaine de vie")
                .subtitle()
                .foregroundColor(ColorTokens.textPrimary)

            if validAreas.isEmpty {
                Text("Aucun domaine disponible")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            } else {
                FlowLayout(spacing: SpacingTokens.sm) {
                    ForEach(validAreas) { area in
                        Button(action: {
                            selectedAreaId = area.id
                            triggerHaptic()
                        }) {
                            HStack(spacing: SpacingTokens.xs) {
                                Text(area.icon)
                                    .font(.satoshi(16))
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

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("Heure planifiée")
                    .subtitle()
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Toggle("", isOn: $hasScheduledTime)
                    .labelsHidden()
                    .tint(ColorTokens.primaryStart)
            }

            if hasScheduledTime {
                DatePicker(
                    "",
                    selection: $scheduledTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
            } else {
                Text("Active le toggle pour définir une heure")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Durée")
                .subtitle()
                .foregroundColor(ColorTokens.textPrimary)

            FlowLayout(spacing: SpacingTokens.sm) {
                ForEach(durationOptions, id: \.self) { duration in
                    Button(action: {
                        durationMinutes = duration
                        triggerHaptic()
                    }) {
                        Text(formatDuration(duration))
                            .font(.system(size: 14, weight: durationMinutes == duration ? .semibold : .regular))
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.sm)
                            .background(durationMinutes == duration ? ColorTokens.primarySoft : ColorTokens.surface)
                            .foregroundColor(durationMinutes == duration ? ColorTokens.primaryStart : ColorTokens.textSecondary)
                            .cornerRadius(RadiusTokens.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                                    .stroke(durationMinutes == duration ? ColorTokens.primaryStart : ColorTokens.border, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h\(mins)"
        }
        return "\(minutes)min"
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ManageRitualsView()
    }
}
