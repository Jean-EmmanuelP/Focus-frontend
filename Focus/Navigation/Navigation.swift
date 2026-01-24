import SwiftUI
import Combine

// MARK: - App Navigation
// Simplified: Chat is the main (and only) tab - Profile accessible from chat header
enum AppTab: Int, CaseIterable {
    case chat = 0        // Main screen - talk to Kai

    // Define which tabs are currently active
    static var activeCases: [AppTab] {
        [.chat]
    }

    var title: String {
        switch self {
        case .chat: return "Kai"
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
    case endOfDay
    case focusSession
    case questDetail(Quest)
    case manageRituals
    case weeklyGoals
}

// MARK: - App Router (Navigation State)
// MARK: - Dashboard Scroll Sections
enum DashboardSection: String, CaseIterable {
    case intentions = "intentions"
    case rituals = "rituals"
    case reflection = "reflection"
    case sessions = "sessions"
}

@MainActor
class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: AppTab = .chat
    @Published var dashboardPath = NavigationPath()
    @Published var showStartTheDay = false
    @Published var showEndOfDay = false
    @Published var showFireModeSession = false  // Shows FireModeView as fullscreen modal

    // FireMode pre-configured session parameters
    @Published var fireModePresetDuration: Int?
    @Published var fireModePresetQuestId: String?
    @Published var fireModePresetDescription: String?
    @Published var fireModePresetTaskId: String?  // Task ID from calendar for post-session validation
    @Published var fireModePresetRitualId: String?  // Ritual ID from calendar for post-session validation

    // Dashboard scroll target
    @Published var dashboardScrollTarget: DashboardSection?

    // Calendar navigation target date
    @Published var calendarTargetDate: Date?

    private init() {}

    // REMOVED: Manual planning - now via chat
    // func navigateToStartTheDay() {
    //     showStartTheDay = true
    // }

    func navigateToEndOfDay() {
        showEndOfDay = true
    }

    func navigateToFireMode(duration: Int? = nil, questId: String? = nil, description: String? = nil, taskId: String? = nil, ritualId: String? = nil) {
        // Set preset values if provided
        fireModePresetDuration = duration
        fireModePresetQuestId = questId
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
        fireModePresetQuestId = nil
        fireModePresetDescription = nil
        fireModePresetTaskId = nil
        fireModePresetRitualId = nil
    }

    func navigateToDashboard(scrollTo section: DashboardSection? = nil) {
        selectedTab = .chat
        dashboardScrollTarget = section
    }

    // Calendar tab removed - calendar accessible via chat
    func navigateToCalendar(date: Date? = nil) {
        calendarTargetDate = date
        selectedTab = .chat
    }

    func dismissSheets() {
        showStartTheDay = false
        showEndOfDay = false
    }

    func navigate(to destination: NavigationDestination) {
        selectedTab = .chat
        dashboardPath.append(destination)
    }

    func navigateToWeeklyGoals() {
        navigate(to: .weeklyGoals)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @StateObject private var router = AppRouter.shared
    @EnvironmentObject var store: FocusAppStore
    @State private var showOnboardingTutorial = false

    var body: some View {
        ZStack {
            // Simplified: Chat is the only view (no tabs)
            ChatView()
                .environmentObject(FocusAppStore.shared)
                .environmentObject(router)
        }
        .sheet(isPresented: $router.showEndOfDay) {
            NavigationStack {
                EndOfDayView()
            }
        }
        .fullScreenCover(isPresented: $router.showFireModeSession, onDismiss: {
            router.clearFireModePresets()
        }) {
            FireModeView()
                .environmentObject(router)
        }
        .environmentObject(router)
        .overlay {
            if showOnboardingTutorial {
                OnboardingTutorialModal(isPresented: $showOnboardingTutorial)
            }
        }
        .onAppear {
            // Show onboarding tutorial on first launch
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboardingTutorial") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showOnboardingTutorial = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .startTheDay:
            PlanYourDayView()
        case .endOfDay:
            EndOfDayView()
        case .focusSession:
            FocusSessionView()
        case .questDetail(let quest):
            QuestDetailView(quest: quest)
        case .manageRituals:
            ManageRitualsView()
        case .weeklyGoals:
            WeeklyGoalsView()
        }
    }
}

// MARK: - Floating Tab Bar (Disabled - Chat-only interface)
// Tab bar removed for minimalist chat experience
// Profile accessible from chat header

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(FocusAppStore.shared)
}
