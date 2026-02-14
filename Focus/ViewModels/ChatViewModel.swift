import Foundation
import SwiftUI
import Combine

// MARK: - Notification for calendar refresh
extension Notification.Name {
    static let calendarNeedsRefresh = Notification.Name("calendarNeedsRefresh")
}

// MARK: - Message Type
enum ChatMessageType: String, Codable {
    case text
    case voice
}

// MARK: - Simple Chat Message Model (for WhatsApp-style UI)

struct SimpleChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let type: ChatMessageType
    let voiceDuration: TimeInterval?
    // Local filename for cached audio (in Documents/voice_messages/)
    let voiceFilename: String?
    // Supabase Storage path for cloud backup (e.g., "voice-messages/userId/uuid.m4a")
    let voiceStoragePath: String?

    // Computed property to get local URL from filename
    var localVoiceURL: URL? {
        guard let filename = voiceFilename else { return nil }
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDir.appendingPathComponent("voice_messages").appendingPathComponent(filename)
    }

    // Check if local file exists
    var hasLocalAudio: Bool {
        guard let url = localVoiceURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    init(content: String, isFromUser: Bool, type: ChatMessageType = .text, voiceDuration: TimeInterval? = nil, voiceURL: URL? = nil, storagePath: String? = nil) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.type = type
        self.voiceDuration = voiceDuration
        self.voiceFilename = voiceURL?.lastPathComponent
        self.voiceStoragePath = storagePath
    }

    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date(), type: ChatMessageType = .text, voiceDuration: TimeInterval? = nil, voiceURL: URL? = nil, storagePath: String? = nil) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.type = type
        self.voiceDuration = voiceDuration
        self.voiceFilename = voiceURL?.lastPathComponent
        self.voiceStoragePath = storagePath
    }
}

