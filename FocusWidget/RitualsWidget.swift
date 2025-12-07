//
//  RitualsWidget.swift
//  FocusWidget
//
//  Widget to display and track daily rituals
//

import WidgetKit
import SwiftUI

// MARK: - Ritual Data Model
struct WidgetRitual: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let isCompleted: Bool
}

// MARK: - Timeline Entry
struct RitualsWidgetEntry: TimelineEntry {
    let date: Date
    let rituals: [WidgetRitual]

    var completedCount: Int {
        rituals.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        rituals.count
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

// MARK: - Timeline Provider
struct RitualsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> RitualsWidgetEntry {
        RitualsWidgetEntry(
            date: Date(),
            rituals: [
                WidgetRitual(id: "1", title: "Morning meditation", icon: "🧘", isCompleted: true),
                WidgetRitual(id: "2", title: "Exercise", icon: "💪", isCompleted: true),
                WidgetRitual(id: "3", title: "Read 30 min", icon: "📚", isCompleted: false),
                WidgetRitual(id: "4", title: "Journal", icon: "✍️", isCompleted: false)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RitualsWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RitualsWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> RitualsWidgetEntry {
        let sharedDefaults = UserDefaults(suiteName: WidgetDataKeys.suiteName)

        var rituals: [WidgetRitual] = []
        if let data = sharedDefaults?.data(forKey: WidgetDataKeys.ritualsData),
           let decoded = try? JSONDecoder().decode([WidgetRitual].self, from: data) {
            rituals = decoded
        }

        return RitualsWidgetEntry(date: Date(), rituals: rituals)
    }
}

// MARK: - Widget Views
struct RitualsWidgetEntryView: View {
    var entry: RitualsWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallRitualsView(entry: entry)
        case .systemMedium:
            MediumRitualsView(entry: entry)
        default:
            SmallRitualsView(entry: entry)
        }
    }
}

// MARK: - Small Rituals View
struct SmallRitualsView: View {
    let entry: RitualsWidgetEntry

    var body: some View {
        Link(destination: URL(string: "focus://dashboard/rituals")!) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text("📋")
                        .font(.system(size: 20))
                    Text("Rituals")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }

                if entry.rituals.isEmpty {
                    Spacer()
                    Text("No rituals today")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    Spacer()

                    // Progress circle
                    HStack {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                                .frame(width: 50, height: 50)

                            Circle()
                                .trim(from: 0, to: entry.progress)
                                .stroke(
                                    LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))

                            Text("\(entry.completedCount)/\(entry.totalCount)")
                                .font(.system(size: 12, weight: .bold))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(entry.progress * 100))%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.green)
                            Text("complete")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    // First uncompleted ritual
                    if let nextRitual = entry.rituals.first(where: { !$0.isCompleted }) {
                        HStack(spacing: 6) {
                            Text(nextRitual.icon)
                                .font(.system(size: 14))
                            Text(nextRitual.title)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Rituals View
struct MediumRitualsView: View {
    let entry: RitualsWidgetEntry

    var body: some View {
        Link(destination: URL(string: "focus://dashboard/rituals")!) {
            HStack(spacing: 16) {
                // Left: Progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("📋")
                            .font(.system(size: 24))
                        Text("Daily Rituals")
                            .font(.system(size: 16, weight: .bold))
                    }

                    Spacer()

                    if entry.rituals.isEmpty {
                        Text("No rituals today")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 12) {
                            // Progress circle
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                    .frame(width: 60, height: 60)

                                Circle()
                                    .trim(from: 0, to: entry.progress)
                                    .stroke(
                                        LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(-90))

                                VStack(spacing: 0) {
                                    Text("\(entry.completedCount)")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("of \(entry.totalCount)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Int(entry.progress * 100))%")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.green)
                                Text("completed")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !entry.rituals.isEmpty {
                    Divider()

                    // Right: Ritual list
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(entry.rituals.prefix(4)) { ritual in
                            HStack(spacing: 8) {
                                Text(ritual.icon)
                                    .font(.system(size: 16))

                                Text(ritual.title)
                                    .font(.system(size: 12))
                                    .foregroundColor(ritual.isCompleted ? .secondary : .primary)
                                    .strikethrough(ritual.isCompleted)
                                    .lineLimit(1)

                                Spacer()

                                if ritual.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                } else {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 14, height: 14)
                                }
                            }
                        }

                        if entry.rituals.count > 4 {
                            Text("+\(entry.rituals.count - 4) more")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Configuration
struct RitualsWidget: Widget {
    let kind: String = "RitualsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RitualsWidgetProvider()) { entry in
            RitualsWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "focus://dashboard/rituals"))
        }
        .configurationDisplayName("Daily Rituals")
        .description("Track your daily rituals and habits.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

// MARK: - Previews
#Preview("Small - With Rituals", as: .systemSmall) {
    RitualsWidget()
} timeline: {
    RitualsWidgetEntry(
        date: Date(),
        rituals: [
            WidgetRitual(id: "1", title: "Morning meditation", icon: "🧘", isCompleted: true),
            WidgetRitual(id: "2", title: "Exercise", icon: "💪", isCompleted: true),
            WidgetRitual(id: "3", title: "Read 30 min", icon: "📚", isCompleted: false),
            WidgetRitual(id: "4", title: "Journal", icon: "✍️", isCompleted: false)
        ]
    )
}

#Preview("Small - Empty", as: .systemSmall) {
    RitualsWidget()
} timeline: {
    RitualsWidgetEntry(date: Date(), rituals: [])
}

#Preview("Medium", as: .systemMedium) {
    RitualsWidget()
} timeline: {
    RitualsWidgetEntry(
        date: Date(),
        rituals: [
            WidgetRitual(id: "1", title: "Morning meditation", icon: "🧘", isCompleted: true),
            WidgetRitual(id: "2", title: "Exercise", icon: "💪", isCompleted: true),
            WidgetRitual(id: "3", title: "Read 30 min", icon: "📚", isCompleted: false),
            WidgetRitual(id: "4", title: "Journal", icon: "✍️", isCompleted: false),
            WidgetRitual(id: "5", title: "Cold shower", icon: "🚿", isCompleted: false)
        ]
    )
}
