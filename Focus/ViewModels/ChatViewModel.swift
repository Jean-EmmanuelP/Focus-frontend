import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var isRecording: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String?

    // Tool states
    @Published var showPlanDay: Bool = false
    @Published var showWeeklyGoals: Bool = false
    @Published var showDailyReflection: Bool = false
    @Published var showMoodPicker: Bool = false

    // MARK: - Services

    private let chatService = ChatAIService.shared
    private let voiceService = VoiceService()
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    // MARK: - Store Reference

    private weak var store: FocusAppStore?

    // MARK: - Initialization

    init() {
        loadMessages()
    }

    func setStore(_ store: FocusAppStore) {
        self.store = store
    }

    // MARK: - Load Messages

    func loadMessages() {
        messages = ChatPersistence.loadMessages()

        // If no messages, add welcome message
        if messages.isEmpty {
            addWelcomeMessage()
        }
    }

    private func addWelcomeMessage() {
        let context = buildContext()
        let greeting = chatService.generateGreeting(context: context)

        let welcomeMessage = ChatMessage(
            type: .text,
            content: greeting,
            isFromUser: false
        )
        messages.append(welcomeMessage)

        // Add quick action tool cards
        addQuickActionCards()

        saveMessages()
    }

    private func addQuickActionCards() {
        let context = buildContext()

        // Morning: suggest plan day
        if context.timeOfDay == .morning {
            let planCard = ChatMessage(
                type: .toolCard,
                content: "Prêt à organiser ta journée ?",
                isFromUser: false,
                toolAction: .planDay
            )
            messages.append(planCard)
        }

        // Evening: suggest reflection
        if context.timeOfDay == .evening || context.timeOfDay == .night {
            let reflectionCard = ChatMessage(
                type: .toolCard,
                content: "Prends un moment pour ta réflexion du jour",
                isFromUser: false,
                toolAction: .dailyReflection
            )
            messages.append(reflectionCard)
        }
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(
            type: .text,
            content: text,
            isFromUser: true
        )
        messages.append(userMessage)
        inputText = ""
        saveMessages()

        // Check for tool intent locally first
        if let tool = chatService.detectToolIntent(from: text) {
            handleToolAction(tool)
            return
        }

        // Send to AI
        Task {
            await sendToAI(text)
        }
    }

    private func sendToAI(_ text: String) async {
        isLoading = true

        do {
            let context = buildContext()
            let response = try await chatService.sendMessage(
                text,
                context: context,
                conversationHistory: messages
            )

            // Add AI response
            let aiMessage = ChatMessage(
                type: .text,
                content: response.reply,
                isFromUser: false,
                toolAction: response.tool
            )
            messages.append(aiMessage)

            // If AI suggests a tool, show it
            if let tool = response.tool {
                let toolCard = ChatMessage(
                    type: .toolCard,
                    content: tool.description,
                    isFromUser: false,
                    toolAction: tool
                )
                messages.append(toolCard)
            }

            saveMessages()
        } catch {
            // Fallback: generate local response
            let fallbackMessage = ChatMessage(
                type: .text,
                content: generateFallbackResponse(for: text),
                isFromUser: false
            )
            messages.append(fallbackMessage)
            saveMessages()

            print("Chat AI error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func generateFallbackResponse(for input: String) -> String {
        let context = buildContext()

        // Simple context-aware fallback responses
        if context.todayTasksCount > 0 {
            let completed = context.todayTasksCompleted
            let total = context.todayTasksCount
            if completed == total {
                return "T'as terminé toutes tes tâches. Bien joué. Qu'est-ce que tu veux faire maintenant ?"
            } else {
                return "T'as encore \(total - completed) tâches à faire aujourd'hui. Sur quoi tu veux te concentrer ?"
            }
        }

        return "Je t'écoute. Qu'est-ce que tu veux accomplir ?"
    }

    // MARK: - Tool Actions

    func handleToolAction(_ tool: ChatTool) {
        // Add acknowledgment message
        let ackMessage = ChatMessage(
            type: .text,
            content: getToolAcknowledgment(tool),
            isFromUser: false
        )
        messages.append(ackMessage)
        saveMessages()

        // Trigger the appropriate sheet/action
        switch tool {
        case .planDay:
            showPlanDay = true
        case .weeklyGoals:
            showWeeklyGoals = true
        case .dailyReflection:
            showDailyReflection = true
        case .startFocus:
            // Navigate to FireMode
            AppRouter.shared.navigateToFireMode()
        case .viewStats:
            // Navigate to profile stats
            AppRouter.shared.selectedTab = .profile
        case .logMood:
            showMoodPicker = true
        }
    }

    private func getToolAcknowledgment(_ tool: ChatTool) -> String {
        switch tool {
        case .planDay:
            return "Ok, organisons ta journée."
        case .weeklyGoals:
            return "Voyons tes objectifs de la semaine."
        case .dailyReflection:
            return "Prends ton temps pour ta réflexion."
        case .startFocus:
            return "C'est parti. Concentre-toi. 🔥"
        case .viewStats:
            return "Voilà ta progression."
        case .logMood:
            return "Comment tu te sens ?"
        }
    }

    // MARK: - Voice Recording

    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            recordingURL = documentsPath.appendingPathComponent("voice_\(UUID().uuidString).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.record()
            isRecording = true

        } catch {
            print("Recording error: \(error)")
            showError(message: "Impossible d'enregistrer")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false

        guard let url = recordingURL else { return }

        // Transcribe and send
        Task {
            await transcribeAndSend(url)
        }
    }

    private func transcribeAndSend(_ url: URL) async {
        isLoading = true

        do {
            // Read audio data
            let audioData = try Data(contentsOf: url)
            let base64Audio = audioData.base64EncodedString()

            // Use voice analyze endpoint for transcription
            let response = try await voiceService.analyzeVoice(text: base64Audio)

            // Add voice message
            let voiceMessage = ChatMessage(
                type: .voice,
                content: response.rawUserText,
                isFromUser: true,
                voiceURL: url,
                voiceTranscript: response.rawUserText
            )
            messages.append(voiceMessage)
            saveMessages()

            // Send transcribed text to AI
            await sendToAI(response.rawUserText)

        } catch {
            print("Transcription error: \(error)")
            showError(message: "Erreur de transcription")
        }

        isLoading = false

        // Clean up
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Build Context

    func buildContext() -> ChatContext {
        guard let store = store else {
            return ChatContext(
                userName: "",
                currentStreak: 0,
                todayTasksCount: 0,
                todayTasksCompleted: 0,
                todayRitualsCount: 0,
                todayRitualsCompleted: 0,
                weeklyGoalsCount: 0,
                weeklyGoalsCompleted: 0,
                focusMinutesToday: 0,
                focusMinutesWeek: 0,
                timeOfDay: .current(),
                lastReflection: nil,
                currentMood: nil,
                dayOfWeek: currentDayOfWeek()
            )
        }

        let todayTasks = store.todaysTasks
        let completedTasks = todayTasks.filter { $0.status == "completed" }

        let todayRituals = store.rituals
        let completedRituals = todayRituals.filter { $0.isCompleted }

        return ChatContext(
            userName: store.user?.pseudo ?? store.user?.firstName ?? "",
            currentStreak: store.currentStreak,
            todayTasksCount: todayTasks.count,
            todayTasksCompleted: completedTasks.count,
            todayRitualsCount: todayRituals.count,
            todayRitualsCompleted: completedRituals.count,
            weeklyGoalsCount: 0, // TODO: Add weekly goals
            weeklyGoalsCompleted: 0,
            focusMinutesToday: store.focusedMinutesToday,
            focusMinutesWeek: store.weeklyProgress.reduce(0) { $0 + $1.minutes },
            timeOfDay: .current(),
            lastReflection: nil, // TODO: Add last reflection
            currentMood: nil,
            dayOfWeek: currentDayOfWeek()
        )
    }

    private func currentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    // MARK: - Persistence

    private func saveMessages() {
        ChatPersistence.saveMessages(messages)
    }

    // MARK: - Add Message After Tool Completion

    func addToolCompletionMessage(tool: ChatTool, summary: String) {
        let message = ChatMessage(
            type: .text,
            content: summary,
            isFromUser: false
        )
        messages.append(message)
        saveMessages()
    }

    // MARK: - Check for Daily Greeting

    func checkForDailyGreeting() {
        guard let lastMessage = messages.last else {
            addWelcomeMessage()
            return
        }

        // If last message was from yesterday, add new greeting
        if !Calendar.current.isDateInToday(lastMessage.timestamp) {
            let context = buildContext()
            let greeting = chatService.generateGreeting(context: context)

            let greetingMessage = ChatMessage(
                type: .text,
                content: greeting,
                isFromUser: false
            )
            messages.append(greetingMessage)
            addQuickActionCards()
            saveMessages()
        }
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }

    // MARK: - Clear Chat

    func clearChat() {
        messages = []
        ChatPersistence.clearMessages()
        addWelcomeMessage()
    }
}
