import SwiftUI

struct ChatMessageBubble: View {
    let message: ChatMessage
    let onToolTap: ((ChatTool) -> Void)?

    init(message: ChatMessage, onToolTap: ((ChatTool) -> Void)? = nil) {
        self.message = message
        self.onToolTap = onToolTap
    }

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            if !message.isFromUser {
                // Coach avatar
                coachAvatar
            } else {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: SpacingTokens.xs) {
                // Message content
                switch message.type {
                case .text:
                    textBubble
                case .voice:
                    voiceBubble
                case .toolCard:
                    if let tool = message.toolAction {
                        toolCard(tool)
                    }
                case .dailyStats:
                    statsCard
                case .taskList:
                    taskListCard
                default:
                    textBubble
                }

                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(ColorTokens.textMuted)
            }

            if message.isFromUser {
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
    }

    // MARK: - Coach Avatar

    private var coachAvatar: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.surface)
                .frame(width: 32, height: 32)

            Image(systemName: CoachPersona.avatarIcon)
                .font(.system(size: 16))
                .foregroundColor(ColorTokens.primaryStart)
        }
    }

    // MARK: - Text Bubble

    private var textBubble: some View {
        Text(message.content)
            .font(.system(size: 15))
            .foregroundColor(message.isFromUser ? .white : ColorTokens.textPrimary)
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(message.isFromUser ? ColorTokens.primaryStart : ColorTokens.surface)
            )
            .frame(maxWidth: 280, alignment: message.isFromUser ? .trailing : .leading)
    }

    // MARK: - Voice Bubble

    private var voiceBubble: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.sm) {
                Image(systemName: "waveform")
                    .foregroundColor(ColorTokens.primaryStart)

                Text("Message vocal")
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            if let transcript = message.voiceTranscript {
                Text(transcript)
                    .font(.system(size: 15))
                    .foregroundColor(message.isFromUser ? .white : ColorTokens.textPrimary)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(message.isFromUser ? ColorTokens.primaryStart : ColorTokens.surface)
        )
        .frame(maxWidth: 280, alignment: message.isFromUser ? .trailing : .leading)
    }

    // MARK: - Tool Card

    private func toolCard(_ tool: ChatTool) -> some View {
        Button {
            onToolTap?(tool)
        } label: {
            HStack(spacing: SpacingTokens.md) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.primarySoft)
                        .frame(width: 40, height: 40)

                    Image(systemName: tool.icon)
                        .font(.system(size: 18))
                        .foregroundColor(ColorTokens.primaryStart)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text(tool.description)
                        .font(.system(size: 12))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTokens.textMuted)
            }
            .padding(SpacingTokens.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: 280)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Tes stats du jour")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)

            // Placeholder - will be populated with real data
            HStack(spacing: SpacingTokens.lg) {
                statItem(value: "45", label: "min focus", icon: "flame")
                statItem(value: "3/5", label: "tâches", icon: "checkmark.circle")
                statItem(value: "2/4", label: "rituels", icon: "arrow.clockwise")
            }
        }
        .padding(SpacingTokens.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
        )
        .frame(maxWidth: 280)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ColorTokens.primaryStart)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(ColorTokens.textMuted)
        }
    }

    // MARK: - Task List Card

    private var taskListCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Tes tâches")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)

            // Placeholder
            Text("Aucune tâche pour le moment")
                .font(.system(size: 13))
                .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(SpacingTokens.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
        )
        .frame(maxWidth: 280)
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ColorTokens.background
            .ignoresSafeArea()

        VStack(spacing: SpacingTokens.md) {
            ChatMessageBubble(
                message: ChatMessage(
                    content: "Salut. Qu'est-ce que tu veux accomplir aujourd'hui ?",
                    isFromUser: false
                )
            )

            ChatMessageBubble(
                message: ChatMessage(
                    content: "Je veux finir mon projet et faire du sport",
                    isFromUser: true
                )
            )

            ChatMessageBubble(
                message: ChatMessage(
                    type: .toolCard,
                    content: "Planifier ma journée",
                    isFromUser: false,
                    toolAction: .planDay
                )
            )
        }
        .padding()
    }
}
