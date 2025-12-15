import SwiftUI
import Combine

// MARK: - App Navigation
enum AppTab: Int, CaseIterable {
    case dashboard = 0
    case calendar = 1
    case crew = 2

    var title: String {
        switch self {
        case .dashboard: return "tab.dashboard".localized
        case .calendar: return "tab.calendar".localized
        case .crew: return "tab.crew".localized
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .calendar: return "calendar"
        case .crew: return "person.3.fill"
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

    @Published var selectedTab: AppTab = .dashboard
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

    func navigateToStartTheDay() {
        showStartTheDay = true
    }

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
        selectedTab = .dashboard
        dashboardScrollTarget = section
    }

    func navigateToCalendar(date: Date? = nil) {
        calendarTargetDate = date
        selectedTab = .calendar
    }

    func dismissSheets() {
        showStartTheDay = false
        showEndOfDay = false
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @StateObject private var router = AppRouter.shared
    @EnvironmentObject var store: FocusAppStore
    @State private var showOnboardingTutorial = false

    var body: some View {
        TabView(selection: $router.selectedTab) {
            // Dashboard
            NavigationStack(path: $router.dashboardPath) {
                DashboardView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.icon)
            }
            .tag(AppTab.dashboard)

            // Calendar
            NavigationStack {
                WeekCalendarView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(AppTab.calendar.title, systemImage: AppTab.calendar.icon)
            }
            .tag(AppTab.calendar)

            // Crew
            NavigationStack {
                CrewView()
            }
            .tabItem {
                Label(AppTab.crew.title, systemImage: AppTab.crew.icon)
            }
            .tag(AppTab.crew)
        }
        .accentColor(ColorTokens.primaryStart)
        .fullScreenCover(isPresented: $router.showStartTheDay) {
            StartTheDayVoiceView()
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
            StartTheDayVoiceView()
        case .endOfDay:
            EndOfDayView()
        case .focusSession:
            FocusSessionView()
        case .questDetail(let quest):
            QuestDetailView(quest: quest)
        case .manageRituals:
            ManageRitualsView()
        }
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(FocusAppStore.shared)
}
