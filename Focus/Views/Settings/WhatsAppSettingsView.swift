import SwiftUI
import Combine

struct WhatsAppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WhatsAppSettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Header with WhatsApp branding
                whatsAppHeader

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.isLinked {
                    linkedView
                } else {
                    linkingView
                }
            }
            .padding(SpacingTokens.lg)
        }
        .background(ColorTokens.background)
        .navigationTitle("WhatsApp")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Erreur", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Succès", isPresented: $viewModel.showSuccess) {
            Button("OK") {}
        } message: {
            Text(viewModel.successMessage)
        }
        .task {
            await viewModel.loadStatus()
        }
    }

    // MARK: - Header

    private var whatsAppHeader: some View {
        VStack(spacing: SpacingTokens.md) {
            // WhatsApp icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.25, green: 0.72, blue: 0.45))
                    .frame(width: 80, height: 80)

                Image(systemName: "message.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            Text("Kai sur WhatsApp")
                .font(.satoshi(22, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            Text("Reçois des rappels et discute avec Kai directement sur WhatsApp")
                .font(.satoshi(14))
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.lg)
        }
        .padding(.vertical, SpacingTokens.xl)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
            Text("Chargement...")
                .font(.satoshi(14))
                .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(.vertical, SpacingTokens.xxl)
    }

    // MARK: - Linked View

    private var linkedView: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Status badge
            HStack(spacing: SpacingTokens.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ColorTokens.success)
                Text("Connecté")
                    .font(.satoshi(14, weight: .semibold))
                    .foregroundColor(ColorTokens.success)
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)
            .background(ColorTokens.success.opacity(0.15))
            .cornerRadius(RadiusTokens.lg)

            // Phone number
            if !viewModel.phoneNumber.isEmpty {
                Text(viewModel.phoneNumber)
                    .font(.satoshi(16, weight: .medium))
                    .foregroundColor(ColorTokens.textPrimary)
            }

            // Preferences section
            preferencesSection

            // Unlink button
            Button {
                Task { await viewModel.unlink() }
            } label: {
                HStack {
                    Image(systemName: "link.badge.plus")
                        .rotationEffect(.degrees(45))
                    Text("Déconnecter WhatsApp")
                }
                .font(.satoshi(14, weight: .medium))
                .foregroundColor(ColorTokens.error)
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.vertical, SpacingTokens.md)
                .background(ColorTokens.error.opacity(0.1))
                .cornerRadius(RadiusTokens.lg)
            }
            .padding(.top, SpacingTokens.lg)
        }
    }

    // MARK: - Linking View

    private var linkingView: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Benefits list
            benefitsList

            // Phone input
            phoneInputSection

            // Code verification (if code sent)
            if viewModel.codeSent {
                codeVerificationSection
            }
        }
    }

    // MARK: - Benefits List

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Avec Kai sur WhatsApp :")
                .font(.satoshi(16, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)

            benefitRow(icon: "sun.rise.fill", text: "Check-in matinal pour planifier ta journée")
            benefitRow(icon: "moon.stars.fill", text: "Review du soir pour faire le bilan")
            benefitRow(icon: "flame.fill", text: "Alertes streak en danger")
            benefitRow(icon: "target", text: "Rappels de quests importantes")
            benefitRow(icon: "bubble.left.and.bubble.right.fill", text: "Discute avec Kai à tout moment")
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: icon)
                .font(.satoshi(14))
                .foregroundColor(ColorTokens.primaryStart)
                .frame(width: 24)

            Text(text)
                .font(.satoshi(14))
                .foregroundColor(ColorTokens.textSecondary)
        }
    }

    // MARK: - Phone Input Section

    private var phoneInputSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Ton numéro WhatsApp")
                .font(.satoshi(14, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)

            HStack(spacing: SpacingTokens.sm) {
                // Country code
                Text("🇫🇷 +33")
                    .font(.satoshi(16))
                    .foregroundColor(ColorTokens.textPrimary)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, SpacingTokens.md)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)

                // Phone number input
                TextField("6 12 34 56 78", text: $viewModel.phoneNumber)
                    .font(.satoshi(16))
                    .keyboardType(.phonePad)
                    .padding(SpacingTokens.md)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
            }

            // Send code button
            Button {
                Task { await viewModel.sendCode() }
            } label: {
                HStack {
                    if viewModel.isSendingCode {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(viewModel.codeSent ? "Renvoyer le code" : "Envoyer le code")
                    }
                }
                .font(.satoshi(16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.md)
                .background(
                    LinearGradient(
                        colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(RadiusTokens.lg)
            }
            .disabled(viewModel.isSendingCode || viewModel.phoneNumber.isEmpty)
            .opacity(viewModel.phoneNumber.isEmpty ? 0.6 : 1)
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Code Verification Section

    private var codeVerificationSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Code de vérification")
                .font(.satoshi(14, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)

            Text("Nous t'avons envoyé un code sur WhatsApp")
                .font(.satoshi(13))
                .foregroundColor(ColorTokens.textSecondary)

            // Code input
            TextField("123456", text: $viewModel.verificationCode)
                .font(.satoshi(24, weight: .bold))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding(SpacingTokens.md)
                .background(ColorTokens.background)
                .cornerRadius(RadiusTokens.md)

            // Verify button
            Button {
                Task { await viewModel.verifyCode() }
            } label: {
                HStack {
                    if viewModel.isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Vérifier et connecter")
                    }
                }
                .font(.satoshi(16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.md)
                .background(Color(red: 0.25, green: 0.72, blue: 0.45))
                .cornerRadius(RadiusTokens.lg)
            }
            .disabled(viewModel.isVerifying || viewModel.verificationCode.count < 4)
            .opacity(viewModel.verificationCode.count < 4 ? 0.6 : 1)
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Notifications")
                .font(.satoshi(16, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)

            VStack(spacing: 0) {
                preferenceToggle(
                    title: "Check-in matinal",
                    subtitle: "Planifie ta journée chaque matin",
                    icon: "sun.rise.fill",
                    isOn: $viewModel.preferences.morningCheckIn
                )

                Divider().padding(.leading, 48)

                preferenceToggle(
                    title: "Review du soir",
                    subtitle: "Fais le bilan de ta journée",
                    icon: "moon.stars.fill",
                    isOn: $viewModel.preferences.eveningReview
                )

                Divider().padding(.leading, 48)

                preferenceToggle(
                    title: "Alertes streak",
                    subtitle: "Prévenir si ta streak est en danger",
                    icon: "flame.fill",
                    isOn: $viewModel.preferences.streakAlerts
                )

                Divider().padding(.leading, 48)

                preferenceToggle(
                    title: "Rappels de quests",
                    subtitle: "Rappels avant les deadlines",
                    icon: "target",
                    isOn: $viewModel.preferences.questReminders
                )
            }
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
        .onChange(of: viewModel.preferences) { _, _ in
            Task { await viewModel.savePreferences() }
        }
    }

    private func preferenceToggle(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Image(systemName: icon)
                .font(.satoshi(16))
                .foregroundColor(ColorTokens.primaryStart)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textPrimary)

                Text(subtitle)
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textMuted)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ColorTokens.primaryStart)
        }
        .padding(SpacingTokens.md)
    }
}

