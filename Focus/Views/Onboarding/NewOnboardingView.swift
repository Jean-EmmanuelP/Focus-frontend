//
//  NewOnboardingView.swift
//  Focus
//
//  Simplified onboarding: 1 profile screen → avatar → name → loading → paywall → meet
//

import SwiftUI
import UIKit
import Combine
import StoreKit

// MARK: - Onboarding Step Enum (6 steps)

enum NewOnboardingStep: Int, CaseIterable {
    case profileInfo = 0        // Step 1: Prénom + Nom + Sexe + Pronoms (single screen)
    case personalizeAvatar = 1  // Step 2: Personnalisez votre Focus (avatar)
    case nameCompanion = 2      // Step 3: Nommez votre Focus
    case loading = 3            // Step 4: Création avec checklist animée
    case paywall = 4            // Step 5: Paywall
    case meetCompanion = 5      // Step 6: [Nom] vous attend
}

// MARK: - API Models

private struct OnboardingSaveRequest: Encodable {
    var currentStep: Int
    var isComplete: Bool = false
    var firstName: String?
    var lastName: String?
    var sex: String?
    var ageRange: String?
    var pronouns: String?
    var companionRole: String?
    var companionGender: String?
    var companionName: String?
    var avatarStyle: String?
    var wellnessGoals: [String]?
    var lifeImprovements: [String]?
    var guideExpectations: [String]?
    var developmentAreas: [String]?
    var additionalActivities: [String]?
}

private struct OnboardingAPIResponse: Decodable {
    var isCompleted: Bool
    var currentStep: Int
    var totalSteps: Int
    var completedAt: Date?
}

// MARK: - Color Constants

private enum OnboardingColors {
    static let lightBg = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let darkNavy = Color(red: 0.08, green: 0.08, blue: 0.20)
    static let blueGradientTop = Color(red: 0.20, green: 0.45, blue: 1.0)
    static let blueGradientBottom = Color(red: 0.35, green: 0.60, blue: 1.0)
    static let cardWhite = Color.white
    static let inputBgBlue = Color.white.opacity(0.15)
}

// MARK: - Main View

struct NewOnboardingView: View {
    @EnvironmentObject var store: FocusAppStore
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel = NewOnboardingViewModel()
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isFirstNameFocused: Bool
    @FocusState private var isLastNameFocused: Bool
    @FocusState private var isCompanionNameFocused: Bool

