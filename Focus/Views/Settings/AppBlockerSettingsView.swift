import SwiftUI
import FamilyControls

// MARK: - App Blocker Settings View
struct AppBlockerSettingsView: View {
    @StateObject private var viewModel = AppBlockerViewModel()
    @State private var showClearConfirmation = false
    @State private var showUnblockConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Authorization Status Card
                authorizationCard

                if viewModel.isAuthorized {
                    // App Selection Card
                    appSelectionCard

                    // Blocking Toggle
                    blockingToggleCard

                    // Status Card (when blocking)
                    if viewModel.isBlocking {
                        blockingStatusCard
                    }
                }

                // Info Section
                infoSection
            }
            .padding(SpacingTokens.lg)
        }
        .background(ColorTokens.background)
        .navigationTitle("Blocage d'apps")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(
            isPresented: $viewModel.showAppPicker,
            selection: $viewModel.selectedApps
        )
        .onChange(of: viewModel.selectedApps) { _, newValue in
            viewModel.updateSelection(newValue)
        }
        .alert("Autorisation refusée", isPresented: $viewModel.showAuthorizationError) {
            Button("OK", role: .cancel) {}
            Button("Ouvrir Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Pour bloquer des apps, autorise l'accès à Temps d'écran dans les réglages de ton iPhone.")
        }
        .alert("Effacer la sélection", isPresented: $showClearConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Effacer", role: .destructive) {
                viewModel.clearSelection()
            }
        } message: {
            Text("Toutes les apps sélectionnées seront retirées de la liste de blocage.")
        }
        .alert("Désactiver le blocage ?", isPresented: $showUnblockConfirmation) {
            Button("Garder le blocage", role: .cancel) {}
            Button("Désactiver quand même", role: .destructive) {
                viewModel.stopBlocking()
            }
        } message: {
            Text("Es-tu sûr ? Ton coach te recommande de garder le blocage actif pour rester concentré. Tu peux aussi lui demander directement dans le chat.")
        }
    }

    // MARK: - Authorization Card
    private var authorizationCard: some View {
        VStack(spacing: SpacingTokens.lg) {
            HStack(spacing: SpacingTokens.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTokens.primaryStart.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "hourglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(ColorTokens.primaryStart)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Temps d'écran")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text(viewModel.authorizationStatus.displayText)
                        .font(.satoshi(13))
                        .foregroundColor(viewModel.isAuthorized ? Color.green : ColorTokens.textMuted)
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(viewModel.isAuthorized ? Color.green : ColorTokens.textMuted)
                    .frame(width: 10, height: 10)
            }

            if !viewModel.isAuthorized {
                Button(action: {
                    Task {
                        await viewModel.requestAuthorization()
                    }
                }) {
                    HStack {
                        if viewModel.isRequestingAuthorization {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.shield")
                            Text("Autoriser l'accès")
                        }
                    }
                    .font(.satoshi(15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.md)
                    .background(ColorTokens.fireGradient)
                    .cornerRadius(RadiusTokens.lg)
                }
                .disabled(viewModel.isRequestingAuthorization)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
    }

    // MARK: - App Selection Card
    private var appSelectionCard: some View {
        VStack(spacing: SpacingTokens.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps à bloquer")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    if viewModel.hasSelectedApps {
                        Text("\(viewModel.selectedAppsCount) sélectionnée(s)")
                            .font(.satoshi(13))
                            .foregroundColor(ColorTokens.textSecondary)
                    } else {
                        Text("Aucune app sélectionnée")
                            .font(.satoshi(13))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }

                Spacer()

                if viewModel.hasSelectedApps {
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.error)
                    }
                }
            }

            // Selected apps preview (simplified)
            if viewModel.hasSelectedApps {
                HStack(spacing: -8) {
                    ForEach(0..<min(5, viewModel.selectedAppsCount), id: \.self) { _ in
                        Circle()
                            .fill(ColorTokens.primaryStart.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "app.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(ColorTokens.primaryStart)
                            )
                            .overlay(
                                Circle()
                                    .stroke(ColorTokens.surface, lineWidth: 2)
                            )
                    }

                    if viewModel.selectedAppsCount > 5 {
                        Circle()
                            .fill(ColorTokens.textMuted.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("+\(viewModel.selectedAppsCount - 5)")
                                    .font(.satoshi(10, weight: .bold))
                                    .foregroundColor(ColorTokens.textSecondary)
                            )
                            .overlay(
                                Circle()
                                    .stroke(ColorTokens.surface, lineWidth: 2)
                            )
                    }

                    Spacer()
                }
            }

            // Choose apps button
            Button(action: {
                viewModel.presentAppPicker()
            }) {
                HStack {
                    Image(systemName: viewModel.hasSelectedApps ? "pencil" : "plus.circle")
                    Text(viewModel.hasSelectedApps ? "Modifier la sélection" : "Choisir les apps")
                }
                .font(.satoshi(15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.md)
                .background(ColorTokens.fireGradient)
                .cornerRadius(RadiusTokens.lg)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
    }

    // MARK: - Blocking Toggle Card
    private var blockingToggleCard: some View {
        VStack(spacing: SpacingTokens.md) {
            Toggle(isOn: $viewModel.enableBlockingDuringFocus) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bloquer pendant le Focus")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Active automatiquement le blocage pendant les sessions de focus")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textMuted)
                }
            }
            .tint(ColorTokens.primaryStart)
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
    }

    // MARK: - Blocking Status Card
    private var blockingStatusCard: some View {
        HStack(spacing: SpacingTokens.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 24))
                .foregroundColor(ColorTokens.success)

            VStack(alignment: .leading, spacing: 2) {
                Text("Blocage actif")
                    .font(.satoshi(16, weight: .bold))
                    .foregroundColor(ColorTokens.success)

                Text("\(viewModel.selectedAppsCount) app(s) bloquée(s)")
                    .font(.satoshi(13))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()

            Button(action: {
                showUnblockConfirmation = true
            }) {
                Text("Arrêter")
                    .font(.satoshi(13, weight: .semibold))
                    .foregroundColor(ColorTokens.error)
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.sm)
                    .background(ColorTokens.error.opacity(0.15))
                    .cornerRadius(RadiusTokens.md)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.success.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.xl)
                .stroke(ColorTokens.success.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(RadiusTokens.xl)
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ColorTokens.primaryStart)
                Text("Comment ça marche")
                    .font(.satoshi(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                infoRow(icon: "1.circle.fill", text: "Choisis les apps distrayantes (Instagram, TikTok...)")
                infoRow(icon: "2.circle.fill", text: "Ton coach peut bloquer tes apps automatiquement")
                infoRow(icon: "3.circle.fill", text: "Demande à ton coach pour débloquer")
            }

            Text("Ton coach peut bloquer tes apps quand tu en as besoin. Pour débloquer, parle-lui dans le chat et donne-lui une bonne raison.")
                .font(.satoshi(12))
                .foregroundColor(ColorTokens.textMuted)
                .padding(.top, SpacingTokens.xs)
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface.opacity(0.5))
        .cornerRadius(RadiusTokens.xl)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.primaryStart)
                .frame(width: 20)

            Text(text)
                .font(.satoshi(13))
                .foregroundColor(ColorTokens.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        AppBlockerSettingsView()
    }
}
