import SwiftUI
import AuthenticationServices
import Combine
import StoreKit
import RevenueCat

// MARK: - Onboarding Step Enum
// Ordre: SignIn -> Questions -> TOUS les problemes -> TOUTES les solutions -> Recap -> Paywall -> Commitment -> Fin
enum OnboardingStep: Int, CaseIterable {
    case signIn = 0
    case projectStatus = 1
    case timeAvailable = 2
    case goals = 3
    // Tous les problemes d'abord
    case problem1 = 4
    case problem2 = 5
    case problem3 = 6
    // Puis toutes les solutions
    case solution1 = 7
    case solution2 = 8
    case solution3 = 9
    case solution4 = 10      // Community - nouvelle solution
    // Recap + Commitment + Paywall
    case featuresRecap = 11  // Resume de toutes les features
    case commitment = 12     // Engagement avant paywall
    case paywall = 13        // Page de paiement
    case streakCard = 14

    var isProblem: Bool {
        switch self {
        case .problem1, .problem2, .problem3:
            return true
        default:
            return false
        }
    }

    var isSolution: Bool {
        switch self {
        case .solution1, .solution2, .solution3, .solution4:
            return true
        default:
            return false
        }
    }

    var isQuestion: Bool {
        switch self {
        case .projectStatus, .timeAvailable, .goals:
            return true
        default:
            return false
        }
    }

    var isPaywall: Bool {
        self == .paywall
    }
}

// MARK: - Qualification Options
struct ProjectStatusOption: Identifiable {
    let id: String
    let label: String
    let icon: String
}

struct TimeAvailableOption: Identifiable {
    let id: String
    let label: String
    let icon: String
}

struct GoalOption: Identifiable {
    let id: String
    let label: String
    let icon: String
}

// MARK: - Review Model
struct OnboardingReview: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let rating: Int
    let text: String
    let avatarEmoji: String
}

// MARK: - ViewModel
@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .signIn
    @Published var isAnimating = false

    // Qualification data
    @Published var selectedProjectStatus: String?
    @Published var selectedTimeAvailable: String?
    @Published var selectedGoals: Set<String> = []

    // Commitment signature
    @Published var signatureLines: [SignatureLine] = []

    // State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isComplete = false

    // Options
    let projectStatusOptions: [ProjectStatusOption] = [
        ProjectStatusOption(id: "student", label: "Etudiant", icon: "📚"),
        ProjectStatusOption(id: "working", label: "En activite", icon: "💼"),
        ProjectStatusOption(id: "entrepreneur", label: "Entrepreneur", icon: "🚀"),
        ProjectStatusOption(id: "other", label: "Autre", icon: "✨")
    ]

    let timeAvailableOptions: [TimeAvailableOption] = [
        TimeAvailableOption(id: "less_than_1h", label: "< 1h", icon: "🌱"),
        TimeAvailableOption(id: "1_to_2h", label: "1-2h", icon: "🌿"),
        TimeAvailableOption(id: "2_to_4h", label: "2-4h", icon: "🌳"),
        TimeAvailableOption(id: "more_than_4h", label: "4h+", icon: "🔥")
    ]

    let goalOptions: [GoalOption] = [
        GoalOption(id: "focus", label: "Rester concentre", icon: "🎯"),
        GoalOption(id: "habits", label: "Creer des habitudes", icon: "✅"),
        GoalOption(id: "accountability", label: "Etre accountable", icon: "👥"),
        GoalOption(id: "track", label: "Suivre mes progres", icon: "📈"),
        GoalOption(id: "discipline", label: "Developper ma discipline", icon: "💪"),
        GoalOption(id: "goals", label: "Atteindre mes objectifs", icon: "🏆")
    ]

    let reviews: [OnboardingReview] = [
        OnboardingReview(
            name: "Lucas Martin",
            handle: "@lucas_builds",
            rating: 5,
            text: "Depuis que j'utilise VOLTA, j'ai enfin reussi a tenir mes habitudes. Le systeme de Crew me motive a rester consistant !",
            avatarEmoji: "👨‍💻"
        ),
        OnboardingReview(
            name: "Emma Dubois",
            handle: "@emma.focus",
            rating: 5,
            text: "Le FireMode a change ma facon de travailler. 2h de deep work par jour, et je vois enfin mes projets avancer.",
            avatarEmoji: "👩‍🎨"
        ),
        OnboardingReview(
            name: "Thomas Petit",
            handle: "@tom_discipline",
            rating: 5,
            text: "La pression sociale positive du Crew, c'est exactement ce qu'il me fallait. Mes potes voient quand je bosse !",
            avatarEmoji: "🧑‍💼"
        )
    ]

    // Services
    private let onboardingService = OnboardingService()
    private var store: FocusAppStore { FocusAppStore.shared }

    func selectProjectStatus(_ id: String) {
        selectedProjectStatus = id
        HapticFeedback.selection()
        // Auto-advance after selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.nextStep()
        }
    }

    func selectTimeAvailable(_ id: String) {
        selectedTimeAvailable = id
        HapticFeedback.selection()
        // Auto-advance after selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.nextStep()
        }
    }

    func toggleGoal(_ goalId: String) {
        if selectedGoals.contains(goalId) {
            selectedGoals.remove(goalId)
        } else if selectedGoals.count < 3 {
            selectedGoals.insert(goalId)
        }
        HapticFeedback.selection()
    }

    func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let nextIndex = OnboardingStep(rawValue: self.currentStep.rawValue + 1) {
                    // Skip paywall step temporarily (payment disabled)
                    if nextIndex == .paywall {
                        // Skip to streakCard instead of commitment
                        self.currentStep = .streakCard
                    } else {
                        self.currentStep = nextIndex
                    }
                }
                self.isAnimating = false
            }

            // Save progress to backend after step transition
            Task {
                await self.saveProgress()
            }
        }
    }

    func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let prevIndex = OnboardingStep(rawValue: self.currentStep.rawValue - 1) {
                    // Skip paywall step temporarily (payment disabled)
                    if prevIndex == .paywall {
                        self.currentStep = .featuresRecap
                    } else {
                        self.currentStep = prevIndex
                    }
                }
                self.isAnimating = false
            }
        }
    }

    func requestAppReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }

    func saveProgress() async {
        print("📝 saveProgress called - step: \(currentStep.rawValue + 1), projectStatus: \(selectedProjectStatus ?? "nil"), timeAvailable: \(selectedTimeAvailable ?? "nil"), goals: \(Array(selectedGoals))")
        do {
            let response = try await onboardingService.saveProgress(
                projectStatus: selectedProjectStatus,
                timeAvailable: selectedTimeAvailable,
                goals: Array(selectedGoals),
                currentStep: currentStep.rawValue + 1,
                isComplete: false
            )
            print("✅ saveProgress success - isCompleted: \(response.isCompleted), step: \(response.currentStep)")
        } catch {
            print("❌ Error saving onboarding progress: \(error)")
        }
    }

    func markComplete() {
        isComplete = true
    }
}

