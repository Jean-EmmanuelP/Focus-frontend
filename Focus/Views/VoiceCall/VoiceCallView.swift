import SwiftUI
import AVFoundation

struct VoiceCallView: View {
    @StateObject private var viewModel = VoiceCallViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "1a1a1a"),
                    Color(hex: "2d1f1a"),
                    Color(hex: "1a1a1a")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: close + timer
                topBar
                    .padding(.top, 8)

                Spacer()

                // Particle orb
                orbView
                    .padding(.bottom, 24)

                // AI response text
                if !viewModel.lastAIResponse.isEmpty {
                    Text(viewModel.lastAIResponse)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }

                // Live transcription
                if viewModel.callState == .listening && !viewModel.transcribedText.isEmpty {
                    Text(viewModel.transcribedText)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }

                // Status indicator
                statusIndicator
                    .padding(.bottom, 32)

                Spacer()

                // Hang up button
                hangUpButton
                    .padding(.bottom, 48)
            }
        }
        .onAppear {
            viewModel.startCall()
        }
        .onDisappear {
            viewModel.endCall()
        }
        .onChange(of: viewModel.callState) { newState in
            if newState == .ended {
                dismiss()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { viewModel.endCall() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }

            Spacer()

            Text(formatDuration(viewModel.callDuration))
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Orb

    private var orbView: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ColorTokens.primaryStart.opacity(orbGlowOpacity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)

            ParticleSphereView(
                isAnimating: viewModel.callState == .listening || viewModel.callState == .speaking,
                intensity: viewModel.isRecording ? 1.5 : 1.0
            )
            .frame(width: 200, height: 200)
        }
    }

    private var orbGlowOpacity: Double {
        switch viewModel.callState {
        case .speaking: return 0.4
        case .listening: return 0.3
        case .processing: return 0.2
        default: return 0.15
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.callState)
    }

    private var statusColor: Color {
        switch viewModel.callState {
        case .connecting: return .yellow
        case .listening: return .red
        case .processing: return .yellow
        case .speaking: return ColorTokens.primaryStart
        case .ended: return .gray
        }
    }

    private var statusText: String {
        switch viewModel.callState {
        case .connecting: return "Connexion..."
        case .listening: return "Ecoute..."
        case .processing: return "Reflechit..."
        case .speaking: return "Parle..."
        case .ended: return "Appel termine"
        }
    }

    // MARK: - Hang Up Button

    private var hangUpButton: some View {
        Button(action: { viewModel.endCall() }) {
            ZStack {
                Circle()
                    .fill(ColorTokens.error)
                    .frame(width: 64, height: 64)

                Image(systemName: "phone.down.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
