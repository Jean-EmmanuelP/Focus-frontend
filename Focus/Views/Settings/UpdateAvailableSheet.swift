import SwiftUI

/// Sheet displayed when an app update is available
struct UpdateAvailableSheet: View {
    @ObservedObject var updateService: AppUpdateService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: SpacingTokens.xl) {
            // Icon
            ZStack {
                Circle()
                    .fill(ColorTokens.primarySoft)
                    .frame(width: 80, height: 80)

                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.fireGradient)
            }
            .padding(.top, SpacingTokens.xl)

            // Title
            VStack(spacing: SpacingTokens.sm) {
                Text("Mise à jour disponible")
                    .font(.satoshi(24, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Une nouvelle version de Volta est disponible")
                    .font(.satoshi(16))
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Version info
            HStack(spacing: SpacingTokens.xl) {
                VStack(spacing: SpacingTokens.xs) {
                    Text("Version actuelle")
                        .font(.satoshi(12))
                        .foregroundColor(ColorTokens.textMuted)
                    Text(updateService.currentVersion)
                        .font(.satoshi(18, weight: .semibold))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(ColorTokens.textMuted)

                VStack(spacing: SpacingTokens.xs) {
                    Text("Nouvelle version")
                        .font(.satoshi(12))
                        .foregroundColor(ColorTokens.textMuted)
                    Text(updateService.appStoreVersion ?? "—")
                        .font(.satoshi(18, weight: .bold))
                        .foregroundStyle(ColorTokens.fireGradient)
                }
            }
            .padding(.vertical, SpacingTokens.md)
            .padding(.horizontal, SpacingTokens.lg)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)

            Spacer()

            // Buttons
            VStack(spacing: SpacingTokens.md) {
                PrimaryButton("Mettre à jour", icon: "arrow.down.app") {
                    updateService.openAppStore()
                }

                Button(action: {
                    dismiss()
                }) {
                    Text("Plus tard")
                        .font(.satoshi(16, weight: .medium))
                        .foregroundColor(ColorTokens.textSecondary)
                }
                .padding(.vertical, SpacingTokens.sm)
            }
            .padding(.bottom, SpacingTokens.lg)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .background(ColorTokens.background)
    }
}

#Preview {
    UpdateAvailableSheet(updateService: AppUpdateService.shared)
}
