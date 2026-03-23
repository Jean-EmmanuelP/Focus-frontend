import SwiftUI

// MARK: - Stat Pill

struct FocusMapStatPill: View {
    let sfSymbol: String
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: sfSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)

            Text("\(value)")
                .font(.satoshi(17, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)
                .contentTransition(.numericText(countsDown: false))

            Text(label)
                .font(.satoshi(12, weight: .medium))
                .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    FocusMapStatPill(
        sfSymbol: "flame.fill",
        value: 47,
        label: "en focus",
        color: .orange
    )
}
