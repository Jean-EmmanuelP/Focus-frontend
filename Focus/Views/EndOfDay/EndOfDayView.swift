import SwiftUI
import Combine

// MARK: - Step Enum
enum EndOfDayStep: Int, CaseIterable {
    case welcome = 0
    case rituals = 1
    case biggestWin = 2
    case challenges = 3
    case gratitude = 4
    case tomorrow = 5
    case review = 6

    var title: String {
        switch self {
        case .welcome: return "end_day.title".localized
        case .rituals: return "end_day.daily_rituals".localized
        case .biggestWin: return "end_day.biggest_win".localized
        case .challenges: return "end_day.challenges".localized
        case .gratitude: return "end_day.best_moment".localized
        case .tomorrow: return "end_day.tomorrow".localized
        case .review: return "end_day.summary".localized
        }
    }

    var emoji: String {
        switch self {
        case .welcome: return "🌙"
        case .rituals: return "✅"
        case .biggestWin: return "🏆"
        case .challenges: return "🚧"
        case .gratitude: return "✨"
        case .tomorrow: return "🎯"
        case .review: return "📋"
        }
    }
}

// MARK: - ViewModel
@MainActor
class EndOfDayViewModel: ObservableObject {
    // Reference to store - single source of truth
    private var store: FocusAppStore { FocusAppStore.shared }
    private var cancellables = Set<AnyCancellable>()

    // Step management
    @Published var currentStep: EndOfDayStep = .welcome
    @Published var isAnimating = false

    // Form data - rituals come from store
    @Published var rituals: [DailyRitual] = []
    @Published var biggestWin: String = ""
    @Published var blockers: String = ""
    @Published var bestMoment: String = ""
    @Published var tomorrowGoal: String = ""

    // State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isComplete = false

    /// Rituals for today (already filtered by backend via todays_routines)
    /// Note: The backend already returns only the routines that should be shown today
    var todaysRituals: [DailyRitual] {
        rituals
    }

    var completedRitualCount: Int {
        todaysRituals.filter { $0.isCompleted }.count
    }

    var totalRitualCount: Int {
        todaysRituals.count
    }

    var ritualCompletionPercentage: Double {
        guard totalRitualCount > 0 else { return 0 }
        return Double(completedRitualCount) / Double(totalRitualCount)
    }

    var progress: Double {
        Double(currentStep.rawValue) / Double(EndOfDayStep.allCases.count - 1)
    }

    var canProceed: Bool {
        switch currentStep {
        case .welcome, .rituals, .biggestWin, .challenges, .gratitude, .tomorrow, .review:
            return true // All steps are optional for evening review
        }
    }

    init() {
        // Get rituals directly from store - NO API call needed
        self.rituals = store.rituals

        // Subscribe to store changes for live updates
        store.$rituals
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rituals in
                self?.rituals = rituals
            }
            .store(in: &cancellables)
    }

    func toggleRitual(_ ritual: DailyRitual) async {
        // Use store method which handles API + local state
        await store.toggleRitual(ritual)
        HapticFeedback.success()
    }

    func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let nextIndex = EndOfDayStep(rawValue: self.currentStep.rawValue + 1) {
                    self.currentStep = nextIndex
                }
                self.isAnimating = false
            }
        }
    }

    func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let prevIndex = EndOfDayStep(rawValue: self.currentStep.rawValue - 1) {
                    self.currentStep = prevIndex
                }
                self.isAnimating = false
            }
        }
    }

    func submitReview() async {
        isLoading = true
        errorMessage = nil

        // Use store method to save reflection
        await store.saveReflection(
            biggestWin: biggestWin.isEmpty ? nil : biggestWin,
            challenges: blockers.isEmpty ? nil : blockers,
            bestMoment: bestMoment.isEmpty ? nil : bestMoment,
            goalForTomorrow: tomorrowGoal.isEmpty ? nil : tomorrowGoal
        )

        HapticFeedback.success()
        isComplete = true
        isLoading = false
    }
}

