//
//  IntentionsWidget.swift
//  FocusWidget
//
//  Widget to display today's intentions from morning check-in
//

import WidgetKit
import SwiftUI

// MARK: - Intention Data Model
struct WidgetIntention: Codable, Identifiable {
    let id: String
    let text: String
    let area: String
    let areaEmoji: String
    let isCompleted: Bool
}

// MARK: - Timeline Entry
struct IntentionsWidgetEntry: TimelineEntry {
    let date: Date
    let intentions: [WidgetIntention]
    let moodEmoji: String?

    var completedCount: Int {
        intentions.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        intentions.count
    }
}

// MARK: - Timeline Provider
struct IntentionsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> IntentionsWidgetEntry {
        IntentionsWidgetEntry(
            date: Date(),
            intentions: [
                WidgetIntention(id: "1", text: "Ship new feature", area: "Work", areaEmoji: "💼", isCompleted: true),
                WidgetIntention(id: "2", text: "Call mom", area: "Family", areaEmoji: "👨‍👩‍👧", isCompleted: false),
                WidgetIntention(id: "3", text: "30 min workout", area: "Health", areaEmoji: "💪", isCompleted: false)
            ],
            moodEmoji: "😊"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (IntentionsWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IntentionsWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> IntentionsWidgetEntry {
        let sharedDefaults = UserDefaults(suiteName: WidgetDataKeys.suiteName)

        var intentions: [WidgetIntention] = []
        if let data = sharedDefaults?.data(forKey: WidgetDataKeys.intentionsData),
           let decoded = try? JSONDecoder().decode([WidgetIntention].self, from: data) {
            intentions = decoded
        }

        let moodEmoji = sharedDefaults?.string(forKey: "widget_mood_emoji")

        return IntentionsWidgetEntry(date: Date(), intentions: intentions, moodEmoji: moodEmoji)
    }
}

// MARK: - Widget Views
struct IntentionsWidgetEntryView: View {
    var entry: IntentionsWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallIntentionsView(entry: entry)
        case .systemMedium:
            MediumIntentionsView(entry: entry)
        default:
            SmallIntentionsView(entry: entry)
        }
    }
}

// MARK: - Small Intentions View
struct SmallIntentionsView: View {
    let entry: IntentionsWidgetEntry

    var body: some View {
        Link(destination: URL(string: "focus://dashboard/intentions")!) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text("☀️")
                        .font(.system(size: 20))
                    Text("Today")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    if let mood = entry.moodEmoji {
                        Text(mood)
                            .font(.system(size: 16))
                    }
                }

                if entry.intentions.isEmpty {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("No intentions set")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("Tap to start your day")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    Spacer()
                } else {
                    Spacer()

                    // Show first 3 intentions
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(entry.intentions.prefix(3)) { intention in
                            HStack(spacing: 6) {
                                Text(intention.areaEmoji)
                                    .font(.system(size: 12))

                                Text(intention.text)
                                    .font(.system(size: 11))
                                    .foregroundColor(intention.isCompleted ? .secondary : .primary)
                                    .strikethrough(intention.isCompleted)
                                    .lineLimit(1)

                                Spacer()

                                if intention.isCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }

                    // Progress
                    HStack {
                        Text("\(entry.completedCount)/\(entry.totalCount) done")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Intentions View
struct MediumIntentionsView: View {
    let entry: IntentionsWidgetEntry

    var body: some View {
        Link(destination: URL(string: "focus://dashboard/intentions")!) {
            HStack(spacing: 16) {
                // Left: Header and mood
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("☀️")
                            .font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Intentions")
                                .font(.system(size: 16, weight: .bold))
                            Text(formattedDate)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if entry.intentions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start your day")
                                .font(.system(size: 14, weight: .medium))
                            Text("Set your intentions for today")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12))
                            Text("Begin")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.blue)
                    } else {
                        // Mood and progress
                        HStack(spacing: 12) {
                            if let mood = entry.moodEmoji {
                                VStack(spacing: 2) {
                                    Text(mood)
                                        .font(.system(size: 28))
                                    Text("mood")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(entry.completedCount)/\(entry.totalCount)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.blue)
                                Text("completed")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !entry.intentions.isEmpty {
                    Divider()

                    // Right: Intention list
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.intentions.prefix(3)) { intention in
                            HStack(spacing: 8) {
                                Text(intention.areaEmoji)
                                    .font(.system(size: 18))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(intention.text)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(intention.isCompleted ? .secondary : .primary)
                                        .strikethrough(intention.isCompleted)
                                        .lineLimit(1)

                                    Text(intention.area)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if intention.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                } else {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 16, height: 16)
                                }
                            }
                        }

                        if entry.intentions.count > 3 {
                            Text("+\(entry.intentions.count - 3) more")
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

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: Date())
    }
}

// MARK: - Widget Configuration
struct IntentionsWidget: Widget {
    let kind: String = "IntentionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IntentionsWidgetProvider()) { entry in
            IntentionsWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "focus://dashboard/intentions"))
        }
        .configurationDisplayName("Today's Intentions")
        .description("View your daily intentions from morning check-in.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

// MARK: - Previews
#Preview("Small - With Intentions", as: .systemSmall) {
    IntentionsWidget()
} timeline: {
    IntentionsWidgetEntry(
        date: Date(),
        intentions: [
            WidgetIntention(id: "1", text: "Ship new feature", area: "Work", areaEmoji: "💼", isCompleted: true),
            WidgetIntention(id: "2", text: "Call mom", area: "Family", areaEmoji: "👨‍👩‍👧", isCompleted: false),
            WidgetIntention(id: "3", text: "30 min workout", area: "Health", areaEmoji: "💪", isCompleted: false)
        ],
        moodEmoji: "😊"
    )
}

#Preview("Small - Empty", as: .systemSmall) {
    IntentionsWidget()
} timeline: {
    IntentionsWidgetEntry(date: Date(), intentions: [], moodEmoji: nil)
}

#Preview("Medium", as: .systemMedium) {
    IntentionsWidget()
} timeline: {
    IntentionsWidgetEntry(
        date: Date(),
        intentions: [
            WidgetIntention(id: "1", text: "Ship new feature", area: "Work", areaEmoji: "💼", isCompleted: true),
            WidgetIntention(id: "2", text: "Call mom", area: "Family", areaEmoji: "👨‍👩‍👧", isCompleted: false),
            WidgetIntention(id: "3", text: "30 min workout", area: "Health", areaEmoji: "💪", isCompleted: false),
            WidgetIntention(id: "4", text: "Read 20 pages", area: "Growth", areaEmoji: "📚", isCompleted: false)
        ],
        moodEmoji: "😊"
    )
}
