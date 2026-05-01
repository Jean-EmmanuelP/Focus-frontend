import SwiftUI

struct LeaderboardView: View {
    var onDismiss: (() -> Void)? = nil

    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var appeared = false

    private var currentUserId: String? {
        FocusAppStore.shared.user?.id
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#000000"),
                    Color(hex: "#0A0A0A"),
                    Color(hex: "#000000")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle glow behind podium
            if !viewModel.entries.isEmpty {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(y: -60)
                    .blur(radius: 40)
            }

            VStack(spacing: 0) {
                header
                scopeToggle
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Spacer()
                } else if viewModel.entries.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Podium
                            if viewModel.podiumEntries.count >= 3 {
                                podiumSection
                                    .padding(.top, 28)
                                    .padding(.bottom, 24)
                            }

                            // Separator
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                                .padding(.horizontal, 20)

                            // List
                            if !viewModel.remainingEntries.isEmpty {
                                listSection
                                    .padding(.top, 12)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task {
            await viewModel.loadLeaderboard()
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ColorTokens.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Spacer()

            // Title with icon
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white, Color.white.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                Text("Classement")
                    .font(.satoshi(18, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Scope Toggle

    private var scopeToggle: some View {
        HStack(spacing: 4) {
            ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.switchScope(to: scope)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: scope == .global ? "globe" : "person.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(scope.title)
                            .font(.satoshi(13, weight: .bold))
                    }
                    .foregroundColor(viewModel.scope == scope ? .white : ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        Capsule()
                            .fill(viewModel.scope == scope
                                  ? AnyShapeStyle(LinearGradient(colors: [ColorTokens.accent, ColorTokens.accent.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.clear))
                    )
                }
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.04))
                .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - Podium

    private var podiumSection: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if viewModel.podiumEntries.count >= 3 {
                // #2
                podiumItem(entry: viewModel.podiumEntries[1], place: 2)
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)

                // #1
                podiumItem(entry: viewModel.podiumEntries[0], place: 1)
                    .offset(y: appeared ? 0 : 40)
                    .opacity(appeared ? 1 : 0)

                // #3
                podiumItem(entry: viewModel.podiumEntries[2], place: 3)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .padding(.horizontal, 16)
    }

    private func podiumColor(_ place: Int) -> Color {
        switch place {
        case 1: return Color.white
        case 2: return Color.white.opacity(0.7)
        case 3: return Color.white.opacity(0.5)
        default: return ColorTokens.textSecondary
        }
    }

    private func podiumHeight(_ place: Int) -> CGFloat {
        switch place {
        case 1: return 80
        case 2: return 56
        case 3: return 40
        default: return 40
        }
    }

    private func podiumItem(entry: LeaderboardEntry, place: Int) -> some View {
        let color = podiumColor(place)
        let isCurrentUser = entry.id == currentUserId

        return VStack(spacing: 0) {
            // Crown for #1
            if place == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white, Color.white.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color.white.opacity(0.4), radius: 8)
                    .padding(.bottom, 4)
            }

            // Avatar with glow
            ZStack {
                // Outer glow for #1
                if place == 1 {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 76, height: 76)
                        .blur(radius: 8)
                }

                avatarView(
                    url: entry.avatarUrl,
                    initial: entry.initial,
                    size: place == 1 ? 68 : 52,
                    borderColor: color,
                    borderWidth: place == 1 ? 3 : 2
                )
                .shadow(color: color.opacity(0.3), radius: place == 1 ? 12 : 6)
            }
            .padding(.bottom, 8)

            // Name
            Text(isCurrentUser ? "Toi" : entry.displayName)
                .font(.satoshi(12, weight: .bold))
                .foregroundColor(isCurrentUser ? ColorTokens.accent : .white)
                .lineLimit(1)

            // Score
            Text("\(entry.formattedScore) pts")
                .font(.satoshi(11, weight: .medium))
                .foregroundColor(color.opacity(0.8))
                .padding(.top, 1)

            // Streak pill
            if entry.currentStreak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                    Text("\(entry.currentStreak)")
                        .font(.satoshi(9, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .padding(.top, 4)
            }

            Spacer().frame(height: 10)

            // Pedestal
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(color.opacity(0.2), lineWidth: 0.5)
                    )

                Text("#\(entry.rank)")
                    .font(.satoshi(20, weight: .black))
                    .foregroundColor(color.opacity(0.6))
            }
            .frame(height: podiumHeight(place))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    private var listSection: some View {
        VStack(spacing: 6) {
            ForEach(Array(viewModel.remainingEntries.enumerated()), id: \.element.id) { index, entry in
                leaderboardRow(entry: entry)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.04), value: appeared)
            }
        }
        .padding(.horizontal, 16)
    }

