//
//  WeeklyGoalsViewModel.swift
//  Focus
//
//  ViewModel for Weekly Goals feature (like daily intentions but for the week)
//

import Foundation
import Combine
import WidgetKit

@MainActor
class WeeklyGoalsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentWeekGoals: WeeklyGoal?
    @Published var allWeeklyGoals: [WeeklyGoal] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var needsSetup = false
    @Published var showSetupSheet = false

    // For the creation flow
    @Published var draftGoals: [DraftGoalItem] = []
    @Published var isSaving = false

    // MARK: - Services
    private let service = WeeklyGoalsService()
    private let store = FocusAppStore.shared

    // MARK: - Computed Properties

    var currentWeekStartDate: String {
        WeeklyGoalsService.currentWeekStartDate()
    }

    var hasGoalsThisWeek: Bool {
        currentWeekGoals != nil && !(currentWeekGoals?.items.isEmpty ?? true)
    }

    var completedCount: Int {
        currentWeekGoals?.completedCount ?? 0
    }

    var totalCount: Int {
        currentWeekGoals?.totalCount ?? 0
    }

    var progress: Double {
        currentWeekGoals?.progress ?? 0
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }

    var weekRangeString: String {
        currentWeekGoals?.weekRangeString ?? calculateWeekRange()
    }

    // MARK: - Initialization

    init() {
        resetDraftGoals()
    }

    // MARK: - Public Methods

    /// Load current week's goals
    func loadCurrentWeekGoals() async {
        // Skip if already loading
        guard !isLoading else { return }

        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let response = try await service.fetchCurrent()
            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Check if response has items - empty items means no goals set yet
            if response.items.isEmpty {
                currentWeekGoals = nil
                needsSetup = true
            } else {
                currentWeekGoals = WeeklyGoal(from: response)
                needsSetup = false
            }
            syncWidgetData()
        } catch {
            // Ignore cancellation errors silently
            if Task.isCancelled { return }
            if let apiError = error as? APIError, case .networkError(let underlyingError) = apiError {
                if (underlyingError as? URLError)?.code == .cancelled { return }
            }

            // 404 means no goals set for this week
            if let apiError = error as? APIError {
                switch apiError {
                case .notFound, .serverError(404, _):
                    currentWeekGoals = nil
                    needsSetup = true
                default:
                    self.error = error.localizedDescription
                }
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    /// Check if user needs to set up weekly goals
    func checkNeedsSetup() async {
        do {
            let response = try await service.checkNeedsSetup()
            needsSetup = response.needsSetup
            if needsSetup {
                showSetupSheet = true
            }
        } catch {
            print("Failed to check needs setup: \(error)")
        }
    }

    /// Load all weekly goals history
    func loadAllWeeklyGoals() async {
        isLoading = true

        do {
            let responses = try await service.fetchAll()
            allWeeklyGoals = responses.map { WeeklyGoal(from: $0) }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Toggle completion of a goal item
    func toggleGoalItem(_ item: WeeklyGoalItem) async {
        guard var goals = currentWeekGoals,
              let index = goals.items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        // Optimistic update
        let newCompletedState = !item.isCompleted
        goals.items[index].isCompleted = newCompletedState
        currentWeekGoals = goals
        // Update store immediately for optimistic UI
        store.updateWeeklyGoals(goals)

        do {
            _ = try await service.toggleItem(itemId: item.id, isCompleted: newCompletedState)
            syncWidgetData()
            HapticFeedback.medium()
        } catch {
            // Rollback on error
            goals.items[index].isCompleted = !newCompletedState
            currentWeekGoals = goals
            store.updateWeeklyGoals(goals)
            self.error = error.localizedDescription
        }
    }

    /// Save draft goals to backend
    func saveDraftGoals() async -> Bool {
        isSaving = true
        error = nil

        // Filter out empty goals
        let validGoals = draftGoals.filter { !$0.content.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !validGoals.isEmpty else {
            error = "Ajoute au moins un objectif"
            isSaving = false
            return false
        }

        let items = validGoals.map { draft in
            WeeklyGoalItemInput(
                areaId: draft.areaId,
                content: draft.content
            )
        }

        do {
            let response = try await service.upsert(weekStartDate: currentWeekStartDate, items: items)
            let goals = WeeklyGoal(from: response)
            currentWeekGoals = goals
            needsSetup = false
            syncWidgetData()
            // Update the centralized store so Dashboard card updates
            store.updateWeeklyGoals(goals)
            isSaving = false
            return true
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Delete weekly goals for current week
    func deleteCurrentWeekGoals() async {
        guard currentWeekGoals != nil else { return }

        do {
            try await service.delete(weekStartDate: currentWeekStartDate)
            currentWeekGoals = nil
            needsSetup = true
            syncWidgetData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Draft Goal Management

    func resetDraftGoals() {
        draftGoals = [
            DraftGoalItem(content: ""),
            DraftGoalItem(content: ""),
            DraftGoalItem(content: "")
        ]
    }

    func addDraftGoal() {
        guard draftGoals.count < 5 else { return }
        draftGoals.append(DraftGoalItem(content: ""))
    }

    func removeDraftGoal(at index: Int) {
        guard draftGoals.count > 1 else { return }
        draftGoals.remove(at: index)
    }

    func updateDraftGoal(at index: Int, content: String) {
        guard index < draftGoals.count else { return }
        draftGoals[index].content = content
    }

    func updateDraftGoalArea(at index: Int, areaId: String?) {
        guard index < draftGoals.count else { return }
        draftGoals[index].areaId = areaId
    }

    // MARK: - Private Helpers

    private func calculateWeekRange() -> String {
        let today = Date()
        let calendar = Calendar.current
        var weekday = calendar.component(.weekday, from: today)
        if weekday == 1 { weekday = 8 }
        let daysToMonday = weekday - 2
        let monday = calendar.date(byAdding: .day, value: -daysToMonday, to: today)!
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: monday)) - \(formatter.string(from: sunday))"
    }

    private func syncWidgetData() {
        let defaults = UserDefaults(suiteName: "group.com.jep.volta")

        if let goals = currentWeekGoals {
            // Get areas for emoji lookup
            let areas = store.areas

            let widgetData = WeeklyGoalsWidgetData(
                items: goals.items.map { item in
                    // Find area emoji if available
                    let areaEmoji = item.areaId.flatMap { areaId in
                        areas.first { $0.id == areaId }?.icon
                    } ?? "🎯"

                    return WeeklyGoalsWidgetItem(
                        id: item.id,
                        areaEmoji: areaEmoji,
                        content: item.content,
                        isCompleted: item.isCompleted
                    )
                },
                weekRange: goals.weekRangeString,
                completedCount: goals.completedCount,
                totalCount: goals.totalCount
            )

            if let encoded = try? JSONEncoder().encode(widgetData) {
                defaults?.set(encoded, forKey: "weeklyGoalsData")
            }
        } else {
            defaults?.removeObject(forKey: "weeklyGoalsData")
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyGoalsWidget")
    }
}

// MARK: - Widget Data Models (shared with widget)
struct WeeklyGoalsWidgetData: Codable {
    let items: [WeeklyGoalsWidgetItem]
    let weekRange: String
    let completedCount: Int
    let totalCount: Int
}

struct WeeklyGoalsWidgetItem: Codable {
    let id: String
    let areaEmoji: String
    let content: String
    let isCompleted: Bool
}