// MARK: - Chat ViewModel

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var messages: [SimpleChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false

    // MARK: - Services

    private let apiClient = APIClient.shared
    private weak var store: FocusAppStore?

    // MARK: - Initialization

    init() {}

    func setStore(_ store: FocusAppStore) {
        self.store = store
    }

    // MARK: - Load History

    func loadHistory() {
        // Load from local storage
        messages = SimpleChatPersistence.loadMessages()

        // Add welcome message if empty
        if messages.isEmpty {
            addWelcomeMessage()
        }

        // Check for daily greeting
        checkForDailyGreeting()

        // Check for pending message from onboarding flow
        checkForPendingMessage()
    }

    /// Check and send any pending message from the onboarding flow
    private func checkForPendingMessage() {
        guard let pendingMessage = UserDefaults.standard.string(forKey: "pending_chat_message"),
              !pendingMessage.isEmpty else {
            return
        }

        // Clear the pending message immediately to prevent duplicate sends
        UserDefaults.standard.removeObject(forKey: "pending_chat_message")

        print("📨 Found pending message from onboarding: \(pendingMessage)")

        // Add user message to UI
        let userMessage = SimpleChatMessage(content: pendingMessage, isFromUser: true)
        messages.append(userMessage)
        saveMessages()

        // Send to AI
        Task {
            await sendToAI(pendingMessage)
        }
    }

    private func addWelcomeMessage() {
        let userName = store?.user?.pseudo ?? store?.user?.firstName ?? "ami"
        let companionName = store?.user?.companionName ?? "Kai"
        let greeting = "Salut \(userName). Je suis \(companionName), ton coach. Dis-moi : c'est quoi le truc que tu veux vraiment changer dans ta vie ?"

        let message = SimpleChatMessage(content: greeting, isFromUser: false)
        messages.append(message)
        saveMessages()
    }

    private func checkForDailyGreeting() {
        guard let lastMessage = messages.last else { return }

        // If last message was from yesterday, add new greeting
        if !Calendar.current.isDateInToday(lastMessage.timestamp) {
            let userName = store?.user?.pseudo ?? store?.user?.firstName ?? ""
            let streak = store?.currentStreak ?? 0
            let hour = Calendar.current.component(.hour, from: Date())

            var greeting: String
            switch hour {
            case 5..<12:
                if streak > 7 {
                    greeting = "\(streak) jours de streak \(userName) 🔥 C'est quoi la priorité aujourd'hui ?"
                } else {
                    greeting = "Salut \(userName). Nouvelle journée, nouvelles opportunités. On attaque quoi ?"
                }
            case 12..<18:
                greeting = "Hey \(userName). Comment avance ta journée ? T'as avancé sur tes tâches ?"
            case 18..<22:
                greeting = "Fin de journée \(userName). C'est quoi ta plus grande victoire aujourd'hui ?"
            default:
                greeting = "Il est tard \(userName). Tu veux faire un bilan rapide avant de te reposer ?"
            }

            let message = SimpleChatMessage(content: greeting, isFromUser: false)
            messages.append(message)
            saveMessages()
        }
    }

    // MARK: - Send Text Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message
        let userMessage = SimpleChatMessage(content: text, isFromUser: true)
        messages.append(userMessage)
        inputText = ""
        saveMessages()

        // Send to AI
        Task {
            await sendToAI(text)
        }
    }

    // MARK: - Send Voice Message

    func sendVoiceMessage(audioURL: URL) async {
        // Get audio duration
        let duration = getAudioDuration(url: audioURL)

        // Copy to permanent local storage for replay
        let permanentURL = copyToPermanentStorage(audioURL)

        // Add voice message to UI immediately (local storage only at first)
        var voiceMessage = SimpleChatMessage(
            content: "🎤 Message vocal",
            isFromUser: true,
            type: .voice,
            voiceDuration: duration,
            voiceURL: permanentURL,
            storagePath: nil
        )
        messages.append(voiceMessage)
        saveMessages()

        isLoading = true

        // Upload to Supabase Storage in background
        var storagePath: String?
        if let userId = AuthService.shared.userId {
            do {
                let audioData = try Data(contentsOf: permanentURL)
                storagePath = try await SupabaseStorageService.shared.uploadVoiceMessage(
                    audioData: audioData,
                    userId: userId
                )
                print("✅ Voice uploaded to Supabase: \(storagePath ?? "nil")")
            } catch {
                print("⚠️ Supabase upload failed (local backup exists): \(error)")
            }
        }

        do {
            // Send to backend for transcription + AI response (include Supabase URL)
            let response: VoiceMessageResponse = try await uploadVoiceMessage(audioURL: audioURL, audioStorageURL: storagePath)

            // Update voice message with transcript and storage path
            if let index = messages.lastIndex(where: { $0.id == voiceMessage.id }) {
                let transcript = response.transcript ?? voiceMessage.content
                messages[index] = SimpleChatMessage(
                    id: voiceMessage.id,
                    content: transcript.isEmpty ? "🎤 Message vocal" : transcript,
                    isFromUser: true,
                    timestamp: voiceMessage.timestamp,
                    type: .voice,
                    voiceDuration: duration,
                    voiceURL: permanentURL,
                    storagePath: storagePath
                )
            }

            // Add AI response
            let aiMessage = SimpleChatMessage(content: response.reply, isFromUser: false)
            messages.append(aiMessage)
            saveMessages()

            // Handle coach actions (task creation, blocking, etc.)
            if let action = response.action {
                await handleCoachAction(action)
            }

        } catch {
            // Update message with storage path even if transcription fails
            if let index = messages.lastIndex(where: { $0.id == voiceMessage.id }), storagePath != nil {
                messages[index] = SimpleChatMessage(
                    id: voiceMessage.id,
                    content: voiceMessage.content,
                    isFromUser: true,
                    timestamp: voiceMessage.timestamp,
                    type: .voice,
                    voiceDuration: duration,
                    voiceURL: permanentURL,
                    storagePath: storagePath
                )
            }

            // Fallback response
            let fallback = "J'ai pas bien entendu, tu peux répéter?"
            let aiMessage = SimpleChatMessage(content: fallback, isFromUser: false)
            messages.append(aiMessage)
            saveMessages()

            print("Voice message error: \(error)")
        }

        isLoading = false

        // Clean up temporary recording file (permanent copy already made)
        try? FileManager.default.removeItem(at: audioURL)
    }

    // Copy audio to permanent storage for replay
    private func copyToPermanentStorage(_ tempURL: URL) -> URL {
        let fileManager = FileManager.default
        let voiceMessagesDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("voice_messages", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: voiceMessagesDir, withIntermediateDirectories: true)

        let permanentURL = voiceMessagesDir.appendingPathComponent("\(UUID().uuidString).m4a")

        do {
            try fileManager.copyItem(at: tempURL, to: permanentURL)
            return permanentURL
        } catch {
            print("Failed to copy audio file: \(error)")
            return tempURL // Fallback to temp URL
        }
    }

    private func getAudioDuration(url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }

    private func uploadVoiceMessage(audioURL: URL, audioStorageURL: String?) async throws -> VoiceMessageResponse {
        // Read audio data
        let audioData = try Data(contentsOf: audioURL)

        // Create multipart form data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(APIConfiguration.baseURL)/chat/voice")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Add auth token from Supabase session (required)
        guard let token = await AuthService.shared.getAccessToken() else {
            print("❌ No auth token available for voice upload")
            throw URLError(.userAuthenticationRequired)
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Build multipart body
        var body = Data()

        // Add audio file (m4a uses audio/mp4 MIME type)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add source field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source\"\r\n\r\n".data(using: .utf8)!)
        body.append("app\r\n".data(using: .utf8)!)

        // Add audio_url field (Supabase Storage path)
        if let audioStorageURL = audioStorageURL {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"audio_url\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(audioStorageURL)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Log response for debugging
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "empty"
            print("❌ Voice upload failed: HTTP \(httpResponse.statusCode) - \(errorBody)")
            throw URLError(.badServerResponse)
        }

        print("✅ Voice upload success: \(data.count) bytes response")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(VoiceMessageResponse.self, from: data)
    }

    // MARK: - Send to AI (text)

    private func sendToAI(_ text: String) async {
        isLoading = true

        do {
            // Call backend chat endpoint (with coach context)
            let isBlocking = ScreenTimeAppBlockerService.shared.isBlocking
            let response: AIResponse = try await apiClient.request(
                endpoint: .chatMessage,
                method: .post,
                body: SimpleChatRequest(content: text, source: "app", appsBlocked: isBlocking)
            )

            // Add AI response
            let aiMessage = SimpleChatMessage(content: response.reply, isFromUser: false)
            messages.append(aiMessage)
            saveMessages()

            // Handle actions from the coach
            if let action = response.action {
                await handleCoachAction(action)
            }

        } catch {
            // Fallback response
            let fallback = generateFallbackResponse()
            let aiMessage = SimpleChatMessage(content: fallback, isFromUser: false)
            messages.append(aiMessage)
            saveMessages()

            print("Chat AI error: \(error)")
        }

        isLoading = false
    }

    // Handle all coach actions (task creation, app blocking, quests, routines)
    private func handleCoachAction(_ action: AIActionData) async {
        switch action.type {
        case "task_created":
            print("📋 Coach created task: \(action.task?.title ?? "unknown")")
            NotificationCenter.default.post(name: .calendarNeedsRefresh, object: nil)

        case "quest_created", "quests_created":
            print("🎯 Coach created quest(s)")
            await store?.loadQuests()

        case "routine_created", "routines_created":
            print("🔄 Coach created routine(s)")
            await store?.loadRituals()

        case "quest_updated":
            print("📈 Coach updated quest progress")
            await store?.loadQuests()

        case "block_apps":
            print("🔒 Coach triggered app blocking")
            let blocker = ScreenTimeAppBlockerService.shared
            if blocker.isBlockingEnabled {
                blocker.startBlocking()
            }

        case "unblock_apps":
            print("🔓 Coach approved app unblocking")
            let blocker = ScreenTimeAppBlockerService.shared
            if blocker.isBlocking {
                blocker.stopBlocking()
            }

        default:
            break
        }
    }

    private func generateFallbackResponse() -> String {
        let responses = [
            "Problème technique de mon côté. Réessaie.",
            "J'ai eu un bug. Renvoie ton message.",
            "Souci de connexion. Dis-moi ça encore une fois."
        ]
        return responses.randomElement() ?? "Réessaie dans quelques secondes."
    }

    // MARK: - Persistence

    private func saveMessages() {
        SimpleChatPersistence.saveMessages(messages)
    }

    // MARK: - Clear Chat

    func clearChat() {
        messages = []
        SimpleChatPersistence.clearMessages()
        addWelcomeMessage()

        // Also clear chat history on the backend
        Task {
            do {
                try await apiClient.request(
                    endpoint: .chatHistory,
                    method: .delete
                )
            } catch {
                print("Failed to clear chat history on backend: \(error)")
            }
        }
    }
}

