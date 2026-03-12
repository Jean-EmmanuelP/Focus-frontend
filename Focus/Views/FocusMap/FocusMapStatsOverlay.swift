import SwiftUI

// MARK: - Animated Odometer Digit

struct OdometerDigit: View {
    let digit: Int

    var body: some View {
        Text("\(digit)")
            .font(.satoshi(20, weight: .bold))
            .foregroundColor(ColorTokens.textPrimary)
            .contentTransition(.numericText(countsDown: false))
    }
}

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

// MARK: - Stats Overlay

struct FocusMapStatsOverlay: View {
    let activeUsers: Int
    let blockedAppsUsers: Int
    let totalMinutesToday: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                FocusMapStatPill(
                    sfSymbol: "flame.fill",
                    value: activeUsers,
                    label: "en focus",
                    color: .orange
                )

                FocusMapStatPill(
                    sfSymbol: "lock.fill",
                    value: blockedAppsUsers,
                    label: "apps bloquees",
                    color: ColorTokens.primaryStart
                )
            }

            FocusMapStatPill(
                sfSymbol: "timer",
                value: totalMinutesToday,
                label: "min aujourd'hui",
                color: ColorTokens.accent
            )
        }
        .animation(.easeOut(duration: 0.6), value: activeUsers)
        .animation(.easeOut(duration: 0.6), value: blockedAppsUsers)
        .animation(.easeOut(duration: 0.6), value: totalMinutesToday)
    }
}

#Preview {
    ZStack {
        Color(hex: "#050508")
            .ignoresSafeArea()

        FocusMapStatsOverlay(
            activeUsers: 47,
            blockedAppsUsers: 31,
            totalMinutesToday: 2_341
        )
    }
}
