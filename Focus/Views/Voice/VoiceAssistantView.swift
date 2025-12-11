import SwiftUI
import AVFoundation
import Speech
import Combine

// MARK: - Conversation Step
enum ConversationStep: Int {
    case greeting = 0
    case waitingResponse1 = 1
    case askIntentions = 2
    case waitingResponse2 = 3
    case askObjectives = 4
    case waitingResponse3 = 5
    case summary = 6
    case done = 7
}

// MARK: - Voice Assistant View (Perplexity Style - Full Auto Voice)
struct VoiceAssistantView: View {
    @StateObject private var viewModel = VoiceAssistantViewModel()
    @EnvironmentObject var store: FocusAppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient
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
                // Header - only close button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(ColorTokens.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Central orb
                orbView

                // Current text display
                if let text = viewModel.currentDisplayText {
                    Text(text)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(ColorTokens.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 40)
                        .animation(.easeInOut, value: text)
                }

                Spacer()

                // Transcription text (what user is saying)
                VStack(spacing: 16) {
                    if viewModel.isRecording && !viewModel.transcribedText.isEmpty {
                        Text(viewModel.transcribedText)
                            .font(.system(size: 16))
                            .foregroundColor(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .lineLimit(3)
                            .transition(.opacity)
                    }

                    // Status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(statusText)
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            let userName = store.user?.name ?? store.user?.pseudo ?? ""
            viewModel.startConversation(userName: userName)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    private var statusColor: Color {
        if viewModel.isPlayingAudio {
            return ColorTokens.primaryStart
        } else if viewModel.isRecording {
            return .red
        } else if viewModel.isProcessing {
            return .yellow
        } else {
            return ColorTokens.textMuted
        }
    }

    private var statusText: String {
        if viewModel.isPlayingAudio {
            return "Volta parle..."
        } else if viewModel.isRecording {
            return "Je t'écoute..."
        } else if viewModel.isProcessing {
            return "Je réfléchis..."
        } else if viewModel.currentStep == .done {
            return "Bonne journée !"
        } else {
            return ""
        }
    }

    // MARK: - Orb View
    private var orbView: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ColorTokens.primaryStart.opacity(viewModel.isPlayingAudio ? 0.4 : 0.2),
                            ColorTokens.primaryStart.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .scaleEffect(viewModel.isPlayingAudio ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isPlayingAudio)

            // Particle sphere
            ParticleSphereView(
                isAnimating: viewModel.isPlayingAudio || viewModel.isRecording,
                intensity: viewModel.isRecording ? 1.5 : 1.0
            )
            .frame(width: 200, height: 200)

            // Recording indicator
            if viewModel.isRecording {
                Circle()
                    .stroke(Color.red.opacity(0.6), lineWidth: 3)
                    .frame(width: 220, height: 220)
                    .scaleEffect(1.05)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isRecording)
            }
        }
    }
}

// MARK: - Particle Sphere View
struct ParticleSphereView: View {
    let isAnimating: Bool
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 10
                let time = timeline.date.timeIntervalSinceReferenceDate

                let particleCount = 600
                for i in 0..<particleCount {
                    let phi = Double(i) / Double(particleCount) * .pi * 2
                    let theta = acos(2.0 * Double(i) / Double(particleCount) - 1)

                    let speed = isAnimating ? 0.5 * intensity : 0.08
                    let animatedPhi = phi + time * speed

                    let x = radius * sin(theta) * cos(animatedPhi)
                    let y = radius * sin(theta) * sin(animatedPhi)
                    let z = radius * cos(theta)

                    let scale = (z + radius * 1.5) / (radius * 2.5)
                    let projectedX = center.x + x * scale
                    let projectedY = center.y + y * scale * 0.85

                    let particleSize = max(1.2, 2.5 * scale)
                    let opacity = 0.4 + 0.6 * scale

                    let rect = CGRect(
                        x: projectedX - particleSize / 2,
                        y: projectedY - particleSize / 2,
                        width: particleSize,
                        height: particleSize
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(ColorTokens.primaryStart.opacity(opacity))
                    )
                }
            }
        }
    }
}

// MARK: - Voice Assistant ViewModel
@MainActor
class VoiceAssistantViewModel: ObservableObject {
    private let voiceService = VoiceService()
    private var audioPlayer: AVAudioPlayer?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var audioDelegate: AudioPlayerDelegateHandler?
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date?

    @Published var currentDisplayText: String?
    @Published var transcribedText: String = ""
    @Published var isProcessing = false
    @Published var isRecording = false
    @Published var isPlayingAudio = false
    @Published var currentStep: ConversationStep = .greeting
    @Published var createdTasks: [CalendarTask] = []

    private var userName: String = ""
    private var collectedResponses: [String] = []

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

