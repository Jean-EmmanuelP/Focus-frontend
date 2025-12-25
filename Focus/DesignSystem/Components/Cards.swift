import SwiftUI

// MARK: - Card Base
struct Card<Content: View>: View {
    let content: Content
    var padding: CGFloat = SpacingTokens.md
    var elevated: Bool = false
    
    init(
        padding: CGFloat = SpacingTokens.md,
        elevated: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.elevated = elevated
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(elevated ? ColorTokens.surfaceElevated : ColorTokens.surface)
            .cornerRadius(RadiusTokens.lg)
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        Card(padding: SpacingTokens.md) {
            VStack(spacing: SpacingTokens.sm) {
                Text(icon)
                    .font(.inter(24))
                
                Text(value)
                    .heading2()
                    .foregroundColor(ColorTokens.textPrimary)
                
                Text(label)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Ritual Card (Simple)
struct RitualCard: View {
    let ritual: DailyRitual
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Icon (SF Symbol or emoji)
            if ritual.icon.count <= 2 {
                Text(ritual.icon)
                    .font(.inter(24))
            } else {
                Image(systemName: ritual.icon)
                    .font(.inter(20))
                    .foregroundColor(ColorTokens.primaryStart)
            }

            // Title
            Text(ritual.title)
                .bodyText()
                .foregroundColor(ColorTokens.textPrimary)

            Spacer()

            // Checkbox
            CheckboxView(isChecked: ritual.isCompleted) {
                onToggle(!ritual.isCompleted)
            }
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }
}

// MARK: - Full Screen Celebration
struct FullScreenCelebration: View {
    let completedCount: Int
    let totalCount: Int
    @Binding var isShowing: Bool

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var flameOffset: CGFloat = 50
    @State private var textOffset: CGFloat = 30

    var body: some View {
        ZStack {
            // Light overlay with blur
            ColorTokens.primaryStart.opacity(0.95)
                .ignoresSafeArea()
                .opacity(opacity)

            VStack(spacing: SpacingTokens.lg) {
                Spacer()

                // Flame
                Text("🔥")
                    .font(.inter(80))
                    .scaleEffect(scale)
                    .offset(y: flameOffset)

                // Message
                VStack(spacing: SpacingTokens.sm) {
                    Text("Nice!")
                        .font(.inter(32, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(completedCount)/\(totalCount) completed")
                        .font(.inter(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .offset(y: textOffset)
                .opacity(opacity)

                Spacer()
            }
        }
        .onAppear {
            // Animate in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
                flameOffset = 0
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                textOffset = 0
            }

            // Auto dismiss after 0.8s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.25)) {
                    opacity = 0
                    scale = 0.8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isShowing = false
                }
            }
        }
    }
}

// MARK: - Swipeable Ritual Card (Minimalist UX)
struct SwipeableRitualCard: View {
    let ritual: DailyRitual
    let completedCount: Int
    let totalCount: Int
    let onComplete: () -> Void
    var onUndo: (() -> Void)? = nil
    var onCelebrate: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil  // Added for tap to edit

    @State private var offset: CGFloat = 0
    @State private var isAnimating = false
    @State private var showSuccess = false
    @State private var cardScale: CGFloat = 1.0
    @State private var checkmarkScale: CGFloat = 0

    private let swipeThreshold: CGFloat = 80
    private let maxSwipe: CGFloat = 120

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let successHaptic = UINotificationFeedbackGenerator()

    private var swipeProgress: CGFloat {
        min(abs(offset) / swipeThreshold, 1.0)
    }

    private var isSwipingRight: Bool { offset > 0 }
    private var isSwipingLeft: Bool { offset < 0 }

    var body: some View {
        ZStack {
            // Background revealed on swipe
            HStack(spacing: 0) {
                // Left side - Complete (green)
                if isSwipingRight && !ritual.isCompleted {
                    ZStack {
                        LinearGradient(
                            colors: [ColorTokens.success, ColorTokens.success.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        Image(systemName: "checkmark")
                            .font(.inter(18, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(swipeProgress > 0.5 ? 1.0 : 0.5)
                            .opacity(swipeProgress)
                    }
                    .frame(width: max(0, offset + 20))
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                }

                Spacer()

                // Right side - Undo (orange/red)
                if isSwipingLeft && ritual.isCompleted {
                    ZStack {
                        LinearGradient(
                            colors: [ColorTokens.warning.opacity(0.8), ColorTokens.warning],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        Image(systemName: "arrow.uturn.backward")
                            .font(.inter(16, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(swipeProgress > 0.5 ? 1.0 : 0.5)
                            .opacity(swipeProgress)
                    }
                    .frame(width: max(0, abs(offset) + 20))
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                }
            }

            // Main card
            HStack(spacing: SpacingTokens.md) {
                // Icon
                ZStack {
                    if showSuccess || ritual.isCompleted {
                        Circle()
                            .fill(ColorTokens.success.opacity(ritual.isCompleted && !showSuccess ? 0.15 : 1.0))
                            .frame(width: 32, height: 32)

                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: ritual.isCompleted && !showSuccess ? .semibold : .bold))
                            .foregroundColor(ritual.isCompleted && !showSuccess ? ColorTokens.success : .white)
                            .scaleEffect(showSuccess ? checkmarkScale : 1.0)
                    } else {
                        if ritual.icon.count <= 2 {
                            Text(ritual.icon)
                                .font(.inter(22))
                        } else {
                            Image(systemName: ritual.icon)
                                .font(.inter(18))
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }
                }
                .frame(width: 32, height: 32)

                // Title
                Text(ritual.title)
                    .font(.inter(15, weight: .medium))
                    .foregroundColor(ritual.isCompleted ? ColorTokens.textMuted : ColorTokens.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Swipe hints
                if !isAnimating {
                    if ritual.isCompleted {
                        // Swipe left hint for undo
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.inter(10, weight: .medium))
                                .opacity(0.5)
                            Image(systemName: "chevron.left")
                                .font(.inter(10, weight: .medium))
                                .opacity(0.3)
                        }
                        .foregroundColor(ColorTokens.textMuted)
                        .opacity(1 - swipeProgress)
                    } else if !showSuccess {
                        // Swipe right hint
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.right")
                                .font(.inter(10, weight: .medium))
                                .opacity(0.3)
                            Image(systemName: "chevron.right")
                                .font(.inter(10, weight: .medium))
                                .opacity(0.5)
                        }
                        .foregroundColor(ColorTokens.textMuted)
                        .opacity(1 - swipeProgress)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.md)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ritual.isCompleted || showSuccess ? ColorTokens.success.opacity(0.08) : ColorTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(
                        ritual.isCompleted || showSuccess ? ColorTokens.success.opacity(0.2) : ColorTokens.border.opacity(0.5),
                        lineWidth: 1
                    )
            )
            .scaleEffect(cardScale)
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        guard !isAnimating else { return }
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        // Only handle horizontal swipes (not vertical scrolling)
                        // If vertical movement is greater, let ScrollView handle it
                        guard abs(horizontal) > abs(vertical) * 1.5 else { return }

                        // Swipe right to complete (only if not completed)
                        if horizontal > 0 && !ritual.isCompleted {
                            offset = horizontal < maxSwipe
                                ? horizontal
                                : maxSwipe + (horizontal - maxSwipe) * 0.3
                        }
                        // Swipe left to undo (only if completed)
                        else if horizontal < 0 && ritual.isCompleted {
                            offset = horizontal > -maxSwipe
                                ? horizontal
                                : -maxSwipe + (horizontal + maxSwipe) * 0.3
                        }

                        if swipeProgress >= 1.0 {
                            lightHaptic.prepare()
                        }
                    }
                    .onEnded { value in
                        guard !isAnimating else { return }
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        // Only process if it was a horizontal swipe
                        guard abs(horizontal) > abs(vertical) * 1.5 else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset = 0
                            }
                            return
                        }

                        // Complete action
                        if horizontal > swipeThreshold && !ritual.isCompleted {
                            completeRitual()
                        }
                        // Undo action
                        else if horizontal < -swipeThreshold && ritual.isCompleted {
                            undoRitual()
                        }
                        // Snap back
                        else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                // Tap to edit (if callback provided)
                if let onEdit = onEdit {
                    lightHaptic.impactOccurred()
                    onEdit()
                }
            }
        }
        .onAppear {
            lightHaptic.prepare()
            successHaptic.prepare()
        }
    }

    private func completeRitual() {
        isAnimating = true
        successHaptic.notificationOccurred(.success)

        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            offset = 60
            cardScale = 0.98
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                offset = 0
                cardScale = 1.0
                showSuccess = true
                checkmarkScale = 1.2
            }

            withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(0.1)) {
                checkmarkScale = 1.0
            }

            onCelebrate?()
            onComplete()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimating = false
                showSuccess = false
            }
        }
    }

    private func undoRitual() {
        isAnimating = true
        lightHaptic.impactOccurred()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            offset = -60
            cardScale = 0.98
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                offset = 0
                cardScale = 1.0
            }

            onUndo?()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }
    }
}

// MARK: - Progress Card
struct ProgressCard: View {
    let title: String
    let progress: Double
    let color: Color
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    Text(title)
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)
                }
                
                ProgressBar(progress: progress, color: color)
            }
        }
    }
}