// MARK: - API Models

struct SimpleChatRequest: Encodable {
    let content: String
    let source: String
    let appsBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case content, source
        case appsBlocked = "apps_blocked"
    }
}

struct AIResponse: Decodable {
    let reply: String
    let tool: String?
    let messageId: String?
    let action: AIActionData?

    enum CodingKeys: String, CodingKey {
        case reply
        case tool
        case messageId = "message_id"
        case action
    }
}

struct VoiceMessageResponse: Decodable {
    let reply: String
    let transcript: String?
    let messageId: String?
    let action: AIActionData?

    enum CodingKeys: String, CodingKey {
        case reply
        case transcript
        case messageId = "message_id"
        case action
    }
}

// Action taken by Kai (task created, focus scheduled, etc.)
struct AIActionData: Decodable {
    let type: String           // "task_created", "focus_scheduled"
    let taskId: String?
    let task: AITaskData?

    enum CodingKeys: String, CodingKey {
        case type
        case taskId = "task_id"
        case task
    }
}

struct AITaskData: Decodable {
    let title: String
    let date: String
    let scheduledStart: String
    let scheduledEnd: String
    let blockApps: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case scheduledStart = "scheduled_start"
        case scheduledEnd = "scheduled_end"
        case blockApps = "block_apps"
    }
}

