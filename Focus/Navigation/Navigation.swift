import SwiftUI
import Combine

// MARK: - App Navigation
enum AppTab: Int, CaseIterable {
    case dashboard = 0
    case fireMode = 1
    case quests = 2
    case crew = 3

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .fireMode: return "FireMode"
        case .quests: return "Quests"
        case .crew: return "Crew"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .fireMode: return "flame.fill"
        case .quests: return "target"
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

    // FireMode pre-configured session parameters
    @Published var fireModePresetDuration: Int?
    @Published var fireModePresetQuestId: String?
    @Published var fireModePresetDescription: String?

    // Dashboard scroll target
    @Published var dashboardScrollTarget: DashboardSection?

    private init() {}

    func navigateToStartTheDay() {
        showStartTheDay = true
    }

    func navigateToEndOfDay() {
        showEndOfDay = true
    }

    func navigateToFireMode(duration: Int? = nil, questId: String? = nil, description: String? = nil) {
        // Set preset values if provided
        fireModePresetDuration = duration
        fireModePresetQuestId = questId
        fireModePresetDescription = description
        selectedTab = .fireMode
    }

    func clearFireModePresets() {
        fireModePresetDuration = nil
        fireModePresetQuestId = nil
        fireModePresetDescription = nil
    }

    func navigateToQuests() {
        selectedTab = .quests
    }

    func navigateToDashboard(scrollTo section: DashboardSection? = nil) {
        selectedTab = .dashboard
        dashboardScrollTarget = section
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

            // FireMode
            NavigationStack {
                FireModeView()
            }
            .tabItem {
                Label(AppTab.fireMode.title, systemImage: AppTab.fireMode.icon)
            }
            .tag(AppTab.fireMode)

            // Quests
            NavigationStack {
                QuestsView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(AppTab.quests.title, systemImage: AppTab.quests.icon)
            }
            .tag(AppTab.quests)

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
        .sheet(isPresented: $router.showStartTheDay) {
            NavigationStack {
                StartTheDayView()
            }
        }
        .sheet(isPresented: $router.showEndOfDay) {
            NavigationStack {
                EndOfDayView()
            }
        }
        .environmentObject(router)
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .startTheDay:
            StartTheDayView()
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
