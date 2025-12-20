import Foundation
import Combine

/// WebSocket message types from the server
enum WSMessageType: String, Codable {
    case focusStarted = "focus_started"
    case focusStopped = "focus_stopped"
    case leaderboardUpdate = "leaderboard_update"
}

/// WebSocket message structure
struct WSMessage: Codable {
    let type: String
    let payload: FocusUpdatePayload
}

/// Focus update payload
struct FocusUpdatePayload: Codable {
    let userId: String
    let pseudo: String
    let avatarUrl: String?
    let isLive: Bool
    let startedAt: String?
    let durationMins: Int?
}

/// Manager for WebSocket connections to receive real-time updates
@MainActor
class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()

    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var lastFocusUpdate: FocusUpdatePayload?

    // MARK: - Publishers
    let focusUpdatePublisher = PassthroughSubject<FocusUpdatePayload, Never>()

    // MARK: - Private Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var isManuallyDisconnected = false

    private init() {}

    // MARK: - Public Methods

    /// Connect to the WebSocket server
    func connect() {
        guard !isConnected, !isManuallyDisconnected else { return }

        Task {
            await connectAsync()
        }
    }

    private func connectAsync() async {
        // Get the base URL and auth token
        guard let baseURL = URL(string: APIConfiguration.baseURL),
              let token = await AuthService.shared.getAccessToken() else {
            print("❌ WebSocket: Missing URL or auth token")
            return
        }

        // Build WebSocket URL (wss:// for HTTPS, ws:// for HTTP)
        let wsScheme = baseURL.scheme == "https" ? "wss" : "ws"
        guard let host = baseURL.host else { return }
        let port = baseURL.port.map { ":\($0)" } ?? ""

        guard let wsURL = URL(string: "\(wsScheme)://\(host)\(port)/ws") else {
            print("❌ WebSocket: Invalid URL")
            return
        }

        var request = URLRequest(url: wsURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        isConnected = true
        reconnectAttempts = 0
        print("🔌 WebSocket: Connecting to \(wsURL)")

        receiveMessage()
        startPingTimer()
    }

    /// Disconnect from the WebSocket server
    func disconnect() {
        isManuallyDisconnected = true
        closeConnection()
    }

    /// Reconnect to the WebSocket server
    func reconnect() {
        isManuallyDisconnected = false
        closeConnection()

        // Exponential backoff for reconnection
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectAttempts += 1

        guard reconnectAttempts <= maxReconnectAttempts else {
            print("❌ WebSocket: Max reconnect attempts reached")
            return
        }

        print("🔄 WebSocket: Reconnecting in \(delay) seconds (attempt \(reconnectAttempts))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }

    // MARK: - Private Methods

    private func closeConnection() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                Task { @MainActor in
                    self.handleMessage(message)
                }
                self.receiveMessage() // Continue listening

            case .failure(let error):
                print("❌ WebSocket receive error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.isConnected = false
                    if !self.isManuallyDisconnected {
                        self.reconnect()
                    }
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let message = try decoder.decode(WSMessage.self, from: data)

            switch message.type {
            case WSMessageType.focusStarted.rawValue, WSMessageType.focusStopped.rawValue:
                print("📡 WebSocket: Focus update received - \(message.payload.pseudo) isLive=\(message.payload.isLive)")
                lastFocusUpdate = message.payload
                focusUpdatePublisher.send(message.payload)

            default:
                print("📡 WebSocket: Unknown message type: \(message.type)")
            }
        } catch {
            print("❌ WebSocket: Failed to decode message: \(error)")
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("❌ WebSocket ping failed: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.isConnected = false
                    if !(self?.isManuallyDisconnected ?? true) {
                        self?.reconnect()
                    }
                }
            }
        }
    }
}
