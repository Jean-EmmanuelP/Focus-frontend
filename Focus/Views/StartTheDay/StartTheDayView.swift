import SwiftUI
import Combine

// MARK: - Step Enum
enum StartTheDayStep: Int, CaseIterable {
    case welcome = 0
    case feeling = 1
    case sleep = 2
    case intention1 = 3
    case intention2 = 4
    case intention3 = 5
    case review = 6

    var title: String {
        switch self {
        case .welcome: return "start_day.step.welcome".localized
        case .feeling: return "start_day.how_feeling".localized
        case .sleep: return "start_day.sleep_quality".localized
        case .intention1: return "start_day.intention_1".localized
        case .intention2: return "start_day.intention_2".localized
        case .intention3: return "start_day.intention_3".localized
        case .review: return "start_day.review".localized
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: return "start_day.step.welcome_subtitle".localized
        case .feeling: return "start_day.feeling_hint".localized
        case .sleep: return "start_day.step.sleep_subtitle".localized
        case .intention1: return "start_day.step.intention1_subtitle".localized
        case .intention2: return "start_day.step.intention2_subtitle".localized
        case .intention3: return "start_day.step.intention3_subtitle".localized
        case .review: return "start_day.confirm_subtitle".localized
        }
    }
}

// MARK: - ViewModel
@MainActor
class StartTheDayViewModel: ObservableObject {
    // Step management
    @Published var currentStep: StartTheDayStep = .welcome
    @Published var isAnimating = false

    // Form data
    @Published var selectedFeeling: Feeling?
    @Published var feelingNote: String = ""
    @Published var sleepQuality: Int = 7
    @Published var sleepNote: String = ""
    @Published var intentions: [Intention] = [
        Intention(text: "", area: .health),
        Intention(text: "", area: .career),
        Intention(text: "", area: .learning)
    ]

    // State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isComplete = false

    // Services
    private let intentionsService = IntentionsService()
    private var store: FocusAppStore { FocusAppStore.shared }