// MARK: - Signature Line Model
struct SignatureLine: Identifiable {
    let id = UUID()
    var points: [CGPoint]
}

// MARK: - Main View
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var authService = AuthService.shared

    var body: some View {
        ZStack {
            // Background based on step
            backgroundView
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Step content
                stepContent
                    .opacity(viewModel.isAnimating ? 0 : 1)
            }

            // Loading overlay
            if authService.isAuthenticating || viewModel.isLoading {
                loadingOverlay
            }
        }
        .onAppear {
            // If already signed in, skip sign-in step immediately
            if authService.isSignedIn && viewModel.currentStep == .signIn {
                viewModel.currentStep = .projectStatus
                print("📋 Onboarding: User already signed in, skipping to projectStatus")
            }
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn && viewModel.currentStep == .signIn {
                viewModel.currentStep = .projectStatus
                print("📋 Onboarding: User just signed in, moving to projectStatus")
            }
        }
    }

    // MARK: - Background
    @ViewBuilder
    private var backgroundView: some View {
        if viewModel.currentStep.isProblem {
            // Red gradient for problems
            LinearGradient(
                colors: [Color(hex: "#8B0000"), Color(hex: "#DC143C"), Color(hex: "#8B0000")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if viewModel.currentStep.isSolution {
            // Blue gradient for solutions
            LinearGradient(
                colors: [Color(hex: "#0A1628"), Color(hex: "#1E3A5F"), Color(hex: "#0A1628")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if viewModel.currentStep == .featuresRecap || viewModel.currentStep.isPaywall {
            // Premium gradient for paywall
            LinearGradient(
                colors: [Color(hex: "#1A1A2E"), Color(hex: "#16213E"), Color(hex: "#0F3460")],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            ColorTokens.background
        }
    }

    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .signIn:
            SignInStepView(viewModel: viewModel, authService: authService)
        case .projectStatus:
            ProjectStatusStepView(viewModel: viewModel)
        case .timeAvailable:
            TimeAvailableStepView(viewModel: viewModel)
        case .goals:
            GoalsStepView(viewModel: viewModel)
        case .problem1:
            ProblemStepView(
                emoji: "😔",
                title: "Tu manques de discipline",
                subtitle: "Tu commences plein de projets mais tu abandonnes apres quelques jours. La motivation disparait et tes objectifs restent des reves.",
                onContinue: { viewModel.nextStep() }
            )
        case .problem2:
            ProblemStepView(
                emoji: "😞",
                title: "Tu te sens seul dans ton parcours",
                subtitle: "Personne autour de toi ne comprend tes ambitions. Tu n'as personne pour te motiver quand tu procrastines.",
                onContinue: { viewModel.nextStep() }
            )
        case .problem3:
            ProblemStepView(
                emoji: "😩",
                title: "Tu ne vois pas tes progres",
                subtitle: "Sans suivi clair, tu as l'impression de stagner. Tes efforts semblent vains et tu finis par abandonner.",
                onContinue: { viewModel.nextStep() }
            )
        case .solution1:
            SolutionStepView(
                emoji: "🔥",
                title: "FireMode: Deep Work garanti",
                subtitle: "Lance des sessions de focus chronometrees. Bloque les distractions, concentre-toi, et accumule des heures de travail reel.",
                feature: "Sessions Pomodoro evoluees",
                onContinue: { viewModel.nextStep() }
            )
        case .solution2:
            SolutionStepView(
                emoji: "🎮",
                title: "Gamifie ta productivite",
                subtitle: "Gagne de l'XP, monte en niveau, debloque des achievements. Transforme tes objectifs en quetes epiques a accomplir.",
                feature: "Systeme de progression RPG",
                onContinue: { viewModel.nextStep() }
            )
        case .solution3:
            SolutionStepView(
                emoji: "📊",
                title: "Visualise chaque progres",
                subtitle: "Dashboard complet avec streaks, statistiques et graphiques. Vois exactement combien tu as accompli et celebre tes victoires.",
                feature: "Analytics personnels",
                onContinue: { viewModel.nextStep() }
            )
        case .solution4:
            SolutionStepView(
                emoji: "👥",
                title: "Crew: Ta communaute",
                subtitle: "Rejoins une squad de personnes motivees. Ils voient tes sessions, tes habitudes, et te poussent a rester consistant. Ensemble.",
                feature: "Accountability sociale",
                onContinue: { viewModel.nextStep() }
            )
        case .featuresRecap:
            FeaturesRecapStepView(viewModel: viewModel)
        case .paywall:
            PaywallStepView(viewModel: viewModel)
        case .commitment:
            CommitmentStepView(viewModel: viewModel)
        case .streakCard:
            StreakCardStepView(viewModel: viewModel)
        }
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                    .scaleEffect(1.5)

                Text("Connexion...")
                    .bodyText()
                    .foregroundColor(ColorTokens.textPrimary)
            }
            .padding(SpacingTokens.xl)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
    }
}

// MARK: - Sign In Step
struct SignInStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var authService: AuthService
    @State private var isAnimating = false
    @State private var showError = false

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: 0) {
                Spacer()

                // Logo and branding
                VStack(spacing: isSmallScreen ? SpacingTokens.md : SpacingTokens.lg) {
                    // Animated flame
                    ZStack {
                        Circle()
                            .fill(ColorTokens.primaryGlow)
                            .frame(width: isSmallScreen ? 100 : 140, height: isSmallScreen ? 100 : 140)
                            .blur(radius: isSmallScreen ? 20 : 30)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: isAnimating
                            )

                        Text("🔥")
                            .font(.system(size: isSmallScreen ? 60 : 80))
                            .scaleEffect(isAnimating ? 1.05 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }
                    .onAppear { isAnimating = true }

                    VStack(spacing: SpacingTokens.xs) {
                        Text("VOLTA")
                            .font(.system(size: isSmallScreen ? 30 : 36, weight: .bold))
                            .foregroundColor(ColorTokens.textPrimary)
                            .tracking(2)

                        Text("Focus. Build. Progress.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }

                Spacer()
                    .frame(height: isSmallScreen ? SpacingTokens.xl : SpacingTokens.xxl)

                // Features
                VStack(spacing: SpacingTokens.md) {
                    featureRow(icon: "🔥", text: "Sessions de deep work")
                    featureRow(icon: "👥", text: "Accountability avec ton Crew")
                    featureRow(icon: "✅", text: "Habitudes quotidiennes")
                    featureRow(icon: "🎯", text: "Objectifs par domaine de vie")
                }
                .padding(.horizontal, SpacingTokens.xl)

                Spacer()

                // Sign in button
                VStack(spacing: SpacingTokens.md) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 56)
                    .cornerRadius(RadiusTokens.md)
                }
                .padding(.horizontal, SpacingTokens.xl)

                // Terms
                VStack(spacing: SpacingTokens.xs) {
                    Text("En continuant, tu acceptes nos")
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)

                    HStack(spacing: SpacingTokens.xs) {
                        Text("CGU")
                            .caption()
                            .foregroundColor(ColorTokens.primaryStart)

                        Text("et")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)

                        Text("Politique de confidentialite")
                            .caption()
                            .foregroundColor(ColorTokens.primaryStart)
                    }
                }
                .padding(.top, SpacingTokens.lg)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.md : SpacingTokens.xl)
            }
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.error?.localizedDescription ?? "Une erreur est survenue")
        }
        .onChange(of: authService.error) { _, error in
            if error != nil && error != .userCancelled {
                showError = true
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Text(icon)
                .font(.satoshi(24))

            Text(text)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)

            Spacer()
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            Task {
                do {
                    try await authService.handleAppleCredential(appleIDCredential)
                } catch let error as AuthError {
                    if error != .userCancelled {
                        print("Auth error: \(error.localizedDescription)")
                    }
                } catch {
                    print("Auth error: \(error.localizedDescription)")
                }
            }

        case .failure(let error):
            print("Apple Sign In error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Project Status Step (Auto-advance on selection)
struct ProjectStatusStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: isSmallScreen ? SpacingTokens.lg : SpacingTokens.xl) {
                Spacer()
                    .frame(height: isSmallScreen ? SpacingTokens.xl : SpacingTokens.xxl)

                Text("👋")
                    .font(.system(size: isSmallScreen ? 50 : 60))

                VStack(spacing: SpacingTokens.sm) {
                    Text("Tu es...")
                        .font(.satoshi(isSmallScreen ? 24 : 28, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("On adapte l'experience pour toi")
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()
                    .frame(height: SpacingTokens.lg)

                // Options - tap to select and auto-advance
                VStack(spacing: SpacingTokens.md) {
                    ForEach(viewModel.projectStatusOptions) { option in
                        QuickSelectCard(
                            icon: option.icon,
                            label: option.label,
                            isSelected: viewModel.selectedProjectStatus == option.id
                        ) {
                            viewModel.selectProjectStatus(option.id)
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.xl)

                Spacer()
            }
        }
    }
}

// MARK: - Time Available Step (Auto-advance on selection)
struct TimeAvailableStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: isSmallScreen ? SpacingTokens.lg : SpacingTokens.xl) {
                Spacer()
                    .frame(height: isSmallScreen ? SpacingTokens.xl : SpacingTokens.xxl)

                Text("⏰")
                    .font(.system(size: isSmallScreen ? 50 : 60))

                VStack(spacing: SpacingTokens.sm) {
                    Text("Combien de temps par jour ?")
                        .font(.satoshi(isSmallScreen ? 24 : 28, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Pour tes projets personnels")
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()
                    .frame(height: SpacingTokens.lg)

                // 2x2 Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SpacingTokens.md) {
                    ForEach(viewModel.timeAvailableOptions) { option in
                        QuickSelectGridCard(
                            icon: option.icon,
                            label: option.label,
                            isSelected: viewModel.selectedTimeAvailable == option.id
                        ) {
                            viewModel.selectTimeAvailable(option.id)
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.xl)

                Spacer()
            }
        }
    }
}

// MARK: - Goals Step (Multi-select with continue button)
struct GoalsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: isSmallScreen ? SpacingTokens.lg : SpacingTokens.xl) {
                Spacer()
                    .frame(height: isSmallScreen ? SpacingTokens.lg : SpacingTokens.xl)

                Text("🎯")
                    .font(.system(size: isSmallScreen ? 50 : 60))

                VStack(spacing: SpacingTokens.sm) {
                    Text("Tes objectifs ?")
                        .font(.satoshi(isSmallScreen ? 24 : 28, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Choisis jusqu'a 3 priorites")
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()
                    .frame(height: SpacingTokens.md)

                // Goals grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SpacingTokens.sm) {
                    ForEach(viewModel.goalOptions) { option in
                        GoalSelectCard(
                            icon: option.icon,
                            label: option.label,
                            isSelected: viewModel.selectedGoals.contains(option.id)
                        ) {
                            viewModel.toggleGoal(option.id)
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.lg)

                Spacer()

                // Continue button
                Button(action: {
                    viewModel.nextStep()
                    HapticFeedback.medium()
                }) {
                    Text("Continuer")
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.md + 2)
                        .background(
                            viewModel.selectedGoals.isEmpty
                                ? LinearGradient(colors: [ColorTokens.textMuted], startPoint: .leading, endPoint: .trailing)
                                : ColorTokens.fireGradient
                        )
                        .cornerRadius(RadiusTokens.lg)
                }
                .disabled(viewModel.selectedGoals.isEmpty)
                .padding(.horizontal, SpacingTokens.xl)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.md : SpacingTokens.xl)
            }
        }
    }
}

// MARK: - Problem Step (Red background)
struct ProblemStepView: View {
    let emoji: String
    let title: String
    let subtitle: String
    let onContinue: () -> Void

    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: isSmallScreen ? SpacingTokens.xl : SpacingTokens.xxl) {
                Spacer()

                // Emoji with pulse
                Text(emoji)
                    .font(.system(size: isSmallScreen ? 70 : 90))
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .onAppear { isAnimating = true }

                VStack(spacing: SpacingTokens.lg) {
                    Text(title)
                        .font(.satoshi(isSmallScreen ? 26 : 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, SpacingTokens.xl)

                    Text(subtitle)
                        .bodyText()
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.xxl)
                        .minimumScaleFactor(0.9)
                }

                Spacer()

                // CTA
                Button(action: {
                    onContinue()
                    HapticFeedback.medium()
                }) {
                    Text("Je me reconnais")
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#8B0000"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.md + 2)
                        .background(Color.white)
                        .cornerRadius(RadiusTokens.lg)
                }
                .padding(.horizontal, SpacingTokens.xxl)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.md : SpacingTokens.xl)
            }
            .padding(.horizontal, SpacingTokens.md)
        }
    }
}

