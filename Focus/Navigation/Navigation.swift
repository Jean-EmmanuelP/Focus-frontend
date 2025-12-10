import SwiftUI
import Combine

// MARK: - App Navigation
enum AppTab: Int, CaseIterable {
    case dashboard = 0
    case calendar = 1
    case quests = 2
    case crew = 3

    var title: String {
        switch self {
        case .dashboard: return "tab.dashboard".localized
        case .calendar: return "tab.calendar".localized
        case .quests: return "tab.quests".localized
        case .crew: return "tab.crew".localized
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .calendar: return "calendar"
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
    @Published var showFireModeSession = false  // Shows FireModeView as fullscreen modal

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
    @State private var showFireModeModal = false

    var body: some View {
        ZStack(alignment: .bottom) {
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

            // Start Focus button above tab bar
            VStack(spacing: 0) {
                Spacer()
                Button(action: {
                    HapticFeedback.selection()
                    Task {
                        await FocusAppStore.shared.loadQuestsIfNeeded()
                    }
                    showFireModeModal = true
                }) {
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Start Focus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                ColorTokens.primaryStart.opacity(0.9),
                                ColorTokens.primaryEnd.opacity(0.7),
                                Color.clear.opacity(0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .background(Color(white: 0.12))
                    .cornerRadius(RadiusTokens.xl)
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.bottom, 85) // Above tab bar
            }
        }
        .fullScreenCover(isPresented: $router.showStartTheDay) {
            VoiceAssistantView()
        }
        .sheet(isPresented: $router.showEndOfDay) {
            NavigationStack {
                EndOfDayView()
            }
        }
        .sheet(isPresented: $showFireModeModal, onDismiss: {
            // Clear presets when modal is dismissed (only if not starting a session)
            if !router.showFireModeSession {
                router.fireModePresetDuration = nil
                router.fireModePresetDescription = nil
            }
        }) {
            StartFireModeSheet(
                quests: store.quests,
                onStart: { duration, questId, description in
                    showFireModeModal = false
                    // Navigate to FireMode with selected parameters (shows fullscreen modal)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        router.navigateToFireMode(duration: duration, questId: questId, description: description)
                    }
                },
                presetDuration: router.fireModePresetDuration,
                presetDescription: router.fireModePresetDescription
            )
        }
        .fullScreenCover(isPresented: $router.showFireModeSession, onDismiss: {
            router.clearFireModePresets()
        }) {
            FireModeView()
                .environmentObject(router)
        }
        .environmentObject(router)
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .startTheDay:
            VoiceAssistantView()
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
