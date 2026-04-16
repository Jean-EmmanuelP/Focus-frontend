import SwiftUI

// MARK: - Challenge Card (Planning View)

struct ChallengeCardView: View {
    let challenge: Challenge
    let currentUserId: String
    var onValidate: () -> Void = {}

    private var isCreator: Bool { currentUserId == challenge.creatorId }
    private var myScore: Int { (isCreator ? challenge.creatorScore : challenge.opponentScore) ?? 0 }
    private var theirScore: Int { (isCreator ? challenge.opponentScore : challenge.creatorScore) ?? 0 }
    private var myStreak: Int { (isCreator ? challenge.creatorStreak : challenge.opponentStreak) ?? 0 }
    private var theirStreak: Int { (isCreator ? challenge.opponentStreak : challenge.creatorStreak) ?? 0 }
    private var myName: String { (isCreator ? challenge.creatorName : challenge.opponentName) ?? "Moi" }
    private var theirName: String { (isCreator ? challenge.opponentName : challenge.creatorName) ?? "..." }

    private var gradient: LinearGradient {
        switch challenge.type {
        case .wakeup: return LinearGradient(colors: [Color(hex: "#FF9500"), Color(hex: "#FF6B00")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gym: return LinearGradient(colors: [Color(hex: "#FF3B30"), Color(hex: "#FF2D55")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .meditation: return LinearGradient(colors: [Color(hex: "#AF52DE"), Color(hex: "#5856D6")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .reading: return LinearGradient(colors: [Color(hex: "#007AFF"), Color(hex: "#5AC8FA")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .custom: return LinearGradient(colors: [Color(hex: "#34C759"), Color(hex: "#30D158")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top — gradient header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: challenge.type.icon)
                        .font(.satoshi(14, weight: .bold))
                    Text(challenge.displayTitle)
                        .font(.satoshi(15, weight: .bold))
                }
                Spacer()
                Text("J\(challenge.dayNumber)/\(challenge.durationDays)")
                    .font(.satoshi(13, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .foregroundColor(.white)
            .padding(16)
            .background(gradient)

            // Scores
            HStack(spacing: 0) {
                // My side
                playerColumn(name: myName, score: myScore, streak: myStreak, isMe: true, isLeading: myScore >= theirScore)

                // Center divider
                VStack(spacing: 4) {
                    Text("VS")
                        .font(.satoshi(11, weight: .black))
                        .foregroundColor(ColorTokens.textMuted)
                    // Progress dots
                    progressDots
                }
                .frame(width: 50)

                // Their side
                playerColumn(name: theirName, score: theirScore, streak: theirStreak, isMe: false, isLeading: theirScore > myScore)
            }
            .padding(.vertical, 16)
            .background(ColorTokens.surfaceElevated)

            // Validate CTA
            if challenge.isActive {
                Button(action: onValidate) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                        Text("Valider aujourd'hui")
                            .font(.satoshi(15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(gradient)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    // MARK: - Player Column

    private func playerColumn(name: String, score: Int, streak: Int, isMe: Bool, isLeading: Bool) -> some View {
        VStack(spacing: 6) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(isMe ? ColorTokens.primarySoft : ColorTokens.border)
                    .frame(width: 40, height: 40)
                Text(String(name.prefix(1)).uppercased())
                    .font(.satoshi(16, weight: .bold))
                    .foregroundColor(isMe ? ColorTokens.primaryStart : ColorTokens.textSecondary)
            }

            Text(name)
                .font(.satoshi(12, weight: .medium))
                .foregroundColor(ColorTokens.textSecondary)
                .lineLimit(1)

            Text("\(score)")
                .font(.satoshi(32, weight: .black))
                .foregroundColor(isLeading ? ColorTokens.textPrimary : ColorTokens.textSecondary)

            if streak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("\(streak)")
                        .font(.satoshi(11, weight: .bold))
                }
                .foregroundColor(ColorTokens.warning)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        let total = min(challenge.durationDays ?? 30, 30)
        let completed = challenge.dayNumber - 1
        let cols = 5
        let rows = min(6, (total + cols - 1) / cols)

        return VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<cols, id: \.self) { col in
                        let day = row * cols + col + 1
                        if day <= total {
                            Circle()
                                .fill(day <= completed ? ColorTokens.primaryStart : ColorTokens.border)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
        }
    }
}
