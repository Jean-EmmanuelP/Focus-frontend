import Foundation
import Combine
import LiveKit

// MARK: - Connection State

enum VoiceConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

// MARK: - Voice Message (for history, copy/paste)

struct VoiceMessage: Identifiable, Equatable {
    let id: UUID
    let role: VoiceMessageRole
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), role: VoiceMessageRole, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }

    enum VoiceMessageRole: String, Equatable, Codable {
        case user
        case agent
    }
}

// MARK: - LiveKit Voice Service

@MainActor
class LiveKitVoiceService: ObservableObject {

    // MARK: - Published State

    @Published var connectionState: VoiceConnectionState = .disconnected
    @Published var agentTranscription: String = ""
    @Published var userTranscription: String = ""
    @Published var isAgentSpeaking: Bool = false
    @Published var isUserSpeaking: Bool = false
    @Published var isMicEnabled: Bool = true
    @Published var messages: [VoiceMessage] = []
    @Published var audioLevel: Float = 0.0

    // MARK: - Private

    private let room = Room()
    private let apiClient = APIClient.shared

    // MARK: - Configuration

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

    func connect(mode: String = "voice_call", planningScope: String? = nil) async throws {
        NSLog("🎤 [LiveKit] connect() called mode=%@ scope=%@", mode, planningScope ?? "nil")
        connectionState = .connecting
        agentTranscription = ""
        userTranscription = ""
        messages = []

        let lang = Locale.current.language.languageCode?.identifier ?? "fr"
        let voiceId = UserDefaults.standard.string(forKey: SettingsPrefsKeys.voltaVoiceId)
        let companionName = FocusAppStore.shared.user?.companionName

        // Get token from backend
        NSLog("🎤 [LiveKit] requesting token from backend...")
        let response: LiveKitTokenResponse
        do {
            response = try await apiClient.request(
                endpoint: .livekitToken,
                method: .post,
                body: LiveKitTokenRequest(mode: mode, lang: lang, voiceId: voiceId, companionName: companionName, planningScope: planningScope)
            )
            NSLog("🎤 [LiveKit] token received, url=%@ token.len=%d", response.url ?? Self.livekitURL, response.token.count)
        } catch {
            NSLog("🎤 [LiveKit] ❌ token request failed: %@", String(describing: error))
            connectionState = .disconnected
            throw error
        }

        let url = response.url ?? Self.livekitURL
        guard !url.isEmpty else {
            NSLog("🎤 [LiveKit] ❌ missing URL")
            connectionState = .disconnected
            throw LiveKitVoiceError.missingURL
        }

        do {
            NSLog("🎤 [LiveKit] connecting to room at %@...", url)
            try await room.connect(url: url, token: response.token)
            NSLog("🎤 [LiveKit] ✅ room connected, sid=%@", room.sid?.stringValue ?? "nil")

            NSLog("🎤 [LiveKit] enabling microphone...")
            try await room.localParticipant.setMicrophone(enabled: true)
            NSLog("🎤 [LiveKit] ✅ microphone enabled")

            try await room.localParticipant.setCamera(enabled: false)

            // Register for native transcription streams (LiveKit SDK 2.12+)
            // Read progressively for smooth word-by-word display
            try await room.registerTextStreamHandler(for: "lk.transcription") { [weak self] reader, participantIdentity in
                guard let self else { return }
                let isAgent = participantIdentity.stringValue != self.room.localParticipant.identity?.stringValue
                NSLog("🎤 [LiveKit] transcription stream from %@ (agent=%@)", participantIdentity.stringValue, isAgent ? "Y" : "N")
                var accumulated = ""
                for try await chunk in reader {
                    accumulated += chunk
                    let text = accumulated
                    Task { @MainActor in
                        if isAgent {
                            self.agentTranscription = text
                        } else {
                            self.userTranscription = text
                        }
                    }
                }
                let finalText = accumulated
                NSLog("🎤 [LiveKit] transcription complete (agent=%@): %@", isAgent ? "Y" : "N", finalText.prefix(80) as CVarArg)
                if !finalText.isEmpty {
                    Task { @MainActor in
                        self.messages.append(VoiceMessage(
                            role: isAgent ? .agent : .user,
                            text: finalText
                        ))
                    }
                }
            }
            NSLog("🎤 [LiveKit] ✅ transcription handler registered")

            connectionState = .connected
            isMicEnabled = true
            NSLog("🎤 [LiveKit] ✅ fully connected, ready to talk")
        } catch {
            NSLog("🎤 [LiveKit] ❌ connect failed: %@", String(describing: error))
            connectionState = .disconnected
            throw error
        }
    }

