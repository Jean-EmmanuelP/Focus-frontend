import Foundation
import Combine

#if canImport(LiveKit)
import LiveKit

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
    private var streamHandlersRegistered = false

    // MARK: - Connection

    func connect(mode: String = "voice_call") async throws {
        if !delegateAdded {
            room.delegates.add(delegate: self)
            delegateAdded = true
        }

        connectionState = .connecting
        agentTranscription = ""
        userTranscription = ""

        // Register stream handlers before connecting so they're ready when agent sends data
        try await registerStreamHandlers()

        // Send mode + assistantId so the agent can call Backboard
        let assistantId = BackboardService.shared.currentAssistantId
        let metadataJSON = "{\"mode\":\"\(mode)\",\"bid\":\"\(assistantId)\"}"

        let response: LiveKitTokenResponse = try await apiClient.request(
            endpoint: .livekitToken,
            method: .post,
            body: LiveKitTokenRequest(
                roomName: "voice-\(UUID().uuidString.prefix(8))",
                metadata: metadataJSON
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
        await unregisterStreamHandlers()
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

    // MARK: - Stream Handlers

    private func registerStreamHandlers() async throws {
        guard !streamHandlersRegistered else { return }
        streamHandlersRegistered = true

        // Handle transcription streams (agent speech-to-text and user speech-to-text)
        try await room.registerTextStreamHandler(for: "lk.transcription") { [weak self] reader, participantIdentity in
            guard let self else { return }
            var accumulated = ""
            for try await chunk in reader {
                guard !chunk.isEmpty else { continue }
                // Agent transcription: chunks are appended
                // User transcription: each chunk replaces content
                let isUser = await self.isLocalParticipant(participantIdentity)
                if isUser {
                    // User STT: full replacement each time
                    accumulated = chunk
                } else {
                    // Agent TTS transcript: append chunks
                    accumulated += chunk
                }
                await MainActor.run { [accumulated, isUser] in
                    if isUser {
                        self.userTranscription = accumulated
                    } else {
                        self.agentTranscription = accumulated
                    }
                }
            }
        }

        // Handle agent events (state changes, etc.)
        try await room.registerTextStreamHandler(for: "lk.agent.events") { [weak self] reader, participantIdentity in
            guard let self else { return }
            for try await eventData in reader {
                guard !eventData.isEmpty else { continue }
                // Parse agent events (JSON) and forward via NotificationCenter
                if let data = eventData.data(using: .utf8) {
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .liveKitAgentEvent,
                            object: nil,
                            userInfo: ["data": data, "participant": participantIdentity.stringValue]
                        )
                    }
                }
            }
        }
    }

    private func unregisterStreamHandlers() async {
        guard streamHandlersRegistered else { return }
        streamHandlersRegistered = false
        await room.unregisterTextStreamHandler(for: "lk.transcription")
        await room.unregisterTextStreamHandler(for: "lk.agent.events")
    }

    private func isLocalParticipant(_ identity: Participant.Identity) -> Bool {
        return identity == room.localParticipant.identity
    }
}

// MARK: - RoomDelegate

extension LiveKitVoiceService: RoomDelegate {

    nonisolated func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
        Task { @MainActor in
            self.connectionState = connectionState
        }
    }

    nonisolated func room(_ room: Room, didUpdateSpeakingParticipants speakers: [Participant]) {
        Task { @MainActor in
            self.isAgentSpeaking = speakers.contains { $0 is RemoteParticipant && $0.isSpeaking }
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
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

#else

// MARK: - Stub when LiveKit SDK is not available

/// Mirrors LiveKit's ConnectionState so ViewModels compile without the SDK
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

@MainActor
class LiveKitVoiceService: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var agentTranscription: String = ""
    @Published var userTranscription: String = ""
    @Published var isAgentSpeaking: Bool = false
    @Published var isMicEnabled: Bool = true

    func connect(mode: String = "voice_call") async throws {
        print("⚠️ LiveKit SDK not available — voice features disabled")
        connectionState = .disconnected
    }

    func disconnect() async {
        connectionState = .disconnected
    }

    func setMicEnabled(_ enabled: Bool) async throws {
        isMicEnabled = enabled
    }
}

#endif

// MARK: - Models (always available)

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
    let agentToken: String?

    enum CodingKeys: String, CodingKey {
        case token, url
        case agentToken = "agent_token"
    }
}

// MARK: - Notification

extension Notification.Name {
    static let liveKitCoachAction = Notification.Name("liveKitCoachAction")
    static let liveKitAgentEvent = Notification.Name("liveKitAgentEvent")
}