// MARK: - Solution Step (Blue background)
struct SolutionStepView: View {
    let emoji: String
    let title: String
    let subtitle: String
    let feature: String
    let onContinue: () -> Void

    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: isSmallScreen ? SpacingTokens.xl : SpacingTokens.xxl) {
                Spacer()

                // Emoji with glow
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: isSmallScreen ? 100 : 130, height: isSmallScreen ? 100 : 130)
                        .blur(radius: 20)

                    Text(emoji)
                        .font(.system(size: isSmallScreen ? 70 : 90))
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                .onAppear { isAnimating = true }

                VStack(spacing: SpacingTokens.lg) {
                    Text(title)
                        .font(.satoshi(isSmallScreen ? 26 : 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)

                    Text(subtitle)
                        .bodyText()
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.lg)
                        .minimumScaleFactor(0.9)

                    // Feature badge
                    Text(feature)
                        .caption()
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, SpacingTokens.md)
                        .padding(.vertical, SpacingTokens.sm)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(RadiusTokens.full)
                }

                Spacer()

                // CTA
                Button(action: {
                    onContinue()
                    HapticFeedback.medium()
                }) {
                    HStack {
                        Text("Decouvrir")
                        Image(systemName: "arrow.right")
                    }
                    .bodyText()
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#1E3A5F"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.md + 2)
                    .background(Color.white)
                    .cornerRadius(RadiusTokens.lg)
                }
                .padding(.horizontal, SpacingTokens.xl)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.md : SpacingTokens.xl)
            }
        }
    }
}

