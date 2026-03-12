import SwiftUI

struct EncouragementToastView: View {
    let toast: EncouragementToast

    var body: some View {
        HStack(spacing: 10) {
            Text(toast.emoji)
                .font(.system(size: 18))

            Text("\(toast.message)")
                .font(.satoshi(14, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)
            +
            Text(" de \(toast.fromInitial).")
                .font(.satoshi(14, weight: .medium))
                .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
    }
}
