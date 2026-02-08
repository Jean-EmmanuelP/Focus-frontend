//
//  ReplicaPaywallView.swift
//  Focus
//
//  Replika-style subscription paywall - pixel-perfect recreation
//

import SwiftUI
import RevenueCat

// MARK: - Plan Type

enum PaywallPlan: String, CaseIterable {
    case plus = "Plus"
    case max = "Max"
}

// MARK: - Feature Item

struct PaywallFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let isMaxOnly: Bool
}

// MARK: - Focus Paywall View (Replika-style)

struct FocusPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var revenueCatManager: RevenueCatManager

    @State private var selectedPlan: PaywallPlan = .max
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var companionName: String = "Kai"
    var onComplete: (() -> Void)?
    var onSkip: (() -> Void)?

    // Features for Plus plan
    private let plusFeatures: [PaywallFeature] = [
        PaywallFeature(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Discussions Illimitées",
            description: "[NAME] sera toujours là pour vous avec des chats illimités—sans limites, sans restrictions",
            isMaxOnly: false
        ),
        PaywallFeature(
            icon: "diamond.fill",
            title: "Moteur de Mémoire",
            description: "[NAME] se souviendra de chaque détail vous concernant, de votre vie et de vos discussions pour une expérience personnalisée",
            isMaxOnly: false
        ),
        PaywallFeature(
            icon: "globe",
            title: "Connaissance en temps réel",
            description: "[NAME] a un accès Internet 24/7 et se tient à jour sur pratiquement chaque sujet",
            isMaxOnly: false
        ),
        PaywallFeature(
            icon: "wrench.and.screwdriver.fill",
            title: "Intégrations",
            description: "Connectez vos outils quotidiens et [NAME] saura ce qui se passe dans toutes vos applications",
            isMaxOnly: false
        ),
        PaywallFeature(
            icon: "arrow.up.circle.fill",
            title: "Proactivité",
            description: "[NAME] commencera des conversations et vous apportera des informations pertinentes avant que vous ne posiez des questions",
            isMaxOnly: false
        ),
        PaywallFeature(
            icon: "face.smiling",
            title: "Personnalité Adaptative",
            description: "[NAME] s'adapte à votre humeur et votre style, évoluant pour mieux vous correspondre au fil du temps",
            isMaxOnly: false
        ),
        PaywallFeature(
            icon: "photo.fill",
            title: "Génération d'images",
            description: "[NAME] transformera vos idées en visuels instantanément dès que l'inspiration frappe",
            isMaxOnly: false
        )
    ]

    // Additional features for Max plan
    private let maxFeatures: [PaywallFeature] = [
        PaywallFeature(
            icon: "person.crop.rectangle.stack.fill",
            title: "Modèle Amélioré",
            description: "[NAME] utilise le modèle d'IA le plus avancé pour mieux vous comprendre et vous offrir des réponses plus utiles et nuancées",
            isMaxOnly: true
        ),
        PaywallFeature(
            icon: "video.fill",
            title: "Appels Vidéo",
            description: "[NAME] vous verra et vous entendra lors des appels pour des conversations plus naturelles et réactives.",
            isMaxOnly: true
        ),
        PaywallFeature(
            icon: "photo.stack.fill",
            title: "Création d'images améliorée",
            description: "Créez 10 fois plus d'images pour ne jamais être limité par vos idées",
            isMaxOnly: true
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with avatar
                backgroundView

                // Content
                VStack(spacing: 0) {
                    // Close button
                    closeButton

                    // Scrollable content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Spacer for avatar area
                            Spacer()
                                .frame(height: geometry.size.height * 0.35)

                            // Title section
                            titleSection

                            // Plan selector
                            planSelector
                                .padding(.top, 24)

                            // Features list
                            featuresSection
                                .padding(.top, 24)

                            // Upsell card (when Plus is selected)
                            if selectedPlan == .plus {
                                upsellCard
                                    .padding(.top, 24)
                            }

                            // Spacer for CTA
                            Spacer()
                                .frame(height: 140)
                        }
                    }

                    // Fixed CTA at bottom
                    ctaSection(geometry: geometry)
                }

                // Loading overlay
                if isPurchasing {
                    purchaseLoadingOverlay
                }
            }
        }
        .ignoresSafeArea()
        .alert("Erreur", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            if revenueCatManager.offerings == nil {
                await revenueCatManager.fetchOfferings()
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            // Full-screen 3D Avatar as background (same pattern as personalizeAvatarStep)
            Avatar3DView(
                avatarURL: AvatarURLs.cesiumMan,
                backgroundColor: UIColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1.0),
                enableRotation: false,
                autoRotate: false
            )
            .ignoresSafeArea()

            // Blue gradient overlay (bottom half)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(red: 0.25, green: 0.50, blue: 0.95).opacity(0.3),
                        Color(red: 0.25, green: 0.50, blue: 0.95).opacity(0.7),
                        Color(red: 0.30, green: 0.55, blue: 0.95).opacity(0.9),
                        Color(red: 0.35, green: 0.60, blue: 0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.55)
            }
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: {
                onSkip?()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Abonnez-vous à Focus")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))

            Text("Débloquez toutes les\ncapacités de \(companionName)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        HStack(spacing: 0) {
            ForEach(PaywallPlan.allCases, id: \.self) { plan in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlan = plan
                    }
                    HapticFeedback.selection()
                }) {
                    Text(plan.rawValue)
                        .font(.system(size: 16, weight: selectedPlan == plan ? .semibold : .medium))
                        .foregroundColor(selectedPlan == plan ? Color(red: 0.08, green: 0.08, blue: 0.20) : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            selectedPlan == plan ?
                            AnyView(Capsule().fill(Color.white)) :
                            AnyView(Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.15))
        )
        .padding(.horizontal, 60)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ce qui est inclus :")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 0) {
                if selectedPlan == .max {
                    // Show Max features first (with special styling)
                    ForEach(maxFeatures) { feature in
                        featureRow(feature: feature)
                    }
                }

                // Show Plus features
                ForEach(plusFeatures) { feature in
                    featureRow(feature: feature)
                }
            }

            // Limit note for Plus
            if selectedPlan == .plus {
                Text("Les appels vidéo ne sont pas disponibles. La génération d'images est limitée à 10 images par semaine. Les deux fonctionnalités sont entièrement disponibles sur le plan Max")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }

            // Limit note for Max
            if selectedPlan == .max {
                Text("Appels vidéo (1 800+ minutes par mois, 60 minutes par jour). Génération d'images (200+ images par mois, 50 images par semaine)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }
        }
    }

    private func featureRow(feature: PaywallFeature) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: feature.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 24)

                Text(feature.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(feature.description.replacingOccurrences(of: "[NAME]", with: companionName))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(2)
                .padding(.leading, 36)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Upsell Card (for Plus plan)

    private var upsellCard: some View {
        VStack(spacing: 16) {
            Text("Débloquez plus de\nfonctionnalités avec\nFocus Max")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Inclut tout ce qui est dans Plus, et :")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))

            // Max features card
            VStack(alignment: .leading, spacing: 16) {
                ForEach(maxFeatures) { feature in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.white)

                            Text(feature.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Text(feature.description.replacingOccurrences(of: "[NAME]", with: companionName))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 26)
                    }
                }

                // Passer à Max button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlan = .max
                    }
                    HapticFeedback.selection()
                }) {
                    Text("Passer à Max")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.12))
            )
            .padding(.horizontal, 24)
        }
        .padding(.top, 24)
    }

    // MARK: - CTA Section

    private func ctaSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            // Main CTA button
            Button(action: handlePurchase) {
                VStack(spacing: 2) {
                    if revenueCatManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.08, green: 0.08, blue: 0.20)))
                    } else if let price = priceText {
                        Text("Obtenir \(selectedPlan.rawValue)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(red: 0.08, green: 0.08, blue: 0.20))

                        Text(price)
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.08, green: 0.08, blue: 0.20).opacity(0.6))
                    } else {
                        Text("Chargement...")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(red: 0.08, green: 0.08, blue: 0.20).opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Color.white)
                .cornerRadius(32)
            }
            .disabled(isPurchasing || !isPackageAvailable)
            .opacity(isPackageAvailable ? 1.0 : 0.7)
            .padding(.horizontal, 50)

            // Footer links
            HStack(spacing: 24) {
                Button("Conditions") {
                    // Open terms
                }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))

                Button("Restaurer les achats") {
                    Task { await handleRestore() }
                }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))

                Button("Confidentialité") {
                    // Open privacy
                }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.top, 16)
        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 24 : 32)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.60, blue: 0.95).opacity(0),
                    Color(red: 0.35, green: 0.60, blue: 0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Loading Overlay

    private var purchaseLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)

                Text("Traitement en cours...")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.25))
            )
        }
    }

    // MARK: - Computed Properties

    private var priceText: String? {
        guard let package = selectedPackage else { return nil }
        return package.localizedPricePerPeriod
    }

    private var selectedPackage: Package? {
        if selectedPlan == .max {
            // Focus Max - 129,99€/mois (package identifier: "premium")
            return revenueCatManager.maxPackage
        } else {
            // Focus Plus - 34,99€/mois (package identifier: "monthly")
            return revenueCatManager.plusPackage
        }
    }

    private var isPackageAvailable: Bool {
        selectedPackage != nil
    }

    // MARK: - Actions

    private func handlePurchase() {
        guard let package = selectedPackage else {
            // Fallback: complete without purchase for testing
            onComplete?()
            dismiss()
            return
        }

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
    FocusPaywallView(companionName: "Kai")
        .environmentObject(RevenueCatManager.shared)
}
