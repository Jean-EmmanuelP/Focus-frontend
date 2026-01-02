import SwiftUI
import Combine

// MARK: - App Navigation
enum AppTab: Int, CaseIterable {
    case dashboard = 0
    case calendar = 1
    // case community = 2  // COMMENTED OUT - Feed disabled for now
    case crew = 3
    case profile = 4

    // Define which tabs are currently active (excluding community)
    static var activeCases: [AppTab] {
        [.dashboard, .calendar, .crew, .profile]
    }

    var title: String {
        switch self {
        case .dashboard: return "tab.dashboard".localized
        case .calendar: return "tab.calendar".localized
        // case .community: return "tab.community".localized
        case .crew: return "tab.crew".localized
        case .profile: return "tab.profile".localized
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "flame.fill"
        case .calendar: return "calendar"
        // case .community: return "photo.stack"
        case .crew: return "person.3.fill"
        case .profile: return "person.circle.fill"
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

    func navigate(to destination: NavigationDestination) {
        selectedTab = .dashboard
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
        ZStack(alignment: .bottom) {
            // Content based on selected tab
            Group {
                switch router.selectedTab {
                case .dashboard:
                    NavigationStack(path: $router.dashboardPath) {
                        DashboardView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                case .calendar:
                    NavigationStack {
                        WeekCalendarView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                // COMMENTED OUT - Community feed disabled for now
                // case .community:
                //     NavigationStack {
                //         CommunityView()
                //     }
                case .crew:
                    NavigationStack {
                        CrewView()
                    }
                case .profile:
                    NavigationStack {
                        ProfileView()
                    }
                }
            }

            // Custom floating tab bar (Opal style)
            FloatingTabBar(selectedTab: $router.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $router.showStartTheDay) {
            PlanYourDayView()
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

// MARK: - Floating Tab Bar (Opal Style)
struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            // Only show active tabs (excluding community for now)
            ForEach(AppTab.activeCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    HapticFeedback.light()
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            ColorTokens.background
        )
        .padding(.bottom, -10)
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(FocusAppStore.shared)
}
