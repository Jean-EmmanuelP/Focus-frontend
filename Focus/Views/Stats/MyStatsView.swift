import SwiftUI

struct MyStatsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var stats: MyStatsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPeriod: StatsPeriod = .week

    enum StatsPeriod: String, CaseIterable {
        case week = "stats.week"
        case month = "stats.month"

        var localizedName: String {
            rawValue.localized
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                } else if let error = errorMessage {
                    VStack(spacing: SpacingTokens.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.satoshi(40))
                            .foregroundColor(ColorTokens.warning)
                        Text(error)
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("common.retry".localized) {
                            Task { await loadStats() }
                        }
                        .foregroundColor(ColorTokens.primaryStart)
                    }
                    .padding()
                } else if let stats = stats {
                    ScrollView {
                        VStack(spacing: SpacingTokens.lg) {
                            // Period selector
                            periodSelector

                            // Summary cards
                            summaryCards(stats: stats)

                            // Focus graph
                            focusGraphSection(stats: stats)

                            // Routines graph
                            routinesGraphSection(stats: stats)
                        }
                        .padding(SpacingTokens.lg)
                    }
                }
            }
            .navigationTitle("stats.my_statistics".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
        .task {
            await loadStats()
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(StatsPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.localizedName)
                        .bodyText()
                        .fontWeight(.medium)
                        .foregroundColor(selectedPeriod == period ? .white : ColorTokens.textSecondary)
                        .padding(.horizontal, SpacingTokens.lg)
                        .padding(.vertical, SpacingTokens.sm)
                        .background(selectedPeriod == period ? ColorTokens.primaryStart : ColorTokens.surface)
                        .cornerRadius(RadiusTokens.md)
                }
            }
        }
    }

    // MARK: - Summary Cards

    private func summaryCards(stats: MyStatsResponse) -> some View {
        let focusMinutes = selectedPeriod == .week ? (stats.weeklyTotalFocus ?? 0) : (stats.monthlyTotalFocus ?? 0)
        let routinesDone = selectedPeriod == .week ? (stats.weeklyTotalRoutines ?? 0) : (stats.monthlyTotalRoutines ?? 0)
        let totalRoutines = stats.totalRoutines ?? 0
        // Fix: Show 0% if no routines exist
        let routineRate = totalRoutines > 0 ? (stats.weeklyRoutineRate ?? 0) : 0
        let possibleRoutines = selectedPeriod == .week ? totalRoutines * 7 : totalRoutines * 30

        return VStack(spacing: SpacingTokens.md) {
            HStack(spacing: SpacingTokens.md) {
                StatSummaryCard(
                    title: "stats.focus_time".localized,
                    value: formatMinutes(focusMinutes),
                    subtitle: selectedPeriod == .week ? "stats.this_week".localized : "stats.this_month".localized,
                    icon: "flame.fill",
                    color: ColorTokens.primaryStart
                )

                StatSummaryCard(
                    title: "stats.avg_daily".localized,
                    value: formatMinutes(selectedPeriod == .week ? (stats.weeklyAvgFocus ?? 0) : (focusMinutes / 30)),
                    subtitle: "stats.focus_time".localized,
                    icon: "clock.fill",
                    color: .blue
                )
            }

            HStack(spacing: SpacingTokens.md) {
                StatSummaryCard(
                    title: "stats.routines".localized,
                    value: "\(routinesDone)/\(possibleRoutines)",
                    subtitle: "stats.completed".localized,
                    icon: "checkmark.circle.fill",
                    color: ColorTokens.success
                )

                StatSummaryCard(
                    title: "stats.completion".localized,
                    value: "\(routineRate)%",
                    subtitle: "stats.rate".localized,
                    icon: "chart.pie.fill",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Focus Graph Section

    private func focusGraphSection(stats: MyStatsResponse) -> some View {
        let data = selectedPeriod == .week
            ? (stats.weeklyFocusMinutes ?? [])
            : (stats.monthlyFocusMinutes ?? [])

        return Card {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(ColorTokens.primaryStart)
                    Text("stats.focus_sessions".localized)
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()
                    Text(selectedPeriod == .week ? "stats.last_7_days".localized : "stats.last_30_days".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                if data.isEmpty {
                    Text("stats.no_sessions".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.lg)
                } else {
                    if selectedPeriod == .week {
                        WeeklyBarChart(data: data, color: ColorTokens.primaryStart)
                    } else {
                        MonthlyBarChart(data: data, color: ColorTokens.primaryStart)
                    }
                }
            }
        }
    }

    // MARK: - Routines Graph Section

    private func routinesGraphSection(stats: MyStatsResponse) -> some View {
        let data = selectedPeriod == .week
            ? (stats.weeklyRoutinesDone ?? [])
            : (stats.monthlyRoutinesDone ?? [])

        return Card {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ColorTokens.success)
                    Text("stats.daily_routines".localized)
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()
                    Text(selectedPeriod == .week ? "stats.last_7_days".localized : "stats.last_30_days".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                if data.isEmpty {
                    Text("stats.no_routines".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.lg)
                } else {
                    if selectedPeriod == .week {
                        WeeklyBarChart(data: data, color: ColorTokens.success)
                    } else {
                        MonthlyBarChart(data: data, color: ColorTokens.success)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }

    private func loadStats() async {
        isLoading = true
        errorMessage = nil

        do {
            let crewService = CrewService()
            stats = try await crewService.fetchMyStats()
        } catch {
            errorMessage = "stats.failed_to_load".localized
        }

        isLoading = false
    }
}

// MARK: - Monthly Bar Chart (for 30 days)

struct MonthlyBarChart: View {
    let data: [DailyStat]
    let color: Color

    private var maxValue: Int {
        data.map { $0.value }.max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.width < 350
            let chartHeight: CGFloat = isSmallScreen ? 70 : 90
            let barWidth: CGFloat = isSmallScreen ? 6 : 8

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: isSmallScreen ? 3 : 4) {
                    ForEach(data) { stat in
                        VStack(spacing: 2) {
                            // Bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(stat.value > 0 ? color : ColorTokens.surface)
                                .frame(width: barWidth, height: barHeight(for: stat.value, maxHeight: chartHeight - 20))

                            // Day number (show every 5th day)
                            if shouldShowLabel(for: stat.date) {
                                Text(dayNumber(from: stat.date))
                                    .font(.system(size: isSmallScreen ? 7 : 8))
                                    .foregroundColor(ColorTokens.textMuted)
                            } else {
                                Text("")
                                    .font(.system(size: isSmallScreen ? 7 : 8))
                            }
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.sm)
            }
            .frame(height: chartHeight)
        }
        .frame(height: 90) // Keep overall frame for layout
    }

    private func barHeight(for value: Int, maxHeight: CGFloat = 60) -> CGFloat {
        let minHeight: CGFloat = 2
        guard maxValue > 0 else { return minHeight }
        let ratio = CGFloat(value) / CGFloat(maxValue)
        return max(minHeight, ratio * maxHeight)
    }

    private func dayNumber(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return String(dateString.suffix(2))
        }
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        return "\(day)"
    }

    private func shouldShowLabel(for dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return false }
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        return day % 5 == 1 || day == 1
    }
}

#Preview {
    MyStatsView()
}
