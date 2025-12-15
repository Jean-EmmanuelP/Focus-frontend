import Foundation
import Network
import Combine

/// Represents a pending sync operation
struct PendingOperation: Codable, Identifiable {
    let id: String
    let type: OperationType
    let entityId: String
    let payload: Data?
    let createdAt: Date
    var retryCount: Int
    let date: String? // For date-specific operations like ritual completions

    enum OperationType: String, Codable {
        case completeTask
        case uncompleteTask
        case completeRitual
        case uncompleteRitual
        case createTask
        case updateTask
        case deleteTask
    }

    init(type: OperationType, entityId: String, payload: Data? = nil, date: String? = nil) {
        self.id = UUID().uuidString
        self.type = type
        self.entityId = entityId
        self.payload = payload
        self.createdAt = Date()
        self.retryCount = 0
        self.date = date
    }
}

/// Manages offline sync queue and automatic retry
@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published private(set) var isOnline = true
    @Published private(set) var pendingOperationsCount = 0
    @Published private(set) var isSyncing = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var pendingOperations: [PendingOperation] = []
    private let maxRetries = 3
    private let cacheKey = "pendingOperations"

    private let calendarService = CalendarService()
    private let routineService = RoutineService()

    private var syncTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadPendingOperations()
        startNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied

                // If we just came online and have pending operations, sync them
                if wasOffline && path.status == .satisfied {
                    print("📶 Network restored - syncing pending operations")
                    await self?.syncPendingOperations()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Queue Operations

    /// Add an operation to the sync queue
    func queueOperation(_ operation: PendingOperation) {
        // Remove any existing operation for the same entity and type to avoid duplicates
        pendingOperations.removeAll {
            $0.entityId == operation.entityId && $0.type == operation.type
        }

        pendingOperations.append(operation)
        pendingOperationsCount = pendingOperations.count
        savePendingOperations()

        print("📝 Queued operation: \(operation.type.rawValue) for \(operation.entityId)")

        // Try to sync immediately if online
        if isOnline {
            Task {
                await syncPendingOperations()
            }
        }
    }

    /// Execute an operation with automatic queue on failure
    func execute<T>(
        operation: PendingOperation,
        action: @escaping () async throws -> T
    ) async -> Result<T, Error> {
        do {
            let result = try await action()
            print("✅ Operation succeeded: \(operation.type.rawValue)")
            return .success(result)
        } catch {
            print("⚠️ Operation failed, queuing for retry: \(error.localizedDescription)")
            queueOperation(operation)
            return .failure(error)
        }
    }

    // MARK: - Sync Pending Operations

    func syncPendingOperations() async {
        guard isOnline && !isSyncing && !pendingOperations.isEmpty else { return }

        isSyncing = true
        print("🔄 Syncing \(pendingOperations.count) pending operations...")

        var completedOperations: [String] = []
        var failedOperations: [PendingOperation] = []

        for operation in pendingOperations {
            do {
                try await executeOperation(operation)
                completedOperations.append(operation.id)
                print("✅ Synced: \(operation.type.rawValue) for \(operation.entityId)")
            } catch {
                var failedOp = operation
                failedOp.retryCount += 1

                if failedOp.retryCount < maxRetries {
                    failedOperations.append(failedOp)
                    print("⚠️ Retry \(failedOp.retryCount)/\(maxRetries) for \(operation.type.rawValue)")
                } else {
                    print("❌ Max retries reached for \(operation.type.rawValue), dropping operation")
                }
            }
        }

        // Update pending operations
        pendingOperations = failedOperations
        pendingOperationsCount = pendingOperations.count
        savePendingOperations()

        isSyncing = false
        print("🔄 Sync complete. \(completedOperations.count) succeeded, \(failedOperations.count) pending")
    }

    private func executeOperation(_ operation: PendingOperation) async throws {
        switch operation.type {
        case .completeTask:
            _ = try await calendarService.completeTask(id: operation.entityId)

        case .uncompleteTask:
            _ = try await calendarService.uncompleteTask(id: operation.entityId)

        case .completeRitual:
            try await routineService.completeRoutine(id: operation.entityId, date: operation.date)

        case .uncompleteRitual:
            try await routineService.uncompleteRoutine(id: operation.entityId, date: operation.date)

        case .createTask, .updateTask, .deleteTask:
            // These require payload data - implement as needed
            break
        }
    }

    // MARK: - Persistence

    private func savePendingOperations() {
        do {
            let data = try JSONEncoder().encode(pendingOperations)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("❌ Failed to save pending operations: \(error)")
        }
    }

    private func loadPendingOperations() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }

        do {
            pendingOperations = try JSONDecoder().decode([PendingOperation].self, from: data)
            pendingOperationsCount = pendingOperations.count
            print("📂 Loaded \(pendingOperations.count) pending operations from cache")
        } catch {
            print("❌ Failed to load pending operations: \(error)")
        }
    }

    // MARK: - Convenience Methods

    /// Complete a task with optimistic update and retry support
    func completeTask(id: String) async {
        let operation = PendingOperation(type: .completeTask, entityId: id)
        _ = await execute(operation: operation) {
            try await self.calendarService.completeTask(id: id)
        }
    }

    /// Uncomplete a task with optimistic update and retry support
    func uncompleteTask(id: String) async {
        let operation = PendingOperation(type: .uncompleteTask, entityId: id)
        _ = await execute(operation: operation) {
            try await self.calendarService.uncompleteTask(id: id)
        }
    }

    /// Complete a ritual with retry support
    /// - Parameters:
    ///   - id: The ritual/routine ID
    ///   - date: The date to mark as completed (YYYY-MM-DD format), defaults to today
    func completeRitual(id: String, date: String? = nil) async {
        let completionDate = date ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()

        print("🔥 SyncManager.completeRitual called for id: \(id), date: \(completionDate)")
        let operation = PendingOperation(type: .completeRitual, entityId: id, date: completionDate)
        let result = await execute(operation: operation) {
            print("🔥 SyncManager: Executing routineService.completeRoutine...")
            try await self.routineService.completeRoutine(id: id, date: completionDate)
            print("🔥 SyncManager: routineService.completeRoutine returned successfully")
        }
        switch result {
        case .success:
            print("✅ SyncManager.completeRitual: SUCCESS for \(id) on \(completionDate)")
        case .failure(let error):
            print("❌ SyncManager.completeRitual: FAILED for \(id) - \(error.localizedDescription)")
        }
    }

    /// Uncomplete a ritual with retry support
    /// - Parameters:
    ///   - id: The ritual/routine ID
    ///   - date: The date to uncomplete (YYYY-MM-DD format), defaults to most recent
    func uncompleteRitual(id: String, date: String? = nil) async {
        print("🔥 SyncManager.uncompleteRitual called for id: \(id), date: \(date ?? "most recent")")
        let operation = PendingOperation(type: .uncompleteRitual, entityId: id, date: date)
        _ = await execute(operation: operation) {
            try await self.routineService.uncompleteRoutine(id: id, date: date)
        }
    }

    /// Force sync all pending operations
    func forceSync() async {
        await syncPendingOperations()
    }

    /// Clear all pending operations (use with caution)
    func clearPendingOperations() {
        pendingOperations.removeAll()
        pendingOperationsCount = 0
        savePendingOperations()
    }
}
