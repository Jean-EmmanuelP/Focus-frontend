import SwiftUI

struct FocusPulseDot: View {
    let user: NearbyUser
    let isCurrentUser: Bool

    @State private var isPulsing = false

    // Randomized pulse duration per user for organic feel
    private var pulseDuration: Double {
        let hash = abs(user.id.hashValue)
        return 2.0 + Double(hash % 10) / 10.0 // 2.0 - 3.0s
    }

    // Dot size scales with total focus minutes today (sqrt curve)
    // 0 min → 14px, 25 min → ~24px, 50 min → ~30px, 100 min → ~38px, 200+ min → ~50px
    private var dotSize: CGFloat {
        let total = CGFloat(user.totalMinutesToday)
        guard total > 0 else { return 14 }
        let base: CGFloat = 14
        let growth: CGFloat = 2.5 // sqrt multiplier
        let maxGrowth: CGFloat = 36 // cap at base + 36 = 50px
        let scaled = min(sqrt(total) * growth, maxGrowth)
        return base + scaled
    }

    private var dotColor: Color {
        if isCurrentUser {
            return ColorTokens.primaryStart
        }
        if !user.isInFocusSession {
            return .white.opacity(0.15)
        }
        // Orange/amber for focusing users
        return .orange
    }

    /// Whether this dot should render as an active/visible dot (not a ghost)
    private var isVisible: Bool {
        isCurrentUser || user.isInFocusSession || user.totalMinutesToday > 0
    }

    var body: some View {
        ZStack {
            if isVisible {
                // Outer glow (pulsing) — only pulse if actively in session
                if user.isInFocusSession || isCurrentUser {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    dotColor.opacity(0.4),
                                    dotColor.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: dotSize * 1.5
                            )
                        )
                        .frame(width: dotSize * 3, height: dotSize * 3)
                        .scaleEffect(isPulsing ? 1.15 : 0.95)
                        .opacity(isPulsing ? 0.8 : 0.5)
                }

                // Core dot
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                isCurrentUser ? ColorTokens.primaryStart : Color.orange.opacity(user.isInFocusSession ? 0.95 : 0.5),
                                isCurrentUser ? ColorTokens.primaryStart.opacity(0.6) : Color(red: 0.9, green: 0.4, blue: 0.1).opacity(user.isInFocusSession ? 0.7 : 0.3)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: dotSize / 2
                        )
                    )
                    .frame(width: dotSize, height: dotSize)

                // Initial (scale with dot)
                Text(user.initial)
                    .font(.system(size: max(10, dotSize * 0.4), weight: .bold))
                    .foregroundColor(.white.opacity(user.isInFocusSession || isCurrentUser ? 1.0 : 0.6))

                // Streak badge (only for users with streak > 3, not current user)
                if !isCurrentUser, let streak = user.currentStreak, streak > 3 {
                    HStack(spacing: 1) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.orange)
                        Text("\(streak)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(6)
                    .offset(y: dotSize / 2 + 6)
                }
            } else {
                // Never focused today: ghost dot
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 10, height: 10)
            }
        }
        .onAppear {
            guard user.isInFocusSession || isCurrentUser else { return }
            withAnimation(
                .easeInOut(duration: pulseDuration)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }
}
