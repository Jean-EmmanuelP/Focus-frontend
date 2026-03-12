import Foundation
import SwiftUI
import Combine

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

    // MARK: - Services

    let liveKitService = FocusRoomLiveKitService()
    private let roomService = FocusRoomService()

    // MARK: - Private

    let category: FocusRoomCategory
    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

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
            let newState = !liveKitService.isMicEnabled
            try? await liveKitService.setMicEnabled(newState)
        }
    }

    func toggleCamera() {
        Task {
            let newState = !liveKitService.isCameraEnabled
            try? await liveKitService.setCameraEnabled(newState)
        }
    }

    // MARK: - Session Timer

    private func startSessionTimer() {
        sessionDuration = 0
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sessionDuration += 1
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