    var body: some View {
        ZStack {
            backgroundForCurrentStep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch viewModel.currentStep {
                    case .profileInfo: profileInfoStep
                    case .personalizeAvatar: personalizeAvatarStep
                    case .nameCompanion: nameCompanionStep
                    case .loading: loadingStep
                    case .paywall: paywallStep
                    case .meetCompanion: meetCompanionStep
                    }
                }
                .id(viewModel.currentStep)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundForCurrentStep: some View {
        switch viewModel.currentStep {
        case .profileInfo:
            OnboardingColors.lightBg

        case .nameCompanion, .loading, .paywall:
            AnimatedMeshBackground()

        case .personalizeAvatar, .meetCompanion:
            Color(red: 0.10, green: 0.12, blue: 0.20)
        }
    }

    // MARK: - Nav Bar (Light Steps)

    private func lightNavBar(showBack: Bool = true) -> some View {
        HStack {
            if showBack && viewModel.currentStep.rawValue > 0 {
                Button(action: { viewModel.previousStep() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(OnboardingColors.darkNavy.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(OnboardingColors.darkNavy.opacity(0.08))
                        )
                }
            } else {
                Spacer().frame(width: 40)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundColor(OnboardingColors.darkNavy)
                Text("Focus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(OnboardingColors.darkNavy)
            }

            Spacer()
            Spacer().frame(width: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Nav Bar (Blue Steps)

    private func blueNavBar(showBack: Bool = true, showSkip: Bool = false, onSkip: (() -> Void)? = nil) -> some View {
        HStack {
            if showBack {
                Button(action: { viewModel.previousStep() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                        )
                }
            } else {
                Spacer().frame(width: 40)
            }

            Spacer()

            if showSkip, let onSkip = onSkip {
                Button(action: onSkip) {
                    Text("Passer")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                }
            } else {
                Spacer().frame(width: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Step 1: Profile Info (Light) — Name + Sex + Pronouns

    private var profileInfoStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            lightNavBar(showBack: false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Parlez-nous de vous")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(OnboardingColors.darkNavy)
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    Text("Cela aidera Focus à mieux vous accompagner.")
                        .font(.system(size: 16))
                        .foregroundColor(OnboardingColors.darkNavy.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.horizontal, 24)

                    // Name fields
                    VStack(spacing: 12) {
                        TextField("", text: $viewModel.firstName, prompt: Text("Prénom").foregroundColor(OnboardingColors.darkNavy.opacity(0.4)))
                            .font(.system(size: 17))
                            .foregroundColor(OnboardingColors.darkNavy)
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(16)
                            .focused($isFirstNameFocused)

                        TextField("", text: $viewModel.lastName, prompt: Text("Nom de famille").foregroundColor(OnboardingColors.darkNavy.opacity(0.4)))
                            .font(.system(size: 17))
                            .foregroundColor(OnboardingColors.darkNavy)
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(16)
                            .focused($isLastNameFocused)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                    // Sex selection
                    Text("Sexe")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OnboardingColors.darkNavy)
                        .padding(.top, 28)
                        .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        sexButton(text: "Homme", value: "homme")
                        sexButton(text: "Femme", value: "femme")
                        sexButton(text: "Autre", value: "autre")
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                    // Pronouns selection
                    Text("Pronoms")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OnboardingColors.darkNavy)
                        .padding(.top, 28)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        pronounButton(symbol: "♀", text: "Elle / La", value: "elle_la")
                        pronounButton(symbol: "♂", text: "Il / Lui", value: "il_lui")
                        pronounButton(symbol: "⚧", text: "Iel / Iels", value: "iel_iels")
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120) // Space for the floating button
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            blueContinueButton(
                enabled: !viewModel.firstName.isEmpty && !viewModel.selectedSex.isEmpty && !viewModel.selectedPronouns.isEmpty,
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.saveAndNext(step: 0, data: [
                        "first_name": viewModel.firstName,
                        "last_name": viewModel.lastName,
                        "sex": viewModel.selectedSex,
                        "pronouns": viewModel.selectedPronouns
                    ])
                }
            }
            .background(OnboardingColors.lightBg)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFirstNameFocused = true
            }
        }
    }

    private func sexButton(text: String, value: String) -> some View {
        let isSelected = viewModel.selectedSex == value
        return Button(action: {
            HapticFeedback.selection()
            viewModel.selectedSex = value
            // Auto-suggest pronouns based on sex
            if value == "homme" && viewModel.selectedPronouns.isEmpty {
                viewModel.selectedPronouns = "il_lui"
            } else if value == "femme" && viewModel.selectedPronouns.isEmpty {
                viewModel.selectedPronouns = "elle_la"
            }
        }) {
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isSelected ? .white : OnboardingColors.darkNavy)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isSelected ? OnboardingColors.blueGradientTop : Color.white)
                .cornerRadius(14)
        }
    }

    private func pronounButton(symbol: String, text: String, value: String) -> some View {
        let isSelected = viewModel.selectedPronouns == value
        return Button(action: {
            HapticFeedback.selection()
            viewModel.selectedPronouns = value
        }) {
            HStack(spacing: 16) {
                Text(symbol)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : OnboardingColors.darkNavy)

                Text(text)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? .white : OnboardingColors.darkNavy)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 60)
            .background(isSelected ? OnboardingColors.blueGradientTop : Color.white)
            .cornerRadius(16)
        }
    }

    // MARK: - Step 2: Personalize Avatar

    private var personalizeAvatarStep: some View {
        ZStack {
            FocusPulseView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { viewModel.previousStep() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }

                    Spacer()

                    Text("Votre compagnon Focus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()
                    Spacer().frame(width: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                whiteContinueButton(isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.saveAndNext(step: 1, data: [
                            "avatar_style": "pulse"
                        ])
                    }
                }
                .padding(.bottom, 16)

                Text("Votre compagnon Focus vous\naccompagnera au quotidien.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Step 3: Name Companion (Blue)

    private var nameCompanionStep: some View {
        VStack(spacing: 0) {
            blueNavBar()

            Text("Nommez votre Focus")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 32)
                .padding(.horizontal, 24)

            TextField("", text: $viewModel.companionName, prompt: Text("Nom").foregroundColor(.white.opacity(0.4)))
                .font(.system(size: 17))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .frame(height: 56)
                .background(Color.white.opacity(0.12))
                .cornerRadius(28)
                .padding(.horizontal, 48)
                .padding(.top, 24)
                .focused($isCompanionNameFocused)

            Spacer()

            whiteContinueButton(isLoading: viewModel.isLoading) {
                Task {
                    await viewModel.saveAndStartLoading()
                }
            }
            .padding(.bottom, 50)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isCompanionNameFocused = true
            }
        }
    }

    // MARK: - Step 4: Loading with Checklist (Blue)

    private var loadingStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                loadingCheckItem(text: "Découvrir vos intérêts", index: 0)
                loadingCheckItem(text: "Rendre leur apparence juste parfaite", index: 1)
                loadingCheckItem(text: "Considérer quelles questions poser", index: 2)
                loadingCheckItem(text: "Nous sommes aussi impatients à ce sujet que vous.", index: 3)
                loadingCheckItem(text: "Presque prêt à dire bonjour", index: 4)
            }
            .padding(.horizontal, 40)

            Spacer()

            Text("Nous créons \(viewModel.displayName)\npour vous")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            Text("Cela peut prendre jusqu'à 2 minutes.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.6))

            Spacer()
        }
    }

    private func loadingCheckItem(text: String, index: Int) -> some View {
        let isCompleted = viewModel.loadingProgress > index
        let isCurrent = viewModel.loadingProgress == index

        return HStack(spacing: 14) {
            if isCurrent {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: isCompleted ? "checkmark" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isCompleted ? .white : .white.opacity(0.3))
                    .frame(width: 20, height: 20)
            }

            Text(text)
                .font(.system(size: 15, weight: isCompleted || isCurrent ? .semibold : .regular))
                .foregroundColor(isCompleted || isCurrent ? .white : .white.opacity(0.4))
        }
    }

