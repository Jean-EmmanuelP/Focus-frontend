import Foundation
import Combine
import AuthenticationServices

// MARK: - Google Calendar Config Response
struct GoogleCalendarConfigResponse: Codable {
    let isConnected: Bool
    let isEnabled: Bool
    let syncDirection: String
    let calendarId: String
    let googleEmail: String?
    let lastSyncAt: Date?
}

// MARK: - Save Tokens Request
struct SaveGoogleTokensRequest: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let googleEmail: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "accessToken"
        case refreshToken = "refreshToken"
        case expiresIn = "expiresIn"
        case googleEmail = "googleEmail"
    }
}

// MARK: - Update Config Request
struct UpdateGoogleConfigRequest: Codable {
    let isEnabled: Bool?
    let syncDirection: String?
    let calendarId: String?
}

// MARK: - Sync Result
struct GoogleSyncResult: Codable {
    let tasksSynced: Int
    let eventsImported: Int
    let errors: [String]?
    let lastSyncAt: String
}

// MARK: - Google Calendar Event (from Google API)
struct GoogleCalendarEvent: Codable, Identifiable {
    let id: String
    let summary: String?
    let description: String?
    let start: GoogleEventDateTime?
    let end: GoogleEventDateTime?
    let status: String?

    var title: String {
        summary ?? "Untitled Event"
    }
}

struct GoogleEventDateTime: Codable {
    let dateTime: String?
    let date: String?
    let timeZone: String?
}

struct GoogleEventsListResponse: Codable {
    let items: [GoogleCalendarEvent]?
    let nextPageToken: String?
}

// MARK: - Google Calendar Service
@MainActor
class GoogleCalendarService: ObservableObject {
    static let shared = GoogleCalendarService()

    @Published var config: GoogleCalendarConfigResponse?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isSyncing = false

    // Google OAuth Configuration
    private let clientID = "613349634589-1d8mmjai794ia29pluv97t21mj2349ej.apps.googleusercontent.com"
    private let calendarScope = "https://www.googleapis.com/auth/calendar"

    // Stored tokens (in memory - will use backend for persistence)
    private var accessToken: String?
    private var refreshToken: String?

    private init() {}

    // MARK: - API Methods

    /// Fetch current Google Calendar configuration
    func fetchConfig() async {
        isLoading = true
        error = nil

        do {
            let response: GoogleCalendarConfigResponse = try await APIClient.shared.request(
                endpoint: .googleCalendarConfig,
                method: .get
            )
            self.config = response
        } catch {
            self.error = error.localizedDescription
            // Default config if not found
            self.config = GoogleCalendarConfigResponse(
                isConnected: false,
                isEnabled: false,
                syncDirection: "bidirectional",
                calendarId: "primary",
                googleEmail: nil,
                lastSyncAt: nil
            )
        }

        isLoading = false
    }

    /// Save OAuth tokens after Google Sign-In
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int, email: String) async throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken

        let request = SaveGoogleTokensRequest(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            googleEmail: email
        )

        let response: GoogleCalendarConfigResponse = try await APIClient.shared.request(
            endpoint: .googleCalendarSaveTokens,
            method: .post,
            body: request
        )

        self.config = response
    }

    /// Update sync preferences
    func updateConfig(isEnabled: Bool? = nil, syncDirection: String? = nil, calendarId: String? = nil) async throws {
        let request = UpdateGoogleConfigRequest(
            isEnabled: isEnabled,
            syncDirection: syncDirection,
            calendarId: calendarId
        )

        let response: GoogleCalendarConfigResponse = try await APIClient.shared.request(
            endpoint: .googleCalendarUpdateConfig,
            method: .patch,
            body: request
        )

        self.config = response
    }

    /// Disconnect Google Calendar
    func disconnect() async throws {
        try await APIClient.shared.request(
            endpoint: .googleCalendarDisconnect,
            method: .delete
        )

        self.config = GoogleCalendarConfigResponse(
            isConnected: false,
            isEnabled: false,
            syncDirection: "bidirectional",
            calendarId: "primary",
            googleEmail: nil,
            lastSyncAt: nil
        )

        self.accessToken = nil
        self.refreshToken = nil
    }

    /// Trigger manual sync
    func syncNow() async throws -> GoogleSyncResult {
        isSyncing = true
        defer { isSyncing = false }

        let result: GoogleSyncResult = try await APIClient.shared.request(
            endpoint: .googleCalendarSync,
            method: .post
        )

        // Refresh config to get updated lastSyncAt
        await fetchConfig()

        return result
    }


    // MARK: - Google Calendar API Direct Methods (using stored access token)

    /// Fetch events directly from Google Calendar API
    func fetchGoogleEvents(from startDate: Date, to endDate: Date) async throws -> [GoogleCalendarEvent] {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }

        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startDate)
        let timeMax = formatter.string(from: endDate)

        let calendarId = config?.calendarId ?? "primary"
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=true&orderBy=startTime"

        guard let url = URL(string: urlString) else {
            throw GoogleCalendarError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GoogleCalendarError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.apiError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let eventsResponse = try decoder.decode(GoogleEventsListResponse.self, from: data)

        return eventsResponse.items ?? []
    }

    /// Create event in Google Calendar
    func createGoogleEvent(title: String, description: String?, startDate: Date, endDate: Date) async throws -> String {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }

        let calendarId = config?.calendarId ?? "primary"
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events"

        guard let url = URL(string: urlString) else {
            throw GoogleCalendarError.invalidURL
        }

        let formatter = ISO8601DateFormatter()

        var eventData: [String: Any] = [
            "summary": title,
            "start": ["dateTime": formatter.string(from: startDate), "timeZone": TimeZone.current.identifier],
            "end": ["dateTime": formatter.string(from: endDate), "timeZone": TimeZone.current.identifier]
        ]

        if let desc = description {
            eventData["description"] = desc
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: eventData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.createFailed
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let eventId = json["id"] as? String {
            return eventId
        }

        throw GoogleCalendarError.createFailed
    }

    /// Update event in Google Calendar
    func updateGoogleEvent(eventId: String, title: String, description: String?, startDate: Date, endDate: Date) async throws {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }

        let calendarId = config?.calendarId ?? "primary"
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events/\(eventId)"

        guard let url = URL(string: urlString) else {
            throw GoogleCalendarError.invalidURL
        }

        let formatter = ISO8601DateFormatter()

        var eventData: [String: Any] = [
            "summary": title,
            "start": ["dateTime": formatter.string(from: startDate), "timeZone": TimeZone.current.identifier],
            "end": ["dateTime": formatter.string(from: endDate), "timeZone": TimeZone.current.identifier]
        ]

        if let desc = description {
            eventData["description"] = desc
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: eventData)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.updateFailed
        }
    }

    /// Delete event from Google Calendar
    func deleteGoogleEvent(eventId: String) async throws {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }

        let calendarId = config?.calendarId ?? "primary"
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events/\(eventId)"

        guard let url = URL(string: urlString) else {
            throw GoogleCalendarError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw GoogleCalendarError.deleteFailed
        }
    }

    // MARK: - Helper to set tokens from Google Sign-In
    func setTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

// MARK: - Google Calendar Errors
enum GoogleCalendarError: LocalizedError {
    case notAuthenticated
    case tokenExpired
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case createFailed
    case updateFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Google Calendar"
        case .tokenExpired:
            return "Google token expired. Please reconnect."
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from Google"
        case .apiError(let code):
            return "Google API error: \(code)"
        case .createFailed:
            return "Failed to create event"
        case .updateFailed:
            return "Failed to update event"
        case .deleteFailed:
            return "Failed to delete event"
        }
    }
}
