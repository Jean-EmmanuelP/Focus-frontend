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
    @StateObject private var leaderboardVM = LeaderboardViewModel()

    var body: some View {
        ZStack {
            // Full-screen map
            mapContent
                .ignoresSafeArea()

            // Loading
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }

            // Empty state
            if !viewModel.isLoading && viewModel.focusingUsers.isEmpty && viewModel.nearbyUsers.isEmpty {
                emptyState
            }

            // Floating UI overlays
            VStack(spacing: 0) {
                // Top: floating buttons
                floatingTopBar
                    .padding(.top, 4)

                // Mini podium strip
                if !leaderboardVM.entries.isEmpty {
                    miniPodiumStrip
                        .padding(.top, 8)
                }

                Spacer()

                // Bottom: CTA
                bottomCTA
                    .padding(.bottom, 20)
                    .padding(.horizontal, 16)
            }

            // Encouragement toast
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

    // MARK: - Floating Top Bar

    private var floatingTopBar: some View {
        HStack {
            // Close
            Button(action: { onDismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.2), radius: 8)
            }

            Spacer()

            // LIVE pill
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text("LIVE")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.green)

                if viewModel.localActiveCount > 0 {
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text("\(viewModel.localActiveCount) en focus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 8)
            )

            Spacer()

            // Friends
            Button { showFriends = true } label: {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.2), radius: 8)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Mini Podium Strip

    private var miniPodiumStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(leaderboardVM.entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    let isMe = entry.id == store.user?.id
                    let medal = index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "#\(index + 1)"

                    HStack(spacing: 6) {
                        if index < 3 {
                            Text(medal)
                                .font(.system(size: 12))
                        } else {
                            Text(medal)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                        }

                        // Mini avatar
                        if let url = entry.avatarUrl, let imageURL = URL(string: url) {
                            AsyncImage(url: imageURL) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().scaledToFill()
                                } else {
                                    miniInitial(entry.initial)
                                }
                            }
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                        } else {
                            miniInitial(entry.initial)
                        }

                        Text(isMe ? "Toi" : entry.displayName)
                            .font(.system(size: 11, weight: isMe ? .bold : .semibold))
                            .foregroundColor(isMe ? Color(red: 0.20, green: 0.45, blue: 1.0) : .white)
                            .lineLimit(1)

                        Text("\(entry.formattedScore)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 6)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func miniInitial(_ initial: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.20, green: 0.45, blue: 1.0).opacity(0.3))
            Text(initial)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 22, height: 22)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        Button {
            showCategoryPicker = true
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15))
                    Text("Lancer une session")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)

                if !viewModel.isUserCurrentlyFocusing {
                    Text("Pour grossir sur la carte")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: viewModel.isUserCurrentlyFocusing ? 52 : 64)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.20, green: 0.45, blue: 1.0), Color(red: 0.30, green: 0.55, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(red: 0.20, green: 0.45, blue: 1.0).opacity(0.4), radius: 16, y: 4)
            )
        }
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(.orange.opacity(0.5))

            VStack(spacing: 6) {
                Text("Personne en focus près de toi")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("Sois le premier !")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(40)
    }
}
