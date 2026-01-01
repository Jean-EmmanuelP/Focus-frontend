//
//  FocusWidget.swift
//  FocusWidget
//
//  Interactive Focus Widget - Start sessions directly from widget
//  With real-time countdown timer
//

import WidgetKit
import SwiftUI

// MARK: - Widget Theme Colors (Sky Blue)
private extension Color {
    static let focusAccent = Color(red: 0.35, green: 0.78, blue: 0.98) // #5AC8FA Sky Blue
    static let focusAccentEnd = Color(red: 0.39, green: 0.82, blue: 1.0) // #64D2FF
}

// MARK: - Shared Data Keys
struct WidgetDataKeys {
    static let suiteName = "group.com.jep.volta"

    // Focus stats
    static let minutesToday = "widget_minutes_today"
    static let sessionsToday = "widget_sessions_today"
    static let streakDays = "widget_streak_days"

    // Active session
    static let isInSession = "widget_is_in_session"
    static let sessionEndDate = "widget_session_end_date" // Date when session ends
    static let sessionTotalDuration = "widget_session_total_duration"
    static let sessionQuestEmoji = "widget_session_quest_emoji"
    static let sessionDescription = "widget_session_description"

    // Rituals
    static let ritualsData = "widget_rituals"

    // Intentions
    static let intentionsData = "widget_intentions"
}

// MARK: - Timeline Entry
struct FocusWidgetEntry: TimelineEntry {
    let date: Date
    let minutesToday: Int
    let sessionsToday: Int
    let streakDays: Int
    let isInSession: Bool
    let sessionEndDate: Date?
    let totalDuration: Int
    let questEmoji: String?
    let sessionDescription: String?

    var progress: Double {
        guard let endDate = sessionEndDate, totalDuration > 0, isInSession else { return 0 }
        let totalSeconds = Double(totalDuration * 60)
        let remainingSeconds = endDate.timeIntervalSince(Date())
        return max(0, min(1, 1.0 - (remainingSeconds / totalSeconds)))
    }

    var timeRemaining: TimeInterval {
        guard let endDate = sessionEndDate else { return 0 }
        return max(0, endDate.timeIntervalSince(Date()))
    }
}

// MARK: - Timeline Provider
struct FocusWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusWidgetEntry {
        FocusWidgetEntry(
            date: Date(),
            minutesToday: 45,
            sessionsToday: 2,
            streakDays: 5,
            isInSession: false,
            sessionEndDate: nil,
            totalDuration: 0,
            questEmoji: nil,
            sessionDescription: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusWidgetEntry>) -> Void) {
        let entry = loadEntry()

        var entries: [FocusWidgetEntry] = [entry]

        if entry.isInSession, let endDate = entry.sessionEndDate {
            // Create an entry for when the session ends
            let endEntry = FocusWidgetEntry(
                date: endDate,
                minutesToday: entry.minutesToday + entry.totalDuration,
                sessionsToday: entry.sessionsToday + 1,
                streakDays: entry.streakDays,
                isInSession: false,
                sessionEndDate: nil,
                totalDuration: 0,
                questEmoji: nil,
                sessionDescription: nil
            )
            entries.append(endEntry)
        }

        // Update policy: if in session, refresh when session ends; otherwise every 15 min
        let policy: TimelineReloadPolicy
        if entry.isInSession, let endDate = entry.sessionEndDate {
            policy = .after(endDate.addingTimeInterval(1))
        } else {
            policy = .after(Date().addingTimeInterval(900))
        }

        let timeline = Timeline(entries: entries, policy: policy)
        completion(timeline)
    }

    private func loadEntry() -> FocusWidgetEntry {
        let sharedDefaults = UserDefaults(suiteName: WidgetDataKeys.suiteName)

        var sessionEndDate: Date? = nil
        if let endTimestamp = sharedDefaults?.double(forKey: WidgetDataKeys.sessionEndDate), endTimestamp > 0 {
            sessionEndDate = Date(timeIntervalSince1970: endTimestamp)
        }

        return FocusWidgetEntry(
            date: Date(),
            minutesToday: sharedDefaults?.integer(forKey: WidgetDataKeys.minutesToday) ?? 0,
            sessionsToday: sharedDefaults?.integer(forKey: WidgetDataKeys.sessionsToday) ?? 0,
            streakDays: sharedDefaults?.integer(forKey: WidgetDataKeys.streakDays) ?? 0,
            isInSession: sharedDefaults?.bool(forKey: WidgetDataKeys.isInSession) ?? false,
            sessionEndDate: sessionEndDate,
            totalDuration: sharedDefaults?.integer(forKey: WidgetDataKeys.sessionTotalDuration) ?? 0,
            questEmoji: sharedDefaults?.string(forKey: WidgetDataKeys.sessionQuestEmoji),
            sessionDescription: sharedDefaults?.string(forKey: WidgetDataKeys.sessionDescription)
        )
    }
}