    private func leaderboardRow(entry: LeaderboardEntry) -> some View {
        let isCurrentUser = entry.id == currentUserId

        return HStack(spacing: 12) {
            // Rank badge
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isCurrentUser ? ColorTokens.accent.opacity(0.15) : Color.white.opacity(0.04))
                    .frame(width: 32, height: 32)
                Text("\(entry.rank)")
                    .font(.satoshi(13, weight: .black))
                    .foregroundColor(isCurrentUser ? ColorTokens.accent : ColorTokens.textSecondary)
            }

            // Avatar
            avatarView(
                url: entry.avatarUrl,
                initial: entry.initial,
                size: 38,
                borderColor: isCurrentUser ? ColorTokens.accent.opacity(0.5) : Color.white.opacity(0.08),
                borderWidth: 1.5
            )

            // Name + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentUser ? "Toi" : entry.displayName)
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(isCurrentUser ? ColorTokens.accent : .white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if entry.totalFocusMinutes > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "timer")
                                .font(.system(size: 9))
                            Text("\(entry.totalFocusMinutes)m")
                                .font(.satoshi(11, weight: .medium))
                        }
                        .foregroundColor(ColorTokens.textSecondary)
                    }
                    if entry.tasksCreated > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 9))
                            Text("\(entry.tasksCompleted)/\(entry.tasksCreated)")
                                .font(.satoshi(11, weight: .medium))
                        }
                        .foregroundColor(ColorTokens.textSecondary)
                    }
                }
            }

            Spacer()

            // Streak badge
            if entry.currentStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Text("\(entry.currentStreak)")
                        .font(.satoshi(11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }

            // Score
            VStack(spacing: 1) {
                Text(entry.formattedScore)
                    .font(.satoshi(16, weight: .black))
                    .foregroundColor(isCurrentUser ? ColorTokens.accent : .white)
                Text("pts")
                    .font(.satoshi(9, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .frame(width: 40)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCurrentUser ? ColorTokens.accent.opacity(0.06) : Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isCurrentUser ? ColorTokens.accent.opacity(0.2) : Color.white.opacity(0.04),
                            lineWidth: 0.5
                        )
                )
        )
    }

    // MARK: - Avatar Helper

    private func avatarView(url: String?, initial: String, size: CGFloat, borderColor: Color?, borderWidth: CGFloat) -> some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialCircle(initial: initial, size: size)
                    }
                }
            } else {
                initialCircle(initial: initial, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(borderColor ?? .clear, lineWidth: borderWidth))
    }

    private func initialCircle(initial: String, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [ColorTokens.accent.opacity(0.3), ColorTokens.accent.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Text(initial)
                .font(.satoshi(size * 0.38, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(ColorTokens.accent.opacity(0.06))
                    .frame(width: 100, height: 100)
                Image(systemName: viewModel.scope == .friends ? "person.2" : "chart.bar")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [ColorTokens.accent, ColorTokens.accent.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 8) {
                Text(viewModel.scope == .friends ? "Pas encore d'amis" : "Aucun classement")
                    .font(.satoshi(18, weight: .bold))
                    .foregroundColor(.white)

                Text(viewModel.scope == .friends ? "Ajoute des amis pour voir\nleur classement ici" : "Lance une session de focus\npour apparaître au classement")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}
