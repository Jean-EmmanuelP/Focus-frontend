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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.incomingToast != nil)
        .task {
            await viewModel.loadData()
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

            // Title (tappable for easter egg)
            Button(action: {
                viewModel.handleDebugTap()
            }) {
                VStack(spacing: 2) {
                    Text("Focus Pulse")
                        .font(.satoshi(18, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)
                    if !viewModel.fakeUsersEnabled {
                        Text("Mode reel")
                            .font(.satoshi(10, weight: .medium))
                            .foregroundColor(ColorTokens.success)
                    }
                }
            }

            Spacer()

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
