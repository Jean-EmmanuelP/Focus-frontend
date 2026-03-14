import Foundation
import SwiftUI
import Combine
import Speech

// MARK: - Notification for calendar refresh
extension Notification.Name {
    static let calendarNeedsRefresh = Notification.Name("calendarNeedsRefresh")
    static let openAppBlockerSettings = Notification.Name("openAppBlockerSettings")
    static let forceUnblockApps = Notification.Name("forceUnblockApps")
}

// MARK: - Message Type
enum ChatMessageType: String, Codable {
    case text
    case voice
}

// MARK: - Chat Card Data (Interactive tools in chat)
enum ChatCardData: Codable {
    case taskList([CardTask])
    case routineList([CardRoutine])
    case planning([CardTask], [CardRoutine], PlanningFocusState?)
    case actionButton(ActionButton)
    case videoCard(VideoCard)
    case videoSuggestions(VideoSuggestionsData)

    struct PlanningFocusState: Codable {
        var activeTaskId: String?
        var activeTaskTitle: String?
        var duration: Int // minutes
        var timeRemaining: Int? // seconds
        var sessionId: String?
        var timerState: FocusTimerState
    }

    enum FocusTimerState: String, Codable {
        case idle, running, paused, completed
    }

    struct CardTask: Codable, Identifiable {
        let id: String
        let title: String
        var isCompleted: Bool
        var estimatedMinutes: Int?
    }

    struct CardRoutine: Codable, Identifiable {
        let id: String
        let title: String
        let icon: String
        var isCompleted: Bool
    }

    struct ActionButton: Codable {
        let title: String
        let icon: String
        let deepLink: String
    }

    struct VideoCard: Codable {
        let url: String
        let videoId: String
        let title: String
        var isCompleted: Bool
    }

    struct VideoSuggestionsData: Codable {
        let category: String
        let videos: [VideoSuggestion]
    }

    struct VideoSuggestion: Codable, Identifiable {
        var id: String { videoId }
        let videoId: String
        let title: String
        let duration: String
    }

    // MARK: - Backward-compatible Codable

    private enum CodingKeys: String, CodingKey {
        case taskList, routineList, planning, actionButton, videoCard, videoSuggestions
    }

    private struct PlanningPayload: Codable {
        let _0: [CardTask]
        let _1: [CardRoutine]
        let _2: PlanningFocusState?

        init(_0: [CardTask], _1: [CardRoutine], _2: PlanningFocusState?) {
            self._0 = _0; self._1 = _1; self._2 = _2
        }
    }

    private struct OldPlanningPayload: Codable {
        let _0: [CardTask]
        let _1: [CardRoutine]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let tasks = try? container.decode([CardTask].self, forKey: .taskList) {
            self = .taskList(tasks)
        } else if let routines = try? container.decode([CardRoutine].self, forKey: .routineList) {
            self = .routineList(routines)
        } else if let payload = try? container.decode(PlanningPayload.self, forKey: .planning) {
            self = .planning(payload._0, payload._1, payload._2)
        } else if let old = try? container.decode(OldPlanningPayload.self, forKey: .planning) {
            self = .planning(old._0, old._1, nil)
        } else if let action = try? container.decode(ActionButton.self, forKey: .actionButton) {
            self = .actionButton(action)
        } else if let video = try? container.decode(VideoCard.self, forKey: .videoCard) {
            self = .videoCard(video)
        } else if let data = try? container.decode(VideoSuggestionsData.self, forKey: .videoSuggestions) {
            self = .videoSuggestions(data)
        } else {
            // Old focusTimer or unknown — fallback to empty task list
            self = .taskList([])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .taskList(let tasks):
            try container.encode(tasks, forKey: .taskList)
        case .routineList(let routines):
            try container.encode(routines, forKey: .routineList)
        case .planning(let tasks, let routines, let focusState):
            try container.encode(PlanningPayload(_0: tasks, _1: routines, _2: focusState), forKey: .planning)
        case .actionButton(let action):
            try container.encode(action, forKey: .actionButton)
        case .videoCard(let video):
            try container.encode(video, forKey: .videoCard)
        case .videoSuggestions(let data):
            try container.encode(data, forKey: .videoSuggestions)
        }
    }
}

// MARK: - Message Status

enum MessageStatus: String, Codable {
    case sent
    case sending
    case failed
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
    // Interactive card data (task list, routine list, etc.)
    var cardData: ChatCardData?
    // Message delivery status (for user messages)
    var status: MessageStatus

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

    /// Return a copy with placeholders resolved in content
    func withResolvedContent(_ resolver: (String) -> String) -> SimpleChatMessage {
        let resolved = resolver(content)
        if resolved == content { return self }
        var msg = SimpleChatMessage(
            id: id,
            content: resolved,
            isFromUser: isFromUser,
            timestamp: timestamp,
            type: type,
            voiceDuration: voiceDuration,
            voiceURL: localVoiceURL,
            storagePath: voiceStoragePath
        )
        msg.cardData = cardData
        msg.status = status
        return msg
    }

    init(content: String, isFromUser: Bool, type: ChatMessageType = .text, voiceDuration: TimeInterval? = nil, voiceURL: URL? = nil, storagePath: String? = nil, status: MessageStatus = .sent) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.type = type
        self.voiceDuration = voiceDuration
        self.voiceFilename = voiceURL?.lastPathComponent
        self.voiceStoragePath = storagePath
        self.status = status
    }

    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date(), type: ChatMessageType = .text, voiceDuration: TimeInterval? = nil, voiceURL: URL? = nil, storagePath: String? = nil, status: MessageStatus = .sent) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.type = type
        self.voiceDuration = voiceDuration
        self.voiceFilename = voiceURL?.lastPathComponent
        self.voiceStoragePath = storagePath
        self.status = status
    }
}

// MARK: - Chat ViewModel

// MARK: - Message Group (for date grouping)