// MARK: - Reviews Step
struct ReviewsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: isSmallScreen ? SpacingTokens.lg : SpacingTokens.xl) {
                Spacer()
                    .frame(height: isSmallScreen ? SpacingTokens.md : SpacingTokens.lg)

                // Header
                VStack(spacing: SpacingTokens.sm) {
                    Text("Give us a rating")
                        .font(.satoshi(isSmallScreen ? 24 : 28, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    // Stars
                    HStack(spacing: SpacingTokens.xs) {
                        ForEach(0..<5) { _ in
                            Text("⭐")
                                .font(.system(size: isSmallScreen ? 24 : 28))
                        }
                    }

                    Text("This app was designed for people like you.")
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)
                }

                // Reviews
                ScrollView(showsIndicators: false) {
                    VStack(spacing: SpacingTokens.md) {
                        ForEach(viewModel.reviews) { review in
                            ReviewCard(review: review, isSmallScreen: isSmallScreen)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.lg)
                }

                Spacer()

                // CTA
                Button(action: {
                    viewModel.nextStep()
                    HapticFeedback.medium()
                }) {
                    Text("Next")
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.md + 2)
                        .background(ColorTokens.fireGradient)
                        .cornerRadius(RadiusTokens.lg)
                }
                .padding(.horizontal, SpacingTokens.xl)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.md : SpacingTokens.xl)
            }
        }
        .onAppear {
            // Request App Store review immediately when page appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.requestAppReview()
            }
        }
    }
}

struct ReviewCard: View {
    let review: OnboardingReview
    let isSmallScreen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                // Avatar
                Text(review.avatarEmoji)
                    .font(.system(size: isSmallScreen ? 28 : 32))
                    .frame(width: isSmallScreen ? 40 : 48, height: isSmallScreen ? 40 : 48)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.name)
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)

                    Text(review.handle)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()

                // Stars
                HStack(spacing: 2) {
                    ForEach(0..<review.rating, id: \.self) { _ in
                        Text("⭐")
                            .font(.satoshi(12))
                    }
                }
            }

            Text("\"\(review.text)\"")
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)
                .italic()
                .lineLimit(isSmallScreen ? 3 : nil)
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }
}

