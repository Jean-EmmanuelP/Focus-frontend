import SwiftUI

struct VoiceCallView: View {
    @StateObject private var viewModel = VoiceCallViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showTranscript = false
    @State private var showVoicePicker = false
    @State private var copiedMessageId: UUID?
    @State private var messageText: String = ""
    @State private var hasDismissed = false
    @State private var selectedVoiceId: String = UserDefaults.standard.string(forKey: SettingsPrefsKeys.voltaVoiceId) ?? "b35yykvVppLXyw_l"
    @State private var exercisesCompleted: Int = 0
    @State private var showExerciseConfirm = false

    var mode: String = "voice_call"
    var planningScope: String?

    private var isMorningVerification: Bool { mode == "morning_verification" }

    private var isListening: Bool {
        viewModel.callState == .listening && !viewModel.isAgentSpeaking
    }

    private var isActive: Bool {
        viewModel.callState == .listening || viewModel.callState == .speaking || viewModel.callState == .processing
    }

    // Dynamic background color — clearly different for AI vs user
    private var bgGradientColor: Color {
        if viewModel.isAgentSpeaking { return Color(white: 0.08) } // dark = AI
        if viewModel.isUserSpeaking { return Color(white: 0.12) } // slightly lighter = user
        if isListening { return Color(white: 0.10) } // subtle = your turn
        return Color(white: 0.03) // neutral dark
    }

