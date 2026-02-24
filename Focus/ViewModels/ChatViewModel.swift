import Foundation
import SwiftUI
import Combine

// MARK: - Notification for calendar refresh
extension Notification.Name {
    static let calendarNeedsRefresh = Notification.Name("calendarNeedsRefresh")
    static let openAppBlockerSettings = Notification.Name("openAppBlockerSettings")
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
    case questList([CardQuest])
    case planning([CardTask], [CardRoutine])
    case actionButton(ActionButton)

    struct CardTask: Codable, Identifiable {
        let id: String
        let title: String
        var isCompleted: Bool
    }

    struct CardRoutine: Codable, Identifiable {
        let id: String
        let title: String
        let icon: String
        var isCompleted: Bool
    }

    struct CardQuest: Codable, Identifiable {
        let id: String
        let title: String
        let emoji: String
        let progress: Double // 0.0 to 1.0
    }

    struct ActionButton: Codable {
        let title: String
        let icon: String
        let deepLink: String
    }
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
        return msg
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
    @Published var satisfactionScore: Int = UserDefaults.standard.object(forKey: "satisfaction_score") as? Int ?? 50
    @Published var freeVoiceMessagesUsed: Int = FocusAppStore.shared.user?.freeVoiceMessagesUsed ?? 0

    var canSendFreeVoice: Bool {
        SubscriptionManager.shared.isProUser || freeVoiceMessagesUsed < 3
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
            let response: AIResponse = try await apiClient.request(
                endpoint: .chatMessage,
                method: .post,
                body: SimpleChatRequest(content: "__greeting__", source: "app", appsBlocked: false, stepsToday: nil, distractionCount: nil)
            )

            updateSatisfactionScore(response.satisfactionScore)

            let aiMessage = SimpleChatMessage(content: response.reply, isFromUser: false)
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

    /// Request a daily greeting from the backend AI (contextual, never the same)
    private func requestDailyGreeting() async {
        isLoading = true

        do {
            let isBlocking = ScreenTimeAppBlockerService.shared.isBlocking
            let steps = await HealthKitService.shared.fetchTodaySteps()
            let response: AIResponse = try await apiClient.request(
                endpoint: .chatMessage,
                method: .post,
                body: SimpleChatRequest(content: "__daily_greeting__", source: "app", appsBlocked: isBlocking, stepsToday: steps, distractionCount: DistractionMonitorService.shared.todayDistractionCount)
            )

            updateSatisfactionScore(response.satisfactionScore)

            let aiMessage = SimpleChatMessage(content: response.reply, isFromUser: false)
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

    /// Generate a varied local greeting as fallback when the backend is unreachable
    private func generateLocalDailyGreeting() -> String {
        let userName = store?.user?.pseudo ?? store?.user?.firstName ?? ""
        let name = userName.isEmpty ? "" : " \(userName)"
        let streak = store?.currentStreak ?? 0
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
            if streak > 3 {
                pool.append("\(streak) jours d'affilée\(name). On lâche rien.")
            }
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
        // Increment local counter immediately (server will confirm)
        if !SubscriptionManager.shared.isProUser {
            freeVoiceMessagesUsed += 1
        }

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
            print("🎤 Voice response — showCard: \(response.showCard ?? "nil"), action: \(response.action?.type ?? "nil"), reply: \(response.reply.prefix(50))")

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

            updateSatisfactionScore(response.satisfactionScore)

            // Update free voice messages counter from server response
            if let count = response.freeVoiceMessagesUsed {
                freeVoiceMessagesUsed = count
                FocusAppStore.shared.user?.freeVoiceMessagesUsed = count
            }

            // Handle coach actions FIRST (creates tasks/routines/quests)
            if let action = response.action {
                await handleCoachAction(action)
            }

            // Add AI response
            var aiMessage = SimpleChatMessage(content: response.reply, isFromUser: false)

            // Attach card data if backend requests it, or infer from action/reply
            var showCard = response.showCard
            if showCard == nil, let action = response.action {
                if ["task_created", "task_completed"].contains(action.type) {
                    showCard = "tasks"
                } else if ["routine_created", "routines_created", "routines_completed"].contains(action.type) {
                    showCard = "routines"
                } else if ["quest_created", "quests_created", "quest_updated"].contains(action.type) {
                    showCard = "quests"
                }
            }
            // Client-side fallback: detect from reply text
            if showCard == nil {
                showCard = detectCardFromReply(response.reply)
            }
            if let showCard {
                aiMessage.cardData = await buildCardData(for: showCard)
            }

            messages.append(aiMessage)
            saveMessages()

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
            let steps = await HealthKitService.shared.fetchTodaySteps()
            let response: AIResponse = try await apiClient.request(
                endpoint: .chatMessage,
                method: .post,
                body: SimpleChatRequest(content: text, source: "app", appsBlocked: isBlocking, stepsToday: steps, distractionCount: DistractionMonitorService.shared.todayDistractionCount)
            )

            updateSatisfactionScore(response.satisfactionScore)
            print("💬 AI response — showCard: \(response.showCard ?? "nil"), action: \(response.action?.type ?? "nil"), reply: \(response.reply.prefix(50))")

            // Handle actions from the coach FIRST (creates tasks/routines/quests)
            if let action = response.action {
                await handleCoachAction(action)
            }

            // Add AI response
            var aiMessage = SimpleChatMessage(content: response.reply, isFromUser: false)

            // Attach card data if backend requests it, or infer from action/reply
            var showCard = response.showCard
            if showCard == nil, let action = response.action {
                if ["task_created", "task_completed"].contains(action.type) {
                    showCard = "tasks"
                } else if ["routine_created", "routines_created", "routines_completed"].contains(action.type) {
                    showCard = "routines"
                } else if ["quest_created", "quests_created", "quest_updated"].contains(action.type) {
                    showCard = "quests"
                }
            }
            // Client-side fallback: detect from reply text
            if showCard == nil {
                showCard = detectCardFromReply(response.reply)
            }
            if let showCard {
                aiMessage.cardData = await buildCardData(for: showCard)
            }

            messages.append(aiMessage)
            saveMessages()

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
            await store?.refreshTodaysTasks()
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
            print("🔒 Coach triggered app blocking (duration: \(action.durationMinutes ?? 0) min)")
            let blocker = ScreenTimeAppBlockerService.shared
            if blocker.isBlockingEnabled {
                blocker.startBlocking(durationMinutes: action.durationMinutes)
            } else if blocker.authorizationStatus != .approved {
                print("⚠️ ScreenTime not authorized — requesting")
                let granted = await blocker.requestAuthorization()
                if granted {
                    if blocker.hasSelectedApps {
                        blocker.startBlocking(durationMinutes: action.durationMinutes)
                    } else {
                        appendAppBlockerPrompt("J'ai bien l'autorisation ! Maintenant, choisis les apps que tu veux bloquer.")
                    }
                } else {
                    appendAppBlockerPrompt("J'ai besoin de l'autorisation Screen Time pour bloquer tes apps. Clique ci-dessous pour configurer.")
                }
            } else {
                // Authorized but no apps selected
                appendAppBlockerPrompt("Tu n'as pas encore choisi d'apps à bloquer. Sélectionne-les ici :")
            }

        case "unblock_apps":
            print("🔓 Coach approved app unblocking")
            let blocker = ScreenTimeAppBlockerService.shared
            if blocker.isBlocking {
                blocker.stopBlocking()
            }

        case "task_completed":
            print("✅ Coach completed a task")
            await store?.refreshTodaysTasks()
            NotificationCenter.default.post(name: .calendarNeedsRefresh, object: nil)

        case "routines_completed":
            print("✅ Coach completed routine(s)")
            await store?.loadRituals()

        case "quest_deleted":
            print("🗑️ Coach deleted a quest")
            await store?.loadQuests()

        case "routine_deleted":
            print("🗑️ Coach deleted a routine")
            await store?.loadRituals()

        case "morning_checkin_saved":
            print("☀️ Morning check-in saved")
            await store?.loadTodayReflection()

        case "evening_checkin_saved":
            print("🌙 Evening check-in saved")
            await store?.loadTodayReflection()

        case "weekly_goals_created":
            print("🎯 Weekly goals created")
            await store?.loadWeeklyGoals()

        case "weekly_goal_completed":
            print("✅ Weekly goal completed")
            await store?.loadWeeklyGoals()

        case "journal_entry_created":
            print("📔 Journal entry created")

        default:
            break
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

        let questPatterns = ["voici tes objectif", "tes objectifs", "tes quests", "tes goals"]
        for pattern in questPatterns {
            if lower.contains(pattern) { return "quests" }
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
                    isCompleted: task.status == "completed"
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
            return .planning(taskCards, routineCards)

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

        case "quests":
            await store.loadQuests()
            print("🃏 buildCardData: loaded \(store.quests.count) quests (\(store.quests.filter { $0.status == .active }.count) active)")
            let cards = store.quests
                .filter { $0.status == .active }
                .map { quest in
                    ChatCardData.CardQuest(
                        id: quest.id,
                        title: quest.title,
                        emoji: quest.area.emoji,
                        progress: quest.progress
                    )
                }
            return .questList(cards)

        default:
            return nil
        }
    }

    func toggleTaskCompletion(messageId: UUID, taskId: String) {
        guard let msgIndex = messages.firstIndex(where: { $0.id == messageId }) else { return }

        var wasCompleted = false
        switch messages[msgIndex].cardData {
        case .taskList(var tasks):
            guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
            wasCompleted = tasks[taskIndex].isCompleted
            tasks[taskIndex].isCompleted = !wasCompleted
            messages[msgIndex].cardData = .taskList(tasks)
        case .planning(var tasks, let routines):
            guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
            wasCompleted = tasks[taskIndex].isCompleted
            tasks[taskIndex].isCompleted = !wasCompleted
            messages[msgIndex].cardData = .planning(tasks, routines)
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
        switch messages[msgIndex].cardData {
        case .routineList(var routines):
            guard let routineIndex = routines.firstIndex(where: { $0.id == routineId }) else { return }
            wasCompleted = routines[routineIndex].isCompleted
            routines[routineIndex].isCompleted = !wasCompleted
            messages[msgIndex].cardData = .routineList(routines)
        case .planning(let tasks, var routines):
            guard let routineIndex = routines.firstIndex(where: { $0.id == routineId }) else { return }
            wasCompleted = routines[routineIndex].isCompleted
            routines[routineIndex].isCompleted = !wasCompleted
            messages[msgIndex].cardData = .planning(tasks, routines)
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
                }
                await store?.loadRituals()
            } catch {
                print("Failed to toggle routine: \(error)")
            }
        }
    }

    // MARK: - Persistence

    func saveMessages() {
        SimpleChatPersistence.saveMessages(messages)
    }

    // MARK: - Clear Chat

    func clearChat() {
        messages = []
        SimpleChatPersistence.clearMessages()

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
    let stepsToday: Int?
    let distractionCount: Int?

    enum CodingKeys: String, CodingKey {
        case content, source
        case appsBlocked = "apps_blocked"
        case stepsToday = "steps_today"
        case distractionCount = "distraction_count"
    }
}

struct AIResponse: Decodable {
    let reply: String
    let tool: String?
    let messageId: String?
    let action: AIActionData?
    let showCard: String?
    let satisfactionScore: Int?
}

struct VoiceMessageResponse: Decodable {
    let reply: String
    let transcript: String?
    let messageId: String?
    let action: AIActionData?
    let showCard: String?
    let satisfactionScore: Int?
    let freeVoiceMessagesUsed: Int?
}

// Action taken by Kai (task created, focus scheduled, etc.)
struct AIActionData: Decodable {
    let type: String           // "task_created", "focus_scheduled", "block_apps"
    let taskId: String?
    let task: AITaskData?
    let durationMinutes: Int?
}

struct AITaskData: Decodable {
    let title: String
    let date: String
    let scheduledStart: String
    let scheduledEnd: String
    let blockApps: Bool
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
