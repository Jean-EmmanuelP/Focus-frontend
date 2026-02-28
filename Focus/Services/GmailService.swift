//
//  GmailService.swift
//  Focus
//
//  Gmail integration for building user persona from email analysis
//

import Foundation
import Combine
import GoogleSignIn

// MARK: - Gmail Config Response

struct GmailConfigResponse: Codable {
    let isConnected: Bool
    let googleEmail: String?
    let lastAnalyzedAt: Date?
    let personaGenerated: Bool
    let messagesAnalyzed: Int
}

// MARK: - Save Gmail Tokens Request

struct SaveGmailTokensRequest: Codable {
    let authCode: String?
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let googleEmail: String

    enum CodingKeys: String, CodingKey {
        case authCode = "auth_code"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case googleEmail = "google_email"
    }
}

// MARK: - Gmail Analysis Result

struct GmailAnalysisResult: Codable {
    let success: Bool
    let messagesAnalyzed: Int
    let personaExtracted: PersonaData?
    let error: String?
}

struct PersonaData: Codable {
    let interests: [String]?
    let communicationStyle: String?
    let professionalContext: String?
    let frequentContacts: [String]?
    let topics: [String]?
}

// MARK: - Gmail Service

@MainActor
class GmailService: ObservableObject {
    static let shared = GmailService()

    @Published var config: GmailConfigResponse?
    @Published var isLoading = false
    @Published var isAnalyzing = false
    @Published var error: String?
    @Published var analysisProgress: String = ""

    // Google OAuth — same client ID as Calendar
    private let clientID = "613349634589-1d8mmjai794ia29pluv97t21mj2349ej.apps.googleusercontent.com"

    // Gmail API scopes
    private let gmailReadScope = "https://www.googleapis.com/auth/gmail.readonly"
    private let gmailMetadataScope = "https://www.googleapis.com/auth/gmail.metadata"
    private let userInfoScope = "https://www.googleapis.com/auth/userinfo.email"

    private init() {}

    var requiredScopes: [String] {
        [gmailReadScope, userInfoScope]
    }

    // MARK: - Restore previous sign-in (call on app launch)