// MARK: - Features Recap Step
struct FeaturesRecapStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showReferralField = false
    @State private var referralCode = ""
    @State private var isValidatingCode = false
    @State private var codeValidationResult: CodeValidationResult?
    @State private var hasCodeFromDeepLink = false
    @FocusState private var isCodeFieldFocused: Bool

    enum CodeValidationResult {
        case valid
        case invalid
        case alreadyUsed
    }

    private let features: [(emoji: String, title: String, desc: String)] = [
        ("🔥", "FireMode", "Sessions de deep work chronometrees"),
        ("🎮", "Gamification", "XP, niveaux et achievements"),
        ("📊", "Analytics", "Statistiques et streaks detailles"),
        ("👥", "Crew", "Communaute d'accountability"),
        ("📅", "Planning", "Calendrier et routines quotidiennes"),
        ("🎯", "Quests", "Objectifs par domaine de vie")
    ]

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: isSmallScreen ? SpacingTokens.md : SpacingTokens.lg)

                // Header
                VStack(spacing: SpacingTokens.sm) {
                    Text("🚀")
                        .font(.system(size: isSmallScreen ? 44 : 54))

                    Text("Tout ce dont tu as besoin")
                        .font(.satoshi(isSmallScreen ? 22 : 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Pour enfin atteindre tes objectifs")
                        .font(.satoshi(isSmallScreen ? 14 : 16))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()
                    .frame(height: isSmallScreen ? SpacingTokens.md : SpacingTokens.lg)

                // Features grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SpacingTokens.sm) {
                    ForEach(features, id: \.title) { feature in
                        VStack(spacing: SpacingTokens.xs) {
                            Text(feature.emoji)
                                .font(.system(size: isSmallScreen ? 26 : 30))

                            Text(feature.title)
                                .font(.satoshi(isSmallScreen ? 12 : 14, weight: .bold))
                                .foregroundColor(.white)

                            Text(feature.desc)
                                .font(.satoshi(isSmallScreen ? 9 : 10))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isSmallScreen ? SpacingTokens.sm : SpacingTokens.md)
                        .padding(.horizontal, SpacingTokens.xs)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(RadiusTokens.md)
                    }
                }
                .padding(.horizontal, SpacingTokens.lg)

                Spacer()

                // Referral Code Section (only if NOT from deep link)
                if !hasCodeFromDeepLink {
                    referralCodeSection
                        .padding(.horizontal, SpacingTokens.xl)
                        .padding(.bottom, SpacingTokens.md)
                }

                // CTA
                Button(action: {
                    // Store the referral code if valid (manual entry)
                    if !referralCode.isEmpty && codeValidationResult == .valid {
                        ReferralService.shared.storePendingCode(referralCode.uppercased())
                    }
                    viewModel.nextStep()
                    HapticFeedback.medium()
                }) {
                    HStack {
                        Text("Debloquer l'acces")
                        Image(systemName: "arrow.right")
                    }
                    .bodyText()
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.md + 2)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(RadiusTokens.lg)
                }
                .padding(.horizontal, SpacingTokens.xl)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.md : SpacingTokens.xl)
            }
        }
        .onAppear {
            // Check if there's a pending code from deep link
            if let pendingCode = ReferralService.shared.pendingReferralCode, !pendingCode.isEmpty {
                hasCodeFromDeepLink = true
                referralCode = pendingCode
                // Code is already stored, no need to show input
            }
        }
    }

    // MARK: - Referral Code Section (only for manual entry)
    @ViewBuilder
    private var referralCodeSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            if showReferralField {
                // Code input field
                HStack(spacing: SpacingTokens.sm) {
                    HStack {
                        Image(systemName: "ticket.fill")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 14))

                        TextField("", text: $referralCode, prompt: Text("CODE-PARRAIN").foregroundColor(.white.opacity(0.3)))
                            .font(.satoshi(16, weight: .semibold))
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isCodeFieldFocused)
                            .onChange(of: referralCode) { _, newValue in
                                // Reset validation when code changes
                                if codeValidationResult != nil {
                                    codeValidationResult = nil
                                }
                            }
                            .onSubmit {
                                validateCode()
                            }

                        // Validation indicator
                        if isValidatingCode {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else if let result = codeValidationResult {
                            Image(systemName: result == .valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result == .valid ? .green : .red)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.sm + 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(RadiusTokens.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .stroke(
                                codeValidationResult == .valid ? Color.green.opacity(0.5) :
                                codeValidationResult == .invalid ? Color.red.opacity(0.5) :
                                Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )

                    // Validate button
                    Button(action: validateCode) {
                        Text("OK")
                            .font(.satoshi(14, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.sm + 2)
                            .background(Color.white)
                            .cornerRadius(RadiusTokens.md)
                    }
                    .disabled(referralCode.isEmpty || isValidatingCode)
                    .opacity(referralCode.isEmpty ? 0.5 : 1)
                }

                // Validation message
                if let result = codeValidationResult {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: result == .valid ? "checkmark.circle" : "info.circle")
                            .font(.system(size: 12))
                        Text(validationMessage(for: result))
                            .font(.satoshi(12))
                    }
                    .foregroundColor(result == .valid ? .green : .red.opacity(0.8))
                }
            } else {
                // Toggle button to show referral field
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showReferralField = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isCodeFieldFocused = true
                    }
                }) {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 14))
                        Text("J'ai un code parrain")
                            .font(.satoshi(14, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#FFD700"))
                    .padding(.vertical, SpacingTokens.sm)
                }
            }
        }
    }

    private func validateCode() {
        guard !referralCode.isEmpty else { return }

        isValidatingCode = true
        isCodeFieldFocused = false

        Task {
            let isValid = await ReferralService.shared.validateCode(referralCode.uppercased())

            await MainActor.run {
                isValidatingCode = false
                codeValidationResult = isValid ? .valid : .invalid

                if isValid {
                    HapticFeedback.success()
                } else {
                    HapticFeedback.error()
                }
            }
        }
    }

    private func validationMessage(for result: CodeValidationResult) -> String {
        switch result {
        case .valid:
            return "Code valide ! Tu seras lie a ton parrain."
        case .invalid:
            return "Code invalide. Verifie l'orthographe."
        case .alreadyUsed:
            return "Tu as deja un parrain."
        }
    }
}

