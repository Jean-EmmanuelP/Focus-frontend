import SwiftUI
import AVFoundation
import Combine

// MARK: - WhatsApp-Style Chat View (Exact Colors)

struct ChatView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showProfile = false

    // Recording state
    @StateObject private var audioRecorder = VoiceRecorderManager()
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingTimer: Timer?

    // EXACT WhatsApp colors (from official app)
    private let whatsAppHeaderGreen = Color(hex: "075E54")
    private let whatsAppSendGreen = Color(hex: "00A884")
    private let chatBackground = Color(hex: "ECE5DD")
    private let userBubbleColor = Color(hex: "DCF8C6")
    private let aiBubbleColor = Color.white
    private let inputBarBackground = Color(hex: "F0F0F0")

    var body: some View {
        ZStack {
            chatBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                chatHeader
                messagesView
                inputBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setStore(store)
            viewModel.loadHistory()
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .environmentObject(store)
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text("🔥")
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Kai")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Text(viewModel.isLoading ? "écrit..." : "en ligne")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button { showProfile = true } label: { profileAvatar }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(whatsAppHeaderGreen)
    }

    private var profileAvatar: some View {
        Group {
            if let avatarUrl = store.user?.avatarURL, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.3))
                        .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "person.fill").foregroundColor(.white))
            }
        }
    }

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.messages) { message in
                        WhatsAppBubble(
                            message: message,
                            userBubbleColor: userBubbleColor,
                            aiBubbleColor: aiBubbleColor
                        )
                        .id(message.id)
                    }

                    if viewModel.isLoading {
                        typingIndicator
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
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

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(18)
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Text field
            HStack {
                TextField("Message", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
            }
            .background(Color.white)
            .cornerRadius(24)

            // Send or Mic button
            if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Mic button - immediate press to record
                MicRecordButton(
                    isRecording: $isRecording,
                    recordingTime: $recordingTime,
                    onStartRecording: startRecording,
                    onStopRecording: stopRecordingAndSend,
                    backgroundColor: whatsAppSendGreen
                )
            } else {
                // Send button
                Button {
                    viewModel.sendMessage()
                    isInputFocused = false
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(whatsAppSendGreen)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(inputBarBackground)
        .overlay(alignment: .top) {
            if isRecording {
                recordingIndicatorView
            }
        }
    }

    private var recordingIndicatorView: some View {
        HStack {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)

            Text(formatTime(recordingTime))
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(.red)

            Spacer()

            Text("Relâcher pour envoyer")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .padding(.horizontal, 8)
        .offset(y: -60)
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

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Mic Record Button (Immediate Response)

struct MicRecordButton: View {
    @Binding var isRecording: Bool
    @Binding var recordingTime: TimeInterval
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let backgroundColor: Color

    @GestureState private var isPressed = false

    var body: some View {
        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
            .font(.system(size: 20))
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .background(isRecording ? Color.red : backgroundColor)
            .clipShape(Circle())
            .scaleEffect(isPressed ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
                    .onChanged { _ in
                        if !isRecording {
                            onStartRecording()
                        }
                    }
                    .onEnded { _ in
                        if isRecording {
                            onStopRecording()
                        }
                    }
            )
    }
}

// MARK: - WhatsApp Message Bubble

struct WhatsAppBubble: View {
    let message: SimpleChatMessage
    let userBubbleColor: Color
    let aiBubbleColor: Color

    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var isDownloading = false
    @State private var downloadedLocalURL: URL?

    var body: some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 60) }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 1) {
                if message.type == .voice {
                    voiceMessageBubble
                } else {
                    textMessageBubble
                }
            }

            if !message.isFromUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    private var textMessageBubble: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(message.content)
                .font(.system(size: 16))
                .foregroundColor(.black)

            Text(formatTime(message.timestamp))
                .font(.system(size: 11))
                .foregroundColor(Color.gray.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(message.isFromUser ? userBubbleColor : aiBubbleColor)
        .cornerRadius(16)
    }

    // Check if audio is available (locally or can be downloaded)
    private var audioAvailable: Bool {
        message.hasLocalAudio || message.voiceStoragePath != nil || downloadedLocalURL != nil
    }

    // Get the URL to play (local or downloaded)
    private var playableURL: URL? {
        if let downloaded = downloadedLocalURL {
            return downloaded
        }
        return message.localVoiceURL
    }

    private var voiceMessageBubble: some View {
        HStack(spacing: 10) {
            // Play/Pause/Download button
            Button {
                if audioPlayer.isPlaying {
                    audioPlayer.pause()
                } else if let url = playableURL, FileManager.default.fileExists(atPath: url.path) {
                    audioPlayer.play(url: url)
                } else if message.voiceStoragePath != nil {
                    // Need to download from Supabase
                    downloadAndPlay()
                }
            } label: {
                if isDownloading {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: audioAvailable ? (audioPlayer.isPlaying ? "pause.fill" : "play.fill") : "icloud.and.arrow.down")
                        .font(.system(size: 20))
                        .foregroundColor(audioAvailable ? Color(hex: "075E54") : Color.gray)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .disabled(isDownloading || (!audioAvailable && message.voiceStoragePath == nil))

            // Waveform + progress
            VStack(alignment: .leading, spacing: 4) {
                // Waveform
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(0..<30, id: \.self) { i in
                            let progress = audioPlayer.isPlaying ? audioPlayer.progress : 0
                            let isPlayed = Double(i) / 30.0 < progress
                            RoundedRectangle(cornerRadius: 1)
                                .fill(isPlayed ? Color(hex: "075E54") : Color.gray.opacity(0.4))
                                .frame(width: 3, height: waveformHeight(for: i))
                        }
                    }
                    .frame(height: 24)
                }
                .frame(width: 120, height: 24)

                // Duration
                HStack {
                    Text(formatDuration(audioPlayer.isPlaying ? audioPlayer.currentTime : (message.voiceDuration ?? 0)))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)

                    Spacer()

                    Text(formatTime(message.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(Color.gray.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(message.isFromUser ? userBubbleColor : aiBubbleColor)
        .cornerRadius(16)
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        // Pseudo-random heights for visual effect
        let heights: [CGFloat] = [8, 14, 10, 18, 12, 20, 8, 16, 14, 10, 18, 8, 14, 20, 10, 16, 12, 18, 8, 14, 10, 20, 16, 12, 8, 18, 14, 10, 16, 12]
        return heights[index % heights.count]
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // Download audio from Supabase and cache locally
    private func downloadAndPlay() {
        guard let storagePath = message.voiceStoragePath else { return }

        isDownloading = true

        Task {
            do {
                // Download from Supabase
                let audioData = try await SupabaseStorageService.shared.downloadVoiceMessage(from: storagePath)

                // Save to local cache
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
                    // Auto-play after download
                    audioPlayer.play(url: localURL)
                }

                print("✅ Downloaded and cached voice message: \(filename)")
            } catch {
                await MainActor.run {
                    isDownloading = false
                }
                print("❌ Failed to download voice message: \(error)")
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
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Audio file not found at: \(url.path)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
            print("▶️ Playing audio from: \(url.lastPathComponent)")

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                self.progress = player.currentTime / player.duration
            }
        } catch {
            print("❌ Playback error: \(error)")
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
}
