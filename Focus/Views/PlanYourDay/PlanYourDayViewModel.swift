import SwiftUI
import AVFoundation
import Speech
import Combine

// MARK: - Feedback Mode
enum FeedbackMode {
    case voice
    case text
}

// MARK: - Intention Model
struct PlanIntention: Identifiable {
    let id = UUID()
    var text: String
    var area: QuestArea
}

// MARK: - ViewModel
@MainActor
class PlanYourDayViewModel: ObservableObject {
    // MARK: - Services
    private let voiceService = VoiceService()
    private let calendarService = CalendarService()
    private let intentionsService = IntentionsService()
    private var store: FocusAppStore?

    // MARK: - Speech Recognition
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?

    // MARK: - Published State
    @Published var currentStep: PlanYourDayStep = .welcome
    @Published var isAnimating = false

    // Form data - Feeling & Sleep
    @Published var selectedFeeling: Feeling?
    @Published var feelingNote: String = ""
    @Published var sleepQuality: Int = 7

    // Form data - Intentions
    @Published var intentions: [PlanIntention] = [
        PlanIntention(text: "", area: .health),
        PlanIntention(text: "", area: .career),
        PlanIntention(text: "", area: .learning)
    ]

    // Voice planning
    @Published var transcribedText: String = ""
    @Published var isRecording = false
    @Published var originalVoiceInput: String = ""

    // AI Preview
    @Published var proposedTasks: [PlanProposedTask] = []
    @Published var aiSummary: String = ""

    // Feedback
    @Published var feedbackMode: FeedbackMode = .voice
    @Published var feedbackText: String = ""

    // State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var addedTaskCount = 0

