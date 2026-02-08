import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var authService = AuthService.shared
    @State private var showError = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background (placeholder for future image)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.12),
                        Color(red: 0.08, green: 0.10, blue: 0.15),
                        Color(red: 0.06, green: 0.08, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top logo
                    logoSection
                        .padding(.top, geometry.safeAreaInsets.top + 20)

                    // Main title
                    titleSection
                        .padding(.top, 24)

                    // Spacer for image area (black placeholder)
                    Spacer()

                    // Bottom section with buttons
                    bottomSection(geometry: geometry)
                }

                // Loading overlay
                if authService.isAuthenticating {
                    loadingOverlay
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
            .onChange(of: authService.isSignedIn) { _, isSignedIn in
                if isSignedIn {
                    Task {
                        await store.handleAuthServiceUpdate()
                    }
                }
            }
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        HStack(spacing: 8) {
            // App icon placeholder (flame or custom logo)
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Volta")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("The AI")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)

            Text("to do life")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)

            Text("with")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Bottom Section

    private func bottomSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            // Sign in with Apple button (blue style like Replika)
            Button {
                triggerAppleSignIn()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .medium))
                    Text("Continuer avec Apple")
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color(red: 0.20, green: 0.45, blue: 0.95)) // Replika blue
                )
            }
            .padding(.horizontal, 24)

            // Terms text
            termsSection
                .padding(.top, 16)
        }
        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 20 : 40)
    }

    // MARK: - Terms Section

    private var termsSection: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text("En continuant, vous acceptez notre")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 4) {
                Button {
                    showTermsOfService = true
                } label: {
                    Text("Conditions d'utilisation")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .underline()
                }

                Text("et")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                Button {
                    showPrivacyPolicy = true
                } label: {
                    Text("Politique de confidentialité")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .underline()
                }
            }
        }
        .multilineTextAlignment(.center)
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("Connexion en cours...")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.15, green: 0.18, blue: 0.25))
            )
        }
    }

    // MARK: - Apple Sign In

    @State private var appleSignInCoordinator: AppleSignInCoordinator?

    private func triggerAppleSignIn() {
        let coordinator = AppleSignInCoordinator { result in
            handleAppleSignIn(result)
        }
        appleSignInCoordinator = coordinator
        coordinator.startSignIn()
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