    var body: some View {
        ZStack {
            // Dynamic background that changes with speaking state
            bgGradientColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: viewModel.isAgentSpeaking)
                .animation(.easeInOut(duration: 0.6), value: isListening)
                .animation(.easeInOut(duration: 0.4), value: viewModel.isUserSpeaking)

            // 3D talking head — lips move when the agent is speaking
            TalkingHeadView(isSpeaking: viewModel.isAgentSpeaking, mood: "neutral")
                .ignoresSafeArea()
                .opacity(0.55)
                .allowsHitTesting(false)

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
        .onAppear {
            NSLog("🎤 [VoiceCallView] onAppear — calling startCall mode=%@", mode)
            viewModel.startCall(mode: mode, planningScope: planningScope)
        }
        .onDisappear {
            viewModel.endCall()
            Task { await viewModel.voiceService.disconnect() }
        }
        .onChange(of: viewModel.callState) { newState in
            if newState == .ended && viewModel.errorMessage == nil && viewModel.callDuration > 3 && !hasDismissed {
                hasDismissed = true
                dismiss()
            }
        }
        .sheet(isPresented: $showVoicePicker) {
            VoltaVoicePickerView(
                currentVoiceId: selectedVoiceId,
                coachName: FocusAppStore.shared.user?.companionName ?? "Kai",
                onDismiss: { showVoicePicker = false },
                onSave: { voiceId in
                    selectedVoiceId = voiceId
                    UserDefaults.standard.set(voiceId, forKey: SettingsPrefsKeys.voltaVoiceId)
                    showVoicePicker = false
                    Task {
                        try? await UserService().updateSettings(voiceId: voiceId)
                    }
                }
            )
            .presentationDetents([.large])
        }
        .alert("Erreur", isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil && viewModel.callState != .offline },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
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
        ZStack {
            VStack(spacing: 0) {
                // Morning verification header
                if isMorningVerification {
                    morningVerificationHeader
                }

                // Transcription area — fills most of the screen
                transcriptionArea
                    .padding(.top, isMorningVerification ? 20 : 80)

                Spacer()

                // "Dites quelque chose..." prompt when listening
                if !isMorningVerification && isListening && !viewModel.isAgentSpeaking && viewModel.transcribedText.isEmpty {
                    Text("Dites quelque chose...")
                        .font(.satoshi(16, weight: .medium))
                        .foregroundColor(Color(white: 0.6).opacity(0.7))
                        .padding(.bottom, 16)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: isListening)
                }

                // User's live transcription
                if !viewModel.transcribedText.isEmpty {
                    Text(viewModel.transcribedText)
                        .font(.satoshi(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .italic()
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 48)
                        .padding(.bottom, 16)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.transcribedText)
                }

                // Morning verification: big "Fait !" button
                if isMorningVerification {
                    morningExerciseButton
                        .padding(.bottom, 16)
                }

                // Speaking status label
                if !speakingStatusText.isEmpty {
                    Text(speakingStatusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(speakingStatusColor)
                        .animation(.easeInOut(duration: 0.3), value: speakingStatusText)
                        .padding(.bottom, 8)
                }

                // Bottom: X button — waves — mic button
                bottomControlsWithOrb
                    .padding(.bottom, 40)
            }
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
                    Circle().fill(Color(white: 0.6)).frame(width: 6, height: 6)
                    Text("Hors ligne")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.6).opacity(0.8))
                }
            }

            // Voice picker button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) { showVoicePicker = true }
            }) {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 40, height: 40)
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

    // MARK: - Transcription Area (top of screen)

    private var transcriptionArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.callState == .connecting {
                Text("Connexion...")
                    .font(.satoshi(20, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            } else if !viewModel.lastAIResponse.isEmpty {
                Text(viewModel.lastAIResponse)
                    .font(.satoshi(26, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.lastAIResponse)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 48)
    }

    // MARK: - Bottom Controls with Waves

    private var bottomControlsWithOrb: some View {
        VStack(spacing: 0) {
            // Audio wave visualization rising from bottom
            audioWaveView
                .frame(height: 120)

            // Control buttons
            HStack {
                // Close button (X)
                Button(action: {
                    viewModel.endCall()
                    hasDismissed = true
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }

                Spacer()

                // Mic button
                Button(action: { viewModel.toggleMic() }) {
                    Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.isMicMuted ? .white.opacity(0.4) : .white.opacity(0.7))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Audio Wave Visualization

    private var audioWaveView: some View {
        let barCount = 40
        let waveActive = viewModel.isAgentSpeaking || viewModel.isUserSpeaking || isListening
        let waveColor = orbGlowColor

        return GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let normalizedPos = Double(i) / Double(barCount)
                    // Bell curve shape — taller in center, shorter at edges
                    let bellFactor = exp(-pow((normalizedPos - 0.5) * 3.0, 2))
                    // Each bar gets a unique phase for natural movement
                    let phase = Double(i) * 0.3

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [waveColor.opacity(0.8), waveColor.opacity(0.2)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: (geo.size.width - CGFloat(barCount - 1) * 3) / CGFloat(barCount),
                            height: waveActive
                                ? CGFloat(20 + bellFactor * 80 * (viewModel.isUserSpeaking ? 1.0 : 0.7))
                                : CGFloat(4 + bellFactor * 8)
                        )
                        .animation(
                            waveActive
                                ? .easeInOut(duration: 0.3 + phase.truncatingRemainder(dividingBy: 0.4))
                                    .repeatForever(autoreverses: true)
                                    .delay(phase.truncatingRemainder(dividingBy: 0.3))
                                : .easeInOut(duration: 0.5),
                            value: waveActive
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - Orb Properties

    // MARK: - Morning Verification UI

    private var morningVerificationHeader: some View {
        VStack(spacing: 8) {
            // Exercise counter
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    ZStack {
                        Circle()
                            .fill(i < exercisesCompleted ? Color.white : Color.white.opacity(0.15))
                            .frame(width: 36, height: 36)
                        if i < exercisesCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(i + 1)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
            }

            Text("Morning Check")
                .font(.satoshi(13, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .kerning(1.5)

            if exercisesCompleted >= 3 {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.white)
                    Text("+50 points")
                        .font(.satoshi(16, weight: .bold))
                        .foregroundColor(.white)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 60)
        .animation(.spring(response: 0.4), value: exercisesCompleted)
    }

    private var morningExerciseButton: some View {
        Button {
            exercisesCompleted += 1
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 20))
                Text("Fait !")
                    .font(.satoshi(20, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color.white, Color(white: 0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .white.opacity(0.3), radius: 12, y: 4)
        }
        .padding(.horizontal, 30)
        .disabled(exercisesCompleted >= 3)
        .opacity(exercisesCompleted >= 3 ? 0.4 : 1)
    }

    // Orb color: distinct blue when AI speaks, warm orange when user speaks
    private var orbGlowColor: Color {
        if viewModel.isAgentSpeaking { return .white } // white = AI
        if viewModel.isUserSpeaking { return Color(white: 0.75) } // light gray = user
        if isListening { return Color(white: 0.6) } // medium gray waiting for user
        return Color(white: 0.4) // neutral gray
    }

    private var orbPulse: CGFloat {
        if viewModel.isAgentSpeaking { return 0.1 }
        if viewModel.isUserSpeaking { return 0.15 }
        return 0.03
    }

    // Status label showing who is speaking
    private var speakingStatusText: String {
        if viewModel.callState == .connecting { return "Connexion..." }
        if viewModel.isAgentSpeaking {
            let name = FocusAppStore.shared.user?.companionName ?? "Kai"
            return "\(name) parle..."
        }
        if viewModel.isUserSpeaking { return "Vous parlez..." }
        if isListening { return "À vous..." }
        return ""
    }

    private var speakingStatusColor: Color {
        if viewModel.isAgentSpeaking { return .white }
        if viewModel.isUserSpeaking { return Color(white: 0.75) }
        return .white.opacity(0.4)
    }

    // bottomControls removed — replaced by bottomControlsWithOrb

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
                .foregroundColor(Color(white: 0.6))
        case .sending:
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        case .sent:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
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
                        .foregroundColor(.white.opacity(0.8))
                        .transition(.opacity)
                }
            }

            if isAgent { Spacer(minLength: 60) }
        }
    }
}