// MARK: - Widget Views
struct FocusWidgetEntryView: View {
    var entry: FocusWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallFocusWidgetView(entry: entry)
        case .systemMedium:
            MediumFocusWidgetView(entry: entry)
        case .accessoryCircular:
            CircularFocusWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularFocusWidgetView(entry: entry)
        default:
            SmallFocusWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View
struct SmallFocusWidgetView: View {
    let entry: FocusWidgetEntry

    var body: some View {
        if entry.isInSession, let endDate = entry.sessionEndDate, endDate > Date() {
            activeSessionView(endDate: endDate)
        } else {
            idleView
        }
    }

    private func activeSessionView(endDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with status
            HStack {
                Text(entry.questEmoji ?? "🔥")
                    .font(.system(size: 24))
                Spacer()
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(4)
            }

            Spacer()

            // Real-time countdown timer
            Text(endDate, style: .timer)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.focusAccent)
                .multilineTextAlignment(.leading)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.focusAccent, .focusAccentEnd], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * entry.progress, height: 6)
                }
            }
            .frame(height: 6)

            // Description
            if let desc = entry.sessionDescription, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var idleView: some View {
        Link(destination: URL(string: "focus://firemode")!) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text("🔥")
                        .font(.system(size: 24))
                    Spacer()
                    if entry.streakDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(entry.streakDays)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.focusAccent)
                    }
                }

                Spacer()

                // Stats
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.minutesToday)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.focusAccent)
                    Text("min today")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Start button
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("Start Focus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(colors: [.focusAccent, .focusAccentEnd], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
            }
            .padding()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View
struct MediumFocusWidgetView: View {
    let entry: FocusWidgetEntry

    var body: some View {
        if entry.isInSession, let endDate = entry.sessionEndDate, endDate > Date() {
            activeSessionView(endDate: endDate)
        } else {
            idleView
        }
    }

    private func activeSessionView(endDate: Date) -> some View {
        HStack(spacing: 16) {
            // Left: Timer and progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.questEmoji ?? "🔥")
                        .font(.system(size: 28))

                    Text("FOCUSING")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.focusAccent)

                    Spacer()

                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }

                Spacer()

                // Real-time countdown timer
                Text(endDate, style: .timer)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundColor(.focusAccent)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.focusAccent, .focusAccentEnd], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * entry.progress, height: 8)
                    }
                }
                .frame(height: 8)
            }

            // Right: Session info
            VStack(alignment: .leading, spacing: 8) {
                if let desc = entry.sessionDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("\(entry.totalDuration) min session")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 11))
                        Text("\(entry.sessionsToday) sessions today")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var idleView: some View {
        Link(destination: URL(string: "focus://firemode")!) {
            HStack(spacing: 16) {
                // Left: Stats
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🔥")
                            .font(.system(size: 28))
                        Text("Volta")
                            .font(.system(size: 16, weight: .bold))
                        Spacer()
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.minutesToday)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.focusAccent)
                        Text("minutes focused today")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Right: Quick stats and action
                VStack(alignment: .leading, spacing: 12) {
                    // Stats
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.sessionsToday)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.focusAccent)
                            Text("sessions")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.streakDays)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.focusAccent)
                            Text("day streak")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Start button
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Start Focus Session")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [.focusAccent, .focusAccentEnd], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(20)
                }
            }
            .padding()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Circular Widget (Lock Screen)
