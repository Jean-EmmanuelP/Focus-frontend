import SwiftUI
import AVFoundation
import Combine

enum RecordingMode: String, CaseIterable {
    case audio = "audio"
    case video = "video"

    var icon: String {
        switch self {
        case .audio: return "mic.fill"
        case .video: return "video.fill"
        }
    }

    var label: String {
        switch self {
        case .audio: return "journal.mode_audio".localized
        case .video: return "journal.mode_video".localized
        }
    }
}

struct JournalRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioRecorder = AudioRecorder()

    let onSave: (JournalEntryResponse) -> Void

    @State private var recordingMode: RecordingMode = .audio
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var savedEntry: JournalEntryResponse?
    @State private var showSuccess = false
    @State private var showVideoRecorder = false

    private let maxDuration: TimeInterval = 180 // 3 minutes

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: SpacingTokens.xl) {
                    // Mode toggle
                    modeToggle
                        .padding(.top, SpacingTokens.lg)

                    Spacer()

                    // Audio recording UI
                    audioRecordingView

                    Spacer()

                    // Error message
                    if let error = uploadError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ColorTokens.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()

                // Loading overlay
                if isUploading {
                    uploadingOverlay
                }

                // Success overlay
                if showSuccess, let entry = savedEntry {
                    successOverlay(entry: entry)
                }
            }
            .navigationTitle("journal.record".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        audioRecorder.cleanup()
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showVideoRecorder) {
                FullScreenVideoRecorderView(
                    maxDuration: maxDuration,
                    onSave: { videoData, duration in
                        uploadMedia(data: videoData, mediaType: "video", contentType: "video/mp4", duration: duration)
                    },
                    onCancel: {
                        showVideoRecorder = false
                    }
                )
            }
            .onChange(of: recordingMode) { _, newMode in
                if newMode == .video {
                    showVideoRecorder = true
                    recordingMode = .audio // Reset so user can tap again
                }
            }
        }
        .onDisappear {
            audioRecorder.cleanup()
        }
    }

    // MARK: - Mode Toggle
    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(RecordingMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        recordingMode = mode
                    }
                }) {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(mode.label)
                            .font(.inter(14, weight: .medium))
                    }
                    .foregroundColor(recordingMode == mode ? .white : ColorTokens.textSecondary)
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.vertical, SpacingTokens.sm)
                    .background(
                        recordingMode == mode ?
                        LinearGradient(colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(RadiusTokens.full)
                }
                .disabled(audioRecorder.isRecording)
            }
        }
        .padding(4)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.full)
    }

    // MARK: - Audio Recording View
    private var audioRecordingView: some View {
        VStack(spacing: SpacingTokens.xl) {
            timerDisplay(time: audioRecorder.recordingTime, isRecording: audioRecorder.isRecording)
            waveformView
            audioRecordButton
            instructionText
        }
    }

    // MARK: - Timer Display
    private func timerDisplay(time: TimeInterval, isRecording: Bool) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(formatTime(time))
                .font(.system(size: 64, weight: .light, design: .monospaced))
                .foregroundColor(isRecording ? ColorTokens.error : ColorTokens.textPrimary)

            Text("journal.max_duration".localized)
                .font(.caption)
                .foregroundColor(ColorTokens.textMuted)
        }
    }

    // MARK: - Waveform
    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(audioRecorder.isRecording ? ColorTokens.primaryStart : ColorTokens.textMuted.opacity(0.3))
                    .frame(width: 4, height: waveformHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: audioRecorder.audioLevel)
            }
        }
        .frame(height: 60)
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        guard audioRecorder.isRecording else { return 10 }
        let baseHeight: CGFloat = 10
        let maxHeight: CGFloat = 60
        let level = CGFloat(audioRecorder.audioLevel)
        let variation = sin(Double(index) * 0.5 + audioRecorder.recordingTime * 2) * 0.3
        return baseHeight + (maxHeight - baseHeight) * level * (0.7 + CGFloat(variation))
    }

    // MARK: - Instruction Text
    private var instructionText: some View {
        Text(audioRecorder.isRecording ? "journal.recording".localized :
             (audioRecorder.hasRecording ? "journal.tap_to_rerecord".localized : "journal.tap_to_record".localized))
            .font(.subheadline)
            .foregroundColor(ColorTokens.textSecondary)
    }

    // MARK: - Audio Record Button
    @ViewBuilder
    private var audioRecordButton: some View {
        VStack(spacing: SpacingTokens.lg) {
            Button(action: toggleAudioRecording) {
                ZStack {
                    Circle()
                        .stroke(audioRecorder.isRecording ? ColorTokens.error : ColorTokens.primaryStart, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    if audioRecorder.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.error)
                            .frame(width: 28, height: 28)
                    } else if audioRecorder.hasRecording {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(ColorTokens.primaryStart)
                    } else {
                        Circle()
                            .fill(ColorTokens.error)
                            .frame(width: 56, height: 56)
                    }
                }
            }
            .disabled(isUploading)

            if audioRecorder.hasRecording && !audioRecorder.isRecording {
                saveButton(action: saveAudioRecording)
            }
        }
    }

    // MARK: - Save Button
    private func saveButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("journal.save".localized)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, SpacingTokens.xl)
            .padding(.vertical, SpacingTokens.md)
            .background(
                LinearGradient(colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(RadiusTokens.full)
        }
        .disabled(isUploading)
    }

    // MARK: - Uploading Overlay
    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("journal.uploading".localized)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("journal.uploading_subtitle".localized)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(SpacingTokens.xl)
        }
    }

    // MARK: - Success Overlay
    private func successOverlay(entry: JournalEntryResponse) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ColorTokens.success)

                Text("journal.entry_saved".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("journal.saved_subtitle".localized)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    onSave(entry)
                    dismiss()
                }) {
                    Text("done".localized)
                        .font(.headline)
                        .foregroundColor(ColorTokens.primaryStart)
                        .padding(.horizontal, SpacingTokens.xl)
                        .padding(.vertical, SpacingTokens.md)
                        .background(Color.white)
                        .cornerRadius(RadiusTokens.full)
                }
                .padding(.top, SpacingTokens.md)
            }
            .padding(SpacingTokens.xl)
        }
    }

    // MARK: - Actions
    private func toggleAudioRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
        } else {
            audioRecorder.startRecording(maxDuration: maxDuration)
        }
    }

    private func saveAudioRecording() {
        guard let audioData = audioRecorder.getRecordingData() else {
            uploadError = "journal.error.no_recording".localized
            return
        }
        uploadMedia(data: audioData, mediaType: "audio", contentType: "audio/m4a", duration: Int(audioRecorder.recordingTime))
    }

    private func uploadMedia(data: Data, mediaType: String, contentType: String, duration: Int) {
        isUploading = true
        uploadError = nil
        showVideoRecorder = false

        Task {
            do {
                let service = JournalService()
                let entry = try await service.createEntry(
                    mediaData: data,
                    mediaType: mediaType,
                    contentType: contentType,
                    durationSeconds: duration
                )
                savedEntry = entry
                showSuccess = true
            } catch {
                uploadError = error.localizedDescription
            }
            isUploading = false
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Recorder
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var hasRecording = false

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    private var maxDuration: TimeInterval = 180

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func startRecording(maxDuration: TimeInterval) {
        self.maxDuration = maxDuration

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async {
                self?.beginRecording()
            }
        }
    }

    private func beginRecording() {
        setupAudioSession()

        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("journal_\(UUID().uuidString).m4a")

        guard let url = recordingURL else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            recordingTime = 0
            hasRecording = false

            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.recordingTime += 1
                    if self.recordingTime >= self.maxDuration {
                        self.stopRecording()
                    }
                }
            }

            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateAudioLevel()
                }
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        audioLevel = max(0, min(1, (level + 50) / 50))
    }

    func stopRecording() {
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil

        audioRecorder?.stop()
        isRecording = false
        audioLevel = 0
        hasRecording = recordingURL != nil
    }

    func getRecordingData() -> Data? {
        guard let url = recordingURL else { return nil }
        return try? Data(contentsOf: url)
    }

    func cleanup() {
        stopRecording()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        hasRecording = false
        recordingTime = 0
    }
}

