import Foundation
import Combine
import Daily

// MARK: - Connection State

enum VoiceConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

// MARK: - Daily Voice Service

@MainActor
class DailyVoiceService: ObservableObject {

    // MARK: - Published State

    @Published var connectionState: VoiceConnectionState = .disconnected
    @Published var agentTranscription: String = ""
    @Published var userTranscription: String = ""
    @Published var isAgentSpeaking: Bool = false
    @Published var isMicEnabled: Bool = true

    // MARK: - Private

    private var callClient: CallClient?
    private let apiClient = APIClient.shared

    // MARK: - Connection

    func connect(mode: String = "voice_call") async throws {
        connectionState = .connecting
        agentTranscription = ""
        userTranscription = ""

        let lang = Locale.current.language.languageCode?.identifier ?? "fr"

        let response: DailyTokenResponse = try await apiClient.request(
            endpoint: .dailyToken,
            method: .post,
            body: DailyTokenRequest(mode: mode, lang: lang)
        )

        let client = CallClient()
        self.callClient = client
        client.delegate = self

        let token = MeetingToken(stringValue: response.token)

        do {
            _ = try await client.join(url: URL(string: response.roomUrl)!, token: token)
            // Enable mic, disable camera
            try await client.setInputEnabled(.microphone, true)
            try await client.setInputEnabled(.camera, false)
            connectionState = .connected
            isMicEnabled = true
        } catch {
            connectionState = .disconnected
            throw error
        }
    }

    func disconnect() async {
        guard let client = callClient else { return }
        try? await client.leave()
        callClient = nil
        connectionState = .disconnected
        agentTranscription = ""
        userTranscription = ""
        isAgentSpeaking = false
    }

    func setMicEnabled(_ enabled: Bool) async throws {
        guard let client = callClient else { return }
        try await client.setInputEnabled(.microphone, enabled)
        isMicEnabled = enabled
    }
}

// MARK: - CallClientDelegate

extension DailyVoiceService: CallClientDelegate {

    func callClient(_ callClient: CallClient, appMessageAsJson jsonData: Data, from participantID: ParticipantID) {
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "agent_transcription":
            if let text = json["text"] as? String {
                agentTranscription = text
            }

        case "user_transcription":
            if let text = json["text"] as? String {
                userTranscription = text
            }

        case "agent_speaking":
            if let speaking = json["speaking"] as? Bool {
                isAgentSpeaking = speaking
            }

        case "coach_action":
            NotificationCenter.default.post(
                name: .dailyCoachAction,
                object: nil,
                userInfo: ["data": jsonData]
            )

        default:
            break
        }
    }

    func callClient(_ callClient: CallClient, activeSpeakerChanged activeSpeaker: Participant?) {
        if let speaker = activeSpeaker, !speaker.info.isLocal {
            isAgentSpeaking = true
        } else {
            isAgentSpeaking = false
        }
    }

    func callClient(_ callClient: CallClient, participantLeft participant: Participant, withReason reason: ParticipantLeftReason) {
        if !participant.info.isLocal {
            isAgentSpeaking = false
        }
    }
}

// MARK: - Models

struct DailyTokenRequest: Encodable {
    let mode: String
    let lang: String
}

struct DailyTokenResponse: Decodable {
    let roomUrl: String
    let token: String

    enum CodingKeys: String, CodingKey {
        case roomUrl = "room_url"
        case token
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let dailyCoachAction = Notification.Name("dailyCoachAction")
}