struct CircularFocusWidgetView: View {
    let entry: FocusWidgetEntry

    var body: some View {
        if entry.isInSession, let endDate = entry.sessionEndDate, endDate > Date() {
            // Show timer progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(Color.focusAccent, lineWidth: 4)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(entry.questEmoji ?? "🔥")
                        .font(.system(size: 12))
                    Text("\(Int(entry.timeRemaining / 60))")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .widgetURL(URL(string: "focus://firemode"))
        } else {
            // Show stats
            Link(destination: URL(string: "focus://firemode")!) {
                ZStack {
                    AccessoryWidgetBackground()

                    VStack(spacing: 0) {
                        Text("🔥")
                            .font(.system(size: 14))
                        Text("\(entry.minutesToday)")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
            }
        }
    }
}

// MARK: - Rectangular Widget (Lock Screen)
struct RectangularFocusWidgetView: View {
    let entry: FocusWidgetEntry

    var body: some View {
        if entry.isInSession, let endDate = entry.sessionEndDate, endDate > Date() {
            // Active session with real-time timer
            HStack(spacing: 8) {
                Text(entry.questEmoji ?? "🔥")
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text(endDate, style: .timer)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))

                    // Mini progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 3)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.focusAccent)
                                .frame(width: geo.size.width * entry.progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }

                Spacer()
            }
            .widgetURL(URL(string: "focus://firemode"))
        } else {
            // Idle stats
            Link(destination: URL(string: "focus://firemode")!) {
                HStack(spacing: 8) {
                    Text("🔥")
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.minutesToday) min")
                            .font(.system(size: 14, weight: .bold))
                        Text("\(entry.sessionsToday) sessions • \(entry.streakDays)🔥")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.focusAccent)
                }
            }
        }
    }
}

// MARK: - Widget Configuration
struct FocusWidget: Widget {
    let kind: String = "FocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusWidgetProvider()) { entry in
            FocusWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "focus://firemode"))
        }
        .configurationDisplayName("Focus Timer")
        .description("Track your focus time and start sessions instantly.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Previews
#Preview("Small - Idle", as: .systemSmall) {
    FocusWidget()
} timeline: {
    FocusWidgetEntry(
        date: Date(),
        minutesToday: 75,
        sessionsToday: 3,
        streakDays: 5,
        isInSession: false,
        sessionEndDate: nil,
        totalDuration: 0,
        questEmoji: nil,
        sessionDescription: nil
    )
}

#Preview("Small - Active", as: .systemSmall) {
    FocusWidget()
} timeline: {
    FocusWidgetEntry(
        date: Date(),
        minutesToday: 75,
        sessionsToday: 3,
        streakDays: 5,
        isInSession: true,
        sessionEndDate: Date().addingTimeInterval(25 * 60),
        totalDuration: 25,
        questEmoji: "💼",
        sessionDescription: "Working on app"
    )
}

#Preview("Medium - Idle", as: .systemMedium) {
    FocusWidget()
} timeline: {
    FocusWidgetEntry(
        date: Date(),
        minutesToday: 120,
        sessionsToday: 5,
        streakDays: 12,
        isInSession: false,
        sessionEndDate: nil,
        totalDuration: 0,
        questEmoji: nil,
        sessionDescription: nil
    )
}

#Preview("Medium - Active", as: .systemMedium) {
    FocusWidget()
} timeline: {
    FocusWidgetEntry(
        date: Date(),
        minutesToday: 120,
        sessionsToday: 5,
        streakDays: 12,
        isInSession: true,
        sessionEndDate: Date().addingTimeInterval(14 * 60 + 5),
        totalDuration: 50,
        questEmoji: "🎨",
        sessionDescription: "Design review for new feature"
    )
}