// MARK: - Quest Card
struct QuestCard: View {
    let quest: Quest
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    HStack {
                        // Area tag
                        HStack(spacing: SpacingTokens.xs) {
                            Text(quest.area.emoji)
                                .font(.inter(14))
                            Text(quest.area.localizedName)
                                .caption()
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xs)
                        .background(Color(hex: quest.area.color).opacity(0.2))
                        .cornerRadius(RadiusTokens.sm)

                        Spacer()

                        // Status badge
                        if quest.status == .completed {
                            Text("✓")
                                .font(.inter(16))
                                .foregroundColor(ColorTokens.success)
                        }
                    }

                    // Title
                    Text(quest.title)
                        .subtitle()
                        .foregroundColor(ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)

                    // Progress
                    HStack(spacing: SpacingTokens.sm) {
                        ProgressBar(
                            progress: quest.progress,
                            color: Color(hex: quest.area.color),
                            height: 6
                        )

                        Text("\(Int(quest.progress * 100))%")
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Swipeable Quest Card (with progress slider)
struct SwipeableQuestCard: View {
    let quest: Quest
    let onProgressChange: (Double) -> Void
    let onEdit: () -> Void

    @State private var isDragging = false
    @State private var localProgress: Double

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let successHaptic = UINotificationFeedbackGenerator()

    init(quest: Quest, onProgressChange: @escaping (Double) -> Void, onEdit: @escaping () -> Void) {
        self.quest = quest
        self.onProgressChange = onProgressChange
        self.onEdit = onEdit
        self._localProgress = State(initialValue: quest.progress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            // Header row
            HStack {
                // Area tag
                HStack(spacing: SpacingTokens.xs) {
                    Text(quest.area.emoji)
                        .font(.inter(14))
                    Text(quest.area.localizedName)
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)
                .background(Color(hex: quest.area.color).opacity(0.2))
                .cornerRadius(RadiusTokens.sm)

                Spacer()

                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.inter(20))
                        .foregroundColor(ColorTokens.textMuted)
                }

                // Status badge
                if quest.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.inter(20))
                        .foregroundColor(ColorTokens.success)
                }
            }