    func disconnect() async {
        // Don't set connectionState here — the RoomDelegate will handle it
        // Setting it here causes double-dismiss crash via the observer chain
        agentTranscription = ""
        userTranscription = ""
        isAgentSpeaking = false
        isUserSpeaking = false
        audioLevel = 0
        // Fire-and-forget room disconnect — don't block caller
        let roomRef = room
        Task.detached { await roomRef.disconnect() }
    }

    func setMicEnabled(_ enabled: Bool) async throws {
        try await room.localParticipant.setMicrophone(enabled: enabled)
        isMicEnabled = enabled
    }
}

// MARK: - RoomDelegate

extension LiveKitVoiceService: RoomDelegate {

    /// Receive data messages from LiveKit agent (transcriptions, coach actions)
    nonisolated func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            NSLog("🎤 [LiveKit] ❓ data received topic=%@ but no JSON type", topic)
            return
        }
        NSLog("🎤 [LiveKit] data type=%@", type)

        Task { @MainActor in
            switch type {
            case "agent_transcription":
                if let text = json["text"] as? String {
                    NSLog("🎤 [LiveKit] agent says: %@", text.prefix(80) as CVarArg)
                    agentTranscription = text
                    messages.append(VoiceMessage(role: .agent, text: text))
                }

            case "user_transcription":
                if let text = json["text"] as? String {
                    NSLog("🎤 [LiveKit] user says: %@", text.prefix(80) as CVarArg)
                    userTranscription = text
                    messages.append(VoiceMessage(role: .user, text: text))
                }

            case "agent_speaking":
                if let speaking = json["speaking"] as? Bool {
                    isAgentSpeaking = speaking
                }

            case "coach_action":
                NotificationCenter.default.post(
                    name: .coachAction,
                    object: nil,
                    userInfo: ["data": data]
                )

            default:
                break
            }
        }
    }

    /// Track speaking state from audio levels
    nonisolated func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsSpeaking isSpeaking: Bool) {
        let isLocal = participant is LocalParticipant
        NSLog("🎤 [LiveKit] %@ speaking=%@", isLocal ? "USER" : "AGENT", isSpeaking ? "Y" : "N")
        Task { @MainActor in
            if participant is RemoteParticipant {
                isAgentSpeaking = isSpeaking
            } else if participant is LocalParticipant {
                isUserSpeaking = isSpeaking
                audioLevel = isSpeaking ? 0.7 : 0.0
            }
        }
    }

    /// Agent left the room
    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        NSLog("🎤 [LiveKit] ❌ agent disconnected from room")
        Task { @MainActor in
            isAgentSpeaking = false
        }
    }

    /// Agent joined the room
    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        NSLog("🎤 [LiveKit] ✅ remote participant joined: %@", participant.identity?.stringValue ?? "?")
    }

    /// Reconnection handling
    nonisolated func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
        NSLog("🎤 [LiveKit] connection state %@ -> %@", String(describing: oldConnectionState), String(describing: connectionState))
        Task { @MainActor in
            switch connectionState {
            case .connected:
                self.connectionState = .connected
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

// MARK: - Models

struct LiveKitTokenRequest: Encodable {
    let mode: String
    let lang: String
    let voiceId: String?
    let companionName: String?
    let planningScope: String?
}

struct LiveKitTokenResponse: Decodable {
    let token: String
    let url: String?
}

// MARK: - Errors

enum LiveKitVoiceError: LocalizedError {
    case missingURL
    case noConnection

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "LiveKit URL manquant dans Config.plist"
        case .noConnection:
            return "Pas de connexion internet"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let coachAction = Notification.Name("coachAction")
}