    func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
                print("✅ Gmail: Restored sign-in for \(user.profile?.email ?? "unknown")")
            }
        }
    }

    // MARK: - Sign in with Gmail scope

    func signIn(from viewController: UIViewController) async throws -> (email: String, accessToken: String, serverAuthCode: String?) {
        return try await withCheckedThrowingContinuation { continuation in
            // Configure with serverClientID to get a server auth code for backend exchange
            let config = GIDConfiguration(clientID: clientID, serverClientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: requiredScopes
            ) { result, error in
                if let error = error {
                    continuation.resume(throwing: GmailError.signInFailed(error.localizedDescription))
                    return
                }

                guard let user = result?.user else {
                    continuation.resume(throwing: GmailError.noUserReturned)
                    return
                }

                let accessToken = user.accessToken.tokenString
                let email = user.profile?.email ?? ""
                let serverAuthCode = result?.serverAuthCode

                continuation.resume(returning: (email, accessToken, serverAuthCode))
            }
        }
    }

    // MARK: - Ensure gmail.readonly scope is granted

    func ensureGmailScope(from viewController: UIViewController) async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw GmailError.notAuthenticated
        }

        let grantedScopes = currentUser.grantedScopes ?? []
        print("📧 Granted scopes: \(grantedScopes)")

        if grantedScopes.contains(gmailReadScope) {
            // Scope already granted — just refresh and return token
            return try await refreshAccessToken()
        }

        // Scope NOT granted — explicitly request it
        print("⚠️ gmail.readonly not granted, requesting via addScopes...")
        return try await withCheckedThrowingContinuation { continuation in
            currentUser.addScopes([self.gmailReadScope], presenting: viewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: GmailError.signInFailed(error.localizedDescription))
                    return
                }
                guard let user = result?.user else {
                    continuation.resume(throwing: GmailError.scopeNotGranted)
                    return
                }

                // Verify scope was actually granted after consent
                let newScopes = user.grantedScopes ?? []
                if !newScopes.contains("https://www.googleapis.com/auth/gmail.readonly") {
                    continuation.resume(throwing: GmailError.scopeNotGranted)
                    return
                }

                print("✅ gmail.readonly scope granted")
                continuation.resume(returning: user.accessToken.tokenString)
            }
        }
    }

    // MARK: - Refresh access token via GIDSignIn SDK

    func refreshAccessToken() async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw GmailError.notAuthenticated
        }

        return try await withCheckedThrowingContinuation { continuation in
            currentUser.refreshTokensIfNeeded { user, error in
                if let error = error {
                    continuation.resume(throwing: GmailError.signInFailed(error.localizedDescription))
                    return
                }
                guard let user = user else {
                    continuation.resume(throwing: GmailError.noUserReturned)
                    return
                }
                continuation.resume(returning: user.accessToken.tokenString)
            }
        }
    }

    // MARK: - Save tokens to backend

    func saveTokens(accessToken: String, serverAuthCode: String? = nil, email: String) async throws {
        let request = SaveGmailTokensRequest(
            authCode: serverAuthCode,
            accessToken: accessToken,
            refreshToken: nil,
            expiresIn: 3600,
            googleEmail: email
        )

        let response: GmailConfigResponse = try await APIClient.shared.request(
            endpoint: .gmailSaveTokens,
            method: .post,
            body: request
        )

        self.config = response
    }

    // MARK: - Fetch Gmail configuration

    func fetchConfig() async {
        isLoading = true
        error = nil

        do {
            let response: GmailConfigResponse = try await APIClient.shared.request(
                endpoint: .gmailConfig,
                method: .get
            )
            self.config = response
        } catch {
            self.error = error.localizedDescription
            self.config = GmailConfigResponse(
                isConnected: false,
                googleEmail: nil,
                lastAnalyzedAt: nil,
                personaGenerated: false,
                messagesAnalyzed: 0
            )
        }

        isLoading = false
    }

    // MARK: - Trigger email analysis (refreshes token first)

    func analyzeEmails() async throws -> GmailAnalysisResult {
        isAnalyzing = true
        analysisProgress = "Récupération des emails..."

        defer {
            isAnalyzing = false
            analysisProgress = ""
        }

        // Refresh access token via GIDSignIn and update backend before analysis
        if let freshToken = try? await refreshAccessToken(),
           let email = GIDSignIn.sharedInstance.currentUser?.profile?.email {
            try? await saveTokens(accessToken: freshToken, email: email)
        }

        let result: GmailAnalysisResult = try await APIClient.shared.request(
            endpoint: .gmailAnalyze,
            method: .post
        )

        await fetchConfig()
        return result
    }

    // MARK: - Disconnect Gmail

    func disconnect() async throws {
        try await APIClient.shared.request(
            endpoint: .gmailDisconnect,
            method: .delete
        )

        self.config = GmailConfigResponse(
            isConnected: false,
            googleEmail: nil,
            lastAnalyzedAt: nil,
            personaGenerated: false,
            messagesAnalyzed: 0
        )

        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Computed Properties

    var isConnected: Bool {
        config?.isConnected == true
    }

    var connectedEmail: String? {
        config?.googleEmail
    }
}

// MARK: - Gmail Errors

enum GmailError: LocalizedError {
    case signInFailed(String)
    case noUserReturned
    case notAuthenticated
    case scopeNotGranted
    case analysisTimeout
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Connexion Gmail échouée: \(message)"
        case .noUserReturned:
            return "Aucun utilisateur retourné"
        case .notAuthenticated:
            return "Non authentifié avec Gmail"
        case .scopeNotGranted:
            return "L'accès en lecture aux emails n'a pas été autorisé. Merci d'accepter la permission Gmail."
        case .analysisTimeout:
            return "L'analyse a pris trop de temps"
        case .serverError(let message):
            return "Erreur serveur: \(message)"
        }
    }
}
