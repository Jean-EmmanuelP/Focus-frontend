import SwiftUI
import AVFoundation
import Speech
import Combine

// MARK: - Voice Start Day Step
enum VoiceStartDayStep: Int {
    case listening = 0     // User speaks their day plan
    case processing = 1    // AI is processing
    case preview = 2       // Show preview of tasks to add
    case confirmed = 3     // Tasks added to calendar
}

// MARK: - Proposed Task (from AI) - Local UI model
struct ProposedTaskUI: Identifiable {
    let id = UUID()
    var title: String
    var scheduledStart: String?
    var scheduledEnd: String?
    var timeBlock: String
    var priority: String
    var date: String
    var isSelected: Bool = true
}

// MARK: - Voice Start Day View
struct StartTheDayVoiceView: View {
    @StateObject private var viewModel = StartTheDayVoiceViewModel()
    @EnvironmentObject var store: FocusAppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(hex: "1a1a1a"),
                    Color(hex: "2d1f1a"),
                    Color(hex: "1a1a1a")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Content based on step
                switch viewModel.currentStep {
                case .listening:
                    listeningView
                case .processing:
                    processingView
                case .preview:
                    previewView
                case .confirmed:
                    confirmedView
                }
            }
        }
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.satoshi(18, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            Text(stepTitle)
                .font(.satoshi(16, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)

            Spacer()

            // Placeholder for symmetry
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var stepTitle: String {
        switch viewModel.currentStep {
        case .listening: return "Dis-moi ta journee"
        case .processing: return "Analyse en cours..."
        case .preview: return "Valide ton planning"
        case .confirmed: return "C'est parti !"
        }
    }

    // MARK: - Listening View
    private var listeningView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Orb animation
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ColorTokens.primaryStart.opacity(viewModel.isRecording ? 0.4 : 0.2),
                                ColorTokens.primaryStart.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isRecording)

                // Inner circle
                Circle()
                    .fill(ColorTokens.primaryStart.opacity(0.3))
                    .frame(width: 160, height: 160)

                // Recording indicator
                if viewModel.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.6), lineWidth: 3)
                        .frame(width: 180, height: 180)
                        .scaleEffect(1.05)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isRecording)

                    // Mic icon
                    Image(systemName: "mic.fill")
                        .font(.satoshi(48))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "mic")
                        .font(.satoshi(48))
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }

            // Instructions
            VStack(spacing: 12) {
                Text("Parle-moi de ta journee")
                    .font(.satoshi(24, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Dis-moi ce que tu veux faire aujourd'hui avec les horaires")
                    .font(.satoshi(16))
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Transcription
            if !viewModel.transcribedText.isEmpty {
                Text(viewModel.transcribedText)
                    .font(.satoshi(16))
                    .foregroundColor(ColorTokens.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(4)
                    .padding(.top, 16)
            }

            Spacer()

            // Control buttons
            HStack(spacing: 24) {
                if viewModel.isRecording {
                    Button(action: { viewModel.stopAndProcess() }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Valider")
                        }
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(ColorTokens.fireGradient)
                        .cornerRadius(12)
                    }
                } else {
                    Button(action: { viewModel.startListening() }) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Recommencer")
                        }
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(ColorTokens.surface)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Loading animation
            ZStack {
                Circle()
                    .fill(ColorTokens.primaryStart.opacity(0.2))
                    .frame(width: 160, height: 160)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                    .scaleEffect(2)
            }

            VStack(spacing: 12) {
                Text("Volta analyse ta journee...")
                    .font(.satoshi(24, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Je prepare ton planning")
                    .font(.satoshi(16))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Preview View
    private var previewView: some View {
        VStack(spacing: 16) {
            // Summary from AI
            VStack(spacing: 8) {
                Text("Voici ce que j'ai compris")
                    .font(.satoshi(20, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                if !viewModel.aiSummary.isEmpty {
                    Text(viewModel.aiSummary)
                        .font(.satoshi(14))
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 24)

            // Task list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($viewModel.proposedTasks) { $task in
                        ProposedTaskUIRow(task: $task)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.satoshi(14))
                    .foregroundColor(ColorTokens.error)
                    .padding(.horizontal, 16)
            }

            // Action buttons
            VStack(spacing: 12) {
                // Confirm button
                Button(action: {
                    Task {
                        await viewModel.confirmAndAddTasks()
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Ajouter au calendrier")
                    }
                    .font(.satoshi(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ColorTokens.fireGradient)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isAddingTasks)

                // Redo button
                Button(action: {
                    viewModel.resetToListening()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Recommencer")
                    }
                    .font(.satoshi(16, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Confirmed View
    private var confirmedView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.2))
                    .frame(width: 160, height: 160)

                Image(systemName: "checkmark.circle.fill")
                    .font(.satoshi(80))
                    .foregroundColor(ColorTokens.success)
            }

            VStack(spacing: 12) {
                Text("C'est parti !")
                    .font(.satoshi(28, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("\(viewModel.addedTaskCount) tache\(viewModel.addedTaskCount > 1 ? "s" : "") ajoutee\(viewModel.addedTaskCount > 1 ? "s" : "") a ton calendrier")
                    .font(.satoshi(16))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()

            // Done button
            Button(action: { dismiss() }) {
                Text("Voir mon calendrier")
                    .font(.satoshi(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ColorTokens.fireGradient)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Proposed Task UI Row
struct ProposedTaskUIRow: View {
    @Binding var task: ProposedTaskUI

    var body: some View {
        HStack(spacing: 12) {
            // Selection toggle
            Button(action: { task.isSelected.toggle() }) {
                Image(systemName: task.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.satoshi(24))
                    .foregroundColor(task.isSelected ? ColorTokens.primaryStart : ColorTokens.textMuted)
            }

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.satoshi(16, weight: .medium))
                    .foregroundColor(task.isSelected ? ColorTokens.textPrimary : ColorTokens.textMuted)

                HStack(spacing: 8) {
                    if let start = task.scheduledStart, let end = task.scheduledEnd {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.satoshi(12))
                            Text("\(start) - \(end)")
                        }
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Priority badge
                    Text(task.priority.capitalized)
                        .font(.satoshi(11, weight: .medium))
                        .foregroundColor(priorityColor(task.priority))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(priorityColor(task.priority).opacity(0.2))
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(ColorTokens.surface)
        .cornerRadius(12)
        .opacity(task.isSelected ? 1.0 : 0.6)
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return ColorTokens.error
        case "medium": return ColorTokens.warning
        default: return ColorTokens.textMuted
        }
    }
}

// MARK: - ViewModel
@MainActor
class StartTheDayVoiceViewModel: ObservableObject {
    private let voiceService = VoiceService()
    private let calendarService = CalendarService()
    private var store: FocusAppStore { FocusAppStore.shared }

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?

    @Published var currentStep: VoiceStartDayStep = .listening
    @Published var transcribedText: String = ""
    @Published var isRecording = false
    @Published var proposedTasks: [ProposedTaskUI] = []
    @Published var errorMessage: String?
    @Published var isAddingTasks = false
    @Published var addedTaskCount = 0
    @Published var aiSummary: String = ""

    init() {
        setupSpeechRecognizer()
        requestPermissions()
    }

    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    // MARK: - Start Listening
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

                    // Reset silence timer on each new word
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            // Auto-submit after 3 seconds of silence
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
            currentStep = .listening
        } catch {
            print("Audio engine failed to start: \(error)")
            inputNode.removeTap(onBus: 0)
        }
    }

    // MARK: - Stop and Process
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
            processWithAI(text)
        } else {
            // No text - stay on listening
            currentStep = .listening
        }
    }

    // MARK: - Process with AI (using new analyze endpoint - no DB write)
    private func processWithAI(_ text: String) {
        currentStep = .processing
        errorMessage = nil

        Task {
            do {
                // Use the new analyze endpoint that only returns proposals (no DB write)
                let response = try await voiceService.analyzeVoice(
                    text: text,
                    date: DateFormatter.yyyyMMdd.string(from: Date())
                )

                // Convert proposed goals to UI model
                if !response.proposedGoals.isEmpty {
                    proposedTasks = response.proposedGoals.map { goal in
                        ProposedTaskUI(
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
                    errorMessage = "Je n'ai pas compris. Essaie de reformuler."
                    currentStep = .listening
                }
            } catch {
                print("AI processing error: \(error)")
                errorMessage = "Erreur de connexion. Reessaie."
                currentStep = .listening
            }
        }
    }

    // MARK: - Confirm and Add Tasks (creates tasks in DB via CalendarService)
    func confirmAndAddTasks() async {
        isAddingTasks = true
        errorMessage = nil

        let selectedTasks = proposedTasks.filter { $0.isSelected }
        var addedCount = 0

        for task in selectedTasks {
            do {
                // Use the task's date from AI response
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
        isAddingTasks = false

        if addedCount > 0 {
            // Refresh store
            await store.refreshTodaysTasks()
            currentStep = .confirmed
        } else {
            errorMessage = "Impossible d'ajouter les taches. Reessaie."
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

    // MARK: - Reset
    func resetToListening() {
        proposedTasks = []
        transcribedText = ""
        aiSummary = ""
        errorMessage = nil
        currentStep = .listening
        startListening()
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

// MARK: - Preview
#Preview {
    StartTheDayVoiceView()
        .environmentObject(FocusAppStore.shared)
}
