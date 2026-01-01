import SwiftUI

/// Quick action cards displayed in chat
struct ChatQuickActions: View {
    let onToolTap: (ChatTool) -> Void
    let suggestedTools: [ChatTool]

    init(
        suggestedTools: [ChatTool] = [.planDay, .startFocus, .dailyReflection],
        onToolTap: @escaping (ChatTool) -> Void
    ) {
        self.suggestedTools = suggestedTools
        self.onToolTap = onToolTap
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sm) {
                ForEach(suggestedTools, id: \.self) { tool in
                    QuickActionChip(tool: tool) {
                        onToolTap(tool)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.md)
        }
    }
}

/// Individual quick action chip
struct QuickActionChip: View {
    let tool: ChatTool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: tool.icon)
                    .font(.system(size: 14))

                Text(tool.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(ColorTokens.primaryStart)
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(ColorTokens.primarySoft)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Expanded tool card with more details
struct ExpandedToolCard: View {
    let tool: ChatTool
    let context: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTokens.primarySoft)
                        .frame(width: 48, height: 48)

                    Image(systemName: tool.icon)
                        .font(.system(size: 20))
                        .foregroundColor(ColorTokens.primaryStart)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    if let context = context {
                        Text(context)
                            .font(.system(size: 13))
                            .foregroundColor(ColorTokens.textSecondary)
                            .lineLimit(2)
                    } else {
                        Text(tool.description)
                            .font(.system(size: 13))
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ColorTokens.textMuted)
            }
            .padding(SpacingTokens.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Button style with scale effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Stats summary card for chat
struct ChatStatsCard: View {
    let focusMinutes: Int
    let tasksCompleted: Int
    let tasksTotal: Int
    let ritualsCompleted: Int
    let ritualsTotal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Ton avancement")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)

            HStack(spacing: SpacingTokens.lg) {
                // Focus time
                statColumn(
                    icon: "flame.fill",
                    value: "\(focusMinutes)",
                    label: "min focus",
                    color: ColorTokens.primaryStart
                )

                Divider()
                    .frame(height: 40)
                    .background(ColorTokens.border)

                // Tasks
                statColumn(
                    icon: "checkmark.circle.fill",
                    value: "\(tasksCompleted)/\(tasksTotal)",
                    label: "tâches",
                    color: ColorTokens.success
                )

                Divider()
                    .frame(height: 40)
                    .background(ColorTokens.border)

                // Rituals
                statColumn(
                    icon: "arrow.clockwise",
                    value: "\(ritualsCompleted)/\(ritualsTotal)",
                    label: "rituels",
                    color: ColorTokens.accent
                )
            }
        }
        .padding(SpacingTokens.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surface)
        )
    }

    private func statColumn(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(ColorTokens.textPrimary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ColorTokens.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Mood picker for chat
struct ChatMoodPicker: View {
    @Binding var selectedMood: Int?
    let onSelect: (Int) -> Void

    private let moods = [
        (1, "😫", "Difficile"),
        (2, "😕", "Bof"),
        (3, "😐", "Neutre"),
        (4, "🙂", "Bien"),
        (5, "😊", "Super")
    ]

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            Text("Comment tu te sens ?")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ColorTokens.textPrimary)

            HStack(spacing: SpacingTokens.md) {
                ForEach(moods, id: \.0) { mood in
                    Button {
                        selectedMood = mood.0
                        onSelect(mood.0)
                    } label: {
                        VStack(spacing: 4) {
                            Text(mood.1)
                                .font(.system(size: 28))

                            Text(mood.2)
                                .font(.system(size: 10))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                        .padding(.vertical, SpacingTokens.sm)
                        .padding(.horizontal, SpacingTokens.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMood == mood.0 ? ColorTokens.primarySoft : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(SpacingTokens.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surface)
        )
    }
}

// MARK: - Previews

#Preview("Quick Actions") {
    ZStack {
        ColorTokens.background
            .ignoresSafeArea()

        ChatQuickActions { tool in
            print("Tapped: \(tool)")
        }
    }
}

#Preview("Expanded Card") {
    ZStack {
        ColorTokens.background
            .ignoresSafeArea()

        ExpandedToolCard(
            tool: .planDay,
            context: "Tu as 5 tâches à organiser",
            onTap: {}
        )
        .padding()
    }
}

#Preview("Stats Card") {
    ZStack {
        ColorTokens.background
            .ignoresSafeArea()

        ChatStatsCard(
            focusMinutes: 45,
            tasksCompleted: 3,
            tasksTotal: 5,
            ritualsCompleted: 2,
            ritualsTotal: 4
        )
        .padding()
    }
}
