//
//  RevenueCatManager.swift
//  Focus
//
//  Subscription management via StoreKit 2
//

import Foundation
import Combine
import StoreKit

// MARK: - Subscription State
enum SubscriptionState: Equatable {
    case unknown
    case notSubscribed
    case subscribed(tier: SubscriptionTier)
    case expired

    var isActive: Bool {
        if case .subscribed = self { return true }
        return false
    }
}

enum SubscriptionTier: String, CaseIterable {
    case plus = "focus_plus_monthly"
    case max = "focus_max_monthly"

    var displayName: String {
        switch self {
        case .plus: return "Focus Plus"
        case .max: return "Focus Max"
        }
    }

    var productId: String { rawValue }
}

// MARK: - Subscription Manager (StoreKit 2)

@MainActor
final class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()

    // MARK: - Product IDs
    static let plusProductId = "focus_plus_monthly"
    static let maxProductId = "focus_max_monthly"
    private let allProductIds: Set<String> = [plusProductId, maxProductId]

    // MARK: - Published State
    @Published private(set) var subscriptionState: SubscriptionState = .unknown
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var subscriptionExpirationDate: Date?

    // MARK: - Transaction Listener
    private var transactionListener: Task<Void, Never>?

    // MARK: - Computed Properties
    var isProUser: Bool {
        subscriptionState.isActive
    }

    /// Focus Plus - 34,99€/mois
    var plusProduct: Product? {
        products.first { $0.id == Self.plusProductId }
    }

    /// Focus Max - 129,99€/mois
    var maxProduct: Product? {
        products.first { $0.id == Self.maxProductId }
    }

    // Legacy aliases (used by views)
    var plusPackage: Product? { plusProduct }
    var maxPackage: Product? { maxProduct }
    var monthlyPackage: Product? { plusProduct }
    var yearlyPackage: Product? { maxProduct }
    var lifetimePackage: Product? { nil }

    /// Non-nil when products are loaded (views check this)
    var offerings: [Product]? {
        products.isEmpty ? nil : products
    }

    /// Non-nil when products are loaded (views check this)
    var currentOffering: [Product]? {
        offerings
    }

    var availablePackages: [Product] {
        products
    }

    /// Compatibility for views that check customerInfo.entitlements
    var customerInfo: SubscriptionInfo? {
        guard subscriptionState.isActive || subscriptionExpirationDate != nil else { return nil }
        return SubscriptionInfo(expirationDate: subscriptionExpirationDate)
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Configuration
    func configure() {
        transactionListener = listenForTransactions()
        print("✅ StoreKit 2 configured")

        Task {
            await refreshData()
        }
    }

    // MARK: - Configure with User ID (StoreKit 2 is device-based)
    func configureWithUser(userId: String) async {
        print("ℹ️ StoreKit 2 configured for user: \(userId)")
        await refreshData()
    }

    // MARK: - Logout
    func logout() async {
        print("ℹ️ StoreKit 2 logout - refreshing state")
        await checkSubscriptionStatus()
    }

    // MARK: - Refresh All Data
    func refreshData() async {
        await fetchOfferings()
        await checkSubscriptionStatus()
    }

    // MARK: - Fetch Products
    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: allProductIds)
            self.products = storeProducts.sorted { $0.price < $1.price }
            print("✅ Products fetched: \(storeProducts.map { "\($0.id) → \($0.displayPrice)" })")
        } catch {
            print("❌ Error fetching products: \(error)")
            errorMessage = "Impossible de charger les offres"
        }
    }

    // MARK: - Check Subscription Status
    func checkSubscriptionStatus() async {
        var foundActive = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.productID == Self.maxProductId {
                subscriptionState = .subscribed(tier: .max)
                subscriptionExpirationDate = transaction.expirationDate
                foundActive = true
                print("✅ Active subscription: Focus Max (expires: \(String(describing: transaction.expirationDate)))")
                break // Max is highest tier
            } else if transaction.productID == Self.plusProductId {
                subscriptionState = .subscribed(tier: .plus)
                subscriptionExpirationDate = transaction.expirationDate
                foundActive = true
                print("✅ Active subscription: Focus Plus (expires: \(String(describing: transaction.expirationDate)))")
            }
        }

        if !foundActive {
            subscriptionState = .notSubscribed
            subscriptionExpirationDate = nil
            print("ℹ️ No active subscription")
        }
    }

    // MARK: - Purchase
    func purchase(package product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "Transaction non verifiee"
                    return false
                }

                await transaction.finish()
                await checkSubscriptionStatus()
                print("✅ Purchase successful: \(product.id)")

                // Activate referral if user was referred
                Task {
                    await ReferralService.shared.applyPendingCodeIfNeeded()
                    await ReferralService.shared.activateReferral()
                }

                return true

            case .userCancelled:
                print("ℹ️ Purchase cancelled by user")
                return false

            case .pending:
                errorMessage = "Paiement en attente de validation"
                return false

            @unknown default:
                return false
            }
        } catch {
            print("❌ Purchase error: \(error)")
            handlePurchaseError(error)
            return false
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()

            if subscriptionState.isActive {
                print("✅ Purchases restored successfully!")
                return true
            } else {
                errorMessage = "Aucun achat a restaurer"
                return false
            }
        } catch {
            print("❌ Restore error: \(error)")
            errorMessage = "Erreur lors de la restauration"
            return false
        }
    }

    // MARK: - Check Entitlement
    func checkEntitlement() async -> Bool {
        await checkSubscriptionStatus()
        return subscriptionState.isActive
    }

    // MARK: - Private Methods
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self.checkSubscriptionStatus()
                print("📱 Transaction updated: \(transaction.productID)")
            }
        }
    }

    private func handlePurchaseError(_ error: Error) {
        if let storeError = error as? StoreKitError {
            switch storeError {
            case .userCancelled:
                break
            case .networkError:
                errorMessage = "Erreur reseau, veuillez reessayer"
            case .notAvailableInStorefront:
                errorMessage = "Produit non disponible"
            default:
                errorMessage = "Erreur lors de l'achat"
            }
        } else if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .purchaseNotAllowed:
                errorMessage = "Achat non autorise sur cet appareil"
            default:
                errorMessage = "Erreur lors de l'achat"
            }
        } else {
            errorMessage = "Une erreur est survenue"
        }
    }
}

