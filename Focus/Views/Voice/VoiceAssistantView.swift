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
                // Spacer for status bar
                Color.clear.frame(height: 12)

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

                // User transcription
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

    // MARK: - Display text (last words from agent for particle rendering)

    private var displayText: String {
        let text = viewModel.agentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        let words = text.split(separator: " ")
        return words.suffix(3).joined(separator: " ")
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

            VoiceParticleTextView(
                text: displayText,
                isFormingText: viewModel.isAgentSpeaking && !displayText.isEmpty,
                particleColor: ColorTokens.primaryStart
            )
            .frame(width: 280, height: 280)
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

            // Mute button
            Button(action: {
                Task {
                    try? await viewModel.toggleMic()
                }
            }) {
                Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(
                            viewModel.isMicMuted ? Color.white.opacity(0.25) : Color.white.opacity(0.1)
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

// MARK: - Voice Text Particle

struct VoiceTextParticle {
    var x: Double
    var y: Double
    var vx: Double = 0
    var vy: Double = 0
    var baseX: Double
    var baseY: Double

    mutating func update(scattered: Bool, center: CGPoint, time: Double) {
        if scattered {
            // Smooth orbit with breathing
            let toCenterX = center.x - x
            let toCenterY = center.y - y
            let dist = sqrt(toCenterX * toCenterX + toCenterY * toCenterY)

            let perpX = -toCenterY / max(dist, 1)
            let perpY = toCenterX / max(dist, 1)

            // Orbit speed varies per particle for organic feel
            let orbitSpeed = 0.3 + sin(baseX * 0.1 + time * 0.5) * 0.15
            vx = vx * 0.85 + perpX * orbitSpeed
            vy = vy * 0.85 + perpY * orbitSpeed

            // Breathing: gently push in/out based on time
            let breathRadius = 60.0 + sin(time * 0.8) * 20.0
            if dist > breathRadius + 10 {
                vx += toCenterX * 0.008
                vy += toCenterY * 0.008
            } else if dist < breathRadius - 10 {
                vx -= toCenterX * 0.005
                vy -= toCenterY * 0.005
            }

            x += vx
            y += vy
        } else {
            // Spring physics — fast snap to text position
            let dx = baseX - x
            let dy = baseY - y

            let springK = 0.15  // Spring constant — snappy
            let damping = 0.7   // Damping — no overshoot

            vx = (vx + dx * springK) * damping
            vy = (vy + dy * springK) * damping

            x += vx
            y += vy
        }
    }
}

// MARK: - Voice Particle Text View

struct VoiceParticleTextView: View {
    let text: String
    let isFormingText: Bool
    let particleColor: Color

    private let particleCount = 500
    @State private var particles: [VoiceTextParticle] = []
    @State private var viewSize: CGSize = .zero

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let cx = size.width / 2
                let cy = size.height / 2
                let maxRadius = size.width / 2

                for particle in particles {
                    let dist = sqrt(pow(particle.x - cx, 2) + pow(particle.y - cy, 2))
                    let normalizedDist = min(dist / maxRadius, 1.0)

                    // Brighter near center, larger particles
                    let opacity = 0.3 + 0.7 * (1.0 - normalizedDist)
                    let pSize: CGFloat = 1.5 + 1.5 * (1.0 - normalizedDist)

                    let rect = CGRect(
                        x: particle.x - pSize / 2,
                        y: particle.y - pSize / 2,
                        width: pSize,
                        height: pSize
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(particleColor.opacity(opacity))
                    )
                }
            }
            .onChange(of: timeline.date) { _, _ in
                guard !particles.isEmpty, viewSize.width > 0 else { return }
                let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                let time = timeline.date.timeIntervalSinceReferenceDate
                for i in particles.indices {
                    particles[i].update(scattered: !isFormingText, center: center, time: time)
                }
            }
        }
        .onChange(of: text) { _, newText in
            if !newText.isEmpty {
                updateBasePositions(for: newText)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        viewSize = geo.size
                        initializeParticles()
                    }
            }
        )
    }

    // MARK: - Particle initialization (scattered cloud)

    private func initializeParticles() {
        guard viewSize.width > 0 else { return }
        let cx = viewSize.width / 2
        let cy = viewSize.height / 2

        particles = (0..<particleCount).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let radius = Double.random(in: 15...70)
            let x = cx + cos(angle) * radius
            let y = cy + sin(angle) * radius
            return VoiceTextParticle(
                x: x, y: y,
                baseX: x, baseY: y
            )
        }

        if !text.isEmpty {
            updateBasePositions(for: text)
        }
    }

    // MARK: - Sample text pixels → update particle targets

    private func updateBasePositions(for displayText: String) {
        guard viewSize.width > 0, !displayText.isEmpty else { return }

        let fontSize: CGFloat = switch displayText.count {
        case 0...3: 100
        case 4...8: 70
        case 9...15: 50
        default: 36
        }

        let renderer = ImageRenderer(
            content: Text(displayText)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        )
        renderer.scale = 1.0

        guard let image = renderer.uiImage,
              let cgImage = image.cgImage,
              let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { return }

        let width = Int(image.size.width)
        let height = Int(image.size.height)
        guard width > 0, height > 0 else { return }

        let dataLength = CFDataGetLength(pixelData)
        let offsetX = (viewSize.width - CGFloat(width)) / 2
        let offsetY = (viewSize.height - CGFloat(height)) / 2

        // Sample opaque pixels from rendered text
        var positions: [(Double, Double)] = []
        var attempts = 0
        while positions.count < particleCount && attempts < particleCount * 8 {
            let px = Int.random(in: 0..<width)
            let py = Int.random(in: 0..<height)
            let idx = ((width * py) + px) * 4 + 3
            if idx >= 0 && idx < dataLength && data[idx] > 128 {
                positions.append((Double(px) + offsetX, Double(py) + offsetY))
            }
            attempts += 1
        }

        guard !positions.isEmpty else { return }

        if particles.isEmpty {
            initializeParticles()
        }

        for i in particles.indices {
            let pos = positions[i % positions.count]
            particles[i].baseX = pos.0
            particles[i].baseY = pos.1
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
    @Published var isMicMuted = false
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
        isMicMuted = !voiceService.isMicEnabled
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
