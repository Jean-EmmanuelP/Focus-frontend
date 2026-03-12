import SwiftUI

struct VoiceCallView: View {
    @StateObject private var viewModel = VoiceCallViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showTranscript = false
    @State private var copiedMessageId: UUID?
    @State private var messageText: String = ""

    private var isListening: Bool {
        viewModel.callState == .listening && !viewModel.isAgentSpeaking
    }

    private var isActive: Bool {
        viewModel.callState == .listening || viewModel.callState == .speaking || viewModel.callState == .processing
    }

    var body: some View {
        ZStack {
            // Pure dark background
            Color(hex: "050508")
                .ignoresSafeArea()

            if viewModel.callState == .offline {
                offlineView
            } else {
                mainCallView
            }

            // Transcript overlay
            if showTranscript {
                transcriptOverlay
            }
        }
        .onAppear { viewModel.startCall() }
        .onDisappear { viewModel.endCall() }
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

    // MARK: - Main Call View

    private var mainCallView: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 8)

            Spacer()

            centralVisualization

            Spacer()

            bottomControls
                .padding(.bottom, 50)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text(formatDuration(viewModel.callDuration))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))

            Spacer()

            if !viewModel.isOnline {
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Text("Hors ligne")
                        .font(.system(size: 12))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }

            if !viewModel.messages.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) { showTranscript.toggle() }
                }) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(width: 40, height: 40)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Central Visualization

    private var centralVisualization: some View {
        VStack(spacing: 0) {
            // Agent transcription — large, centered
            if !viewModel.lastAIResponse.isEmpty {
                Text(viewModel.lastAIResponse)
                    .font(.satoshi(22, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.lastAIResponse)
            }

            // Central orb with glow
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

                // Orb visualization
                if viewModel.isAgentSpeaking && !displayText.isEmpty {
                    Text(displayText)
                        .font(.satoshi(28, weight: .bold))
                        .foregroundColor(ColorTokens.primaryStart.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(width: 220, height: 220)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [orbGlowColor.opacity(0.6), orbGlowColor.opacity(0.1)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(isActive ? 1.0 + orbIntensity * 0.1 : 0.9)
                        .animation(
                            isActive
                                ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                                : .easeInOut(duration: 0.5),
                            value: isActive
                        )
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .frame(height: 260)
            .animation(.easeInOut(duration: 0.5), value: viewModel.isAgentSpeaking)

            // User transcription or status
            Group {
                if !viewModel.transcribedText.isEmpty && isListening {
                    Text(viewModel.transcribedText)
                        .font(.satoshi(16))
                        .foregroundColor(.white.opacity(0.3))
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 40)
                        .padding(.top, 24)
                        .transition(.opacity)
                } else if viewModel.callState == .connecting {
                    Text("Connexion...")
                        .font(.satoshi(16))
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.top, 24)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.transcribedText)
            .animation(.easeInOut(duration: 0.3), value: viewModel.callState)
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
        if viewModel.callState == .connecting { return 0.1 }
        return 0.15
    }

    private var glowScale: CGFloat {
        if viewModel.isAgentSpeaking { return 1.15 }
        if isListening { return 1.05 }
        return 0.95
    }

    private var orbIntensity: Double {
        if viewModel.isAgentSpeaking { return 1.2 }
        if isListening { return 0.8 }
        if viewModel.callState == .connecting { return 0.2 }
        return 0.4
    }

    private var displayText: String {
        let text = viewModel.lastAIResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        let words = text.split(separator: " ")
        return words.suffix(3).joined(separator: " ")
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            // End call (red)
            Button(action: { viewModel.endCall() }) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(ColorTokens.error))
            }

            Spacer()

            // Mute
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
            .disabled(viewModel.callState == .offline)
        }
        .padding(.horizontal, 56)
    }

    // MARK: - Transcript Overlay

    private var transcriptOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) { showTranscript = false }
                }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Transcription")
                        .font(.satoshi(18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) { showTranscript = false }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 16)

                // Messages
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
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            if copiedMessageId == message.id { copiedMessageId = nil }
                                        }
                                    } label: {
                                        Label("Copier", systemImage: "doc.on.doc")
                                    }

                                    Button {
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
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .transition(.opacity)
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

            if !MessageQueueService.shared.queuedMessages.isEmpty {
                queuedMessagesView
            }

            Spacer()

            offlineMessageInput

            // Bottom controls even in offline
            HStack {
                Button(action: { viewModel.endCall() }) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(ColorTokens.error))
                }

                Spacer()
            }
            .padding(.horizontal, 56)
            .padding(.bottom, 50)
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
