import Foundation
import Combine

// MARK: - Referral Models
// Note: APIClient uses .convertFromSnakeCase, so no CodingKeys needed

struct ReferralStats: Codable {
    let code: String
    let shareLink: String
    let totalReferrals: Int
    let activeReferrals: Int
    let totalEarned: Double
    let currentBalance: Double
    let commissionRate: Double

    var commissionPercentage: Int {
        Int(commissionRate * 100)
    }

    var formattedTotalEarned: String {
        String(format: "%.2f", totalEarned) + "€"
    }

    var formattedBalance: String {
        String(format: "%.2f", currentBalance) + "€"
    }
}

struct ReferralItem: Codable, Identifiable {
    let id: String
    let referredName: String
    let referredAvatar: String
    let status: String
    let referredAt: String
    let activatedAt: String?

    var statusEmoji: String {
        switch status {
        case "active": return "✅"
        case "pending": return "⏳"
        case "churned": return "❌"
        default: return "❓"
        }
    }

    var statusText: String {
        switch status {
        case "active": return "Abonné"
        case "pending": return "En attente"
        case "churned": return "Désabonné"
        default: return status
        }
    }
}

struct ReferralEarning: Codable, Identifiable {
    var id: String { "\(month)-\(referredName)" }
    let month: String
    let referredName: String
    let subscriptionAmount: Double
    let commissionAmount: Double
    let status: String

    var formattedCommission: String {
        String(format: "%.2f", commissionAmount) + "€"
    }

    var formattedMonth: String {
        // Convert "2024-01" to "Janvier 2024"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: month) else { return month }

        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date).capitalized
    }
}

struct ApplyCodeResponse: Codable {
    let success: Bool
    let message: String
    let referrerName: String?
}

struct ValidateCodeResponse: Codable {
    let valid: Bool
    let code: String?
}

// MARK: - Referral Service

@MainActor
class ReferralService: ObservableObject {
    static let shared = ReferralService()

    private let apiClient = APIClient.shared

    @Published var stats: ReferralStats?
    @Published var referrals: [ReferralItem] = []
    @Published var earnings: [ReferralEarning] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Stored referral code (from deep link before signup)
    @Published var pendingReferralCode: String?

    private init() {}

    // MARK: - Fetch Stats

    func fetchStats() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: ReferralStats = try await apiClient.request(
                endpoint: .referralStats,
                method: .get
            )
            self.stats = response
        } catch {
            print("❌ Failed to fetch referral stats: \(error)")
            errorMessage = "Impossible de charger les statistiques"
        }

        isLoading = false
    }

    // MARK: - Fetch Referrals List

    func fetchReferrals() async {
        do {
            // API may return null instead of empty array
            let response: [ReferralItem]? = try await apiClient.requestOptional(
                endpoint: .referralList,
                method: .get
            )
            self.referrals = response ?? []
        } catch {
            print("❌ Failed to fetch referrals: \(error)")
            self.referrals = []
        }
    }

    // MARK: - Fetch Earnings

    func fetchEarnings() async {
        do {
            // API may return null instead of empty array
            let response: [ReferralEarning]? = try await apiClient.requestOptional(
                endpoint: .referralEarnings,
                method: .get
            )
            self.earnings = response ?? []
        } catch {
            print("❌ Failed to fetch earnings: \(error)")
            self.earnings = []
        }
    }

    // MARK: - Apply Referral Code

    func applyCode(_ code: String) async -> (success: Bool, message: String) {
        do {
            let request = ["code": code]
            let response: ApplyCodeResponse = try await apiClient.request(
                endpoint: .referralApply,
                method: .post,
                body: request
            )

            if response.success {
                // Clear pending code
                pendingReferralCode = nil
            }

            return (response.success, response.message)
        } catch {
            print("❌ Failed to apply referral code: \(error)")
            return (false, "Une erreur est survenue")
        }
    }

    // MARK: - Validate Code (Public)

    func validateCode(_ code: String) async -> Bool {
        do {
            // This endpoint doesn't require auth
            let url = URL(string: "\(APIConfiguration.baseURL)/referral/validate?code=\(code)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ValidateCodeResponse.self, from: data)
            return response.valid
        } catch {
            print("❌ Failed to validate referral code: \(error)")
            return false
        }
    }

    // MARK: - Activate Referral (after subscription)

    func activateReferral() async {
        do {
            let _: EmptyResponse = try await apiClient.request(
                endpoint: .referralActivate,
                method: .post
            )
            print("✅ Referral activated")

            // Refresh stats
            await fetchStats()
        } catch {
            print("❌ Failed to activate referral: \(error)")
        }
    }

    // MARK: - Store Pending Code (from deep link)

    func storePendingCode(_ code: String) {
        pendingReferralCode = code
        // Also store in UserDefaults for persistence
        UserDefaults.standard.set(code, forKey: "pending_referral_code")
        print("📝 Stored pending referral code: \(code)")
    }

    // MARK: - Apply Pending Code (after signup)

    func applyPendingCodeIfNeeded() async {
        // Check UserDefaults first
        if pendingReferralCode == nil {
            pendingReferralCode = UserDefaults.standard.string(forKey: "pending_referral_code")
        }

        guard let code = pendingReferralCode else { return }

        let result = await applyCode(code)
        if result.success {
            UserDefaults.standard.removeObject(forKey: "pending_referral_code")
            print("✅ Pending referral code applied successfully")
        }
    }

    // MARK: - Share Link

    func getShareLink() -> String {
        guard let code = stats?.code else {
            return "https://apps.apple.com/app/focus-fire-level/id6743387301"
        }
        return "https://apps.apple.com/app/focus-fire-level/id6743387301"
    }

    func getShareMessage() -> String {
        guard let code = stats?.code else {
            return """
            Découvre Focus, l'app qui t'aide à rester concentré et atteindre tes objectifs ! 🔥

            Télécharge-la ici :
            https://apps.apple.com/app/focus-fire-level/id6743387301
            """
        }

        return """
        Rejoins-moi sur Focus ! 🔥

        L'app qui m'aide à rester concentré et atteindre mes objectifs.

        📲 Télécharge l'app : https://apps.apple.com/app/focus-fire-level/id6743387301

        🎁 Utilise mon code de parrainage : \(code)
        (Entre-le lors de ton inscription pour profiter de l'offre)
        """
    }
}
