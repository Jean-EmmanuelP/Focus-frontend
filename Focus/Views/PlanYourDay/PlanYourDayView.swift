import SwiftUI
import AVFoundation
import Speech
import Combine

// MARK: - Plan Your Day Step
enum PlanYourDayStep: Int, CaseIterable {
    case welcome = 0
    case feeling = 1
    case sleep = 2
    case intention1 = 3
    case intention2 = 4
    case intention3 = 5
    case voicePlanning = 6
    case processing = 7
    case preview = 8
    case feedback = 9
    case confirmed = 10

    var title: String {
        switch self {
        case .welcome: return "plan_day.step.welcome".localized
        case .feeling: return "plan_day.how_feeling".localized
        case .sleep: return "plan_day.sleep_quality".localized
        case .intention1: return "plan_day.intention_1".localized
        case .intention2: return "plan_day.intention_2".localized
        case .intention3: return "plan_day.intention_3".localized
        case .voicePlanning: return "plan_day.voice_planning".localized
        case .processing: return "plan_day.processing".localized
        case .preview: return "plan_day.preview".localized
        case .feedback: return "plan_day.feedback".localized
        case .confirmed: return "plan_day.confirmed".localized
        }
    }

    var isIntentionStep: Bool {
        self == .intention1 || self == .intention2 || self == .intention3
    }
}

// MARK: - Proposed Task UI Model
struct PlanProposedTask: Identifiable {
    let id = UUID()
    var title: String
    var scheduledStart: String?
    var scheduledEnd: String?
    var timeBlock: String
    var priority: String
    var date: String
    var isSelected: Bool = true
}

// MARK: - Main View
struct PlanYourDayView: View {
    @StateObject private var viewModel = PlanYourDayViewModel()
    @EnvironmentObject var store: FocusAppStore
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Content based on step
                stepContent

