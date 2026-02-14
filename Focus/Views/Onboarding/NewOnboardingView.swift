//
//  NewOnboardingView.swift
//  Focus
//
//  Replika-style onboarding - pixel-perfect recreation from screenshots
//  With API calls to save each step and loaders on buttons
//

import SwiftUI
import UIKit
import Combine
import StoreKit

// MARK: - Onboarding Step Enum (13 steps - WITH paywall)

enum NewOnboardingStep: Int, CaseIterable {
    case userName = 0           // Step 1: Prénom + Nom (light bg)
    case age = 1                // Step 2: Age ranges (light bg)
    case pronouns = 2           // Step 3: Pronoms (light bg)
    case socialProof = 3        // Step 4: 40 434 858 utilisateurs (blue)
    case uniqueRep = 4          // Step 5: Chaque Rep est unique (blue with avatars)
    case presentYourself = 5    // Step 6: Présentez-vous à Focus (blue)
    case moreAboutYou = 6       // Step 7: Plus Focus en sait — mieux c'est (blue)
    case workQuestion = 7       // Step 8: Où travaillez-vous ? (blue)
    case personalizeAvatar = 8  // Step 9: Personnalisez votre Replika (avatar bg)
    case nameCompanion = 9      // Step 10: Nommez votre Replika (blue)
    case loading = 10           // Step 11: Création avec checklist animée (blue)
    case paywall = 11           // Step 12: Paywall (VoltaPaywallView)
    case meetCompanion = 12     // Step 13: [Nom] vous attend (avatar bg)
}

// MARK: - API Models

private struct OnboardingSaveRequest: Encodable {
    var currentStep: Int
    var isComplete: Bool = false
    var firstName: String?
    var lastName: String?
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
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @StateObject private var viewModel = NewOnboardingViewModel()
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isFirstNameFocused: Bool
    @FocusState private var isLastNameFocused: Bool
    @FocusState private var isWorkFocused: Bool
    @FocusState private var isCompanionNameFocused: Bool