// MARK: - Paywall Step (Using RevenueCat)
struct PaywallStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var store: FocusAppStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var selectedPackage: Package?
    @State private var fallbackSelectedPlan: String = "yearly"
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "#0A0A1A"), Color(hex: "#1A1A2E"), Color(hex: "#0F0F23")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: isSmallScreen ? SpacingTokens.lg : SpacingTokens.xxl)

                        // MARK: - Header Section
                        headerSection(isSmallScreen: isSmallScreen)

                        // MARK: - Social Proof
                        socialProofSection
                            .padding(.top, SpacingTokens.lg)
                            .padding(.bottom, SpacingTokens.xl)

                        // MARK: - Benefits Grid
                        benefitsGridSection
                            .padding(.bottom, SpacingTokens.xl)

                        // MARK: - Plans
                        if revenueCatManager.isLoading && revenueCatManager.offerings == nil {
                            loadingSection
                        } else if revenueCatManager.currentOffering != nil {
                            packagesSection
                        } else {
                            fallbackPlansSection
                        }

                        // MARK: - Referral Thank You (if from referral)
                        if let referralCode = ReferralService.shared.pendingReferralCode, !referralCode.isEmpty {
                            referralThankYouSection(code: referralCode)
                                .padding(.top, SpacingTokens.md)
                        }

                        Spacer().frame(height: SpacingTokens.lg)

                        // MARK: - CTA
                        ctaSection(geometry: geometry)
                    }
                }

                if isProcessing {
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
            if revenueCatManager.offerings == nil {
                await revenueCatManager.fetchOfferings()
            }
            if selectedPackage == nil {
                selectedPackage = revenueCatManager.yearlyPackage ?? revenueCatManager.monthlyPackage
            }
        }
    }

    // MARK: - Header
    private func headerSection(isSmallScreen: Bool) -> some View {
        VStack(spacing: SpacingTokens.md) {
            // Animated glow effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#FFD700").opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)

                Text("🚀")
                    .font(.system(size: isSmallScreen ? 56 : 64))
            }

            Text("Rejoins la communaute")
                .font(.satoshi(isSmallScreen ? 24 : 28, weight: .bold))
                .foregroundColor(.white)

            Text("des personnes qui passent a l'action")
                .font(.satoshi(isSmallScreen ? 16 : 18, weight: .medium))
                .foregroundColor(Color(hex: "#FFD700"))
        }
    }

    // MARK: - Social Proof
    private var socialProofSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            // Avatar stack
            HStack(spacing: -12) {
                ForEach(0..<5, id: \.self) { index in
                    let avatarColors: [[Color]] = [
                        [Color(hex: "#FF6B6B"), Color(hex: "#FF8E8E")],
                        [Color(hex: "#4ECDC4"), Color(hex: "#7EE8E1")],
                        [Color(hex: "#FFD700"), Color(hex: "#FFE44D")],
                        [Color(hex: "#A855F7"), Color(hex: "#C084FC")],
                        [Color(hex: "#3B82F6"), Color(hex: "#60A5FA")]
                    ]
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: avatarColors[index % 5],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(["🔥", "💪", "⚡", "🎯", "✨"][index])
                                .font(.system(size: 16))
                        )
                        .overlay(Circle().stroke(Color(hex: "#0A0A1A"), lineWidth: 2))
                }

                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("+2K")
                            .font(.satoshi(10, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .overlay(Circle().stroke(Color(hex: "#0A0A1A"), lineWidth: 2))
            }

            Text("2,847 membres actifs")
                .font(.satoshi(14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            // Rating stars
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
                Text("4.9")
                    .font(.satoshi(12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, SpacingTokens.md)
        .padding(.horizontal, SpacingTokens.xl)
        .background(Color.white.opacity(0.05))
        .cornerRadius(RadiusTokens.lg)
        .padding(.horizontal, SpacingTokens.xl)
    }

    // MARK: - Benefits Grid
    private var benefitsGridSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.sm) {
                benefitCard(icon: "flame.fill", title: "Focus illimite", color: Color(hex: "#FF6B6B"))
                benefitCard(icon: "person.3.fill", title: "Communaute", color: Color(hex: "#4ECDC4"))
            }
            HStack(spacing: SpacingTokens.sm) {
                benefitCard(icon: "trophy.fill", title: "Gamification", color: Color(hex: "#FFD700"))
                benefitCard(icon: "chart.line.uptrend.xyaxis", title: "Analytics", color: Color(hex: "#A855F7"))
            }
        }
        .padding(.horizontal, SpacingTokens.xl)
    }

    private func benefitCard(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)

            Text(title)
                .font(.satoshi(14, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)
        }
        .padding(SpacingTokens.md)
        .background(Color.white.opacity(0.05))
        .cornerRadius(RadiusTokens.md)
    }

    // MARK: - Referral Thank You
    private func referralThankYouSection(code: String) -> some View {
        HStack(spacing: SpacingTokens.md) {
            // Gift icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#FFD700").opacity(0.2))
                    .frame(width: 44, height: 44)

                Text("🎁")
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Invite par un ami")
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(.white)

                Text("Merci a ton parrain pour la confiance !")
                    .font(.satoshi(12))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Code badge
            Text(code)
                .font(.satoshi(11, weight: .bold))
                .foregroundColor(Color(hex: "#FFD700"))
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, 4)
                .background(Color(hex: "#FFD700").opacity(0.15))
                .cornerRadius(RadiusTokens.sm)
        }
        .padding(SpacingTokens.md)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg)
                        .stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, SpacingTokens.xl)
    }

    // MARK: - Loading
    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            Text("Chargement...")
                .font(.satoshi(14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, SpacingTokens.xl)
    }

    // MARK: - RevenueCat Packages
    private var packagesSection: some View {
        VStack(spacing: SpacingTokens.md) {
            if let yearly = revenueCatManager.yearlyPackage {
                planCard(
                    package: yearly,
                    title: "Annuel",
                    subtitle: "Le plus populaire",
                    badge: "ECONOMISE 33%",
                    isRecommended: true
                )
            }

            if let monthly = revenueCatManager.monthlyPackage {
                planCard(
                    package: monthly,
                    title: "Mensuel",
                    subtitle: "Flexible",
                    badge: nil,
                    isRecommended: false
                )
            }
        }
        .padding(.horizontal, SpacingTokens.xl)
    }

    private func planCard(package: Package, title: String, subtitle: String, badge: String?, isRecommended: Bool) -> some View {
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
                        .font(.satoshi(11, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#FFD700"))
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.satoshi(18, weight: .bold))
                            .foregroundColor(.white)

                        Text(subtitle)
                            .font(.satoshi(13))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(package.storeProduct.localizedPriceString)
                            .font(.satoshi(24, weight: .bold))
                            .foregroundColor(.white)

                        Text(periodText(for: package))
                            .font(.satoshi(12))
                            .foregroundColor(.white.opacity(0.5))
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
            }
            .background(
                RoundedRectangle(cornerRadius: badge != nil ? 0 : RadiusTokens.lg)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.03))
            )
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .stroke(isSelected ? Color(hex: "#FFD700") : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func periodText(for package: Package) -> String {
        switch package.packageType {
        case .monthly: return "/mois"
        case .annual: return "/an"
        case .lifetime: return "a vie"
        case .weekly: return "/semaine"
        default: return ""
        }
    }

    // MARK: - Fallback Plans
    private var fallbackPlansSection: some View {
        VStack(spacing: SpacingTokens.md) {
            fallbackPlanCard(planId: "yearly", title: "Annuel", subtitle: "Le plus populaire", price: "79,99 €", period: "/an", badge: "ECONOMISE 33%")
            fallbackPlanCard(planId: "monthly", title: "Mensuel", subtitle: "Flexible", price: "9,99 €", period: "/mois", badge: nil)
        }
        .padding(.horizontal, SpacingTokens.xl)
    }

    private func fallbackPlanCard(planId: String, title: String, subtitle: String, price: String, period: String, badge: String?) -> some View {
        let isSelected = fallbackSelectedPlan == planId

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                fallbackSelectedPlan = planId
            }
            HapticFeedback.selection()
        }) {
            VStack(spacing: 0) {
                if let badge = badge {
                    Text(badge)
                        .font(.satoshi(11, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#FFD700"))
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.satoshi(18, weight: .bold))
                            .foregroundColor(.white)

                        Text(subtitle)
                            .font(.satoshi(13))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(price)
                            .font(.satoshi(24, weight: .bold))
                            .foregroundColor(.white)

                        Text(period)
                            .font(.satoshi(12))
                            .foregroundColor(.white.opacity(0.5))
                    }

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
            }
            .background(
                RoundedRectangle(cornerRadius: badge != nil ? 0 : RadiusTokens.lg)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.03))
            )
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .stroke(isSelected ? Color(hex: "#FFD700") : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - CTA
    private func ctaSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: SpacingTokens.md) {
            Button(action: handlePurchase) {
                HStack(spacing: SpacingTokens.sm) {
                    Text("Rejoindre la communaute")
                        .font(.satoshi(17, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(RadiusTokens.lg)
                .shadow(color: Color(hex: "#FFD700").opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .disabled(isProcessing)

            // Guarantee text
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                Text("Satisfait ou rembourse • Annule quand tu veux")
                    .font(.satoshi(12))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Restore & Terms
            HStack(spacing: SpacingTokens.lg) {
                Button("Restaurer") {
                    Task { await handleRestore() }
                }
                .font(.satoshi(12))
                .foregroundColor(.white.opacity(0.4))

                Text("•").foregroundColor(.white.opacity(0.2))

                Button("CGV") { }
                .font(.satoshi(12))
                .foregroundColor(.white.opacity(0.4))

                Text("•").foregroundColor(.white.opacity(0.2))

                Button("Confidentialite") { }
                .font(.satoshi(12))
                .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, SpacingTokens.xl)
        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.lg : SpacingTokens.xxl)
    }

    // MARK: - Loading Overlay
    private var purchaseLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFD700")))
                    .scaleEffect(1.5)

                Text("Traitement en cours...")
                    .font(.satoshi(16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(SpacingTokens.xxl)
            .background(Color(hex: "#1A1A2E"))
            .cornerRadius(RadiusTokens.xl)
        }
    }

    // MARK: - Actions
    private func handlePurchase() {
        guard let package = selectedPackage else {
            viewModel.nextStep()
            return
        }

        isProcessing = true
        HapticFeedback.medium()

        Task {
            let success = await revenueCatManager.purchase(package: package)
            isProcessing = false

            if success {
                HapticFeedback.success()
                viewModel.nextStep()
            } else if let error = revenueCatManager.errorMessage {
                errorMessage = error
                showError = true
            }
        }
    }

    private func handleRestore() async {
        isProcessing = true

        let success = await revenueCatManager.restorePurchases()
        isProcessing = false

        if success {
            HapticFeedback.success()
            viewModel.nextStep()
        } else if let error = revenueCatManager.errorMessage {
            errorMessage = error
            showError = true
        }
    }
}

// MARK: - SubscriptionPeriod Extension
extension RevenueCat.SubscriptionPeriod {
    var periodTitle: String {
        switch unit {
        case .day:
            return value == 1 ? "1 jour" : "\(value) jours"
        case .week:
            return value == 1 ? "1 semaine" : "\(value) semaines"
        case .month:
            return value == 1 ? "1 mois" : "\(value) mois"
        case .year:
            return value == 1 ? "1 an" : "\(value) ans"
        @unknown default:
            return "\(value)"
        }
    }
}

// MARK: - Commitment Step (Signature)
struct CommitmentStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            VStack(spacing: isSmallScreen ? SpacingTokens.lg : SpacingTokens.xl) {
                // Back button
                HStack {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.satoshi(20, weight: .semibold))
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.top, SpacingTokens.md)

                VStack(spacing: SpacingTokens.sm) {
                    Text("Sign your commitment")
                        .font(.satoshi(isSmallScreen ? 24 : 28, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Finally, promise yourself that you will stay consistent and build your discipline.")
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.lg)
                }

                Spacer()
                    .frame(height: SpacingTokens.md)

                // Signature canvas
                SignatureCanvas(lines: $viewModel.signatureLines)
                    .frame(height: isSmallScreen ? 150 : 200)
                    .background(Color.white)
                    .cornerRadius(RadiusTokens.md)
                    .padding(.horizontal, SpacingTokens.xl)

                // Clear button
                Button(action: {
                    viewModel.signatureLines = []
                }) {
                    Text("Clear")
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                Text("Draw on the open space above")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                // Finish button
                Button(action: {
                    viewModel.nextStep()
                    HapticFeedback.medium()
                }) {
                    Text("Finish")
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.md + 2)
                        .background(
                            viewModel.signatureLines.isEmpty
                                ? LinearGradient(colors: [ColorTokens.textMuted], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(RadiusTokens.lg)
                }
                .disabled(viewModel.signatureLines.isEmpty)
                .padding(.horizontal, SpacingTokens.xl)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.md : SpacingTokens.xl)
            }
        }
    }
}

// MARK: - Signature Canvas
struct SignatureCanvas: View {
    @Binding var lines: [SignatureLine]
    @State private var currentLine: SignatureLine = SignatureLine(points: [])

    var body: some View {
        Canvas { context, size in
            for line in lines {
                var path = Path()
                if let firstPoint = line.points.first {
                    path.move(to: firstPoint)
                    for point in line.points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                context.stroke(path, with: .color(.black), lineWidth: 2)
            }

            // Current line being drawn
            var currentPath = Path()
            if let firstPoint = currentLine.points.first {
                currentPath.move(to: firstPoint)
                for point in currentLine.points.dropFirst() {
                    currentPath.addLine(to: point)
                }
            }
            context.stroke(currentPath, with: .color(.black), lineWidth: 2)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    currentLine.points.append(value.location)
                }
                .onEnded { _ in
                    lines.append(currentLine)
                    currentLine = SignatureLine(points: [])
                }
        )
    }
}

// MARK: - Streak Card Step
struct StreakCardStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var store: FocusAppStore
    @State private var isAnimating = false
    @State private var showConfetti = false
    @State private var isCompleting = false

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700

            ZStack {
                VStack(spacing: 0) {
                    Spacer()

                    // Main content - centered
                    VStack(spacing: isSmallScreen ? SpacingTokens.xl : SpacingTokens.xxl) {
                        // Flame with glow
                        ZStack {
                            // Subtle glow
                            Circle()
                                .fill(ColorTokens.primaryStart.opacity(0.15))
                                .frame(width: isSmallScreen ? 140 : 180, height: isSmallScreen ? 140 : 180)
                                .blur(radius: 40)
                                .scaleEffect(isAnimating ? 1.2 : 1.0)
                                .animation(
                                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                    value: isAnimating
                                )

                            Text("🔥")
                                .font(.system(size: isSmallScreen ? 100 : 120))
                                .scaleEffect(isAnimating ? 1.05 : 1.0)
                                .animation(
                                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                        }
                        .onAppear {
                            isAnimating = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showConfetti = true
                            }
                        }

                        // Day text
                        VStack(spacing: SpacingTokens.sm) {
                            Text("Jour 1")
                                .font(.system(size: isSmallScreen ? 56 : 72, weight: .bold))
                                .foregroundColor(ColorTokens.textPrimary)

                            Text("Un nouveau jour pour progresser")
                                .bodyText()
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }

                    Spacer()

                    // CTA at bottom
                    VStack(spacing: SpacingTokens.md) {
                        Button(action: {
                            guard !isCompleting else { return }
                            isCompleting = true
                            HapticFeedback.success()
                            Task {
                                await store.completeOnboarding()
                            }
                        }) {
                            HStack(spacing: SpacingTokens.sm) {
                                if isCompleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Commencer l'aventure")
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .bodyText()
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SpacingTokens.md + 4)
                            .background(ColorTokens.fireGradient)
                            .cornerRadius(RadiusTokens.lg)
                        }
                        .disabled(isCompleting)
                    }
                    .padding(.horizontal, SpacingTokens.xl)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.lg : SpacingTokens.xxl)
                }
                // Watch for onboarding completion to ensure view transitions
                .onChange(of: store.hasCompletedOnboarding) { _, completed in
                    if completed {
                        print("✅ Onboarding completed, view should transition to MainTabView")
                    }
                }

                // Confetti effect
                if showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(.system(size: particle.size))
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles()
            }
        }
    }

    private func createParticles(in size: CGSize) {
        let emojis = ["🎉", "✨", "🔥", "⭐", "💪", "🎯"]
        for _ in 0..<30 {
            particles.append(ConfettiParticle(
                emoji: emojis.randomElement()!,
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: -50),
                size: CGFloat.random(in: 20...35),
                opacity: 1.0
            ))
        }
    }

    private func animateParticles() {
        withAnimation(.easeOut(duration: 3.0)) {
            for i in particles.indices {
                particles[i].position.y += CGFloat.random(in: 600...900)
                particles[i].position.x += CGFloat.random(in: -100...100)
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let emoji: String
    var position: CGPoint
    let size: CGFloat
    var opacity: Double
}

// MARK: - Quick Select Card (for auto-advance steps)
struct QuickSelectCard: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.md) {
                Text(icon)
                    .font(.satoshi(28))

                Text(label)
                    .bodyText()
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.satoshi(24))
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }
            .padding(SpacingTokens.lg)
            .background(isSelected ? ColorTokens.primarySoft : ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .stroke(isSelected ? ColorTokens.primaryStart : ColorTokens.border, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

struct QuickSelectGridCard: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sm) {
                Text(icon)
                    .font(.satoshi(36))

                Text(label)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.xl)
            .background(isSelected ? ColorTokens.primarySoft : ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .stroke(isSelected ? ColorTokens.primaryStart : ColorTokens.border, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

struct GoalSelectCard: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.xs) {
                Text(icon)
                    .font(.satoshi(28))

                Text(label)
                    .caption()
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.md)
            .padding(.horizontal, SpacingTokens.sm)
            .background(isSelected ? ColorTokens.primarySoft : ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(isSelected ? ColorTokens.primaryStart : ColorTokens.border, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
        .environmentObject(FocusAppStore.shared)
}