struct MessageGroup: Identifiable {
    let date: Date
    let messages: [SimpleChatMessage]
    var id: Date { date }
}

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var messages: [SimpleChatMessage] = [] {
        didSet { recalculateGroupedMessages() }
    }
    @Published var groupedMessages: [MessageGroup] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var satisfactionScore: Int = UserDefaults.standard.object(forKey: "satisfaction_score") as? Int ?? 50
    @Published var freeVoiceMessagesUsed: Int = FocusAppStore.shared.user?.freeVoiceMessagesUsed ?? 0

    var canSendFreeVoice: Bool {
        SubscriptionManager.shared.isProUser || freeVoiceMessagesUsed < 3
    }

    private func recalculateGroupedMessages() {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []
        var currentDate: Date?
        var currentMessages: [SimpleChatMessage] = []

        for message in messages {
            let messageDate = calendar.startOfDay(for: message.timestamp)

            if currentDate == nil {
                currentDate = messageDate
                currentMessages = [message]
            } else if calendar.isDate(messageDate, inSameDayAs: currentDate!) {
                currentMessages.append(message)
            } else {
                groups.append(MessageGroup(date: currentDate!, messages: currentMessages))
                currentDate = messageDate
                currentMessages = [message]
            }
        }

        if let date = currentDate, !currentMessages.isEmpty {
            groups.append(MessageGroup(date: date, messages: currentMessages))
        }

        groupedMessages = groups
    }

    // MARK: - Services

    private let apiClient = APIClient.shared
    private weak var store: FocusAppStore?

    private func updateSatisfactionScore(_ score: Int?) {
        guard let score = score else { return }
        let clamped = max(0, min(100, score))
        satisfactionScore = clamped
        UserDefaults.standard.set(clamped, forKey: "satisfaction_score")

        // Refresh afternoon notification with updated score
        Task {
            await NotificationService.shared.scheduleAfternoonCheck()
        }
    }

    /// Adjust satisfaction locally when user completes/uncompletes a task or routine
    private func adjustSatisfaction(completed: Bool) {
        let delta = completed ? 8 : -5
        // Ensure completing tasks always pushes above 50 baseline
        var newScore = max(0, min(100, satisfactionScore + delta))
        if completed && newScore < 50 {
            newScore = max(newScore, 50)
        }
        satisfactionScore = newScore
        UserDefaults.standard.set(newScore, forKey: "satisfaction_score")
    }

    // MARK: - Initialization

    init() {}

    func setStore(_ store: FocusAppStore) {
        self.store = store
        self.freeVoiceMessagesUsed = store.user?.freeVoiceMessagesUsed ?? 0
    }

    // MARK: - Load History

    func loadHistory() {
        // Load from local storage
        messages = SimpleChatPersistence.loadMessages()

        // Migrate: remove old welcome messages that contain unresolved placeholders
        let hadPlaceholders = messages.contains { $0.content.contains("{{COMPANION_NAME}}") || $0.content.contains("{{USER_NAME}}") }
        if hadPlaceholders {
            messages.removeAll { !$0.isFromUser && ($0.content.contains("{{COMPANION_NAME}}") || $0.content.contains("{{USER_NAME}}")) }
            saveMessages()
        }

        // Check for pending message from onboarding flow
        checkForPendingMessage()

        // If chat is empty (new user), request a greeting from the coach
        if messages.isEmpty {
            Task {
                await requestGreeting()
            }
        } else {
            // Check for daily greeting
            checkForDailyGreeting()
        }
    }

    /// Request a greeting from the coach (first message when chat is empty)
    private func requestGreeting() async {
        isLoading = true

        do {
            let (reply, sideEffects) = try await BackboardService.shared.sendMessage("Salut")
            await applySideEffects(sideEffects)

            var aiMessage = SimpleChatMessage(content: reply, isFromUser: false)
            if let video = sideEffects.firstShowVideo {
                aiMessage.cardData = makeVideoCard(url: video.url, title: video.title)
            } else if let category = sideEffects.firstShowVideoSuggestions {
                aiMessage.cardData = makeVideoSuggestionsCard(for: category)
            } else if let cardType = sideEffects.firstShowCard {
                aiMessage.cardData = await buildCardData(for: cardType)
            }
            messages.append(aiMessage)
            saveMessages()
        } catch {
            // Fallback greeting for first-time users
            let userName = store?.user?.pseudo ?? store?.user?.firstName ?? ""
            let name = userName.isEmpty ? "" : " \(userName)"
            let fallback = "Salut\(name) ! Je suis ton coach. Dis-moi ce que tu veux accomplir."
            let aiMessage = SimpleChatMessage(content: fallback, isFromUser: false)
            messages.append(aiMessage)
            saveMessages()
            print("Greeting request failed: \(error)")
        }

        isLoading = false
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

    /// Resolve dynamic placeholders in a message string
    func resolvedContent(_ content: String) -> String {
        let userName = store?.user?.pseudo ?? store?.user?.firstName ?? "ami"
        let companionName = store?.user?.companionName ?? "ton coach"
        return content
            .replacingOccurrences(of: "{{USER_NAME}}", with: userName)
            .replacingOccurrences(of: "{{COMPANION_NAME}}", with: companionName)
    }

    private func checkForDailyGreeting() {
        guard let lastMessage = messages.last else { return }

        // If last message was from a previous day, request a fresh AI greeting
        if !Calendar.current.isDateInToday(lastMessage.timestamp) {
            Task {
                await requestDailyGreeting()
            }
        }
    }

    /// Request a daily greeting from Backboard (contextual, never the same)
    private func requestDailyGreeting() async {
        isLoading = true

        let hour = Calendar.current.component(.hour, from: Date())
        let isMorning = (5..<12).contains(hour)
        let greetingMessage = isMorning ? "[MORNING_FLOW]" : "Salut, nouvelle journée"

        do {
            let (reply, sideEffects) = try await BackboardService.shared.sendMessage(greetingMessage)
            await applySideEffects(sideEffects)

            var aiMessage = SimpleChatMessage(content: reply, isFromUser: false)
            if let video = sideEffects.firstShowVideo {
                aiMessage.cardData = makeVideoCard(url: video.url, title: video.title)
            } else if let category = sideEffects.firstShowVideoSuggestions {
                aiMessage.cardData = makeVideoSuggestionsCard(for: category)
            } else if let cardType = sideEffects.firstShowCard {
                aiMessage.cardData = await buildCardData(for: cardType)
            }
            messages.append(aiMessage)
            saveMessages()
        } catch {
            // Fallback: varied local greeting pool
            let greeting = generateLocalDailyGreeting()
            let message = SimpleChatMessage(content: greeting, isFromUser: false)
            messages.append(message)
            saveMessages()
            print("Daily greeting request failed, using local fallback: \(error)")
        }

        isLoading = false
    }

    /// Request a coach reaction when user completes a task or routine
    private func requestCompletionReaction(itemName: String, isTask: Bool) async {
        let verb = isTask ? "la tâche" : "le rituel"
        do {
            let (reply, sideEffects) = try await BackboardService.shared.sendMessage("J'ai terminé \(verb): \(itemName)")
            await applySideEffects(sideEffects)

            let aiMessage = SimpleChatMessage(content: reply, isFromUser: false)
            messages.append(aiMessage)
            saveMessages()
        } catch {
            print("Completion reaction failed: \(error)")
        }
    }

    /// Generate a varied local greeting as fallback when the backend is unreachable
    private func generateLocalDailyGreeting() -> String {
        let userName = store?.user?.pseudo ?? store?.user?.firstName ?? ""
        let name = userName.isEmpty ? "" : " \(userName)"
        let hour = Calendar.current.component(.hour, from: Date())
        let tasksCount = store?.todaysTasks.filter { $0.status != "completed" }.count ?? 0
        let ritualsCount = store?.rituals.filter { !$0.isCompleted }.count ?? 0

        var pool: [String] = []

        switch hour {
        case 5..<12:
            pool = [
                "Yo\(name). Qu'est-ce que tu veux accomplir aujourd'hui ?",
                "Salut\(name). C'est quoi le truc le plus important de ta journée ?",
                "Hey\(name). Prêt à attaquer la journée ?",
                "Nouvelle journée\(name). Sur quoi tu veux avancer ?",
                "Bonjour\(name). Comment tu te sens ce matin ?",
            ]
            if tasksCount > 0 {
                pool.append("T'as \(tasksCount) truc\(tasksCount > 1 ? "s" : "") prévu\(tasksCount > 1 ? "s" : "") aujourd'hui\(name). Par quoi tu commences ?")
            }
        case 12..<18:
            pool = [
                "Salut\(name). Ça se passe comment ?",
                "Hey\(name). Quoi de neuf ?",
                "Yo\(name). Tu fais quoi de beau ?",
                "De retour\(name). Raconte.",
                "Hey\(name). Tout roule ?",
            ]
            if tasksCount > 0 {
                pool.append("Il te reste \(tasksCount) tâche\(tasksCount > 1 ? "s" : "")\(name). Tu gères ?")
            }
            if ritualsCount > 0 {
                pool.append("T'as encore \(ritualsCount) rituel\(ritualsCount > 1 ? "s" : "") à faire\(name). On s'y met ?")
            }
        case 18..<22:
            pool = [
                "Hey\(name). Comment s'est passée ta journée ?",
                "Salut\(name). C'était quoi le meilleur moment aujourd'hui ?",
                "Yo\(name). Tu peux être fier de quoi aujourd'hui ?",
                "Bientôt la fin de journée\(name). Ça a donné quoi ?",
                "Hey\(name). T'as kiffé ta journée ?",
            ]
        default:
            pool = [
                "Encore debout\(name) ? Tout va bien ?",
                "Hey\(name). Tu devrais peut-être te reposer.",
                "Salut\(name). On fait un petit bilan avant de dormir ?",
                "Il est tard\(name). Demain c'est un nouveau jour.",
            ]
        }

        return pool.randomElement() ?? "Hey\(name). Quoi de neuf ?"
    }

    // MARK: - Send Text Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message with sending status
        let userMessage = SimpleChatMessage(content: text, isFromUser: true, status: .sending)
        messages.append(userMessage)
        inputText = ""
        saveMessages()

        // Send to AI
        Task {
            await sendToAI(text, userMessageId: userMessage.id)
        }
    }

    // MARK: - Retry Failed Message

    func retryMessage(_ message: SimpleChatMessage) {
        guard message.status == .failed, message.isFromUser else { return }

        // Mark as sending again
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].status = .sending
            saveMessages()
        }

        Task {
            await sendToAI(message.content, userMessageId: message.id)
        }
    }

    // MARK: - Send Voice Message

    func sendVoiceMessage(audioURL: URL) async {
        // Increment local counter immediately and persist
        if !SubscriptionManager.shared.isProUser {
            freeVoiceMessagesUsed += 1
            store?.user?.freeVoiceMessagesUsed = freeVoiceMessagesUsed
            UserDefaults.standard.set(freeVoiceMessagesUsed, forKey: "freeVoiceMessagesUsed")
        }

        // Get audio duration
        let duration = getAudioDuration(url: audioURL)

        // Copy to permanent local storage for replay
        let permanentURL = copyToPermanentStorage(audioURL)

        // Add voice message to UI immediately
        let voiceMessage = SimpleChatMessage(
            content: "🎤 Message vocal",
            isFromUser: true,
            type: .voice,
            voiceDuration: duration,
            voiceURL: permanentURL,
            storagePath: nil,
            status: .sending
        )
        messages.append(voiceMessage)
        saveMessages()

        isLoading = true

        // Upload to Supabase Storage in background
        if let userId = AuthService.shared.userId {
            do {
                let audioData = try Data(contentsOf: permanentURL)
                let storagePath = try await SupabaseStorageService.shared.uploadVoiceMessage(
                    audioData: audioData,
                    userId: userId
                )
                print("✅ Voice uploaded to Supabase: \(storagePath)")
                // Update message with storage path
                if let index = messages.lastIndex(where: { $0.id == voiceMessage.id }) {
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
            } catch {
                print("⚠️ Supabase upload failed (local backup exists): \(error)")
                // Mark message status so user knows upload didn't persist
                if let index = messages.lastIndex(where: { $0.id == voiceMessage.id }) {
                    messages[index].status = .failed
                }
            }
        }

        // Client-side STT transcription
        let transcript = await transcribeAudio(url: permanentURL)

        // Update voice message with transcript
        if let index = messages.lastIndex(where: { $0.id == voiceMessage.id }), let transcript, !transcript.isEmpty {
            messages[index] = SimpleChatMessage(
                id: voiceMessage.id,
                content: transcript,
                isFromUser: true,
                timestamp: voiceMessage.timestamp,
                type: .voice,
                voiceDuration: duration,
                voiceURL: permanentURL,
                storagePath: messages[index].voiceStoragePath
            )
            saveMessages()
        }

        // Send transcribed text (or fallback) to Backboard
        let textToSend = transcript ?? "Message vocal"
        do {
            let (reply, sideEffects) = try await BackboardService.shared.sendMessage(textToSend)

            // Mark voice message as sent
            if let index = messages.lastIndex(where: { $0.id == voiceMessage.id }) {
                messages[index].status = .sent
            }

            await applySideEffects(sideEffects)

            var aiMessage = SimpleChatMessage(content: reply, isFromUser: false)
            if sideEffects.firstStartFocusSession != nil || sideEffects.hasBlockApps {
                aiMessage.cardData = await buildFocusPlanningCard(sideEffects: sideEffects)
            } else if let video = sideEffects.firstShowVideo {
                aiMessage.cardData = makeVideoCard(url: video.url, title: video.title)
            } else if let category = sideEffects.firstShowVideoSuggestions {
                aiMessage.cardData = makeVideoSuggestionsCard(for: category)
            } else if let cardType = sideEffects.firstShowCard {
                aiMessage.cardData = await buildCardData(for: cardType)
            } else if let cardType = detectCardFromReply(reply) {
                aiMessage.cardData = await buildCardData(for: cardType)
            }

            messages.append(aiMessage)
            saveMessages()
        } catch {
            // Mark voice message as failed
            if let index = messages.lastIndex(where: { $0.id == voiceMessage.id }) {
                messages[index].status = .failed
            }
            saveMessages()
            print("Voice message error: \(error)")
        }

        isLoading = false

        // Clean up temporary recording file
        try? FileManager.default.removeItem(at: audioURL)
    }

    /// Client-side speech-to-text using SFSpeechRecognizer
    private func transcribeAudio(url: URL) async -> String? {
        await withCheckedContinuation { continuation in
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
            guard let recognizer, recognizer.isAvailable else {
                continuation.resume(returning: nil)
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false

            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if error != nil {
                    continuation.resume(returning: nil)
                }
            }
        }
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


    // MARK: - Send to AI (text) via Backboard

    private func sendToAI(_ text: String, userMessageId: UUID? = nil) async {
        isLoading = true

        do {
            let (reply, sideEffects) = try await BackboardService.shared.sendMessage(text)
            print("💬 Backboard response — sideEffects: \(sideEffects.count), reply: \(reply.prefix(50))")

            // Mark user message as sent
            if let msgId = userMessageId, let index = messages.firstIndex(where: { $0.id == msgId }) {
                messages[index].status = .sent
            }

            // Apply side effects (refresh store, handle app blocking, etc.)
            await applySideEffects(sideEffects)

            // Add AI response
            var aiMessage = SimpleChatMessage(content: reply, isFromUser: false)

            // Attach card data if a video, show_card, or focus tool was called
            for (i, effect) in sideEffects.enumerated() {
                print("📋 sideEffect[\(i)]: \(effect)")
            }

            if sideEffects.firstStartFocusSession != nil || sideEffects.hasBlockApps {
                aiMessage.cardData = await buildFocusPlanningCard(sideEffects: sideEffects)
            } else if let video = sideEffects.firstShowVideo {
                aiMessage.cardData = makeVideoCard(url: video.url, title: video.title)
            } else if let category = sideEffects.firstShowVideoSuggestions {
                aiMessage.cardData = makeVideoSuggestionsCard(for: category)
            } else if let cardType = sideEffects.firstShowCard {
                aiMessage.cardData = await buildCardData(for: cardType)
            } else if let cardType = detectCardFromReply(reply) {
                aiMessage.cardData = await buildCardData(for: cardType)
            }

            messages.append(aiMessage)
            saveMessages()

        } catch {
            // Mark user message as failed
            if let msgId = userMessageId, let index = messages.firstIndex(where: { $0.id == msgId }) {
                messages[index].status = .failed
                saveMessages()
            }

            print("Chat AI error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Apply Side Effects from Backboard Tool Calls

    private func applySideEffects(_ effects: [BackboardSideEffect]) async {
        for effect in effects {
            switch effect {
            case .refreshTasks:
                await store?.refreshTodaysTasks()

            case .calendarNeedsRefresh:
                NotificationCenter.default.post(name: .calendarNeedsRefresh, object: nil)

            case .refreshRituals:
                await store?.loadRituals()

            case .refreshReflection:
                await store?.loadTodayReflection()

            case .refreshWeeklyGoals:
                await store?.loadWeeklyGoals()

            case .blockApps(let duration):
                let blocker = ScreenTimeAppBlockerService.shared
                if blocker.isBlockingEnabled {
                    blocker.startBlocking(durationMinutes: duration)
                } else if blocker.authorizationStatus != .approved {
                    let granted = await blocker.requestAuthorization()
                    if granted {
                        if blocker.hasSelectedApps {
                            blocker.startBlocking(durationMinutes: duration)
                        } else {
                            appendAppBlockerPrompt("J'ai bien l'autorisation ! Maintenant, choisis les apps que tu veux bloquer.")
                        }
                    } else {
                        appendAppBlockerPrompt("J'ai besoin de l'autorisation Screen Time pour bloquer tes apps. Clique ci-dessous pour configurer.")
                    }
                } else {
                    appendAppBlockerPrompt("Tu n'as pas encore choisi d'apps à bloquer. Sélectionne-les ici :")
                }

            case .unblockApps:
                let blocker = ScreenTimeAppBlockerService.shared
                if blocker.isBlocking {
                    blocker.stopBlocking()
                }

            case .showForceUnblockCard:
                appendForceUnblockCard()

            case .showCard:
                break // Handled in the message attachment step

            case .showVideo:
                break // Handled in the message attachment step

            case .showVideoSuggestions:
                break // Handled in the message attachment step

            case .startFocusSession:
                break // Handled inline via planning card focus state

            case .refreshSettings:
                break // Settings UI observes MorningBlockService.shared directly

            case .refreshCalendarEvents:
                let manager = CalendarProviderManager.shared
                await manager.fetchEvents()
                let blockingEvents = manager.todayEvents.filter { $0.blockApps }
                await CalendarEventBlockingService.shared.scheduleBlockingForEvents(blockingEvents)
            }
        }
    }

    // MARK: - YouTube Helpers

    private func extractYouTubeId(from url: String) -> String? {
        // youtube.com/watch?v=ID
        if let components = URLComponents(string: url),
           let vItem = components.queryItems?.first(where: { $0.name == "v" }),
           let videoId = vItem.value, !videoId.isEmpty {
            return videoId
        }
        // youtu.be/ID
        if let parsed = URL(string: url), parsed.host == "youtu.be" || parsed.host == "www.youtu.be" {
            let id = parsed.lastPathComponent
            if !id.isEmpty && id != "/" { return id }
        }
        // youtube.com/embed/ID
        if let parsed = URL(string: url),
           let embedIndex = parsed.pathComponents.firstIndex(of: "embed"),
           embedIndex + 1 < parsed.pathComponents.count {
            return parsed.pathComponents[embedIndex + 1]
        }
        return nil
    }

    private func makeVideoCard(url: String, title: String) -> ChatCardData {
        let videoId = extractYouTubeId(from: url) ?? ""
        return .videoCard(ChatCardData.VideoCard(
            url: url, videoId: videoId, title: title, isCompleted: false
        ))
    }

    private func makeVideoSuggestionsCard(for category: String) -> ChatCardData {
        let videos = BackboardService.curatedVideos[category] ?? BackboardService.curatedVideos["meditation"]!
        let suggestions = videos.map { video in
            ChatCardData.VideoSuggestion(
                videoId: video.videoId,
                title: video.title,
                duration: video.duration
            )
        }
        return .videoSuggestions(ChatCardData.VideoSuggestionsData(
            category: category,
            videos: suggestions
        ))
    }

    func selectSuggestedVideo(messageId: UUID, video: ChatCardData.VideoSuggestion) {
        let url = "https://www.youtube.com/watch?v=\(video.videoId)"

        // Save as favorite video
        UserDefaults.standard.set(url, forKey: "favorite_video_url")
        UserDefaults.standard.set(video.title, forKey: "favorite_video_title")
        FocusAppStore.shared.user?.favoriteVideoUrl = url
        FocusAppStore.shared.user?.favoriteVideoTitle = video.title

        // Transform the suggestions card into a video player card
        if let msgIndex = messages.firstIndex(where: { $0.id == messageId }) {
            messages[msgIndex].cardData = makeVideoCard(url: url, title: video.title)
            saveMessages()
        }

        // Send confirmation to Kai
        let userMsg = SimpleChatMessage(content: "J'ai choisi cette vidéo : \(video.title)", isFromUser: true)
        messages.append(userMsg)
        saveMessages()

        Task {
            // Also save to Backboard memory
            try? await BackboardService.shared.addMemory(content: "Vidéo favorite de l'utilisateur pour rituel quotidien: \(video.title) - \(url)")
            await sendToAI("J'ai choisi cette vidéo : \(video.title)", userMessageId: userMsg.id)
        }
    }

    func videoCompleted(messageId: UUID) {
        guard let msgIndex = messages.firstIndex(where: { $0.id == messageId }) else { return }
        if case .videoCard(var video) = messages[msgIndex].cardData {
            video.isCompleted = true
            messages[msgIndex].cardData = .videoCard(video)
            saveMessages()

            let userMsg = SimpleChatMessage(content: "J'ai fini de regarder ma vidéo ✅", isFromUser: true)
            messages.append(userMsg)
            saveMessages()

            Task {
                await sendToAI("J'ai fini de regarder ma vidéo : \(video.title)", userMessageId: userMsg.id)
            }
        }
    }

    // MARK: - Card Detection from Reply Text

    private func detectCardFromReply(_ reply: String) -> String? {
        let lower = reply.lowercased()

        let taskPatterns = ["voici tes tâches", "voici tes taches", "ton planning", "ta journée",
                            "tes tâches du jour", "voici ton programme", "voici ta journée",
                            "voici ton planning", "prévues pour", "tes tâches", "tes taches"]
        for pattern in taskPatterns {
            if lower.contains(pattern) { return "tasks" }
        }

        let routinePatterns = ["voici tes rituel", "tes routine", "tes habitude", "voici tes habitude"]
        for pattern in routinePatterns {
            if lower.contains(pattern) { return "routines" }
        }

        return nil
    }

    /// Append a message with a button to open app blocker settings
    private func appendAppBlockerPrompt(_ text: String) {
        var msg = SimpleChatMessage(content: text, isFromUser: false)
        msg.cardData = .actionButton(ChatCardData.ActionButton(
            title: "Sélectionner les apps à bloquer",
            icon: "shield.lefthalf.filled",
            deepLink: "openAppBlockerSettings"
        ))
        messages.append(msg)
        saveMessages()
    }

    /// Append a card with a force-unblock button when user insists apps are still blocked
    private func appendForceUnblockCard() {
        var msg = SimpleChatMessage(content: "Clique ici pour forcer le déblocage de tes apps :", isFromUser: false)
        msg.cardData = .actionButton(ChatCardData.ActionButton(
            title: "Débloquer mes apps",
            icon: "lock.open.fill",
            deepLink: "forceUnblockApps"
        ))
        messages.append(msg)
        saveMessages()
    }

    private func generateFallbackResponse() -> String {
        let responses = [
            "Problème technique de mon côté. Réessaie.",
            "J'ai eu un bug. Renvoie ton message.",
            "Souci de connexion. Dis-moi ça encore une fois."
        ]
        return responses.randomElement() ?? "Réessaie dans quelques secondes."
    }

    // MARK: - Card Data

    private func buildCardData(for cardType: String) async -> ChatCardData? {
        guard let store = store else {
            print("⚠️ buildCardData: store is nil")
            return nil
        }

        print("🃏 buildCardData: building card for type '\(cardType)'")

        switch cardType {
        case "tasks":
            await store.refreshTodaysTasks()
            await store.loadRituals()
            print("🃏 buildCardData: loaded \(store.todaysTasks.count) tasks + \(store.rituals.count) routines")
            let taskCards = store.todaysTasks.map { task in
                ChatCardData.CardTask(
                    id: task.id,
                    title: task.title,
                    isCompleted: task.status == "completed",
                    estimatedMinutes: task.estimatedMinutes
                )
            }
            let routineCards = store.rituals.map { ritual in
                ChatCardData.CardRoutine(
                    id: ritual.id,
                    title: ritual.title,
                    icon: ritual.icon,
                    isCompleted: ritual.isCompleted
                )
            }
            return .planning(taskCards, routineCards, nil)

        case "routines":
            await store.loadRituals()
            let cards = store.rituals.map { ritual in
                ChatCardData.CardRoutine(
                    id: ritual.id,
                    title: ritual.title,
                    icon: ritual.icon,
                    isCompleted: ritual.isCompleted
                )
            }
            return .routineList(cards)

        default:
            return nil
        }
    }

    /// Build a planning card with focus state attached (for start_focus_session / block_apps)
    private func buildFocusPlanningCard(sideEffects: [BackboardSideEffect]) async -> ChatCardData? {
        guard let store = store else { return nil }

        let focusSession = sideEffects.firstStartFocusSession
        let duration = focusSession?.duration ?? sideEffects.blockAppsDuration ?? 25

        await store.refreshTodaysTasks()
        await store.loadRituals()

        let taskCards = store.todaysTasks.map { task in
            ChatCardData.CardTask(
                id: task.id,
                title: task.title,
                isCompleted: task.status == "completed",
                estimatedMinutes: task.estimatedMinutes
            )
        }
        let routineCards = store.rituals.map { ritual in
            ChatCardData.CardRoutine(
                id: ritual.id,
                title: ritual.title,
                icon: ritual.icon,
                isCompleted: ritual.isCompleted
            )
        }

        let focusState = ChatCardData.PlanningFocusState(
            activeTaskId: focusSession?.taskId,
            activeTaskTitle: focusSession?.taskTitle,
            duration: duration,
            timeRemaining: duration * 60,
            sessionId: nil,
            timerState: .idle
        )

        print("🎯 Attaching planning card with focus state: duration=\(duration), taskId=\(focusSession?.taskId ?? "nil")")
        return .planning(taskCards, routineCards, focusState)
    }

    func toggleTaskCompletion(messageId: UUID, taskId: String) {
        guard let msgIndex = messages.firstIndex(where: { $0.id == messageId }) else { return }

        var wasCompleted = false
        var taskTitle = ""
        switch messages[msgIndex].cardData {
        case .taskList(var tasks):
            guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
            wasCompleted = tasks[taskIndex].isCompleted
            taskTitle = tasks[taskIndex].title
            tasks[taskIndex].isCompleted = !wasCompleted
            messages[msgIndex].cardData = .taskList(tasks)
        case .planning(var tasks, let routines, let focusState):
            guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
            wasCompleted = tasks[taskIndex].isCompleted
            taskTitle = tasks[taskIndex].title
            tasks[taskIndex].isCompleted = !wasCompleted
            messages[msgIndex].cardData = .planning(tasks, routines, focusState)
        default:
            return
        }
        saveMessages()
        adjustSatisfaction(completed: !wasCompleted)

        Task {
            do {
                if wasCompleted {
                    try await apiClient.request(
                        endpoint: .uncompleteCalendarTask(taskId),
                        method: .post
                    )
                } else {
                    try await apiClient.request(
                        endpoint: .completeCalendarTask(taskId),
                        method: .post
                    )
                    // Notify coach about task completion
                    await requestCompletionReaction(itemName: taskTitle, isTask: true)
                }
                NotificationCenter.default.post(name: .calendarNeedsRefresh, object: nil)
            } catch {
                print("Failed to toggle task: \(error)")
            }
        }
    }

    func toggleRoutineCompletion(messageId: UUID, routineId: String) {
        guard let msgIndex = messages.firstIndex(where: { $0.id == messageId }) else { return }

        var wasCompleted = false
        var routineTitle = ""
        switch messages[msgIndex].cardData {
        case .routineList(var routines):
            guard let routineIndex = routines.firstIndex(where: { $0.id == routineId }) else { return }
            wasCompleted = routines[routineIndex].isCompleted
            routineTitle = routines[routineIndex].title
            routines[routineIndex].isCompleted = !wasCompleted
            messages[msgIndex].cardData = .routineList(routines)
        case .planning(let tasks, var routines, let focusState):
            guard let routineIndex = routines.firstIndex(where: { $0.id == routineId }) else { return }
            wasCompleted = routines[routineIndex].isCompleted
            routineTitle = routines[routineIndex].title
            routines[routineIndex].isCompleted = !wasCompleted
            messages[msgIndex].cardData = .planning(tasks, routines, focusState)
        default:
            return
        }
        saveMessages()
        adjustSatisfaction(completed: !wasCompleted)

        Task {
            do {
                if wasCompleted {
                    try await apiClient.request(
                        endpoint: .uncompleteRoutine(routineId),
                        method: .delete
                    )
                } else {
                    try await apiClient.request(
                        endpoint: .completeRoutine(routineId),
                        method: .post
                    )
                    // Notify coach about routine completion
                    await requestCompletionReaction(itemName: routineTitle, isTask: false)
                }
                await store?.loadRituals()
            } catch {
                print("Failed to toggle routine: \(error)")
            }
        }
    }

    // MARK: - Inline Focus Timer (integrated in Planning Card)

    private var focusTimer: Timer?
    private(set) var focusTimerMessageId: UUID?
    private var focusTimerStartTime: Date?
    private var focusTimerPausedRemaining: Int?

    /// Select a task for focus within the planning card
    func selectTaskForFocus(messageId: UUID, taskId: String, taskTitle: String) {
        updatePlanningFocusState(messageId: messageId) { state in
            state.activeTaskId = taskId
            state.activeTaskTitle = taskTitle
        }
    }

    /// Update selected duration for focus
    func updateFocusDuration(messageId: UUID, duration: Int) {
        updatePlanningFocusState(messageId: messageId) { state in
            state.duration = duration
            state.timeRemaining = duration * 60
        }
    }

    /// Start the inline focus timer on a specific planning card
    func startInlineFocusTimer(messageId: UUID, taskId: String?, taskTitle: String?, duration: Int) {
        focusTimerMessageId = messageId
        focusTimerStartTime = Date()

        HapticFeedback.medium()

        // Start app blocking if enabled
        let blocker = ScreenTimeAppBlockerService.shared
        if blocker.isBlockingEnabled {
            blocker.startBlocking(durationMinutes: duration)
        }

        // Create session in backend
        Task {
            do {
                let session = try await FocusAppStore.shared.startSession(
                    durationMinutes: duration,
                    taskId: taskId,
                    description: taskTitle
                )
                updatePlanningFocusState(messageId: messageId) { state in
                    state.sessionId = session.id
                }
            } catch {
                print("❌ Inline timer: failed to create session: \(error)")
            }
        }

        // Start Live Activity
        LiveActivityManager.shared.startLiveActivity(
            sessionId: UUID().uuidString,
            totalDuration: duration,
            description: taskTitle,
            sessionTitle: nil,
            sessionEmoji: nil
        )

        // Update widget
        FocusAppStore.shared.startWidgetSession(
            durationMinutes: duration,
            emoji: nil,
            description: taskTitle
        )

        // Update card state to running
        updatePlanningFocusState(messageId: messageId) { state in
            state.timerState = .running
            state.timeRemaining = duration * 60
            state.activeTaskId = taskId
            state.activeTaskTitle = taskTitle
            state.duration = duration
        }

        // Start timer loop
        focusTimer?.invalidate()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.focusTimerTick()
            }
        }
    }

    func pauseInlineFocusTimer(messageId: UUID) {
        focusTimer?.invalidate()
        focusTimer = nil
        HapticFeedback.light()

        updatePlanningFocusState(messageId: messageId) { state in
            state.timerState = .paused
        }

        if let remaining = currentPlanningFocusState(messageId: messageId)?.timeRemaining {
            focusTimerPausedRemaining = remaining
            LiveActivityManager.shared.updateLiveActivity(
                timeRemaining: remaining,
                progress: timerProgress(for: messageId),
                isPaused: true
            )
        }
    }

    func resumeInlineFocusTimer(messageId: UUID) {
        HapticFeedback.light()

        updatePlanningFocusState(messageId: messageId) { state in
            state.timerState = .running
        }

        if let remaining = currentPlanningFocusState(messageId: messageId)?.timeRemaining {
            LiveActivityManager.shared.updateLiveActivity(
                timeRemaining: remaining,
                progress: timerProgress(for: messageId),
                isPaused: false
            )
        }

        // Restart timer loop
        focusTimer?.invalidate()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.focusTimerTick()
            }
        }
    }

    func stopInlineFocusTimer(messageId: UUID) {
        focusTimer?.invalidate()
        focusTimer = nil

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Stop blocking
        let blocker = ScreenTimeAppBlockerService.shared
        if blocker.isBlocking {
            blocker.stopBlocking()
        }

        // End Live Activity + widget
        LiveActivityManager.shared.endLiveActivity(completed: false)
        FocusAppStore.shared.endWidgetSession()

        // Cancel session in backend
        if let sessionId = currentPlanningFocusState(messageId: messageId)?.sessionId {
            Task {
                try? await FocusAppStore.shared.cancelSession(sessionId: sessionId)
                FocusAppStore.shared.syncWidgetData()
            }
        }

        // Reset focus state to idle
        updatePlanningFocusState(messageId: messageId) { state in
            state.timerState = .idle
            state.timeRemaining = state.duration * 60
            state.sessionId = nil
        }
        focusTimerMessageId = nil
        focusTimerStartTime = nil
        saveMessages()
    }

    private func completeFocusTimer(messageId: UUID) {
        focusTimer?.invalidate()
        focusTimer = nil

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Stop blocking
        let blocker = ScreenTimeAppBlockerService.shared
        if blocker.isBlocking {
            blocker.stopBlocking()
        }

        // End Live Activity + widget
        LiveActivityManager.shared.endLiveActivity(completed: true)
        FocusAppStore.shared.endWidgetSession()

        // Complete session in backend
        if let sessionId = currentPlanningFocusState(messageId: messageId)?.sessionId {
            Task {
                try? await FocusAppStore.shared.completeSession(sessionId: sessionId)
                FocusAppStore.shared.syncWidgetData()
            }
        }

        // Update card to completed
        updatePlanningFocusState(messageId: messageId) { state in
            state.timerState = .completed
            state.timeRemaining = 0
        }
        focusTimerStartTime = nil
        saveMessages()
    }

    /// Validate the linked task after focus completion
    func validateFocusTimerTask(messageId: UUID, completed: Bool) {
        guard let state = currentPlanningFocusState(messageId: messageId),
              let taskId = state.activeTaskId, completed else {
            // Reset focus state and clear it
            resetPlanningFocusState(messageId: messageId)
            return
        }

        Task {
            do {
                try await FocusAppStore.shared.toggleTask(taskId: taskId, completed: true)
                NotificationCenter.default.post(name: .calendarNeedsRefresh, object: nil)

                // Also mark the task as completed in the planning card (preserve focusState)
                if let msgIndex = messages.firstIndex(where: { $0.id == messageId }),
                   case .planning(var tasks, let routines, let focusState) = messages[msgIndex].cardData {
                    if let taskIdx = tasks.firstIndex(where: { $0.id == taskId }) {
                        tasks[taskIdx].isCompleted = true
                    }
                    messages[msgIndex].cardData = .planning(tasks, routines, focusState)
                }
            } catch {
                print("❌ Failed to validate task: \(error)")
                resetPlanningFocusState(messageId: messageId)
            }
            saveMessages()
        }
    }

    private func resetPlanningFocusState(messageId: UUID) {
        // Clear focus state entirely (back to normal planning card)
        if let msgIndex = messages.firstIndex(where: { $0.id == messageId }),
           case .planning(let tasks, let routines, _) = messages[msgIndex].cardData {
            messages[msgIndex].cardData = .planning(tasks, routines, nil)
        }
        focusTimerMessageId = nil
        saveMessages()
    }

    private func focusTimerTick() {
        guard let messageId = focusTimerMessageId,
              let state = currentPlanningFocusState(messageId: messageId),
              state.timerState == .running,
              let remaining = state.timeRemaining, remaining > 0 else { return }

        let newRemaining = remaining - 1
        updatePlanningFocusState(messageId: messageId) { state in
            state.timeRemaining = newRemaining
        }

        // Update Live Activity every 5 seconds
        if newRemaining % 5 == 0 {
            LiveActivityManager.shared.updateLiveActivity(
                timeRemaining: newRemaining,
                progress: timerProgress(for: messageId),
                isPaused: false
            )
        }

        if newRemaining == 0 {
            completeFocusTimer(messageId: messageId)
        }
    }

    private func updatePlanningFocusState(messageId: UUID, mutate: (inout ChatCardData.PlanningFocusState) -> Void) {
        guard let msgIndex = messages.firstIndex(where: { $0.id == messageId }),
              case .planning(let tasks, let routines, var focusState) = messages[msgIndex].cardData,
              var state = focusState else { return }
        mutate(&state)
        messages[msgIndex].cardData = .planning(tasks, routines, state)
    }

    private func currentPlanningFocusState(messageId: UUID) -> ChatCardData.PlanningFocusState? {
        guard let msgIndex = messages.firstIndex(where: { $0.id == messageId }),
              case .planning(_, _, let focusState) = messages[msgIndex].cardData else { return nil }
        return focusState
    }

    private func timerProgress(for messageId: UUID) -> Double {
        guard let state = currentPlanningFocusState(messageId: messageId) else { return 0 }
        let totalSeconds = state.duration * 60
        guard totalSeconds > 0, let remaining = state.timeRemaining else { return 0 }
        return 1.0 - (Double(remaining) / Double(totalSeconds))
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Persistence

    func saveMessages() {
        SimpleChatPersistence.saveMessages(messages)
    }

    // MARK: - Clear Chat

    func clearChat() {
        messages = []
        SimpleChatPersistence.clearMessages()

        // Delete Backboard thread and create a new one
        Task {
            await BackboardService.shared.deleteThread()
            _ = try? await BackboardService.shared.createNewThread()
        }
    }

}

// MARK: - BackboardSideEffect Helpers

extension Array where Element == BackboardSideEffect {
    /// Extract the first show_card type from side effects
    var firstShowCard: String? {
        for effect in self {
            if case .showCard(let cardType) = effect {
                return cardType
            }
        }
        return nil
    }

    /// Extract the first show_video from side effects
    var firstShowVideo: (url: String, title: String)? {
        for effect in self {
            if case .showVideo(let url, let title) = effect {
                return (url, title)
            }
        }
        return nil
    }

    /// Extract the first show_video_suggestions category from side effects
    var firstShowVideoSuggestions: String? {
        for effect in self {
            if case .showVideoSuggestions(let category) = effect {
                return category
            }
        }
        return nil
    }

    /// Extract the first start_focus_session from side effects
    var firstStartFocusSession: (duration: Int?, taskId: String?, taskTitle: String?)? {
        for effect in self {
            if case .startFocusSession(let duration, let taskId, let taskTitle) = effect {
                return (duration, taskId, taskTitle)
            }
        }
        return nil
    }

    /// Check if block_apps was called
    var hasBlockApps: Bool {
        contains { if case .blockApps = $0 { return true }; return false }
    }

    /// Get the block_apps duration
    var blockAppsDuration: Int? {
        for effect in self {
            if case .blockApps(let duration) = effect { return duration }
        }
        return nil
    }
}

// MARK: - Simple Chat Persistence (v3 - with voice support)

enum SimpleChatPersistence {
    private static let key = "chat_messages_v3"
    private static let maxMessages = 200

    static func saveMessages(_ messages: [SimpleChatMessage]) {
        // Keep only the most recent messages to prevent UserDefaults bloat
        let trimmed = messages.count > maxMessages ? Array(messages.suffix(maxMessages)) : messages
        if let data = try? JSONEncoder().encode(trimmed) {
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
