import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var authService = AuthService.shared
    @State private var isAnimating = false
    @State private var showError = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                ColorTokens.background
                    .ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    Spacer()

                    // Logo and branding
                    brandingSection(screenHeight: geometry.size.height)

                    Spacer()
                        .frame(height: geometry.size.height < 700 ? SpacingTokens.xl : SpacingTokens.xxl)

                    // Story/Value proposition
                    storySection

                    Spacer()

                    // Sign in button
                    signInSection

                    // Terms
                    termsSection
                }
                .padding(.horizontal, SpacingTokens.xl)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? SpacingTokens.md : SpacingTokens.xl)

                // Loading overlay
                if authService.isAuthenticating {
                    loadingOverlay
                }
            }
            .alert("auth.error_title".localized, isPresented: $showError) {
                Button("common.ok".localized, role: .cancel) {}
            } message: {
                Text(authService.error?.localizedDescription ?? "error.generic".localized)
            }
            .onChange(of: authService.error) { _, error in
                if error != nil && error != .userCancelled {
                    showError = true
                }
            }
            .onChange(of: authService.isSignedIn) { _, isSignedIn in
                if isSignedIn {
                    store.handleAuthServiceUpdate()
                }
            }
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

                Text("auth.signing_in".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textPrimary)
            }
            .padding(SpacingTokens.xl)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
    }

    // MARK: - Branding Section
    private func brandingSection(screenHeight: CGFloat) -> some View {
        let isSmallScreen = screenHeight < 700
        let glowSize: CGFloat = isSmallScreen ? 100 : 140
        let flameSize: CGFloat = isSmallScreen ? 60 : 80
        let titleSize: CGFloat = isSmallScreen ? 30 : 36

        return VStack(spacing: isSmallScreen ? SpacingTokens.md : SpacingTokens.lg) {
            // Animated flame icon
            ZStack {
                // Glow effect
                Circle()
                    .fill(ColorTokens.primaryGlow)
                    .frame(width: glowSize, height: glowSize)
                    .blur(radius: isSmallScreen ? 20 : 30)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                // Flame emoji
                Text("🔥")
                    .font(.system(size: flameSize))
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .onAppear {
                isAnimating = true
            }

            // App name
            VStack(spacing: SpacingTokens.xs) {
                Text("VOLTA")
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
                    .tracking(2)

                Text("auth.tagline".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
            }
        }
    }

    // MARK: - Story Section
    private var storySection: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Feature highlights
            VStack(spacing: SpacingTokens.md) {
                featureRow(icon: "⚡", text: "auth.feature.focus".localized)
                featureRow(icon: "🎯", text: "auth.feature.quests".localized)
                featureRow(icon: "📈", text: "auth.feature.habits".localized)
                featureRow(icon: "🌅", text: "auth.feature.rituals".localized)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Text(icon)
                .font(.system(size: 24))

            Text(text)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sign In Section
    private var signInSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // Custom Sign in with Apple button with localized text
            Button {
                triggerAppleSignIn()
            } label: {
                HStack(spacing: SpacingTokens.sm) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .medium))
                    Text("auth.sign_in_apple".localized)
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(RadiusTokens.md)
            }
        }
    }

    @State private var appleSignInCoordinator: AppleSignInCoordinator?

    private func triggerAppleSignIn() {
        let coordinator = AppleSignInCoordinator { result in
            handleAppleSignIn(result)
        }
        appleSignInCoordinator = coordinator
        coordinator.startSignIn()
    }

    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text("auth.terms.agree".localized)
                .font(.caption)
                .foregroundColor(ColorTokens.textMuted)

            HStack(spacing: SpacingTokens.xs) {
                Button {
                    showTermsOfService = true
                } label: {
                    Text("auth.terms.tos".localized)
                        .font(.caption)
                        .foregroundColor(ColorTokens.primaryStart)
                }

                Text("auth.terms.and".localized)
                    .font(.caption)
                    .foregroundColor(ColorTokens.textMuted)

                Button {
                    showPrivacyPolicy = true
                } label: {
                    Text("auth.terms.privacy".localized)
                        .font(.caption)
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
        .padding(.bottom, SpacingTokens.lg)
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Handle Apple Sign In
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            // Use async Task to handle the credential
            Task {
                do {
                    try await authService.handleAppleCredential(appleIDCredential)
                    // Auth state change will be handled by onChange observer
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

// MARK: - Apple Sign In Coordinator
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var completion: (Result<ASAuthorization, Error>) -> Void

    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
    }

    func startSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Preview
#Preview {
    AuthenticationView()
        .environmentObject(FocusAppStore.shared)
}
