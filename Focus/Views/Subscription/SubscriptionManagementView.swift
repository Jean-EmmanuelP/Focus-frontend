//
//  SubscriptionManagementView.swift
//  Focus
//
//  Subscription management and Customer Center
//

import SwiftUI
import RevenueCat
import RevenueCatUI

// MARK: - Subscription Management View
/// Main view for managing subscriptions - accessible from Settings
struct SubscriptionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var showPaywall = false
    @State private var showCustomerCenter = false
    @State private var isRestoring = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.xl) {
                        // Current Plan Card
                        currentPlanCard

                        // Actions
                        if revenueCatManager.isProUser {
                            // Pro user - show manage options
                            manageSubscriptionSection
                        } else {
                            // Free user - show upgrade option
                            upgradeSection
                        }

                        // Features comparison
                        featuresComparisonSection

                        // Help section
                        helpSection
                    }
                    .padding(SpacingTokens.lg)
                }
            }
            .navigationTitle("Abonnement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                VoltaPaywallView(
                    onComplete: {
                        showPaywall = false
                    },
                    onSkip: {
                        showPaywall = false
                    }
                )
                .environmentObject(revenueCatManager)
            }
            .sheet(isPresented: $showCustomerCenter) {
                CustomerCenterView()
            }
            .alert("Restauration", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage)
            }
        }
    }

    // MARK: - Current Plan Card
    private var currentPlanCard: some View {
        VStack(spacing: SpacingTokens.md) {
            // Status icon
            ZStack {
                Circle()
                    .fill(revenueCatManager.isProUser
                          ? Color(hex: "#FFD700").opacity(0.2)
                          : ColorTokens.surface)
                    .frame(width: 80, height: 80)

                Text(revenueCatManager.isProUser ? "👑" : "🔓")
                    .font(.system(size: 40))
            }

            // Plan name
            Text(currentPlanName)
                .font(.satoshi(24, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            // Status badge
            HStack(spacing: SpacingTokens.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.satoshi(14))
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.xs)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.full)

            // Expiration date (if applicable)
            if let expirationDate = revenueCatManager.customerInfo?.entitlements["Volta Pro"]?.expirationDate {
                Text("Renouvellement le \(formattedDate(expirationDate))")
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.xl)
        .background(
            revenueCatManager.isProUser
            ? LinearGradient(
                colors: [Color(hex: "#1A1A2E"), Color(hex: "#16213E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [ColorTokens.surface, ColorTokens.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(RadiusTokens.xl)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.xl)
                .stroke(
                    revenueCatManager.isProUser ? Color(hex: "#FFD700").opacity(0.3) : ColorTokens.border,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Manage Subscription Section
    private var manageSubscriptionSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // Customer Center button
            Button(action: { showCustomerCenter = true }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(ColorTokens.primaryStart)

                    Text("Gerer mon abonnement")
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(ColorTokens.textMuted)
                }
                .padding(SpacingTokens.lg)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.lg)
            }

            // Restore button
            Button(action: handleRestore) {
                HStack {
                    if isRestoring {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.textSecondary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    Text("Restaurer les achats")
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)

                    Spacer()
                }
                .padding(SpacingTokens.lg)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.lg)
            }
            .disabled(isRestoring)
        }
    }

    // MARK: - Upgrade Section
    private var upgradeSection: some View {
        VStack(spacing: SpacingTokens.md) {
            Button(action: { showPaywall = true }) {
                HStack {
                    Text("👑")
                        .font(.system(size: 24))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Passer a Volta Pro")
                            .font(.satoshi(16, weight: .bold))
                            .foregroundColor(.black)

                        Text("Debloquer toutes les fonctionnalites")
                            .font(.satoshi(12))
                            .foregroundColor(.black.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .foregroundColor(.black)
                }
                .padding(SpacingTokens.lg)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(RadiusTokens.lg)
            }

            // Restore button
            Button(action: handleRestore) {
                HStack {
                    if isRestoring {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.textSecondary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    Text("Restaurer les achats")
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)

                    Spacer()
                }
                .padding(SpacingTokens.lg)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.lg)
            }
            .disabled(isRestoring)
        }
    }

    // MARK: - Features Comparison
    private var featuresComparisonSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Fonctionnalites")
                .font(.satoshi(18, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            VStack(spacing: SpacingTokens.sm) {
                featureRow("Sessions FireMode", free: "3/jour", pro: "Illimite")
                featureRow("Quests", free: "3 max", pro: "Illimite")
                featureRow("Statistiques", free: "Basiques", pro: "Avancees")
                featureRow("Crew", free: "1 groupe", pro: "Illimite")
                featureRow("Themes", free: "Standard", pro: "Premium")
                featureRow("Support", free: "Email", pro: "Prioritaire")
            }
            .padding(SpacingTokens.lg)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
    }

    private func featureRow(_ name: String, free: String, pro: String) -> some View {
        HStack {
            Text(name)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)

            Spacer()

            HStack(spacing: SpacingTokens.lg) {
                Text(free)
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textMuted)
                    .frame(width: 60, alignment: .center)

                Text(pro)
                    .font(.satoshi(12, weight: .semibold))
                    .foregroundColor(Color(hex: "#FFD700"))
                    .frame(width: 60, alignment: .center)
            }
        }
    }

    // MARK: - Help Section
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Aide")
                .font(.satoshi(18, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            VStack(spacing: 0) {
                helpRow(icon: "questionmark.circle", title: "FAQ", subtitle: "Questions frequentes")
                Divider().background(ColorTokens.border)
                helpRow(icon: "envelope", title: "Contact", subtitle: "support@volta.app")
                Divider().background(ColorTokens.border)
                helpRow(icon: "doc.text", title: "CGV", subtitle: "Conditions d'utilisation")
            }
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
    }

    private func helpRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Image(systemName: icon)
                .font(.satoshi(18))
                .foregroundColor(ColorTokens.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .bodyText()
                    .foregroundColor(ColorTokens.textPrimary)

                Text(subtitle)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.satoshi(14))
                .foregroundColor(ColorTokens.textMuted)
        }
        .padding(SpacingTokens.lg)
    }

    // MARK: - Computed Properties
    private var currentPlanName: String {
        switch revenueCatManager.subscriptionState {
        case .subscribed(let tier):
            switch tier {
            case .monthly: return "Volta Pro Mensuel"
            case .yearly: return "Volta Pro Annuel"
            case .lifetime: return "Volta Pro A vie"
            }
        case .expired:
            return "Abonnement expire"
        case .notSubscribed, .unknown:
            return "Plan Gratuit"
        }
    }

    private var statusColor: Color {
        switch revenueCatManager.subscriptionState {
        case .subscribed: return .green
        case .expired: return .orange
        case .notSubscribed, .unknown: return ColorTokens.textMuted
        }
    }

    private var statusText: String {
        switch revenueCatManager.subscriptionState {
        case .subscribed: return "Actif"
        case .expired: return "Expire"
        case .notSubscribed, .unknown: return "Gratuit"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }

    // MARK: - Actions
    private func handleRestore() {
        isRestoring = true

        Task {
            let success = await revenueCatManager.restorePurchases()
            isRestoring = false

            if success {
                restoreMessage = "Vos achats ont ete restaures avec succes !"
            } else {
                restoreMessage = revenueCatManager.errorMessage ?? "Aucun achat a restaurer"
            }
            showRestoreAlert = true
        }
    }
}

