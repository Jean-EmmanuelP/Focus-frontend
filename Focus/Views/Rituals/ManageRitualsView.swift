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

    func updateRitual(id: String, title: String, frequency: String, icon: String, scheduledTime: String? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await store.updateRitual(id: id, title: title, frequency: frequency, icon: icon, scheduledTime: scheduledTime)
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
                        .font(.system(size: 22))
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
                SwipeableRitualManageCard(
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
                        viewModel.editingRitual = ritual
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteRitual(ritual)
                        }
                    }
                )
            }

            // Swipe hint
            if viewModel.rituals.filter({ $0.isCompleted }).count == 0 {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 12))
                    Text("routines.swipe_hint".localized)
                        .font(.system(size: 12))
                }
                .foregroundColor(ColorTokens.textMuted)
                .padding(.top, SpacingTokens.xs)
            }
        }
    }
}

// MARK: - Swipeable Ritual Manage Card (with edit/delete on swipe left)
struct SwipeableRitualManageCard: View {
    let ritual: DailyRitual
    let completedCount: Int
    let totalCount: Int
    let onComplete: () -> Void
    let onUndo: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isAnimating = false
    @State private var showSuccess = false
    @State private var cardScale: CGFloat = 1.0
    @State private var checkmarkScale: CGFloat = 0
    @State private var showingDeleteConfirm = false

    private let swipeThreshold: CGFloat = 80
    private let maxSwipe: CGFloat = 120
    private let actionSwipeThreshold: CGFloat = 60

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let successHaptic = UINotificationFeedbackGenerator()

    private var swipeProgress: CGFloat {
        min(abs(offset) / swipeThreshold, 1.0)
    }

    private var isSwipingRight: Bool { offset > 0 }
    private var isSwipingLeft: Bool { offset < 0 }

    var body: some View {
        ZStack {
            // Background revealed on swipe
            HStack(spacing: 0) {
                // Left side - Complete (green)
                if isSwipingRight && !ritual.isCompleted {
                    ZStack {
                        LinearGradient(
                            colors: [ColorTokens.success, ColorTokens.success.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(swipeProgress > 0.5 ? 1.0 : 0.5)
                            .opacity(swipeProgress)
                    }
                    .frame(width: max(0, offset + 20))
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                }

                Spacer()

                // Right side - Edit/Delete actions
                if isSwipingLeft {
                    HStack(spacing: 0) {
                        // Edit button
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                offset = 0
                            }
                            onEdit()
                        }) {
                            ZStack {
                                Color.blue
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 60)
                        }

                        // Delete button
                        Button(action: {
                            showingDeleteConfirm = true
                        }) {
                            ZStack {
                                ColorTokens.error
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 60)
                        }
                    }
                    .frame(width: min(abs(offset) + 20, 140))
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                }
            }

            // Main card
            HStack(spacing: SpacingTokens.md) {
                // Icon
                ZStack {
                    if showSuccess || ritual.isCompleted {
                        Circle()
                            .fill(ColorTokens.success.opacity(ritual.isCompleted && !showSuccess ? 0.15 : 1.0))
                            .frame(width: 32, height: 32)

                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: ritual.isCompleted && !showSuccess ? .semibold : .bold))
                            .foregroundColor(ritual.isCompleted && !showSuccess ? ColorTokens.success : .white)
                            .scaleEffect(showSuccess ? checkmarkScale : 1.0)
                    } else {
                        if ritual.icon.count <= 2 {
                            Text(ritual.icon)
                                .font(.system(size: 22))
                        } else {
                            Image(systemName: ritual.icon)
                                .font(.system(size: 18))
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }
                }
                .frame(width: 32, height: 32)

                // Title and frequency
                VStack(alignment: .leading, spacing: 2) {
                    Text(ritual.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ritual.isCompleted ? ColorTokens.textMuted : ColorTokens.textPrimary)
                        .lineLimit(1)

                    Text(ritual.frequency.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()

                // Swipe hints
                if !isAnimating && offset == 0 {
                    if ritual.isCompleted {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .medium))
                                .opacity(0.5)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .medium))
                                .opacity(0.3)
                        }
                        .foregroundColor(ColorTokens.textMuted)
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .opacity(0.3)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .opacity(0.5)
                        }
                        .foregroundColor(ColorTokens.textMuted)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.md)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ritual.isCompleted || showSuccess ? ColorTokens.success.opacity(0.08) : ColorTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(
                        ritual.isCompleted || showSuccess ? ColorTokens.success.opacity(0.2) : ColorTokens.border.opacity(0.5),
                        lineWidth: 1
                    )
            )
            .scaleEffect(cardScale)
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        guard !isAnimating else { return }
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        // Only handle horizontal swipes
                        guard abs(horizontal) > abs(vertical) * 1.5 else { return }

                        // Swipe right to complete (only if not completed)
                        if horizontal > 0 && !ritual.isCompleted {
                            offset = horizontal < maxSwipe
                                ? horizontal
                                : maxSwipe + (horizontal - maxSwipe) * 0.3
                        }
                        // Swipe left for actions (edit/delete)
                        else if horizontal < 0 {
                            offset = horizontal > -140
                                ? horizontal
                                : -140 + (horizontal + 140) * 0.3
                        }
                    }
                    .onEnded { value in
                        guard !isAnimating else { return }
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        guard abs(horizontal) > abs(vertical) * 1.5 else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset = 0
                            }
                            return
                        }

                        // Complete action
                        if horizontal > swipeThreshold && !ritual.isCompleted {
                            completeRitual()
                        }
                        // Show actions (keep offset at -120 to reveal buttons)
                        else if horizontal < -actionSwipeThreshold {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset = -120
                            }
                        }
                        // Snap back
                        else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .alert("routines.delete_confirm".localized, isPresented: $showingDeleteConfirm) {
            Button("common.cancel".localized, role: .cancel) {
                withAnimation(.spring(response: 0.35)) {
                    offset = 0
                }
            }
            Button("common.delete".localized, role: .destructive) {
                onDelete()
            }
        } message: {
            Text("routines.delete_message".localized(with: ritual.title))
        }
        .onAppear {
            lightHaptic.prepare()
            successHaptic.prepare()
        }
    }

    private func completeRitual() {
        isAnimating = true
        successHaptic.notificationOccurred(.success)

        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            offset = 60
            cardScale = 0.98
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                offset = 0
                cardScale = 1.0
                showSuccess = true
                checkmarkScale = 1.2
            }

            withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(0.1)) {
                checkmarkScale = 1.0
            }

            onComplete()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimating = false
                showSuccess = false
            }
        }
    }
}

