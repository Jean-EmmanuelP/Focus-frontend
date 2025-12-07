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
        ZStack {
            // Background
            ColorTokens.background
                .ignoresSafeArea()

            // Content
            VStack(spacing: SpacingTokens.xxl) {
                Spacer()

                // Logo and branding
                brandingSection

                // Story/Value proposition
                storySection

                Spacer()

                // Sign in button
                signInSection

                // Terms
                termsSection
            }
            .padding(SpacingTokens.xl)

            // Loading overlay
            if authService.isAuthenticating {
                loadingOverlay
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.error?.localizedDescription ?? "An error occurred")
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

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                    .scaleEffect(1.5)

                Text("Signing in...")
                    .bodyText()
                    .foregroundColor(ColorTokens.textPrimary)
            }
            .padding(SpacingTokens.xl)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
        }
    }

    // MARK: - Branding Section
    private var brandingSection: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Animated flame icon
            ZStack {
                // Glow effect
                Circle()
                    .fill(ColorTokens.primaryGlow)
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                // Flame emoji
                Text("🔥")
                    .font(.system(size: 80))
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
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
                    .tracking(2)

                Text("Ship your side project")
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
                featureRow(icon: "⚡", text: "Deep focus sessions")
                featureRow(icon: "🎯", text: "Track quests and goals")
                featureRow(icon: "📈", text: "Level up with habits")
                featureRow(icon: "🌅", text: "Daily rituals")
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
            // Sign in with Apple button
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
    }

    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text("By continuing, you agree to our")
                .caption()
                .foregroundColor(ColorTokens.textMuted)

            HStack(spacing: SpacingTokens.xs) {
                Button("Terms of Service") {
                    showTermsOfService = true
                }
                .foregroundColor(ColorTokens.primaryStart)

                Text("and")
                    .foregroundColor(ColorTokens.textMuted)

                Button("Privacy Policy") {
                    showPrivacyPolicy = true
                }
                .foregroundColor(ColorTokens.primaryStart)
            }
            .caption()
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

// MARK: - Preview
#Preview {
    AuthenticationView()
        .environmentObject(FocusAppStore.shared)
}