    // MARK: - Step 5: Paywall

    private var paywallStep: some View {
        FocusPaywallView(
            companionName: viewModel.displayName,
            onComplete: {
                viewModel.currentStep = .meetCompanion
            },
            onSkip: {
                viewModel.currentStep = .meetCompanion
            }
        )
        .environmentObject(subscriptionManager)
    }

    // MARK: - Step 6: Meet Companion (Avatar background)

    private var meetCompanionStep: some View {
        ZStack {
            FocusPulseView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                    Text("Fait")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))

                Text("\(viewModel.displayName) vous attend")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 32)

                Button(action: {
                    HapticFeedback.success()
                    completeOnboarding()
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Rencontrer \(viewModel.displayName)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white.opacity(0.2))
                .cornerRadius(28)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .disabled(viewModel.isLoading)

                Text("\(viewModel.displayName) est une IA et ne peut pas fournir de conseils\nmédicaux. En cas de crise, demandez de l'aide à un\nexpert.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Shared Components

    private func blueContinueButton(enabled: Bool = true, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            guard !isLoading else { return }
            HapticFeedback.selection()
            action()
        }) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("Continuer")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 200, height: 56)
        .background(OnboardingColors.blueGradientTop)
        .cornerRadius(28)
        .disabled(!enabled || isLoading)
        .opacity(enabled ? 1 : 0.4)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 50)
    }

    private func whiteContinueButton(text: String = "Continuer", isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            guard !isLoading else { return }
            HapticFeedback.selection()
            action()
        }) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: OnboardingColors.darkNavy))
            } else {
                Text(text)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(OnboardingColors.darkNavy)
            }
        }
        .frame(width: 240, height: 56)
        .background(Color.white)
        .cornerRadius(28)
        .disabled(isLoading)
    }

    // MARK: - Actions

    private func completeOnboarding() {
        viewModel.isLoading = true
        Task {
            await viewModel.completeOnboarding()
            await store.completeOnboarding()
            HapticFeedback.success()
            dismiss()
        }
    }
}

