import Foundation

// MARK: - WhatsApp Models

struct WhatsAppStatus: Codable {
    let isLinked: Bool
    let phoneNumber: String?
    let linkedAt: Date?
    let preferences: WhatsAppPreferences?
}

struct WhatsAppPreferences: Codable, Equatable {
    var morningCheckIn: Bool
    var morningCheckInTime: String  // "HH:mm" format
    var eveningReview: Bool
    var eveningReviewTime: String   // "HH:mm" format
    var streakAlerts: Bool
    var questReminders: Bool
    var inactivityReminders: Bool

    init(
        morningCheckIn: Bool = true,
        morningCheckInTime: String = "08:00",
        eveningReview: Bool = true,
        eveningReviewTime: String = "21:00",
        streakAlerts: Bool = true,
        questReminders: Bool = true,
        inactivityReminders: Bool = true
    ) {
        self.morningCheckIn = morningCheckIn
        self.morningCheckInTime = morningCheckInTime
        self.eveningReview = eveningReview
        self.eveningReviewTime = eveningReviewTime
        self.streakAlerts = streakAlerts
        self.questReminders = questReminders
        self.inactivityReminders = inactivityReminders
    }
}

struct WhatsAppLinkRequest: Encodable {
    let phoneNumber: String
    let verificationCode: String
}

struct WhatsAppSendCodeResponse: Decodable {
    let success: Bool
    let message: String?
}

struct WhatsAppVerifyResponse: Decodable {
    let success: Bool
    let message: String?
    let isLinked: Bool
}

// MARK: - WhatsApp Service

@MainActor
class WhatsAppService {
    static let shared = WhatsAppService()
    private let client = APIClient.shared

    private init() {}

    // MARK: - Status

    /// Get current WhatsApp linking status
    func getStatus() async throws -> WhatsAppStatus {
        try await client.request(endpoint: .whatsappStatus)
    }

    // MARK: - Linking Flow

    /// Step 1: Send verification code to phone number
    func sendVerificationCode(phoneNumber: String) async throws -> WhatsAppSendCodeResponse {
        // Format phone number (ensure +33 format for France)
        let formattedPhone = formatPhoneNumber(phoneNumber)
        return try await client.request(endpoint: .whatsappSendCode(phoneNumber: formattedPhone))
    }

    /// Step 2: Verify code and link WhatsApp
    func verifyAndLink(phoneNumber: String, code: String) async throws -> WhatsAppVerifyResponse {
        let request = WhatsAppLinkRequest(
            phoneNumber: formatPhoneNumber(phoneNumber),
            verificationCode: code
        )
        return try await client.request(
            endpoint: .whatsappVerifyCode,
            method: .post,
            body: request
        )
    }

    /// Unlink WhatsApp account
    func unlink() async throws {
        try await client.request(
            endpoint: .whatsappUnlink,
            method: .delete
        )
    }

    // MARK: - Preferences

    /// Get WhatsApp notification preferences
    func getPreferences() async throws -> WhatsAppPreferences {
        try await client.request(endpoint: .whatsappPreferences)
    }

    /// Update WhatsApp notification preferences
    func updatePreferences(_ preferences: WhatsAppPreferences) async throws -> WhatsAppPreferences {
        try await client.request(
            endpoint: .whatsappUpdatePreferences,
            method: .put,
            body: preferences
        )
    }

    // MARK: - Helpers

    /// Format phone number to international format
    private func formatPhoneNumber(_ phone: String) -> String {
        var cleaned = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        // If starts with 0, assume French number
        if cleaned.hasPrefix("0") {
            cleaned = "+33" + cleaned.dropFirst()
        }

        // Ensure + prefix
        if !cleaned.hasPrefix("+") {
            cleaned = "+" + cleaned
        }

        return cleaned
    }

    /// Validate phone number format
    func isValidPhoneNumber(_ phone: String) -> Bool {
        let formatted = formatPhoneNumber(phone)
        // Basic validation: starts with + and has 10-15 digits
        let digits = formatted.filter { $0.isNumber }
        return formatted.hasPrefix("+") && digits.count >= 10 && digits.count <= 15
    }
}
