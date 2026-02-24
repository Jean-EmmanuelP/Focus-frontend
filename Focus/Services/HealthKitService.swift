import Foundation
import HealthKit

/// Service to fetch health data (step count) from HealthKit
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore: HKHealthStore?
    private(set) var isAuthorized = false

    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        } else {
            healthStore = nil
        }
    }

    // MARK: - Authorization

    /// Request read access to step count
    func requestAuthorization() async -> Bool {
        guard let healthStore else { return false }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            isAuthorized = true
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    // MARK: - Fetch Steps

    /// Fetch today's step count. Returns nil if not available or not authorized.
    /// Automatically requests authorization on first call.
    func fetchTodaySteps() async -> Int? {
        guard let healthStore else { return nil }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }

        // Auto-request authorization if needed
        if !isAuthorized {
            _ = await requestAuthorization()
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    print("HealthKit step query error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                let steps = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps.map { Int($0) })
            }
            healthStore.execute(query)
        }
    }
}