// MARK: - Full Screen Video Recorder (Instagram Style)
struct FullScreenVideoRecorderView: View {
    let maxDuration: TimeInterval
    let onSave: (Data, Int) -> Void
    let onCancel: () -> Void

    @StateObject private var camera = CameraModel()
    @State private var isUploading = false

    var body: some View {
        ZStack {
            // Full screen camera preview
            CameraPreview(camera: camera)
                .ignoresSafeArea()

            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    // Close button
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Recording timer
                    if camera.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text(formatTime(camera.recordingTime))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                    }

                    Spacer()

                    // Switch camera button
                    Button(action: { camera.switchCamera() }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(camera.isRecording)
                    .opacity(camera.isRecording ? 0.5 : 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Bottom controls
                VStack(spacing: 16) {
                    // Duration info or recorded duration
                    if camera.hasRecording && !camera.isRecording {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ColorTokens.success)
                            Text(formatTime(camera.recordingTime) + " " + "journal.recorded".localized)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    } else if !camera.isRecording {
                        Text("journal.max_duration".localized)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Main controls row
                    HStack {
                        // Re-record button (left)
                        if camera.hasRecording && !camera.isRecording {
                            Button(action: { camera.resetRecording() }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        } else {
                            Color.clear.frame(width: 60, height: 60)
                        }

                        Spacer()

                        // Main record button (center)
                        Button(action: {
                            if camera.isRecording {
                                camera.stopRecording()
                            } else if camera.hasRecording {
                                if let data = camera.getRecordingData() {
                                    onSave(data, Int(camera.recordingTime))
                                }
                            } else {
                                camera.startRecording(maxDuration: maxDuration)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 80, height: 80)

                                if camera.isRecording {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red)
                                        .frame(width: 30, height: 30)
                                } else if camera.hasRecording {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 64, height: 64)
                                }
                            }
                        }

                        Spacer()

                        // Spacer for symmetry (right)
                        Color.clear.frame(width: 60, height: 60)
                    }
                    .padding(.horizontal, 40)

                    // Instruction text
                    Text(camera.isRecording ? "journal.recording".localized :
                         (camera.hasRecording ? "journal.tap_to_save".localized : "journal.tap_to_record".localized))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
            }

            // Loading overlay
            if isUploading {
                Color.black.opacity(0.7).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .onAppear {
            camera.checkPermissions()
        }
        .onDisappear {
            camera.cleanup()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Camera Model
class CameraModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var hasRecording = false
    @Published var session = AVCaptureSession()

    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    private var timer: Timer?
    private var recordingURL: URL?
    private var maxDuration: TimeInterval = 180

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            checkAudioPermission()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.checkAudioPermission()
                }
            }
        default:
            break
        }
    }

