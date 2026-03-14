import SwiftUI
import LiveKit

struct FocusRoomView: View {
    let category: FocusRoomCategory
    @StateObject private var viewModel: FocusRoomViewModel
    @Environment(\.dismiss) private var dismiss

    init(category: FocusRoomCategory) {
        self.category = category
        _viewModel = StateObject(wrappedValue: FocusRoomViewModel(category: category))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            // Background
            Color(hex: "050508")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 8)

                // Participants grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        // Local user tile
                        localUserTile

                        // Remote participants
                        ForEach(viewModel.participants) { participant in
                            ParticipantTile(participant: participant)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                Spacer(minLength: 0)

                bottomControls
                    .padding(.bottom, 50)
            }

            // Connecting overlay
            if viewModel.roomState == .connecting {
                connectingOverlay
            }

            // Error overlay
            if case .error(let message) = viewModel.roomState {
                errorOverlay(message: message)
            }
        }
        .onAppear { viewModel.joinRoom() }
        .onDisappear { viewModel.leaveRoom() }
        .onChange(of: viewModel.roomState) { newState in
            if newState == .ended {
                dismiss()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 10) {
            // Timer with progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)

                // Progress ring (fills over 1 hour = 3600s)
                Circle()
                    .trim(from: 0, to: min(viewModel.sessionDuration / 3600, 1.0))
                    .stroke(
                        ColorTokens.primaryGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.sessionDuration)

                Text(viewModel.formattedDuration)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTokens.primaryStart)
            }
            .frame(width: 100, height: 100)

            // Category badge + participant count
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.primaryGradient)

                Text(category.displayName)
                    .font(.satoshi(13, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)

                Text("\(viewModel.participantCount)/\(viewModel.maxParticipants)")
                    .font(.satoshi(13, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(ColorTokens.primarySoft)
                    )
            }

            // Milestone badge
            if let milestone = viewModel.currentMilestone {
                Text(milestone)
                    .font(.satoshi(16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(ColorTokens.primaryGradient)
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Local User Tile

    private var localUserTile: some View {
        ParticipantTile(
            participant: ParticipantState(
                id: "local",
                displayName: "Toi",
                isSpeaking: false,
                isMuted: viewModel.isMicMuted,
                isCameraOn: viewModel.isCameraOn,
                videoTrack: viewModel.localVideoTrack
            ),
            isLocalUser: true
        )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            // Leave (red)
            Button(action: { viewModel.leaveRoom() }) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(ColorTokens.error))
            }

            Spacer()

            // App blocking toggle
            Button(action: { viewModel.toggleAppBlocking() }) {
                Image(systemName: viewModel.isAppBlockingActive ? "lock.shield.fill" : "lock.shield")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isAppBlockingActive ? ColorTokens.primaryStart : .white.opacity(0.5))
                    .frame(width: 64, height: 64)
                    .background(
                        Circle().fill(
                            viewModel.isAppBlockingActive ? ColorTokens.primaryStart.opacity(0.15) : Color.white.opacity(0.08)
                        )
                    )
            }

            Spacer()

            // Camera toggle
            Button(action: { viewModel.toggleCamera() }) {
                Image(systemName: viewModel.isCameraOn ? "video.fill" : "video.slash.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isCameraOn ? .white : .white.opacity(0.5))
                    .frame(width: 64, height: 64)
                    .background(
                        Circle().fill(
                            viewModel.isCameraOn ? Color.white.opacity(0.15) : Color.white.opacity(0.08)
                        )
                    )
            }

            Spacer()

            // Mic toggle
            Button(action: { viewModel.toggleMic() }) {
                Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isMicMuted ? .white.opacity(0.5) : .white)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle().fill(
                            viewModel.isMicMuted ? Color.white.opacity(0.15) : Color.white.opacity(0.08)
                        )
                    )
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Connecting Overlay

    private var connectingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)

                Text("Connexion...")
                    .font(.satoshi(16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Error Overlay

    private func errorOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ColorTokens.error)

                Text(message)
                    .font(.satoshi(16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: { dismiss() }) {
                    Text("Fermer")
                        .font(.satoshi(15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .frame(height: 48)
                        .background(
                            Capsule().fill(Color.white.opacity(0.15))
                        )
                }
            }
        }
    }
}

#Preview {
    FocusRoomView(category: .travail)
}
