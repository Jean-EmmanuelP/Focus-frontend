import SwiftUI
import Combine

// MARK: - App Navigation
// Simplified: Chat is the main (and only) tab - Profile accessible from chat header
enum AppTab: Int, CaseIterable {
    case chat = 0        // Main screen - talk to companion

    // Define which tabs are currently active
    static var activeCases: [AppTab] {
        [.chat]
    }

    var title: String {
        switch self {
        case .chat: return "Chat"  // Not displayed - companion name fetched from store
        }
    }

    var icon: String {
        switch self {
        case .chat: return "message.fill"
        }
    }
}

// MARK: - Navigation Destination
enum NavigationDestination: Hashable {
    case settings
    case notificationSettings
    case appBlockerSettings
}

// MARK: - App Router (Navigation State)
@MainActor
class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: AppTab = .chat
    @Published var showSettings = false
    @Published var showOnboarding = false  // For Ralph design verification
    @Published var showPaywall = false  // For Ralph design verification
    @Published var showLandingPage = false  // For Ralph design verification

    private init() {}

    func navigateToSettings() {
        showSettings = true
    }

    func navigateToOnboarding() {
        showOnboarding = true
    }

    func navigateToPaywall() {
        showPaywall = true
    }

    func dismissSheets() {
        showSettings = false
        showOnboarding = false
        showPaywall = false
        showLandingPage = false
    }

    func navigate(to destination: NavigationDestination) {
        selectedTab = .chat
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @StateObject private var router = AppRouter.shared
    @EnvironmentObject var store: FocusAppStore

    var body: some View {
        ZStack {
            // Simplified: Chat is the only view (no tabs)
            ChatView()
                .environmentObject(FocusAppStore.shared)
                .environmentObject(router)
        }
        .sheet(isPresented: $router.showPaywall) {
            VoltaPaywallView()
                .environmentObject(SubscriptionManager.shared)
        }
        .environmentObject(router)
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(FocusAppStore.shared)
}
