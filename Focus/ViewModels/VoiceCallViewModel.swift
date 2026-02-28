import Foundation
import SwiftUI
import Combine
#if canImport(LiveKit)
import LiveKit
#endif


// MARK: - Voice Call State Machine

enum VoiceCallState: Equatable {
    case connecting
    case listening
    case processing
    case speaking
    case ended
}

// MARK: - ViewModel

@MainActor
class VoiceCallViewModel: ObservableObject {

    // MARK: - Published State

    @Published var callState: VoiceCallState = .connecting
    @Published var transcribedText: String = ""
    @Published var lastAIResponse: String = ""
    @Published var callDuration: TimeInterval = 0
    @Published var isAgentSpeaking = false
    @Published var isMicMuted = false
    @Published var errorMessage: String?

    // MARK: - LiveKit Voice Service

    let voiceService = LiveKitVoiceService()

    // MARK: - Private

    private var callTimer: Timer?
    private var maxDurationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let maxCallDuration: TimeInterval = 15 * 60 // 15 minutes
    private let warningDuration: TimeInterval = 12 * 60 // 12 minutes
    private var hasShownWarning = false

    private weak var store: FocusAppStore?

    // MARK: - Init

    init() {
        store = FocusAppStore.shared
        observeVoiceService()
    }

    // MARK: - Observe LiveKit Voice Service

    private func observeVoiceService() {
        voiceService.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .connected:
                    self.callState = .listening
                case .disconnected:
                    // Only end the call if we were actually in an active state
                    // (avoids premature dismissal during connection setup)
                    if self.callState == .listening || self.callState == .speaking || self.callState == .processing {
                        self.callState = .ended
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)

        voiceService.$userTranscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self, !text.isEmpty else { return }
                self.transcribedText = text
                self.callState = .listening
            }
            .store(in: &cancellables)

        voiceService.$agentTranscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self, !text.isEmpty else { return }
                self.lastAIResponse = text
            }
            .store(in: &cancellables)

        voiceService.$isAgentSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaking in
                guard let self else { return }
                self.isAgentSpeaking = speaking
                if speaking {
                    self.callState = .speaking
                } else if self.callState == .speaking {
                    self.callState = .listening
                }
            }
            .store(in: &cancellables)

        // Coach actions from agent via data channel
        NotificationCenter.default.publisher(for: .liveKitCoachAction)
            .compactMap { $0.userInfo?["data"] as? Data }
            .sink { [weak self] data in
                Task { @MainActor in
                    self?.handleCoachActionData(data)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Mic Control

    func toggleMic() {
        Task {
            let newState = voiceService.isMicEnabled
            try? await voiceService.setMicEnabled(!newState)
            isMicMuted = !voiceService.isMicEnabled
        }
    }

    // MARK: - Call Lifecycle

    func startCall() {
        callState = .connecting
        startCallTimer()
        startMaxDurationTimer()

        Task {
            do {
                try await voiceService.connect(mode: "voice_call")
            } catch {
                print("❌ Voice call error: \(error)")
                errorMessage = "Impossible de se connecter. Réessaie plus tard."
                callState = .ended
            }
        }
    }

    func endCall() {
        callTimer?.invalidate()
        callTimer = nil
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        callState = .ended

        Task {
            await voiceService.disconnect()
        }
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

    // MARK: - Coach Actions (received via LiveKit data channel)

    private func handleCoachActionData(_ data: Data) {
        // Try parsing as BackboardSideEffect-compatible format
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let effectType = json["type"] as? String else { return }

        Task {
            switch effectType {
            case "refresh_tasks", "task_created", "task_completed":
                await store?.refreshTodaysTasks()
                NotificationCenter.default.post(name: .calendarNeedsRefresh, object: nil)
            case "refresh_rituals", "routine_created", "routines_created", "routines_completed", "routine_deleted":
                await store?.loadRituals()
            case "refresh_quests", "quest_created", "quests_created", "quest_updated", "quest_deleted":
                await store?.loadQuests()
            case "refresh_reflection":
                await store?.loadTodayReflection()
            case "refresh_weekly_goals", "weekly_goals_created", "weekly_goal_completed":
                await store?.loadWeeklyGoals()
            case "block_apps":
                let duration = json["duration_minutes"] as? Int
                let blocker = ScreenTimeAppBlockerService.shared
                if blocker.isBlockingEnabled {
                    blocker.startBlocking(durationMinutes: duration)
                } else if blocker.authorizationStatus != .approved {
                    let granted = await blocker.requestAuthorization()
                    if granted && blocker.hasSelectedApps {
                        blocker.startBlocking(durationMinutes: duration)
                    }
                }
            case "unblock_apps":
                let blocker = ScreenTimeAppBlockerService.shared
                if blocker.isBlocking {
                    blocker.stopBlocking()
                }
            default:
                break
            }
        }
    }
}