                // Navigation (hidden on certain steps)
                if !viewModel.currentStep.isVoiceOrProcessingStep {
                    navigationButtons
                }
            }
        }
        .onAppear {
            viewModel.setStore(store)
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.currentStep) { _, newStep in
            if newStep.isIntentionStep {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isTextFieldFocused = true
                }
            }
        }
    }

    // MARK: - Header (Minimal)
    private var headerView: some View {
        VStack(spacing: SpacingTokens.sm) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)

            // Progress bar (thin, elegant)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 3)

                    Capsule()
                        .fill(ColorTokens.fireGradient)
                        .frame(width: geometry.size.width * viewModel.progress, height: 3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.progress)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }

    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            welcomeStep
        case .feeling:
            feelingStep
        case .sleep:
            sleepStep
        case .intention1:
            intentionStep(index: 0)
        case .intention2:
            intentionStep(index: 1)
        case .intention3:
            intentionStep(index: 2)
        case .voicePlanning:
            voicePlanningStep
        case .processing:
            processingStep
        case .preview:
            previewStep
        case .feedback:
            feedbackStep
        case .confirmed:
            confirmedStep
        }
    }

    // MARK: - Welcome Step (Minimal, Direct)
    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: SpacingTokens.lg) {
                Text(viewModel.timeOfDayGreeting)
                    .font(.inter(32, weight: .bold))
                    .foregroundColor(.white)

                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.inter(15))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
    }

    // MARK: - Feeling Step (Clean, Centered)
    private var feelingStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: SpacingTokens.xl) {
                Text("plan_day.how_feeling".localized)
                    .font(.inter(24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // Emoji grid (compact)
                VStack(spacing: SpacingTokens.sm) {
                    HStack(spacing: SpacingTokens.sm) {
                        ForEach(Array(Feeling.allCases.prefix(4)), id: \.self) { feeling in
                            feelingButton(feeling)
                        }
                    }
                    HStack(spacing: SpacingTokens.sm) {
                        ForEach(Array(Feeling.allCases.suffix(4)), id: \.self) { feeling in
                            feelingButton(feeling)
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.md)
            }

            Spacer()
        }
    }

    private func feelingButton(_ feeling: Feeling) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedFeeling = feeling
            }
            HapticFeedback.selection()
        }) {
            Text(feeling.rawValue)
                .font(.system(size: 32))
                .frame(width: 60, height: 60)
                .background(
                    viewModel.selectedFeeling == feeling
                        ? Color.white.opacity(0.15)
                        : Color.white.opacity(0.05)
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            viewModel.selectedFeeling == feeling
                                ? ColorTokens.primaryStart
                                : Color.clear,
                            lineWidth: 2
                        )
                )
                .scaleEffect(viewModel.selectedFeeling == feeling ? 1.1 : 1.0)
        }
    }

    // MARK: - Sleep Step (Minimal, Centered)
    private var sleepStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: SpacingTokens.xl) {
                Text("plan_day.sleep_quality".localized)
                    .font(.inter(24, weight: .bold))
                    .foregroundColor(.white)

                // Sleep display
                VStack(spacing: SpacingTokens.md) {
                    Text(viewModel.sleepEmoji)
                        .font(.system(size: 60))

                    Text("\(viewModel.sleepQuality)")
                        .font(.inter(56, weight: .bold))
                        .foregroundColor(viewModel.sleepColor)
                }

                // Slider (full width, minimal)
                VStack(spacing: SpacingTokens.xs) {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.sleepQuality) },
                            set: { viewModel.sleepQuality = Int($0) }
                        ),
                        in: 1...10,
                        step: 1
                    )
                    .tint(viewModel.sleepColor)

                    HStack {
                        Text("1")
                            .font(.inter(12))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                        Text("10")
                            .font(.inter(12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - Intention Step (Clean, Focused)
    private func intentionStep(index: Int) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: SpacingTokens.xl) {
                // Step indicator
                HStack(spacing: SpacingTokens.sm) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i <= index ? ColorTokens.primaryStart : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }

                Text(intentionTitle(for: index))
                    .font(.inter(24, weight: .bold))
                    .foregroundColor(.white)

                // Text input (minimal, elegant)
                TextField(intentionPlaceholder(for: index), text: $viewModel.intentions[index].text)
                    .focused($isTextFieldFocused)
                    .font(.inter(18))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, SpacingTokens.lg)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(RadiusTokens.lg)
                    .padding(.horizontal, 24)

                // Area selection (horizontal scroll, compact)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SpacingTokens.sm) {
                        ForEach(QuestArea.allCases, id: \.self) { questArea in
                            areaChipButton(questArea: questArea, intentionIndex: index)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            Spacer()
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }

    // MARK: - Area Chip Button
    @ViewBuilder
    private func areaChipButton(questArea: QuestArea, intentionIndex: Int) -> some View {
        let isSelected = viewModel.intentions[intentionIndex].area == questArea

        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.intentions[intentionIndex].area = questArea
            }
            HapticFeedback.selection()
        }) {
            HStack(spacing: 6) {
                Text(questArea.emoji)
                    .font(.system(size: 16))
                Text(questArea.localizedName)
                    .font(.inter(13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? ColorTokens.primaryStart.opacity(0.3) : Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? ColorTokens.primaryStart : Color.clear, lineWidth: 1.5)
            )
        }
    }

    private func intentionEmoji(for index: Int) -> String {
        ["1️⃣", "2️⃣", "3️⃣"][index]
    }

    private func intentionTitle(for index: Int) -> String {
        ["plan_day.intention_1".localized, "plan_day.intention_2".localized, "plan_day.intention_3".localized][index]
    }

    private func intentionPrompt(for index: Int) -> String {
        ["plan_day.intention_prompt_1".localized, "plan_day.intention_prompt_2".localized, "plan_day.intention_prompt_3".localized][index]
    }

    private func intentionPlaceholder(for index: Int) -> String {
        ["plan_day.intention_example_1".localized, "plan_day.intention_example_2".localized, "plan_day.intention_example_3".localized][index]
    }

    // MARK: - Voice Planning Step (Clean Orb)
    private var voicePlanningStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated orb
            ZStack {
                // Outer pulse
                Circle()
                    .fill(ColorTokens.primaryStart.opacity(0.08))
                    .frame(width: 200, height: 200)
                    .scaleEffect(viewModel.isRecording ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: viewModel.isRecording)

                // Middle glow
                Circle()
                    .fill(ColorTokens.primaryStart.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: viewModel.isRecording)

                // Core
                Circle()
                    .fill(viewModel.isRecording ? ColorTokens.primaryStart : Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(viewModel.isRecording ? .white : .white.opacity(0.5))
            }

            VStack(spacing: SpacingTokens.md) {
                Text(viewModel.isRecording ? "plan_day.listening".localized : "plan_day.voice_title".localized)
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(.white)

                if !viewModel.transcribedText.isEmpty {
                    Text(viewModel.transcribedText)
                        .font(.inter(15))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.top, 32)

            Spacer()

            // Action button
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopAndProcess()
                } else {
                    viewModel.startListening()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isRecording ? "checkmark" : "mic.fill")
                    Text(viewModel.isRecording ? "plan_day.validate".localized : "plan_day.start_speaking".localized)
                }
                .font(.inter(16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(ColorTokens.fireGradient)
                .clipShape(Capsule())
            }

            // Skip button - save intentions only without voice planning
            Button(action: {
                Task {
                    await viewModel.skipVoicePlanningAndSaveIntentions()
                }
            }) {
                Text("Passer cette étape")
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, SpacingTokens.md)
            .padding(.bottom, 30)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.startListening()
            }
        }
    }

    // MARK: - Processing Step (Minimal Spinner)
    private var processingStep: some View {
        ProcessingSpinnerView()
    }

    // MARK: - Preview Step (Clean List)
    private var previewStep: some View {
        VStack(spacing: 0) {
            // Title
            Text("plan_day.preview_title".localized)
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Task list
            ScrollView {
                VStack(spacing: 10) {
                    ForEach($viewModel.proposedTasks) { $task in
                        ProposedTaskRow(task: $task)
                    }
                }
                .padding(.horizontal, 20)
            }

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.inter(13))
                    .foregroundColor(ColorTokens.error)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            // Actions (stacked vertically, clean)
            VStack(spacing: 12) {
                Button(action: {
                    Task { await viewModel.confirmAndSaveAll() }
                }) {
                    Text("plan_day.confirm".localized)
                        .font(.inter(16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ColorTokens.fireGradient)
                        .clipShape(Capsule())
                }
                .disabled(viewModel.isLoading)

                HStack(spacing: 24) {
                    Button(action: { viewModel.goToFeedback() }) {
                        Text("plan_day.adjust".localized)
                            .font(.inter(14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Button(action: { viewModel.resetToVoicePlanning() }) {
                        Text("plan_day.redo".localized)
                            .font(.inter(14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Feedback Step (Simplified)
    private var feedbackStep: some View {
        VStack(spacing: 0) {
            Text("plan_day.feedback_title".localized)
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 32)

            Spacer()

            // Text input only (simpler)
            VStack(spacing: SpacingTokens.md) {
                Text("plan_day.feedback_example".localized)
                    .font(.inter(13))
                    .foregroundColor(.white.opacity(0.4))
                    .italic()

                TextField("plan_day.feedback_placeholder".localized, text: $viewModel.feedbackText, axis: .vertical)
                    .font(.inter(16))
                    .foregroundColor(.white)
                    .lineLimit(4...6)
                    .padding(SpacingTokens.lg)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(RadiusTokens.lg)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 16) {
                Button(action: {
                    Task { await viewModel.applyFeedback() }
                }) {
                    Text("plan_day.apply_feedback".localized)
                        .font(.inter(16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Group {
                                if viewModel.feedbackText.isEmpty {
                                    Color.white.opacity(0.1)
                                } else {
                                    ColorTokens.fireGradient
                                }
                            }
                        )
                        .clipShape(Capsule())
                }
                .disabled(viewModel.feedbackText.isEmpty || viewModel.isLoading)

                Button(action: { viewModel.backToPreview() }) {
                    Text("plan_day.back_to_preview".localized)
                        .font(.inter(14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Confirmed Step (Clean Success)
    private var confirmedStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: SpacingTokens.xl) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(ColorTokens.success.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(ColorTokens.success)
                }

                VStack(spacing: 8) {
                    Text("plan_day.success_title".localized)
                        .font(.inter(24, weight: .bold))
                        .foregroundColor(.white)

                    Text("plan_day.success_subtitle".localized(with: viewModel.addedTaskCount))
                        .font(.inter(15))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Intentions summary (minimal)
                VStack(spacing: 8) {
                    ForEach(viewModel.intentions) { intention in
                        if !intention.text.isEmpty {
                            HStack(spacing: 10) {
                                Text(intention.area.emoji)
                                    .font(.system(size: 16))
                                Text(intention.text)
                                    .font(.inter(14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: {
                router.navigateToCalendar()
                dismiss()
            }) {
                Text("plan_day.view_calendar".localized)
                    .font(.inter(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ColorTokens.fireGradient)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
    }

    // MARK: - Navigation Buttons (Clean, Floating)
    private var navigationButtons: some View {
        HStack(spacing: SpacingTokens.md) {
            // Back button (subtle)
            if viewModel.currentStep != .welcome {
                Button(action: {
                    viewModel.previousStep()
                    HapticFeedback.light()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }

            Spacer()

            // Next button (pill)
            Button(action: {
                viewModel.nextStep()
                HapticFeedback.medium()
            }) {
                Text(viewModel.currentStep == .welcome ? "plan_day.lets_go".localized : "common.continue".localized)
                    .font(.inter(16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        viewModel.canProceed
                            ? ColorTokens.fireGradient
                            : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
            .disabled(!viewModel.canProceed)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

// MARK: - Proposed Task Row (Clean for Black BG)
struct ProposedTaskRow: View {
    @Binding var task: PlanProposedTask

    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            Button(action: { task.isSelected.toggle() }) {
                Image(systemName: task.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(task.isSelected ? ColorTokens.primaryStart : .white.opacity(0.3))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.inter(15, weight: .medium))
                    .foregroundColor(task.isSelected ? .white : .white.opacity(0.5))
                    .lineLimit(2)

                if let start = task.scheduledStart, let end = task.scheduledEnd {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("\(start) - \(end)")
                            .font(.inter(12))
                    }
                    .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            // Priority dot
            Circle()
                .fill(priorityColor(task.priority))
                .frame(width: 8, height: 8)
        }
        .padding(14)
        .background(Color.white.opacity(task.isSelected ? 0.08 : 0.04))
        .cornerRadius(12)
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return ColorTokens.error
        case "medium": return ColorTokens.warning
        default: return .white.opacity(0.3)
        }
    }
}

// MARK: - Extension for Step Check
extension PlanYourDayStep {
    var isVoiceOrProcessingStep: Bool {
        self == .voicePlanning || self == .processing || self == .preview || self == .feedback || self == .confirmed
    }
}

// MARK: - Processing Spinner View
struct ProcessingSpinnerView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: SpacingTokens.xl) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 3)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(ColorTokens.primaryStart, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                }

                Text("plan_day.analyzing".localized)
                    .font(.inter(18, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview
#Preview {
    PlanYourDayView()
        .environmentObject(FocusAppStore.shared)
        .environmentObject(AppRouter.shared)
}