// MARK: - ViewModel

@MainActor
class WhatsAppSettingsViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var isLinked = false
    @Published var phoneNumber = ""
    @Published var verificationCode = ""
    @Published var codeSent = false
    @Published var isSendingCode = false
    @Published var isVerifying = false
    @Published var preferences = WhatsAppPreferences()

    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""

    private let service = WhatsAppService.shared

    func loadStatus() async {
        isLoading = true
        do {
            let status = try await service.getStatus()
            isLinked = status.isLinked
            if let phone = status.phoneNumber {
                phoneNumber = phone
            }
            if let prefs = status.preferences {
                preferences = prefs
            }
        } catch {
            // Not linked yet, show linking UI
            isLinked = false
        }
        isLoading = false
    }

    func sendCode() async {
        guard !phoneNumber.isEmpty else { return }

        isSendingCode = true
        do {
            let response = try await service.sendVerificationCode(phoneNumber: phoneNumber)
            if response.success {
                codeSent = true
                successMessage = "Code envoyé sur WhatsApp !"
                showSuccess = true
            } else {
                errorMessage = response.message ?? "Erreur lors de l'envoi"
                showError = true
            }
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
            showError = true
        }
        isSendingCode = false
    }

    func verifyCode() async {
        guard !verificationCode.isEmpty else { return }

        isVerifying = true
        do {
            let response = try await service.verifyAndLink(
                phoneNumber: phoneNumber,
                code: verificationCode
            )
            if response.success {
                isLinked = true
                successMessage = "WhatsApp connecté ! Tu vas recevoir un message de Kai."
                showSuccess = true
            } else {
                errorMessage = response.message ?? "Code invalide"
                showError = true
            }
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
            showError = true
        }
        isVerifying = false
    }

    func unlink() async {
        do {
            try await service.unlink()
            isLinked = false
            phoneNumber = ""
            verificationCode = ""
            codeSent = false
            preferences = WhatsAppPreferences()
            successMessage = "WhatsApp déconnecté"
            showSuccess = true
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
            showError = true
        }
    }

    func savePreferences() async {
        do {
            preferences = try await service.updatePreferences(preferences)
        } catch {
            // Silent fail for preferences update
            print("Failed to update preferences: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        WhatsAppSettingsView()
    }
}
