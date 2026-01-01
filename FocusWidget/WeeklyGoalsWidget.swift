//
//  WeeklyGoalsWidget.swift
//  FocusWidget
//
//  Widget to display weekly goals on home screen with interactive toggles
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Color Theme (Sky Blue)
extension Color {
    static let widgetAccent = Color(red: 0.35, green: 0.78, blue: 0.98) // #5AC8FA Sky Blue
}

// MARK: - Widget Data Model
struct WeeklyGoalsWidgetData: Codable {
    let items: [WeeklyGoalsWidgetItem]
    let weekRange: String
    let completedCount: Int
    let totalCount: Int
}

struct WeeklyGoalsWidgetItem: Codable, Identifiable {
    let id: String
    let areaEmoji: String
    let content: String
    let isCompleted: Bool
}

// MARK: - App Intent for toggling goals
struct ToggleWeeklyGoalIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Weekly Goal"
    static var description = IntentDescription("Marks a weekly goal as completed or not completed")

    @Parameter(title: "Goal ID")
    var goalId: String

    @Parameter(title: "Is Completed")
    var isCompleted: Bool

    init() {}

    init(goalId: String, isCompleted: Bool) {
        self.goalId = goalId
        self.isCompleted = isCompleted
    }

    func perform() async throws -> some IntentResult {
        // Update the goal in UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta")

        if let data = sharedDefaults?.data(forKey: "weeklyGoalsData"),
           var decoded = try? JSONDecoder().decode(WeeklyGoalsWidgetData.self, from: data) {
            // Find and update the goal
            var updatedItems = decoded.items
            if let index = updatedItems.firstIndex(where: { $0.id == goalId }) {
                updatedItems[index] = WeeklyGoalsWidgetItem(
                    id: updatedItems[index].id,
                    areaEmoji: updatedItems[index].areaEmoji,
                    content: updatedItems[index].content,
                    isCompleted: isCompleted
                )

                // Recalculate counts
                let newCompletedCount = updatedItems.filter { $0.isCompleted }.count

                let updatedData = WeeklyGoalsWidgetData(
                    items: updatedItems,
                    weekRange: decoded.weekRange,
                    completedCount: newCompletedCount,
                    totalCount: decoded.totalCount
                )

                if let encoded = try? JSONEncoder().encode(updatedData) {
                    sharedDefaults?.set(encoded, forKey: "weeklyGoalsData")
                }

                // Store the pending toggle for the app to sync with backend
                var pendingToggles = sharedDefaults?.array(forKey: "pendingWeeklyGoalToggles") as? [[String: Any]] ?? []
                pendingToggles.append([
                    "goalId": goalId,
                    "isCompleted": isCompleted,
                    "timestamp": Date().timeIntervalSince1970
                ])
                sharedDefaults?.set(pendingToggles, forKey: "pendingWeeklyGoalToggles")
            }
        }

        // Reload widget
        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyGoalsWidget")

        return .result()
    }
}

// MARK: - Timeline Entry
struct WeeklyGoalsWidgetEntry: TimelineEntry {
    let date: Date
    let goals: [WeeklyGoalsWidgetItem]
    let weekRange: String
    let completedCount: Int
    let totalCount: Int

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    static let placeholder = WeeklyGoalsWidgetEntry(
        date: Date(),
        goals: [
            WeeklyGoalsWidgetItem(id: "1", areaEmoji: "🎯", content: "Finir le projet X", isCompleted: true),
            WeeklyGoalsWidgetItem(id: "2", areaEmoji: "💪", content: "3 séances sport", isCompleted: false),
            WeeklyGoalsWidgetItem(id: "3", areaEmoji: "📚", content: "Lire 50 pages", isCompleted: false)
        ],
        weekRange: "30 Dec - 5 Jan",
        completedCount: 1,
        totalCount: 3
    )

    static let empty = WeeklyGoalsWidgetEntry(
        date: Date(),
        goals: [],
        weekRange: "",
        completedCount: 0,
        totalCount: 0
    )
}

// MARK: - Timeline Provider
struct WeeklyGoalsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyGoalsWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyGoalsWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyGoalsWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> WeeklyGoalsWidgetEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.jep.volta")

        guard let data = sharedDefaults?.data(forKey: "weeklyGoalsData"),
              let decoded = try? JSONDecoder().decode(WeeklyGoalsWidgetData.self, from: data) else {
            return .empty
        }

        return WeeklyGoalsWidgetEntry(
            date: Date(),
            goals: decoded.items,
            weekRange: decoded.weekRange,
            completedCount: decoded.completedCount,
            totalCount: decoded.totalCount
        )
    }
}

// MARK: - Widget Entry View
struct WeeklyGoalsWidgetEntryView: View {
    var entry: WeeklyGoalsWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWeeklyGoalsView(entry: entry)
        case .systemMedium:
            MediumWeeklyGoalsView(entry: entry)
        case .accessoryRectangular:
            LockScreenWeeklyGoalsView(entry: entry)
        default:
            SmallWeeklyGoalsView(entry: entry)
        }
    }
}

