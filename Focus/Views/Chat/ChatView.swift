import SwiftUI
import AVFoundation
import Combine

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
    @State private var showThoughtsSheet = false
    @State private var showTrainingSheet = false
    @State private var showCompanionProfile = false
    @State private var showVoiceCall = false
    @State private var isHomeMode = false  // Toggle between home view and chat view

    @EnvironmentObject var revenueCatManager: RevenueCatManager

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
            if showThoughtsSheet {
                ChatFeatureOverlayContent(
                    featureType: .thoughts,
                    companionName: companionName,
                    onShowPaywall: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPaywall = true
                        }
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showThoughtsSheet = false
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if showTrainingSheet {
                ChatFeatureOverlayContent(
                    featureType: .training,
                    companionName: companionName,
                    onShowPaywall: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPaywall = true
                        }
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showTrainingSheet = false
                        }
                    }
                )
                .transition(.opacity)
            }
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
                .environmentObject(revenueCatManager)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showThoughtsSheet)
        .animation(.easeInOut(duration: 0.25), value: showTrainingSheet)
        .animation(.easeInOut(duration: 0.3), value: showPaywall)
        .onChange(of: showPaywall) { _, isShowing in
            if isShowing {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onChange(of: showThoughtsSheet) { _, isShowing in
            if isShowing {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onChange(of: showTrainingSheet) { _, isShowing in
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
        .fullScreenCover(isPresented: $showVoiceCall) {
            VoiceCallView()
        }
        .onChange(of: isInputFocused) { _, focused in
            // Exit home mode when user starts typing (only if there are messages)
            if focused && isHomeMode && !viewModel.messages.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isHomeMode = false
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
            autoRotate: false
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

            // Center: Name bubble (clickable to open profile)
            Button(action: {
                isInputFocused = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCompanionProfile = true
                }
            }) {
                VStack(spacing: 1) {
                    Text(companionName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Votre Ami")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
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

    private var isShowingFeatureOverlay: Bool {
        showThoughtsSheet || showTrainingSheet
    }

    private var conversationHeader: some View {
        HStack(spacing: 12) {
            // Left: Home button + companion name
            HStack(spacing: 8) {
                Button(action: {
                    isInputFocused = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showThoughtsSheet = false
                        showTrainingSheet = false
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
                    HStack(spacing: 4) {
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

            // Right: Phone, Chat (thoughts) and lightning (training) icons
            HStack(spacing: 8) {
                Button(action: {
                    if revenueCatManager.isProUser {
                        showVoiceCall = true
                    } else {
                        showPaywall = true
                    }
                }) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                        )
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showTrainingSheet = false
                        showThoughtsSheet = true
                    }
                }) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                        )
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showThoughtsSheet = false
                        showTrainingSheet = true
                    }
                }) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                        )
                }
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
                    ForEach(groupedMessages, id: \.date) { group in
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
                    // Delay to let keyboard animation start, then scroll
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.25)) {
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

    // Group messages by date
    private var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []
        var currentDate: Date?
        var currentMessages: [SimpleChatMessage] = []

        for message in viewModel.messages {
            let messageDate = calendar.startOfDay(for: message.timestamp)

            if currentDate == nil {
                currentDate = messageDate
                currentMessages = [message]
            } else if calendar.isDate(messageDate, inSameDayAs: currentDate!) {
                currentMessages.append(message)
            } else {
                groups.append(MessageGroup(date: currentDate!, messages: currentMessages))
                currentDate = messageDate
                currentMessages = [message]
            }
        }

        if let date = currentDate, !currentMessages.isEmpty {
            groups.append(MessageGroup(date: date, messages: currentMessages))
        }

        return groups
    }

    private func dateSeparator(date: Date) -> some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"

        return Text(formatter.string(from: date))
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
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
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
            // Left: Mic button (separate circle, grayish-taupe)
            Button(action: {
                if revenueCatManager.isProUser {
                    if isRecording {
                        stopRecordingAndSend()
                    } else {
                        startRecording()
                    }
                } else {
                    showPaywall = true
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.58, green: 0.53, blue: 0.55)) // Grayish-taupe like Replika
                        .frame(width: 52, height: 52)

                    if isRecording {
                        Image(systemName: "waveform")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.red)
                    } else {
                        // Three dots/bars like Replika mic icon
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: 5, height: [10, 16, 10][i])
                            }
                        }
                    }
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
                    // Plus button inside the capsule
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial) // Blur/glass effect
                    .overlay(
                        Capsule()
                            .fill(Color(red: 0.45, green: 0.50, blue: 0.58).opacity(0.4))
                    )
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

// MARK: - Message Group (for date grouping)

struct MessageGroup {
    let date: Date
    let messages: [SimpleChatMessage]
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
    }

    // MARK: - Card Views

    @ViewBuilder
    private func cardView(for cardData: ChatCardData) -> some View {
        switch cardData {
        case .taskList(let tasks):
            InlineTaskListCard(tasks: tasks, messageId: message.id, viewModel: viewModel)
        case .routineList(let routines):
            InlineRoutineListCard(routines: routines, messageId: message.id, viewModel: viewModel)
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

// MARK: - Inline Task List Card (Google Tasks style)

struct InlineTaskListCard: View {
    let tasks: [ChatCardData.CardTask]
    let messageId: UUID
    var viewModel: ChatViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: 12) {
                    Button {
                        viewModel?.toggleTaskCompletion(messageId: messageId, taskId: task.id)
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(task.isCompleted ? Color.clear : Color.white.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 22, height: 22)

                            if task.isCompleted {
                                Circle()
                                    .fill(Color(hex: "#34C759").opacity(0.9))
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    Text(task.title)
                        .font(.satoshi(15))
                        .foregroundColor(task.isCompleted ? .white.opacity(0.35) : .white.opacity(0.85))
                        .strikethrough(task.isCompleted, color: .white.opacity(0.2))
                        .lineLimit(2)

                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)

                if index < tasks.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 50)
                }
            }
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Inline Routine List Card

struct InlineRoutineListCard: View {
    let routines: [ChatCardData.CardRoutine]
    let messageId: UUID
    var viewModel: ChatViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                HStack(spacing: 12) {
                    Button {
                        viewModel?.toggleRoutineCompletion(messageId: messageId, routineId: routine.id)
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(routine.isCompleted ? Color.clear : Color.white.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 22, height: 22)

                            if routine.isCompleted {
                                Circle()
                                    .fill(Color(hex: "#34C759").opacity(0.9))
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    Text(routine.icon)
                        .font(.system(size: 16))

                    Text(routine.title)
                        .font(.satoshi(15))
                        .foregroundColor(routine.isCompleted ? .white.opacity(0.35) : .white.opacity(0.85))
                        .strikethrough(routine.isCompleted, color: .white.opacity(0.2))
                        .lineLimit(2)

                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)

                if index < routines.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 50)
                }
            }
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
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
        ReplicaSettingsView(onDismiss: onDismiss)
            .environmentObject(store)
    }
}

// MARK: - Preview

#Preview {
    ChatView()
        .environmentObject(FocusAppStore.shared)
        .environmentObject(RevenueCatManager.shared)
}
