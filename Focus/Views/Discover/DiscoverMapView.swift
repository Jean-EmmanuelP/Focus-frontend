import SwiftUI
import MapKit

struct DiscoverMapView: View {
    var onDismiss: () -> Void

    @StateObject private var viewModel = DiscoverMapViewModel()
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var store: FocusAppStore

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showPaywall = false

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
                    if !viewModel.isLoading && viewModel.nearbyUsers.isEmpty {
                        emptyState
                    }
                }
            }

            // Bottom sheet
            if viewModel.selectedUser != nil {
                profileSheet
            }
        }
        .overlay {
            if showPaywall {
                FocusPaywallView(
                    companionName: store.user?.companionName ?? "ton coach",
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) { showPaywall = false }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) { showPaywall = false }
                    }
                )
                .environmentObject(subscriptionManager)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPaywall)
        .task {
            await viewModel.loadData()
            if let loc = viewModel.userLocation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                ))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Close
            Button(action: {
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }

            Spacer()

            // Title (tappable for easter egg)
            Button(action: {
                viewModel.handleDebugTap()
            }) {
                VStack(spacing: 2) {
                    Text("Explorer")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    if !viewModel.fakeUsersEnabled {
                        Text("Mode réel")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            // User count badge
            if viewModel.userCount > 0 {
                Text("\(viewModel.userCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // Current user annotation
            if let loc = viewModel.userLocation, let user = store.user {
                Annotation("", coordinate: loc) {
                    NearbyUserAnnotation(
                        user: NearbyUser(
                            id: user.id,
                            pseudo: user.pseudo,
                            firstName: user.firstName,
                            avatarUrl: user.avatarURL,
                            lifeGoal: user.lifeGoal,
                            hobbies: user.hobbies,
                            productivityPeak: user.productivityPeak?.rawValue,
                            currentStreak: user.currentStreak,
                            city: nil, country: nil,
                            latitude: loc.latitude, longitude: loc.longitude
                        ),
                        isCurrentUser: true
                    )
                }
            }

            // Nearby users
            ForEach(viewModel.nearbyUsers) { user in
                Annotation("", coordinate: user.coordinate) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectUser(user)
                        }
                    } label: {
                        NearbyUserAnnotation(user: user, isCurrentUser: false)
                    }
                }
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControlVisibility(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.3))
            Text("Personne dans ta zone pour le moment")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Profile Sheet

    private var profileSheet: some View {
        VStack {
            Spacer()

            if let user = viewModel.selectedUser {
                NearbyUserProfileCard(
                    user: user,
                    matchResult: viewModel.matchResult,
                    isProUser: subscriptionManager.isProUser,
                    onPaywall: {
                        withAnimation(.easeInOut(duration: 0.3)) { showPaywall = true }
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.deselectUser()
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.selectedUser?.id)
    }
}
