import Foundation
import Combine
import FirebaseMessaging
import FirebaseAnalytics
import UserNotifications

// MARK: - Push Notification Service

@MainActor
class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()

    private let apiClient = APIClient.shared

    @Published var fcmToken: String?
    @Published var isRegistered: Bool = false

    private init() {}

    // MARK: - FCM Token Management

    /// Register FCM token with backend
    func registerFCMToken(_ token: String) async {
        self.fcmToken = token

        // Only send to backend if user is authenticated
        guard FocusAppStore.shared.isAuthenticated else {
            print("⏳ FCM token saved locally, will register when authenticated")
            return
        }

        do {
            let request = FCMTokenRequest(fcmToken: token, platform: "ios")
            let _: EmptyResponse = try await apiClient.request(
                endpoint: .registerFCMToken,
                method: .post,
                body: request
            )
            self.isRegistered = true
            print("✅ FCM token registered with backend")
        } catch {
            print("❌ Failed to register FCM token: \(error)")
        }
    }

    /// Re-register token after user login
    func registerTokenAfterLogin() async {
        // Try to get current token
        do {
            let token = try await Messaging.messaging().token()
            await registerFCMToken(token)
        } catch {
            print("❌ Failed to get FCM token: \(error)")
        }
    }

    /// Unregister token on logout
    func unregisterToken() async {
        guard let token = fcmToken else { return }

        do {
            let request = FCMTokenRequest(fcmToken: token, platform: "ios")
            let _: EmptyResponse = try await apiClient.request(
                endpoint: .unregisterFCMToken,
                method: .post,
                body: request
            )
            self.isRegistered = false
            print("✅ FCM token unregistered from backend")
        } catch {
            print("❌ Failed to unregister FCM token: \(error)")
        }
    }

    // MARK: - Notification Tracking

    /// Track when a notification is opened
    func trackNotificationOpened(notificationId: String) async {
        guard notificationId != "unknown" else { return }

        do {
            let request = NotificationTrackingRequest(
                notificationId: notificationId,
                event: "opened"
            )
            let _: EmptyResponse = try await apiClient.request(
                endpoint: .trackNotification,
                method: .post,
                body: request
            )
            print("✅ Notification open tracked: \(notificationId)")
        } catch {
            print("❌ Failed to track notification open: \(error)")
        }
    }

    /// Track when user converts (takes action from notification)
    func trackNotificationConverted(notificationId: String, action: String) async {
        guard notificationId != "unknown" else { return }

        // Log to Firebase Analytics
        Analytics.logEvent("notification_converted", parameters: [
            "notification_id": notificationId,
            "action": action
        ])

        do {
            let request = NotificationTrackingRequest(
                notificationId: notificationId,
                event: "converted",
                action: action
            )
            let _: EmptyResponse = try await apiClient.request(
                endpoint: .trackNotification,
                method: .post,
                body: request
            )
            print("✅ Notification conversion tracked: \(notificationId)")
        } catch {
            print("❌ Failed to track notification conversion: \(error)")
        }
    }

    // MARK: - Permission Request

    /// Request notification permissions and register for remote notifications
    func requestPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                // Register for remote notifications on main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("✅ Notification permissions granted")
            }

            return granted
        } catch {
            print("❌ Failed to request notification permissions: \(error)")
            return false
        }
    }

    // MARK: - Topic Subscription

    /// Subscribe to a topic for targeted notifications
    func subscribeToTopic(_ topic: String) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("❌ Failed to subscribe to topic \(topic): \(error)")
            } else {
                print("✅ Subscribed to topic: \(topic)")
            }
        }
    }

    /// Unsubscribe from a topic
    func unsubscribeFromTopic(_ topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            if let error = error {
                print("❌ Failed to unsubscribe from topic \(topic): \(error)")
            } else {
                print("✅ Unsubscribed from topic: \(topic)")
            }
        }
    }
}

// MARK: - Request/Response Models

struct FCMTokenRequest: Codable {
    let fcmToken: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case fcmToken = "fcm_token"
        case platform
    }
}

struct NotificationTrackingRequest: Codable {
    let notificationId: String
    let event: String // "opened", "converted"
    var action: String?

    enum CodingKeys: String, CodingKey {
        case notificationId = "notification_id"
        case event
        case action
    }
}

// Note: EmptyResponse is defined in APIClient.swift
