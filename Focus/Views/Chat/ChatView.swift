import SwiftUI
import AVFoundation
import Combine

// MARK: - Replika-Style Chat View (Ralph Design)

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

    @EnvironmentObject var revenueCatManager: RevenueCatManager

    // Companion name (from store or default)
    private var companionName: String {
        let name = store.user?.pseudo ?? "Kai"
        return name.isEmpty ? "Kai" : name
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient (light blue/gray like Replika)
                chatBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    chatHeader

                    // Companion name bubble (centered, above avatar)
                    if viewModel.messages.isEmpty {
                        companionNameBubble
                    }

                    // Messages or avatar area
                    if viewModel.messages.isEmpty {
                        // Empty state: show avatar placeholder
                        Spacer()
                        avatarPlaceholder(size: geometry.size)
                        Spacer()
                    } else {
                        // Conversation mode
                        messagesView
                    }

                    // Input bar
                    chatInputBar
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setStore(store)
            viewModel.loadHistory()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .onTapGesture {
            isInputFocused = false
        }
        .sheet(isPresented: $showPaywall) {
            VoltaPaywallView(onComplete: {
                showPaywall = false
            }, onSkip: {
                showPaywall = false
            })
            .environmentObject(revenueCatManager)
        }
    }

    // MARK: - Background

    private var chatBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.72, green: 0.78, blue: 0.88),
                Color(red: 0.80, green: 0.84, blue: 0.92),
                Color(red: 0.88, green: 0.90, blue: 0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            if viewModel.messages.isEmpty {
                // Empty state: menu icon left
                Button(action: { showSettings = true }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.6))
                        )
                }
            } else {
                // Conversation: companion name with chevron
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text(companionName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black.opacity(0.8))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black.opacity(0.4))
                    }
                }
            }

            Spacer()

            // Logo "Focus" centre
            Text("Focus")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black.opacity(0.8))

            Spacer()

            if viewModel.messages.isEmpty {
                // Profile icon
                Button(action: { showSettings = true }) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                        .frame(width: 36, height: 36)
                }
            } else {
                // Phone & video icons
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.black.opacity(0.5))
                    }
                    Button(action: {}) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.black.opacity(0.5))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Companion Name Bubble

    private var companionNameBubble: some View {
        VStack(spacing: 2) {
            Text(companionName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black.opacity(0.8))
            Text("Votre Ami")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.black.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.5))
        )
        .padding(.top, 8)
    }

    // MARK: - Avatar Placeholder

    private func avatarPlaceholder(size: CGSize) -> some View {
        ZStack {
            // Soft glow placeholder for future avatar
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: size.width * 0.35
                    )
                )
                .frame(width: size.width * 0.7, height: size.width * 0.7)

            // Placeholder icon
            Image(systemName: "person.fill")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.15))
        }
    }

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    // Date header
                    Text(currentDateFormatted)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.black.opacity(0.4))
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(viewModel.messages) { message in
                        ReplikaBubble(
                            message: message,
                            userBubbleColor: Color.white,
                            aiBubbleColor: Color.white
                        )
                        .id(message.id)
                    }

                    if viewModel.isLoading {
                        typingIndicator
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: Date())
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(22)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Input Bar (Replika style: mic LEFT, text CENTER, + RIGHT)

    private var chatInputBar: some View {
        HStack(spacing: 10) {
            // Mic button (LEFT) - gray circle
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
                        .fill(Color(white: 0.65).opacity(0.6))
                        .frame(width: 44, height: 44)

                    if isRecording {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
            }

            // Text field (CENTER) - "Votre message"
            HStack(spacing: 0) {
                TextField("", text: $viewModel.inputText, prompt: Text("Votre message").foregroundColor(.black.opacity(0.35)))
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .focused($isInputFocused)

                if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        viewModel.sendMessage()
                        isInputFocused = false
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 0.0, green: 0.4, blue: 1.0))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.7))
            )

            // "+" button (RIGHT) - dark circle
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.20))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
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

// MARK: - Replika Message Bubble

struct ReplikaBubble: View {
    let message: SimpleChatMessage
    let userBubbleColor: Color
    let aiBubbleColor: Color

    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var isDownloading = false
    @State private var downloadedLocalURL: URL?

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isFromUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                if message.type == .voice {
                    voiceMessageBubble
                } else {
                    textBubble
                }
            }

            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
    }

    private var textBubble: some View {
        Text(message.content)
            .font(.system(size: 16))
            .foregroundColor(.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(22)
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
        HStack(spacing: 12) {
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
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 32, height: 32)
                }
            }

            // Waveform
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    let progress = audioPlayer.isPlaying ? audioPlayer.progress : 0
                    let isPlayed = Double(i) / 20.0 < progress
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPlayed ? Color.black : Color.black.opacity(0.2))
                        .frame(width: 3, height: waveformHeight(for: i))
                }
            }
            .frame(height: 20)

            Text(formatDuration(message.voiceDuration ?? 0))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.black.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(22)
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

// MARK: - Preview

#Preview {
    ChatView()
        .environmentObject(FocusAppStore.shared)
        .environmentObject(RevenueCatManager.shared)
}
