import SwiftUI
import MapKit

struct DiscoverMapView: View {
    var onDismiss: () -> Void

    @StateObject private var viewModel = DiscoverMapViewModel()
    @EnvironmentObject var store: FocusAppStore

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showCategoryPicker = false
    @State private var pendingCategory: FocusRoomCategory?
    @State private var activeRoomCategory: FocusRoomCategory?
    @State private var showFriends = false
    @State private var leaderboardExpanded = false
    @StateObject private var leaderboardVM = LeaderboardViewModel()

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#050508").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Map
                ZStack {
                    mapContent

                    // Loading
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    }

                    // Empty state
                    if !viewModel.isLoading && viewModel.focusingUsers.isEmpty {
                        emptyState
                    }

                    // Overlays
                    if !viewModel.isLoading && !viewModel.nearbyUsers.isEmpty {
                        VStack {
                            // Stats pills at top
                            HStack(spacing: 8) {
                                FocusMapStatPill(
                                    sfSymbol: "flame.fill",
                                    value: viewModel.localActiveCount,
                                    label: "en focus",
                                    color: .orange
                                )

                                FocusMapStatPill(
                                    sfSymbol: "timer",
                                    value: viewModel.localTotalMinutes,
                                    label: "min",
                                    color: ColorTokens.accent
                                )
                            }
                            .animation(.easeOut(duration: 0.6), value: viewModel.localActiveCount)
                            .animation(.easeOut(duration: 0.6), value: viewModel.localTotalMinutes)
                            .padding(.top, 8)

                            Spacer()

                            // Subtle hint if user is not focusing
                            if !viewModel.isUserCurrentlyFocusing {
                                Text("Lance une session pour grossir sur la carte")
                                    .font(.satoshi(12, weight: .medium))
                                    .foregroundColor(ColorTokens.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                    )
                                    .padding(.bottom, 8)
                            }

                            // Coach card at bottom
                            FocusMapCoachCard(
                                message: viewModel.coachMessage,
                                onJoinFocus: {
                                    showCategoryPicker = true
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }

            // Leaderboard overlay panel
            if leaderboardExpanded {
                VStack {
                    Spacer()
                    LeaderboardOverlayPanel(viewModel: leaderboardVM, currentUserId: store.user?.id)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(5)
            }

            // Encouragement toast (top)
            if let toast = viewModel.incomingToast {
                VStack {
                    EncouragementToastView(toast: toast)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .zIndex(10)
            }

        }
        .sheet(item: $viewModel.selectedUser) { user in
            FocusPulseUserCard(
                user: user,
                alreadySent: viewModel.hasAlreadyEncouraged(user.id),
                onSendEncouragement: { emoji, message in
                    viewModel.sendEncouragement(to: user.id, emoji: emoji, message: message)
                },
                onDismiss: {
                    viewModel.deselectUser()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showCategoryPicker, onDismiss: {
            if let cat = pendingCategory {
                pendingCategory = nil
                activeRoomCategory = cat
            }
        }) {
            CategoryPickerSheet { category in
                pendingCategory = category
                showCategoryPicker = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .fullScreenCover(item: $activeRoomCategory) { category in
            FocusRoomView(category: category)
        }
        .sheet(isPresented: $showFriends) {
            FriendsView(onDismiss: { showFriends = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.incomingToast != nil)
        .task {
            await viewModel.loadData()
            await leaderboardVM.loadLeaderboard()
            if let loc = viewModel.userLocation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                ))
            }
        }
        .onAppear {
            viewModel.startEncouragementSimulation()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Close
            Button(action: { onDismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }

            Spacer()

            Text("Focus Pulse")
                .font(.satoshi(18, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            Spacer()

            HStack(spacing: 8) {
                // LIVE indicator
                HStack(spacing: 5) {
                    Circle()
                        .fill(ColorTokens.success)
                        .frame(width: 6, height: 6)

                    Text("LIVE")
                        .font(.satoshi(11, weight: .bold))
                        .foregroundColor(ColorTokens.success)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(ColorTokens.success.opacity(0.12))
                )

                // Leaderboard toggle
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        leaderboardExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(leaderboardExpanded ? .white : .orange)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(leaderboardExpanded ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.ultraThinMaterial)))
                }

                // Friends button
                Button { showFriends = true } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ColorTokens.accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // Current user annotation
            if let loc = viewModel.userLocation, let user = store.user {
                Annotation("", coordinate: loc) {
                    FocusPulseDot(
                        user: NearbyUser(
                            id: user.id,
                            pseudo: user.pseudo,
                            firstName: user.firstName,
                            avatarUrl: user.avatarURL,
                            lifeGoal: nil, hobbies: nil,
                            productivityPeak: user.productivityPeak?.rawValue,
                            currentStreak: user.currentStreak,
                            city: nil, country: nil,
                            latitude: loc.latitude, longitude: loc.longitude,
                            isInFocusSession: viewModel.isUserCurrentlyFocusing,
                            totalMinutesToday: store.todayMinutes
                        ),
                        isCurrentUser: true
                    )
                }
            }

            // Nearby users
            ForEach(viewModel.nearbyUsers) { user in
                Annotation("", coordinate: user.coordinate) {
                    Button {
                        guard user.isInFocusSession || user.totalMinutesToday > 0 else { return }
                        viewModel.selectUser(user)
                    } label: {
                        FocusPulseDot(user: user, isCurrentUser: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .colorScheme(.dark)
        .mapControlVisibility(.hidden)
    }

    // MARK: - Empty State

    // Note: LeaderboardOverlayPanel is defined at bottom of file

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(.orange.opacity(0.5))

            VStack(spacing: 6) {
                Text("Personne en focus pres de toi")
                    .font(.satoshi(16, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Sois le premier !")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Button {
                showCategoryPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15))
                    Text("Lancer une session")
                        .font(.satoshi(15, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .frame(height: 50)
                .background(
                    Capsule()
                        .fill(ColorTokens.primaryGradient)
                )
            }
        }
        .padding(40)
    }

}

// MARK: - Leaderboard Overlay Panel

struct LeaderboardOverlayPanel: View {
    @ObservedObject var viewModel: LeaderboardViewModel
    let currentUserId: String?

    private func podiumColor(_ place: Int) -> Color {
        switch place {
        case 1: return Color(hex: "#FFD700")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)

            // Title
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")], startPoint: .top, endPoint: .bottom)
                    )
                Text("Classement")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.entries.count) focuseurs")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            if viewModel.isLoading {
                ProgressView().tint(.white).padding(.vertical, 30)
            } else if viewModel.entries.isEmpty {
                Text("Lance une session pour apparaître")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 30)
            } else {
                // Top entries (scrollable)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(Array(viewModel.entries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                            let isMe = entry.id == currentUserId
                            HStack(spacing: 10) {
                                // Rank
                                if entry.rank <= 3 {
                                    Text(entry.rank == 1 ? "🥇" : entry.rank == 2 ? "🥈" : "🥉")
                                        .font(.system(size: 16))
                                        .frame(width: 28)
                                } else {
                                    Text("#\(entry.rank)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 28)
                                }

                                // Avatar
                                if let url = entry.avatarUrl, let imageURL = URL(string: url) {
                                    AsyncImage(url: imageURL) { phase in
                                        if case .success(let img) = phase {
                                            img.resizable().scaledToFill()
                                        } else {
                                            Circle().fill(Color.white.opacity(0.1))
                                                .overlay(
                                                    Text(entry.initial)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                } else {
                                    Circle().fill(Color.white.opacity(0.1))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(entry.initial)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }

                                // Name
                                Text(isMe ? "Toi" : entry.displayName)
                                    .font(.system(size: 14, weight: isMe ? .bold : .medium))
                                    .foregroundColor(isMe ? Color(red: 0.20, green: 0.45, blue: 1.0) : .white)
                                    .lineLimit(1)

                                Spacer()

                                // Streak
                                if entry.currentStreak > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.orange)
                                        Text("\(entry.currentStreak)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }

                                // Score
                                Text("\(entry.formattedScore)")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(isMe ? Color(red: 0.20, green: 0.45, blue: 1.0) : .white)
                                    .frame(width: 36, alignment: .trailing)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isMe ? Color(red: 0.20, green: 0.45, blue: 1.0).opacity(0.1) : Color.clear)
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: -5)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}