            // Title
            Text(quest.title)
                .font(.inter(15, weight: .semibold))
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            // Interactive Progress Slider
            VStack(spacing: SpacingTokens.xs) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorTokens.surface)
                            .frame(height: 12)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: quest.area.color), Color(hex: quest.area.color).opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * localProgress, height: 12)

                        // Draggable thumb
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: quest.area.color), lineWidth: 3)
                            )
                            .offset(x: (geometry.size.width * localProgress) - 12)
                            .scaleEffect(isDragging ? 1.2 : 1.0)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    haptic.impactOccurred()
                                }
                                let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                // Snap to 10% increments
                                let snapped = (newProgress * 10).rounded() / 10
                                if snapped != localProgress {
                                    localProgress = snapped
                                    haptic.impactOccurred()
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                if localProgress != quest.progress {
                                    if localProgress >= 1.0 {
                                        successHaptic.notificationOccurred(.success)
                                    }
                                    onProgressChange(localProgress)
                                }
                            }
                    )
                }
                .frame(height: 24)

                // Progress label
                HStack {
                    Text("quests.swipe_to_update".localized)
                        .font(.inter(10))
                        .foregroundColor(ColorTokens.textMuted)

                    Spacer()

                    Text("\(Int(localProgress * 100))%")
                        .font(.inter(14, weight: .bold))
                        .foregroundColor(Color(hex: quest.area.color))
                }
            }
        }
        .padding(SpacingTokens.md)
        .background(localProgress >= 1.0 ? ColorTokens.success.opacity(0.08) : ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                .stroke(localProgress >= 1.0 ? ColorTokens.success.opacity(0.3) : ColorTokens.border, lineWidth: 1)
        )
        .onChange(of: quest.progress) { _, newValue in
            localProgress = newValue
        }
        .onAppear {
            haptic.prepare()
            successHaptic.prepare()
        }
    }
}

