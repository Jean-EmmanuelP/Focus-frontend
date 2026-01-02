import SwiftUI

struct ChatView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var viewModel = ChatViewModel()
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                chatHeader

                // Messages
                messagesScrollView

                // Quick actions (when no text input)
                if viewModel.inputText.isEmpty && !viewModel.isLoading {
                    quickActions
                }

                // Input bar
                ChatInputBar(
                    text: $viewModel.inputText,
                    isRecording: viewModel.isRecording,
                    isLoading: viewModel.isLoading,
                    onSend: {
                        viewModel.sendMessage()
                        scrollToBottom()
                    },
                    onMicTap: {
                        viewModel.startRecording()
                    },
                    onMicRelease: {
                        viewModel.stopRecording()
                    }
                )
            }

            // Recording overlay
            VoiceRecordingOverlay(
                isRecording: viewModel.isRecording,
                onCancel: {
                    viewModel.stopRecording()
                }
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setStore(store)
            viewModel.checkForDailyGreeting()
        }
        .sheet(isPresented: $viewModel.showPlanDay) {
            PlanYourDayView()
                .onDisappear {
                    viewModel.addToolCompletionMessage(
                        tool: .planDay,
                        summary: "Ta journée est planifiée. Maintenant, exécute. 💪"
                    )
                }
        }
        .sheet(isPresented: $viewModel.showWeeklyGoals) {
            NavigationStack {
                WeeklyGoalsView()
            }
            .onDisappear {
                viewModel.addToolCompletionMessage(
                    tool: .weeklyGoals,
                    summary: "Objectifs définis. Reste focalisé sur ce qui compte."
                )
            }
        }
        .sheet(isPresented: $viewModel.showDailyReflection) {
            NavigationStack {
                EndOfDayView()
            }
            .onDisappear {
                viewModel.addToolCompletionMessage(
                    tool: .dailyReflection,
                    summary: "Réflexion enregistrée. Repose-toi bien."
                )
            }
        }
        .sheet(isPresented: $viewModel.showMoodPicker) {
            moodPickerSheet
        }
        .alert("Erreur", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Une erreur est survenue")
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: SpacingTokens.md) {
            // Coach avatar
            ZStack {
                Circle()
                    .fill(ColorTokens.surface)
                    .frame(width: 40, height: 40)

                Image(systemName: CoachPersona.avatarIcon)
                    .font(.system(size: 20))
                    .foregroundColor(ColorTokens.primaryStart)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(CoachPersona.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Ton coach")
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()

            // Streak badge
            if store.currentStreak > 0 {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 14))
                    Text("\(store.currentStreak)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ColorTokens.primaryStart)
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(ColorTokens.primarySoft)
                )
            }

            // Menu
            Menu {
                Button(role: .destructive) {
                    viewModel.clearChat()
                } label: {
                    Label("Effacer la conversation", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(
            Rectangle()
                .fill(ColorTokens.background)
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        )
    }

    // MARK: - Messages ScrollView

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: SpacingTokens.md) {
                    ForEach(viewModel.messages) { message in
                        ChatMessageBubble(
                            message: message,
                            onToolTap: { tool in
                                viewModel.handleToolAction(tool)
                            }
                        )
                        .id(message.id)
                    }

                    // Loading indicator
                    if viewModel.isLoading {
                        loadingIndicator
                    }

                    // Bottom spacer for scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, SpacingTokens.md)
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom()
            }
        }
    }

    private var loadingIndicator: some View {
        HStack(spacing: SpacingTokens.sm) {
            // Coach avatar
            ZStack {
                Circle()
                    .fill(ColorTokens.surface)
                    .frame(width: 32, height: 32)

                Image(systemName: CoachPersona.avatarIcon)
                    .font(.system(size: 16))
                    .foregroundColor(ColorTokens.primaryStart)
            }

            // Typing indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(ColorTokens.textMuted)
                        .frame(width: 8, height: 8)
                        .opacity(0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: viewModel.isLoading
                        )
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTokens.surface)
            )

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        ChatQuickActions(
            suggestedTools: suggestedToolsForContext(),
            onToolTap: { tool in
                viewModel.handleToolAction(tool)
            }
        )
        .padding(.vertical, SpacingTokens.sm)
    }

    private func suggestedToolsForContext() -> [ChatTool] {
        let context = viewModel.buildContext()

        switch context.timeOfDay {
        case .morning:
            return [.planDay, .startFocus, .weeklyGoals]
        case .afternoon:
            return [.startFocus, .viewStats, .planDay]
        case .evening, .night:
            return [.dailyReflection, .viewStats, .logMood]
        }
    }

    // MARK: - Mood Picker Sheet

    private var moodPickerSheet: some View {
        VStack(spacing: SpacingTokens.xl) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(ColorTokens.textMuted)
                .frame(width: 40, height: 4)
                .padding(.top, SpacingTokens.md)

            ChatMoodPicker(
                selectedMood: .constant(nil),
                onSelect: { mood in
                    viewModel.showMoodPicker = false
                    viewModel.addToolCompletionMessage(
                        tool: .logMood,
                        summary: getMoodResponse(mood)
                    )
                }
            )
            .padding(.horizontal, SpacingTokens.lg)

            Spacer()
        }
        .background(ColorTokens.background)
        .presentationDetents([.height(250)])
    }

    private func getMoodResponse(_ mood: Int) -> String {
        switch mood {
        case 1:
            return "Les jours difficiles font partie du chemin. Qu'est-ce qui te pèse ?"
        case 2:
            return "Pas la meilleure journée. C'est ok. Qu'est-ce qui pourrait t'aider ?"
        case 3:
            return "Neutre. Parfois c'est comme ça. Qu'est-ce qui pourrait améliorer ta journée ?"
        case 4:
            return "Bien. Continue sur cette lancée."
        case 5:
            return "Super ! Qu'est-ce qui contribue à cette énergie positive ?"
        default:
            return "Merci de partager."
        }
    }

    // MARK: - Helpers

    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
        .environmentObject(FocusAppStore.shared)
}
