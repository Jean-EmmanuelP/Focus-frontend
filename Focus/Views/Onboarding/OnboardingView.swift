import SwiftUI
import AuthenticationServices
import Combine
import StoreKit

// MARK: - Onboarding Step Enum
// Ordre: SignIn -> Questions -> TOUS les problemes -> TOUTES les solutions -> Reviews -> Fin
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
    case reviews = 10
    case commitment = 11
    case streakCard = 12

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
        case .solution1, .solution2, .solution3:
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
                    self.currentStep = nextIndex
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
                    self.currentStep = prevIndex
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
                subtitle: "Tu commences plein de choses mais tu finis rarement. La motivation s'effondre apres quelques jours et tes objectifs restent des reves.",
                onContinue: { viewModel.nextStep() }
            )
        case .solution1:
            SolutionStepView(
                emoji: "🔥",
                title: "FireMode: Deep Work garanti",
                subtitle: "Lance des sessions de focus chronometrees. Tu definis la duree, tu te concentres, et tu vois tes heures de travail s'accumuler jour apres jour.",
                feature: "Pomodoro evolue avec tracking",
                onContinue: { viewModel.nextStep() }
            )
        case .problem2:
            ProblemStepView(
                emoji: "😞",
                title: "Tu te sens seul",
                subtitle: "Personne autour de toi ne comprend tes objectifs. Tu n'as personne pour te pousser quand tu procrastines.",
                onContinue: { viewModel.nextStep() }
            )
        case .solution2:
            SolutionStepView(
                emoji: "👥",
                title: "Crew: Ta squad d'accountability",
                subtitle: "Rejoins un groupe de personnes motivees. Ils voient quand tu bosses, tes habitudes completees, et te challengent a rester consistant.",
                feature: "Pression sociale positive",
                onContinue: { viewModel.nextStep() }
            )
        case .problem3:
            ProblemStepView(
                emoji: "😩",
                title: "Tu ne vois pas tes progres",
                subtitle: "Sans suivi clair, tu as l'impression de stagner. Tes efforts semblent vains et tu abandonnes.",
                onContinue: { viewModel.nextStep() }
            )
        case .solution3:
            SolutionStepView(
                emoji: "📈",
                title: "Quests & Stats: Visualise ta progression",
                subtitle: "Definis tes objectifs par domaine de vie. Suis ta progression, tes streaks, et celebre chaque victoire.",
                feature: "Dashboard complet",
                onContinue: { viewModel.nextStep() }
            )
        case .reviews:
            ReviewsStepView(viewModel: viewModel)
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
