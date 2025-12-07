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

    var body: some Scene {
        WindowGroup {
            Group {
                if store.isAuthenticated {
                    MainTabView()
                } else {
                    AuthenticationView()
                }
            }
            .environmentObject(store)
            .environmentObject(router)
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                handleDeepLink(url)
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
