import SwiftUI

struct VoiceCallView: View {
    @StateObject private var viewModel = VoiceCallViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var copiedMessageId: UUID?
    @State private var messageText: String = ""

    /// Whether user is actively being listened to
    private var isListening: Bool {
        viewModel.callState == .listening && !viewModel.isAgentSpeaking
    }

    var body: some View {
        ZStack {
            // Dynamic background
            backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: isListening)

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.top, 8)

                // Offline banner
                if !viewModel.isOnline {
                    offlineBanner
                }

                if viewModel.callState == .offline {
                    offlineView
                } else if viewModel.messages.isEmpty {
                    // Classic orb view when no messages yet
                    classicOrbLayout
                } else {
                    // Message bubbles when conversation started
                    messageListView
                }

                // Bottom bar
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
        .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil && viewModel.callState != .offline)) {
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
            Text(formatDuration(viewModel.callDuration))
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))

            Spacer()

            // Connection indicator
            if !viewModel.isOnline {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Hors ligne")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14))
            Text("Pas de connexion — les messages seront envoyes automatiquement")
                .font(.system(size: 13))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.8))
    }

    // MARK: - Offline View

    private var offlineView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: 8) {
                Text("Pas de connexion")
                    .font(.satoshi(24, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))

                Text("Tu peux ecrire un message — il sera envoye quand tu seras reconnecte")
                    .font(.satoshi(16))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Queued messages
            if !MessageQueueService.shared.queuedMessages.isEmpty {
                queuedMessagesView
            }

            Spacer()

            // Text input for offline messages
            offlineMessageInput
        }
    }

    // MARK: - Queued Messages

    private var queuedMessagesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Messages en attente")
                .font(.satoshi(14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 24)

            ForEach(MessageQueueService.shared.queuedMessages) { msg in
                HStack(spacing: 8) {
                    Text(msg.text)
                        .font(.satoshi(14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)

                    Spacer()

                    statusIcon(for: msg.status)
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = msg.text
                    } label: {
                        Label("Copier", systemImage: "doc.on.doc")
                    }
                    if msg.status == .failed {
                        Button {
                            MessageQueueService.shared.retryMessage(msg.id)
                        } label: {
                            Label("Renvoyer", systemImage: "arrow.clockwise")
                        }
                    }
                    Button(role: .destructive) {
                        MessageQueueService.shared.removeMessage(msg.id)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for status: QueuedMessage.QueuedMessageStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(.orange)
        case .sending:
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        case .sent:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
        }
    }

    // MARK: - Offline Message Input

    private var offlineMessageInput: some View {
        HStack(spacing: 12) {
            TextField("Ecris ton message...", text: $messageText)
                .textFieldStyle(.plain)
                .font(.satoshi(16))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)

            Button(action: {
                let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                viewModel.queueMessage(text)
                messageText = ""
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .white.opacity(0.3)
                            : ColorTokens.primaryStart
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Classic Orb Layout (no messages yet)

    private var classicOrbLayout: some View {
        VStack(spacing: 0) {
            // Agent response text
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

            // Large centered orb
            if !isListening {
                largeOrbView
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()
        }
    }

    // MARK: - Message List View (WhatsApp-like)

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isCopied: copiedMessageId == message.id
                        )
                        .id(message.id)
                        .contextMenu {
                            Button {
                                viewModel.copyMessage(message)
                                copiedMessageId = message.id
                                // Reset copied indicator after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedMessageId == message.id {
                                        copiedMessageId = nil
                                    }
                                }
                            } label: {
                                Label("Copier", systemImage: "doc.on.doc")
                            }

                            Button {
                                // Copy all messages
                                let allText = viewModel.messages.map { msg in
                                    let prefix = msg.role == .agent ? "Volta" : "Moi"
                                    return "\(prefix): \(msg.text)"
                                }.joined(separator: "\n")
                                UIPasteboard.general.string = allText
                            } label: {
                                Label("Copier tout", systemImage: "doc.on.doc.fill")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Display text (last words from agent for particle rendering)

    private var displayText: String {
        let text = viewModel.lastAIResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        let words = text.split(separator: " ")
        return words.suffix(3).joined(separator: " ")
    }

    // MARK: - Large Orb

    private var largeOrbView: some View {
        ZStack {
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
            } else if viewModel.callState == .offline {
                Text("Hors ligne")
                    .font(.satoshi(16))
                    .foregroundColor(.orange.opacity(0.8))
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
            .disabled(viewModel.callState == .offline)
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

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: VoiceMessage
    var isCopied: Bool = false

    private var isAgent: Bool { message.role == .agent }

    var body: some View {
        HStack {
            if !isAgent { Spacer(minLength: 60) }

            VStack(alignment: isAgent ? .leading : .trailing, spacing: 4) {
                Text(message.text)
                    .font(.satoshi(15))
                    .foregroundColor(isAgent ? .white.opacity(0.85) : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isAgent
                                ? Color.white.opacity(0.1)
                                : ColorTokens.primaryStart.opacity(0.6)
                            )
                    )

                if isCopied {
                    Text("Copie !")
                        .font(.system(size: 11))
                        .foregroundColor(.green.opacity(0.8))
                        .transition(.opacity)
                }
            }

            if isAgent { Spacer(minLength: 60) }
        }
    }
}
