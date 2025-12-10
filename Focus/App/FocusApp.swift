//
//  FocusApp.swift
//  Focus
//
//  Created by Jean-Emmanuel on 04/12/2025.
//

import SwiftUI

@main
struct FocusApp: App {
    @StateObject private var store = FocusAppStore.shared
    @StateObject private var router = AppRouter.shared
    @State private var appState: AppLaunchState = .splash

    enum AppLaunchState {
        case splash
        case welcome
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
                                appState = .welcome
                            }
                        }

                    case .welcome:
                        WelcomeLoadingView {
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
                        } else if !store.isAuthenticated {
                            // Not authenticated: show onboarding (starts at sign in)
                            OnboardingView()
                                .transition(.opacity)
                        } else {
                            // Authenticated but hasn't completed onboarding: show onboarding
                            OnboardingView()
                                .transition(.opacity)
                        }
                    }
                }
            }
            .environmentObject(store)
            .environmentObject(router)
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.3), value: store.hasCompletedOnboarding)
            .animation(.easeInOut(duration: 0.3), value: store.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: store.isCheckingOnboarding)
            .onOpenURL { url in
                handleDeepLink(url)
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
    /// - focus://dashboard/rituals
    /// - focus://dashboard/intentions
    /// - focus://dashboard/sessions
    /// - focus://quests
    /// - focus://starttheday
    /// - focus://endofday
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "focus" else { return }

        let path = url.pathComponents.filter { $0 != "/" }

        switch url.host {
        case "firemode":
            router.navigateToFireMode()

        case "dashboard":
            // Check for section path: focus://dashboard/rituals
            if let sectionName = path.first,
               let section = DashboardSection(rawValue: sectionName) {
                router.navigateToDashboard(scrollTo: section)
            } else {
                router.navigateToDashboard()
            }

        case "quests":
            router.navigateToQuests()

        case "starttheday":
            router.navigateToStartTheDay()

        case "endofday":
            router.navigateToEndOfDay()

        default:
            break
        }
    }
}
