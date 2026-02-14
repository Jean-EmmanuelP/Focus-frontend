//
//  LandingPageView.swift
//  Focus
//
//  Landing page for logged-out users
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct LandingPageView: View {
    @EnvironmentObject var store: FocusAppStore
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            // Background with portal scene
            OnboardingBackgroundView()

            // Content overlay
            VStack(spacing: 0) {
                // Logo
                logoSection
                    .padding(.top, 60)

                // Title
                titleSection
                    .padding(.top, 16)

                Spacer()

                // Bottom buttons
                bottomSection
            }
        }
        .overlay {
            if showOnboarding {
                NewOnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showOnboarding)
    }

    // MARK: - Logo

    private var logoSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Focus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text("The AI")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundColor(.white)

            Text("to do life")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundColor(.white)

            Text("with")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.43, green: 0.66, blue: 1.0),
                            Color(red: 0.65, green: 0.55, blue: 0.98),
                            Color(red: 0.38, green: 0.84, blue: 0.77)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 14) {
            // Apple Sign In
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    handleAppleSignIn(authorization)
                case .failure(let error):
                    print("Apple Sign In failed: \(error)")
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 56)
            .clipShape(Capsule())

            // Google Sign In
            Button(action: handleGoogleSignInTap) {
                HStack(spacing: 10) {
                    GoogleLogoView()
                        .frame(width: 22, height: 22)

                    Text("Continuer avec Google")
                        .font(.system(size: 19, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white.opacity(0.95))
                .clipShape(Capsule())
            }

            // Terms
            Text("En continuant, vous acceptez nos Conditions et Confidentialité")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 50)
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(_ result: ASAuthorization) {
        Task {
            if let credential = result.credential as? ASAuthorizationAppleIDCredential {
                do {
                    try await AuthService.shared.handleAppleCredential(credential)
                    if store.isAuthenticated {
                        showOnboarding = true
                    }
                } catch {
                    print("Apple Sign In error: \(error)")
                }
            }
        }
    }

    // MARK: - Google Sign In

    private func handleGoogleSignInTap() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        let clientID = "613349634589-1d8mmjai794ia29pluv97t21mj2349ej.apps.googleusercontent.com"
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error = error {
                print("Google Sign In error: \(error)")
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Google Sign In: missing ID token")
                return
            }

            Task {
                await handleGoogleIdToken(idToken, user: user)
            }
        }
    }

    @MainActor
    private func handleGoogleIdToken(_ idToken: String, user: GIDGoogleUser) async {
        do {
            try await AuthService.shared.handleGoogleIdToken(
                idToken: idToken,
                fullName: user.profile?.name,
                email: user.profile?.email
            )
            if store.isAuthenticated {
                showOnboarding = true
            }
        } catch {
            print("Google Sign In Supabase error: \(error)")
        }
    }
}

// MARK: - Google Logo

