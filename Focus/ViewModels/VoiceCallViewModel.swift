import Foundation
import SwiftUI
import AVFoundation
import Speech
import Combine

// MARK: - Voice Call State Machine

enum VoiceCallState: Equatable {
    case connecting
    case listening
    case processing
    case speaking
    case ended
}

// MARK: - TTS Models

struct ChatTTSRequest: Encodable {
    let text: String
    let voiceID: String

    enum CodingKeys: String, CodingKey {
        case text
        case voiceID = "voice_id"
    }
}

struct ChatTTSResponse: Decodable {
    let audioBase64: String

    enum CodingKeys: String, CodingKey {
        case audioBase64 = "audio_base64"
    }

    var audioData: Data? {
        Data(base64Encoded: audioBase64)
    }
}

// MARK: - ViewModel

@MainActor
class VoiceCallViewModel: ObservableObject {

    // MARK: - Published State

    @Published var callState: VoiceCallState = .connecting
    @Published var transcribedText: String = ""
    @Published var lastAIResponse: String = ""
    @Published var callDuration: TimeInterval = 0
    @Published var isPlayingAudio = false
    @Published var isRecording = false

    // MARK: - Private

    private let apiClient = APIClient.shared
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var absoluteTimer: Timer?
    private var callTimer: Timer?
    private var maxDurationTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var audioDelegate: VoiceCallAudioDelegate?
    private var isCancelled = false

    private let maxCallDuration: TimeInterval = 15 * 60 // 15 minutes
    private let warningDuration: TimeInterval = 12 * 60 // 12 minutes
    private var hasShownWarning = false

    private weak var store: FocusAppStore?

