//
//  FocusApp.swift
//  Focus
//
//  Created by Jean-Emmanuel on 04/12/2025.
//

import SwiftUI
import GoogleSignIn
import RevenueCat
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import FirebaseAnalytics

@main
struct FocusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = FocusAppStore.shared
    @StateObject private var router = AppRouter.shared
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @StateObject private var updateService = AppUpdateService.shared
    @State private var appState: AppLaunchState = .splash
    @State private var showUpdateSheet = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Configure RevenueCat on app launch
        RevenueCatManager.shared.configure()
    }

    enum AppLaunchState {
        case splash
        case ready
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main content
                Group {
                    switch appState {
                    case .splash:
                        SplashView {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                appState = .ready
                            }
                        }

                    case .ready:
                        // Debug: log state changes
                        let _ = print("📱 FocusApp ready state: isAuth=\(store.isAuthenticated), hasCompleted=\(store.hasCompletedOnboarding), isChecking=\(store.isCheckingOnboarding)")

                        if store.isAuthenticated && store.hasCompletedOnboarding {
                            // User is authenticated AND has completed onboarding
                            MainTabView()
                                .transition(.opacity)
                        } else if store.isAuthenticated && store.isCheckingOnboarding {
                            // Checking onboarding status
                            loadingView
                                .transition(.opacity)
                        } else if store.isAuthenticated {
                            // Authenticated but checking/completing onboarding - show main app
                            // (onboarding is now disabled, handled by backend)
                            MainTabView()
                                .transition(.opacity)
                        } else {
                            // Not authenticated: show chat directly (Perplexity-style)
                            // Login modal will appear when user tries to send first message
                            ChatOnboardingView()
                                .transition(.opacity)
                        }
                    }
                }
            }
            .environmentObject(store)
            .environmentObject(router)
            .environmentObject(revenueCatManager)
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.3), value: store.hasCompletedOnboarding)
            .animation(.easeInOut(duration: 0.3), value: store.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: store.isCheckingOnboarding)
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .task {
                // Check for app updates on launch
                await updateService.checkForUpdate()
                if updateService.updateAvailable {
                    showUpdateSheet = true
                }
            }
            .sheet(isPresented: $showUpdateSheet) {
                UpdateAvailableSheet(updateService: updateService)
                    .presentationDetents([.medium])
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active && store.isAuthenticated {
                    // Refresh morning notifications with new phrases when app becomes active
                    Task {
                        await NotificationService.shared.scheduleMorningNotification()
                    }
                }
            }
            // Note: Onboarding status is checked in FocusAppStore.handleAuthServiceUpdate()
        }
    }

    private var loadingView: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                    .scaleEffect(1.2)

                Text("Chargement...")
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
            }
        }
    }

    /// Handle deep links from widgets and notifications
    /// Supported URLs:
    /// - focus://firemode
    /// - focus://dashboard
    /// - focus://starttheday
    /// - focus://endofday
    /// - focus://referral?code=XXXX
    /// - https://focus.app/r/XXXX (Universal Link)
    private func handleDeepLink(_ url: URL) {
        // Handle Google Sign-In callback
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }

        // Handle Universal Links (https://focus.app/r/CODE)
        if url.scheme == "https" && url.host == "focus.app" {
            handleUniversalLink(url)
            return
        }

        guard url.scheme == "focus" else { return }

        switch url.host {
        case "firemode":
            router.navigateToFireMode()

        case "dashboard":
            // Dashboard is now chat
            router.selectedTab = .chat

        case "starttheday":
            // Redirect to chat - planning is now done via Kai
            router.selectedTab = .chat

        case "endofday":
            router.navigateToEndOfDay()

        case "calendar":
            router.navigateToCalendar()

        case "weekly-goals":
            router.navigateToWeeklyGoals()

        case "referral":
            // Extract code from query parameters
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                handleReferralCode(code)
            }

        default:
            break
        }
    }

    /// Handle Universal Links (https://focus.app/r/CODE)
    private func handleUniversalLink(_ url: URL) {
        let pathComponents = url.pathComponents
        // Expected: /r/CODE -> ["", "r", "CODE"]
        if pathComponents.count >= 3 && pathComponents[1] == "r" {
            let code = pathComponents[2]
            handleReferralCode(code)
        }
    }

    /// Handle referral code from deep link
    private func handleReferralCode(_ code: String) {
        print("📝 Received referral code from deep link: \(code)")

        // Store the code for later (will be applied after signup/login)
        ReferralService.shared.storePendingCode(code)

        // If user is already logged in, try to apply it now
        if store.isAuthenticated {
            Task {
                let result = await ReferralService.shared.applyCode(code)
                if result.success {
                    print("✅ Referral code applied: \(result.message)")
                } else {
                    print("⚠️ Referral code not applied: \(result.message)")
                }
            }
        }
    }
}

// MARK: - App Delegate for Notifications & Firebase

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Set up Firebase Messaging delegate
        Messaging.messaging().delegate = self

        // Register for remote notifications
        application.registerForRemoteNotifications()

        // Log app open event for analytics
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)

        return true
    }

    // MARK: - APNs Token Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to Firebase
        Messaging.messaging().apnsToken = deviceToken
        print("📱 APNs token registered")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }

    // MARK: - Firebase Messaging Delegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("🔥 FCM Token: \(token)")

        // Send token to backend
        Task {
            await PushNotificationService.shared.registerFCMToken(token)
        }
    }

    // MARK: - Notification Presentation (Foreground)

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo

        // Log notification received event
        Analytics.logEvent("notification_received_foreground", parameters: [
            "notification_id": userInfo["notification_id"] as? String ?? "unknown"
        ])

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Notification Tap Handler

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Log notification opened event
        let notificationId = userInfo["notification_id"] as? String ?? "unknown"
        let notificationType = userInfo["type"] as? String ?? "unknown"

        Analytics.logEvent("notification_opened", parameters: [
            "notification_id": notificationId,
            "notification_type": notificationType
        ])

        // Track in our backend
        Task {
            await PushNotificationService.shared.trackNotificationOpened(notificationId: notificationId)
        }

        // Handle deep link
        if let deepLink = userInfo["deepLink"] as? String,
           let url = URL(string: deepLink) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }

        completionHandler()
    }

    // MARK: - Handle Remote Notification (Background/Terminated)

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle silent push or data-only notification
        print("📬 Received remote notification: \(userInfo)")

        completionHandler(.newData)
    }
}
