import SwiftUI

// MARK: - Priority Button Row
struct PriorityButtonRow: View {
    @Binding var priority: TaskPriority

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(TaskPriority.allCases, id: \.self) { p in
                PriorityButton(priority: p, isSelected: priority == p) {
                    priority = p
                }
            }
        }
    }
}

struct PriorityButton: View {
    let priority: TaskPriority
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(priority.displayName)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : ColorTokens.textSecondary)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.sm)
                .background(backgroundGradient)
                .cornerRadius(RadiusTokens.md)
        }
    }

    private var backgroundGradient: LinearGradient {
        if isSelected {
            switch priority {
            case .low:
                return LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .top, endPoint: .bottom)
            case .medium:
                return LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
            case .high:
                return LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .top, endPoint: .bottom)
            case .urgent:
                return LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .top, endPoint: .bottom)
            }
        } else {
            return LinearGradient(colors: [ColorTokens.surface], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Estimated Time Button Row
struct EstimatedTimeButtonRow: View {
    @Binding var estimatedMinutes: Int
    let options: [Int] = [15, 30, 45, 60, 90]

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(options, id: \.self) { minutes in
                EstimatedTimeButton(minutes: minutes, isSelected: estimatedMinutes == minutes) {
                    estimatedMinutes = minutes
                }
            }
        }
    }
}

struct EstimatedTimeButton: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(minutes)m")
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : ColorTokens.textSecondary)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.sm)
                .background(isSelected ? ColorTokens.fireGradient : LinearGradient(colors: [ColorTokens.surface], startPoint: .top, endPoint: .bottom))
                .cornerRadius(RadiusTokens.md)
        }
    }
}

// MARK: - Quest Picker Section
struct QuestPickerSection: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var selectedQuestId: String?

    var body: some View {
        if !viewModel.quests.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("calendar.link_quest".localized)
                    .font(.satoshi(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)

                Menu {
                    Button(action: { selectedQuestId = nil }) {
                        Text("common.none".localized)
                    }

                    ForEach(viewModel.quests) { quest in
                        Button(action: { selectedQuestId = quest.id }) {
                            Text("\(quest.area.emoji) \(quest.title)")
                        }
                    }
                } label: {
                    QuestPickerLabel(viewModel: viewModel, selectedQuestId: selectedQuestId)
                }
            }
        }
    }
}

struct QuestPickerLabel: View {
    @ObservedObject var viewModel: CalendarViewModel
    let selectedQuestId: String?

    var body: some View {
        HStack {
            if let questId = selectedQuestId,
               let quest = viewModel.quests.first(where: { $0.id == questId }) {
                Text("\(quest.area.emoji) \(quest.title)")
                    .foregroundColor(ColorTokens.textPrimary)
            } else {
                Text("calendar.select_quest".localized)
                    .foregroundColor(ColorTokens.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.satoshi(12))
                .foregroundColor(ColorTokens.textMuted)
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }
}

// MARK: - Private Task Toggle Row
struct PrivateTaskToggleRow: View {
    @Binding var isPrivate: Bool

    var body: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(isPrivate ? ColorTokens.primaryStart : ColorTokens.textMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text("calendar.private_task".localized)
                    .font(.satoshi(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)
                Text("calendar.private_task_desc".localized)
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textMuted)
            }

            Spacer()

            Toggle("", isOn: $isPrivate)
                .labelsHidden()
                .tint(ColorTokens.primaryStart)
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }
}

// MARK: - AI Generate Day Sheet
struct AIGenerateDaySheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.xl) {
                        // Hero section
                        VStack(spacing: SpacingTokens.md) {
                            Text("✨")
                                .font(.satoshi(64))

                            Text("calendar.ai_plan_title".localized)
                                .font(.satoshi(24, weight: .bold))
                                .foregroundColor(ColorTokens.textPrimary)
                                .multilineTextAlignment(.center)

                            Text("calendar.ai_plan_subtitle".localized)
                                .font(.satoshi(14))
                                .foregroundColor(ColorTokens.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, SpacingTokens.xl)

                        // Prompt input
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("calendar.describe_your_day".localized)
                                .font(.satoshi(14, weight: .semibold))
                                .foregroundColor(ColorTokens.textSecondary)

                            TextEditor(text: $viewModel.idealDayPrompt)
                                .frame(minHeight: 150)
                                .padding(SpacingTokens.md)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                                        .stroke(isPromptFocused ? ColorTokens.primaryStart : ColorTokens.border, lineWidth: isPromptFocused ? 2 : 1)
                                )
                                .focused($isPromptFocused)

                            // Examples
                            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                Text("calendar.examples".localized)
                                    .font(.satoshi(12, weight: .semibold))
                                    .foregroundColor(ColorTokens.textMuted)

                                exampleChip("De 8h à 12h, je travaille sur le marketing")
                                exampleChip("Calls de sales de 14h à 17h")
                                exampleChip("Session de sport à 18h puis lecture")
                            }
                            .padding(.top, SpacingTokens.sm)
                        }

                        // Generate button
                        PrimaryButton(
                            "calendar.generate_plan".localized,
                            icon: "✨",
                            isLoading: viewModel.isGeneratingPlan
                        ) {
                            Task {
                                await viewModel.generateDayPlan()
                            }
                        }
                        .disabled(viewModel.idealDayPrompt.isEmpty)

                        Spacer()
                    }
                    .padding(SpacingTokens.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("calendar.plan_your_day".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }
            }
        }
    }

    private func exampleChip(_ text: String) -> some View {
        Button(action: {
            if viewModel.idealDayPrompt.isEmpty {
                viewModel.idealDayPrompt = text
            } else {
                viewModel.idealDayPrompt += "\n" + text
            }
        }) {
            Text(text)
                .font(.satoshi(12))
                .foregroundColor(ColorTokens.textSecondary)
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.sm)
        }
    }
}

