import Foundation
import AuthenticationServices
import CryptoKit
import Combine
import UIKit

#if canImport(Supabase)
import Supabase
#endif

// MARK: - Auth Service
@MainActor
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    // MARK: - Published State
    @Published var isAuthenticating = false
    @Published var error: AuthError?
    @Published var isSignedIn = false
    @Published var userId: String?
    @Published var userEmail: String?
    @Published var userName: String?

    #if canImport(Supabase)
    @Published var session: Session?

    // Supabase client
    private lazy var supabaseClient: SupabaseClient = {
        SupabaseClient(
            supabaseURL: SupabaseConfig.supabaseURL,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }()
    #endif

    // MARK: - Private Properties
    private var currentNonce: String?

    private override init() {
        super.init()
        print("🚀 AuthService initialized")

        #if canImport(Supabase)
        print("📦 Supabase module available")
        // Listen to auth state changes
        Task {
            // First check for existing session
            print("🔍 Checking for existing session on startup...")
            let hasSession = await checkSession()
            print("📋 Startup session check result: \(hasSession)")

            // Then listen for changes
            await listenToAuthChanges()
        }
        #else
        print("⚠️ Supabase module NOT available")
        #endif
    }

    #if canImport(Supabase)
    // MARK: - Listen to Auth State Changes
    private func listenToAuthChanges() async {
        for await (event, session) in supabaseClient.auth.authStateChanges {
            self.session = session
            self.isSignedIn = session != nil
            self.userId = session?.user.id.uuidString
            self.userEmail = session?.user.email
            self.userName = session?.user.userMetadata["full_name"]?.stringValue

            if event == .signedOut {
                self.session = nil
                self.isSignedIn = false
                self.userId = nil
                self.userEmail = nil
                self.userName = nil
            }
        }
    }

    // MARK: - Check Current Session
    func checkSession() async -> Bool {
        do {
            print("🔍 Checking Supabase session...")
            let session = try await supabaseClient.auth.session
            self.session = session
            self.isSignedIn = true
            self.userId = session.user.id.uuidString
            self.userEmail = session.user.email
            self.userName = session.user.userMetadata["full_name"]?.stringValue
            print("✅ Supabase session found: \(session.user.email ?? "no email")")
            return true
        } catch {
            print("❌ No Supabase session: \(error.localizedDescription)")
            self.session = nil
            self.isSignedIn = false
            return false
        }
    }

    // MARK: - Get Access Token
    func getAccessToken() async -> String? {
        // First try current session
        if let token = session?.accessToken {
            print("✅ Got token from current session")
            return token
        }

        // Try to restore session
        print("⏳ No current session, checking Supabase...")
        let hasSession = await checkSession()
        if hasSession, let token = session?.accessToken {
            print("✅ Got token after checkSession")
            return token
        }

        print("❌ No access token available")
        return nil
    }
    #else
    func checkSession() async -> Bool {
        return false
    }

    func getAccessToken() async -> String? {
        print("⚠️ Supabase not available, no token")
        return nil
    }
    #endif

    // MARK: - Handle Apple Credential from SwiftUI Button
    func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async throws {
        isAuthenticating = true
        error = nil

        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            isAuthenticating = false
            throw AuthError.invalidCredential
        }

        #if canImport(Supabase)
        do {
            // Sign in with Supabase using the Apple ID token
            let session = try await supabaseClient.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: identityToken
                )
            )

            // Update user metadata with name if available
            if let fullName = credential.fullName,
               let givenName = fullName.givenName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                if !displayName.isEmpty {
                    try await supabaseClient.auth.update(user: .init(data: [
                        "full_name": .string(displayName),
                        "first_name": .string(givenName),
                        "last_name": .string(fullName.familyName ?? "")
                    ]))
                }
            }

            self.session = session
            self.userId = session.user.id.uuidString
            self.userEmail = session.user.email
            self.userName = session.user.userMetadata["full_name"]?.stringValue
            print("🎉 Sign in successful! Token: \(session.accessToken.prefix(20))...")

            // CRITICAL: Check onboarding status BEFORE setting isSignedIn
            // This prevents the race condition where OnboardingView advances before we know the status
            await FocusAppStore.shared.handleAuthServiceUpdate()

            // Only set isSignedIn AFTER onboarding status is checked
            self.isSignedIn = true
            isAuthenticating = false

        } catch {
            isAuthenticating = false
            let authError = AuthError.supabaseError(error.localizedDescription)
            self.error = authError
            throw authError
        }
        #else
        // Without Supabase, just store the Apple credential locally
        self.isSignedIn = true
        self.userId = credential.user

        if let fullName = credential.fullName {
            self.userName = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
        }

        if let email = credential.email {
            self.userEmail = email
        }

        isAuthenticating = false
        #endif
    }

    // MARK: - Sign Out
    func signOut() async throws {
        #if canImport(Supabase)
        do {
            try await supabaseClient.auth.signOut()
        } catch {
            throw AuthError.supabaseError(error.localizedDescription)
        }
        #endif

        self.isSignedIn = false
        self.userId = nil
        self.userEmail = nil
        self.userName = nil

        #if canImport(Supabase)
        self.session = nil
        #endif
    }

    // MARK: - Nonce Generation (Security)
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Auth Errors
enum AuthError: Error, LocalizedError, Equatable {
    case userCancelled
    case appleSignInFailed
    case invalidCredential
    case networkError
    case supabaseError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Sign in was cancelled"
        case .appleSignInFailed:
            return "Apple Sign In failed"
        case .invalidCredential:
            return "Invalid credentials received"
        case .networkError:
            return "Network error. Please check your connection."
        case .supabaseError(let message):
            return message
        case .unknown:
            return "An unknown error occurred"
        }
    }

    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.userCancelled, .userCancelled),
             (.appleSignInFailed, .appleSignInFailed),
             (.invalidCredential, .invalidCredential),
             (.networkError, .networkError),
             (.unknown, .unknown):
            return true
        case (.supabaseError(let lhsMsg), .supabaseError(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