private struct GoogleLogoView: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let scale = s / 24.0

            // Blue
            var blue = Path()
            blue.move(to: CGPoint(x: 22.56 * scale, y: 12.25 * scale))
            blue.addCurve(to: CGPoint(x: 12 * scale, y: 10 * scale),
                          control1: CGPoint(x: 22.56 * scale, y: 11.47 * scale),
                          control2: CGPoint(x: 22.49 * scale, y: 10 * scale))
            blue.addLine(to: CGPoint(x: 12 * scale, y: 14.26 * scale))
            blue.addLine(to: CGPoint(x: 17.92 * scale, y: 14.26 * scale))
            blue.addCurve(to: CGPoint(x: 15.72 * scale, y: 17.58 * scale),
                          control1: CGPoint(x: 17.52 * scale, y: 15.68 * scale),
                          control2: CGPoint(x: 16.82 * scale, y: 16.8 * scale))
            blue.addLine(to: CGPoint(x: 19.28 * scale, y: 20.35 * scale))
            blue.addCurve(to: CGPoint(x: 22.56 * scale, y: 12.25 * scale),
                          control1: CGPoint(x: 21.36 * scale, y: 18.43 * scale),
                          control2: CGPoint(x: 22.56 * scale, y: 15.49 * scale))
            context.fill(blue, with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))

            // Green
            var green = Path()
            green.move(to: CGPoint(x: 12 * scale, y: 23 * scale))
            green.addCurve(to: CGPoint(x: 19.28 * scale, y: 20.34 * scale),
                           control1: CGPoint(x: 14.97 * scale, y: 23 * scale),
                           control2: CGPoint(x: 17.46 * scale, y: 22.02 * scale))
            green.addLine(to: CGPoint(x: 15.71 * scale, y: 17.57 * scale))
            green.addCurve(to: CGPoint(x: 12 * scale, y: 18.63 * scale),
                           control1: CGPoint(x: 14.73 * scale, y: 18.23 * scale),
                           control2: CGPoint(x: 13.48 * scale, y: 18.63 * scale))
            green.addCurve(to: CGPoint(x: 5.84 * scale, y: 14.1 * scale),
                           control1: CGPoint(x: 9.14 * scale, y: 18.63 * scale),
                           control2: CGPoint(x: 6.71 * scale, y: 16.7 * scale))
            green.addLine(to: CGPoint(x: 2.18 * scale, y: 16.94 * scale))
            green.addCurve(to: CGPoint(x: 12 * scale, y: 23 * scale),
                           control1: CGPoint(x: 3.99 * scale, y: 20.53 * scale),
                           control2: CGPoint(x: 7.7 * scale, y: 23 * scale))
            context.fill(green, with: .color(Color(red: 0.20, green: 0.66, blue: 0.33)))

            // Yellow
            var yellow = Path()
            yellow.move(to: CGPoint(x: 5.84 * scale, y: 14.09 * scale))
            yellow.addCurve(to: CGPoint(x: 5.84 * scale, y: 9.91 * scale),
                            control1: CGPoint(x: 5.62 * scale, y: 13.43 * scale),
                            control2: CGPoint(x: 5.49 * scale, y: 12.73 * scale))
            yellow.addLine(to: CGPoint(x: 2.18 * scale, y: 7.07 * scale))
            yellow.addCurve(to: CGPoint(x: 2.18 * scale, y: 16.93 * scale),
                            control1: CGPoint(x: 1.43 * scale, y: 8.55 * scale),
                            control2: CGPoint(x: 1 * scale, y: 10.22 * scale))
            yellow.addLine(to: CGPoint(x: 5.84 * scale, y: 14.09 * scale))
            context.fill(yellow, with: .color(Color(red: 0.98, green: 0.74, blue: 0.02)))

            // Red
            var red = Path()
            red.move(to: CGPoint(x: 12 * scale, y: 5.38 * scale))
            red.addCurve(to: CGPoint(x: 16.21 * scale, y: 7.02 * scale),
                         control1: CGPoint(x: 13.62 * scale, y: 5.38 * scale),
                         control2: CGPoint(x: 15.06 * scale, y: 5.94 * scale))
            red.addLine(to: CGPoint(x: 19.36 * scale, y: 3.87 * scale))
            red.addCurve(to: CGPoint(x: 12 * scale, y: 1 * scale),
                         control1: CGPoint(x: 17.45 * scale, y: 2.09 * scale),
                         control2: CGPoint(x: 14.97 * scale, y: 1 * scale))
            red.addCurve(to: CGPoint(x: 2.18 * scale, y: 7.07 * scale),
                         control1: CGPoint(x: 7.7 * scale, y: 1 * scale),
                         control2: CGPoint(x: 3.99 * scale, y: 3.47 * scale))
            red.addLine(to: CGPoint(x: 5.84 * scale, y: 9.91 * scale))
            red.addCurve(to: CGPoint(x: 12 * scale, y: 5.38 * scale),
                         control1: CGPoint(x: 6.71 * scale, y: 7.31 * scale),
                         control2: CGPoint(x: 9.14 * scale, y: 5.38 * scale))
            context.fill(red, with: .color(Color(red: 0.92, green: 0.26, blue: 0.21)))
        }
    }
}

// MARK: - Preview

#Preview {
    LandingPageView()
        .environmentObject(FocusAppStore.shared)
}