// MARK: - Simple Chat Persistence (v3 - with voice support)

enum SimpleChatPersistence {
    private static let key = "chat_messages_v3"

    static func saveMessages(_ messages: [SimpleChatMessage]) {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadMessages() -> [SimpleChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let messages = try? JSONDecoder().decode([SimpleChatMessage].self, from: data) else {
            // Try loading from v2 format
            return loadFromV2()
        }
        return messages
    }

    private static func loadFromV2() -> [SimpleChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: "chat_messages_v2"),
              let oldMessages = try? JSONDecoder().decode([OldChatMessage].self, from: data) else {
            return []
        }

        // Convert old format to new
        return oldMessages.map { msg in
            SimpleChatMessage(
                id: msg.id,
                content: msg.content,
                isFromUser: msg.isFromUser,
                timestamp: msg.timestamp,
                type: msg.type == .voice ? .voice : .text,
                voiceDuration: nil,
                voiceURL: msg.voiceURL
            )
        }
    }

    static func clearMessages() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: "chat_messages_v2")
    }
}

// MARK: - Old ChatMessage for Migration

struct OldChatMessage: Identifiable, Codable {
    let id: UUID
    let type: MessageType
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let toolAction: OldChatTool?
    let voiceURL: URL?
    let voiceTranscript: String?

    enum MessageType: String, Codable {
        case text
        case voice
        case toolCard
    }

    init(
        id: UUID = UUID(),
        type: MessageType = .text,
        content: String,
        isFromUser: Bool,
        timestamp: Date = Date(),
        toolAction: OldChatTool? = nil,
        voiceURL: URL? = nil,
        voiceTranscript: String? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.toolAction = toolAction
        self.voiceURL = voiceURL
        self.voiceTranscript = voiceTranscript
    }
}

enum OldChatTool: String, Codable {
    case planDay
    case weeklyGoals
    case dailyReflection
    case startFocus
    case viewStats
    case logMood
}

// MARK: - Import AVFoundation for duration
import AVFoundation
