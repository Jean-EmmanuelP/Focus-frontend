import Foundation
import Combine
import LiveKit

// MARK: - Participant State

struct ParticipantState: Identifiable, Equatable {
    let id: String
    var displayName: String
    var isSpeaking: Bool
    var isMuted: Bool
    var isCameraOn: Bool
    var videoTrack: VideoTrack?

    static func == (lhs: ParticipantState, rhs: ParticipantState) -> Bool {
        lhs.id == rhs.id &&
        lhs.displayName == rhs.displayName &&
        lhs.isSpeaking == rhs.isSpeaking &&
        lhs.isMuted == rhs.isMuted &&
        lhs.isCameraOn == rhs.isCameraOn
    }
}

// MARK: - Focus Room LiveKit Service

@MainActor
class FocusRoomLiveKitService: ObservableObject, RoomDelegate {

    // MARK: - Published State

    @Published var connectionState: VoiceConnectionState = .disconnected
    @Published var participants: [ParticipantState] = []
    @Published var isMicEnabled: Bool = true
    @Published var isCameraEnabled: Bool = false

    // MARK: - Private

    private let room = Room()

    private static var livekitURL: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let url = dict["LIVEKIT_URL"] as? String else {
            return ""
        }
        return url
    }

    // MARK: - Init

    init() {
        room.add(delegate: self)
    }

    // MARK: - Connection

    func connect(token: String, url: String?) async throws {
        connectionState = .connecting
        participants = []

        let resolvedURL = url ?? Self.livekitURL
        guard !resolvedURL.isEmpty else {
            connectionState = .disconnected
            throw LiveKitVoiceError.missingURL
        }

        do {
            try await room.connect(url: resolvedURL, token: token)
            try await room.localParticipant.setMicrophone(enabled: true)
            try await room.localParticipant.setCamera(enabled: false)
            connectionState = .connected
            isMicEnabled = true
            isCameraEnabled = false
            syncParticipants()
        } catch {
            connectionState = .disconnected
            throw error
        }
    }

    func disconnect() async {
        await room.disconnect()
        connectionState = .disconnected
        participants = []
    }

    func setMicEnabled(_ enabled: Bool) async throws {
        try await room.localParticipant.setMicrophone(enabled: enabled)
        isMicEnabled = enabled
    }

    func setCameraEnabled(_ enabled: Bool) async throws {
        try await room.localParticipant.setCamera(enabled: enabled)
        isCameraEnabled = enabled
        syncParticipants()
    }

    // MARK: - Sync Participants

    private func syncParticipants() {
        var states: [ParticipantState] = []

        for (_, participant) in room.remoteParticipants {
            let videoTrack = participant.videoTracks.first?.track as? VideoTrack
            let audioPublication = participant.audioTracks.first
            let isMuted = audioPublication?.isMuted ?? true

            states.append(ParticipantState(
                id: participant.identity?.stringValue ?? participant.sid?.stringValue ?? UUID().uuidString,
                displayName: participant.name ?? participant.identity?.stringValue ?? "Inconnu",
                isSpeaking: participant.isSpeaking,
                isMuted: isMuted,
                isCameraOn: videoTrack != nil,
                videoTrack: videoTrack
            ))
        }

        participants = states
    }

    // MARK: - RoomDelegate

    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in
            self.syncParticipants()
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            self.syncParticipants()
        }
    }

    nonisolated func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsSpeaking isSpeaking: Bool) {
        Task { @MainActor in
            self.syncParticipants()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            self.syncParticipants()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            self.syncParticipants()
        }
    }

    nonisolated func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
        Task { @MainActor in
            switch connectionState {
            case .connected:
                self.connectionState = .connected
                self.syncParticipants()
            case .disconnected:
                if self.connectionState == .connected || self.connectionState == .reconnecting {
                    self.connectionState = .disconnected
                }
            case .reconnecting:
                self.connectionState = .reconnecting
            default:
                break
            }
        }
    }
}
