import SwiftUI

struct CrewView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var viewModel = CrewViewModel()
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var showingShareSheet = false
    @State private var showingSignOutAlert = false
    @State private var showingMyStats = false
    @State private var selectedVisibility: DayVisibility = .crewOnly
    @State private var isUpdatingVisibility = false

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: SpacingTokens.xl) {
                    // Header
                    headerSection

                    // Tab Selector
                    tabSelector

                    // Content based on selected tab
                    switch viewModel.activeTab {
                    case .leaderboard:
                        leaderboardSection
                    case .myCrew:
                        myCrewSection
                    case .requests:
                        requestsSection
                    }

                    // Account Section
                    accountSection
                }
                .padding(SpacingTokens.lg)
            }

            // Search overlay
            if viewModel.showingSearch {
                searchOverlay
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showingMemberDetail) {
            if viewModel.selectedMember != nil {
                MemberDayDetailView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingMyStats) {
            MyStatsView()
        }
        .alert("common.error".localized, isPresented: $viewModel.showError) {
            Button("common.ok".localized, role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "error.generic".localized)
        }
        .alert("profile.sign_out_title".localized, isPresented: $showingSignOutAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("profile.sign_out".localized, role: .destructive) {
                store.signOut()
            }
        } message: {
            Text("profile.sign_out_confirm".localized)
        }
        .task {
            await viewModel.loadInitialData()
        }
        .onAppear {
            // Initialize visibility from user profile
            if let visibility = store.user?.dayVisibility,
               let dayVis = DayVisibility(rawValue: visibility) {
                selectedVisibility = dayVis
            }
        }
        .id(localization.currentLanguage) // Force refresh when language changes
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("👥")
                    .font(.system(size: 28))

                Text("crew.title".localized)
                    .label()
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                // Search button
                Button {
                    withAnimation {
                        viewModel.showingSearch = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(ColorTokens.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.md)
                }
            }

            Text("crew.subtitle".localized)
                .caption()
                .foregroundColor(ColorTokens.textSecondary)
        }
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(CrewTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: CrewTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.activeTab = tab
            }
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))

                Text(tab.displayName)
                    .caption()
                    .fontWeight(.medium)

                // Badge for requests
                if tab == .requests && viewModel.hasNewRequests {
                    Text("\(viewModel.pendingRequestsCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ColorTokens.primaryStart)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(viewModel.activeTab == tab ? ColorTokens.primaryStart : ColorTokens.textSecondary)
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)
            .background(viewModel.activeTab == tab ? ColorTokens.primarySoft : ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
        }
    }

    // MARK: - Leaderboard Section
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🏆")
                    .font(.system(size: 20))
                Text("crew.top_builders".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
            }

            if viewModel.isLoadingLeaderboard {
                loadingView
            } else if viewModel.leaderboard.isEmpty {
                emptyStateCard(
                    icon: "chart.bar",
                    title: "crew.no_activity".localized,
                    subtitle: "crew.start_session_hint".localized
                )
            } else {
                VStack(spacing: SpacingTokens.sm) {
                    ForEach(viewModel.leaderboard) { entry in
                        LeaderboardEntryRow(
                            entry: entry,
                            onTap: {
                                // Convert to CrewMemberResponse for viewing
                                let member = CrewMemberResponse(
                                    id: entry.id,
                                    memberId: entry.id,
                                    pseudo: entry.pseudo,
                                    firstName: entry.firstName,
                                    lastName: entry.lastName,
                                    avatarUrl: entry.avatarUrl,
                                    dayVisibility: entry.dayVisibility,
                                    totalSessions7d: entry.totalSessions7d,
                                    totalMinutes7d: entry.totalMinutes7d,
                                    activityScore: entry.activityScore,
                                    createdAt: nil
                                )
                                viewModel.selectMember(member)
                            },
                            onSendRequest: {
                                Task {
                                    _ = await viewModel.sendRequest(to: entry.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - My Crew Section
    private var myCrewSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🤝")
                    .font(.system(size: 20))
                Text("crew.your_crew".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()

                Text("\(viewModel.crewMembers.count) \("crew.members".localized)")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            if viewModel.isLoadingMembers {
                loadingView
            } else if viewModel.crewMembers.isEmpty {
                emptyStateCard(
                    icon: "person.2",
                    title: "crew.no_members".localized,
                    subtitle: "crew.search_hint".localized
                )
            } else {
                VStack(spacing: SpacingTokens.sm) {
                    ForEach(viewModel.crewMembers) { member in
                        CrewMemberRow(
                            member: member,
                            onTap: {
                                viewModel.selectMember(member)
                            },
                            onRemove: {
                                Task {
                                    _ = await viewModel.removeMember(member)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Requests Section
    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            // Received requests
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    Text("📥")
                        .font(.system(size: 20))
                    Text("crew.received_requests".localized)
                        .subtitle()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()
                }

                if viewModel.isLoadingRequests {
                    loadingView
                } else if viewModel.receivedRequests.isEmpty {
                    emptyStateCard(
                        icon: "envelope",
                        title: "crew.no_requests".localized,
                        subtitle: "crew.requests_hint".localized
                    )
                } else {
                    VStack(spacing: SpacingTokens.sm) {
                        ForEach(viewModel.receivedRequests) { request in
                            CrewRequestRow(
                                request: request,
                                isReceived: true,
                                onAccept: {
                                    Task {
                                        _ = await viewModel.acceptRequest(request)
                                    }
                                },
                                onReject: {
                                    Task {
                                        _ = await viewModel.rejectRequest(request)
                                    }
                                }
                            )
                        }
                    }
                }
            }

            // Sent requests
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    Text("📤")
                        .font(.system(size: 20))
                    Text("crew.sent_requests".localized)
                        .subtitle()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()
                }

                if viewModel.sentRequests.isEmpty {
                    emptyStateCard(
                        icon: "paperplane",
                        title: "crew.no_sent_requests".localized,
                        subtitle: "crew.search_to_send".localized
                    )
                } else {
                    VStack(spacing: SpacingTokens.sm) {
                        ForEach(viewModel.sentRequests) { request in
                            CrewRequestRow(
                                request: request,
                                isReceived: false,
                                onAccept: {},
                                onReject: {}
                            )
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadSentRequests()
        }
    }

    // MARK: - Search Overlay
    private var searchOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        viewModel.showingSearch = false
                        viewModel.clearSearch()
                    }
                }

            VStack(spacing: SpacingTokens.md) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ColorTokens.textMuted)

                    TextField("crew.search_placeholder".localized, text: $viewModel.searchQuery)
                        .foregroundColor(ColorTokens.textPrimary)
                        .onChange(of: viewModel.searchQuery) { _, _ in
                            viewModel.searchUsers()
                        }

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                }
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)

                // Search results
                if viewModel.isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                        .padding()
                } else if !viewModel.searchResults.isEmpty {
                    ScrollView {
                        VStack(spacing: SpacingTokens.sm) {
                            ForEach(viewModel.searchResults) { result in
                                SearchResultRow(
                                    result: result,
                                    onSendRequest: {
                                        Task {
                                            _ = await viewModel.sendRequest(to: result.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                } else if !viewModel.searchQuery.isEmpty {
                    Text("crew.no_users_found".localized)
                        .bodyText()
                        .foregroundColor(ColorTokens.textMuted)
                        .padding()
                }

                // Close button
                Button {
                    withAnimation {
                        viewModel.showingSearch = false
                        viewModel.clearSearch()
                    }
                } label: {
                    Text("common.close".localized)
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)
                        .padding(.vertical, SpacingTokens.sm)
                        .padding(.horizontal, SpacingTokens.lg)
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.md)
                }
            }
            .padding(SpacingTokens.lg)
            .background(ColorTokens.background)
            .cornerRadius(RadiusTokens.lg)
            .padding(SpacingTokens.lg)
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // User info
            if let user = store.user {
                Card {
                    HStack(spacing: SpacingTokens.md) {
                        AvatarView(name: user.name, avatarURL: user.avatarURL, size: 50)

                        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                            Text(user.name)
                                .subtitle()
                                .fontWeight(.semibold)
                                .foregroundColor(ColorTokens.textPrimary)

                            Text(user.email.isEmpty ? "profile.guest_account".localized : user.email)
                                .caption()
                                .foregroundColor(ColorTokens.textMuted)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                            Text("profile.level".localized(with: user.level))
                                .bodyText()
                                .fontWeight(.medium)
                                .foregroundColor(ColorTokens.primaryStart)

                            Text("🔥 \(user.currentStreak) \("dashboard.day_streak".localized)")
                                .caption()
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }
                }
            }

            // My Statistics Button
            Button {
                showingMyStats = true
            } label: {
                Card {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 18))
                            .foregroundColor(ColorTokens.primaryStart)

                        Text("profile.my_statistics".localized)
                            .bodyText()
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Day Visibility Setting
            Card {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    HStack {
                        Image(systemName: "eye")
                            .foregroundColor(ColorTokens.primaryStart)
                        Text("profile.day_visibility".localized)
                            .bodyText()
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textPrimary)
                        Spacer()
                        if isUpdatingVisibility {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    Text("profile.visibility_description".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)

                    // Visibility options
                    VStack(spacing: SpacingTokens.sm) {
                        ForEach(DayVisibility.allCases, id: \.self) { visibility in
                            Button {
                                updateVisibility(visibility)
                            } label: {
                                HStack {
                                    Image(systemName: visibility.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedVisibility == visibility ? ColorTokens.primaryStart : ColorTokens.textMuted)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(visibility.displayName)
                                            .bodyText()
                                            .foregroundColor(selectedVisibility == visibility ? ColorTokens.textPrimary : ColorTokens.textSecondary)

                                        Text(visibility.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(ColorTokens.textMuted)
                                    }

                                    Spacer()

                                    if selectedVisibility == visibility {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(ColorTokens.primaryStart)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(ColorTokens.textMuted)
                                    }
                                }
                                .padding(SpacingTokens.sm)
                                .background(selectedVisibility == visibility ? ColorTokens.primarySoft : Color.clear)
                                .cornerRadius(RadiusTokens.sm)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isUpdatingVisibility)
                        }
                    }
                }
            }

            // Sign Out (discreet)
            Button(action: {
                showingSignOutAlert = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.textMuted)

                    Text("profile.sign_out".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)

                    Spacer()
                }
            }
            .padding(.top, SpacingTokens.md)

            // Version info
            Text("profile.version".localized)
                .font(.system(size: 10))
                .foregroundColor(ColorTokens.textMuted.opacity(0.6))
                .padding(.top, SpacingTokens.xs)
        }
    }

    // MARK: - Update Visibility
    private func updateVisibility(_ visibility: DayVisibility) {
        guard visibility != selectedVisibility else { return }

        isUpdatingVisibility = true
        let previousVisibility = selectedVisibility
        selectedVisibility = visibility

        Task {
            do {
                let crewService = CrewService()
                try await crewService.updateDayVisibility(visibility)
                // Update the store's user with the new visibility
                if var user = store.user {
                    user.dayVisibility = visibility.rawValue
                    store.user = user
                }
            } catch {
                // Revert on error
                selectedVisibility = previousVisibility
                viewModel.errorMessage = "error.update_visibility".localized
                viewModel.showError = true
            }
            isUpdatingVisibility = false
        }
    }

    // MARK: - Helper Views
    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
            Spacer()
        }
        .padding()
    }

    private func emptyStateCard(icon: String, title: String, subtitle: String) -> some View {
        Card {
            VStack(spacing: SpacingTokens.md) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(ColorTokens.textMuted)

                Text(title)
                    .bodyText()
                    .fontWeight(.medium)
                    .foregroundColor(ColorTokens.textPrimary)

                Text(subtitle)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.lg)
        }
    }
}

// MARK: - Leaderboard Entry Row
struct LeaderboardEntryRow: View {
    let entry: LeaderboardEntry
    let onTap: () -> Void
    let onSendRequest: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card {
                HStack(spacing: SpacingTokens.md) {
                    // Rank
                    Text("#\(entry.safeRank)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(rankColor)
                        .frame(width: 40)

                    // Avatar
                    AvatarView(
                        name: entry.displayName,
                        avatarURL: entry.avatarUrl,
                        size: 44
                    )

                    // Info
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        HStack {
                            Text(entry.displayName)
                                .bodyText()
                                .fontWeight(.medium)
                                .foregroundColor(ColorTokens.textPrimary)

                            if entry.safeIsCrewMember {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(ColorTokens.success)
                            }
                        }

                        HStack(spacing: SpacingTokens.sm) {
                            Label("\(entry.totalSessions7d ?? 0)", systemImage: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(ColorTokens.textMuted)

                            Label(entry.formattedFocusTime, systemImage: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }

                    Spacer()

                    // Action button
                    if entry.safeIsCrewMember {
                        // Already in crew - show checkmark
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ColorTokens.success)
                    } else if entry.safeHasPendingRequest {
                        // Pending request
                        Text(entry.requestDirection == "outgoing" ? "crew.pending".localized : "crew.respond".localized)
                            .caption()
                            .foregroundColor(entry.requestDirection == "outgoing" ? ColorTokens.warning : ColorTokens.primaryStart)
                            .padding(.horizontal, SpacingTokens.sm)
                            .padding(.vertical, SpacingTokens.xs)
                            .background((entry.requestDirection == "outgoing" ? ColorTokens.warning : ColorTokens.primaryStart).opacity(0.15))
                            .cornerRadius(RadiusTokens.sm)
                    } else {
                        // Can send request
                        Button {
                            onSendRequest()
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16))
                                .foregroundColor(ColorTokens.primaryStart)
                                .frame(width: 36, height: 36)
                                .background(ColorTokens.primarySoft)
                                .cornerRadius(RadiusTokens.sm)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var rankColor: Color {
        switch entry.safeRank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.orange
        default: return ColorTokens.textMuted
        }
    }
}

// MARK: - Crew Member Row
struct CrewMemberRow: View {
    let member: CrewMemberResponse
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var showingRemoveAlert = false

    var body: some View {
        Button(action: onTap) {
            Card {
                HStack(spacing: SpacingTokens.md) {
                    AvatarView(
                        name: member.displayName,
                        avatarURL: member.avatarUrl,
                        size: 44
                    )

                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text(member.displayName)
                            .bodyText()
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textPrimary)

                        if let sessions = member.totalSessions7d, let minutes = member.totalMinutes7d {
                            HStack(spacing: SpacingTokens.sm) {
                                Label("\(sessions) \("crew.sessions".localized)", systemImage: "flame.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(ColorTokens.textMuted)

                                let hours = minutes / 60
                                let mins = minutes % 60
                                let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
                                Label(timeStr, systemImage: "clock")
                                    .font(.system(size: 11))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                    }

                    Spacer()

                    // Visibility indicator
                    if let visibility = member.dayVisibility {
                        Image(systemName: visibilityIcon(visibility))
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.textMuted)
                    }

                    // Remove button
                    Button {
                        showingRemoveAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.textMuted)
                            .frame(width: 30, height: 30)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .alert("crew.remove".localized, isPresented: $showingRemoveAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("crew.remove".localized, role: .destructive) {
                onRemove()
            }
        } message: {
            Text("crew.remove_confirm".localized(with: member.displayName))
        }
    }

    private func visibilityIcon(_ visibility: String) -> String {
        switch visibility {
        case "public": return "globe"
        case "crew": return "person.2"
        default: return "lock"
        }
    }
}

// MARK: - Crew Request Row
struct CrewRequestRow: View {
    let request: CrewRequestResponse
    let isReceived: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        Card {
            HStack(spacing: SpacingTokens.md) {
                // Avatar
                let user = isReceived ? request.fromUser : request.toUser
                AvatarView(
                    name: user?.displayName ?? "User",
                    avatarURL: user?.avatarUrl,
                    size: 44
                )

                // Info
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text(user?.displayName ?? "User")
                        .bodyText()
                        .fontWeight(.medium)
                        .foregroundColor(ColorTokens.textPrimary)

                    if let message = request.message, !message.isEmpty {
                        Text(message)
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                            .lineLimit(2)
                    }

                    Text(request.createdAt.timeAgoDisplay())
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()

                // Actions (only for received pending requests)
                if isReceived && request.status == "pending" {
                    HStack(spacing: SpacingTokens.sm) {
                        Button {
                            onReject()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ColorTokens.error)
                                .frame(width: 36, height: 36)
                                .background(ColorTokens.error.opacity(0.1))
                                .cornerRadius(RadiusTokens.sm)
                        }

                        Button {
                            onAccept()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ColorTokens.success)
                                .frame(width: 36, height: 36)
                                .background(ColorTokens.success.opacity(0.1))
                                .cornerRadius(RadiusTokens.sm)
                        }
                    }
                } else {
                    // Status badge
                    Text(request.status.capitalized)
                        .caption()
                        .foregroundColor(statusColor)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xs)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(RadiusTokens.sm)
                }
            }
        }
    }

    private var statusColor: Color {
        switch request.status {
        case "pending": return ColorTokens.warning
        case "accepted": return ColorTokens.success
        case "rejected": return ColorTokens.error
        default: return ColorTokens.textMuted
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchUserResult
    let onSendRequest: () -> Void

    var body: some View {
        Card {
            HStack(spacing: SpacingTokens.md) {
                AvatarView(
                    name: result.displayName,
                    avatarURL: result.avatarUrl,
                    size: 44
                )

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    HStack {
                        Text(result.displayName)
                            .bodyText()
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textPrimary)

                        if result.isCrewMember {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTokens.success)
                        }
                    }

                    if let sessions = result.totalSessions7d {
                        Label("\(sessions) \("crew.sessions".localized) \("crew.this_week".localized)", systemImage: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }

                Spacer()

                // Action button
                if result.isCrewMember {
                    Text("crew.in_crew".localized)
                        .caption()
                        .foregroundColor(ColorTokens.success)
                } else if result.hasPendingRequest {
                    Text(result.requestDirection == "outgoing" ? "crew.pending".localized : "crew.respond".localized)
                        .caption()
                        .foregroundColor(ColorTokens.warning)
                } else {
                    Button {
                        onSendRequest()
                    } label: {
                        Text("common.add".localized)
                            .caption()
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.sm)
                            .background(ColorTokens.primaryStart)
                            .cornerRadius(RadiusTokens.sm)
                    }
                }
            }
        }
    }
}

// MARK: - Member Day Detail View
struct MemberDayDetailView: View {
    @ObservedObject var viewModel: CrewViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                if viewModel.isLoadingMemberDay {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                } else if let day = viewModel.selectedMemberDay {
                    ScrollView {
                        VStack(spacing: SpacingTokens.lg) {
                            // Date navigation
                            dateNavigation

                            // User header
                            userHeader(day.user)

                            // Stats graphs section
                            if let stats = day.stats {
                                statsSection(stats)
                            }

                            // Intentions
                            if let intentions = day.intentions, !intentions.isEmpty {
                                intentionsSection(intentions)
                            }

                            // Focus sessions (limited to 3 with "See more")
                            if let sessions = day.focusSessions, !sessions.isEmpty {
                                focusSessionsSection(sessions)
                            }

                            // All routines (completed and not completed)
                            if let routines = day.routines, !routines.isEmpty {
                                allRoutinesSection(routines)
                            }

                            // Empty state
                            if (day.intentions ?? []).isEmpty &&
                               (day.focusSessions ?? []).isEmpty &&
                               (day.routines ?? []).isEmpty &&
                               day.stats == nil {
                                emptyDayState
                            }
                        }
                        .padding(SpacingTokens.lg)
                    }
                } else {
                    // Private or no permission
                    VStack(spacing: SpacingTokens.lg) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 60))
                            .foregroundColor(ColorTokens.textMuted)

                        Text("crew.day_not_visible".localized)
                            .subtitle()
                            .fontWeight(.bold)
                            .foregroundColor(ColorTokens.textPrimary)

                        Text("crew.day_private".localized)
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle(viewModel.selectedMember?.displayName ?? "crew.crew_member".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                        viewModel.closeMemberDetail()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
    }

    private var dateNavigation: some View {
        HStack {
            Button {
                viewModel.changeSelectedDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ColorTokens.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.sm)
            }

            Spacer()

            Text(formattedDate)
                .bodyText()
                .fontWeight(.medium)
                .foregroundColor(ColorTokens.textPrimary)

            Spacer()

            Button {
                viewModel.changeSelectedDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Calendar.current.isDateInToday(viewModel.selectedDate) ? ColorTokens.textMuted : ColorTokens.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.sm)
            }
            .disabled(Calendar.current.isDateInToday(viewModel.selectedDate))
        }
    }

    private var formattedDate: String {
        if Calendar.current.isDateInToday(viewModel.selectedDate) {
            return "time.today".localized
        } else if Calendar.current.isDateInYesterday(viewModel.selectedDate) {
            return "time.yesterday".localized
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: viewModel.selectedDate)
        }
    }

    private func userHeader(_ user: CrewUserInfo) -> some View {
        Card {
            HStack(spacing: SpacingTokens.md) {
                AvatarView(
                    name: user.displayName,
                    avatarURL: user.avatarUrl,
                    size: 50
                )

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text(user.displayName)
                        .subtitle()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("crew.crew_member".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()
            }
        }
    }

    private func intentionsSection(_ intentions: [CrewIntention]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🎯")
                    .font(.system(size: 18))
                Text("crew.intentions".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
            }

            Card {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    ForEach(intentions) { intention in
                        HStack(alignment: .top, spacing: SpacingTokens.sm) {
                            Text("•")
                                .foregroundColor(ColorTokens.primaryStart)
                            Text(intention.content)
                                .bodyText()
                                .foregroundColor(ColorTokens.textPrimary)
                        }
                    }
                }
            }
        }
    }

    @State private var showAllSessions = false

    private func focusSessionsSection(_ sessions: [CrewFocusSession]) -> some View {
        let displayedSessions = showAllSessions ? sessions : Array(sessions.prefix(3))
        let hasMore = sessions.count > 3

        return VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🔥")
                    .font(.system(size: 18))
                Text("crew.focus_sessions".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text("\(sessions.count) \("crew.sessions".localized)")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            VStack(spacing: SpacingTokens.sm) {
                ForEach(displayedSessions) { session in
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                                Text(session.description ?? "Focus Session")
                                    .bodyText()
                                    .foregroundColor(ColorTokens.textPrimary)

                                Text(session.formattedDuration)
                                    .caption()
                                    .foregroundColor(ColorTokens.textMuted)
                            }

                            Spacer()

                            Text(formatTime(session.startedAt))
                                .caption()
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                }

                // Show more / Show less button
                if hasMore {
                    Button {
                        withAnimation {
                            showAllSessions.toggle()
                        }
                    } label: {
                        HStack {
                            Text(showAllSessions ? "common.show_less".localized : "common.see_all".localized(with: sessions.count))
                                .caption()
                                .fontWeight(.medium)
                            Image(systemName: showAllSessions ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(ColorTokens.primaryStart)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.sm)
                    }
                }
            }
        }
    }

    // MARK: - Stats Section (Compact)
    @State private var showMemberStats = false

    private func statsSection(_ stats: CrewMemberStats) -> some View {
        Button {
            showMemberStats = true
        } label: {
            Card {
                HStack {
                    // Quick stats
                    HStack(spacing: SpacingTokens.lg) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatMinutes(stats.weeklyTotalFocus ?? 0))
                                .bodyText()
                                .fontWeight(.semibold)
                                .foregroundColor(ColorTokens.textPrimary)
                            Text("crew.focus_this_week".localized)
                                .font(.system(size: 10))
                                .foregroundColor(ColorTokens.textMuted)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(stats.weeklyRoutineRate ?? 0)%")
                                .bodyText()
                                .fontWeight(.semibold)
                                .foregroundColor(ColorTokens.textPrimary)
                            Text("crew.routines_done".localized)
                                .font(.system(size: 10))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }

                    Spacer()

                    HStack(spacing: SpacingTokens.xs) {
                        Text("stats.view_stats".localized)
                            .caption()
                            .foregroundColor(ColorTokens.primaryStart)
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTokens.primaryStart)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showMemberStats) {
            MemberStatsDetailView(stats: stats, memberName: viewModel.selectedMember?.displayName ?? "Member")
        }
    }

    private func weeklyGraphSection(title: String, subtitle: String, data: [DailyStat], color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .bodyText()
                        .fontWeight(.medium)
                        .foregroundColor(ColorTokens.textPrimary)
                    Text(subtitle)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                // Bar chart
                WeeklyBarChart(data: data, color: color)
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }

    private func routinesSection(_ routines: [CrewCompletedRoutine]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("✅")
                    .font(.system(size: 18))
                Text("crew.completed_routines".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text("\(routines.count) \("crew.done".localized)")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            Card {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    ForEach(routines) { routine in
                        HStack(spacing: SpacingTokens.sm) {
                            Text(routine.icon ?? "✓")
                                .font(.system(size: 16))

                            Text(routine.title)
                                .bodyText()
                                .foregroundColor(ColorTokens.textPrimary)

                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func allRoutinesSection(_ routines: [CrewRoutine]) -> some View {
        let completedCount = routines.filter { $0.completed }.count
        let totalCount = routines.count

        return VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("📋")
                    .font(.system(size: 18))
                Text("stats.routines".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text("\(completedCount)/\(totalCount) \("crew.done".localized)")
                    .caption()
                    .foregroundColor(completedCount == totalCount ? ColorTokens.success : ColorTokens.textMuted)
            }

            Card {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    ForEach(routines) { routine in
                        HStack(spacing: SpacingTokens.sm) {
                            // Completion indicator
                            Image(systemName: routine.completed ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(routine.completed ? ColorTokens.success : ColorTokens.textMuted)

                            // Icon
                            Text(routine.icon ?? "✨")
                                .font(.system(size: 16))

                            // Title
                            Text(routine.title)
                                .bodyText()
                                .foregroundColor(routine.completed ? ColorTokens.textPrimary : ColorTokens.textMuted)
                                .strikethrough(!routine.completed ? false : false) // No strikethrough, just dim

                            Spacer()
                        }
                        .opacity(routine.completed ? 1.0 : 0.6)
                    }
                }
            }
        }
    }

    private var emptyDayState: some View {
        Card {
            VStack(spacing: SpacingTokens.md) {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 40))
                    .foregroundColor(ColorTokens.textMuted)

                Text("crew.no_activity".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.lg)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Stat Summary Card
struct StatSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                    Spacer()
                }

                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .caption()
                        .fontWeight(.medium)
                        .foregroundColor(ColorTokens.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(ColorTokens.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Weekly Bar Chart
struct WeeklyBarChart: View {
    let data: [DailyStat]
    let color: Color

    private var maxValue: Int {
        data.map { $0.value }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.sm) {
            ForEach(data) { stat in
                VStack(spacing: SpacingTokens.xs) {
                    // Bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stat.value > 0 ? color : ColorTokens.surface)
                        .frame(height: barHeight(for: stat.value))
                        .frame(maxWidth: .infinity)

                    // Day label
                    Text(dayLabel(from: stat.date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ColorTokens.textMuted)
                }
            }
        }
        .frame(height: 100)
    }

    private func barHeight(for value: Int) -> CGFloat {
        let maxHeight: CGFloat = 70
        let minHeight: CGFloat = 4
        guard maxValue > 0 else { return minHeight }
        let ratio = CGFloat(value) / CGFloat(maxValue)
        return max(minHeight, ratio * maxHeight)
    }

    private func dayLabel(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return String(dateString.suffix(2))
        }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E"
        return String(dayFormatter.string(from: date).prefix(1))
    }
}

// MARK: - Date Extension
extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)

        if let days = components.day, days > 0 {
            return days == 1 ? "time.1_day_ago".localized : "time.days_ago".localized(with: days)
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "time.1_hour_ago".localized : "time.hours_ago".localized(with: hours)
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "time.1_min_ago".localized : "time.mins_ago".localized(with: minutes)
        } else {
            return "time.just_now".localized
        }
    }
}

// MARK: - Member Stats Detail View
struct MemberStatsDetailView: View {
    let stats: CrewMemberStats
    let memberName: String
    @Environment(\.dismiss) var dismiss
    @State private var selectedPeriod: StatsPeriod = .week

    enum StatsPeriod: CaseIterable {
        case week
        case month

        var displayName: String {
            switch self {
            case .week: return "stats.week".localized
            case .month: return "stats.month".localized
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.lg) {
                        // Period selector
                        periodSelector

                        // Summary cards
                        summaryCards

                        // Focus graph
                        focusGraphSection

                        // Routines graph
                        routinesGraphSection
                    }
                    .padding(SpacingTokens.lg)
                }
            }
            .navigationTitle("stats.member_stats".localized(with: memberName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
    }

    private var periodSelector: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(StatsPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.displayName)
                        .bodyText()
                        .fontWeight(.medium)
                        .foregroundColor(selectedPeriod == period ? .white : ColorTokens.textSecondary)
                        .padding(.horizontal, SpacingTokens.lg)
                        .padding(.vertical, SpacingTokens.sm)
                        .background(selectedPeriod == period ? ColorTokens.primaryStart : ColorTokens.surface)
                        .cornerRadius(RadiusTokens.md)
                }
            }
        }
    }

    private var summaryCards: some View {
        let focusMinutes = selectedPeriod == .week ? (stats.weeklyTotalFocus ?? 0) : (stats.monthlyTotalFocus ?? 0)
        let routinesDone = selectedPeriod == .week ? (stats.weeklyTotalRoutines ?? 0) : (stats.monthlyTotalRoutines ?? 0)
        let routineRate = stats.weeklyRoutineRate ?? 0

        return HStack(spacing: SpacingTokens.md) {
            StatSummaryCard(
                title: "stats.focus_time".localized,
                value: formatMinutes(focusMinutes),
                subtitle: selectedPeriod == .week ? "stats.this_week".localized : "stats.this_month".localized,
                icon: "flame.fill",
                color: ColorTokens.primaryStart
            )

            StatSummaryCard(
                title: "stats.routines".localized,
                value: "\(routinesDone)",
                subtitle: "stats.completed".localized,
                icon: "checkmark.circle.fill",
                color: ColorTokens.success
            )
        }
    }

    private var focusGraphSection: some View {
        let data = selectedPeriod == .week
            ? (stats.weeklyFocusMinutes ?? [])
            : (stats.monthlyFocusMinutes ?? [])

        return Card {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(ColorTokens.primaryStart)
                    Text("stats.focus_sessions".localized)
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()
                    Text(selectedPeriod == .week ? "stats.last_7_days".localized : "stats.last_30_days".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                if data.isEmpty {
                    Text("stats.no_sessions".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.lg)
                } else {
                    WeeklyBarChart(data: data, color: ColorTokens.primaryStart)
                }
            }
        }
    }

    private var routinesGraphSection: some View {
        let data = selectedPeriod == .week
            ? (stats.weeklyRoutinesDone ?? [])
            : (stats.monthlyRoutinesDone ?? [])

        return Card {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ColorTokens.success)
                    Text("stats.daily_routines".localized)
                        .bodyText()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()
                    Text(selectedPeriod == .week ? "stats.last_7_days".localized : "stats.last_30_days".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                if data.isEmpty {
                    Text("stats.no_routines".localized)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.lg)
                } else {
                    WeeklyBarChart(data: data, color: ColorTokens.success)
                }
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Preview
#Preview {
    CrewView()
        .environmentObject(FocusAppStore.shared)
}