// MARK: - ViewModel

@MainActor
class NewOnboardingViewModel: ObservableObject {
    @Published var currentStep: NewOnboardingStep = .profileInfo
    @Published var isLoading = false

    // Step 1: Profile info
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var selectedSex: String = ""
    @Published var selectedPronouns: String = ""

    // Step 2: Avatar customization
    @Published var selectedAvatarStyle: String = "realistic"

    // Step 3: Companion name
    @Published var companionName: String = ""

    // Loading state
    @Published var loadingProgress: Int = 0

    var displayName: String {
        companionName.isEmpty ? "ton coach" : companionName
    }

    func nextStep() {
        guard let next = NewOnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func previousStep() {
        guard currentStep.rawValue > 0,
              let previous = NewOnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    // MARK: - API Calls

    func saveAndNext(step: Int, data: [String: Any]) async {
        isLoading = true
        defer { isLoading = false }

        do {
            var request = OnboardingSaveRequest(currentStep: step)

            if let firstName = data["first_name"] as? String {
                request.firstName = firstName
            }
            if let lastName = data["last_name"] as? String {
                request.lastName = lastName
            }
            if let sex = data["sex"] as? String {
                request.sex = sex
            }
            if let pronouns = data["pronouns"] as? String {
                request.pronouns = pronouns
            }
            if let companionGender = data["companion_gender"] as? String {
                request.companionGender = companionGender
            }
            if let avatarStyle = data["avatar_style"] as? String {
                request.avatarStyle = avatarStyle
            }

            let _: OnboardingAPIResponse = try await APIClient.shared.request(
                endpoint: .onboardingProgress,
                method: .put,
                body: request
            )

            nextStep()
        } catch {
            print("Failed to save onboarding step \(step): \(error)")
            nextStep()
        }
    }

    func saveAndStartLoading() async {
        isLoading = true

        do {
            var request = OnboardingSaveRequest(currentStep: 2)
            request.companionName = companionName.isEmpty ? nil : companionName

            let _: OnboardingAPIResponse = try await APIClient.shared.request(
                endpoint: .onboardingProgress,
                method: .put,
                body: request
            )
        } catch {
            print("Failed to save companion name: \(error)")
        }

        isLoading = false
        currentStep = .loading
        startLoadingAnimation()
    }

    private func startLoadingAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { self.loadingProgress = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { self.loadingProgress = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { self.loadingProgress = 3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation { self.loadingProgress = 4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation { self.loadingProgress = 5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
            self.currentStep = .paywall
        }
    }

    func completeOnboarding() async {
        do {
            struct CompleteRequest: Encodable {
                var isComplete: Bool = true
            }

            let _: OnboardingAPIResponse = try await APIClient.shared.request(
                endpoint: .onboardingComplete,
                method: .post,
                body: CompleteRequest()
            )
        } catch {
            print("Failed to complete onboarding: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    NewOnboardingView()
        .environmentObject(FocusAppStore.shared)
        .environmentObject(SubscriptionManager.shared)
}