// MARK: - Create Scheduled Task Sheet (formerly TimeBlock)
struct CreateScheduledTaskSheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600) // 1 hour later
    @State private var selectedQuestId: String?
    @State private var priority: TaskPriority = .medium
    @State private var isPrivate: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.lg) {
                        // Title
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("calendar.task_title".localized)
                                .font(.satoshi(14, weight: .semibold))
                                .foregroundColor(ColorTokens.textSecondary)

                            TextField("calendar.task_title_placeholder".localized, text: $title)
                                .textFieldStyle(.plain)
                                .padding(SpacingTokens.md)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.md)
                        }

                        // Description
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("calendar.task_description".localized)
                                .font(.satoshi(14, weight: .semibold))
                                .foregroundColor(ColorTokens.textSecondary)

                            TextField("calendar.task_description_placeholder".localized, text: $description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(2...4)
                                .padding(SpacingTokens.md)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.md)
                        }

                        // Time pickers
                        HStack(spacing: SpacingTokens.md) {
                            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                Text("calendar.start_time".localized)
                                    .font(.satoshi(14, weight: .semibold))
                                    .foregroundColor(ColorTokens.textSecondary)

                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(SpacingTokens.sm)
                                    .background(ColorTokens.surface)
                                    .cornerRadius(RadiusTokens.md)
                            }

                            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                Text("calendar.end_time".localized)
                                    .font(.satoshi(14, weight: .semibold))
                                    .foregroundColor(ColorTokens.textSecondary)

                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(SpacingTokens.sm)
                                    .background(ColorTokens.surface)
                                    .cornerRadius(RadiusTokens.md)
                            }
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("calendar.priority".localized)
                                .font(.satoshi(14, weight: .semibold))
                                .foregroundColor(ColorTokens.textSecondary)

                            PriorityButtonRow(priority: $priority)
                        }

                        // Link to Quest (optional)
                        QuestPickerSection(viewModel: viewModel, selectedQuestId: $selectedQuestId)

                        // Private toggle
                        PrivateTaskToggleRow(isPrivate: $isPrivate)

                        // Create button
                        PrimaryButton("calendar.create_task".localized) {
                            createTask()
                        }
                        .disabled(title.isEmpty)
                        .padding(.top, SpacingTokens.md)
                    }
                    .padding(SpacingTokens.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("calendar.new_task".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }
            }
        }
    }

    private func createTask() {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let scheduledStart = timeFormatter.string(from: startTime)
        let scheduledEnd = timeFormatter.string(from: endTime)

        // Determine time block based on start time
        let hour = Calendar.current.component(.hour, from: startTime)
        let timeBlock: String
        if hour < 12 {
            timeBlock = "morning"
        } else if hour < 18 {
            timeBlock = "afternoon"
        } else {
            timeBlock = "evening"
        }

        // Calculate estimated minutes
        let estimatedMinutes = Int(endTime.timeIntervalSince(startTime) / 60)

        Task {
            await viewModel.createTask(
                title: title,
                description: description.isEmpty ? nil : description,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
                timeBlock: timeBlock,
                questId: selectedQuestId,
                estimatedMinutes: estimatedMinutes,
                priority: priority.rawValue,
                isPrivate: isPrivate
            )
            dismiss()
        }
    }
}

// MARK: - Create Task Sheet
struct CreateTaskSheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    var timeBlock: String = "morning"
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var estimatedMinutes: Int = 30
    @State private var priority: TaskPriority = .medium
    @State private var selectedQuestId: String?
    @State private var isPrivate: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.lg) {
                        // Title
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("calendar.task_title".localized)
                                .font(.satoshi(14, weight: .semibold))
                                .foregroundColor(ColorTokens.textSecondary)

                            TextField("calendar.task_title_placeholder".localized, text: $title)
                                .textFieldStyle(.plain)
                                .padding(SpacingTokens.md)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.md)
                        }

                        // Description
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("calendar.task_description".localized)
                                .font(.satoshi(14, weight: .semibold))
                                .foregroundColor(ColorTokens.textSecondary)

                            TextField("calendar.task_description_placeholder".localized, text: $description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(2...4)
                                .padding(SpacingTokens.md)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.md)
                        }

                        // Estimated time
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("calendar.estimated_time".localized)
                                .font(.satoshi(14, weight: .semibold))
                                .foregroundColor(ColorTokens.textSecondary)

                            EstimatedTimeButtonRow(estimatedMinutes: $estimatedMinutes)
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("calendar.priority".localized)
                                .font(.satoshi(14, weight: .semibold))
                                .foregroundColor(ColorTokens.textSecondary)

                            PriorityButtonRow(priority: $priority)
                        }

                        // Link to Quest (optional)
                        QuestPickerSection(viewModel: viewModel, selectedQuestId: $selectedQuestId)

                        // Private toggle
                        PrivateTaskToggleRow(isPrivate: $isPrivate)

                        // Create button
                        PrimaryButton("calendar.create_task".localized) {
                            createTask()
                        }
                        .disabled(title.isEmpty)
                        .padding(.top, SpacingTokens.md)
                    }
                    .padding(SpacingTokens.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("calendar.new_task".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }
            }
        }
    }

    private func createTask() {
        Task {
            await viewModel.createTask(
                title: title,
                description: description.isEmpty ? nil : description,
                timeBlock: timeBlock,
                questId: selectedQuestId,
                estimatedMinutes: estimatedMinutes,
                priority: priority.rawValue,
                isPrivate: isPrivate
            )
            dismiss()
        }
    }
}