    // MARK: - Computed Properties
    var progress: Double {
        // If user has existing intentions, we skip steps 3-5
        // So total steps: welcome(0), feeling(1), sleep(2), voicePlanning(6) -> mapped to 0,1,2,3
        if hasExistingIntentions {
            switch currentStep {
            case .welcome: return 0.0
            case .feeling: return 0.33
            case .sleep: return 0.66
            case .voicePlanning, .processing, .preview, .feedback, .confirmed: return 1.0
            default: return 1.0
            }
        }

        // Normal flow: Steps 0-6 have progress
        if currentStep.rawValue <= 6 {
            return Double(currentStep.rawValue) / 6.0
        }
        return 1.0
    }

    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .feeling:
            return selectedFeeling != nil
        case .sleep:
            return true
        case .intention1:
            return !intentions[0].text.trimmingCharacters(in: .whitespaces).isEmpty
        case .intention2:
            return !intentions[1].text.trimmingCharacters(in: .whitespaces).isEmpty
        case .intention3:
            return !intentions[2].text.trimmingCharacters(in: .whitespaces).isEmpty
        default:
            return true
        }
    }

    var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "plan_day.greeting_morning".localized
        } else if hour < 17 {
            return "plan_day.greeting_afternoon".localized
        } else {
            return "plan_day.greeting_evening".localized
        }
    }

    var sleepEmoji: String {
        switch sleepQuality {
        case 1...3: return "😴"
        case 4...5: return "😐"
        case 6...7: return "🙂"
        case 8...9: return "😊"
        case 10: return "🌟"
        default: return "😴"
        }
    }

    var sleepColor: Color {
        switch sleepQuality {
        case 1...3: return ColorTokens.error
        case 4...5: return ColorTokens.warning
        case 6...7: return ColorTokens.textSecondary
        case 8...10: return ColorTokens.success
        default: return ColorTokens.textSecondary
        }
    }

    var sleepDescription: String {
        switch sleepQuality {
        case 1...2: return "plan_day.sleep_1".localized
        case 3...4: return "plan_day.sleep_3".localized
        case 5...6: return "plan_day.sleep_5".localized
        case 7...8: return "plan_day.sleep_7".localized
        case 9...10: return "plan_day.sleep_10".localized
        default: return ""
        }
    }

    // MARK: - Init
    init() {
        setupSpeechRecognizer()
        requestPermissions()
    }

    func setStore(_ store: FocusAppStore) {
        self.store = store

        // If user already has intentions for today, pre-fill them
        if let existingCheckIn = store.morningCheckIn {
            selectedFeeling = existingCheckIn.feeling
            sleepQuality = existingCheckIn.sleepQuality

            // Pre-fill intentions from existing check-in
            let existingIntentions = existingCheckIn.intentions
            if !existingIntentions.isEmpty {
                for (index, intention) in existingIntentions.prefix(3).enumerated() {
                    intentions[index].text = intention.intention
                    intentions[index].area = intention.area
                }
            }
        }
    }

    /// Check if user has already set intentions today
    var hasExistingIntentions: Bool {
        guard let store = store,
              let checkIn = store.morningCheckIn else {
            return false
        }
        return !checkIn.intentions.isEmpty
    }

    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    // MARK: - Navigation
    func nextStep() {
        guard canProceed else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                var nextRawValue = self.currentStep.rawValue + 1

                // Skip intention steps (3, 4, 5) if user already has intentions
                if self.hasExistingIntentions {
                    // If we're on sleep step (2), jump directly to voicePlanning (6)
                    if self.currentStep == .sleep {
                        nextRawValue = PlanYourDayStep.voicePlanning.rawValue
                    }
                    // If somehow on intention steps, skip to voice planning
                    else if self.currentStep == .intention1 || self.currentStep == .intention2 || self.currentStep == .intention3 {
                        nextRawValue = PlanYourDayStep.voicePlanning.rawValue
                    }
                }

                if let nextIndex = PlanYourDayStep(rawValue: nextRawValue) {
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
                var prevRawValue = self.currentStep.rawValue - 1

                // Skip intention steps going back if user has existing intentions
                if self.hasExistingIntentions {
                    // If we're on voicePlanning (6), go back to sleep (2)
                    if self.currentStep == .voicePlanning {
                        prevRawValue = PlanYourDayStep.sleep.rawValue
                    }
                }

                if let prevIndex = PlanYourDayStep(rawValue: prevRawValue) {
                    self.currentStep = prevIndex
                }
                self.isAnimating = false
            }
        }
    }

    func goToFeedback() {
        currentStep = .feedback
        feedbackText = ""
    }

    func backToPreview() {
        currentStep = .preview
    }

    func resetToVoicePlanning() {
        proposedTasks = []
        transcribedText = ""
        originalVoiceInput = ""
        aiSummary = ""
        errorMessage = nil
        currentStep = .voicePlanning
    }

    /// Skip voice planning and just save intentions (no task creation)
    func skipVoicePlanningAndSaveIntentions() async {
        isLoading = true
        errorMessage = nil

        do {
            // Save intentions only (no tasks)
            let moodRating = feelingToMoodRating(selectedFeeling ?? .neutral)
            let moodEmoji = selectedFeeling?.rawValue ?? "😐"
            let sleepRating = (sleepQuality + 1) / 2
            let sleepEmojiStr = sleepEmoji

            let intentionInputs = intentions.compactMap { intention -> IntentionInput? in
                guard !intention.text.isEmpty else { return nil }
                return IntentionInput(
                    areaId: nil,
                    content: "\(intention.area.emoji) \(intention.text)"
                )
            }

            _ = try await intentionsService.saveIntentions(
                date: Date(),
                moodRating: moodRating,
                moodEmoji: moodEmoji,
                sleepRating: sleepRating,
                sleepEmoji: sleepEmojiStr,
                intentions: intentionInputs
            )

            // Update store with intentions (no tasks)
            if let store = store {
                let dailyIntentions = intentions.compactMap { intention -> DailyIntention? in
                    guard !intention.text.isEmpty else { return nil }
                    return DailyIntention(
                        id: UUID().uuidString,
                        userId: store.authUserId ?? "",
                        date: Date(),
                        intention: intention.text,
                        area: intention.area,
                        isCompleted: false
                    )
                }

                store.morningCheckIn = MorningCheckIn(
                    id: UUID().uuidString,
                    userId: store.authUserId ?? "",
                    date: Date(),
                    feeling: selectedFeeling ?? .neutral,
                    feelingNote: feelingNote.isEmpty ? nil : feelingNote,
                    sleepQuality: sleepQuality,
                    sleepNote: nil,
                    intentions: dailyIntentions
                )
            }

            addedTaskCount = 0 // No tasks were added
            currentStep = .confirmed

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Voice Recording (Main Planning)
    func startListening() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        guard audioSession.recordPermission == .granted else {
            audioSession.requestRecordPermission { granted in
                if granted {
                    Task { @MainActor in
                        self.startListening()
                    }
                }
            }
            return
        }

        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set audio session: \(error)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("Invalid audio format")
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString

                    // Reset silence timer
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            self?.stopAndProcess()
                        }
                    }
                }

                if error != nil {
                    self.stopAndProcess()
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
            transcribedText = ""
        } catch {
            print("Audio engine failed to start: \(error)")
            inputNode.removeTap(onBus: 0)
        }
    }

    func stopAndProcess() {
        guard isRecording else { return }

        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !text.isEmpty {
            originalVoiceInput = text
            processWithAI(text, feedback: nil)
        } else {
            // No text - stay on voice planning
            currentStep = .voicePlanning
        }
    }

    // MARK: - Feedback Recording
    func startFeedbackRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else { return }

        let audioSession = AVAudioSession.sharedInstance()
        guard audioSession.recordPermission == .granted else { return }

        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else { return }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let result = result {
                    self.feedbackText = result.bestTranscription.formattedString
                }
                if error != nil {
                    self.stopFeedbackRecording()
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
            feedbackText = ""
        } catch {
            inputNode.removeTap(onBus: 0)
        }
    }

    func stopFeedbackRecording() {
        guard isRecording else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        // After stopping, apply the feedback
        if !feedbackText.isEmpty {
            Task {
                await applyFeedback()
            }
        }
    }

    // MARK: - AI Processing
    private func processWithAI(_ text: String, feedback: String?) {
        currentStep = .processing
        isLoading = true  // Enable spinner animation
        errorMessage = nil

        Task {
            defer { isLoading = false }  // Always reset on completion
            do {
                // Build context with intentions
                var context = "Mes intentions pour aujourd'hui:\n"
                for (index, intention) in intentions.enumerated() {
                    if !intention.text.isEmpty {
                        context += "\(index + 1). \(intention.area.emoji) \(intention.text)\n"
                    }
                }
                context += "\nPlanification de ma journee:\n\(text)"

                if let feedback = feedback {
                    context += "\n\nAjustements demandes:\n\(feedback)"
                }

                let response = try await voiceService.analyzeVoice(
                    text: context,
                    date: DateFormatter.yyyyMMdd.string(from: Date())
                )

                if !response.proposedGoals.isEmpty {
                    proposedTasks = response.proposedGoals.map { goal in
                        PlanProposedTask(
                            title: goal.title,
                            scheduledStart: goal.scheduledStart,
                            scheduledEnd: goal.scheduledEnd,
                            timeBlock: goal.timeBlock,
                            priority: goal.priority,
                            date: goal.date,
                            isSelected: true
                        )
                    }
                    aiSummary = response.summary
                    currentStep = .preview
                } else {
                    errorMessage = "plan_day.no_tasks_error".localized
                    currentStep = .voicePlanning
                }
            } catch {
                print("AI processing error: \(error)")
                errorMessage = "plan_day.connection_error".localized
                currentStep = .voicePlanning
            }
        }
    }

    // MARK: - Apply Feedback
    func applyFeedback() async {
        guard !feedbackText.isEmpty else { return }

        // Rebuild context with original input + feedback
        let combinedText = originalVoiceInput
        processWithAI(combinedText, feedback: feedbackText)
    }

    // MARK: - Confirm and Save All
    func confirmAndSaveAll() async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. Save intentions first
            let moodRating = feelingToMoodRating(selectedFeeling ?? .neutral)
            let moodEmoji = selectedFeeling?.rawValue ?? "😐"
            let sleepRating = (sleepQuality + 1) / 2
            let sleepEmojiStr = sleepEmoji

            let intentionInputs = intentions.compactMap { intention -> IntentionInput? in
                guard !intention.text.isEmpty else { return nil }
                return IntentionInput(
                    areaId: nil,
                    content: "\(intention.area.emoji) \(intention.text)"
                )
            }

            _ = try await intentionsService.saveIntentions(
                date: Date(),
                moodRating: moodRating,
                moodEmoji: moodEmoji,
                sleepRating: sleepRating,
                sleepEmoji: sleepEmojiStr,
                intentions: intentionInputs
            )

            // 2. Create selected tasks
            let selectedTasks = proposedTasks.filter { $0.isSelected }
            var addedCount = 0

            for task in selectedTasks {
                do {
                    _ = try await calendarService.createTask(
                        questId: nil,
                        areaId: nil,
                        title: task.title,
                        description: nil,
                        date: task.date,
                        scheduledStart: task.scheduledStart,
                        scheduledEnd: task.scheduledEnd,
                        timeBlock: task.timeBlock,
                        estimatedMinutes: estimateDuration(start: task.scheduledStart, end: task.scheduledEnd),
                        priority: task.priority
                    )
                    addedCount += 1
                } catch {
                    print("Failed to create task: \(task.title) - \(error)")
                }
            }

            addedTaskCount = addedCount

            // 3. Update store
            if let store = store {
                let dailyIntentions = intentions.compactMap { intention -> DailyIntention? in
                    guard !intention.text.isEmpty else { return nil }
                    return DailyIntention(
                        id: UUID().uuidString,
                        userId: store.authUserId ?? "",
                        date: Date(),
                        intention: intention.text,
                        area: intention.area,
                        isCompleted: false
                    )
                }

                store.morningCheckIn = MorningCheckIn(
                    id: UUID().uuidString,
                    userId: store.authUserId ?? "",
                    date: Date(),
                    feeling: selectedFeeling ?? .neutral,
                    feelingNote: feelingNote.isEmpty ? nil : feelingNote,
                    sleepQuality: sleepQuality,
                    sleepNote: nil,
                    intentions: dailyIntentions
                )

                await store.refreshTodaysTasks()
            }

            currentStep = .confirmed
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func feelingToMoodRating(_ feeling: Feeling) -> Int {
        switch feeling {
        case .happy, .excited: return 5
        case .calm: return 4
        case .neutral: return 3
        case .tired, .anxious: return 2
        case .sad, .frustrated: return 1
        }
    }

    private func estimateDuration(start: String?, end: String?) -> Int {
        guard let start = start, let end = end else { return 60 }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let startDate = formatter.date(from: start),
              let endDate = formatter.date(from: end) else { return 60 }

        let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
        return max(15, minutes)
    }

    // MARK: - Cleanup
    func cleanup() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        if isRecording {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
    }
}