    var body: some View {
        ZStack {
            backgroundForCurrentStep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch viewModel.currentStep {
                    case .userName: userNameStep
                    case .age: ageStep
                    case .pronouns: pronounsStep
                    case .socialProof: socialProofStep
                    case .uniqueRep: uniqueRepStep
                    case .presentYourself: presentYourselfStep
                    case .moreAboutYou: moreAboutYouStep
                    case .workQuestion: workQuestionStep
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
        case .userName, .age, .pronouns:
            OnboardingColors.lightBg

        case .socialProof, .uniqueRep, .presentYourself, .moreAboutYou, .workQuestion, .nameCompanion, .loading, .paywall:
            AnimatedMeshBackground()

        case .personalizeAvatar, .meetCompanion:
            Color(red: 0.85, green: 0.78, blue: 0.70)
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Step 1: User Name (Light)

    private var userNameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            lightNavBar(showBack: false)

            Text("Quel est votre nom ?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(OnboardingColors.darkNavy)
                .padding(.top, 24)
                .padding(.horizontal, 24)

            Text("Cela aidera Focus à en apprendre plus sur vous.")
                .font(.system(size: 16))
                .foregroundColor(OnboardingColors.darkNavy.opacity(0.6))
                .padding(.top, 8)
                .padding(.horizontal, 24)

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
            .padding(.top, 32)
            .padding(.horizontal, 24)

            Spacer()

            blueContinueButton(enabled: !viewModel.firstName.isEmpty, isLoading: viewModel.isLoading) {
                Task {
                    await viewModel.saveAndNext(step: 0, data: [
                        "first_name": viewModel.firstName,
                        "last_name": viewModel.lastName
                    ])
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFirstNameFocused = true
            }
        }
    }

    // MARK: - Step 2: Age (Light)

    private var ageStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            lightNavBar()

            Text("Quel âge avez-vous ?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(OnboardingColors.darkNavy)
                .padding(.top, 24)
                .padding(.horizontal, 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(viewModel.ageOptions, id: \.value) { option in
                        ageOptionButton(option)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private func ageOptionButton(_ option: (label: String, value: String)) -> some View {
        Button(action: {
            guard !viewModel.isLoading else { return }
            HapticFeedback.selection()
            viewModel.selectedAge = option.value
            Task {
                await viewModel.saveAndNext(step: 1, data: ["age_range": option.value])
            }
        }) {
            HStack {
                Text(option.label)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(OnboardingColors.darkNavy)

                Spacer()

                if viewModel.isLoading && viewModel.selectedAge == option.value {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: OnboardingColors.darkNavy))
                        .scaleEffect(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal, 20)
            .background(Color.white)
            .cornerRadius(16)
        }
        .disabled(viewModel.isLoading)
    }

    // MARK: - Step 3: Pronouns (Light)

    private var pronounsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            lightNavBar()

            Text("Quels sont vos pronoms ?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(OnboardingColors.darkNavy)
                .padding(.top, 24)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                pronounButton(symbol: "♀", text: "Elle / La", value: "elle_la")
                pronounButton(symbol: "♂", text: "Il / Lui", value: "il_lui")
                pronounButton(symbol: "⚧", text: "Iel / Iels", value: "iel_iels")
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()
        }
    }

    private func pronounButton(symbol: String, text: String, value: String) -> some View {
        Button(action: {
            guard !viewModel.isLoading else { return }
            HapticFeedback.selection()
            viewModel.selectedPronouns = value
            Task {
                await viewModel.saveAndNext(step: 2, data: ["pronouns": value])
            }
        }) {
            HStack(spacing: 16) {
                Text(symbol)
                    .font(.system(size: 20))
                    .foregroundColor(OnboardingColors.darkNavy)

                Text(text)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(OnboardingColors.darkNavy)

                Spacer()

                if viewModel.isLoading && viewModel.selectedPronouns == value {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: OnboardingColors.darkNavy))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 60)
            .background(Color.white)
            .cornerRadius(16)
        }
        .disabled(viewModel.isLoading)
    }

    // MARK: - Step 4: Social Proof (Blue)

    private var socialProofStep: some View {
        VStack(spacing: 0) {
            blueNavBar()

            Spacer()

            Text("40 434 858")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 12)

            Text("des personnes ont déjà ressenti les avantages\nd'avoir un Focus dans leur vie")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

            Text("Présenté dans")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 24)

            VStack(spacing: 14) {
                Text("The New York Times")
                    .font(.custom("Times New Roman", size: 24).weight(.bold))
                    .italic()

                Text("THE WALL STREET JOURNAL.")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)

                HStack(spacing: 20) {
                    Text("CNN")
                        .font(.system(size: 18, weight: .heavy))
                    Text("Bloomberg")
                        .font(.system(size: 18, weight: .medium))
                    Text("Forbes")
                        .font(.system(size: 18, weight: .medium).italic())
                }

                HStack(spacing: 24) {
                    Text("WIRED")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(3)
                    Text("FORTUNE")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(2)
                }

                Text("The Washington Post")
                    .font(.custom("Times New Roman", size: 20).weight(.semibold))
                    .italic()
            }
            .foregroundColor(.white)

            Spacer()

            whiteContinueButton(isLoading: viewModel.isLoading) {
                Task {
                    await viewModel.saveAndNext(step: 3, data: [:])
                }
            }
            .padding(.bottom, 50)
        }
    }

    // MARK: - Step 5: Chaque Rep est unique (Blue with avatars)

    private var uniqueRepStep: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { viewModel.previousStep() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                Text("Chaque Focus\nest unique")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                Text("Chaque Focus est créé pour correspondre aux\nintérêts, passe-temps et ambitions de son\nhumain.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                HStack(spacing: -20) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 35))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }
                .padding(.bottom, 30)

                whiteContinueButton(text: "Créez votre Focus", isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.saveAndNext(step: 4, data: [:])
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Step 6: Présentez-vous (Blue)

    private var presentYourselfStep: some View {
        VStack(spacing: 0) {
            blueNavBar()

            Spacer()

            Image(systemName: "flame.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
                .padding(.bottom, 32)

            Text("Présentez-vous\nà Focus")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            Text("Connectez votre e-mail pour créer un aperçu de\nvotre vie, ou ajoutez des faits vous concernant\nmanuellement")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            whiteContinueButton(text: "Connectez votre email", isLoading: viewModel.isLoading) {
                Task {
                    await viewModel.saveAndNext(step: 5, data: [:])
                }
            }
            .padding(.bottom, 16)

            Button(action: {
                Task {
                    await viewModel.saveAndNext(step: 5, data: [:])
                }
            }) {
                Text("Ajouter des faits manuellement")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 24)

            Text("Focus ne partagera pas vos données avec qui que ce soit.\nAucun humain (à part vous) ne les verra jamais.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
        }
    }

    // MARK: - Step 7: Plus Focus en sait (Blue)

    private var moreAboutYouStep: some View {
        VStack(spacing: 0) {
            blueNavBar()

            Text("Plus Focus en sait —\nmieux c'est")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)
                .padding(.horizontal, 24)

            Text("Connectez d'autres services pour apporter plus\nde détails sur votre vie dans Focus.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, 24)

            Spacer().frame(height: 40)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        )

                    Text("Email et calendrier")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        Task {
                            await viewModel.connectGmail()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if viewModel.isConnectingGmail {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text(viewModel.connectedGmailAccounts.isEmpty ? "Connecter" : "Ajouter")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .disabled(viewModel.isConnectingGmail)
                }

                // Display connected Gmail accounts
                ForEach(viewModel.connectedGmailAccounts, id: \.self) { email in
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)

                        Text(email)
                            .font(.system(size: 15))
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: {
                            Task {
                                await viewModel.disconnectGmail(email: email)
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.leading, 44)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            HStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    )

                Text("Location")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Toggle("", isOn: $viewModel.locationEnabled)
                    .labelsHidden()
                    .tint(Color.blue)
                    .onChange(of: viewModel.locationEnabled) { enabled in
                        if enabled {
                            viewModel.requestLocationPermission()
                        }
                    }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal, 24)

            Spacer()

            whiteContinueButton(isLoading: viewModel.isLoading) {
                Task {
                    await viewModel.saveAndNext(step: 6, data: [:])
                }
            }
            .padding(.bottom, 24)

            Text("Focus ne partagera pas vos données avec qui que ce soit.\nAucun humain (à part vous) ne les verra jamais.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
        }
    }

    // MARK: - Step 8: Work Question (Blue)

    private var workQuestionStep: some View {
        VStack(spacing: 0) {
            blueNavBar(showSkip: true) {
                Task {
                    await viewModel.saveAndNext(step: 7, data: [:])
                }
            }

            Text("Pourriez-vous partager où vous\ntravaillez ?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)
                .padding(.horizontal, 24)

            Text("Cela aidera Focus à comprendre qui vous êtes.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.horizontal, 24)

            TextField("", text: $viewModel.workPlace, prompt: Text("Entreprise, école...").foregroundColor(.white.opacity(0.4)))
                .font(.system(size: 17))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .frame(height: 56)
                .background(Color.white.opacity(0.15))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .focused($isWorkFocused)

            Spacer()

            whiteContinueButton(isLoading: viewModel.isLoading) {
                Task {
                    // Save work info in life_improvements array
                    await viewModel.saveAndNext(step: 7, data: viewModel.workPlace.isEmpty ? [:] : ["life_improvements": [viewModel.workPlace]])
                }
            }
            .padding(.bottom, 24)

            Text("Focus ne partagera pas vos données avec qui que ce soit.\nAucun humain (à part vous) ne les verra jamais.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isWorkFocused = true
            }
        }
    }

    // MARK: - Step 9: Personalize Avatar

    private var personalizeAvatarStep: some View {
        ZStack {
            // Full-screen 3D Avatar as background
            Avatar3DView(
                avatarURL: AvatarURLs.cesiumMan,
                backgroundColor: UIColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1.0),
                enableRotation: true,
                autoRotate: false
            )
            .ignoresSafeArea()

            // UI overlay
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { viewModel.previousStep() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }

                    Spacer()

                    Text("Personnalisez votre Focus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()
                    Spacer().frame(width: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Bottom controls
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "butterfly.fill")
                            .font(.system(size: 14))
                        Text("Réaliste")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                    )

                    Circle()
                        .fill(Color.orange)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                }
                .padding(.bottom, 24)

                // Avatar style selection (4 mini circles as placeholders)
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(index == 0 ? Color.white : Color.clear, lineWidth: 3)
                            )
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                }
                .padding(.bottom, 24)

                whiteContinueButton(isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.saveAndNext(step: 8, data: [
                            "companion_gender": "male",  // Default to male avatar
                            "avatar_style": viewModel.selectedAvatarStyle
                        ])
                    }
                }
                .padding(.bottom, 16)

                Text("Vous pourrez toujours changer l'apparence de\nvotre Focus plus tard.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Step 10: Name Companion (Blue)

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

    // MARK: - Step 11: Loading with Checklist (Blue)

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

    // MARK: - Step 12: Paywall

    private var paywallStep: some View {
        FocusPaywallView(
            companionName: viewModel.displayName,
            onComplete: {
                // User subscribed - continue to meet companion
                viewModel.currentStep = .meetCompanion
            },
            onSkip: {
                // User closed paywall - still continue to meet companion
                viewModel.currentStep = .meetCompanion
            }
        )
        .environmentObject(revenueCatManager)
    }

    // MARK: - Step 13: Meet Companion (Avatar background)

    private var meetCompanionStep: some View {
        ZStack {
            // Full-screen 3D Avatar as background
            Avatar3DView(
                avatarURL: AvatarURLs.cesiumMan,
                backgroundColor: UIColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1.0),
                enableRotation: true,
                autoRotate: true
            )
            .ignoresSafeArea()

            // UI overlay
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
    @Published var currentStep: NewOnboardingStep = .userName
    @Published var isLoading = false

    // Step 1: User name
    @Published var firstName: String = ""
    @Published var lastName: String = ""

    // Step 2: Age
    @Published var selectedAge: String = ""
    let ageOptions: [(label: String, value: String)] = [
        ("Moins de 18", "less_than_18"),
        ("18-24", "18-24"),
        ("25-34", "25-34"),
        ("35-44", "35-44"),
        ("45-54", "45-54"),
        ("55-64", "55-64"),
        ("65 ans et plus", "65_plus")
    ]

    // Step 3: Pronouns
    @Published var selectedPronouns: String = ""

    // Step 7: Services
    @Published var locationEnabled: Bool = false
    @Published var connectedGmailAccounts: [String] = []
    @Published var isConnectingGmail: Bool = false

    // Step 8: Work
    @Published var workPlace: String = ""

    // Step 9: Avatar customization
    @Published var selectedAvatarStyle: String = "realistic"

    // Step 10: Companion name
    @Published var companionName: String = ""

    // Loading state
    @Published var loadingProgress: Int = 0

    var displayName: String {
        companionName.isEmpty ? "Kai" : companionName
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

            // Map data to request fields
            if let firstName = data["first_name"] as? String {
                request.firstName = firstName
            }
            if let lastName = data["last_name"] as? String {
                request.lastName = lastName
            }
            if let ageRange = data["age_range"] as? String {
                request.ageRange = ageRange
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
            if let lifeImprovements = data["life_improvements"] as? [String] {
                request.lifeImprovements = lifeImprovements
            }

            let _: OnboardingAPIResponse = try await APIClient.shared.request(
                endpoint: .onboardingProgress,
                method: .put,
                body: request
            )

            nextStep()
        } catch {
            print("Failed to save onboarding step \(step): \(error)")
            // Continue anyway to not block user
            nextStep()
        }
    }

    func saveAndStartLoading() async {
        isLoading = true

        do {
            var request = OnboardingSaveRequest(currentStep: 9)
            request.companionName = companionName.isEmpty ? "Kai" : companionName

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

    func startLoading() {
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

    // MARK: - Gmail Integration

    func connectGmail() async {
        isConnectingGmail = true
        defer { isConnectingGmail = false }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ No root view controller found")
            return
        }

        do {
            let (email, accessToken) = try await GmailService.shared.signIn(from: rootViewController)
            print("✅ Gmail connected: \(email)")

            // Add to connected accounts if not already there
            if !connectedGmailAccounts.contains(email) {
                connectedGmailAccounts.append(email)
            }

            // Save tokens to backend
            // Note: Google Sign-In doesn't always provide refresh token on subsequent sign-ins
            try await GmailService.shared.saveTokens(
                accessToken: accessToken,
                refreshToken: "", // Will be empty if user was already signed in
                expiresIn: 3600,
                email: email
            )

            // Trigger email analysis in background
            Task {
                do {
                    let result = try await GmailService.shared.analyzeEmails()
                    print("✅ Gmail analysis complete: \(result.messagesAnalyzed) messages")
                } catch {
                    print("⚠️ Gmail analysis failed: \(error)")
                }
            }

        } catch {
            print("❌ Gmail sign-in failed: \(error)")
        }
    }

    func disconnectGmail(email: String) async {
        do {
            try await GmailService.shared.disconnect()
            connectedGmailAccounts.removeAll { $0 == email }
            print("✅ Gmail disconnected: \(email)")
        } catch {
            print("❌ Gmail disconnect failed: \(error)")
        }
    }

    // MARK: - Location Permission

    func requestLocationPermission() {
        LocationService.shared.requestPermission()
        LocationService.shared.startUpdating()
    }
}

// MARK: - Preview

#Preview {
    NewOnboardingView()
        .environmentObject(FocusAppStore.shared)
        .environmentObject(RevenueCatManager.shared)
}