// MARK: - Subscription Info (replaces CustomerInfo)
struct SubscriptionInfo {
    let expirationDate: Date?

    var entitlements: [String: EntitlementInfo] {
        ["Volta Pro": EntitlementInfo(expirationDate: expirationDate)]
    }
}

struct EntitlementInfo {
    let expirationDate: Date?
}

// MARK: - Product Extension for Display
extension Product {
    var localizedPricePerPeriod: String {
        guard let subscription = subscription else {
            return displayPrice
        }

        switch subscription.subscriptionPeriod.unit {
        case .month:
            return "\(displayPrice)/mois"
        case .year:
            return "\(displayPrice)/an"
        case .week:
            return "\(displayPrice)/semaine"
        case .day:
            return "\(displayPrice)/jour"
        @unknown default:
            return displayPrice
        }
    }

    var localizedPricePerWeek: String? {
        guard let subscription = subscription else { return nil }

        let weeksInPeriod: Decimal
        switch subscription.subscriptionPeriod.unit {
        case .day:
            weeksInPeriod = Decimal(subscription.subscriptionPeriod.value) / 7
        case .week:
            weeksInPeriod = Decimal(subscription.subscriptionPeriod.value)
        case .month:
            weeksInPeriod = Decimal(subscription.subscriptionPeriod.value) * Decimal(52.0 / 12.0)
        case .year:
            weeksInPeriod = Decimal(subscription.subscriptionPeriod.value) * 52
        @unknown default:
            return nil
        }

        guard weeksInPeriod > 0 else { return nil }
        let weekPrice = price / weeksInPeriod

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: weekPrice as NSDecimalNumber)
    }

    /// Compatibility: views use .identifier (Package had this)
    var identifier: String { id }
}
