import Foundation
import LiveKit
import Combine

// MARK: - LiveKit Voice Service

@MainActor
class LiveKitVoiceService: ObservableObject {

    // MARK: - Published State

    @Published var connectionState: ConnectionState = .disconnected
    @Published var agentTranscription: String = ""
    @Published var userTranscription: String = ""
    @Published var isAgentSpeaking: Bool = false
    @Published var isMicEnabled: Bool = true

    // MARK: - Private

    private let room = Room()
    private let apiClient = APIClient.shared
    private var delegateAdded = false

    // MARK: - Connection

    func connect(mode: String = "voice_call") async throws {
        if !delegateAdded {
            room.delegates.add(delegate: self)
            delegateAdded = true
        }

        connectionState = .connecting
        agentTranscription = ""
        userTranscription = ""

        // Get LiveKit token from backend
        let response: LiveKitTokenResponse = try await apiClient.request(
            endpoint: .livekitToken,
            method: .post,
            body: LiveKitTokenRequest(
                roomName: "voice-\(UUID().uuidString.prefix(8))",
                metadata: mode
            )
        )

        // Connect to LiveKit room with microphone enabled
        try await room.connect(
            url: response.url,
            token: response.token,
            connectOptions: ConnectOptions(enableMicrophone: true)
        )
    }

    func disconnect() async {
        await room.disconnect()
        connectionState = .disconnected
        agentTranscription = ""
        userTranscription = ""
        isAgentSpeaking = false
    }

    func setMicEnabled(_ enabled: Bool) async throws {
        try await room.localParticipant.setMicrophone(enabled: enabled)
        isMicEnabled = enabled
    }
}

// MARK: - RoomDelegate

extension LiveKitVoiceService: RoomDelegate {

    nonisolated func room(_ room: Room, didUpdate connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
        Task { @MainActor in
            self.connectionState = connectionState
        }
    }

    nonisolated func room(_ room: Room, didUpdate speakers: [Participant]) {
        Task { @MainActor in
            self.isAgentSpeaking = speakers.contains { $0 is RemoteParticipant && $0.isSpeaking }
        }
    }

    nonisolated func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didReceiveTranscriptionSegments segments: [TranscriptionSegment]) {
        Task { @MainActor in
            for segment in segments {
                // Check if the transcribed track belongs to the local participant (user speech)
                let isUserTrack = room.localParticipant.trackPublications.values.contains {
                    $0.sid == trackPublication.sid
                }

                if isUserTrack {
                    self.userTranscription = segment.text
                } else {
                    self.agentTranscription = segment.text
                }
            }
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didReceiveData data: Data, forTopic topic: String) {
        guard topic == "coach_action" else { return }
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .liveKitCoachAction,
                object: nil,
                userInfo: ["data": data]
            )
        }
    }
}

// MARK: - Models

struct LiveKitTokenRequest: Encodable {
    let roomName: String
    let metadata: String?

    enum CodingKeys: String, CodingKey {
        case roomName = "room_name"
        case metadata
    }
}

struct LiveKitTokenResponse: Decodable {
    let token: String
    let url: String
}

// MARK: - Notification

extension Notification.Name {
    static let liveKitCoachAction = Notification.Name("liveKitCoachAction")
}
