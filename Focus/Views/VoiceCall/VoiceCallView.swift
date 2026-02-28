import SwiftUI

struct VoiceCallView: View {
    @StateObject private var viewModel = VoiceCallViewModel()
    @Environment(\.dismiss) private var dismiss

    /// Whether user is actively being listened to
    private var isListening: Bool {
        viewModel.callState == .listening && !viewModel.isAgentSpeaking
    }

    var body: some View {
        ZStack {
            // Dynamic background — warm amber (idle/speaking) → teal (listening)
            backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: isListening)

            VStack(spacing: 0) {
                // Top bar — timer
                topBar
                    .padding(.top, 8)

                // Agent response text (top-left, large)
                if !viewModel.lastAIResponse.isEmpty {
                    Text(viewModel.lastAIResponse)
                        .font(.satoshi(24, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.lastAIResponse)
                }

                // User transcription
                if !viewModel.transcribedText.isEmpty {
                    Text(viewModel.transcribedText)
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
            viewModel.startCall()
        }
        .onDisappear {
            viewModel.endCall()
        }
        .onChange(of: viewModel.callState) { newState in
            if newState == .ended && viewModel.errorMessage == nil {
                dismiss()
            }
        }
        .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
                dismiss()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
            // Timer
            Text(formatDuration(viewModel.callDuration))
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Display text (last words from agent for particle rendering)

    private var displayText: String {
        let text = viewModel.lastAIResponse.trimmingCharacters(in: .whitespacesAndNewlines)
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
                viewModel.endCall()
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
            } else if viewModel.callState == .connecting {
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
                viewModel.toggleMic()
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

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