    // MARK: - Init

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
        store = FocusAppStore.shared
    }

    // MARK: - Call Lifecycle

    func startCall() {
        isCancelled = false
        callState = .connecting

        // Request permissions
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self, granted else { return }
                self.startCallTimer()
                self.startMaxDurationTimer()
                await self.sendGreeting()
            }
        }
    }

    func endCall() {
        isCancelled = true
        stopRecording()
        audioPlayer?.stop()
        callTimer?.invalidate()
        callTimer = nil
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        absoluteTimer?.invalidate()
        absoluteTimer = nil
        isPlayingAudio = false
        isRecording = false
        callState = .ended
    }

    // MARK: - Call Timer

    private func startCallTimer() {
        callDuration = 0
        callTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.callDuration += 1
            }
        }
    }

    private func startMaxDurationTimer() {
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: maxCallDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.endCall()
            }
        }
    }

    // MARK: - Conversation Loop

    private func sendGreeting() async {
        guard !isCancelled else { return }
        callState = .processing

        do {
            let isBlocking = ScreenTimeAppBlockerService.shared.isBlocking
            let response: AIResponse = try await apiClient.request(
                endpoint: .chatMessage,
                method: .post,
                body: SimpleChatRequest(content: "__greeting__", source: "voice_call", appsBlocked: isBlocking)
            )

            guard !isCancelled else { return }
            lastAIResponse = response.reply

            if let action = response.action {
                await handleCoachAction(action)
            }

            await speakAndListen(response.reply)
        } catch {
            guard !isCancelled else { return }
            lastAIResponse = "Salut ! Comment ça va ?"
            await speakAndListen(lastAIResponse)
        }
    }

    private func processUserMessage(_ text: String) async {
        guard !isCancelled else { return }
        callState = .processing
        transcribedText = text

        do {
            let isBlocking = ScreenTimeAppBlockerService.shared.isBlocking
            let response: AIResponse = try await apiClient.request(
                endpoint: .chatMessage,
                method: .post,
                body: SimpleChatRequest(content: text, source: "voice_call", appsBlocked: isBlocking)
            )

            guard !isCancelled else { return }
            lastAIResponse = response.reply

            if let action = response.action {
                await handleCoachAction(action)
            }

            await speakAndListen(response.reply)
        } catch {
            guard !isCancelled else { return }
            lastAIResponse = "Désolé, j'ai pas bien compris. Tu peux répéter ?"
            await speakAndListen(lastAIResponse)
        }
    }

    private func speakAndListen(_ text: String) async {
        guard !isCancelled else { return }
        callState = .speaking

        // Get TTS audio
        do {
            let response: ChatTTSResponse = try await apiClient.request(
                endpoint: .chatTTS,
                method: .post,
                body: ChatTTSRequest(text: text, voiceID: "b35yykvVppLXyw_l")
            )

            guard !isCancelled else { return }

            if let audioData = response.audioData {
                await playAudioAndWait(data: audioData)
            }
        } catch {
            // If TTS fails, just wait a beat and continue to listening
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        guard !isCancelled else { return }

        // Check for duration warning
        if !hasShownWarning && callDuration >= warningDuration {
            hasShownWarning = true
            // Will naturally end at maxCallDuration
        }

        startListening()
    }

    // MARK: - Speech Recognition (STT)

    private func startListening() {
        guard !isCancelled else { return }
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
                guard let self, !self.isCancelled else { return }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString

                    // Reset silence timer on each partial result
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

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
            callState = .listening
            transcribedText = ""

            // Absolute timeout: 30s of no meaningful speech
            absoluteTimer?.invalidate()
            absoluteTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSilenceTimeout()
                }
            }
        } catch {
            inputNode.removeTap(onBus: 0)
        }
    }

    private func finishRecordingAndProcess() {
        guard isRecording else { return }

        silenceTimer?.invalidate()
        silenceTimer = nil
        absoluteTimer?.invalidate()
        absoluteTimer = nil

        stopRecording()

        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !text.isEmpty {
            Task {
                await processUserMessage(text)
            }
        } else {
            handleSilenceTimeout()
        }
    }

    private func handleSilenceTimeout() {
        guard !isCancelled else { return }
        stopRecording()

        Task {
            lastAIResponse = "Je n'ai pas entendu, tu peux répéter ?"
            await speakAndListen(lastAIResponse)
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        if isRecording {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Audio Playback

    private func playAudioAndWait(data: Data) async {
        await withCheckedContinuation { continuation in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)

                audioPlayer = try AVAudioPlayer(data: data)
                audioDelegate = VoiceCallAudioDelegate { [weak self] in
                    self?.isPlayingAudio = false
                    continuation.resume()
                }
                audioPlayer?.delegate = audioDelegate
                audioPlayer?.prepareToPlay()
                isPlayingAudio = true
                audioPlayer?.play()
            } catch {
                isPlayingAudio = false
                continuation.resume()
            }
        }
    }

    // MARK: - Coach Actions (same as ChatViewModel)

    private func handleCoachAction(_ action: AIActionData) async {
        switch action.type {
        case "task_created":
            NotificationCenter.default.post(name: .calendarNeedsRefresh, object: nil)
        case "quest_created", "quests_created":
            await store?.loadQuests()
        case "routine_created", "routines_created":
            await store?.loadRituals()
        case "quest_updated":
            await store?.loadQuests()
        case "block_apps":
            let blocker = ScreenTimeAppBlockerService.shared
            if blocker.isBlockingEnabled {
                blocker.startBlocking()
            }
        case "unblock_apps":
            let blocker = ScreenTimeAppBlockerService.shared
            if blocker.isBlocking {
                blocker.stopBlocking()
            }
        case "task_completed":
            NotificationCenter.default.post(name: .calendarNeedsRefresh, object: nil)
        case "routines_completed":
            await store?.loadRituals()
        case "quest_deleted":
            await store?.loadQuests()
        case "routine_deleted":
            await store?.loadRituals()
        case "weekly_goals_created", "weekly_goal_completed":
            await store?.loadWeeklyGoals()
        default:
            break
        }
    }
}

// MARK: - Audio Player Delegate

class VoiceCallAudioDelegate: NSObject, AVAudioPlayerDelegate {
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
