import ActivityKit
import WidgetKit
import SwiftUI

// Import the shared ActivityAttributes from the main app
// Note: In a real project, these would be in a shared framework

struct FocusSessionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: Int
        var progress: Double
        var isPaused: Bool
    }

    var sessionId: String
    var totalDuration: Int
    var description: String?
    var questTitle: String?
    var questEmoji: String?
    var startTime: Date
}

struct FocusSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionActivityAttributes.self) { context in
            // Lock screen / banner view
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Text(context.attributes.questEmoji ?? "🔥")
                            .font(.system(size: 24))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(context.state.timeRemaining))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)

                        Text(context.state.isPaused ? "Paused" : "Focusing")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        if let title = context.attributes.questTitle {
                            Text(title)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        } else if let desc = context.attributes.description {
                            Text(desc)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        } else {
                            Text("Focus Session")
                                .font(.system(size: 14, weight: .medium))
                        }

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * context.state.progress, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.totalDuration) min session")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Text(context.attributes.questEmoji ?? "🔥")
                        .font(.system(size: 14))

                    if context.state.isPaused {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
            } compactTrailing: {
                Text(formatTimeShort(context.state.timeRemaining))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.orange)
            } minimal: {
                ZStack {
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(Color.orange, lineWidth: 2)
                        .rotationEffect(.degrees(-90))

                    Text(context.attributes.questEmoji ?? "🔥")
                        .font(.system(size: 10))
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func formatTimeShort(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes)m"
    }
}

// MARK: - Lock Screen Live Activity View
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<FocusSessionActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Left: Icon and info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(context.attributes.questEmoji ?? "🔥")
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 2) {
                        if let title = context.attributes.questTitle {
                            Text(title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        } else if let desc = context.attributes.description {
                            Text(desc)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        } else {
                            Text("Focus Session")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Text(context.state.isPaused ? "Paused" : "Focusing...")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * context.state.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            // Right: Timer
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(context.state.timeRemaining))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)

                Text("remaining")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.8))
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Preview
#Preview("Live Activity", as: .content, using: FocusSessionActivityAttributes(
    sessionId: "preview",
    totalDuration: 25,
    description: "Working on iOS app",
    questTitle: "Build MVP",
    questEmoji: "💼",
    startTime: Date()
)) {
    FocusSessionLiveActivity()
} contentStates: {
    FocusSessionActivityAttributes.ContentState(
        timeRemaining: 1200,
        progress: 0.2,
        isPaused: false
    )
}
