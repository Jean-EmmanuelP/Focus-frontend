import Foundation
import SwiftUI
import Combine
import LiveKit
import UIKit

// MARK: - Focus Room State

enum FocusRoomState: Equatable {
    case connecting
    case connected
    case reconnecting
    case ended
    case error(String)

    static func == (lhs: FocusRoomState, rhs: FocusRoomState) -> Bool {
        switch (lhs, rhs) {
        case (.connecting, .connecting),
             (.connected, .connected),
             (.reconnecting, .reconnecting),
             (.ended, .ended):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - ViewModel

@MainActor
class FocusRoomViewModel: ObservableObject {

    // MARK: - Published State

    @Published var roomState: FocusRoomState = .connecting
    @Published var room: FocusRoom?
    @Published var participants: [ParticipantState] = []
    @Published var sessionDuration: TimeInterval = 0
    @Published var isMicMuted: Bool = false
    @Published var isCameraOn: Bool = false
    @Published var localVideoTrack: VideoTrack?
    @Published var isAppBlockingActive: Bool = false
    @Published var currentMilestone: String?

    // MARK: - Services

    let liveKitService = FocusRoomLiveKitService()
    private let roomService = FocusRoomService()

    // MARK: - Private

    let category: FocusRoomCategory
    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var triggeredMilestones: Set<Int> = []
    private static let milestoneSeconds = [5 * 60, 10 * 60, 25 * 60, 30 * 60, 60 * 60]

    // MARK: - Init

    init(category: FocusRoomCategory) {
        self.category = category
        observeLiveKitService()
    }

    // MARK: - Observe LiveKit Service

    private func observeLiveKitService() {
        liveKitService.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .connected:
                    self.roomState = .connected
                case .disconnected:
                    if self.roomState == .connected || self.roomState == .reconnecting {
                        self.roomState = .ended
                    }
                case .reconnecting:
                    self.roomState = .reconnecting
                case .connecting:
                    break
                }
            }
            .store(in: &cancellables)

        liveKitService.$participants
            .receive(on: DispatchQueue.main)
            .assign(to: &$participants)

        liveKitService.$isMicEnabled
            .receive(on: DispatchQueue.main)
            .map { !$0 }
            .assign(to: &$isMicMuted)

        liveKitService.$isCameraEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$isCameraOn)

        liveKitService.$localVideoTrack
            .receive(on: DispatchQueue.main)
            .assign(to: &$localVideoTrack)
    }

    // MARK: - Join Room

    func joinRoom() {
        guard roomState != .connected else { return }
        roomState = .connecting
        print("[FocusRoom] joinRoom() called for category: \(category.rawValue)")

        Task {
            do {
                print("[FocusRoom] Calling API joinRoom...")
                let response = try await roomService.joinRoom(category: category)
                print("[FocusRoom] API success — room: \(response.room.id), token length: \(response.token.count)")
                self.room = response.room
                print("[FocusRoom] Connecting to LiveKit...")
                try await liveKitService.connect(token: response.token, url: response.url)
                print("[FocusRoom] LiveKit connected!")
                startSessionTimer()

                // Start Live Activity for lock screen timer
                LiveActivityManager.shared.startLiveActivity(
                    sessionId: response.room.id,
                    totalDuration: 120, // Focus rooms are open-ended, use 2h as max
                    description: category.displayName,
                    sessionTitle: "Focus Room",
                    sessionEmoji: "🎯"
                )

                // Start app blocking if enabled
                ScreenTimeAppBlockerService.shared.startBlockingIfEnabled()
                isAppBlockingActive = ScreenTimeAppBlockerService.shared.isBlocking
            } catch {
                print("[FocusRoom] ERROR: \(error)")
                roomState = .error("Impossible de rejoindre la room. Reessaie plus tard.")
            }
        }
    }

    // MARK: - Leave Room

    func leaveRoom() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        roomState = .ended

        // End Live Activity
        LiveActivityManager.shared.endLiveActivity(completed: true)

        // Stop app blocking
        if isAppBlockingActive {
            ScreenTimeAppBlockerService.shared.stopBlocking()
            isAppBlockingActive = false
        }

        Task {
            await liveKitService.disconnect()
            if let roomId = room?.id {
                try? await roomService.leaveRoom(roomId: roomId)
            }
        }
    }

    // MARK: - Mic / Camera Toggles

    func toggleMic() {
        Task {
            do {
                let newState = !liveKitService.isMicEnabled
                try await liveKitService.setMicEnabled(newState)
            } catch {
                print("[FocusRoom] Mic toggle failed: \(error)")
            }
        }
    }

    func toggleCamera() {
        Task {
            do {
                let newState = !liveKitService.isCameraEnabled
                try await liveKitService.setCameraEnabled(newState)
            } catch {
                print("[FocusRoom] Camera toggle failed: \(error)")
            }
        }
    }

    // MARK: - App Blocking Toggle

    func toggleAppBlocking() {
        if isAppBlockingActive {
            ScreenTimeAppBlockerService.shared.stopBlocking()
            isAppBlockingActive = false
        } else {
            ScreenTimeAppBlockerService.shared.startBlockingIfEnabled()
            isAppBlockingActive = ScreenTimeAppBlockerService.shared.isBlocking
        }
    }

    // MARK: - Session Timer

    private func startSessionTimer() {
        sessionDuration = 0
        triggeredMilestones = []
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.sessionDuration += 1
                self.checkMilestones()
            }
        }
    }

    // MARK: - Milestones

    private func checkMilestones() {
        let seconds = Int(sessionDuration)
        for milestone in Self.milestoneSeconds {
            if seconds == milestone && !triggeredMilestones.contains(milestone) {
                triggeredMilestones.insert(milestone)
                let minutes = milestone / 60
                let label = minutes >= 60 ? "\(minutes / 60)h" : "\(minutes) min"
                triggerMilestone(label)
            }
        }
    }

    private func triggerMilestone(_ label: String) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            currentMilestone = label
        }

        // Dismiss after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                if self.currentMilestone == label {
                    self.currentMilestone = nil
                }
            }
        }
    }

    // MARK: - Computed

    var participantCount: Int {
        participants.count + 1 // +1 for local user
    }

    var maxParticipants: Int {
        room?.maxParticipants ?? 6
    }

    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
