//
//  SetWeeklyGoalsSheet.swift
//  Focus
//
//  Sheet for creating/editing weekly goals
//

import SwiftUI

struct SetWeeklyGoalsSheet: View {
    @ObservedObject var viewModel: WeeklyGoalsViewModel
    @ObservedObject private var store = FocusAppStore.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.lg) {
                        // Header
                        headerView

                        // Goals list
                        goalsListView

                        // Add goal button
                        if viewModel.draftGoals.count < 5 {
                            addGoalButton
                        }

                        // Tip
                        tipView

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.top, SpacingTokens.md)
                }

                // Save button at bottom
                VStack {
                    Spacer()
                    saveButtonView
                }
            }
            .navigationTitle("Weekly Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .alert("Erreur", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: SpacingTokens.sm) {
            Text("🎯")
                .font(.system(size: 50))

            Text("Définis tes objectifs")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ColorTokens.textPrimary)

            Text(viewModel.weekRangeString)
                .font(.subheadline)
                .foregroundColor(ColorTokens.textSecondary)

            Text("Qu'est-ce que tu veux accomplir cette semaine ?")
                .font(.body)
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, SpacingTokens.md)
    }

    // MARK: - Goals List
    private var goalsListView: some View {
        VStack(spacing: SpacingTokens.md) {
            ForEach(Array(viewModel.draftGoals.enumerated()), id: \.element.id) { index, goal in
                DraftGoalRowView(
                    goal: goal,
                    index: index,
                    areas: store.areas,
                    isFocused: focusedField == index,
                    onContentChange: { content in
                        viewModel.updateDraftGoal(at: index, content: content)
                    },
                    onAreaChange: { areaId in
                        viewModel.updateDraftGoalArea(at: index, areaId: areaId)
                    },
                    onDelete: viewModel.draftGoals.count > 1 ? {
                        withAnimation {
                            viewModel.removeDraftGoal(at: index)
                        }
                    } : nil
                )
                .focused($focusedField, equals: index)
            }
        }
    }

    // MARK: - Add Goal Button
    private var addGoalButton: some View {
        Button {
            withAnimation {
                viewModel.addDraftGoal()
                focusedField = viewModel.draftGoals.count - 1
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(ColorTokens.primaryStart)
                Text("Ajouter un objectif")
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface.opacity(0.5))
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundColor(ColorTokens.border)
            )
        }
    }

    // MARK: - Tip View
    private var tipView: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(ColorTokens.warning)
            Text("Conseil : Sois spécifique et réaliste. 3-5 objectifs maximum pour rester focus.")
                .font(.caption)
                .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }

    // MARK: - Save Button
    private var saveButtonView: some View {
        VStack {
            PrimaryButton(
                viewModel.isSaving ? "Enregistrement..." : "Enregistrer mes objectifs",
                isLoading: viewModel.isSaving
            ) {
                Task {
                    let success = await viewModel.saveDraftGoals()
                    if success {
                        dismiss()
                    }
                }
            }
            .disabled(viewModel.isSaving || !hasValidGoals)
            .opacity(hasValidGoals ? 1 : 0.5)
        }
        .padding(SpacingTokens.md)
        .background(
            LinearGradient(
                colors: [ColorTokens.background.opacity(0), ColorTokens.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var hasValidGoals: Bool {
        viewModel.draftGoals.contains { !$0.content.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

// MARK: - Draft Goal Row View
struct DraftGoalRowView: View {
    let goal: DraftGoalItem
    let index: Int
    let areas: [Area]
    let isFocused: Bool
    let onContentChange: (String) -> Void
    let onAreaChange: (String?) -> Void
    let onDelete: (() -> Void)?

    @State private var showAreaPicker = false
    @State private var localContent: String

    init(goal: DraftGoalItem, index: Int, areas: [Area], isFocused: Bool, onContentChange: @escaping (String) -> Void, onAreaChange: @escaping (String?) -> Void, onDelete: (() -> Void)?) {
        self.goal = goal
        self.index = index
        self.areas = areas
        self.isFocused = isFocused
        self.onContentChange = onContentChange
        self.onAreaChange = onAreaChange
        self.onDelete = onDelete
        self._localContent = State(initialValue: goal.content)
    }

    private var currentAreaEmoji: String {
        if let areaId = goal.areaId,
           let area = areas.first(where: { $0.id == areaId }) {
            return area.icon
        }
        return "🎯"
    }

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            // Area picker button
            Button {
                showAreaPicker = true
            } label: {
                Text(currentAreaEmoji)
                    .font(.title)
                    .frame(width: 44, height: 44)
                    .background(ColorTokens.surfaceElevated)
                    .cornerRadius(RadiusTokens.sm)
            }

            // Text field
            TextField("Objectif \(index + 1)", text: $localContent)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundColor(ColorTokens.textPrimary)
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .strokeBorder(
                            isFocused ? ColorTokens.primaryStart : Color.clear,
                            lineWidth: 2
                        )
                )
                .onChange(of: localContent) { _, newValue in
                    onContentChange(newValue)
                }

            // Delete button
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorTokens.textMuted)
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAreaPicker) {
            areaPickerSheet
        }
    }

    private var areaPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.sm) {
                    // Default option (no area)
                    Button {
                        onAreaChange(nil)
                        showAreaPicker = false
                    } label: {
                        HStack {
                            Text("🎯")
                                .font(.title)
                            Text("Général")
                                .font(.body)
                                .foregroundColor(ColorTokens.textPrimary)
                            Spacer()
                            if goal.areaId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ColorTokens.primaryStart)
                            }
                        }
                        .padding(SpacingTokens.md)
                        .background(goal.areaId == nil ? ColorTokens.primarySoft : ColorTokens.surface)
                        .cornerRadius(RadiusTokens.md)
                    }

                    // Areas
                    ForEach(areas) { area in
                        Button {
                            onAreaChange(area.id)
                            showAreaPicker = false
                        } label: {
                            HStack {
                                Text(area.icon)
                                    .font(.title)
                                Text(area.name)
                                    .font(.body)
                                    .foregroundColor(ColorTokens.textPrimary)
                                Spacer()
                                if goal.areaId == area.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(ColorTokens.primaryStart)
                                }
                            }
                            .padding(SpacingTokens.md)
                            .background(goal.areaId == area.id ? ColorTokens.primarySoft : ColorTokens.surface)
                            .cornerRadius(RadiusTokens.md)
                        }
                    }
                }
                .padding(SpacingTokens.md)
            }
            .background(ColorTokens.background)
            .navigationTitle("Choisir un domaine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        showAreaPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SetWeeklyGoalsSheet(viewModel: WeeklyGoalsViewModel())
}