// MARK: - Small View
struct SmallWeeklyGoalsView: View {
    let entry: WeeklyGoalsWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header - tappable to open app
            Link(destination: URL(string: "focus://weekly-goals")!) {
                HStack {
                    Text("🎯")
                        .font(.system(size: 20))
                    Text("This Week")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    if entry.totalCount > 0 {
                        Text("\(entry.completedCount)/\(entry.totalCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.widgetAccent)
                    }
                }
            }

            if entry.goals.isEmpty {
                Spacer()
                Link(destination: URL(string: "focus://weekly-goals")!) {
                    VStack(spacing: 4) {
                        Text("No goals set")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("Tap to set your goals")
                            .font(.system(size: 11))
                            .foregroundColor(.widgetAccent)
                    }
                    .frame(maxWidth: .infinity)
                }
                Spacer()
            } else {
                Spacer()

                // Show goals with interactive toggles
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.goals.prefix(3)) { goal in
                        HStack(spacing: 6) {
                            // Interactive toggle button
                            Button(intent: ToggleWeeklyGoalIntent(goalId: goal.id, isCompleted: !goal.isCompleted)) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(
                                            goal.isCompleted ? Color.clear : Color.gray.opacity(0.5),
                                            lineWidth: 1.5
                                        )
                                        .background(
                                            Circle()
                                                .fill(goal.isCompleted ? Color.green : Color.clear)
                                        )
                                        .frame(width: 18, height: 18)

                                    if goal.isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Text(goal.areaEmoji)
                                .font(.system(size: 12))

                            Text(goal.content)
                                .font(.system(size: 11))
                                .foregroundColor(goal.isCompleted ? .secondary : .primary)
                                .strikethrough(goal.isCompleted)
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                }

                if entry.goals.count > 3 {
                    Text("+\(entry.goals.count - 3) more")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium View
struct MediumWeeklyGoalsView: View {
    let entry: WeeklyGoalsWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Simple header: title + count
            HStack {
                Text("Weekly Goals")
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                if entry.totalCount > 0 {
                    Text("\(entry.completedCount)/\(entry.totalCount)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.widgetAccent)
                }
            }

            if entry.goals.isEmpty {
                // Empty state
                Spacer()
                Link(destination: URL(string: "focus://weekly-goals")!) {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("No goals yet")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                            Text("+ Add goals")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.widgetAccent)
                        }
                        Spacer()
                    }
                }
                Spacer()
            } else {
                // Goals list - simple vertical scroll
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(entry.goals.prefix(4)) { goal in
                        HStack(spacing: 10) {
                            // Toggle button
                            Button(intent: ToggleWeeklyGoalIntent(goalId: goal.id, isCompleted: !goal.isCompleted)) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(
                                            goal.isCompleted ? Color.clear : Color.gray.opacity(0.4),
                                            lineWidth: 2
                                        )
                                        .background(
                                            Circle()
                                                .fill(goal.isCompleted ? Color.green : Color.clear)
                                        )
                                        .frame(width: 24, height: 24)

                                    if goal.isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            // Emoji + text
                            Text(goal.areaEmoji)
                                .font(.system(size: 16))

                            Text(goal.content)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(goal.isCompleted ? .secondary : .primary)
                                .strikethrough(goal.isCompleted)
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                }

                if entry.goals.count > 4 {
                    Text("+\(entry.goals.count - 4) more")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Lock Screen View
struct LockScreenWeeklyGoalsView: View {
    let entry: WeeklyGoalsWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("🎯 Weekly Goals")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if entry.totalCount > 0 {
                    Text("\(entry.completedCount)/\(entry.totalCount)")
                        .font(.system(size: 11))
                }
            }

            if entry.goals.isEmpty {
                Text("Tap to set goals")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.goals.prefix(2)) { goal in
                    HStack(spacing: 4) {
                        if goal.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8))
                        } else {
                            Text("○")
                                .font(.system(size: 10))
                        }
                        Text(goal.content)
                            .font(.system(size: 11))
                            .strikethrough(goal.isCompleted)
                            .lineLimit(1)
                    }
                }
            }
        }
        .widgetURL(URL(string: "focus://weekly-goals"))
    }
}

// MARK: - Widget Configuration
struct WeeklyGoalsWidget: Widget {
    let kind: String = "WeeklyGoalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyGoalsWidgetProvider()) { entry in
            WeeklyGoalsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weekly Goals")
        .description("Tes objectifs de la semaine avec toggles interactifs.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular
        ])
    }
}

// MARK: - Previews
#Preview("Small - With Goals", as: .systemSmall) {
    WeeklyGoalsWidget()
} timeline: {
    WeeklyGoalsWidgetEntry.placeholder
}

#Preview("Small - Empty", as: .systemSmall) {
    WeeklyGoalsWidget()
} timeline: {
    WeeklyGoalsWidgetEntry.empty
}

#Preview("Medium", as: .systemMedium) {
    WeeklyGoalsWidget()
} timeline: {
    WeeklyGoalsWidgetEntry(
        date: Date(),
        goals: [
            WeeklyGoalsWidgetItem(id: "1", areaEmoji: "🎯", content: "Finir le projet X", isCompleted: true),
            WeeklyGoalsWidgetItem(id: "2", areaEmoji: "💪", content: "3 séances sport", isCompleted: false),
            WeeklyGoalsWidgetItem(id: "3", areaEmoji: "📚", content: "Lire 50 pages", isCompleted: false),
            WeeklyGoalsWidgetItem(id: "4", areaEmoji: "❤️", content: "Dîner avec parents", isCompleted: false)
        ],
        weekRange: "30 Dec - 5 Jan",
        completedCount: 1,
        totalCount: 4
    )
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    WeeklyGoalsWidget()
} timeline: {
    WeeklyGoalsWidgetEntry.placeholder
}
