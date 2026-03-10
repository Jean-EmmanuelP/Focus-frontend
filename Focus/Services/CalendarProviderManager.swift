import Foundation
import Combine

// MARK: - External Calendar Event Model

struct ExternalCalendarEvent: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let location: String?
    let startAt: String
    let endAt: String
    let isAllDay: Bool
    let eventType: String
    let eventStatus: String
    let blockApps: Bool
    let isBusy: Bool
    let providerType: String
    let providerEmail: String?

    var startDate: Date? {
        ISO8601DateFormatter().date(from: startAt)
    }

    var endDate: Date? {
        ISO8601DateFormatter().date(from: endAt)
    }
}

// MARK: - Calendar Events Response

struct CalendarEventsResponse: Codable {
    let events: [ExternalCalendarEvent]
    let count: Int
    let date: String
    let cacheStale: Bool
}

// MARK: - Calendar Provider Model

struct CalendarProviderInfo: Codable, Identifiable {
    let id: String
    let providerType: String
    let providerEmail: String?
    let isConnected: Bool
    let isActive: Bool
    let syncDirection: String
    let lastSyncAt: String?
    let lastSyncStatus: String
}

struct CalendarProvidersResponse: Codable {
    let providers: [CalendarProviderInfo]
    let count: Int
}

// MARK: - Blocking Schedule

struct BlockingWindowResponse: Codable {
    let id: String
    let title: String
    let source: String
    let startAt: String
    let endAt: String
    let blockApps: Bool
}

struct BlockingScheduleResponse: Codable {
    let windows: [BlockingWindowResponse]
    let count: Int
    let date: String
}

// MARK: - Calendar Provider Manager

@MainActor
final class CalendarProviderManager: ObservableObject {
    static let shared = CalendarProviderManager()

    @Published var providers: [CalendarProviderInfo] = []
    @Published var todayEvents: [ExternalCalendarEvent] = []
    @Published var isLoading = false
    @Published var hasCalendarConnected = false

    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 15 * 60 // 15 minutes

    private init() {}

    // MARK: - Fetch Providers

    func fetchProviders() async {
        do {
            let response: CalendarProvidersResponse = try await APIClient.shared.request(
                endpoint: .calendarProviders,
                method: .get
            )
            self.providers = response.providers
            self.hasCalendarConnected = response.providers.contains { $0.isConnected && $0.isActive }
        } catch {
            print("[CalendarProviderManager] Failed to fetch providers: \(error)")
        }
    }

    // MARK: - Fetch Events

    func fetchEvents(for date: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        let dateStr = date ?? todayString()

        do {
            let response: CalendarEventsResponse = try await APIClient.shared.request(
                endpoint: .calendarEvents(date: dateStr),
                method: .get
            )
            // Only update todayEvents if fetching for today
            if dateStr == todayString() {
                self.todayEvents = response.events
                self.lastFetchTime = Date()
            }

            // If cache is stale, trigger a sync
            if response.cacheStale && hasCalendarConnected {
                await syncEvents()
            }
        } catch {
            print("[CalendarProviderManager] Failed to fetch events: \(error)")
        }
    }

    // MARK: - Sync Events (force refresh from Google)

    func syncEvents() async {
        do {
            let _: GoogleSyncResult = try await APIClient.shared.request(
                endpoint: .googleCalendarSync,
                method: .post
            )
            // Refetch cached events after sync
            await fetchEvents()
        } catch {
            print("[CalendarProviderManager] Sync failed: \(error)")
        }
    }

    // MARK: - Toggle Blocking

    func toggleBlocking(eventId: String, enabled: Bool, source: String = "manual") async -> Bool {
        struct UpdateBody: Encodable {
            let blockApps: Bool
            let source: String

            enum CodingKeys: String, CodingKey {
                case blockApps = "block_apps"
                case source
            }
        }

        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                endpoint: .calendarEventBlocking(id: eventId),
                method: .patch,
                body: UpdateBody(blockApps: enabled, source: source)
            )

            // Update local state
            if let index = todayEvents.firstIndex(where: { $0.id == eventId }) {
                // We need to create a new event since structs are value types
                let old = todayEvents[index]
                let updated = ExternalCalendarEvent(
                    id: old.id, title: old.title, description: old.description,
                    location: old.location, startAt: old.startAt, endAt: old.endAt,
                    isAllDay: old.isAllDay, eventType: old.eventType,
                    eventStatus: old.eventStatus, blockApps: enabled,
                    isBusy: old.isBusy, providerType: old.providerType,
                    providerEmail: old.providerEmail
                )
                todayEvents[index] = updated
            }
            return true
        } catch {
            print("[CalendarProviderManager] Toggle blocking failed: \(error)")
            return false
        }
    }

    // MARK: - Refresh if needed

    func refreshIfNeeded() async {
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < cacheDuration {
            return
        }
        await fetchProviders()
        if hasCalendarConnected {
            await fetchEvents()
        }
    }

    // MARK: - Helpers

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// EmptyResponse is already defined elsewhere, but ensure it exists
// struct EmptyResponse: Codable {}
