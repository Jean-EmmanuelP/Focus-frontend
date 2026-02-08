//
//  RevenueCatManager.swift
//  Focus
//
//  RevenueCat integration for subscription management
//

import Foundation
import Combine
import RevenueCat
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
    case plus = "monthly"      // Focus Plus - 34,99€/mois
    case max = "premium"       // Focus Max - 129,99€/mois

    var displayName: String {
        switch self {
        case .plus: return "Focus Plus"
        case .max: return "Focus Max"
        }
    }

    var packageIdentifier: String {
        rawValue
    }
}

// MARK: - RevenueCat Manager
final class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()

    // MARK: - Configuration
    private let apiKey = "appl_YgMmJqvIqMgLEKzriMHnHGXILMu"
    private let entitlementID = "Volta Pro"

    // MARK: - Delegate Handler
    private var delegateHandler: RevenueCatDelegateHandler?

    // MARK: - Published State
    @Published private(set) var subscriptionState: SubscriptionState = .unknown
    @Published private(set) var offerings: Offerings?
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // MARK: - Computed Properties
    var isProUser: Bool {
        subscriptionState.isActive
    }

    var currentOffering: Offering? {
        offerings?.current
    }

    /// Focus Plus - 34,99€/mois (package identifier: "monthly")
    var plusPackage: Package? {
        currentOffering?.package(identifier: "monthly") ?? currentOffering?.monthly
    }

    /// Focus Max - 129,99€/mois (package identifier: "premium")
    var maxPackage: Package? {
        currentOffering?.package(identifier: "premium")
    }

    // Legacy aliases for compatibility
    var monthlyPackage: Package? { plusPackage }
    var yearlyPackage: Package? { maxPackage }
    var lifetimePackage: Package? { nil }

    var availablePackages: [Package] {
        currentOffering?.availablePackages ?? []
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Configuration
    func configure() {
        Purchases.logLevel = .debug

        Purchases.configure(
            with: Configuration.Builder(withAPIKey: apiKey)
                .with(usesStoreKit2IfAvailable: true)
                .build()
        )

        // Set delegate for customer info updates
        delegateHandler = RevenueCatDelegateHandler { [weak self] customerInfo in
            Task { @MainActor in
                self?.customerInfo = customerInfo
                self?.updateSubscriptionState(from: customerInfo)
            }
        }
        Purchases.shared.delegate = delegateHandler

        print("✅ RevenueCat configured with API key")

        // Fetch initial data
        Task {
            await refreshData()
        }
    }

    // MARK: - Configure with User ID (after sign in)
    func configureWithUser(userId: String) async {
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            self.customerInfo = customerInfo
            updateSubscriptionState(from: customerInfo)
            print("✅ RevenueCat logged in with user: \(userId)")
        } catch {
            print("❌ RevenueCat login error: \(error)")
            // Still fetch offerings even if login fails
            await fetchOfferings()
        }
    }

    // MARK: - Logout
    func logout() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            updateSubscriptionState(from: customerInfo)
            print("✅ RevenueCat logged out")
        } catch {
            print("❌ RevenueCat logout error: \(error)")
        }
    }

    // MARK: - Refresh All Data
    func refreshData() async {
        await fetchCustomerInfo()
        await fetchOfferings()
    }

    // MARK: - Fetch Customer Info
    func fetchCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            self.customerInfo = info
            updateSubscriptionState(from: info)
            print("✅ Customer info fetched")
        } catch {
            print("❌ Error fetching customer info: \(error)")
            errorMessage = "Impossible de recuperer les informations d'abonnement"
        }
    }

    // MARK: - Fetch Offerings
    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            print("✅ Offerings fetched: \(offerings.all.count) offerings")

            if let current = offerings.current {
                print("📦 Current offering: \(current.identifier)")
                print("📦 Available packages: \(current.availablePackages.map { $0.identifier })")
            }
        } catch {
            print("❌ Error fetching offerings: \(error)")
            errorMessage = "Impossible de charger les offres"
        }
    }

    // MARK: - Purchase
    func purchase(package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            if !result.userCancelled {
                self.customerInfo = result.customerInfo
                updateSubscriptionState(from: result.customerInfo)
                print("✅ Purchase successful!")

                // Activate referral if user was referred (apply + activate)
                Task {
                    await ReferralService.shared.applyPendingCodeIfNeeded()
                    await ReferralService.shared.activateReferral()
                }

                return true
            } else {
                print("ℹ️ Purchase cancelled by user")
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
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            updateSubscriptionState(from: customerInfo)

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
        guard let customerInfo = try? await Purchases.shared.customerInfo() else {
            return false
        }
        return customerInfo.entitlements[entitlementID]?.isActive == true
    }

    // MARK: - Private Methods
    private func updateSubscriptionState(from customerInfo: CustomerInfo) {
        // Check for active entitlement "Volta Pro"
        if let entitlement = customerInfo.entitlements[entitlementID], entitlement.isActive {
            // Determine tier based on product identifier
            // focus_plus_monthly = Plus, focus_max_monthly = Max
            let productId = entitlement.productIdentifier.lowercased()

            if productId.contains("max") {
                subscriptionState = .subscribed(tier: .max)
            } else {
                // Default to Plus for any other subscription
                subscriptionState = .subscribed(tier: .plus)
            }

            print("✅ User is subscribed: \(subscriptionState)")
        } else if customerInfo.entitlements[entitlementID] != nil {
            // Had entitlement but expired
            subscriptionState = .expired
            print("⚠️ Subscription expired")
        } else {
            subscriptionState = .notSubscribed
            print("ℹ️ User is not subscribed")
        }
    }

    private func handlePurchaseError(_ error: Error) {
        if let rcError = error as? RevenueCat.ErrorCode {
            switch rcError {
            case .purchaseCancelledError:
                // User cancelled, no error message needed
                break
            case .paymentPendingError:
                errorMessage = "Paiement en attente de validation"
            case .productNotAvailableForPurchaseError:
                errorMessage = "Produit non disponible"
            case .purchaseNotAllowedError:
                errorMessage = "Achat non autorise sur cet appareil"
            case .networkError:
                errorMessage = "Erreur reseau, veuillez reessayer"
            default:
                errorMessage = "Erreur lors de l'achat"
            }
        } else {
            errorMessage = "Une erreur est survenue"
        }
    }
}

