import SwiftUI

/// Sheet displaying flame level progression and streak requirements
struct FlameInfoSheet: View {
    let currentStreak: Int
    let flameLevels: [FlameLevel]
    let todayValidation: DayValidationResponse?
    @Environment(\.dismiss) private var dismiss

    private var currentLevel: FlameLevel? {
        flameLevels.first(where: { $0.isCurrent })
    }

    private var nextLevel: FlameLevel? {
        guard let current = currentLevel else { return nil }
        return flameLevels.first(where: { $0.level == current.level + 1 })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.xl) {
                    // Current Level Hero
                    currentLevelSection

                    // Progress to Next Level
                    if let next = nextLevel {
                        nextLevelSection(next: next)
                    }

                    // All Levels
                    allLevelsSection

                    // Requirements Section
                    requirementsSection
                }
                .padding(SpacingTokens.lg)
            }
            .background(ColorTokens.background)
            .navigationTitle("flame.info_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
            }
        }
    }

    // MARK: - Current Level Section
    private var currentLevelSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // Large flame icon
            Text(currentLevel?.icon ?? "🔥")
                .font(.system(size: 80))
                .shadow(color: ColorTokens.primaryStart.opacity(0.6), radius: 20)

            // Level name
            Text(currentLevel?.name.uppercased() ?? "SPARK")
                .font(.inter(24, weight: .bold))
                .foregroundColor(ColorTokens.primaryStart)

            // Day count
            Text("streak.day_count".localized(with: currentStreak))
                .font(.inter(18, weight: .medium))
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.xl)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.xl)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Next Level Section
    private func nextLevelSection(next: FlameLevel) -> some View {
        let daysToNext = next.daysRequired - currentStreak

        return VStack(spacing: SpacingTokens.sm) {
            HStack {
                Text("flame.next_level".localized)
                    .font(.inter(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
                Spacer()
            }

            HStack(spacing: SpacingTokens.md) {
                Text(next.icon)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 2) {
                    Text(next.name)
                        .font(.inter(16, weight: .bold))
                        .foregroundColor(.white)

                    Text("flame.days_remaining".localized(with: daysToNext))
                        .font(.inter(13))
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()

                // Progress indicator
                Text("\(currentStreak)/\(next.daysRequired)")
                    .font(.inter(14, weight: .bold))
                    .foregroundColor(ColorTokens.primaryStart)
            }
            .padding(SpacingTokens.md)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .fill(ColorTokens.surface)
            )
        }
    }

    // MARK: - All Levels Section
    private var allLevelsSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            HStack {
                Text("flame.all_levels".localized)
                    .font(.inter(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
                Spacer()
            }

            VStack(spacing: SpacingTokens.xs) {
                ForEach(flameLevels, id: \.level) { level in
                    flameLevelRow(level: level)
                }
            }
        }
    }

    private func flameLevelRow(level: FlameLevel) -> some View {
        let isCurrentOrPast = level.isUnlocked
        let isCurrent = level.isCurrent

        return HStack(spacing: SpacingTokens.md) {
            // Icon
            Text(level.icon)
                .font(.system(size: 24))
                .opacity(isCurrentOrPast ? 1.0 : 0.4)

            // Name and days required
            VStack(alignment: .leading, spacing: 2) {
                Text(level.name)
                    .font(.inter(14, weight: isCurrent ? .bold : .medium))
                    .foregroundColor(isCurrentOrPast ? .white : ColorTokens.textMuted)

                Text("flame.days_required".localized(with: level.daysRequired))
                    .font(.inter(11))
                    .foregroundColor(ColorTokens.textMuted)
            }

            Spacer()

            // Status indicator
            if isCurrent {
                Text("flame.current".localized)
                    .font(.inter(11, weight: .bold))
                    .foregroundColor(ColorTokens.primaryStart)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, SpacingTokens.xs)
                    .background(ColorTokens.primaryStart.opacity(0.15))
                    .cornerRadius(RadiusTokens.sm)
            } else if isCurrentOrPast {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ColorTokens.success)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(ColorTokens.textMuted)
                    .font(.system(size: 12))
            }
        }
        .padding(SpacingTokens.md)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(isCurrent ? ColorTokens.primaryStart.opacity(0.1) : ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .stroke(isCurrent ? ColorTokens.primaryStart.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }

    // MARK: - Requirements Section
    private var requirementsSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ColorTokens.primaryStart)
                Text("flame.how_to_maintain".localized)
                    .font(.inter(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
                Spacer()
            }

            VStack(spacing: SpacingTokens.xs) {
                if let validation = todayValidation {
                    requirementRow(
                        icon: "checkmark.circle.fill",
                        text: "streak.requirement_completion".localized(with: validation.requiredCompletionRate),
                        current: "\(validation.overallRate)%",
                        isMet: validation.meetsCompletionRate
                    )

                    requirementRow(
                        icon: "list.bullet",
                        text: "streak.requirement_tasks".localized(with: validation.requiredMinTasks),
                        current: "\(validation.totalItems)/\(validation.requiredMinTasks)",
                        isMet: validation.meetsMinTasks
                    )
                } else {
                    // Default requirements when data not loaded
                    Text("flame.requirements_loading".localized)
                        .font(.inter(13))
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SpacingTokens.md)
                }
            }
            .padding(SpacingTokens.md)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .fill(ColorTokens.surface)
            )
        }
    }

    private func requirementRow(icon: String, text: String, current: String, isMet: Bool) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: icon)
                .foregroundColor(isMet ? ColorTokens.success : ColorTokens.warning)
                .frame(width: 20)

            Text(text)
                .font(.inter(13))
                .foregroundColor(ColorTokens.textPrimary)

            Spacer()

            Text(current)
                .font(.inter(13, weight: .bold))
                .foregroundColor(isMet ? ColorTokens.success : ColorTokens.warning)

            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? ColorTokens.success : ColorTokens.textMuted)
                .font(.system(size: 16))
        }
    }
}

#Preview {
    FlameInfoSheet(
        currentStreak: 42,
        flameLevels: [
            FlameLevel(level: 1, name: "Spark", icon: "🔥", daysRequired: 0, isUnlocked: true, isCurrent: false),
            FlameLevel(level: 2, name: "Ember", icon: "🔥", daysRequired: 7, isUnlocked: true, isCurrent: false),
            FlameLevel(level: 3, name: "Blaze", icon: "🔥", daysRequired: 30, isUnlocked: true, isCurrent: true),
            FlameLevel(level: 4, name: "Inferno", icon: "🔥", daysRequired: 60, isUnlocked: false, isCurrent: false),
            FlameLevel(level: 5, name: "Phoenix", icon: "🔥", daysRequired: 100, isUnlocked: false, isCurrent: false)
        ],
        todayValidation: DayValidationResponse(
            date: "2025-01-15",
            hasIntention: true,
            totalRoutines: 3,
            completedRoutines: 2,
            routineRate: 67,
            totalTasks: 6,
            completedTasks: 5,
            taskRate: 83,
            totalItems: 9,
            completedItems: 7,
            overallRate: 78,
            isValid: true,
            requiredCompletionRate: 60,
            requiredMinTasks: 1,
            meetsCompletionRate: true,
            meetsMinTasks: true
        )
    )
}
