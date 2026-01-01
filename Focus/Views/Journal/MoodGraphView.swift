import SwiftUI

struct MoodGraphView: View {
    let moodData: [MoodDataPoint]
    var height: CGFloat = 100
    var showLabels: Bool = true

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            if moodData.isEmpty {
                emptyState
            } else {
                graphContent
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text("journal.no_mood_data".localized)
                .font(.caption)
                .foregroundColor(ColorTokens.textMuted)
        }
        .frame(height: height)
    }

    // MARK: - Graph Content
    private var graphContent: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let graphHeight = height - (showLabels ? 24 : 0)
            let pointSpacing = width / CGFloat(max(moodData.count - 1, 1))

            ZStack(alignment: .bottom) {
                // Background grid lines
                gridLines(height: graphHeight)

                // Gradient fill
                gradientFill(width: width, height: graphHeight, pointSpacing: pointSpacing)

                // Line
                moodLine(width: width, height: graphHeight, pointSpacing: pointSpacing)

                // Points
                moodPoints(width: width, height: graphHeight, pointSpacing: pointSpacing)
            }

            // Day labels
            if showLabels {
                dayLabels(width: width, pointSpacing: pointSpacing)
                    .offset(y: graphHeight + 4)
            }
        }
        .frame(height: height)
    }

    // MARK: - Grid Lines
    private func gridLines(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<5) { i in
                Rectangle()
                    .fill(ColorTokens.textMuted.opacity(0.1))
                    .frame(height: 1)
                if i < 4 {
                    Spacer()
                }
            }
        }
        .frame(height: height)
    }

    // MARK: - Gradient Fill
    private func gradientFill(width: CGFloat, height: CGFloat, pointSpacing: CGFloat) -> some View {
        Path { path in
            guard !moodData.isEmpty else { return }

            let firstPoint = CGPoint(
                x: 0,
                y: height - (CGFloat(moodData[0].score) / 10.0 * height)
            )
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: firstPoint)

            for (index, data) in moodData.enumerated() {
                let x = CGFloat(index) * pointSpacing
                let y = height - (CGFloat(data.score) / 10.0 * height)
                path.addLine(to: CGPoint(x: x, y: y))
            }

            path.addLine(to: CGPoint(x: CGFloat(moodData.count - 1) * pointSpacing, y: height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    ColorTokens.primaryStart.opacity(0.3),
                    ColorTokens.primaryEnd.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Mood Line
    private func moodLine(width: CGFloat, height: CGFloat, pointSpacing: CGFloat) -> some View {
        Path { path in
            guard !moodData.isEmpty else { return }

            let firstPoint = CGPoint(
                x: 0,
                y: height - (CGFloat(moodData[0].score) / 10.0 * height)
            )
            path.move(to: firstPoint)

            for (index, data) in moodData.enumerated() {
                let x = CGFloat(index) * pointSpacing
                let y = height - (CGFloat(data.score) / 10.0 * height)
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        .stroke(
            LinearGradient(
                colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Mood Points
    private func moodPoints(width: CGFloat, height: CGFloat, pointSpacing: CGFloat) -> some View {
        ForEach(Array(moodData.enumerated()), id: \.offset) { index, data in
            let x = CGFloat(index) * pointSpacing
            let y = height - (CGFloat(data.score) / 10.0 * height)

            Circle()
                .fill(moodColor(for: data.mood))
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .position(x: x, y: y)
        }
    }

    // MARK: - Day Labels
    private func dayLabels(width: CGFloat, pointSpacing: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(moodData.enumerated()), id: \.offset) { index, data in
                Text(dayLabel(for: data.date))
                    .font(.system(size: 10))
                    .foregroundColor(ColorTokens.textMuted)
                    .frame(width: index == 0 || index == moodData.count - 1 ? pointSpacing / 2 : pointSpacing)

                if index < moodData.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Helpers
    private func moodColor(for mood: String?) -> Color {
        switch mood {
        case "great": return ColorTokens.success
        case "good": return ColorTokens.primaryStart
        case "neutral": return ColorTokens.textMuted
        case "low": return ColorTokens.warning
        case "bad": return ColorTokens.error
        default: return ColorTokens.primaryStart
        }
    }

    private func dayLabel(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E"
        return dayFormatter.string(from: date)
    }
}

// MARK: - Mood Data Point
struct MoodDataPoint: Identifiable {
    let id = UUID()
    let date: String
    let score: Int
    let mood: String?

    init(date: String, score: Int, mood: String? = nil) {
        self.date = date
        self.score = score
        self.mood = mood
    }
}

// MARK: - Mini Mood Graph (for Dashboard)
struct MiniMoodGraphView: View {
    let entries: [JournalEntryResponse]

    var body: some View {
        let moodData = entries.compactMap { entry -> MoodDataPoint? in
            guard let score = entry.moodScore else { return nil }
            return MoodDataPoint(date: entry.entryDate, score: score, mood: entry.mood)
        }
        .suffix(7)

        MoodGraphView(moodData: Array(moodData), height: 60, showLabels: false)
    }
}

// MARK: - Average Mood Badge
struct AverageMoodBadge: View {
    let entries: [JournalEntryResponse]

    private var averageScore: Double {
        let scores = entries.compactMap { $0.moodScore }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private var averageMood: String {
        let avg = averageScore
        switch avg {
        case 8...10: return "great"
        case 6..<8: return "good"
        case 4..<6: return "neutral"
        case 2..<4: return "low"
        default: return "bad"
        }
    }

    private var moodEmoji: String {
        switch averageMood {
        case "great": return "😄"
        case "good": return "🙂"
        case "neutral": return "😐"
        case "low": return "😔"
        case "bad": return "😢"
        default: return "😐"
        }
    }

    private var moodColor: Color {
        switch averageMood {
        case "great": return ColorTokens.success
        case "good": return ColorTokens.primaryStart
        case "neutral": return ColorTokens.textMuted
        case "low": return ColorTokens.warning
        case "bad": return ColorTokens.error
        default: return ColorTokens.textMuted
        }
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(moodEmoji)
                .font(.title3)

            VStack(alignment: .leading, spacing: 0) {
                Text("journal.avg_mood".localized)
                    .font(.caption2)
                    .foregroundColor(ColorTokens.textMuted)

                Text(String(format: "%.1f", averageScore))
                    .font(.headline)
                    .foregroundColor(ColorTokens.textPrimary)
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(moodColor.opacity(0.1))
        .cornerRadius(RadiusTokens.md)
    }
}

#Preview {
    VStack(spacing: 20) {
        MoodGraphView(
            moodData: [
                MoodDataPoint(date: "2024-01-10", score: 7, mood: "good"),
                MoodDataPoint(date: "2024-01-11", score: 8, mood: "great"),
                MoodDataPoint(date: "2024-01-12", score: 5, mood: "neutral"),
                MoodDataPoint(date: "2024-01-13", score: 6, mood: "good"),
                MoodDataPoint(date: "2024-01-14", score: 4, mood: "low"),
                MoodDataPoint(date: "2024-01-15", score: 7, mood: "good"),
                MoodDataPoint(date: "2024-01-16", score: 9, mood: "great")
            ]
        )
        .padding()
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)

        MoodGraphView(moodData: [])
            .padding()
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
    }
    .padding()
    .background(ColorTokens.background)
}
