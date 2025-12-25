import SwiftUI
import AVFoundation
import AVKit
import Combine

struct JournalEntryView: View {
    let entry: JournalEntryResponse
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var showDeleteConfirmation = false

    init(entry: JournalEntryResponse, onDelete: (() -> Void)? = nil) {
        self.entry = entry
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                // Header with date and mood
                headerSection

                // Media player (video or audio)
                if entry.mediaType == "video" {
                    videoPlayerSection
                } else {
                    audioPlayerSection
                }

                // Analysis pending notice (if no analysis yet)
                if entry.title == nil && entry.summary == nil && entry.mood == nil {
                    analysisPendingSection
                }

                // Title and summary
                if let title = entry.title {
                    titleSection(title)
                }

                if let summary = entry.summary {
                    summarySection(summary)
                }

                // Tags
                if let tags = entry.tags, !tags.isEmpty {
                    tagsSection(tags)
                }

                // Transcript
                if let transcript = entry.transcript, !transcript.isEmpty {
                    transcriptSection(transcript)
                }
            }
            .padding()
        }
        .background(ColorTokens.background)
        .navigationTitle(formattedDate)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onDelete != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(ColorTokens.error)
                    }
                }
            }
        }
        .confirmationDialog(
            "journal.delete_confirm".localized,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("delete".localized, role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("cancel".localized, role: .cancel) {}
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text(formattedDate)
                    .font(.headline)
                    .foregroundColor(ColorTokens.textPrimary)

                HStack(spacing: SpacingTokens.sm) {
                    // Media type badge
                    HStack(spacing: 4) {
                        Image(systemName: entry.mediaType == "video" ? "video.fill" : "mic.fill")
                            .font(.caption2)
                        Text(entry.mediaType == "video" ? "journal.mode_video".localized : "journal.mode_audio".localized)
                            .font(.caption)
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, 4)
                    .background(ColorTokens.primaryStart.opacity(0.1))
                    .cornerRadius(RadiusTokens.full)

                    Text(entry.formattedDuration)
                        .font(.caption)
                        .foregroundColor(ColorTokens.textMuted)
                }
            }

            Spacer()

            // Mood badge
            if let mood = entry.mood, let score = entry.moodScore {
                VStack(spacing: SpacingTokens.xs) {
                    Text(entry.moodEmoji)
                        .font(.largeTitle)

                    Text("\(score)/10")
                        .font(.caption)
                        .foregroundColor(ColorTokens.textMuted)
                }
                .padding(SpacingTokens.sm)
                .background(moodColor.opacity(0.1))
                .cornerRadius(RadiusTokens.md)
            }
        }
        .padding()
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Video Player Section
    private var videoPlayerSection: some View {
        VStack(spacing: 0) {
            if let url = URL(string: entry.mediaUrl) {
                VideoPlayerView(url: url)
                    .frame(height: 280)
                    .cornerRadius(RadiusTokens.lg)
            }
        }
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Audio Player Section
    private var audioPlayerSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // Waveform visualization
            HStack(spacing: 2) {
                ForEach(0..<30, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            index < Int(audioPlayer.progress * 30) ?
                            LinearGradient(colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd], startPoint: .bottom, endPoint: .top) :
                            LinearGradient(colors: [ColorTokens.textMuted.opacity(0.3)], startPoint: .bottom, endPoint: .top)
                        )
                        .frame(width: 3, height: waveformBarHeight(for: index))
                }
            }
            .frame(height: 40)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorTokens.textMuted.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geometry.size.width * audioPlayer.progress, height: 4)
                }
            }
            .frame(height: 4)

            // Time labels
            HStack {
                Text(formatTime(audioPlayer.currentTime))
                    .font(.caption)
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                Text(formatTime(TimeInterval(entry.durationSeconds)))
                    .font(.caption)
                    .foregroundColor(ColorTokens.textMuted)
            }

            // Play button
            Button(action: togglePlayback) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .offset(x: audioPlayer.isPlaying ? 0 : 2)
                }
            }
        }
        .padding()
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Analysis Pending Section
    private var analysisPendingSection: some View {
        HStack(spacing: SpacingTokens.md) {
            // Animated loader
            AnalysisLoaderView()

            VStack(alignment: .leading, spacing: 4) {
                Text("journal.recorded".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("journal.analysis_pending".localized)
                    .font(.caption)
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(ColorTokens.warning.opacity(0.1))
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Title Section
    private func titleSection(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("journal.title_label".localized)
                .font(.caption)
                .foregroundColor(ColorTokens.textMuted)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(ColorTokens.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Summary Section
    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("journal.summary_label".localized)
                .font(.caption)
                .foregroundColor(ColorTokens.textMuted)

            Text(summary)
                .font(.body)
                .foregroundColor(ColorTokens.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Tags Section
    private func tagsSection(_ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("journal.tags_label".localized)
                .font(.caption)
                .foregroundColor(ColorTokens.textMuted)

            JournalTagFlowLayout(spacing: SpacingTokens.sm) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .foregroundColor(ColorTokens.primaryStart)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xs)
                        .background(ColorTokens.primaryStart.opacity(0.1))
                        .cornerRadius(RadiusTokens.full)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Transcript Section
    private func transcriptSection(_ transcript: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("journal.transcript_label".localized)
                    .font(.caption)
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundColor(ColorTokens.textMuted)
            }

            Text(transcript)
                .font(.body)
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Helpers
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: entry.entryDate) else { return entry.entryDate }
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private var moodColor: Color {
        switch entry.mood {
        case "great": return .green
        case "good": return .blue
        case "neutral": return .gray
        case "low": return .orange
        case "bad": return .red
        default: return .gray
        }
    }

    private func waveformBarHeight(for index: Int) -> CGFloat {
        // Generate pseudo-random heights based on index
        let heights: [CGFloat] = [15, 25, 35, 20, 40, 30, 25, 35, 20, 30, 40, 25, 35, 20, 30, 25, 40, 35, 20, 30, 25, 35, 40, 20, 30, 35, 25, 40, 30, 35]
        return heights[index % heights.count]
    }

    private func togglePlayback() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.play(url: entry.mediaUrl)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Analysis Loader View (Animated)
struct AnalysisLoaderView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Outer rotating ring
            Circle()
                .stroke(ColorTokens.warning.opacity(0.3), lineWidth: 3)
                .frame(width: 44, height: 44)

            // Animated arc
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(ColorTokens.warning, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )

            // Brain/AI emoji in center
            Text("🧠")
                .font(.system(size: 20))
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
            }

            // Play button overlay when paused
            if !isPlaying {
                Button(action: togglePlay) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 70, height: 70)

                        Image(systemName: "play.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .offset(x: 3)
                    }
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
    }

    private func setupPlayer() {
        player = AVPlayer(url: url)

        // Observe playback status
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            player?.seek(to: .zero)
        }
    }

    private func togglePlay() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

// MARK: - Audio Player
class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var progress: CGFloat = 0

    private var player: AVPlayer?
    private var timeObserver: Any?

    func play(url: String) {
        guard let audioURL = URL(string: url) else { return }

        if player == nil {
            let playerItem = AVPlayerItem(url: audioURL)
            player = AVPlayer(playerItem: playerItem)

            // Add time observer
            timeObserver = player?.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self = self,
                      let duration = self.player?.currentItem?.duration.seconds,
                      duration.isFinite else { return }

                self.currentTime = time.seconds
                self.progress = CGFloat(time.seconds / duration)
            }

            // Observe end of playback
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem
            )
        }

        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        currentTime = 0
        progress = 0
    }

    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        currentTime = 0
        progress = 0
        player?.seek(to: .zero)
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Tag Flow Layout for Journal
struct JournalTagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)

                if x + viewSize.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, viewSize.height)
                x += viewSize.width + spacing
            }

            size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    NavigationStack {
        JournalEntryView(
            entry: JournalEntryResponse(
                id: "1",
                userId: "user1",
                mediaType: "video",
                mediaUrl: "https://example.com/video.mp4",
                durationSeconds: 95,
                transcript: "Today was a productive day. I managed to complete the feature I was working on and also had a great workout session. Feeling accomplished!",
                summary: "- Completed major feature\n- Great workout\n- Feeling accomplished",
                title: "Productive Monday",
                mood: "great",
                moodScore: 8,
                tags: ["productivity", "health", "work"],
                entryDate: "2024-01-15",
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
}