// MARK: - Streak Card
struct StreakCard: View {
    let days: Int
    
    var body: some View {
        Card(elevated: true) {
            HStack(spacing: SpacingTokens.md) {
                // Fire icon with glow
                ZStack {
                    Circle()
                        .fill(ColorTokens.primaryGlow)
                        .frame(width: 50, height: 50)
                        .blur(radius: 8)
                    
                    Text("🔥")
                        .font(.inter(28))
                }
                
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("\(days) days")
                        .heading2()
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    Text("Current Streak")
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Action Card (Adaptive CTA)
struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String?
    let buttonTitle: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Card(elevated: true) {
            VStack(spacing: SpacingTokens.md) {
                HStack {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        if let icon = icon {
                            Text(icon)
                                .font(.inter(24))
                        }
                        
                        Text(title)
                            .subtitle()
                            .foregroundColor(ColorTokens.textPrimary)
                        
                        Text(subtitle)
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                    
                    Spacer()
                }
                
                if isCompleted {
                    HStack {
                        Text("✓ Completed")
                            .bodyText()
                            .foregroundColor(ColorTokens.success)
                        Spacer()
                    }
                } else {
                    SecondaryButton(buttonTitle, action: action)
                }
            }
        }
    }
}

// MARK: - Quick Stat Card (Compact)
struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = ColorTokens.primaryStart

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(icon)
                .font(.inter(20))

            Text(value)
                .font(.inter(20, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.inter(10, weight: .medium))
                .foregroundColor(ColorTokens.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.md)
        .padding(.horizontal, SpacingTokens.sm)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }
}

// MARK: - Preview
#Preview("Cards") {
    ScrollView {
        VStack(spacing: SpacingTokens.lg) {
            MetricCard(icon: "🔥", value: "18", label: "This week")
            
            RitualCard(
                ritual: DailyRitual(
                    id: "1",
                    title: "Morning workout",
                    icon: "figure.run",
                    isCompleted: true,
                    category: .health
                )
            ) { _ in }
            
            ProgressCard(
                title: "Health",
                progress: 0.75,
                color: ColorTokens.success
            )
            
            QuestCard(
                quest: Quest(
                    id: "preview-1",
                    userId: "user-1",
                    title: "Build SaaS MVP",
                    area: .career,
                    progress: 0.65,
                    status: .active,
                    createdAt: Date(),
                    targetDate: nil
                ),
                onTap: {}
            )
            
            StreakCard(days: 12)
            
            ActionCard(
                title: "Start your day right",
                subtitle: "Complete your morning check-in",
                icon: "☀️",
                buttonTitle: "Start the Day",
                isCompleted: false,
                action: {}
            )
        }
        .padding()
    }
    .background(ColorTokens.background)
}
