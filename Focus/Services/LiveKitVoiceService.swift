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
    @Published var isMicEnabled: Bool = true
    @Published var messages: [VoiceMessage] = []

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

    func connect(mode: String = "voice_call") async throws {
        connectionState = .connecting
        agentTranscription = ""
        userTranscription = ""
        messages = []

        let lang = Locale.current.language.languageCode?.identifier ?? "fr"
        let voiceId = UserDefaults.standard.string(forKey: SettingsPrefsKeys.voltaVoiceId)
        let companionName = FocusAppStore.shared.user?.companionName

        // Get token from backend
        let response: LiveKitTokenResponse = try await apiClient.request(
            endpoint: .livekitToken,
            method: .post,
            body: LiveKitTokenRequest(mode: mode, lang: lang, voiceId: voiceId, companionName: companionName)
        )

        let url = response.url ?? Self.livekitURL
        guard !url.isEmpty else {
            connectionState = .disconnected
            throw LiveKitVoiceError.missingURL
        }

        do {
            try await room.connect(url: url, token: response.token)
            try await room.localParticipant.setMicrophone(enabled: true)
            try await room.localParticipant.setCamera(enabled: false)
            connectionState = .connected
            isMicEnabled = true
        } catch {
            connectionState = .disconnected
            throw error
        }
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

    /// Receive data messages from LiveKit agent (transcriptions, coach actions)
    nonisolated func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        Task { @MainActor in
            switch type {
            case "agent_transcription":
                if let text = json["text"] as? String {
                    agentTranscription = text
                    messages.append(VoiceMessage(role: .agent, text: text))
                }

            case "user_transcription":
                if let text = json["text"] as? String {
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
        guard participant is RemoteParticipant else { return }
        Task { @MainActor in
            isAgentSpeaking = isSpeaking
        }
    }

    /// Agent left the room
    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            isAgentSpeaking = false
        }
    }

    /// Reconnection handling
    nonisolated func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
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
