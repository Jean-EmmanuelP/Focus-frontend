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
                    .font(.inter(24, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Une nouvelle version de Volta est disponible")
                    .font(.inter(16))
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Version info
            HStack(spacing: SpacingTokens.xl) {
                VStack(spacing: SpacingTokens.xs) {
                    Text("Version actuelle")
                        .font(.inter(12))
                        .foregroundColor(ColorTokens.textMuted)
                    Text(updateService.currentVersion)
                        .font(.inter(18, weight: .semibold))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(ColorTokens.textMuted)

                VStack(spacing: SpacingTokens.xs) {
                    Text("Nouvelle version")
                        .font(.inter(12))
                        .foregroundColor(ColorTokens.textMuted)
                    Text(updateService.appStoreVersion ?? "—")
                        .font(.inter(18, weight: .bold))
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
                        .font(.inter(16, weight: .medium))
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

/// Small banner that can be shown at the top of the app
struct UpdateAvailableBanner: View {
    @ObservedObject var updateService: AppUpdateService
    @Binding var isPresented: Bool

    var body: some View {
        if updateService.updateAvailable {
            HStack(spacing: SpacingTokens.md) {
                Image(systemName: "arrow.down.app.fill")
                    .foregroundStyle(ColorTokens.fireGradient)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mise à jour disponible")
                        .font(.inter(14, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)
                    Text("Version \(updateService.appStoreVersion ?? "")")
                        .font(.inter(12))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Button(action: {
                    isPresented = true
                }) {
                    Text("Voir")
                        .font(.inter(13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, SpacingTokens.md)
                        .padding(.vertical, SpacingTokens.xs)
                        .background(ColorTokens.fireGradient)
                        .cornerRadius(RadiusTokens.full)
                }

                Button(action: {
                    withAnimation {
                        updateService.updateAvailable = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.inter(12))
                        .foregroundColor(ColorTokens.textMuted)
                }
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(ColorTokens.primaryStart.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, SpacingTokens.md)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    UpdateAvailableSheet(updateService: AppUpdateService.shared)
}