    // MARK: - Start Conversation
    func startConversation(userName: String) {
        self.userName = userName.isEmpty ? "" : userName.components(separatedBy: " ").first ?? userName

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await sendGreeting()
        }
    }

    private func sendGreeting() async {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting = hour < 12 ? "Bonjour" : (hour < 18 ? "Bon après-midi" : "Bonsoir")

        let greeting: String
        if userName.isEmpty {
            greeting = "\(timeGreeting) ! Es-tu prêt à commencer ta journée ?"
        } else {
            greeting = "\(timeGreeting) \(userName) ! Es-tu prêt à commencer ta journée ?"
        }

        currentDisplayText = greeting
        currentStep = .waitingResponse1

        await speakText(greeting)

        // Auto-start listening after speaking
        startListeningAuto()
    }

    // MARK: - Process User Response
    private func processUserResponse(_ text: String) async {
        collectedResponses.append(text)
        transcribedText = ""

        switch currentStep {
        case .waitingResponse1:
            currentStep = .askIntentions
            let response = "Super ! Quelles sont tes 3 intentions importantes pour aujourd'hui ?"
            currentDisplayText = response
            await speakText(response)
            currentStep = .waitingResponse2
            startListeningAuto()

        case .waitingResponse2:
            currentStep = .askObjectives
            let response = "Excellentes intentions ! Maintenant, quels sont tes objectifs concrets ? Donne-moi des horaires si possible."
            currentDisplayText = response
            await speakText(response)
            currentStep = .waitingResponse3
            startListeningAuto()

        case .waitingResponse3:
            currentStep = .summary
            isProcessing = true
            currentDisplayText = "Je prépare ta journée..."

            do {
                let response = try await voiceService.voiceAssistant(
                    text: text,
                    date: DateFormatter.yyyyMMdd.string(from: Date()),
                    voiceId: "b35yykvVppLXyw_l",
                    audioFormat: "wav"
                )

                if response.intentType == "ADD_GOAL" {
                    createdTasks = response.tasks ?? []
                }

                let taskCount = response.tasks?.count ?? 0
                let summaryText: String
                if taskCount > 0 {
                    summaryText = "Parfait ! J'ai ajouté \(taskCount) objectif\(taskCount > 1 ? "s" : "") à ta journée. Tu es prêt à conquérir cette journée ! Bonne chance !"
                } else {
                    summaryText = "C'est noté ! Passe une excellente journée productive !"
                }

                currentDisplayText = summaryText
                await speakText(summaryText)

            } catch {
                let errorText = "J'ai bien compris. Passe une excellente journée !"
                currentDisplayText = errorText
                await speakText(errorText)
            }

            currentStep = .done
            isProcessing = false

        default:
            break
        }
    }

    // MARK: - TTS
    private func speakText(_ text: String) async {
        do {
            let response = try await voiceService.voiceAssistant(
                text: "TTS_ONLY:\(text)",
                date: DateFormatter.yyyyMMdd.string(from: Date()),
                voiceId: "b35yykvVppLXyw_l",
                audioFormat: "wav"
            )

            if let audioData = response.audioData {
                await playAudioAndWait(data: audioData)
            }
        } catch {
            print("TTS failed: \(error)")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func playAudioAndWait(data: Data) async {
        await withCheckedContinuation { continuation in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)

                audioPlayer = try AVAudioPlayer(data: data)
                audioDelegate = AudioPlayerDelegateHandler {
                    self.isPlayingAudio = false
                    continuation.resume()
                }
                audioPlayer?.delegate = audioDelegate
                audioPlayer?.prepareToPlay()
                isPlayingAudio = true
                audioPlayer?.play()

            } catch {
                print("Failed to play audio: \(error)")
                isPlayingAudio = false
                continuation.resume()
            }
        }
    }

    // MARK: - Auto Listening
    private func startListeningAuto() {
        guard currentStep != .done else { return }

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.startRecording()
            }
        }
    }

    private func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }

        // Check microphone permission first
        let audioSession = AVAudioSession.sharedInstance()
        guard audioSession.recordPermission == .granted else {
            print("Microphone permission not granted")
            // Request permission
            audioSession.requestRecordPermission { granted in
                if granted {
                    Task { @MainActor in
                        self.startRecording()
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

        // Check if format is valid
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("Invalid audio format: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount)")
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.lastSpeechTime = Date()

                    // Reset silence timer
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            self?.finishRecordingAndProcess()
                        }
                    }
                }

                if error != nil {
                    self.finishRecordingAndProcess()
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
            lastSpeechTime = Date()

            // Timeout after 10 seconds of no speech
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.finishRecordingAndProcess()
                }
            }
        } catch {
            print("Audio engine failed to start: \(error)")
            // Clean up tap if engine fails
            inputNode.removeTap(onBus: 0)
        }
    }

    private func finishRecordingAndProcess() {
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

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !text.isEmpty {
            Task {
                await processUserResponse(text)
            }
        } else {
            // If no speech detected, prompt again
            Task {
                let prompt = "Je n'ai pas entendu. Peux-tu répéter ?"
                currentDisplayText = prompt
                await speakText(prompt)
                startListeningAuto()
            }
        }
    }

    func cleanup() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioPlayer?.stop()
        audioEngine.stop()
        if isRecording {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
        isPlayingAudio = false
    }
}

// MARK: - Audio Player Delegate Handler
class AudioPlayerDelegateHandler: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinish()
        }
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Preview
#Preview {
    VoiceAssistantView()
        .environmentObject(FocusAppStore.shared)
}
