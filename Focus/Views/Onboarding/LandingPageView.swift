//
//  LandingPageView.swift
//  Focus
//
//  Landing page for logged-out users - Ralph design implementation
//

import SwiftUI
import AuthenticationServices

struct LandingPageView: View {
    @EnvironmentObject var store: FocusAppStore
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            // Fond sombre (dark gradient plein ecran)
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.22),
                    Color(red: 0.12, green: 0.16, blue: 0.32),
                    Color(red: 0.10, green: 0.14, blue: 0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Logo "Focus" centre en haut, blanc
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Focus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 60)

                Spacer()

                // Titre large centre, blanc, bold serif: "The AI to do life with" (3 lignes)
                VStack(spacing: 4) {
                    Text("The AI")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundColor(.white)

                    Text("to do life")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundColor(.white)

                    Text("with")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                Spacer()

                // Section bas de page
                VStack(spacing: 16) {
                    // 1 bouton d'auth en bas, pill shape (~56pt height, full width padding 24pt)
                    // "Continuer avec Apple" - fond bleu (#0066FF), icone Apple, texte blanc
                    Button(action: {
                        handleAppleSignInTap()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Continuer avec Apple")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 0.0, green: 0.4, blue: 1.0)) // #0066FF
                        .cornerRadius(28)
                    }
                    .padding(.horizontal, 24)

                    // Texte legal en bas: ~13pt, gris, centre
                    Text("En continuant, vous acceptez notre Conditions d'utilisation et Politique de confidentialité")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            NewOnboardingView()
        }
    }

    // MARK: - Actions

    private func handleAppleSignInTap() {
        // Use ASAuthorizationController for Sign in with Apple
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = LandingAppleSignInCoordinator.shared
        authorizationController.presentationContextProvider = LandingAppleSignInCoordinator.shared
        authorizationController.performRequests()

        // Store reference to handle callback
        LandingAppleSignInCoordinator.shared.onSuccess = { authorization in
            handleAppleSignIn(authorization)
        }
    }

    private func handleAppleSignIn(_ authorization: ASAuthorization) {
        Task {
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
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
}

// MARK: - Apple Sign In Coordinator (Landing)

class LandingAppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = LandingAppleSignInCoordinator()

    var onSuccess: ((ASAuthorization) -> Void)?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onSuccess?(authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In failed: \(error)")
    }
}

// MARK: - Preview

#Preview {
    LandingPageView()
        .environmentObject(FocusAppStore.shared)
}