// MARK: - Ritual Manage Card (legacy - keeping for compatibility)
struct RitualManageCard: View {
    let ritual: DailyRitual
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Checkbox
            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ritual.isCompleted ? ColorTokens.success : ColorTokens.border, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if ritual.isCompleted {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorTokens.success)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            // Icon
            if ritual.icon.count <= 2 {
                Text(ritual.icon)
                    .font(.system(size: 24))
            } else {
                Image(systemName: ritual.icon)
                    .font(.system(size: 20))
                    .foregroundColor(ColorTokens.primaryStart)
            }

            // Title
            Text(ritual.title)
                .bodyText()
                .foregroundColor(ritual.isCompleted ? ColorTokens.textMuted : ColorTokens.textPrimary)
                .strikethrough(ritual.isCompleted)

            Spacer()

            // Actions menu
            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: {
                    showingDeleteConfirm = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(ColorTokens.textMuted)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
        .alert("routines.delete_confirm".localized, isPresented: $showingDeleteConfirm) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive, action: onDelete)
        } message: {
            Text("routines.delete_message".localized(with: ritual.title))
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

            // Selected icon preview
            HStack {
                Spacer()
                Text(selectedIcon)
                    .font(.system(size: 64))
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

// MARK: - Edit Ritual Sheet
struct EditRitualSheet: View {
    // Don't observe viewModel - only use for save
    let viewModel: RitualsViewModel
    let ritual: DailyRitual
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var selectedIcon: String
    @State private var selectedFrequency = "daily"
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

    init(viewModel: RitualsViewModel, ritual: DailyRitual) {
        self.viewModel = viewModel
        self.ritual = ritual
        _title = State(initialValue: ritual.title)
        _selectedIcon = State(initialValue: ritual.icon)
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
                            "routines.save_changes".localized,
                            isLoading: isLoading,
                            isDisabled: title.isEmpty
                        ) {
                            Task {
                                isLoading = true
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
                    .font(.system(size: 64))
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

// MARK: - Preview
#Preview {
    NavigationStack {
        ManageRitualsView()
    }
}
