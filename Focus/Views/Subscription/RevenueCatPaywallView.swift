//
//  RevenueCatPaywallView.swift
//  Focus
//
//  Custom Paywall using RevenueCat offerings
//

import SwiftUI
import RevenueCat
import RevenueCatUI

// MARK: - RevenueCat Native Paywall
/// Use this view to present RevenueCat's built-in paywall UI
/// Requires configuring a paywall template in RevenueCat dashboard
struct RevenueCatNativePaywall: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var revenueCatManager: RevenueCatManager

    var onPurchaseCompleted: (() -> Void)?
    var onRestoreCompleted: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        PaywallView(
            displayCloseButton: true
        )
        .onPurchaseCompleted { customerInfo in
            print("✅ Purchase completed via native paywall")
            onPurchaseCompleted?()
        }
        .onRestoreCompleted { customerInfo in
            print("✅ Restore completed via native paywall")
            onRestoreCompleted?()
        }
    }
}

// MARK: - Custom Volta Paywall
/// Custom-designed paywall using RevenueCat data
struct VoltaPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var onComplete: (() -> Void)?
    var onSkip: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: "#1A1A2E"), Color(hex: "#16213E"), Color(hex: "#0F3460")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Close button
                        HStack {
                            Spacer()
                            Button(action: {
                                onSkip?()
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(SpacingTokens.sm)
                            }
                        }
                        .padding(.horizontal, SpacingTokens.md)
                        .padding(.top, SpacingTokens.sm)

                        // Header
                        headerSection(isSmallScreen: isSmallScreen)

                        // Benefits
                        benefitsSection
                            .padding(.bottom, SpacingTokens.xl)

                        // Packages
                        if revenueCatManager.isLoading && revenueCatManager.offerings == nil {
                            loadingSection
                        } else if let _ = revenueCatManager.currentOffering {
                            packagesSection
                        } else {
                            errorSection
                        }

                        Spacer()
                            .frame(height: SpacingTokens.xl)

                        // CTA
                        ctaSection(geometry: geometry)
                    }
                }

                // Loading overlay
                if isPurchasing {
                    purchaseLoadingOverlay
                }
            }
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            // Fetch offerings if not already loaded
            if revenueCatManager.offerings == nil {
                await revenueCatManager.fetchOfferings()
            }

            // Pre-select yearly package
            if selectedPackage == nil {
                selectedPackage = revenueCatManager.yearlyPackage ?? revenueCatManager.monthlyPackage
            }
        }
    }

    // MARK: - Header
    private func headerSection(isSmallScreen: Bool) -> some View {
        VStack(spacing: SpacingTokens.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FFD700").opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Text("👑")
                    .font(.system(size: isSmallScreen ? 60 : 70))
            }

            Text("Deviens Volta Pro")
                .font(.inter(isSmallScreen ? 26 : 32, weight: .bold))
                .foregroundColor(.white)

            Text("Debloque tout le potentiel de Volta")
                .bodyText()
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, SpacingTokens.xl)
    }

    // MARK: - Benefits
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            benefitRow(icon: "flame.fill", text: "Sessions FireMode illimitees", color: .orange)
            benefitRow(icon: "person.3.fill", text: "Rejoins la communaute", color: .blue)
            benefitRow(icon: "star.fill", text: "Gamifie ta vie", color: .yellow)
            benefitRow(icon: "chart.bar.fill", text: "Statistiques avancees", color: .green)
            benefitRow(icon: "target", text: "Quests & objectifs illimites", color: .purple)
            benefitRow(icon: "bell.fill", text: "Rappels intelligents", color: .cyan)
        }
        .padding(.horizontal, SpacingTokens.xl)
    }

    private func benefitRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 28)

            Text(text)
                .bodyText()
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
        }
    }

    // MARK: - Packages
    private var packagesSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // Yearly (recommended)
            if let yearly = revenueCatManager.yearlyPackage {
                packageCard(
                    package: yearly,
                    title: "Annuel",
                    subtitle: yearly.storeProduct.localizedPriceString + "/an",
                    badge: "MEILLEURE OFFRE",
                    isRecommended: true
                )
            }

            // Monthly
            if let monthly = revenueCatManager.monthlyPackage {
                packageCard(
                    package: monthly,
                    title: "Mensuel",
                    subtitle: monthly.storeProduct.localizedPriceString + "/mois",
                    badge: nil,
                    isRecommended: false
                )
            }

            // Lifetime
            if let lifetime = revenueCatManager.lifetimePackage {
                packageCard(
                    package: lifetime,
                    title: "A vie",
                    subtitle: lifetime.storeProduct.localizedPriceString + " (paiement unique)",
                    badge: "POPULAIRE",
                    isRecommended: false
                )
            }
        }
        .padding(.horizontal, SpacingTokens.xl)
    }

    private func packageCard(
        package: Package,
        title: String,
        subtitle: String,
        badge: String?,
        isRecommended: Bool
    ) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPackage = package
            }
            HapticFeedback.selection()
        }) {
            VStack(spacing: 0) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#FFD700"))
                        .cornerRadius(4, corners: [.topLeft, .topRight])
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.inter(16, weight: .bold))
                            .foregroundColor(.white)

                        if let pricePerWeek = package.localizedPricePerWeek {
                            Text("\(pricePerWeek)/semaine")
                                .font(.inter(12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(package.storeProduct.localizedPriceString)
                            .font(.inter(20, weight: .bold))
                            .foregroundColor(.white)

                        if package.packageType == .annual {
                            Text("/an")
                                .font(.inter(12))
                                .foregroundColor(.white.opacity(0.5))
                        } else if package.packageType == .monthly {
                            Text("/mois")
                                .font(.inter(12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color(hex: "#FFD700") : Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(Color(hex: "#FFD700"))
                                .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.leading, SpacingTokens.sm)
                }
                .padding(SpacingTokens.lg)
                .background(
                    RoundedRectangle(cornerRadius: badge != nil ? 0 : RadiusTokens.lg)
                        .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                        .cornerRadius(RadiusTokens.lg, corners: badge != nil ? [.bottomLeft, .bottomRight] : .allCorners)
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .stroke(isSelected ? Color(hex: "#FFD700") : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Loading
    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)

            Text("Chargement des offres...")
                .bodyText()
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, SpacingTokens.xxl)
    }

    // MARK: - Error
    private var errorSection: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.yellow)

            Text("Impossible de charger les offres")
                .bodyText()
                .foregroundColor(.white)

            Button("Reessayer") {
                Task {
                    await revenueCatManager.fetchOfferings()
                }
            }
            .font(.inter(14, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, SpacingTokens.xl)
            .padding(.vertical, SpacingTokens.sm)
            .background(Color(hex: "#FFD700"))
            .cornerRadius(RadiusTokens.md)
        }
        .padding(.vertical, SpacingTokens.xxl)
    }

    // MARK: - CTA
    private func ctaSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: SpacingTokens.md) {
            // Purchase button
            Button(action: handlePurchase) {
                HStack {
                    Text("Commencer maintenant")
                    Image(systemName: "arrow.right")
                }
                .bodyText()
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.md + 4)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(RadiusTokens.lg)
            }
            .disabled(selectedPackage == nil || isPurchasing)
            .opacity(selectedPackage == nil ? 0.5 : 1)

            // Trial info
            if let package = selectedPackage,
               let intro = package.storeProduct.introductoryDiscount {
                if intro.price == 0 {
                    Text("\(intro.subscriptionPeriod.periodTitle) d'essai gratuit")
                        .font(.inter(12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Restore & Terms
            HStack(spacing: SpacingTokens.lg) {
                Button("Restaurer") {
                    Task { await handleRestore() }
                }
                .font(.inter(12))
                .foregroundColor(.white.opacity(0.5))

                Text("•")
                    .foregroundColor(.white.opacity(0.3))

                Button("CGV") {
                    // Open terms
                }
                .font(.inter(12))
                .foregroundColor(.white.opacity(0.5))

                Text("•")
                    .foregroundColor(.white.opacity(0.3))

                Button("Confidentialite") {
                    // Open privacy
                }
                .font(.inter(12))
                .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, SpacingTokens.xl)
        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.lg : SpacingTokens.xxl)
    }

    // MARK: - Purchase Loading
    private var purchaseLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("Traitement en cours...")
                    .bodyText()
                    .foregroundColor(.white)
            }
            .padding(SpacingTokens.xl)
            .background(Color(hex: "#1A1A2E"))
            .cornerRadius(RadiusTokens.lg)
        }
    }

    // MARK: - Actions
    private func handlePurchase() {
        guard let package = selectedPackage else { return }

        isPurchasing = true
        HapticFeedback.medium()

        Task {
            let success = await revenueCatManager.purchase(package: package)
            isPurchasing = false

            if success {
                HapticFeedback.success()
                onComplete?()
                dismiss()
            } else if let error = revenueCatManager.errorMessage {
                errorMessage = error
                showError = true
            }
        }
    }

    private func handleRestore() async {
        isPurchasing = true

        let success = await revenueCatManager.restorePurchases()
        isPurchasing = false

        if success {
            HapticFeedback.success()
            onComplete?()
            dismiss()
        } else if let error = revenueCatManager.errorMessage {
            errorMessage = error
            showError = true
        }
    }
}

// MARK: - Preview
#Preview {
    VoltaPaywallView()
        .environmentObject(RevenueCatManager.shared)
}