// MARK: - RevenueCat Delegate Handler
final class RevenueCatDelegateHandler: NSObject, PurchasesDelegate {
    private let onCustomerInfoUpdate: (CustomerInfo) -> Void

    init(onCustomerInfoUpdate: @escaping (CustomerInfo) -> Void) {
        self.onCustomerInfoUpdate = onCustomerInfoUpdate
        super.init()
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        print("📱 Customer info updated via delegate")
        onCustomerInfoUpdate(customerInfo)
    }
}

// MARK: - Package Extension for Display
extension Package {
    var localizedPricePerPeriod: String {
        let price = localizedPriceString

        switch packageType {
        case .monthly:
            return "\(price)/mois"
        case .annual:
            return "\(price)/an"
        case .lifetime:
            return "\(price) (a vie)"
        case .weekly:
            return "\(price)/semaine"
        default:
            return price
        }
    }

    var localizedPricePerWeek: String? {
        guard let product = storeProduct.pricePerWeek else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = storeProduct.priceFormatter?.locale ?? Locale.current

        return formatter.string(from: product as NSDecimalNumber)
    }

    var savingsPercentage: Int? {
        // Calculate savings compared to monthly
        guard packageType == .annual else { return nil }

        // 79.99€/year vs 9.99€*12 = 119.88€/year = ~33% savings
        return 33
    }
}

// MARK: - StoreProduct Extension
extension StoreProduct {
    var pricePerWeek: Decimal? {
        guard let period = subscriptionPeriod else { return nil }

        let weeksInPeriod: Decimal
        switch period.unit {
        case .day:
            weeksInPeriod = Decimal(period.value) / 7
        case .week:
            weeksInPeriod = Decimal(period.value)
        case .month:
            weeksInPeriod = Decimal(period.value) * Decimal(52.0 / 12.0)
        case .year:
            weeksInPeriod = Decimal(period.value) * 52
        @unknown default:
            return nil
        }

        guard weeksInPeriod > 0 else { return nil }
        return price / weeksInPeriod
    }
}
