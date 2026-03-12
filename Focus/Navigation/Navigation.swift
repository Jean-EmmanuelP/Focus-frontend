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
    case startTheDay
    case focusSession
    case manageRituals
    case weeklyGoals
    case settings
    case notificationSettings
    case appBlockerSettings
}

// MARK: - App Router (Navigation State)
@MainActor
class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: AppTab = .chat
    @Published var showStartTheDay = false
    @Published var showFireModeSession = false  // Shows FireModeView as fullscreen modal
    @Published var showSettings = false
    @Published var showOnboarding = false  // For Ralph design verification
    @Published var showPaywall = false  // For Ralph design verification
    @Published var showLandingPage = false  // For Ralph design verification

    // FireMode pre-configured session parameters
    @Published var fireModePresetDuration: Int?
    @Published var fireModePresetDescription: String?
    @Published var fireModePresetTaskId: String?  // Task ID from calendar for post-session validation
    @Published var fireModePresetRitualId: String?  // Ritual ID from calendar for post-session validation

    // Calendar navigation target date
    @Published var calendarTargetDate: Date?

    private init() {}

    func navigateToFireMode(duration: Int? = nil, description: String? = nil, taskId: String? = nil, ritualId: String? = nil) {
        // Set preset values if provided
        fireModePresetDuration = duration
        fireModePresetDescription = description
        fireModePresetTaskId = taskId
        fireModePresetRitualId = ritualId
        // Show FireModeView as fullscreen modal
        showFireModeSession = true
    }

    func dismissFireMode() {
        showFireModeSession = false
        clearFireModePresets()
    }

    func clearFireModePresets() {
        fireModePresetDuration = nil
        fireModePresetDescription = nil
        fireModePresetTaskId = nil
        fireModePresetRitualId = nil
    }

    // Calendar tab removed - calendar accessible via chat
    func navigateToCalendar(date: Date? = nil) {
        calendarTargetDate = date
        selectedTab = .chat
    }

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
        showStartTheDay = false
        showSettings = false
        showOnboarding = false
        showPaywall = false
        showLandingPage = false
    }

    func navigate(to destination: NavigationDestination) {
        selectedTab = .chat
    }

    func navigateToWeeklyGoals() {
        navigate(to: .weeklyGoals)
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
        .overlay {
            if router.showFireModeSession {
                FireModeView()
                    .environmentObject(router)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: router.showFireModeSession)
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .startTheDay:
            PlanYourDayView()
        case .focusSession:
            FireModeView()
        case .manageRituals:
            ManageRitualsView()
        case .weeklyGoals:
            WeeklyGoalsView()
        case .settings:
            SettingsView(onDismiss: {})
        case .notificationSettings:
            SettingsView(onDismiss: {})
        case .appBlockerSettings:
            SettingsView(onDismiss: {})
        }
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(FocusAppStore.shared)
}
