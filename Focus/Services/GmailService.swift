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
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let googleEmail: String

    enum CodingKeys: String, CodingKey {
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

    // Google OAuth - same client ID as Calendar
    private let clientID = "613349634589-1d8mmjai794ia29pluv97t21mj2349ej.apps.googleusercontent.com"

    // Gmail API scopes
    private let gmailReadScope = "https://www.googleapis.com/auth/gmail.readonly"
    private let gmailMetadataScope = "https://www.googleapis.com/auth/gmail.metadata"
    private let userInfoScope = "https://www.googleapis.com/auth/userinfo.email"

    // Stored tokens
    private var accessToken: String?
    private var refreshToken: String?

    private init() {}

    // MARK: - Scopes needed for Gmail

    var requiredScopes: [String] {
        [gmailReadScope, userInfoScope]
    }

    // MARK: - API Methods

    /// Fetch Gmail configuration
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

    /// Sign in with Gmail scope
    func signIn(from viewController: UIViewController) async throws -> (email: String, accessToken: String) {
        return try await withCheckedThrowingContinuation { continuation in
            let config = GIDConfiguration(clientID: clientID)
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

                continuation.resume(returning: (email, accessToken))
            }
        }
    }

    /// Save tokens after sign-in
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int, email: String) async throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken

        let request = SaveGmailTokensRequest(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            googleEmail: email
        )

        let response: GmailConfigResponse = try await APIClient.shared.request(
            endpoint: .gmailSaveTokens,
            method: .post,
            body: request
        )

        self.config = response
    }

    /// Trigger email analysis to build persona
    func analyzeEmails() async throws -> GmailAnalysisResult {
        isAnalyzing = true
        analysisProgress = "Récupération des emails..."

        defer {
            isAnalyzing = false
            analysisProgress = ""
        }

        // Call backend to analyze emails
        let result: GmailAnalysisResult = try await APIClient.shared.request(
            endpoint: .gmailAnalyze,
            method: .post
        )

        // Refresh config
        await fetchConfig()

        return result
    }

    /// Disconnect Gmail
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

        self.accessToken = nil
        self.refreshToken = nil

        // Sign out from Google
        GIDSignIn.sharedInstance.signOut()
    }

    /// Set tokens from external sign-in
    func setTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    /// Check if user is connected to Gmail
    var isConnected: Bool {
        config?.isConnected == true
    }

    /// Get connected email
    var connectedEmail: String? {
        config?.googleEmail
    }
}

// MARK: - Gmail Errors

enum GmailError: LocalizedError {
    case signInFailed(String)
    case noUserReturned
    case notAuthenticated
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
        case .analysisTimeout:
            return "L'analyse a pris trop de temps"
        case .serverError(let message):
            return "Erreur serveur: \(message)"
        }
    }
}