    private func checkAudioPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            DispatchQueue.main.async {
                self.setupCamera()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }

    func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        // Video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(videoInput)

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Movie output
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            videoOutput = movieOutput

            // Set video orientation
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                if connection.isVideoMirroringSupported && currentCameraPosition == .front {
                    connection.isVideoMirrored = true
                }
            }
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func switchCamera() {
        currentCameraPosition = currentCameraPosition == .front ? .back : .front
        setupCamera()
    }

    func startRecording(maxDuration: TimeInterval) {
        guard let output = videoOutput, !output.isRecording else { return }

        self.maxDuration = maxDuration

        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("journal_video_\(UUID().uuidString).mp4")
        recordingURL = url

        output.startRecording(to: url, recordingDelegate: self)

        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingTime = 0
            self.hasRecording = false
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.recordingTime += 1
                if self.recordingTime >= self.maxDuration {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        timer?.invalidate()
        timer = nil
        videoOutput?.stopRecording()
    }

    func resetRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        hasRecording = false
        recordingTime = 0
    }

    func getRecordingData() -> Data? {
        guard let url = recordingURL else { return nil }
        return try? Data(contentsOf: url)
    }

    func cleanup() {
        stopRecording()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        hasRecording = false
        recordingTime = 0

        if session.isRunning {
            session.stopRunning()
        }
    }
}

extension CameraModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            if error == nil {
                self.hasRecording = true
            } else {
                print("Video recording error: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = camera.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // Update if needed
    }
}

class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
}

#Preview {
    JournalRecorderView { _ in }
}
