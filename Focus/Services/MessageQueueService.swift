import Foundation
import Combine
import Network

// MARK: - Queued Message

struct QueuedMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let date: String
    let createdAt: Date
    var status: QueuedMessageStatus

    init(text: String, date: String) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.createdAt = Date()
        self.status = .pending
    }

    enum QueuedMessageStatus: String, Codable, Equatable {
        case pending    // En attente (pas de connexion)
        case sending    // En cours d'envoi
        case sent       // Envoye avec succes
        case failed     // Echec d'envoi
    }
}

// MARK: - Message Queue Service

@MainActor
class MessageQueueService: ObservableObject {
    static let shared = MessageQueueService()

    @Published var isOnline: Bool = true
    @Published var queuedMessages: [QueuedMessage] = []

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.volta.networkMonitor")
    private let voiceService = VoiceService()
    private let storageKey = "volta_queued_messages"
    private var isProcessing = false

    private init() {
        loadQueuedMessages()
        startNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = path.status == .satisfied

                // Connexion restauree → envoyer les messages en attente
                if wasOffline && self.isOnline {
                    await self.processQueue()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Queue a Message

    func enqueueMessage(text: String, date: String? = nil) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let dateStr = date ?? fmt.string(from: Date())
        let message = QueuedMessage(text: text, date: dateStr)
        queuedMessages.append(message)
        saveQueuedMessages()

        if isOnline {
            Task {
                await processQueue()
            }
        }
    }

    // MARK: - Process Queue

    func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true

        for i in queuedMessages.indices {
            guard queuedMessages[i].status == .pending || queuedMessages[i].status == .failed else { continue }
            guard isOnline else { break }

            queuedMessages[i].status = .sending
            saveQueuedMessages()

            do {
                _ = try await voiceService.voiceAssistant(
                    text: queuedMessages[i].text,
                    date: queuedMessages[i].date
                )
                queuedMessages[i].status = .sent
            } catch {
                queuedMessages[i].status = .failed
                print("Failed to send queued message: \(error)")
            }
            saveQueuedMessages()
        }

        // Nettoyer les messages envoyes apres un delai
        Task {
            try? await Task.sleep(for: .seconds(3))
            queuedMessages.removeAll { $0.status == .sent }
            saveQueuedMessages()
        }

        isProcessing = false
    }

    // MARK: - Retry a Failed Message

    func retryMessage(_ messageId: UUID) {
        guard let index = queuedMessages.firstIndex(where: { $0.id == messageId }) else { return }
        queuedMessages[index].status = .pending
        saveQueuedMessages()

        if isOnline {
            Task {
                await processQueue()
            }
        }
    }

    // MARK: - Remove a Message

    func removeMessage(_ messageId: UUID) {
        queuedMessages.removeAll { $0.id == messageId }
        saveQueuedMessages()
    }

    // MARK: - Persistence

    private func saveQueuedMessages() {
        if let data = try? JSONEncoder().encode(queuedMessages) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadQueuedMessages() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let messages = try? JSONDecoder().decode([QueuedMessage].self, from: data) else { return }
        queuedMessages = messages
    }

    deinit {
        monitor.cancel()
    }
}
