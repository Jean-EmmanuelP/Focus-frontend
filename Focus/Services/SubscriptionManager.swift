//
//  SubscriptionManager.swift
//  Focus
//
//  Subscription management via StoreKit 2
//

import Foundation
import Combine
import StoreKit

// MARK: - Store Error

enum StoreError: Error { case failedVerification }

// MARK: - Subscription Manager (StoreKit 2)

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs
    static let productIDs: Set<String> = [
        "com.volta.monthly",
        "com.volta.yearly"
    ]

    // MARK: - Published State
    @Published var products: [Product] = []
    @Published var isSubscribed: Bool = false
    @Published var activePlanID: String? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Transaction Listener
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Computed Properties

    /// Backward-compat: views use isProUser
    var isProUser: Bool { isSubscribed }

    /// Monthly product (Focus Plus)
    var plusProduct: Product? {
        products.first { $0.id == "com.volta.monthly" }
    }

    /// Yearly product (Focus Max)
    var maxProduct: Product? {
        products.first { $0.id == "com.volta.yearly" }
    }

    // Aliases used by paywall views
    var plusPackage: Product? { plusProduct }
    var maxPackage: Product? { maxProduct }

    /// Non-nil when products are loaded
    var offerings: [Product]? {
        products.isEmpty ? nil : products
    }

    var currentOffering: [Product]? { offerings }

    /// Subscription state for SubscriptionManagementView
    var subscriptionState: SubscriptionState {
        guard isSubscribed, let planID = activePlanID else {
            return .notSubscribed
        }
        if planID == "com.volta.yearly" {
            return .subscribed(tier: .max)
        }
        return .subscribed(tier: .plus)
    }

    /// Expiration date (populated on status check)
    var subscriptionExpirationDate: Date? {
        _expirationDate
    }
    private var _expirationDate: Date?

    /// Compat for SubscriptionManagementView
    var customerInfo: SubscriptionInfo? {
        guard isSubscribed || _expirationDate != nil else { return nil }
        return SubscriptionInfo(expirationDate: _expirationDate)
    }

    // MARK: - Initialization

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateStatus()
        }
    }

    deinit { updateListenerTask?.cancel() }

    // MARK: - Configuration (called from FocusApp.init)

    func configure() {
        print("✅ StoreKit 2 configured")
        Task {
            await loadProducts()
            await updateStatus()
        }
    }

    func configureWithUser(userId: String) async {
        print("ℹ️ StoreKit 2 configured for user: \(userId)")
        await updateStatus()
    }

    func logout() async {
        print("ℹ️ StoreKit 2 logout — refreshing state")
        await updateStatus()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
            products.sort { $0.price < $1.price } // Plus avant Max
            print("✅ Products fetched: \(products.map { "\($0.id) → \($0.displayPrice)" })")
        } catch {
            print("❌ Error fetching products: \(error)")
            errorMessage = "Impossible de charger les offres"
        }
    }

    /// Alias kept for existing paywall views
    func fetchOfferings() async {
        await loadProducts()
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
                let transaction = try checkVerified(verification)
                await updateStatus()
                await transaction.finish()
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

    // MARK: - Update Status

    func updateStatus() async {
        var foundPlan: String? = nil
        var expDate: Date? = nil

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.revocationDate == nil {
                foundPlan = transaction.productID
                expDate = transaction.expirationDate
            }
        }

        self.activePlanID = foundPlan
        self.isSubscribed = foundPlan != nil
        self._expirationDate = expDate

        if let plan = foundPlan {
            print("✅ Active subscription: \(plan) (expires: \(String(describing: expDate)))")
        } else {
            print("ℹ️ No active subscription")
        }
    }

    /// Alias kept for existing views
    func checkSubscriptionStatus() async {
        await updateStatus()
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateStatus()

            if isSubscribed {
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

    func restore() async {
        _ = await restorePurchases()
    }

    func checkEntitlement() async -> Bool {
        await updateStatus()
        return isSubscribed
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? await self.checkVerified(result) {
                    await self.updateStatus()
                    await transaction.finish()
                    print("📱 Transaction updated: \(transaction.productID)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
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

// MARK: - Subscription State (used by SubscriptionManagementView)

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
    case plus = "com.volta.monthly"
    case max = "com.volta.yearly"

    var displayName: String {
        switch self {
        case .plus: return "Focus Plus"
        case .max: return "Focus Max"
        }
    }

    var productId: String { rawValue }
}

// MARK: - Subscription Info (compat for SubscriptionManagementView)

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
        case .month: return "\(displayPrice)/mois"
        case .year: return "\(displayPrice)/an"
        case .week: return "\(displayPrice)/semaine"
        case .day: return "\(displayPrice)/jour"
        @unknown default: return displayPrice
        }
    }

    var localizedPricePerWeek: String? {
        guard let subscription = subscription else { return nil }
        let weeksInPeriod: Decimal
        switch subscription.subscriptionPeriod.unit {
        case .day: weeksInPeriod = Decimal(subscription.subscriptionPeriod.value) / 7
        case .week: weeksInPeriod = Decimal(subscription.subscriptionPeriod.value)
        case .month: weeksInPeriod = Decimal(subscription.subscriptionPeriod.value) * Decimal(52.0 / 12.0)
        case .year: weeksInPeriod = Decimal(subscription.subscriptionPeriod.value) * 52
        @unknown default: return nil
        }
        guard weeksInPeriod > 0 else { return nil }
        let weekPrice = price / weeksInPeriod
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: weekPrice as NSDecimalNumber)
    }

    /// Compat: views use .identifier
    var identifier: String { id }
}
