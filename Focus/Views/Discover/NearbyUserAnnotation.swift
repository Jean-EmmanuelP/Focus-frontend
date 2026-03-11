import SwiftUI

struct NearbyUserAnnotation: View {
    let user: NearbyUser
    let isCurrentUser: Bool

    private var size: CGFloat { isCurrentUser ? 44 : 36 }

    private var bgColor: Color {
        if isCurrentUser {
            return Color(hex: "#5AC8FA") // primaryStart / accent
        }
        // Deterministic color from name hash
        let hash = abs(user.displayName.hashValue)
        let colors: [Color] = [
            Color(red: 0.35, green: 0.78, blue: 0.65),  // teal
            Color(red: 0.55, green: 0.47, blue: 0.85),  // purple
            Color(red: 0.90, green: 0.55, blue: 0.35),  // orange
            Color(red: 0.40, green: 0.65, blue: 0.90),  // blue
            Color(red: 0.85, green: 0.40, blue: 0.55),  // pink
            Color(red: 0.65, green: 0.80, blue: 0.35),  // green
        ]
        return colors[hash % colors.count]
    }

    var body: some View {
        ZStack {
            // Glow ring
            Circle()
                .fill(bgColor.opacity(0.25))
                .frame(width: size + 10, height: size + 10)

            // Main circle
            Circle()
                .fill(bgColor)
                .frame(width: size, height: size)

            // Ring for current user
            if isCurrentUser {
                Circle()
                    .stroke(Color(hex: "#5AC8FA"), lineWidth: 3)
                    .frame(width: size + 4, height: size + 4)
            }

            // Initial
            Text(user.initial)
                .font(.system(size: isCurrentUser ? 18 : 14, weight: .bold))
                .foregroundColor(.white)

            // Streak badge
            if let streak = user.currentStreak, streak > 0, !isCurrentUser {
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
                .offset(y: size / 2 + 4)
            }
        }
    }
}
