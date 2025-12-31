//
//  WeeklyGoalsView.swift
//  Focus
//
//  Main view displaying weekly goals
//

import SwiftUI

struct WeeklyGoalsView: View {
    @StateObject private var viewModel = WeeklyGoalsViewModel()
    @ObservedObject private var store = FocusAppStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var hasLoaded = false
    @State private var showSetupSheet = false

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading {
                LoadingView(message: "Chargement...")
            } else if viewModel.hasGoalsThisWeek {
                goalsListView
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Weekly Goals")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.hasGoalsThisWeek {
                    Button {
                        viewModel.resetDraftGoals()
                        // Pre-fill with current goals
                        if let goals = viewModel.currentWeekGoals {
                            viewModel.draftGoals = goals.items.map { item in
                                DraftGoalItem(content: item.content, areaId: item.areaId)
                            }
                        }
                        showSetupSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(ColorTokens.primaryStart)
                    }
                }
            }
        }
        .sheet(isPresented: $showSetupSheet) {
            SetWeeklyGoalsSheet(viewModel: viewModel)
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            Task {
                await viewModel.loadCurrentWeekGoals()
            }
        }
    }

    // MARK: - Goals List View
    private var goalsListView: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Header with progress
                weekHeaderView

                // Goals list
                VStack(spacing: SpacingTokens.md) {
                    ForEach(viewModel.currentWeekGoals?.items ?? []) { item in
                        WeeklyGoalRowView(item: item, areas: store.areas) {
                            Task {
                                await viewModel.toggleGoalItem(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.md)

                Spacer(minLength: 100)
            }
            .padding(.top, SpacingTokens.md)
        }
    }

    // MARK: - Week Header
    private var weekHeaderView: some View {
        VStack(spacing: SpacingTokens.sm) {
            Text(viewModel.weekRangeString)
                .font(.subheadline)
                .foregroundColor(ColorTokens.textSecondary)

            // Progress ring
            ZStack {
                Circle()
                    .stroke(ColorTokens.surface, lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        LinearGradient(
                            colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)

                VStack(spacing: 2) {
                    Text("\(viewModel.completedCount)/\(viewModel.totalCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Text("complétés")
                        .font(.caption)
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .padding(.vertical, SpacingTokens.md)

            if viewModel.currentWeekGoals?.isComplete == true {
                Label("Tous les objectifs atteints !", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundColor(ColorTokens.success)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: SpacingTokens.lg) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Pas encore d'objectifs cette semaine")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            Text("Définis 3-5 objectifs pour rester focus et motivé toute la semaine")
                .font(.body)
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)

            PrimaryButton("Définir mes objectifs") {
                viewModel.resetDraftGoals()
                showSetupSheet = true
            }
            .padding(.horizontal, SpacingTokens.xl)
            .padding(.top, SpacingTokens.md)
        }
    }
}

// MARK: - Goal Row View
struct WeeklyGoalRowView: View {
    let item: WeeklyGoalItem
    let areas: [Area]
    let onToggle: () -> Void

    private var areaEmoji: String {
        if let areaId = item.areaId,
           let area = areas.first(where: { $0.id == areaId }) {
            return area.icon
        }
        return "🎯"
    }

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Checkbox
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            item.isCompleted
                                ? Color.clear
                                : ColorTokens.border,
                            lineWidth: 2
                        )
                        .background(
                            Circle()
                                .fill(
                                    item.isCompleted
                                        ? LinearGradient(
                                            colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
                                )
                        )
                        .frame(width: 28, height: 28)

                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            // Area emoji
            Text(areaEmoji)
                .font(.title2)

            // Content
            Text(item.content)
                .font(.body)
                .foregroundColor(item.isCompleted ? ColorTokens.textMuted : ColorTokens.textPrimary)
                .strikethrough(item.isCompleted, color: ColorTokens.textMuted)
                .lineLimit(2)

            Spacer()
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }
}

#Preview {
    WeeklyGoalsView()
}