    struct Intention: Identifiable {
        let id = UUID()
        var text: String
        var area: QuestArea
    }

    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .feeling:
            return selectedFeeling != nil
        case .sleep:
            return true // Sleep is optional
        case .intention1:
            return !intentions[0].text.trimmingCharacters(in: .whitespaces).isEmpty
        case .intention2:
            return !intentions[1].text.trimmingCharacters(in: .whitespaces).isEmpty
        case .intention3:
            return !intentions[2].text.trimmingCharacters(in: .whitespaces).isEmpty
        case .review:
            return true
        }
    }

    var progress: Double {
        Double(currentStep.rawValue) / Double(StartTheDayStep.allCases.count - 1)
    }

    func nextStep() {
        guard canProceed else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let nextIndex = StartTheDayStep(rawValue: self.currentStep.rawValue + 1) {
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
                if let prevIndex = StartTheDayStep(rawValue: self.currentStep.rawValue - 1) {
                    self.currentStep = prevIndex
                }
                self.isAnimating = false
            }
        }
    }

    func submitCheckIn() async {
        guard canProceed else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Convert feeling to mood rating (1-5) and emoji
            let moodRating = feelingToMoodRating(selectedFeeling ?? .neutral)
            let moodEmoji = selectedFeeling?.rawValue ?? "😐"

            // Convert sleep quality (1-10) to sleep rating (1-5) and emoji
            let sleepRating = (sleepQuality + 1) / 2 // Convert 1-10 to 1-5
            let sleepEmojiStr = sleepQualityEmoji(sleepQuality)

            // Convert intentions to API format
            let intentionInputs = intentions.map { intention in
                IntentionInput(
                    areaId: nil, // Area is optional, could map QuestArea to area ID if needed
                    content: "\(intention.area.emoji) \(intention.text)"
                )
            }

            // Save intentions to backend using correct API
            let response = try await intentionsService.saveIntentions(
                date: Date(),
                moodRating: moodRating,
                moodEmoji: moodEmoji,
                sleepRating: sleepRating,
                sleepEmoji: sleepEmojiStr,
                intentions: intentionInputs
            )

            // Update store directly with the morning check-in data
            let dailyIntentions = intentions.map { intention in
                DailyIntention(
                    id: UUID().uuidString,
                    userId: store.authUserId ?? "",
                    date: Date(),
                    intention: intention.text,
                    area: intention.area,
                    isCompleted: false
                )
            }

            await MainActor.run {
                store.morningCheckIn = MorningCheckIn(
                    id: response.id,
                    userId: store.authUserId ?? "",
                    date: Date(),
                    feeling: selectedFeeling ?? .neutral,
                    feelingNote: feelingNote.isEmpty ? nil : feelingNote,
                    sleepQuality: sleepQuality,
                    sleepNote: sleepNote.isEmpty ? nil : sleepNote,
                    intentions: dailyIntentions
                )

                isComplete = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    // Convert Feeling enum to mood rating (1-5)
    private func feelingToMoodRating(_ feeling: Feeling) -> Int {
        switch feeling {
        case .happy, .excited: return 5
        case .calm: return 4
        case .neutral: return 3
        case .tired, .anxious: return 2
        case .sad, .frustrated: return 1
        }
    }

    // Get emoji for sleep quality
    private func sleepQualityEmoji(_ quality: Int) -> String {
        switch quality {
        case 1...3: return "😴"
        case 4...5: return "😐"
        case 6...7: return "🙂"
        case 8...9: return "😊"
        case 10: return "🌟"
        default: return "😴"
        }
    }
}

// MARK: - Main View
struct StartTheDayView: View {
    @StateObject private var viewModel = StartTheDayViewModel()
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool

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
                        .font(.inter(16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(ColorTokens.surface)
                        .clipShape(Circle())
                }
            }
        }
        .onChange(of: viewModel.currentStep) { _, newStep in
            // Focus text field on intention steps
            if case .intention1 = newStep { focusTextField() }
            if case .intention2 = newStep { focusTextField() }
            if case .intention3 = newStep { focusTextField() }
        }
    }

    private func focusTextField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isTextFieldFocused = true
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
                        .fill(ColorTokens.fireGradient)
                        .frame(width: geometry.size.width * viewModel.progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, SpacingTokens.lg)

            // Step indicator
            HStack {
                Text("start_day.step_indicator".localized(with: viewModel.currentStep.rawValue + 1, StartTheDayStep.allCases.count))
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                Text(viewModel.currentStep.title)
                    .caption()
                    .fontWeight(.medium)
                    .foregroundColor(ColorTokens.primaryStart)
            }
            .padding(.horizontal, SpacingTokens.lg)
        }
        .padding(.top, SpacingTokens.md)
    }

    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: SpacingTokens.xl) {
                    // Anchor at top for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("top")

                    switch viewModel.currentStep {
                    case .welcome:
                        welcomeStep
                    case .feeling:
                        feelingStep
                    case .sleep:
                        sleepStep
                    case .intention1:
                        singleIntentionStep(index: 0)
                    case .intention2:
                        singleIntentionStep(index: 1)
                    case .intention3:
                        singleIntentionStep(index: 2)
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
            .onChange(of: viewModel.currentStep) { _, _ in
                // Scroll to top when step changes
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy.scrollTo("top", anchor: .top)
                }
            }
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

                Text("☀️")
                    .font(.system(size: emojiSize))

                VStack(spacing: SpacingTokens.sm) {
                    Text(timeOfDayGreeting)
                        .heading1()
                        .foregroundColor(ColorTokens.textPrimary)
                        .minimumScaleFactor(0.8)

                    Text(Date().formatted(date: .complete, time: .omitted))
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                        .minimumScaleFactor(0.9)
                }

                Text("start_day.subtitle".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xl)
                    .minimumScaleFactor(0.9)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "start_day.greeting_morning".localized
        } else if hour < 17 {
            return "start_day.greeting_afternoon".localized
        } else {
            return "start_day.greeting_evening".localized
        }
    }

    // MARK: - Feeling Step
    private var feelingStep: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xl) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("start_day.how_feeling".localized)
                    .heading2()
                    .foregroundColor(ColorTokens.textPrimary)

                Text("start_day.feeling_hint".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // Emoji grid (2 rows of 4)
            VStack(spacing: SpacingTokens.md) {
                HStack(spacing: SpacingTokens.md) {
                    ForEach(Array(Feeling.allCases.prefix(4)), id: \.self) { feeling in
                        feelingButton(feeling)
                    }
                }

                HStack(spacing: SpacingTokens.md) {
                    ForEach(Array(Feeling.allCases.suffix(4)), id: \.self) { feeling in
                        feelingButton(feeling)
                    }
                }
            }

            // Optional note
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("start_day.add_note".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)

                CustomTextArea(
                    placeholder: "start_day.note_placeholder".localized,
                    text: $viewModel.feelingNote,
                    minHeight: 80
                )
            }
        }
    }

    private func feelingButton(_ feeling: Feeling) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedFeeling = feeling
            }
            HapticFeedback.selection()
        }) {
            VStack(spacing: SpacingTokens.xs) {
                Text(feeling.rawValue)
                    .font(.inter(36))

                Text(feeling.label)
                    .caption()
                    .foregroundColor(
                        viewModel.selectedFeeling == feeling
                            ? ColorTokens.textPrimary
                            : ColorTokens.textMuted
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.md)
            .background(
                viewModel.selectedFeeling == feeling
                    ? ColorTokens.primarySoft
                    : ColorTokens.surface
            )
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(
                        viewModel.selectedFeeling == feeling
                            ? ColorTokens.primaryStart
                            : ColorTokens.border,
                        lineWidth: viewModel.selectedFeeling == feeling ? 2 : 1
                    )
            )
            .scaleEffect(viewModel.selectedFeeling == feeling ? 1.02 : 1.0)
        }
    }

    // MARK: - Sleep Step
    private var sleepStep: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xl) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("start_day.sleep_quality".localized)
                    .heading2()
                    .foregroundColor(ColorTokens.textPrimary)

                Text("start_day.sleep_hint".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // Large sleep quality display
            VStack(spacing: SpacingTokens.lg) {
                Text(sleepEmoji)
                    .font(.inter(60))

                Text("\(viewModel.sleepQuality)/10")
                    .font(.inter(48, weight: .bold))
                    .foregroundColor(sleepColor)

                Text(sleepDescription)
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.xl)

            // Slider
            VStack(spacing: SpacingTokens.sm) {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.sleepQuality) },
                        set: { viewModel.sleepQuality = Int($0) }
                    ),
                    in: 1...10,
                    step: 1
                )
                .tint(sleepColor)

                HStack {
                    Text("start_day.poor".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                    Spacer()
                    Text("start_day.excellent".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)

            // Optional note
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("start_day.sleep_notes".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)

                CustomTextArea(
                    placeholder: "start_day.sleep_placeholder".localized,
                    text: $viewModel.sleepNote,
                    minHeight: 80
                )
            }
        }
    }

    private var sleepEmoji: String {
        switch viewModel.sleepQuality {
        case 1...3: return "😴"
        case 4...5: return "😐"
        case 6...7: return "🙂"
        case 8...9: return "😊"
        case 10: return "🌟"
        default: return "😴"
        }
    }

    private var sleepColor: Color {
        switch viewModel.sleepQuality {
        case 1...3: return ColorTokens.error
        case 4...5: return ColorTokens.warning
        case 6...7: return ColorTokens.textSecondary
        case 8...10: return ColorTokens.success
        default: return ColorTokens.textSecondary
        }
    }

    private var sleepDescription: String {
        switch viewModel.sleepQuality {
        case 1...2: return "start_day.sleep_1".localized
        case 3...4: return "start_day.sleep_3".localized
        case 5...6: return "start_day.sleep_5".localized
        case 7...8: return "start_day.sleep_7".localized
        case 9...10: return "start_day.sleep_10".localized
        default: return ""
        }
    }

    // MARK: - Single Intention Step
    private func singleIntentionStep(index: Int) -> some View {
        let emoji = intentionEmoji(for: index)
        let prompt = intentionPrompt(for: index)
        let intentionTitle = intentionTitleLocalized(for: index)

        return VStack(spacing: SpacingTokens.lg) {
            // Large emoji
            Text(emoji)
                .font(.inter(60))
                .padding(.top, SpacingTokens.md)

            // Title and subtitle
            VStack(spacing: SpacingTokens.sm) {
                Text(intentionTitle)
                    .heading1()
                    .foregroundColor(ColorTokens.textPrimary)

                Text(prompt)
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.md)
            }

            // Input card
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                // Text input with focus
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("start_day.intention_placeholder".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)

                    TextField(intentionPlaceholder(for: index), text: $viewModel.intentions[index].text)
                        .focused($isTextFieldFocused)
                        .padding(SpacingTokens.md)
                        .background(ColorTokens.surfaceElevated)
                        .cornerRadius(RadiusTokens.md)
                        .foregroundColor(ColorTokens.textPrimary)
                }

                // Area selection
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("start_day.life_area".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)

                    // Area picker - flexible flow layout
                    FlowLayout(spacing: SpacingTokens.sm) {
                        ForEach(QuestArea.allCases, id: \.self) { area in
                            AreaChip(
                                area: area,
                                isSelected: viewModel.intentions[index].area == area
                            ) {
                                viewModel.intentions[index].area = area
                                HapticFeedback.selection()
                            }
                        }
                    }
                }
            }
            .padding(SpacingTokens.lg)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.xl)
        }
    }

    private func intentionEmoji(for index: Int) -> String {
        switch index {
        case 0: return "1️⃣"
        case 1: return "2️⃣"
        case 2: return "3️⃣"
        default: return "🎯"
        }
    }

    private func intentionTitleLocalized(for index: Int) -> String {
        switch index {
        case 0: return "start_day.intention_1".localized
        case 1: return "start_day.intention_2".localized
        case 2: return "start_day.intention_3".localized
        default: return "start_day.intentions".localized
        }
    }

    private func intentionPrompt(for index: Int) -> String {
        switch index {
        case 0: return "start_day.intention_prompt_1".localized
        case 1: return "start_day.intention_prompt_2".localized
        case 2: return "start_day.intention_prompt_3".localized
        default: return "start_day.intention_placeholder".localized
        }
    }

    private func intentionPlaceholder(for index: Int) -> String {
        switch index {
        case 0: return "start_day.intention_example_1".localized
        case 1: return "start_day.intention_example_2".localized
        case 2: return "start_day.intention_example_3".localized
        default: return "start_day.intention_placeholder".localized
        }
    }

    // MARK: - Review Step
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("start_day.review".localized)
                    .heading2()
                    .foregroundColor(ColorTokens.textPrimary)

                Text("start_day.confirm_subtitle".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .padding(.bottom, SpacingTokens.sm)

            // Feeling summary
            reviewCard(
                icon: viewModel.selectedFeeling?.rawValue ?? "😊",
                title: "start_day.feeling".localized,
                value: viewModel.selectedFeeling?.label ?? "start_day.not_set".localized,
                note: viewModel.feelingNote.isEmpty ? nil : viewModel.feelingNote
            )

            // Sleep summary
            reviewCard(
                icon: sleepEmoji,
                title: "start_day.sleep_quality".localized,
                value: "\(viewModel.sleepQuality)/10 - \(sleepDescription)",
                note: viewModel.sleepNote.isEmpty ? nil : viewModel.sleepNote
            )

            // Intentions summary
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    Text("🎯")
                        .font(.inter(24))
                    Text("start_day.focus_areas".localized)
                        .subtitle()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                }

                ForEach(viewModel.intentions) { intention in
                    HStack(spacing: SpacingTokens.sm) {
                        Text(intention.area.emoji)
                            .font(.inter(20))

                        Text(intention.text.isEmpty ? "start_day.not_set".localized : intention.text)
                            .bodyText()
                            .foregroundColor(
                                intention.text.isEmpty
                                    ? ColorTokens.textMuted
                                    : ColorTokens.textPrimary
                            )

                        Spacer()
                    }
                    .padding(SpacingTokens.md)
                    .background(ColorTokens.surfaceElevated)
                    .cornerRadius(RadiusTokens.md)
                }
            }
            .padding(SpacingTokens.lg)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)

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

    private func reviewCard(icon: String, title: String, value: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text(icon)
                    .font(.inter(24))
                Text(title)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
            }

            Text(value)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)

            if let note = note {
                Text(note)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
                    .italic()
            }
        }
        .padding(SpacingTokens.lg)
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
                    "start_day.start_my_day".localized,
                    icon: "☀️",
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.canProceed
                ) {
                    Task {
                        await viewModel.submitCheckIn()
                    }
                }
            } else {
                Button(action: {
                    viewModel.nextStep()
                    HapticFeedback.medium()
                }) {
                    HStack {
                        Text(viewModel.currentStep == .welcome ? "start_day.lets_go".localized : "common.continue".localized)
                        Image(systemName: "chevron.right")
                    }
                    .bodyText()
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.md)
                    .background(
                        viewModel.canProceed
                            ? ColorTokens.fireGradient
                            : LinearGradient(colors: [ColorTokens.textMuted], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(RadiusTokens.lg)
                }
                .disabled(!viewModel.canProceed)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.background)
    }

    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: SpacingTokens.xl) {
            Spacer()

            Text("☀️")
                .font(.inter(100))

            VStack(spacing: SpacingTokens.md) {
                Text("start_day.youre_ready".localized)
                    .heading1()
                    .foregroundColor(ColorTokens.textPrimary)

                Text("start_day.ready_subtitle".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Quick summary
            VStack(spacing: SpacingTokens.sm) {
                ForEach(viewModel.intentions) { intention in
                    HStack {
                        Text(intention.area.emoji)
                        Text(intention.text)
                            .bodyText()
                            .foregroundColor(ColorTokens.textPrimary)
                        Spacer()
                    }
                    .padding(SpacingTokens.sm)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.sm)
                }
            }
            .padding(.horizontal, SpacingTokens.xl)

            Spacer()

            PrimaryButton("start_day.lets_go".localized, icon: "🔥") {
                dismiss()
            }
            .padding(.horizontal, SpacingTokens.lg)
        }
        .padding(SpacingTokens.xl)
    }
}

// MARK: - Area Chip Component
struct AreaChip: View {
    let area: QuestArea
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xs) {
                Text(area.emoji)
                    .font(.inter(14))
                Text(area.localizedName)
                    .caption()
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .white : ColorTokens.textSecondary)
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.sm)
            .background(
                isSelected
                    ? Color(hex: area.color)
                    : ColorTokens.surfaceElevated
            )
            .cornerRadius(RadiusTokens.full)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StartTheDayView()
    }
}
