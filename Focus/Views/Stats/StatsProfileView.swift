import SwiftUI

// MARK: - Stats Profile View (Gamified)

struct StatsProfileView: View {
    @EnvironmentObject var store: FocusAppStore
    @Environment(\.dismiss) private var dismiss

    @State private var streakData: StreakResponse?
    @State private var completionsByDate: [String: Int] = [:]
    @State private var isLoading = true
    @State private var appeared = false
    @State private var ringProgress: Double = 0
    @State private var streakScale: CGFloat = 0.5
    @State private var showAllLevels = false

    private let bgColor = Color.black
    private let streakService = StreakService()
    private let completionsService = CompletionsService()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE"
        return f
    }()

    // Today stats
    private var tasksCompleted: Int { store.todaysTasks.filter { $0.isCompleted }.count }
    private var tasksTotal: Int { store.todaysTasks.count }
    private var ritualsCompleted: Int { store.rituals.filter { $0.isCompleted }.count }
    private var ritualsTotal: Int { store.rituals.count }
    private var focusMinutes: Int { store.todayMinutes }

    private var tasksPct: Double {
        guard tasksTotal > 0 else { return 0 }
        return Double(tasksCompleted) / Double(tasksTotal)
    }
    private var ritualsPct: Double {
        guard ritualsTotal > 0 else { return 0 }
        return Double(ritualsCompleted) / Double(ritualsTotal)
    }
    private var focusPct: Double {
        min(1.0, Double(focusMinutes) / 25.0)
    }
    private var overallPct: Double {
        let total = tasksPct + ritualsPct + focusPct
        return total / 3.0
    }

    // Week stats
    private var thisWeekCompletions: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reduce(0) { sum, offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return sum }
            let key = Self.dateFormatter.string(from: day)
            return sum + (completionsByDate[key] ?? 0)
        }
    }
    private var lastWeekCompletions: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (7..<14).reduce(0) { sum, offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return sum }
            let key = Self.dateFormatter.string(from: day)
            return sum + (completionsByDate[key] ?? 0)
        }
    }
    private var weekTrend: Int {
        guard lastWeekCompletions > 0 else { return thisWeekCompletions > 0 ? 100 : 0 }
        return Int(((Double(thisWeekCompletions) / Double(lastWeekCompletions)) - 1.0) * 100)
    }

    private var currentStreak: Int { streakData?.currentStreak ?? store.currentStreak }
    private var longestStreak: Int { streakData?.longestStreak ?? store.user?.longestStreak ?? 0 }
    private var flameLevels: [FlameLevel] { streakData?.flameLevels ?? [] }
    private var currentFlameLevel: Int { streakData?.currentFlameLevel ?? 0 }
    private var isStreakRecord: Bool { currentStreak > 0 && currentStreak >= longestStreak }

    private var streakFlameColor: Color {
        switch currentStreak {
        case 0: return .gray
        case 1...3: return .white.opacity(0.6)
        case 4...7: return .white.opacity(0.75)
        case 8...14: return .white.opacity(0.9)
        default: return .white
        }
    }
    private var streakGlowRadius: CGFloat {
        switch currentStreak {
        case 0...3: return 4
        case 4...7: return 8
        case 8...14: return 12
        default: return 16
        }
    }

    private var currentFlameName: String {
        flameLevels.first { $0.isCurrent }?.name ?? "Débutant"
    }
    private var currentFlameIcon: String {
        flameLevels.first { $0.isCurrent }?.icon ?? "flame"
    }
    private var nextFlameLevel: FlameLevel? {
        flameLevels.first { !$0.isUnlocked }
    }
    private var progressToNextLevel: Double {
        guard let next = nextFlameLevel else { return 1.0 }
        let prev = flameLevels.last { $0.isUnlocked }
        let prevDays = prev?.daysRequired ?? 0
        let range = next.daysRequired - prevDays
        guard range > 0 else { return 0 }
        return min(1.0, Double(currentStreak - prevDays) / Double(range))
    }

    private var memberSinceText: String? {
        guard let created = store.user?.createdAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return "Membre depuis \(formatter.string(from: created))"
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 56)

                        profileHeader
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)

                        streakCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)

                        weekView
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: appeared)

                        todayStatsRow
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35), value: appeared)

                        if !flameLevels.isEmpty {
                            flameLevelsSection
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45), value: appeared)
                        }

                        Spacer().frame(height: 40)
                    }
                }
            }

            // Top bar
            VStack {
                topBar
                Spacer()
            }
        }
        .task {
            await loadData()
            withAnimation(.easeOut(duration: 0.3)) {
                isLoading = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.8)) {
                    ringProgress = overallPct
                }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
                    streakScale = 1.0
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            Spacer()
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            bgColor.opacity(0.85)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            // Avatar with animated ring
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.08), Color.clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 5)
                    .frame(width: 110, height: 110)

                // Progress ring
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.7), .white, .white],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))

                // Avatar
                if let avatarURL = store.user?.avatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            avatarPlaceholder
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                }
            }

            // Score label
            Text("\(Int(overallPct * 100))% aujourd'hui")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))

            // Name
            Text(store.user?.name ?? "Utilisateur")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            // Member since
            if let since = memberSinceText {
                Text(since)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }

            // Flame level badge
            HStack(spacing: 6) {
                Image(systemName: currentFlameIcon)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                Text(currentFlameName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
            Text(String(store.user?.name.prefix(1) ?? "U").uppercased())
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Streak number
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 28))
                            .foregroundColor(streakFlameColor)
                            .shadow(color: streakFlameColor.opacity(0.5), radius: streakGlowRadius)

                        if currentStreak > 0 {
                            Text("\(currentStreak)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .scaleEffect(streakScale)
                        } else {
                            Text("0")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }

                    if currentStreak == 0 {
                        Text("Recommence aujourd'hui !")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text("jours de suite")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                // Record badge
                VStack(alignment: .trailing, spacing: 4) {
                    if isStreakRecord && currentStreak > 0 {
                        // Record badge with glow
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                            Text("RECORD !")
                                .font(.system(size: 11, weight: .black))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                        .shadow(color: .white.opacity(0.2), radius: 8)
                    } else {
                        Text("Record")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))
                            .textCase(.uppercase)
                            .kerning(0.5)
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(longestStreak) j")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }

            // Progress to next level
            if let next = nextFlameLevel {
                VStack(spacing: 6) {
                    HStack {
                        Text("Prochain : \(next.name)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("\(currentStreak)/\(next.daysRequired) j")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.6), .white],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progressToNextLevel)
                                .animation(.easeOut(duration: 1.0).delay(0.5), value: appeared)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isStreakRecord ? Color.white.opacity(0.15) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Week View (replaces GitHub grid)

    private var weekView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cette semaine")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .kerning(1)
                    Text("\(thisWeekCompletions) actions")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Trend badge
                if lastWeekCompletions > 0 || thisWeekCompletions > 0 {
                    let isUp = weekTrend >= 0
                    HStack(spacing: 4) {
                        Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(abs(weekTrend))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
                }
            }
            .padding(.horizontal, 4)

            // 7 day circles
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let days: [(date: Date, key: String)] = (0..<7).reversed().compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
                return (day, Self.dateFormatter.string(from: day))
            }

            HStack(spacing: 6) {
                ForEach(days, id: \.key) { day in
                    let count = completionsByDate[day.key] ?? 0
                    let maxCount = max(1, completionsByDate.values.max() ?? 1)
                    let fillPct = count > 0 ? max(0.15, Double(count) / Double(maxCount)) : 0
                    let isToday = calendar.isDateInToday(day.date)

                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 3)

                            Circle()
                                .trim(from: 0, to: appeared ? fillPct : 0)
                                .stroke(
                                    Color.white,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 0.6).delay(Double(6 - (days.firstIndex(where: { $0.key == day.key }) ?? 0)) * 0.05 + 0.3), value: appeared)

                            Text("\(count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(count > 0 ? .white : .white.opacity(0.2))
                        }
                        .frame(width: 40, height: 40)

                        Text(isToday ? "Auj" : Self.dayNameFormatter.string(from: day.date).prefix(3).capitalized)
                            .font(.system(size: 10, weight: isToday ? .bold : .medium))
                            .foregroundColor(isToday ? .white.opacity(0.8) : .white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - This Week Section

    private var thisWeekSection: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cette semaine")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .kerning(1)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(thisWeekCompletions)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("actions")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            // Trend badge
            if lastWeekCompletions > 0 || thisWeekCompletions > 0 {
                let isUp = weekTrend >= 0
                HStack(spacing: 4) {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(abs(weekTrend))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Today Stats Row

    private var todayStatsRow: some View {
        HStack(spacing: 10) {
            statMiniCard(
                title: "Tâches",
                value: "\(tasksCompleted)/\(tasksTotal)",
                progress: tasksPct,
                color: .white,
                icon: "checkmark.circle.fill",
                delay: 0.4
            )
            statMiniCard(
                title: "Rituels",
                value: "\(ritualsCompleted)/\(ritualsTotal)",
                progress: ritualsPct,
                color: Color(hex: "#AAAAAA"),
                icon: "repeat",
                delay: 0.5
            )
            statMiniCard(
                title: "Focus",
                value: "\(focusMinutes) min",
                progress: focusPct,
                color: Color(hex: "#999999"),
                icon: "timer",
                delay: 0.6
            )
        }
        .padding(.horizontal, 16)
    }

    private func statMiniCard(title: String, value: String, progress: Double, color: Color, icon: String, delay: Double) -> some View {
        VStack(spacing: 10) {
            // Mini ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: appeared ? progress : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8).delay(delay), value: appeared)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            .frame(width: 40, height: 40)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Flame Levels (Simplified)

    private var flameLevelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current + Next level (always visible)
            let currentLevel = flameLevels.first { $0.isCurrent }
            let nextLevel = nextFlameLevel

            if let current = currentLevel {
                VStack(spacing: 14) {
                    // Current level — big display
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 50, height: 50)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 50, height: 50)
                                .shadow(color: .white.opacity(0.2), radius: 8)
                            Image(systemName: current.icon)
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(current.name)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Niv. \(current.level)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white.opacity(0.1)))
                            }
                            Text("Ton niveau actuel")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }

                        Spacer()
                    }

                    // Next level target
                    if let next = nextLevel {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.2))

                            Image(systemName: next.icon)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.3))

                            Text(next.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))

                            Spacer()

                            Text("dans \(max(0, next.daysRequired - currentStreak)) j")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.06))
                )
            }

            // Expandable all levels
            if flameLevels.count > 2 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showAllLevels.toggle()
                    }
                } label: {
                    HStack {
                        Text(showAllLevels ? "Masquer les niveaux" : "Voir tous les niveaux")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.25))
                            .rotationEffect(.degrees(showAllLevels ? 90 : 0))
                    }
                    .padding(.horizontal, 4)
                }

                if showAllLevels {
                    VStack(spacing: 0) {
                        ForEach(Array(flameLevels.enumerated()), id: \.element.id) { index, level in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(level.isUnlocked ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: level.icon)
                                        .font(.system(size: 13))
                                        .foregroundColor(level.isUnlocked ? .white : .white.opacity(0.15))
                                }

                                Text(level.name)
                                    .font(.system(size: 14, weight: level.isCurrent ? .bold : .medium))
                                    .foregroundColor(level.isUnlocked ? .white : .white.opacity(0.25))

                                Spacer()

                                Text("\(level.daysRequired)j")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.25))

                                if level.isUnlocked {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.04))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Load streak data
        do {
            streakData = try await streakService.fetchStreak()
        } catch {
            print("⚠️ Failed to load streak: \(error)")
        }

        // Load completions for last 14 days (for week comparison)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let from = calendar.date(byAdding: .day, value: -13, to: today) else { return }
        let fromStr = Self.dateFormatter.string(from: from)
        let toStr = Self.dateFormatter.string(from: today)

        do {
            let completions = try await completionsService.fetchCompletions(routineId: nil, from: fromStr, to: toStr)
            var byDate: [String: Int] = [:]
            for completion in completions {
                let dateKey = Self.dateFormatter.string(from: completion.completedAt)
                byDate[dateKey, default: 0] += 1
            }
            completionsByDate = byDate
        } catch {
            print("⚠️ Failed to load completions: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    StatsProfileView()
        .environmentObject(FocusAppStore.shared)
}
