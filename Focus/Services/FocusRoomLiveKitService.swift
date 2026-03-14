import Foundation
import Combine
import LiveKit
import AVFoundation

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
        lhs.isCameraOn == rhs.isCameraOn &&
        lhs.videoTrack === rhs.videoTrack
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
    @Published var localVideoTrack: VideoTrack?

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

        // Configure AVAudioSession for background audio
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("[FocusRoom] AVAudioSession config failed: \(error)")
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
        localVideoTrack = nil
        isCameraEnabled = false
        isMicEnabled = true
    }

    func setMicEnabled(_ enabled: Bool) async throws {
        try await room.localParticipant.setMicrophone(enabled: enabled)
        isMicEnabled = enabled
    }

    func setCameraEnabled(_ enabled: Bool) async throws {
        let publication = try await room.localParticipant.setCamera(enabled: enabled)
        isCameraEnabled = enabled
        localVideoTrack = enabled ? publication?.track as? VideoTrack : nil
        syncParticipants()
    }

    // MARK: - Sync Participants

    private func syncParticipants() {
        var states: [ParticipantState] = []

        for (_, participant) in room.remoteParticipants {
            // Skip AI agent participants
            let identity = participant.identity?.stringValue ?? ""
            if identity.hasPrefix("agent-") { continue }

            let videoTrack = participant.videoTracks.first?.track as? VideoTrack
            let audioPublication = participant.audioTracks.first
            let isMuted = audioPublication?.isMuted ?? true

            states.append(ParticipantState(
                id: identity.isEmpty ? (participant.sid?.stringValue ?? UUID().uuidString) : identity,
                displayName: participant.name ?? (identity.isEmpty ? "Inconnu" : identity),
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

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            self.syncParticipants()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            self.syncParticipants()
        }
    }

    nonisolated func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
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