// MARK: - Main View
struct EndOfDayView: View {
    @StateObject private var viewModel = EndOfDayViewModel()
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            if viewModel.isComplete {
                successView
            } else {
                VStack(spacing: 0) {
                    // Header with progress
                    headerView

                    // Step content
                    stepContent
                        .opacity(viewModel.isAnimating ? 0 : 1)

                    Spacer()

                    // Navigation buttons
                    navigationButtons
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: SpacingTokens.md) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.surface)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, SpacingTokens.lg)

            // Step indicator
            HStack {
                Text("end_day.step_indicator".localized(with: viewModel.currentStep.rawValue + 1, EndOfDayStep.allCases.count))
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                HStack(spacing: SpacingTokens.xs) {
                    Text(viewModel.currentStep.emoji)
                    Text(viewModel.currentStep.title)
                        .fontWeight(.medium)
                }
                .caption()
                .foregroundColor(Color.purple)
            }
            .padding(.horizontal, SpacingTokens.lg)
        }
        .padding(.top, SpacingTokens.md)
    }

    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.xl) {
                switch viewModel.currentStep {
                case .welcome:
                    welcomeStep
                case .rituals:
                    ritualsStep
                case .biggestWin:
                    reflectionStep(
                        emoji: "🏆",
                        title: "end_day.biggest_win_question".localized,
                        subtitle: "end_day.biggest_win_hint".localized,
                        placeholder: "end_day.biggest_win_placeholder".localized,
                        text: $viewModel.biggestWin,
                        examples: [
                            "end_day.example_task".localized,
                            "end_day.example_helped".localized,
                            "end_day.example_learned".localized,
                            "end_day.example_focused".localized
                        ]
                    )
                case .challenges:
                    reflectionStep(
                        emoji: "🚧",
                        title: "end_day.challenges_question".localized,
                        subtitle: "end_day.challenges_hint".localized,
                        placeholder: "end_day.challenges_placeholder".localized,
                        text: $viewModel.blockers,
                        examples: [
                            "end_day.example_distractions".localized,
                            "end_day.example_conversation".localized,
                            "end_day.example_time".localized,
                            "end_day.example_energy".localized
                        ]
                    )
                case .gratitude:
                    reflectionStep(
                        emoji: "✨",
                        title: "end_day.best_moment_question".localized,
                        subtitle: "end_day.best_moment_hint".localized,
                        placeholder: "end_day.best_moment_placeholder".localized,
                        text: $viewModel.bestMoment,
                        examples: [
                            "end_day.example_good_conversation".localized,
                            "end_day.example_achieving".localized,
                            "end_day.example_peaceful".localized,
                            "end_day.example_funny".localized
                        ]
                    )
                case .tomorrow:
                    reflectionStep(
                        emoji: "🎯",
                        title: "end_day.tomorrow_question".localized,
                        subtitle: "end_day.tomorrow_hint".localized,
                        placeholder: "end_day.tomorrow_placeholder".localized,
                        text: $viewModel.tomorrowGoal,
                        examples: [
                            "end_day.example_project".localized,
                            "end_day.example_exercise".localized,
                            "end_day.example_talk".localized,
                            "end_day.example_learn".localized
                        ]
                    )
                case .review:
                    reviewStep
                }
            }
            .padding(SpacingTokens.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            hideKeyboard()
        }
    }

    // MARK: - Welcome Step
    private var welcomeStep: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 500
            let emojiSize: CGFloat = isSmallScreen ? 60 : 80

            VStack(spacing: isSmallScreen ? SpacingTokens.lg : SpacingTokens.xl) {
                Spacer()
                    .frame(height: isSmallScreen ? SpacingTokens.lg : 40)

                Text("🌙")
                    .font(.system(size: emojiSize))

                VStack(spacing: SpacingTokens.sm) {
                    Text("end_day.time_to_reflect".localized)
                        .heading1()
                        .foregroundColor(ColorTokens.textPrimary)
                        .minimumScaleFactor(0.8)

                    Text(Date().formatted(date: .complete, time: .omitted))
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                        .minimumScaleFactor(0.9)
                }

                Text("end_day.subtitle".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xl)
                    .minimumScaleFactor(0.9)

                // Quick stats preview
                if !viewModel.todaysRituals.isEmpty {
                    HStack(spacing: SpacingTokens.lg) {
                        statBadge(
                            value: "\(viewModel.completedRitualCount)/\(viewModel.totalRitualCount)",
                            label: "end_day.rituals".localized
                        )
                    }
                    .padding(.top, isSmallScreen ? SpacingTokens.md : SpacingTokens.lg)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(value)
                .heading2()
                .foregroundColor(ColorTokens.textPrimary)
            Text(label)
                .caption()
                .foregroundColor(ColorTokens.textMuted)
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }

    // MARK: - Rituals Step
    private var ritualsStep: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xl) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("end_day.your_rituals".localized)
                    .heading2()
                    .foregroundColor(ColorTokens.textPrimary)

                Text("end_day.rituals_hint".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // Progress indicator
            VStack(spacing: SpacingTokens.sm) {
                HStack {
                    Text("end_day.rituals_progress".localized(with: viewModel.completedRitualCount, viewModel.totalRitualCount))
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()
                    Text("\(Int(viewModel.ritualCompletionPercentage * 100))%")
                        .subtitle()
                        .fontWeight(.bold)
                        .foregroundColor(completionColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorTokens.surface)
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(completionColor)
                            .frame(width: geometry.size.width * viewModel.ritualCompletionPercentage, height: 12)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.ritualCompletionPercentage)
                    }
                }
                .frame(height: 12)
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surfaceElevated)
            .cornerRadius(RadiusTokens.md)

            // Rituals list
            if viewModel.todaysRituals.isEmpty {
                Card {
                    HStack {
                        Text("routines.no_scheduled".localized)
                            .bodyText()
                            .foregroundColor(ColorTokens.textMuted)
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: SpacingTokens.sm) {
                    ForEach(viewModel.todaysRituals) { ritual in
                        RitualToggleCard(ritual: ritual) {
                            Task {
                                await viewModel.toggleRitual(ritual)
                            }
                        }
                    }
                }
            }
        }
    }

    private var completionColor: Color {
        switch viewModel.ritualCompletionPercentage {
        case 0..<0.3: return ColorTokens.error
        case 0.3..<0.6: return ColorTokens.warning
        case 0.6..<0.9: return Color.blue
        default: return ColorTokens.success
        }
    }

    // MARK: - Generic Reflection Step
    private func reflectionStep(
        emoji: String,
        title: String,
        subtitle: String,
        placeholder: String,
        text: Binding<String>,
        examples: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xl) {
            // Header
            VStack(alignment: .center, spacing: SpacingTokens.md) {
                Text(emoji)
                    .font(.system(size: 60))

                VStack(spacing: SpacingTokens.xs) {
                    Text(title)
                        .heading2()
                        .foregroundColor(ColorTokens.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)

            // Text area
            CustomTextArea(
                placeholder: placeholder,
                text: text,
                minHeight: 120
            )

            // Example prompts
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("end_day.ideas".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)

                FlowLayout(spacing: SpacingTokens.sm) {
                    ForEach(examples, id: \.self) { example in
                        Button(action: {
                            if text.wrappedValue.isEmpty {
                                text.wrappedValue = example
                            } else {
                                text.wrappedValue += ", \(example.lowercased())"
                            }
                            HapticFeedback.selection()
                        }) {
                            Text(example)
                                .caption()
                                .foregroundColor(ColorTokens.textSecondary)
                                .padding(.horizontal, SpacingTokens.sm)
                                .padding(.vertical, SpacingTokens.xs)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.full)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Review Step
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xl) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("end_day.your_day_review".localized)
                    .heading2()
                    .foregroundColor(ColorTokens.textPrimary)

                Text("end_day.summary_hint".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // Rituals summary
            summaryCard(
                emoji: "✅",
                title: "end_day.rituals".localized,
                value: "end_day.rituals_completed".localized(with: viewModel.completedRitualCount, viewModel.totalRitualCount),
                color: completionColor
            )

            // Reflections summary
            if !viewModel.biggestWin.isEmpty {
                summaryCard(emoji: "🏆", title: "end_day.biggest_win".localized, value: viewModel.biggestWin)
            }

            if !viewModel.blockers.isEmpty {
                summaryCard(emoji: "🚧", title: "end_day.challenges".localized, value: viewModel.blockers)
            }

            if !viewModel.bestMoment.isEmpty {
                summaryCard(emoji: "✨", title: "end_day.best_moment".localized, value: viewModel.bestMoment)
            }

            if !viewModel.tomorrowGoal.isEmpty {
                summaryCard(emoji: "🎯", title: "end_day.tomorrow_goal".localized, value: viewModel.tomorrowGoal)
            }

            // Empty state
            if viewModel.biggestWin.isEmpty && viewModel.blockers.isEmpty &&
               viewModel.bestMoment.isEmpty && viewModel.tomorrowGoal.isEmpty {
                Card {
                    VStack(spacing: SpacingTokens.sm) {
                        Text("💭")
                            .font(.system(size: 40))
                        Text("end_day.no_reflections".localized)
                            .bodyText()
                            .foregroundColor(ColorTokens.textMuted)
                        Text("end_day.no_reflections_hint".localized)
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(SpacingTokens.md)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .caption()
                    .foregroundColor(ColorTokens.error)
                    .padding(SpacingTokens.md)
                    .background(ColorTokens.error.opacity(0.1))
                    .cornerRadius(RadiusTokens.md)
            }
        }
    }

    private func summaryCard(emoji: String, title: String, value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text(emoji)
                    .font(.system(size: 20))
                Text(title)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
            }

            Text(value)
                .bodyText()
                .foregroundColor(color ?? ColorTokens.textSecondary)
                .lineLimit(3)
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: SpacingTokens.md) {
            // Back button
            if viewModel.currentStep != .welcome {
                Button(action: {
                    viewModel.previousStep()
                    HapticFeedback.light()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("common.back".localized)
                    }
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.md)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.lg)
                }
            }

            // Next/Submit button
            if viewModel.currentStep == .review {
                PrimaryButton(
                    "end_day.complete_review".localized,
                    icon: "🌙",
                    isLoading: viewModel.isLoading
                ) {
                    Task {
                        await viewModel.submitReview()
                    }
                }
            } else {
                Button(action: {
                    viewModel.nextStep()
                    HapticFeedback.medium()
                }) {
                    HStack {
                        Text(viewModel.currentStep == .welcome ? "end_day.lets_reflect".localized : "common.continue".localized)
                        Image(systemName: "chevron.right")
                    }
                    .bodyText()
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.md)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(RadiusTokens.lg)
                }
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.background)
    }

    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: SpacingTokens.xl) {
            Spacer()

            Text("🌙")
                .font(.system(size: 100))

            VStack(spacing: SpacingTokens.md) {
                Text("end_day.day_complete".localized)
                    .heading1()
                    .foregroundColor(ColorTokens.textPrimary)

                Text("end_day.rest_well".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Stats
            HStack(spacing: SpacingTokens.xl) {
                VStack {
                    Text("\(viewModel.completedRitualCount)")
                        .heading1()
                        .foregroundColor(ColorTokens.success)
                    Text("end_day.rituals_done".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                if !viewModel.tomorrowGoal.isEmpty {
                    VStack {
                        Text("🎯")
                            .font(.system(size: 32))
                        Text("end_day.goal_set".localized)
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
            }
            .padding(.top, SpacingTokens.lg)

            Spacer()

            PrimaryButton("end_day.good_night".localized, icon: "😴") {
                dismiss()
            }
            .padding(.horizontal, SpacingTokens.lg)
        }
        .padding(SpacingTokens.xl)
    }
}

// MARK: - Ritual Toggle Card
struct RitualToggleCard: View {
    let ritual: DailyRitual
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: SpacingTokens.md) {
                // Icon
                if ritual.icon.count <= 2 {
                    Text(ritual.icon)
                        .font(.system(size: 24))
                } else {
                    Image(systemName: ritual.icon)
                        .font(.system(size: 20))
                        .foregroundColor(ritual.isCompleted ? ColorTokens.success : ColorTokens.textMuted)
                }

                // Title
                Text(ritual.title)
                    .bodyText()
                    .foregroundColor(ritual.isCompleted ? ColorTokens.textSecondary : ColorTokens.textPrimary)
                    .strikethrough(ritual.isCompleted, color: ColorTokens.textMuted)

                Spacer()

                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            ritual.isCompleted ? ColorTokens.success : ColorTokens.border,
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)

                    if ritual.isCompleted {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorTokens.success)
                            .frame(width: 28, height: 28)

                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(SpacingTokens.md)
            .background(ritual.isCompleted ? ColorTokens.success.opacity(0.1) : ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(ritual.isCompleted ? ColorTokens.success.opacity(0.3) : ColorTokens.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        EndOfDayView()
    }
}