// MARK: - Customer Center View (RevenueCat Native)
struct CustomerCenterView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // Use RevenueCat's built-in Customer Center if available
            // For now, show a simple management view
            ManageSubscriptionsView(
                onDismiss: { dismiss() }
            )
            .navigationTitle("Gerer l'abonnement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Manage Subscriptions View
struct ManageSubscriptionsView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.xl) {
                Spacer()

                Image(systemName: "gearshape.2")
                    .font(.system(size: 60))
                    .foregroundColor(ColorTokens.textMuted)

                VStack(spacing: SpacingTokens.sm) {
                    Text("Gestion de l'abonnement")
                        .font(.satoshi(20, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Pour modifier ou annuler votre abonnement, utilisez les parametres de votre compte Apple.")
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.xl)
                }

                Spacer()

                VStack(spacing: SpacingTokens.md) {
                    // Open subscription settings
                    Button(action: openSubscriptionSettings) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Ouvrir les parametres")
                        }
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.md)
                        .background(ColorTokens.fireGradient)
                        .cornerRadius(RadiusTokens.lg)
                    }

                    Button("Retour") {
                        onDismiss()
                    }
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
                }
                .padding(.horizontal, SpacingTokens.xl)
                .padding(.bottom, SpacingTokens.xxl)
            }
        }
    }

    private func openSubscriptionSettings() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview
#Preview {
    SubscriptionManagementView()
        .environmentObject(RevenueCatManager.shared)
}
