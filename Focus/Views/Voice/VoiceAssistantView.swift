import SwiftUI
import Combine

// MARK: - Voice Assistant View (LiveKit — agent handles conversation flow)
struct VoiceAssistantView: View {
    @StateObject private var viewModel = VoiceAssistantViewModel()
    @EnvironmentObject var store: FocusAppStore
    @Environment(\.dismiss) private var dismiss

    /// Whether user is actively being listened to
    private var isListening: Bool {
        viewModel.isConnected && !viewModel.isAgentSpeaking
    }

    var body: some View {
        ZStack {
            // Dynamic background — warm amber (idle/speaking) → teal (listening)
            backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: isListening)

            VStack(spacing: 0) {
                // Top bar — settings gear
                topBar
                    .padding(.top, 8)

                // Agent response text (top-left, large)
                if !viewModel.agentText.isEmpty {
                    Text(viewModel.agentText)
                        .font(.satoshi(24, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.agentText)
                }

                // User transcription (debug — what the user is saying)
                if !viewModel.userText.isEmpty {
                    Text(viewModel.userText)
                        .font(.satoshi(16))
                        .foregroundColor(.white.opacity(0.35))
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .lineLimit(3)
                }

                Spacer()

                // Large centered orb (idle / agent speaking)
                if !isListening {
                    largeOrbView
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                // Bottom bar — close + center prompt/orb + mic
                bottomBar
                    .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isListening)
        .onAppear {
            viewModel.startConversation()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundGradient: some View {
        if isListening {
            LinearGradient(
                colors: [
                    Color(hex: "0f1f1f"),
                    Color(hex: "152a2a"),
                    Color(hex: "0f1a1a")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [
                    Color(hex: "1a1a1a"),
                    Color(hex: "2d1f1a"),
                    Color(hex: "1a1a1a")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            Image(systemName: "gearshape")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Large Orb (idle / agent speaking)

    private var largeOrbView: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ColorTokens.primaryStart.opacity(viewModel.isAgentSpeaking ? 0.4 : 0.2),
                            ColorTokens.primaryStart.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 180
                    )
                )
                .frame(width: 340, height: 340)
                .scaleEffect(viewModel.isAgentSpeaking ? 1.1 : 1.0)
                .animation(
                    viewModel.isAgentSpeaking
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .easeInOut(duration: 0.4),
                    value: viewModel.isAgentSpeaking
                )

            ParticleSphereView(
                isAnimating: viewModel.isAgentSpeaking || viewModel.isConnected,
                intensity: viewModel.isAgentSpeaking ? 1.5 : 1.0
            )
            .frame(width: 220, height: 220)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Close button
            Button(action: {
                viewModel.cleanup()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }

            Spacer()

            // Center: prompt text OR small listening orb
            if isListening {
                ParticleSphereView(isAnimating: true, intensity: 1.0)
                    .frame(width: 80, height: 80)
                    .transition(.scale.combined(with: .opacity))
            } else if viewModel.isConnecting {
                Text("Connexion...")
                    .font(.satoshi(16))
                    .foregroundColor(.white.opacity(0.4))
            } else {
                Text("Dites quelque chose...")
                    .font(.satoshi(16))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            // Mic button
            Button(action: {
                Task {
                    try? await viewModel.toggleMic()
                }
            }) {
                Image(systemName: isListening ? "mic.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(
                            isListening ? Color.red.opacity(0.85) : Color.white.opacity(0.1)
                        )
                    )
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Particle Sphere View
struct ParticleSphereView: View {
    let isAnimating: Bool
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 10
                let time = timeline.date.timeIntervalSinceReferenceDate

                let particleCount = 600
                for i in 0..<particleCount {
                    let phi = Double(i) / Double(particleCount) * .pi * 2
                    let theta = acos(2.0 * Double(i) / Double(particleCount) - 1)

                    let speed = isAnimating ? 0.5 * intensity : 0.08
                    let animatedPhi = phi + time * speed

                    let x = radius * sin(theta) * cos(animatedPhi)
                    let y = radius * sin(theta) * sin(animatedPhi)
                    let z = radius * cos(theta)

                    let scale = (z + radius * 1.5) / (radius * 2.5)
                    let projectedX = center.x + x * scale
                    let projectedY = center.y + y * scale * 0.85

                    let particleSize = max(1.2, 2.5 * scale)
                    let opacity = 0.4 + 0.6 * scale

                    let rect = CGRect(
                        x: projectedX - particleSize / 2,
                        y: projectedY - particleSize / 2,
                        width: particleSize,
                        height: particleSize
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(ColorTokens.primaryStart.opacity(opacity))
                    )
                }
            }
        }
    }
}

// MARK: - Voice Assistant ViewModel (LiveKit)
@MainActor
class VoiceAssistantViewModel: ObservableObject {
    private let voiceService = LiveKitVoiceService()
    private var cancellables = Set<AnyCancellable>()

    @Published var agentText: String = ""
    @Published var userText: String = ""
    @Published var isAgentSpeaking = false
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var isDone = false

    init() {
        observeVoiceService()
    }

    private func observeVoiceService() {
        voiceService.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .connected:
                    self.isConnected = true
                    self.isConnecting = false
                case .connecting:
                    self.isConnecting = true
                    self.isConnected = false
                case .disconnected:
                    self.isConnected = false
                    self.isConnecting = false
                default:
                    break
                }
            }
            .store(in: &cancellables)

        voiceService.$agentTranscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self, !text.isEmpty else { return }
                self.agentText = text
            }
            .store(in: &cancellables)

        voiceService.$userTranscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self else { return }
                self.userText = text
            }
            .store(in: &cancellables)

        voiceService.$isAgentSpeaking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAgentSpeaking)
    }

    // MARK: - Start Conversation
    func startConversation() {
        Task {
            isConnecting = true
            do {
                try await voiceService.connect(mode: "voice_assistant")
            } catch {
                print("Voice assistant connection failed: \(error)")
                isConnecting = false
                isDone = true
            }
        }
    }

    func toggleMic() async throws {
        let newState = !voiceService.isMicEnabled
        try await voiceService.setMicEnabled(newState)
    }

    func cleanup() {
        Task {
            await voiceService.disconnect()
        }
        isDone = true
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Preview
#Preview {
    VoiceAssistantView()
        .environmentObject(FocusAppStore.shared)
}
