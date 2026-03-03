import SwiftUI
import Combine


// MARK: - Voice Assistant View (LiveKit — Perplexity-style)
struct VoiceAssistantView: View {
    @StateObject private var viewModel = VoiceAssistantViewModel()
    @EnvironmentObject var store: FocusAppStore
    @Environment(\.dismiss) private var dismiss

    private var isListening: Bool {
        viewModel.isConnected && !viewModel.isAgentSpeaking
    }

    private var isActive: Bool {
        viewModel.isConnected
    }

    var body: some View {
        ZStack {
            // Pure dark background
            Color(hex: "050508")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Central visualization: text + orb + user text
                centralVisualization

                Spacer()

                // Minimal bottom controls
                bottomControls
                    .padding(.bottom, 50)
            }
        }
        .onAppear { viewModel.startConversation() }
        .onDisappear { viewModel.cleanup() }
    }

    // MARK: - Central Visualization

    private var centralVisualization: some View {
        VStack(spacing: 0) {
            // Agent transcription — large, centered
            if !viewModel.agentText.isEmpty {
                Text(viewModel.agentText)
                    .font(.satoshi(22, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.agentText)
            }

            // Orb with glow
            ZStack {
                // Radial glow behind orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbGlowColor.opacity(orbGlowOpacity),
                                orbGlowColor.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .scaleEffect(glowScale)
                    .animation(
                        viewModel.isAgentSpeaking
                            ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                            : .easeInOut(duration: 0.8),
                        value: viewModel.isAgentSpeaking
                    )
                    .animation(.easeInOut(duration: 0.8), value: isListening)

                // Particle orb or text particles
                if viewModel.isAgentSpeaking && !displayText.isEmpty {
                    VoiceParticleTextView(
                        text: displayText,
                        isFormingText: true,
                        particleColor: ColorTokens.primaryStart
                    )
                    .frame(width: 220, height: 220)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    ParticleSphereView(
                        isAnimating: isActive,
                        intensity: orbIntensity
                    )
                    .frame(width: 180, height: 180)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .frame(height: 260)
            .animation(.easeInOut(duration: 0.5), value: viewModel.isAgentSpeaking)

            // User transcription or status
            Group {
                if !viewModel.userText.isEmpty && isListening {
                    Text(viewModel.userText)
                        .font(.satoshi(16))
                        .foregroundColor(.white.opacity(0.3))
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 40)
                        .padding(.top, 24)
                        .transition(.opacity)
                } else if viewModel.isConnecting {
                    Text("Connexion...")
                        .font(.satoshi(16))
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.top, 24)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.userText)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isConnecting)
        }
    }

    // MARK: - Orb Properties

    private var orbGlowColor: Color {
        if viewModel.isAgentSpeaking { return ColorTokens.primaryStart }
        if isListening { return ColorTokens.accent }
        return ColorTokens.primaryStart
    }

    private var orbGlowOpacity: Double {
        if viewModel.isAgentSpeaking { return 0.35 }
        if isListening { return 0.2 }
        return 0.1
    }

    private var glowScale: CGFloat {
        if viewModel.isAgentSpeaking { return 1.15 }
        if isListening { return 1.05 }
        return 0.95
    }

    private var orbIntensity: Double {
        if viewModel.isAgentSpeaking { return 1.2 }
        if isListening { return 0.8 }
        if viewModel.isConnecting { return 0.2 }
        return 0.4
    }

    private var displayText: String {
        let text = viewModel.agentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        let words = text.split(separator: " ")
        return words.suffix(3).joined(separator: " ")
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            // Close
            Button(action: {
                viewModel.cleanup()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }

            Spacer()

            // Mute
            Button(action: {
                Task { try? await viewModel.toggleMic() }
            }) {
                Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isMicMuted ? .white.opacity(0.5) : .white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle().fill(
                            viewModel.isMicMuted ? Color.white.opacity(0.15) : Color.white.opacity(0.08)
                        )
                    )
            }
        }
        .padding(.horizontal, 56)
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
            let toCenterX = center.x - x
            let toCenterY = center.y - y
            let dist = sqrt(toCenterX * toCenterX + toCenterY * toCenterY)

            let perpX = -toCenterY / max(dist, 1)
            let perpY = toCenterX / max(dist, 1)

            let orbitSpeed = 0.3 + sin(baseX * 0.1 + time * 0.5) * 0.15
            vx = vx * 0.85 + perpX * orbitSpeed
            vy = vy * 0.85 + perpY * orbitSpeed

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
            let dx = baseX - x
            let dy = baseY - y

            let springK = 0.15
            let damping = 0.7

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
