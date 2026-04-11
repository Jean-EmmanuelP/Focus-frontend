import SwiftUI

// MARK: - Challenge Card (for Planning View)

struct ChallengeCardView: View {
    let challenge: Challenge
    let currentUserId: String
    var onValidate: () -> Void = {}

    private var isCreator: Bool {
        currentUserId == challenge.creatorId
    }

    private var myScore: Int {
        isCreator ? challenge.creatorScore : challenge.opponentScore
    }

    private var opponentScore: Int {
        isCreator ? challenge.opponentScore : challenge.creatorScore
    }

    private var myStreak: Int {
        isCreator ? challenge.creatorStreak : challenge.opponentStreak
    }

    private var myName: String {
        (isCreator ? challenge.creatorName : challenge.opponentName) ?? "Moi"
    }

    private var opponentName: String {
        (isCreator ? challenge.opponentName : challenge.creatorName) ?? "En attente"
    }

    private var typeColor: Color {
        switch challenge.type {
        case .wakeup: return .orange
        case .gym: return .red
        case .meditation: return .purple
        case .reading: return .blue
        case .custom: return .green
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: challenge.type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(typeColor)

                Text(challenge.displayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Day counter
                Text("Jour \(challenge.dayNumber)/\(challenge.durationDays)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(typeColor)
                        .frame(width: geo.size.width * CGFloat(challenge.dayNumber) / CGFloat(max(1, challenge.durationDays)), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Scores — side by side
            HStack(spacing: 0) {
                // My score
                VStack(spacing: 4) {
                    Text(myName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(myScore)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(typeColor)
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text("\(myStreak)j")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.orange.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                // VS
                Text("VS")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.25))

                // Opponent score
                VStack(spacing: 4) {
                    Text(opponentName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(opponentScore)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        let oppStreak = isCreator ? challenge.opponentStreak : challenge.creatorStreak
                        Text("\(oppStreak)j")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.orange.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)

            // Validate button
            if challenge.isActive {
                Button(action: onValidate) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 13))
                        Text("Valider en live")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(typeColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

            // Alarm time if wake-up
            if challenge.type == .wakeup, let time = challenge.alarmTime {
                HStack {
                    Image(systemName: "alarm")
                        .font(.system(size: 11))
                    Text("Réveil à \(time)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.35))
                .padding(.bottom, 10)
            }
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
