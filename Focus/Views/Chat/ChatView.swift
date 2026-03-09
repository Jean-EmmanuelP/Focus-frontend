import SwiftUI
import AVFoundation
import Combine
import WebKit

// MARK: - Replika-Style Chat View

struct ChatView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showSettings = false

    // Recording state
    @StateObject private var audioRecorder = VoiceRecorderManager()
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var showPaywall = false
    @State private var showCompanionProfile = false
    @State private var showVoiceCall = false
    @State private var isHomeMode = false  // Toggle between home view and chat view
    @State private var showAppBlocker = false
    @State private var isAvatarPaused = false

    @EnvironmentObject var subscriptionManager: SubscriptionManager

    // Companion name (from user settings)
    private var companionName: String {
        store.user?.companionName ?? "ton coach"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Blue gradient background (like Replika)
                replikaBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header - changes based on mode
                    if isHomeMode || viewModel.messages.isEmpty {
                        homeHeader
                    } else {
                        conversationHeader
                    }

                    // App blocking banner
                    if ScreenTimeAppBlockerService.shared.isBlocking {
                        AppBlockingBanner()
                            .padding(.top, 6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Content area (avatar is in background)
                    if isHomeMode || viewModel.messages.isEmpty {
                        // Home mode: just spacer, avatar is background
                        Spacer()
                    } else {
                        // Chat mode: messages overlay on avatar background
                        messagesScrollView
                    }

                    // Input bar - always visible
                    replikaInputBar
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setStore(store)
            viewModel.loadHistory()
        }
        .onDisappear {
            // Clean up timer to prevent memory leak
            recordingTimer?.invalidate()
            recordingTimer = nil
        }
        .onTapGesture {
            isInputFocused = false
        }
        .overlay {
            if showPaywall {
                FocusPaywallView(
                    companionName: companionName,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPaywall = false
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPaywall = false
                        }
                    }
                )
                .environmentObject(subscriptionManager)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPaywall)
        .onChange(of: showPaywall) { _, isShowing in
            if isShowing {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onChange(of: showSettings) { _, isShowing in
            if isShowing {
                isInputFocused = false
            }
        }
        .overlay {
            if showCompanionProfile {
                CompanionProfileView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCompanionProfile = false
                    }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCompanionProfile)
        .animation(.easeInOut(duration: 0.3), value: isHomeMode)
        .overlay {
            if showSettings {
                SettingsPageView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSettings = false
                    }
                })
                .environmentObject(store)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSettings)
        .overlay {
            if showAppBlocker {
                AppBlockerSettingsView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) { showAppBlocker = false }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showAppBlocker)
        .onChange(of: showAppBlocker) { _, isShowing in
            // Auto-start blocking when user closes the app blocker settings after selecting apps
            if !isShowing {
                let blocker = ScreenTimeAppBlockerService.shared
                if blocker.hasSelectedApps && !blocker.isBlocking {
                    blocker.startBlocking()
                    let confirmMsg = SimpleChatMessage(content: "Apps bloquées ! Tu peux te concentrer maintenant.", isFromUser: false)
                    viewModel.messages.append(confirmMsg)
                    viewModel.saveMessages()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAppBlockerSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showAppBlocker = true
            }
        }
        .fullScreenCover(isPresented: $showVoiceCall) {
            VoiceCallView()
        }
        .onChange(of: isInputFocused) { _, focused in
            if focused {
                // Pause 3D scene immediately to free GPU for keyboard animation
                isAvatarPaused = true
                // Exit home mode when user starts typing (only if there are messages)
                if isHomeMode && !viewModel.messages.isEmpty {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isHomeMode = false
                    }
                }
            } else {
                // Resume 3D scene after keyboard dismiss animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isAvatarPaused = false
                }
            }
        }
    }

    // MARK: - Background (Full screen 3D Avatar)

    private var replikaBackground: some View {
        // Full-screen 3D Avatar as background (same as personalizeAvatarStep)
        Avatar3DView(
            avatarURL: AvatarURLs.cesiumMan,
            backgroundColor: UIColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1.0),
            enableRotation: false,
            autoRotate: false,
            isPaused: isAvatarPaused
        )
        .ignoresSafeArea()
    }

    // MARK: - Home Header (home mode or empty state)

    private var homeHeader: some View {
        HStack {
            // Left: Tulip/customize look button
            Button(action: {
                // Customize look action - can open a sheet later
            }) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }

            Spacer()

            // Center: Satisfaction gauge + companion name
            Button(action: {
                isInputFocused = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCompanionProfile = true
                }
            }) {
                VStack(spacing: 4) {
                    SatisfactionGaugeView(score: viewModel.satisfactionScore, size: 60)
                    Text(companionName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            // Right: Settings gear
            Button(action: {
                isInputFocused = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSettings = true
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Conversation Header

    private var conversationHeader: some View {
        HStack(spacing: 12) {
            // Left: Home button + companion name
            HStack(spacing: 8) {
                Button(action: {
                    isInputFocused = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isHomeMode = true
                    }
                }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                        )
                }

                Button(action: {
                    isInputFocused = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCompanionProfile = true
                    }
                }) {
                    HStack(spacing: 8) {
                        SatisfactionGaugeView(score: viewModel.satisfactionScore, size: 28)
                        Text(companionName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
                }
            }

            Spacer()

            // Right: Settings gear
            Button(action: {
                isInputFocused = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSettings = true
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }


    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    // Group messages by date
                    ForEach(viewModel.groupedMessages) { group in
                        // Date separator
                        dateSeparator(date: group.date)

                        // Messages for this date
                        ForEach(group.messages) { message in
                            ReplikaMessageBubble(message: message.withResolvedContent(viewModel.resolvedContent), viewModel: viewModel)
                                .id(message.id)
                        }
                    }

                    if viewModel.isLoading {
                        typingIndicator
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    // Wait for keyboard animation to finish, then scroll
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private static let dateSeparatorFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    private func dateSeparator(date: Date) -> some View {
        return Text(Self.dateSeparatorFormatter.string(from: date))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
            )
            .padding(.vertical, 8)
    }

    private var typingIndicator: some View {
        HStack {
            TypingDotsView()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.95))
                .cornerRadius(20)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Input Bar (Replika style)

    private var replikaInputBar: some View {
        HStack(spacing: 8) {
            // Left: Phone call button
            Button(action: {
                #if DEBUG
                showVoiceCall = true
                #else
                if subscriptionManager.isProUser {
                    showVoiceCall = true
                } else {
                    showPaywall = true
                }
                #endif
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.58, green: 0.53, blue: 0.55))
                        .frame(width: 52, height: 52)

                    Image(systemName: "phone.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            // Text field capsule with blur effect and "+" inside
            HStack(spacing: 0) {
                TextField("", text: $viewModel.inputText, prompt: Text("Votre message").foregroundColor(.white.opacity(0.45)))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .focused($isInputFocused)

                Spacer()

                if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Send button when text is entered
                    Button {
                        // Exit home mode when sending message
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isHomeMode = false
                        }
                        viewModel.sendMessage()
                        isInputFocused = false
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                } else {
                    // Mic button inside the capsule — start voice recording
                    Button {
                        if viewModel.canSendFreeVoice {
                            if isRecording {
                                stopRecordingAndSend()
                            } else {
                                startRecording()
                            }
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isRecording ? .red : .white.opacity(0.5))
                    }
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color(red: 0.25, green: 0.28, blue: 0.35).opacity(0.85))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Recording Functions

    private func startRecording() {
        HapticFeedback.medium()
        audioRecorder.startRecording()
        isRecording = true
        recordingTime = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }

    private func stopRecordingAndSend() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        guard isRecording else { return }
        isRecording = false
        HapticFeedback.light()

        if let audioURL = audioRecorder.stopRecording(), recordingTime > 0.5 {
            Task {
                await viewModel.sendVoiceMessage(audioURL: audioURL)
            }
        }
    }
}

// MARK: - Satisfaction Gauge View

struct SatisfactionGaugeView: View {
    let score: Int
    var size: CGFloat = 60

    private var progress: Double {
        Double(max(0, min(100, score))) / 100.0
    }

    private var gaugeColor: Color {
        switch score {
        case ..<30: return Color(red: 0.9, green: 0.25, blue: 0.2)
        case 30..<50: return Color(red: 0.95, green: 0.55, blue: 0.2)
        case 50..<70: return Color(red: 0.95, green: 0.8, blue: 0.2)
        case 70..<86: return Color(red: 0.45, green: 0.85, blue: 0.4)
        default: return Color(red: 0.2, green: 0.85, blue: 0.35)
        }
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: size * 0.08)

            // Colored arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(gaugeColor, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: score)

            // Score text
            Text("\(score)")
                .font(.system(size: size * 0.33, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Replika Message Bubble

struct ReplikaMessageBubble: View {
    let message: SimpleChatMessage
    var viewModel: ChatViewModel?

    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var isDownloading = false
    @State private var downloadedLocalURL: URL?

    // Colors
    private let userBubbleColor = Color(red: 0.22, green: 0.28, blue: 0.42) // Dark navy blue
    private let aiBubbleColor = Color.white.opacity(0.95) // White/cream

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 0) {
                if message.isFromUser {
                    Spacer(minLength: 120)
                } else {
                    Spacer(minLength: 100)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    if message.type == .voice {
                        voiceMessageBubble
                    } else {
                        textBubble
                    }

                    // Failed status: retry button
                    if message.isFromUser && message.status == .failed {
                        Button {
                            viewModel?.retryMessage(message)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Réessayer")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }

                if !message.isFromUser {
                    Spacer().frame(width: 16)
                }
            }

            // Card data (task list, routine list)
            if let cardData = message.cardData {
                HStack {
                    Spacer(minLength: 60)
                    cardView(for: cardData)
                    Spacer().frame(width: 16)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var textBubble: some View {
        Text(message.content)
            .font(.system(size: 16))
            .foregroundColor(message.isFromUser ? .white : .black)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(message.isFromUser ? userBubbleColor : aiBubbleColor)
            .cornerRadius(26)
            .opacity(message.status == .sending ? 0.6 : 1.0)
            .opacity(message.status == .failed ? 0.5 : 1.0)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                }
            } preview: {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundColor(message.isFromUser ? .white : .black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(message.isFromUser ? userBubbleColor : aiBubbleColor)
                    .cornerRadius(26)
                    .padding(8)
            }
    }

    // MARK: - Card Views

    @ViewBuilder
    private func cardView(for cardData: ChatCardData) -> some View {
        switch cardData {
        case .taskList(let tasks):
            InlineTaskListCard(tasks: tasks, messageId: message.id, viewModel: viewModel)
        case .routineList(let routines):
            InlineRoutineListCard(routines: routines, messageId: message.id, viewModel: viewModel)
        case .planning(let tasks, let routines, let focusState):
            InlinePlanningCard(tasks: tasks, routines: routines, focusState: focusState, messageId: message.id, viewModel: viewModel)
        case .videoCard(let video):
            InlineVideoCard(video: video, messageId: message.id, viewModel: viewModel)
        case .videoSuggestions(let data):
            VideoSuggestionsCard(data: data, messageId: message.id, viewModel: viewModel)
        case .actionButton(let action):
            Button {
                NotificationCenter.default.post(name: Notification.Name(action.deepLink), object: nil)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: action.icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(action.title)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            }
        }
    }

    // Voice message
    private var audioAvailable: Bool {
        message.hasLocalAudio || message.voiceStoragePath != nil || downloadedLocalURL != nil
    }

    private var playableURL: URL? {
        if let downloaded = downloadedLocalURL {
            return downloaded
        }
        return message.localVoiceURL
    }

    private var voiceMessageBubble: some View {
        let isUser = message.isFromUser
        let textColor: Color = isUser ? .white : .black
        let bgColor = isUser ? userBubbleColor : aiBubbleColor

        return HStack(spacing: 12) {
            Button {
                if audioPlayer.isPlaying {
                    audioPlayer.pause()
                } else if let url = playableURL, FileManager.default.fileExists(atPath: url.path) {
                    audioPlayer.play(url: url)
                } else if message.voiceStoragePath != nil {
                    downloadAndPlay()
                }
            } label: {
                if isDownloading {
                    ProgressView()
                        .tint(textColor)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                        .frame(width: 32, height: 32)
                }
            }

            // Waveform
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    let progress = audioPlayer.isPlaying ? audioPlayer.progress : 0
                    let isPlayed = Double(i) / 20.0 < progress
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPlayed ? textColor : textColor.opacity(0.3))
                        .frame(width: 3, height: waveformHeight(for: i))
                }
            }
            .frame(height: 20)

            Text(formatDuration(message.voiceDuration ?? 0))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textColor.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(bgColor)
        .cornerRadius(26)
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [6, 12, 8, 16, 10, 18, 6, 14, 12, 8, 16, 6, 12, 18, 8, 14, 10, 16, 6, 12]
        return heights[index % heights.count]
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func downloadAndPlay() {
        guard let storagePath = message.voiceStoragePath else { return }

        isDownloading = true

        Task {
            do {
                let audioData = try await SupabaseStorageService.shared.downloadVoiceMessage(from: storagePath)

                let fileManager = FileManager.default
                let voiceMessagesDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("voice_messages", isDirectory: true)

                try? fileManager.createDirectory(at: voiceMessagesDir, withIntermediateDirectories: true)

                let filename = message.voiceFilename ?? "\(message.id.uuidString).m4a"
                let localURL = voiceMessagesDir.appendingPathComponent(filename)

                try audioData.write(to: localURL)

                await MainActor.run {
                    downloadedLocalURL = localURL
                    isDownloading = false
                    audioPlayer.play(url: localURL)
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                }
                print("Failed to download voice message: \(error)")
            }
        }
    }
}

// MARK: - Inline Task List Card

struct InlineTaskListCard: View {
    let tasks: [ChatCardData.CardTask]
    let messageId: UUID
    var viewModel: ChatViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                Text("Tâches du jour")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text("\(tasks.filter { $0.isCompleted }.count)/\(tasks.count)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.black.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if tasks.isEmpty {
                Text("Aucune tache pour aujourd'hui")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                // Tasks
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    Button {
                        viewModel?.toggleTaskCompletion(messageId: messageId, taskId: task.id)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(task.isCompleted ? Color.clear : Color.black.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)

                                if task.isCompleted {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            Text(task.title)
                                .font(.system(size: 15, weight: task.isCompleted ? .regular : .medium))
                                .foregroundColor(task.isCompleted ? .black.opacity(0.3) : .black.opacity(0.85))
                                .strikethrough(task.isCompleted, color: .black.opacity(0.2))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                    }

                    if index < tasks.count - 1 {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 50)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Inline Routine List Card

struct InlineRoutineListCard: View {
    let routines: [ChatCardData.CardRoutine]
    let messageId: UUID
    var viewModel: ChatViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "repeat")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                Text("Rituels")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text("\(routines.filter { $0.isCompleted }.count)/\(routines.count)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.black.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if routines.isEmpty {
                Text("Aucun rituel configure")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                // Routines
                ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                    Button {
                        viewModel?.toggleRoutineCompletion(messageId: messageId, routineId: routine.id)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(routine.isCompleted ? Color.clear : Color.black.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)

                                if routine.isCompleted {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            Text(routine.icon)
                                .font(.system(size: 16))

                            Text(routine.title)
                                .font(.system(size: 15, weight: routine.isCompleted ? .regular : .medium))
                                .foregroundColor(routine.isCompleted ? .black.opacity(0.3) : .black.opacity(0.85))
                                .strikethrough(routine.isCompleted, color: .black.opacity(0.2))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                    }

                    if index < routines.count - 1 {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 50)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Inline Planning Card (Tasks + Routines combined)

struct InlinePlanningCard: View {
    let tasks: [ChatCardData.CardTask]
    let routines: [ChatCardData.CardRoutine]
    let focusState: ChatCardData.PlanningFocusState?
    let messageId: UUID
    var viewModel: ChatViewModel?

    @State private var selectedDuration: Int = 25
    @State private var showCustomDuration = false
    @State private var customMinutes: String = ""
    @State private var customFocusTitle: String = ""
    @State private var showConfetti = false

    private var totalItems: Int { tasks.count + routines.count }
    private var completedItems: Int {
        tasks.filter { $0.isCompleted }.count + routines.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let focus = focusState, focus.timerState == .running || focus.timerState == .paused {
                timerActiveView(focus: focus)
            } else if let focus = focusState, focus.timerState == .completed {
                completedView(focus: focus)
            } else {
                normalPlanningView
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .onAppear {
            if let focus = focusState {
                selectedDuration = focus.duration
            }
        }
    }

    // MARK: - Normal / Idle Planning View

    @ViewBuilder
    private var normalPlanningView: some View {
        // Header
        HStack(spacing: 8) {
            Image(systemName: focusState != nil ? "flame.fill" : "checklist")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(focusState != nil ? .orange : .black.opacity(0.5))
            Text(focusState != nil ? "Session Focus" : "Planning du jour")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
            if focusState == nil && totalItems > 0 {
                Text("\(completedItems)/\(totalItems)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.black.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)

        if tasks.isEmpty && routines.isEmpty {
            Text("Aucune tache ni rituel pour aujourd'hui")
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.4))
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        } else {
            // Tasks section
            if !tasks.isEmpty {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    HStack(spacing: 0) {
                        Button {
                            viewModel?.toggleTaskCompletion(messageId: messageId, taskId: task.id)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(task.isCompleted ? Color.clear : Color.black.opacity(0.2), lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                    if task.isCompleted {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.black)
                                            .frame(width: 22, height: 22)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                Text(task.title)
                                    .font(.system(size: 15, weight: task.isCompleted ? .regular : .medium))
                                    .foregroundColor(task.isCompleted ? .black.opacity(0.3) : .black.opacity(0.85))
                                    .strikethrough(task.isCompleted, color: .black.opacity(0.2))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                        }
                        // Focus button on each task (only in focus mode, idle state, non-completed tasks)
                        if focusState != nil && !task.isCompleted {
                            Button {
                                viewModel?.selectTaskForFocus(messageId: messageId, taskId: task.id, taskTitle: task.title)
                                if let est = task.estimatedMinutes, est > 0 {
                                    selectedDuration = est
                                }
                            } label: {
                                Image(systemName: focusState?.activeTaskId == task.id ? "flame.fill" : "flame")
                                    .font(.system(size: 16))
                                    .foregroundColor(focusState?.activeTaskId == task.id ? .orange : .black.opacity(0.2))
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 16)

                    if index < tasks.count - 1 || !routines.isEmpty {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 50)
                    }
                }
            }

            // Routines section (hidden during focus mode to save space)
            if !routines.isEmpty && focusState == nil {
                if !tasks.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "repeat")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black.opacity(0.35))
                        Text("Rituels")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black.opacity(0.35))
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                }

                ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                    Button {
                        viewModel?.toggleRoutineCompletion(messageId: messageId, routineId: routine.id)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(routine.isCompleted ? Color.clear : Color.black.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                if routine.isCompleted {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Text(routine.icon)
                                .font(.system(size: 16))
                            Text(routine.title)
                                .font(.system(size: 15, weight: routine.isCompleted ? .regular : .medium))
                                .foregroundColor(routine.isCompleted ? .black.opacity(0.3) : .black.opacity(0.85))
                                .strikethrough(routine.isCompleted, color: .black.opacity(0.2))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                    }
                    if index < routines.count - 1 {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 50)
                    }
                }
            }
            Spacer().frame(height: 4)
        }

        // Focus controls (duration + start button) — only in focus/idle mode
        if let focus = focusState, focus.timerState == .idle {
            focusIdleControls(focus: focus)
        }
    }

    // MARK: - Focus Idle Controls (duration chips + start)

    private func focusIdleControls(focus: ChatCardData.PlanningFocusState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5)

            // Duration chips
            VStack(alignment: .leading, spacing: 6) {
                Text("Durée")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.horizontal, 16)

                HStack(spacing: 8) {
                    ForEach([25, 50, 90], id: \.self) { minutes in
                        Button {
                            selectedDuration = minutes
                            showCustomDuration = false
                            viewModel?.updateFocusDuration(messageId: messageId, duration: minutes)
                        } label: {
                            Text("\(minutes) min")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(selectedDuration == minutes && !showCustomDuration ? .white : .black.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedDuration == minutes && !showCustomDuration ? Color.black : Color.black.opacity(0.06))
                                .cornerRadius(12)
                        }
                    }

                    Button {
                        showCustomDuration = true
                    } label: {
                        if showCustomDuration {
                            HStack(spacing: 4) {
                                TextField("", text: $customMinutes)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .keyboardType(.numberPad)
                                    .frame(width: 30)
                                    .multilineTextAlignment(.center)
                                    .onChange(of: customMinutes) { _, newValue in
                                        if let val = Int(newValue), val > 0 {
                                            selectedDuration = val
                                            viewModel?.updateFocusDuration(messageId: messageId, duration: val)
                                        }
                                    }
                                Text("min")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .cornerRadius(12)
                        } else {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.06))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Free subject field (when no task selected)
            if focus.activeTaskId == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sujet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black.opacity(0.4))
                        .padding(.horizontal, 16)

                    TextField("Sur quoi tu veux focus ?", text: $customFocusTitle)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.04))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                }
            }

            // Start button
            Button {
                viewModel?.startInlineFocusTimer(
                    messageId: messageId,
                    taskId: focus.activeTaskId,
                    taskTitle: focus.activeTaskId != nil ? focus.activeTaskTitle : (customFocusTitle.isEmpty ? nil : customFocusTitle),
                    duration: selectedDuration
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Commencer")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(14)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Timer Active View (running / paused)

    private func timerActiveView(focus: ChatCardData.PlanningFocusState) -> some View {
        let isPaused = focus.timerState == .paused
        return VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                Text(isPaused ? "En pause" : "Focus en cours")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if let title = focus.activeTaskTitle {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black.opacity(0.4))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Progress ring + countdown
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: timerProgress(focus: focus))
                    .stroke(
                        isPaused ? Color.orange : Color.black,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: focus.timeRemaining)

                VStack(spacing: 2) {
                    Text(formattedTime(focus: focus))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)

                    if isPaused {
                        Text("pause")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(width: 140, height: 140)

            // Controls
            HStack(spacing: 20) {
                Button {
                    viewModel?.stopInlineFocusTimer(messageId: messageId)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Circle())
                }

                Button {
                    if isPaused {
                        viewModel?.resumeInlineFocusTimer(messageId: messageId)
                    } else {
                        viewModel?.pauseInlineFocusTimer(messageId: messageId)
                    }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.black)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Completed View

    private func completedView(focus: ChatCardData.PlanningFocusState) -> some View {
        VStack(spacing: 14) {
            if showConfetti {
                InlineConfettiView()
                    .frame(height: 60)
            }

            VStack(spacing: 6) {
                Text("🔥")
                    .font(.system(size: 40))
                Text("Session terminée !")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                Text("\(focus.duration) minutes de focus")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.5))
            }
            .padding(.top, 16)

            if focus.activeTaskId != nil, let title = focus.activeTaskTitle {
                VStack(spacing: 10) {
                    Text("Tu as terminé « \(title) » ?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button {
                            viewModel?.validateFocusTimerTask(messageId: messageId, completed: false)
                        } label: {
                            Text("Pas encore")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.06))
                                .cornerRadius(12)
                        }

                        Button {
                            viewModel?.validateFocusTimerTask(messageId: messageId, completed: true)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Oui !")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                    }
                }
            } else {
                Button {
                    viewModel?.validateFocusTimerTask(messageId: messageId, completed: false)
                } label: {
                    Text("Fermer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.06))
                        .cornerRadius(12)
                }
            }

            Spacer().frame(height: 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showConfetti = true
            }
        }
    }

    // MARK: - Helpers

    private func timerProgress(focus: ChatCardData.PlanningFocusState) -> Double {
        let total = Double(focus.duration * 60)
        guard total > 0, let remaining = focus.timeRemaining else { return 0 }
        return 1.0 - (Double(remaining) / total)
    }

    private func formattedTime(focus: ChatCardData.PlanningFocusState) -> String {
        let remaining = focus.timeRemaining ?? 0
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Inline Confetti View

struct InlineConfettiView: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, rotation: Double)] = []

    private let colors: [Color] = [.orange, .yellow, .red, .green, .blue, .purple]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { particle in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(particle.color)
                        .frame(width: 6, height: 10)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                for i in 0..<20 {
                    let x = CGFloat.random(in: 0...geo.size.width)
                    particles.append((
                        id: i,
                        x: x,
                        y: -10,
                        color: colors.randomElement()!,
                        rotation: Double.random(in: 0...360)
                    ))
                }

                withAnimation(.easeIn(duration: 1.2)) {
                    for i in particles.indices {
                        particles[i].y = CGFloat.random(in: 20...60)
                        particles[i].rotation += Double.random(in: 90...270)
                    }
                }

                // Fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        particles.removeAll()
                    }
                }
            }
        }
    }
}

// MARK: - Video Suggestions Card

struct VideoSuggestionsCard: View {
    let data: ChatCardData.VideoSuggestionsData
    let messageId: UUID
    var viewModel: ChatViewModel?

    private var categoryLabel: String {
        switch data.category {
        case "meditation": return "Méditation"
        case "breathing": return "Respiration"
        case "motivation": return "Motivation"
        case "prayer": return "Prière"
        default: return data.category.capitalized
        }
    }

    private var categoryIcon: String {
        switch data.category {
        case "meditation": return "brain.head.profile"
        case "breathing": return "wind"
        case "motivation": return "bolt.fill"
        case "prayer": return "hands.sparkles.fill"
        default: return "play.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                Text("Vidéos de \(categoryLabel)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Video list
            ForEach(Array(data.videos.enumerated()), id: \.element.id) { index, video in
                HStack(spacing: 12) {
                    // YouTube thumbnail
                    AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.videoId)/mqdefault.jpg")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.black.opacity(0.3))
                                )
                        default:
                            Rectangle()
                                .fill(Color.black.opacity(0.05))
                                .overlay(ProgressView().tint(.black.opacity(0.3)))
                        }
                    }
                    .frame(width: 100, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Title + duration
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.85))
                            .lineLimit(2)
                        Text(video.duration)
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.4))
                    }

                    Spacer()

                    // Choose button
                    Button {
                        viewModel?.selectSuggestedVideo(messageId: messageId, video: video)
                    } label: {
                        Text("Choisir")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if index < data.videos.count - 1 {
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.leading, 128)
                }
            }

            Spacer().frame(height: 6)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Inline Video Card

struct InlineVideoCard: View {
    let video: ChatCardData.VideoCard
    let messageId: UUID
    var viewModel: ChatViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                if video.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Terminé")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // YouTube Player (tap to play in Safari)
            YouTubePlayerView(videoId: video.videoId)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)

            // "J'ai fini" button
            if !video.isCompleted {
                Button {
                    viewModel?.videoCompleted(messageId: messageId)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("J'ai fini la vidéo")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.black.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }

            Spacer().frame(height: 4)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - YouTube Player (WKWebView with Safari user-agent)

struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String

    /// Bundle-ID origin — WKWebView sends this as HTTP Referer, which YouTube requires for embeds
    private static let origin: String = {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jep.volta"
        return "https://\(bundleID)".lowercased()
    }()

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
            * { margin: 0; padding: 0; }
            html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
            iframe { width: 100%; height: 100%; border: none; }
        </style>
        </head>
        <body>
        <iframe
            src="https://www.youtube.com/embed/\(videoId)?playsinline=1&rel=0&modestbranding=1&origin=\(Self.origin)"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen>
        </iframe>
        </body>
        </html>
        """

        // baseURL sets the security origin → WKWebView sends it as Referer header to YouTube
        webView.loadHTMLString(html, baseURL: URL(string: Self.origin))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                // Allow YouTube embed, API, and media resources
                if url.contains("youtube.com/embed") ||
                   url.contains("youtube-nocookie.com/embed") ||
                   url.contains("youtube.com/iframe_api") ||
                   url.contains("accounts.google.com") ||
                   url.contains("ytimg.com") ||
                   url.contains("googlevideo.com") ||
                   url.contains("google.com/recaptcha") ||
                   url.contains("gstatic.com") ||
                   url.hasPrefix(Self.bundleOrigin) ||
                   navigationAction.navigationType == .other {
                    decisionHandler(.allow)
                    return
                }
            }
            decisionHandler(.cancel)
        }

        private static let bundleOrigin: String = {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.jep.volta"
            return "https://\(bundleID)".lowercased()
        }()
    }
}

// MARK: - Typing Dots Animation

struct TypingDotsView: View {
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .offset(y: dotOffsets[index])
            }
        }
        .onAppear {
            for i in 0..<3 {
                withAnimation(
                    .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
                ) {
                    dotOffsets[i] = -5
                }
            }
        }
    }
}

// MARK: - App Blocking Banner

struct AppBlockingBanner: View {
    @State private var elapsedSeconds: Int = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Text("Apps bloquées")
                .font(.satoshi(13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Text("·")
                .foregroundColor(.white.opacity(0.4))

            Text(formatElapsed(elapsedSeconds))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "#1A1B21"))
        .cornerRadius(20)
        .onReceive(timer) { _ in
            elapsedSeconds += 1
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Audio Player Manager

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0

    func play(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Audio file not found at: \(url.path)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                self.progress = player.currentTime / player.duration
            }
        } catch {
            print("Playback error: \(error)")
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 0
        currentTime = 0
        timer?.invalidate()
    }
}

// MARK: - Voice Recorder Manager

class VoiceRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL?

    @Published var isRecording = false

    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("voice_\(UUID().uuidString).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            audioURL = audioFilename
            isRecording = true
        } catch {
            print("Recording failed: \(error)")
        }
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return audioURL
    }
}

// MARK: - Settings Page View (full screen wrapper for fade transition)

struct SettingsPageView: View {
    var onDismiss: () -> Void
    @EnvironmentObject var store: FocusAppStore

    var body: some View {
        SettingsView(onDismiss: onDismiss)
            .environmentObject(store)
    }
}

// MARK: - Preview

#Preview {
    ChatView()
        .environmentObject(FocusAppStore.shared)
        .environmentObject(SubscriptionManager.shared)
}
