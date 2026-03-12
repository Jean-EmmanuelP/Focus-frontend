import SwiftUI

struct FocusMapCoachCard: View {
    let message: String
    let onJoinFocus: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 16) {
            // Coach message
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.primaryGradient)

                Text(message)
                    .font(.satoshi(15, weight: .medium))
                    .foregroundColor(ColorTokens.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, 4)

            // CTA Button — pill style
            Button(action: onJoinFocus) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15, weight: .semibold))

                    Text("Rejoindre le focus")
                        .font(.satoshi(16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(ColorTokens.primaryGradient)
                )
                .scaleEffect(isPressed ? 0.97 : 1.0)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                    .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    ZStack {
        Color(hex: "#050508")
            .ignoresSafeArea()

        FocusMapCoachCard(
            message: "47 personnes focus en ce moment. Et toi, tu fais quoi ?",
            onJoinFocus: {}
        )
        .padding()
    }
}
