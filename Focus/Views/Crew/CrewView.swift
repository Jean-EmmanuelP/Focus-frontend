import SwiftUI

struct CrewView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var viewModel = CrewViewModel()
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var showingShareSheet = false

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
                    case .groups:
                        groupsSection
                    case .requests:
                        requestsSection
                    }

                    // Account Section
                    accountSection
                }
                .padding(SpacingTokens.lg)
            }
            .refreshable {
                await viewModel.loadInitialData()
            }

            // Search overlay
            if viewModel.showingSearch {
                searchOverlay
            }
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.showingSearch) { _, isShowing in
            if isShowing && viewModel.suggestedUsers.isEmpty {
                Task {
                    await viewModel.loadSuggestedUsers()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingMemberDetail) {
            if viewModel.selectedMember != nil {
                MemberDayDetailView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showingCreateGroup) {
            CreateGroupView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingGroupDetail) {
            if viewModel.selectedGroup != nil {
                GroupDetailView(viewModel: viewModel)
            }
        }
        .alert("common.error".localized, isPresented: $viewModel.showError) {
            Button("common.ok".localized, role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "error.generic".localized)
        }
        .task {
            await viewModel.loadInitialData()
        }
        .onAppear {
            // Connect to WebSocket for real-time focus updates
            viewModel.connectWebSocket()
            // Start auto-refresh as fallback
            viewModel.startLeaderboardAutoRefresh()
        }
        .onDisappear {
            viewModel.stopLeaderboardAutoRefresh()
            // Keep WebSocket connected for background updates
        }
        .onChange(of: viewModel.activeTab) { _, newTab in
            // Restart auto-refresh when switching to leaderboard tab
            if newTab == .leaderboard {
                viewModel.startLeaderboardAutoRefresh()
            }
        }
        .id(localization.currentLanguage) // Force refresh when language changes
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("👥")
                    .font(.satoshi(28))

                Text("crew.title".localized)
                    .label()
                    .font(.satoshi(20, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                // Search button
                Button {
                    withAnimation {
                        viewModel.showingSearch = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.satoshi(20, weight: .medium))
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

    // MARK: - Tab Selector (Segmented Control)
    private var tabSelector: some View {
        GeometryReader { geometry in
            let tabWidth = (geometry.size.width - SpacingTokens.xs * 2) / CGFloat(CrewTab.allCases.count)
            let selectedIndex = CGFloat(CrewTab.allCases.firstIndex(of: viewModel.activeTab) ?? 0)

            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.surface)

                // Selection indicator
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(ColorTokens.primarySoft)
                    .frame(width: tabWidth - SpacingTokens.xs)
                    .padding(SpacingTokens.xs / 2)
                    .offset(x: selectedIndex * tabWidth + SpacingTokens.xs / 2)

                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(CrewTab.allCases, id: \.self) { tab in
                        segmentedTabButton(tab, width: tabWidth)
                    }
                }
            }
        }
        .frame(height: 44)
    }

    private func segmentedTabButton(_ tab: CrewTab, width: CGFloat) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.activeTab = tab
            }
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Text(tab.displayName)
                    .font(.system(size: 13, weight: viewModel.activeTab == tab ? .semibold : .medium))

                // Badge for requests (friend requests + group invitations)
                if tab == .requests && viewModel.hasNewRequests {
                    Text("\(viewModel.totalPendingCount)")
                        .font(.satoshi(10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(ColorTokens.primaryStart)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(viewModel.activeTab == tab ? ColorTokens.primaryStart : ColorTokens.textMuted)
            .frame(width: width, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Leaderboard Section
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack {
                    Text("🏆")
                        .font(.satoshi(20))
                    Text("crew.top_builders".localized)
                        .subtitle()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()
                }

                Text("crew.ranking_hint".localized)
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textSecondary)
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
                                    createdAt: nil,
                                    email: entry.email
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
                    .font(.satoshi(20))
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

    // MARK: - Requests Section (Simplified)
    @State private var showSentRequests = false

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            // Inbox: Received Requests & Invitations (combined)
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    Text("📥")
                        .font(.satoshi(20))
                    Text("crew.inbox".localized)
                        .subtitle()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()

                    if viewModel.totalReceivedCount > 0 {
                        Text("\(viewModel.totalReceivedCount)")
                            .font(.satoshi(12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTokens.primaryStart)
                            .clipShape(Capsule())
                    }
                }

                if viewModel.isLoadingRequests || viewModel.isLoadingGroupInvitations {
                    loadingView
                } else if viewModel.receivedRequests.isEmpty && viewModel.receivedGroupInvitations.isEmpty {
                    emptyInboxCard
                } else {
                    VStack(spacing: SpacingTokens.sm) {
                        // Friend requests first
                        ForEach(viewModel.receivedRequests) { request in
                            CrewRequestRow(
                                request: request,
                                isReceived: true,
                                onAccept: {
                                    HapticFeedback.success()
                                    Task {
                                        _ = await viewModel.acceptRequest(request)
                                    }
                                },
                                onReject: {
                                    HapticFeedback.light()
                                    Task {
                                        _ = await viewModel.rejectRequest(request)
                                    }
                                }
                            )
                        }

                        // Then group invitations
                        ForEach(viewModel.receivedGroupInvitations) { invitation in
                            GroupInvitationRow(
                                invitation: invitation,
                                isReceived: true,
                                onAccept: {
                                    HapticFeedback.success()
                                    Task {
                                        _ = await viewModel.acceptGroupInvitation(invitation)
                                    }
                                },
                                onReject: {
                                    HapticFeedback.light()
                                    Task {
                                        _ = await viewModel.rejectGroupInvitation(invitation)
                                    }
                                }
                            )
                        }
                    }
                }
            }

            // Sent Requests (collapsible)
            if !viewModel.sentRequests.isEmpty || !viewModel.sentGroupInvitations.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showSentRequests.toggle()
                        }
                    }) {
                        HStack {
                            Text("📤")
                                .font(.satoshi(20))
                            Text("crew.sent".localized)
                                .subtitle()
                                .fontWeight(.semibold)
                                .foregroundColor(ColorTokens.textPrimary)

                            Text("\(viewModel.sentRequests.count + viewModel.sentGroupInvitations.count)")
                                .font(.satoshi(12))
                                .foregroundColor(ColorTokens.textMuted)

                            Spacer()

                            Image(systemName: showSentRequests ? "chevron.up" : "chevron.down")
                                .font(.satoshi(14))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    if showSentRequests {
                        VStack(spacing: SpacingTokens.sm) {
                            ForEach(viewModel.sentRequests) { request in
                                CrewRequestRow(
                                    request: request,
                                    isReceived: false,
                                    onAccept: {},
                                    onReject: {}
                                )
                            }

                            ForEach(viewModel.sentGroupInvitations) { invitation in
                                GroupInvitationRow(
                                    invitation: invitation,
                                    isReceived: false,
                                    onAccept: {},
                                    onReject: {
                                        Task {
                                            _ = await viewModel.cancelGroupInvitation(invitation)
                                        }
                                    }
                                )
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .task {
            await viewModel.loadSentRequests()
            await viewModel.loadSentGroupInvitations()
        }
    }

    // MARK: - Empty Inbox Card (Friendlier)
    private var emptyInboxCard: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(ColorTokens.textMuted.opacity(0.5))

            VStack(spacing: SpacingTokens.xs) {
                Text("crew.inbox_empty".localized)
                    .font(.satoshi(16, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("crew.inbox_empty_hint".localized)
                    .font(.satoshi(13))
                    .foregroundColor(ColorTokens.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.xl)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Search Overlay
    private var searchOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.showingSearch = false
                            viewModel.clearSearch()
                        }
                    }

                // Search container - 90% height, full width
                VStack(spacing: 0) {
                    // Header with close button
                    HStack {
                        Text("crew.search_friends".localized)
                            .font(.satoshi(20, weight: .bold))
                            .foregroundColor(ColorTokens.textPrimary)

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewModel.showingSearch = false
                                viewModel.clearSearch()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ColorTokens.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(ColorTokens.surface)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.top, SpacingTokens.lg)
                    .padding(.bottom, SpacingTokens.md)

                    // Search bar
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundColor(ColorTokens.textMuted)

                        TextField("crew.search_placeholder".localized, text: $viewModel.searchQuery)
                            .font(.satoshi(16))
                            .foregroundColor(ColorTokens.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: viewModel.searchQuery) { _, _ in
                                viewModel.searchUsers()
                            }

                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                viewModel.clearSearch()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.md)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.lg)
                    .padding(.horizontal, SpacingTokens.lg)

                    // Divider
                    Rectangle()
                        .fill(ColorTokens.border.opacity(0.5))
                        .frame(height: 1)
                        .padding(.top, SpacingTokens.lg)

                    // Content area
                    ScrollView {
                        LazyVStack(spacing: SpacingTokens.sm) {
                            if viewModel.isSearching || viewModel.isLoadingSuggestions {
                                // Loading state
                                VStack(spacing: SpacingTokens.md) {
                                    Spacer().frame(height: 60)
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                                        .scaleEffect(1.2)
                                    Text("crew.searching".localized)
                                        .font(.satoshi(14))
                                        .foregroundColor(ColorTokens.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, SpacingTokens.xl)

                            } else if !viewModel.searchResults.isEmpty {
                                // Search results
                                ForEach(viewModel.searchResults) { result in
                                    SearchResultRow(
                                        result: result,
                                        onSendRequest: {
                                            Task {
                                                _ = await viewModel.sendRequest(to: result.id)
                                            }
                                        }
                                    )
                                    .padding(.horizontal, SpacingTokens.lg)
                                }

                            } else if !viewModel.searchQuery.isEmpty {
                                // No results found
                                VStack(spacing: SpacingTokens.md) {
                                    Spacer().frame(height: 60)
                                    Image(systemName: "person.slash")
                                        .font(.system(size: 48))
                                        .foregroundColor(ColorTokens.textMuted.opacity(0.5))
                                    Text("crew.no_users_found".localized)
                                        .font(.satoshi(16, weight: .medium))
                                        .foregroundColor(ColorTokens.textSecondary)
                                    Text("crew.try_different_search".localized)
                                        .font(.satoshi(14))
                                        .foregroundColor(ColorTokens.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, SpacingTokens.xl)

                            } else if !viewModel.suggestedUsers.isEmpty {
                                // Suggestions header
                                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                                    Text("crew.suggested".localized)
                                        .font(.satoshi(14, weight: .semibold))
                                        .foregroundColor(ColorTokens.textSecondary)
                                    Text("crew.suggested_hint".localized)
                                        .font(.satoshi(12))
                                        .foregroundColor(ColorTokens.textMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, SpacingTokens.lg)
                                .padding(.top, SpacingTokens.md)

                                // Suggested users
                                ForEach(viewModel.suggestedUsers) { user in
                                    SearchResultRow(
                                        result: user,
                                        onSendRequest: {
                                            Task {
                                                _ = await viewModel.sendRequest(to: user.id)
                                            }
                                        }
                                    )
                                    .padding(.horizontal, SpacingTokens.lg)
                                }

                            } else {
                                // Empty state - no suggestions
                                VStack(spacing: SpacingTokens.md) {
                                    Spacer().frame(height: 60)
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(ColorTokens.textMuted.opacity(0.5))
                                    Text("crew.search_hint".localized)
                                        .font(.satoshi(16, weight: .medium))
                                        .foregroundColor(ColorTokens.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, SpacingTokens.xl)
                            }
                        }
                        .padding(.top, SpacingTokens.md)
                        .padding(.bottom, SpacingTokens.xl)
                    }
                }
                .frame(width: geometry.size.width)
                .frame(height: geometry.size.height * 0.9)
                .background(ColorTokens.background)
                .cornerRadius(RadiusTokens.xl)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
                .offset(y: geometry.size.height * 0.05)
            }
        }
        .ignoresSafeArea()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Account Section
    private var accountSection: some View {
        // Version info
        Text("profile.version".localized)
            .font(.satoshi(10))
            .foregroundColor(ColorTokens.textMuted.opacity(0.6))
            .padding(.top, SpacingTokens.xs)
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
                    .font(.satoshi(40))
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

    // For live timer animation
    @State private var liveElapsedSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        Button(action: onTap) {
            Card {
                HStack(spacing: SpacingTokens.md) {
                    // Rank with medal for top 3
                    rankView

                    // Avatar with live indicator
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(
                            name: entry.displayName,
                            avatarURL: entry.avatarUrl,
                            size: 44,
                            allowZoom: true
                        )

                        // Live indicator dot
                        if entry.safeIsLive {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(ColorTokens.surface, lineWidth: 2)
                                )
                                .offset(x: 2, y: 2)
                        }
                    }

                    // Info
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        HStack(spacing: SpacingTokens.xs) {
                            Text(entry.displayName)
                                .font(.satoshi(15, weight: .semibold))
                                .foregroundColor(ColorTokens.textPrimary)
                                .lineLimit(1)

                            if entry.safeIsCrewMember {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(ColorTokens.success)
                            }
                        }

                        // Stats row: streak flames only (focus time is shown on the right)
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(entry.safeCurrentStreak > 0 ? ColorTokens.primaryStart : ColorTokens.textMuted)
                            Text("\(entry.safeCurrentStreak)j")
                                .font(.satoshi(12, weight: .medium))
                                .foregroundColor(entry.safeCurrentStreak > 0 ? ColorTokens.primaryStart : ColorTokens.textMuted)
                        }
                    }

                    Spacer()

                    // Right side: Live timer OR weekly focus time
                    if entry.safeIsLive {
                        // Live focus indicator with real-time timer
                        liveTimerView
                    } else {
                        // Weekly focus time display
                        weeklyFocusView
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if entry.safeIsLive {
                startLiveTimer()
            }
        }
        .onDisappear {
            timerTask?.cancel()
        }
        .onChange(of: entry.safeIsLive) { _, isLive in
            if isLive {
                startLiveTimer()
            } else {
                timerTask?.cancel()
            }
        }
    }

    // MARK: - Rank View
    private var rankView: some View {
        ZStack {
            if entry.safeRank <= 3 {
                // Medal for top 3
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(rankEmoji)
                            .font(.system(size: 16))
                    )
            } else {
                Text("#\(entry.safeRank)")
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(ColorTokens.textMuted)
                    .frame(width: 32)
            }
        }
    }

    // MARK: - Live Timer View
    private var liveTimerView: some View {
        HStack(spacing: 4) {
            // Pulsing dot
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .modifier(PulsingAnimation())

            Text(formattedLiveTime)
                .font(.satoshi(13, weight: .bold))
                .foregroundColor(.green)
                .monospacedDigit()
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(Color.green.opacity(0.15))
        .cornerRadius(RadiusTokens.md)
    }

    // MARK: - Weekly Focus Time View
    private var weeklyFocusView: some View {
        Text(entry.formattedFocusTime)
            .font(.satoshi(14, weight: .bold))
            .foregroundColor(ColorTokens.primaryStart)
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs)
            .background(ColorTokens.primarySoft)
            .cornerRadius(RadiusTokens.md)
    }

    // MARK: - Helpers
    private var rankColor: Color {
        switch entry.safeRank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return ColorTokens.accent  // Bronze replaced with teal accent
        default: return ColorTokens.textMuted
        }
    }

    private var rankEmoji: String {
        switch entry.safeRank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }

    private var formattedLiveTime: String {
        let minutes = liveElapsedSeconds / 60
        let seconds = liveElapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startLiveTimer() {
        // Initialize with current elapsed time
        if let elapsed = entry.liveElapsedSeconds {
            liveElapsedSeconds = elapsed
        }

        // Start timer to update every second
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if !Task.isCancelled {
                    await MainActor.run {
                        liveElapsedSeconds += 1
                    }
                }
            }
        }
    }
}

// MARK: - Pulsing Animation Modifier
struct PulsingAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
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
                                    .font(.satoshi(11))
                                    .foregroundColor(ColorTokens.textMuted)

                                let hours = minutes / 60
                                let mins = minutes % 60
                                let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
                                Label(timeStr, systemImage: "clock")
                                    .font(.satoshi(11))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                    }

                    Spacer()

                    // Visibility indicator
                    if let visibility = member.dayVisibility {
                        Image(systemName: visibilityIcon(visibility))
                            .font(.satoshi(14))
                            .foregroundColor(ColorTokens.textMuted)
                    }

                    // Remove button
                    Button {
                        showingRemoveAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.satoshi(14))
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
                                .font(.satoshi(14, weight: .medium))
                                .foregroundColor(ColorTokens.error)
                                .frame(width: 36, height: 36)
                                .background(ColorTokens.error.opacity(0.1))
                                .cornerRadius(RadiusTokens.sm)
                        }

                        Button {
                            onAccept()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.satoshi(14, weight: .medium))
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

// MARK: - Group Invitation Row
struct GroupInvitationRow: View {
    let invitation: GroupInvitation
    let isReceived: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        Card {
            HStack(spacing: SpacingTokens.md) {
                // Group icon
                ZStack {
                    Circle()
                        .fill(groupColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Text(invitation.group?.icon ?? "👥")
                        .font(.satoshi(20))
                }

                // Info
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text(invitation.group?.name ?? "crew.group".localized)
                        .bodyText()
                        .fontWeight(.medium)
                        .foregroundColor(ColorTokens.textPrimary)

                    if isReceived, let fromUser = invitation.fromUser {
                        Text("crew.invited_by".localized(with: fromUser.displayName))
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                    } else if let toUser = invitation.toUser {
                        Text("crew.invited_user".localized(with: toUser.displayName))
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    Text(invitation.createdAt.timeAgoDisplay())
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()

                // Actions
                if isReceived && invitation.status == "pending" {
                    HStack(spacing: SpacingTokens.sm) {
                        Button {
                            onReject()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.satoshi(14, weight: .medium))
                                .foregroundColor(ColorTokens.error)
                                .frame(width: 36, height: 36)
                                .background(ColorTokens.error.opacity(0.1))
                                .cornerRadius(RadiusTokens.sm)
                        }

                        Button {
                            onAccept()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.satoshi(14, weight: .medium))
                                .foregroundColor(ColorTokens.success)
                                .frame(width: 36, height: 36)
                                .background(ColorTokens.success.opacity(0.1))
                                .cornerRadius(RadiusTokens.sm)
                        }
                    }
                } else if !isReceived && invitation.status == "pending" {
                    // Sent invitation - can cancel
                    Button {
                        onReject()
                    } label: {
                        Text("common.cancel".localized)
                            .caption()
                            .foregroundColor(ColorTokens.error)
                            .padding(.horizontal, SpacingTokens.sm)
                            .padding(.vertical, SpacingTokens.xs)
                            .background(ColorTokens.error.opacity(0.1))
                            .cornerRadius(RadiusTokens.sm)
                    }
                } else {
                    // Status badge
                    Text(invitation.status.capitalized)
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

    private var groupColor: Color {
        if let colorHex = invitation.group?.color {
            return Color(hex: colorHex) ?? ColorTokens.primaryStart
        }
        return ColorTokens.primaryStart
    }

    private var statusColor: Color {
        switch invitation.status {
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
                                .font(.satoshi(12))
                                .foregroundColor(ColorTokens.success)
                        }
                    }

                    if let sessions = result.totalSessions7d {
                        Label("\(sessions) \("crew.sessions".localized) \("crew.this_week".localized)", systemImage: "flame.fill")
                            .font(.satoshi(11))
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
    @State private var selectedTab: MemberDetailTab = .calendar

    enum MemberDetailTab: String, CaseIterable {
        case calendar = "calendar"
        case routines = "routines"
        case stats = "stats"

        var title: String {
            switch self {
            case .calendar: return "crew.member.calendar".localized
            case .routines: return "crew.member.routines".localized
            case .stats: return "stats.title".localized
            }
        }

        var icon: String {
            switch self {
            case .calendar: return "calendar"
            case .routines: return "checkmark.circle"
            case .stats: return "chart.bar"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                if viewModel.isLoadingMemberDay {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                } else if let day = viewModel.selectedMemberDay {
                    VStack(spacing: 0) {
                        // User header compact
                        compactUserHeader(day.user)
                            .padding(.horizontal, SpacingTokens.lg)
                            .padding(.top, SpacingTokens.sm)

                        // Week calendar strip
                        weekCalendarStrip
                            .padding(.top, SpacingTokens.md)

                        // Tab selector
                        memberTabSelector
                            .padding(.horizontal, SpacingTokens.lg)
                            .padding(.top, SpacingTokens.md)

                        // Content based on selected tab
                        ScrollView {
                            VStack(spacing: SpacingTokens.lg) {
                                switch selectedTab {
                                case .calendar:
                                    calendarTabContent(day)
                                case .routines:
                                    routinesTabContent(day)
                                case .stats:
                                    statsTabContent(day)
                                }
                            }
                            .padding(SpacingTokens.lg)
                        }
                    }
                } else {
                    // Private or no permission
                    VStack(spacing: SpacingTokens.lg) {
                        Image(systemName: "lock.fill")
                            .font(.satoshi(60))
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

    // MARK: - Compact User Header
    private func compactUserHeader(_ user: CrewUserInfo) -> some View {
        HStack(spacing: SpacingTokens.md) {
            AvatarView(
                name: user.displayName,
                avatarURL: user.avatarUrl,
                size: 40,
                allowZoom: true
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .bodyText()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("crew.crew_member".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            Spacer()
        }
    }

    // MARK: - Week Calendar Strip
    private var weekCalendarStrip: some View {
        let calendar = Calendar.current
        let today = Date()
        let weekDays = getWeekDays(for: viewModel.selectedDate)

        return VStack(spacing: SpacingTokens.sm) {
            HStack {
                Button {
                    viewModel.changeSelectedDate(by: -7)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.satoshi(14, weight: .medium))
                        .foregroundColor(ColorTokens.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.sm)
                }

                Spacer()

                Text(monthYearString(from: viewModel.selectedDate))
                    .bodyText()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Button {
                    // Only allow going forward if not already at current week
                    if !calendar.isDate(viewModel.selectedDate, equalTo: today, toGranularity: .weekOfYear) {
                        viewModel.changeSelectedDate(by: 7)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.satoshi(14, weight: .medium))
                        .foregroundColor(calendar.isDate(viewModel.selectedDate, equalTo: today, toGranularity: .weekOfYear) ? ColorTokens.textMuted : ColorTokens.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.sm)
                }
                .disabled(calendar.isDate(viewModel.selectedDate, equalTo: today, toGranularity: .weekOfYear))
            }
            .padding(.horizontal, SpacingTokens.lg)

            // Week days
            HStack(spacing: SpacingTokens.xs) {
                ForEach(weekDays, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    let isFuture = date > today

                    Button {
                        if !isFuture {
                            viewModel.selectedDate = date
                            Task {
                                await viewModel.loadMemberDay()
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayOfWeekLetter(from: date))
                                .font(.satoshi(10, weight: .medium))
                                .foregroundColor(isSelected ? .white : ColorTokens.textMuted)

                            Text("\(calendar.component(.day, from: date))")
                                .font(.satoshi(14, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : (isFuture ? ColorTokens.textMuted.opacity(0.5) : ColorTokens.textPrimary))

                            // Indicator dot for today
                            if isToday && !isSelected {
                                Circle()
                                    .fill(ColorTokens.primaryStart)
                                    .frame(width: 4, height: 4)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.sm)
                        .background(isSelected ? ColorTokens.primaryStart : Color.clear)
                        .cornerRadius(RadiusTokens.md)
                    }
                    .disabled(isFuture)
                }
            }
            .padding(.horizontal, SpacingTokens.md)
        }
        .padding(.vertical, SpacingTokens.sm)
        .background(ColorTokens.surface)
    }

    // MARK: - Tab Selector
    private var memberTabSelector: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(MemberDetailTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: tab.icon)
                            .font(.satoshi(12))
                        Text(tab.title)
                            .font(.satoshi(12, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .white : ColorTokens.textMuted)
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.sm)
                    .background(selectedTab == tab ? ColorTokens.primaryStart : ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
                }
            }
        }
    }

    // MARK: - Calendar Tab Content
    private func calendarTabContent(_ day: CrewMemberDayResponse) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            // Daily schedule header
            HStack {
                Text("📅")
                    .font(.satoshi(18))
                Text("crew.member.daily_schedule".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
            }

            // Calendar Tasks
            if let tasks = day.tasks, !tasks.isEmpty {
                tasksSection(tasks)
            }

            // Intentions for the day
            if let intentions = day.intentions, !intentions.isEmpty {
                intentionsSection(intentions)
            }

            // Focus sessions timeline
            if let sessions = day.focusSessions, !sessions.isEmpty {
                focusSessionsSection(sessions)
            }

            // Scheduled routines
            if let routines = day.routines, !routines.isEmpty {
                scheduledRoutinesSection(routines)
            }

            // Empty state for calendar
            if (day.tasks ?? []).isEmpty &&
               (day.intentions ?? []).isEmpty &&
               (day.focusSessions ?? []).isEmpty &&
               (day.routines ?? []).isEmpty {
                emptyDayState
            }
        }
    }

    // MARK: - Tasks Section
    private func tasksSection(_ tasks: [CrewTask]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Planning du Jour")
                .caption()
                .fontWeight(.semibold)
                .foregroundColor(ColorTokens.textMuted)

            ForEach(tasks) { task in
                Card {
                    HStack(spacing: SpacingTokens.md) {
                        // Area icon or lock for private tasks
                        if task.isPrivate == true {
                            Image(systemName: "lock.fill")
                                .font(.satoshi(18))
                                .foregroundColor(ColorTokens.textMuted)
                        } else {
                            Text(task.areaIcon ?? "📋")
                                .font(.satoshi(20))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.satoshi(14, weight: .medium))
                                .foregroundColor(task.isPrivate == true ? ColorTokens.textMuted : ColorTokens.textPrimary)
                                .lineLimit(1)
                                .italic(task.isPrivate == true)

                            HStack(spacing: SpacingTokens.sm) {
                                // Time if available
                                if let start = task.scheduledStart, let end = task.scheduledEnd {
                                    Text("\(start) - \(end)")
                                        .caption()
                                        .foregroundColor(ColorTokens.textMuted)
                                } else {
                                    Text(task.timeBlock.capitalized)
                                        .caption()
                                        .foregroundColor(ColorTokens.textMuted)
                                }

                                // Area name if available (not shown for private tasks)
                                if let areaName = task.areaName, task.isPrivate != true {
                                    Text("•")
                                        .caption()
                                        .foregroundColor(ColorTokens.textMuted)
                                    Text(areaName)
                                        .caption()
                                        .foregroundColor(ColorTokens.textMuted)
                                }
                            }
                        }

                        Spacer()

                        // Status indicator
                        if task.status == "completed" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ColorTokens.success)
                        } else {
                            Circle()
                                .stroke(ColorTokens.border, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .padding(SpacingTokens.md)
                }
            }
        }
    }

    // MARK: - Routines Tab Content
    private func routinesTabContent(_ day: CrewMemberDayResponse) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            if let routines = day.routines, !routines.isEmpty {
                allRoutinesSection(routines)
            } else {
                Card {
                    VStack(spacing: SpacingTokens.md) {
                        Image(systemName: "checkmark.circle")
                            .font(.satoshi(40))
                            .foregroundColor(ColorTokens.textMuted)

                        Text("crew.member.no_routines_scheduled".localized)
                            .bodyText()
                            .foregroundColor(ColorTokens.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(SpacingTokens.lg)
                }
            }
        }
    }

    // MARK: - Stats Tab Content
    private func statsTabContent(_ day: CrewMemberDayResponse) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            if let stats = day.stats {
                // Weekly stats card
                Card {
                    VStack(alignment: .leading, spacing: SpacingTokens.md) {
                        Text("stats.this_week".localized)
                            .bodyText()
                            .fontWeight(.semibold)
                            .foregroundColor(ColorTokens.textPrimary)

                        HStack(spacing: SpacingTokens.lg) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatMinutes(stats.weeklyTotalFocus ?? 0))
                                    .font(.satoshi(24, weight: .bold))
                                    .foregroundColor(ColorTokens.primaryStart)
                                Text("stats.focus_time".localized)
                                    .caption()
                                    .foregroundColor(ColorTokens.textMuted)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 4) {
                                let routineRate = (stats.weeklyTotalRoutines ?? 0) > 0 ? (stats.weeklyRoutineRate ?? 0) : 0
                                Text("\(routineRate)%")
                                    .font(.satoshi(24, weight: .bold))
                                    .foregroundColor(ColorTokens.success)
                                Text("stats.routines".localized)
                                    .caption()
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                    }
                }

                // Weekly focus chart
                if let focusData = stats.weeklyFocusMinutes, !focusData.isEmpty {
                    weeklyGraphSection(
                        title: "stats.focus_sessions".localized,
                        subtitle: "stats.last_7_days".localized,
                        data: focusData,
                        color: ColorTokens.primaryStart
                    )
                }

                // Weekly routines chart
                if let routinesData = stats.weeklyRoutinesDone, !routinesData.isEmpty {
                    weeklyGraphSection(
                        title: "stats.daily_routines".localized,
                        subtitle: "stats.last_7_days".localized,
                        data: routinesData,
                        color: ColorTokens.success
                    )
                }
            } else {
                Card {
                    VStack(spacing: SpacingTokens.md) {
                        Image(systemName: "chart.bar")
                            .font(.satoshi(40))
                            .foregroundColor(ColorTokens.textMuted)

                        Text("stats.no_sessions".localized)
                            .bodyText()
                            .foregroundColor(ColorTokens.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(SpacingTokens.lg)
                }
            }
        }
    }

    // MARK: - Scheduled Routines Section
    private func scheduledRoutinesSection(_ routines: [CrewRoutine]) -> some View {
        let completedCount = routines.filter { $0.completed }.count
        let totalCount = routines.count

        return VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("✨")
                    .font(.satoshi(18))
                Text("crew.member.routines".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                // Progress pill
                Text("\(completedCount)/\(totalCount)")
                    .font(.satoshi(12, weight: .semibold))
                    .foregroundColor(completedCount == totalCount ? .white : ColorTokens.textPrimary)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, 4)
                    .background(completedCount == totalCount ? ColorTokens.success : ColorTokens.surface)
                    .cornerRadius(RadiusTokens.full)
            }

            VStack(spacing: SpacingTokens.sm) {
                ForEach(routines) { routine in
                    Card {
                        HStack(spacing: SpacingTokens.sm) {
                            // Completion indicator
                            Image(systemName: routine.completed ? "checkmark.circle.fill" : "circle")
                                .font(.satoshi(20))
                                .foregroundColor(routine.completed ? ColorTokens.success : ColorTokens.textMuted)

                            // Icon
                            Text(routine.icon ?? "✨")
                                .font(.satoshi(18))

                            // Title
                            Text(routine.title)
                                .bodyText()
                                .foregroundColor(routine.completed ? ColorTokens.textPrimary : ColorTokens.textMuted)

                            Spacer()

                            // Like button for completed routines
                            if routine.completed {
                                RoutineLikeButton(
                                    isLiked: routine.isLikedByMe ?? false,
                                    likeCount: routine.likeCount ?? 0
                                ) {
                                    Task {
                                        await viewModel.toggleRoutineLike(
                                            completionId: routine.id,
                                            isCurrentlyLiked: routine.isLikedByMe ?? false
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .opacity(routine.completed ? 1.0 : 0.7)
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func getWeekDays(for date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func dayOfWeekLetter(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1)).uppercased()
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func intentionsSection(_ intentions: [CrewIntention]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🎯")
                    .font(.satoshi(18))
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
                    .font(.satoshi(18))
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
                                .font(.satoshi(10))
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
                                .font(.satoshi(10))
                                .foregroundColor(ColorTokens.textMuted)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            // Fix: Show 0% if no routines exist or total is 0
                            let routineRate = (stats.weeklyTotalRoutines ?? 0) > 0 ? (stats.weeklyRoutineRate ?? 0) : 0
                            Text("\(routineRate)%")
                                .bodyText()
                                .fontWeight(.semibold)
                                .foregroundColor(ColorTokens.textPrimary)
                            Text("crew.routines_done".localized)
                                .font(.satoshi(10))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }

                    Spacer()

                    HStack(spacing: SpacingTokens.xs) {
                        Text("stats.view_stats".localized)
                            .caption()
                            .foregroundColor(ColorTokens.primaryStart)
                        Image(systemName: "chart.bar.fill")
                            .font(.satoshi(12))
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
                    .font(.satoshi(18))
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
                                .font(.satoshi(16))

                            Text(routine.title)
                                .bodyText()
                                .foregroundColor(ColorTokens.textPrimary)

                            Spacer()

                            // Like button and count
                            RoutineLikeButton(
                                isLiked: routine.isLikedByMe ?? false,
                                likeCount: routine.likeCount ?? 0
                            ) {
                                Task {
                                    await viewModel.toggleRoutineLike(
                                        completionId: routine.id,
                                        isCurrentlyLiked: routine.isLikedByMe ?? false
                                    )
                                }
                            }
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
                    .font(.satoshi(18))
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
                                .font(.satoshi(18))
                                .foregroundColor(routine.completed ? ColorTokens.success : ColorTokens.textMuted)

                            // Icon
                            Text(routine.icon ?? "✨")
                                .font(.satoshi(16))

                            // Title
                            Text(routine.title)
                                .bodyText()
                                .foregroundColor(routine.completed ? ColorTokens.textPrimary : ColorTokens.textMuted)
                                .strikethrough(!routine.completed ? false : false) // No strikethrough, just dim

                            Spacer()

                            // Like button for completed routines only
                            if routine.completed {
                                RoutineLikeButton(
                                    isLiked: routine.isLikedByMe ?? false,
                                    likeCount: routine.likeCount ?? 0
                                ) {
                                    Task {
                                        await viewModel.toggleRoutineLike(
                                            completionId: routine.id,
                                            isCurrentlyLiked: routine.isLikedByMe ?? false
                                        )
                                    }
                                }
                            }
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
                    .font(.satoshi(40))
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
                        .font(.satoshi(14))
                        .foregroundColor(color)
                    Spacer()
                }

                Text(value)
                    .font(.satoshi(22, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .caption()
                        .fontWeight(.medium)
                        .foregroundColor(ColorTokens.textPrimary)
                    Text(subtitle)
                        .font(.satoshi(10))
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
                        .font(.satoshi(10, weight: .medium))
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
        // Fix: Show 0% if no routines exist
        let routineRate = routinesDone > 0 ? (stats.weeklyRoutineRate ?? 0) : 0

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

// MARK: - Groups Section Extension
extension CrewView {
    var groupsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("👥")
                    .font(.satoshi(20))
                Text("crew.groups.title".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()

                // Create group button
                Button {
                    viewModel.selectedMembersForGroup.removeAll()
                    viewModel.showingCreateGroup = true
                } label: {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: "plus")
                            .font(.satoshi(14, weight: .semibold))
                        Text("crew.groups.create".localized)
                            .caption()
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.sm)
                    .background(ColorTokens.primaryStart)
                    .cornerRadius(RadiusTokens.md)
                }
            }

            if viewModel.isLoadingGroups {
                loadingView
            } else if viewModel.crewGroups.isEmpty {
                emptyStateCard(
                    icon: "person.3",
                    title: "crew.groups.empty".localized,
                    subtitle: "crew.groups.empty_hint".localized
                )
            } else {
                VStack(spacing: SpacingTokens.sm) {
                    ForEach(viewModel.crewGroups) { group in
                        CrewGroupRow(
                            group: group,
                            onTap: {
                                viewModel.selectGroup(group)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Crew Group Row
struct CrewGroupRow: View {
    let group: CrewGroup
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card {
                HStack(spacing: SpacingTokens.md) {
                    // Group icon
                    Text(group.icon)
                        .font(.satoshi(24))
                        .frame(width: 44, height: 44)
                        .background(Color(hex: group.color).opacity(0.2))
                        .cornerRadius(RadiusTokens.md)

                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text(group.name)
                            .bodyText()
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textPrimary)

                        Text("\(group.memberCount) \("crew.members".localized)")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.satoshi(14))
                        .foregroundColor(ColorTokens.textMuted)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Create Group View
struct CreateGroupView: View {
    @ObservedObject var viewModel: CrewViewModel
    @Environment(\.dismiss) var dismiss

    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var selectedIcon = "👥"
    @State private var selectedColor = "#6366F1"
    @State private var isCreating = false

    private let icons = ["👥", "💪", "🏃", "📚", "💼", "🎯", "⭐️", "🔥", "🎮", "🏋️"]
    private let colors = ["#6366F1", "#EC4899", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#06B6D4", "#84CC16"]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.lg) {
                        // Group Name
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("crew.groups.name".localized)
                                .bodyText()
                                .fontWeight(.medium)
                                .foregroundColor(ColorTokens.textPrimary)

                            TextField("crew.groups.name_placeholder".localized, text: $groupName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(SpacingTokens.sm)
                                .background(ColorTokens.surface)
                                .cornerRadius(RadiusTokens.md)
                        }

                        // Icon Selection
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("crew.groups.icon".localized)
                                .bodyText()
                                .fontWeight(.medium)
                                .foregroundColor(ColorTokens.textPrimary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: SpacingTokens.sm) {
                                ForEach(icons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        Text(icon)
                                            .font(.satoshi(24))
                                            .frame(width: 50, height: 50)
                                            .background(selectedIcon == icon ? ColorTokens.primarySoft : ColorTokens.surface)
                                            .cornerRadius(RadiusTokens.md)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: RadiusTokens.md)
                                                    .stroke(selectedIcon == icon ? ColorTokens.primaryStart : Color.clear, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }

                        // Color Selection
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text("crew.groups.color".localized)
                                .bodyText()
                                .fontWeight(.medium)
                                .foregroundColor(ColorTokens.textPrimary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: SpacingTokens.sm) {
                                ForEach(colors, id: \.self) { color in
                                    Button {
                                        selectedColor = color
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedColor == color ? ColorTokens.textPrimary : Color.clear, lineWidth: 3)
                                            )
                                    }
                                }
                            }
                        }

                        // Members Selection
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            HStack {
                                Text("crew.groups.select_members".localized)
                                    .bodyText()
                                    .fontWeight(.medium)
                                    .foregroundColor(ColorTokens.textPrimary)

                                Spacer()

                                Text("\(viewModel.selectedMembersForGroup.count) \("common.selected".localized)")
                                    .caption()
                                    .foregroundColor(ColorTokens.primaryStart)
                            }

                            if viewModel.crewMembers.isEmpty {
                                Card {
                                    VStack(spacing: SpacingTokens.md) {
                                        Image(systemName: "person.2")
                                            .font(.satoshi(30))
                                            .foregroundColor(ColorTokens.textMuted)
                                        Text("crew.groups.no_friends".localized)
                                            .caption()
                                            .foregroundColor(ColorTokens.textMuted)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(SpacingTokens.lg)
                                }
                            } else {
                                VStack(spacing: SpacingTokens.sm) {
                                    ForEach(viewModel.crewMembers) { member in
                                        SelectableMemberRow(
                                            member: member,
                                            isSelected: viewModel.selectedMembersForGroup.contains(member.memberId),
                                            onToggle: {
                                                viewModel.toggleMemberSelection(member.memberId)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(SpacingTokens.lg)
                }
            }
            .navigationTitle("crew.groups.create_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        createGroup()
                    } label: {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("common.create".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .disabled(groupName.isEmpty || viewModel.selectedMembersForGroup.isEmpty || isCreating)
                }
            }
        }
    }

    private func createGroup() {
        isCreating = true
        Task {
            let success = await viewModel.createGroup(
                name: groupName,
                description: groupDescription.isEmpty ? nil : groupDescription,
                icon: selectedIcon,
                color: selectedColor
            )
            isCreating = false
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Selectable Member Row
struct SelectableMemberRow: View {
    let member: CrewMemberResponse
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Card {
                HStack(spacing: SpacingTokens.md) {
                    AvatarView(
                        name: member.displayName,
                        avatarURL: member.avatarUrl,
                        size: 40
                    )

                    Text(member.displayName)
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.satoshi(22))
                        .foregroundColor(isSelected ? ColorTokens.primaryStart : ColorTokens.textMuted)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Group Detail View
struct GroupDetailView: View {
    @ObservedObject var viewModel: CrewViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showingDeleteAlert = false
    @State private var showingLeaveAlert = false
    @State private var showingAddMembers = false
    @State private var showingInviteMembers = false
    @State private var showingEditGroup = false
    @State private var showingMemberDetail = false
    @State private var selectedMemberForDetail: CrewMemberResponse?

    // Check if current user is the owner of the group
    private var isCurrentUserOwner: Bool {
        guard let group = viewModel.selectedGroup,
              let currentUserId = AuthService.shared.userId else { return false }
        return group.members?.contains { member in
            member.memberId.lowercased() == currentUserId.lowercased() && member.safeIsOwner
        } ?? false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                if let group = viewModel.selectedGroup {
                    ScrollView {
                        VStack(spacing: SpacingTokens.lg) {
                            // Group Header
                            groupHeader(group)

                            // Shared Routines
                            groupRoutinesSection(group)

                            // Members List
                            membersSection(group)
                        }
                        .padding(SpacingTokens.lg)
                    }
                    .task {
                        await viewModel.loadGroupRoutines(groupId: group.id)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                }
            }
            .navigationTitle(viewModel.selectedGroup?.name ?? "crew.groups.detail".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done".localized) {
                        dismiss()
                        viewModel.closeGroupDetail()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        // Only owner can edit group
                        if isCurrentUserOwner {
                            Button {
                                showingEditGroup = true
                            } label: {
                                Label("crew.groups.edit".localized, systemImage: "pencil")
                            }
                        }

                        Button {
                            showingInviteMembers = true
                        } label: {
                            Label("crew.groups.invite".localized, systemImage: "person.badge.plus")
                        }

                        Button {
                            showingAddMembers = true
                        } label: {
                            Label("crew.groups.add_members".localized, systemImage: "person.2.badge.gearshape")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingLeaveAlert = true
                        } label: {
                            Label("crew.groups.leave".localized, systemImage: "rectangle.portrait.and.arrow.right")
                        }

                        // Only owner can delete group
                        if isCurrentUserOwner {
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("crew.groups.delete".localized, systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(ColorTokens.textPrimary)
                    }
                }
            }
            .alert("crew.groups.delete_title".localized, isPresented: $showingDeleteAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("common.delete".localized, role: .destructive) {
                    if let group = viewModel.selectedGroup {
                        Task {
                            _ = await viewModel.deleteGroup(group)
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("crew.groups.delete_confirm".localized)
            }
            .alert("crew.groups.leave_title".localized, isPresented: $showingLeaveAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("crew.groups.leave".localized, role: .destructive) {
                    if let group = viewModel.selectedGroup {
                        Task {
                            _ = await viewModel.leaveGroup(group)
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("crew.groups.leave_confirm".localized)
            }
            .sheet(isPresented: $showingAddMembers) {
                AddMembersToGroupView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingInviteMembers) {
                InviteToGroupView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingShareRoutine) {
                ShareRoutineSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditGroup) {
                EditGroupSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingMemberDetail) {
                if let member = selectedMemberForDetail {
                    GroupMemberDayDetailView(viewModel: viewModel, member: member)
                }
            }
        }
    }

    // MARK: - Group Routines Section

    private func groupRoutinesSection(_ group: CrewGroup) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("crew.groups.shared_routines".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
                Button {
                    viewModel.startShareRoutine()
                } label: {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text("crew.groups.share_routine".localized)
                    }
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }

            if viewModel.isLoadingGroupRoutines {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, SpacingTokens.lg)
            } else if viewModel.groupRoutines.isEmpty {
                Card {
                    VStack(spacing: SpacingTokens.md) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.satoshi(30))
                            .foregroundColor(ColorTokens.textMuted)
                        Text("crew.groups.no_shared_routines".localized)
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                        Text("crew.groups.share_routine_hint".localized)
                            .font(.satoshi(12))
                            .foregroundColor(ColorTokens.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(SpacingTokens.lg)
                }
            } else {
                VStack(spacing: SpacingTokens.sm) {
                    ForEach(viewModel.groupRoutines) { routine in
                        GroupRoutineRow(
                            routine: routine,
                            currentUserId: AuthService.shared.userId ?? "",
                            onToggle: { isCurrentlyCompleted, onSuccess, onError in
                                // Toggle in background - no UI blocking
                                Task {
                                    let routineService = RoutineService()
                                    // Use today's date explicitly
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateFormat = "yyyy-MM-dd"
                                    let todayStr = dateFormatter.string(from: Date())

                                    do {
                                        if isCurrentlyCompleted {
                                            print("🔄 Uncompleting routine \(routine.routineId) for \(todayStr)")
                                            try await routineService.uncompleteRoutine(id: routine.routineId, date: todayStr)
                                        } else {
                                            print("✅ Completing routine \(routine.routineId) for \(todayStr)")
                                            try await routineService.completeRoutine(id: routine.routineId, date: todayStr)
                                        }
                                        // Silent refresh - no loading indicator
                                        await viewModel.refreshGroupRoutinesSilently(groupId: group.id)
                                        // Notify success to reset local state
                                        await MainActor.run { onSuccess() }
                                    } catch {
                                        print("❌ Toggle error: \(error)")
                                        // Network error - revert optimistic update
                                        await MainActor.run {
                                            onError()
                                            HapticFeedback.error()
                                        }
                                    }
                                }
                            },
                            onRemove: {
                                Task {
                                    _ = await viewModel.removeRoutineFromGroup(
                                        groupId: group.id,
                                        groupRoutineId: routine.id
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func groupHeader(_ group: CrewGroup) -> some View {
        Card {
            VStack(spacing: SpacingTokens.md) {
                Text(group.icon)
                    .font(.satoshi(50))
                    .frame(width: 80, height: 80)
                    .background(Color(hex: group.color).opacity(0.2))
                    .cornerRadius(RadiusTokens.lg)

                // Tappable name for owner to edit
                if isCurrentUserOwner {
                    Button {
                        showingEditGroup = true
                    } label: {
                        HStack(spacing: SpacingTokens.xs) {
                            Text(group.name)
                                .font(.satoshi(22, weight: .bold))
                                .foregroundColor(ColorTokens.textPrimary)
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                } else {
                    Text(group.name)
                        .font(.satoshi(22, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)
                }

                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .bodyText()
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Text("\(group.memberCount) \("crew.members".localized)")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.md)
        }
    }

    private func membersSection(_ group: CrewGroup) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("crew.members".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
            }

            if let members = group.members, !members.isEmpty {
                VStack(spacing: SpacingTokens.sm) {
                    ForEach(members) { member in
                        GroupMemberRow(
                            member: member,
                            onViewDay: {
                                // Convert to CrewMemberResponse and show detail in a new sheet
                                let crewMember = CrewMemberResponse(
                                    id: member.id,
                                    memberId: member.memberId,
                                    pseudo: member.pseudo,
                                    firstName: member.firstName,
                                    lastName: member.lastName,
                                    avatarUrl: member.avatarUrl,
                                    dayVisibility: nil,
                                    totalSessions7d: nil,
                                    totalMinutes7d: nil,
                                    activityScore: nil,
                                    createdAt: nil,
                                    email: nil
                                )
                                selectedMemberForDetail = crewMember
                                showingMemberDetail = true
                            },
                            onRemove: {
                                Task {
                                    _ = await viewModel.removeMemberFromGroup(
                                        groupId: group.id,
                                        memberId: member.memberId
                                    )
                                }
                            }
                        )
                    }
                }
            } else {
                Card {
                    VStack(spacing: SpacingTokens.md) {
                        Image(systemName: "person.2.slash")
                            .font(.satoshi(30))
                            .foregroundColor(ColorTokens.textMuted)
                        Text("crew.groups.no_members".localized)
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(SpacingTokens.lg)
                }
            }
        }
    }
}

// MARK: - Group Member Row
struct GroupMemberRow: View {
    let member: CrewGroupMember
    let onViewDay: () -> Void
    let onRemove: () -> Void

    @State private var showingRemoveAlert = false

    var body: some View {
        Card {
            HStack(spacing: SpacingTokens.md) {
                AvatarView(
                    name: member.displayName,
                    avatarURL: member.avatarUrl,
                    size: 44
                )

                Text(member.displayName)
                    .bodyText()
                    .fontWeight(.medium)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                // View day button
                Button(action: onViewDay) {
                    Image(systemName: "calendar")
                        .font(.satoshi(16))
                        .foregroundColor(ColorTokens.primaryStart)
                        .frame(width: 36, height: 36)
                        .background(ColorTokens.primarySoft)
                        .cornerRadius(RadiusTokens.sm)
                }

                // Remove button
                Button {
                    showingRemoveAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.satoshi(14))
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .alert("crew.groups.remove_member".localized, isPresented: $showingRemoveAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("crew.remove".localized, role: .destructive) {
                onRemove()
            }
        } message: {
            Text("crew.groups.remove_member_confirm".localized(with: member.displayName))
        }
    }
}

// MARK: - Add Members to Group View
struct AddMembersToGroupView: View {
    @ObservedObject var viewModel: CrewViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedMembers: Set<String> = []
    @State private var isAdding = false

    // Get members not already in the group
    private var availableMembers: [CrewMemberResponse] {
        let existingMemberIds = Set(viewModel.selectedGroup?.members?.map { $0.memberId } ?? [])
        return viewModel.crewMembers.filter { !existingMemberIds.contains($0.memberId) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                if availableMembers.isEmpty {
                    VStack(spacing: SpacingTokens.lg) {
                        Image(systemName: "person.badge.plus")
                            .font(.satoshi(50))
                            .foregroundColor(ColorTokens.textMuted)

                        Text("crew.groups.all_members_added".localized)
                            .bodyText()
                            .foregroundColor(ColorTokens.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: SpacingTokens.sm) {
                            ForEach(availableMembers) { member in
                                SelectableMemberRow(
                                    member: member,
                                    isSelected: selectedMembers.contains(member.memberId),
                                    onToggle: {
                                        if selectedMembers.contains(member.memberId) {
                                            selectedMembers.remove(member.memberId)
                                        } else {
                                            selectedMembers.insert(member.memberId)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(SpacingTokens.lg)
                    }
                }
            }
            .navigationTitle("crew.groups.add_members".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addMembers()
                    } label: {
                        if isAdding {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("common.add".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .disabled(selectedMembers.isEmpty || isAdding)
                }
            }
        }
    }

    private func addMembers() {
        guard let groupId = viewModel.selectedGroup?.id else { return }

        isAdding = true
        Task {
            let success = await viewModel.addMembersToGroup(
                groupId: groupId,
                memberIds: Array(selectedMembers)
            )
            isAdding = false
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Edit Group Sheet
struct EditGroupSheet: View {
    @ObservedObject var viewModel: CrewViewModel
    @Environment(\.dismiss) var dismiss

    @State private var groupName: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                VStack(spacing: SpacingTokens.lg) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        Text("crew.groups.name".localized)
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)

                        TextField("crew.groups.name_placeholder".localized, text: $groupName)
                            .font(.satoshi(16))
                            .padding(SpacingTokens.md)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.md)
                                    .stroke(ColorTokens.border, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.top, SpacingTokens.lg)

                    Spacer()

                    // Save button
                    Button {
                        saveChanges()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("common.save".localized)
                            }
                        }
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            if groupName.isEmpty || groupName == viewModel.selectedGroup?.name {
                                ColorTokens.textMuted
                            } else {
                                ColorTokens.fireGradient
                            }
                        }
                        .cornerRadius(RadiusTokens.lg)
                    }
                    .disabled(groupName.isEmpty || groupName == viewModel.selectedGroup?.name || isSaving)
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.bottom, SpacingTokens.lg)
                }
            }
            .navigationTitle("crew.groups.edit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textMuted)
                }
            }
            .onAppear {
                groupName = viewModel.selectedGroup?.name ?? ""
            }
        }
    }

    private func saveChanges() {
        guard let group = viewModel.selectedGroup else { return }
        isSaving = true
        Task {
            let success = await viewModel.updateGroup(groupId: group.id, name: groupName)
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Group Member Day Detail View (shown from group detail)
struct GroupMemberDayDetailView: View {
    @ObservedObject var viewModel: CrewViewModel
    let member: CrewMemberResponse
    @Environment(\.dismiss) var dismiss

    @State private var selectedDate = Date()
    @State private var memberDay: CrewMemberDayResponse?
    @State private var isLoading = false

    private let crewService = CrewService()

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                } else if let day = memberDay {
                    VStack(spacing: 0) {
                        // User header compact
                        compactUserHeader(day.user)
                            .padding(.horizontal, SpacingTokens.lg)
                            .padding(.top, SpacingTokens.sm)

                        // Week calendar strip
                        weekCalendarStrip
                            .padding(.top, SpacingTokens.md)

                        // Content
                        ScrollView {
                            VStack(spacing: SpacingTokens.lg) {
                                calendarTabContent(day)
                            }
                            .padding(SpacingTokens.lg)
                        }
                    }
                } else {
                    // Private or no permission
                    VStack(spacing: SpacingTokens.lg) {
                        Image(systemName: "lock.fill")
                            .font(.satoshi(60))
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
            .navigationTitle(member.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
            .task {
                await loadMemberDay()
            }
        }
    }

    // MARK: - Load Data
    private func loadMemberDay() async {
        isLoading = true
        defer { isLoading = false }

        do {
            memberDay = try await crewService.fetchCrewMemberDay(
                userId: member.memberId,
                date: selectedDate
            )
        } catch {
            memberDay = nil
        }
    }

    // MARK: - Compact User Header
    private func compactUserHeader(_ user: CrewUserInfo) -> some View {
        HStack(spacing: SpacingTokens.md) {
            AvatarView(
                name: user.displayName,
                avatarURL: user.avatarUrl,
                size: 40,
                allowZoom: true
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .bodyText()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("crew.crew_member".localized)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            Spacer()
        }
    }

    // MARK: - Week Calendar Strip
    private var weekCalendarStrip: some View {
        let calendar = Calendar.current
        let today = Date()
        let weekDays = getWeekDays(for: selectedDate)

        return VStack(spacing: SpacingTokens.sm) {
            HStack {
                Button {
                    changeSelectedDate(by: -7)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.satoshi(14, weight: .medium))
                        .foregroundColor(ColorTokens.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.sm)
                }

                Spacer()

                Text(selectedDate, style: .date)
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Button {
                    changeSelectedDate(by: 7)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.satoshi(14, weight: .medium))
                        .foregroundColor(selectedDate > today ? ColorTokens.textMuted : ColorTokens.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.sm)
                }
                .disabled(calendar.isDate(selectedDate, inSameDayAs: today) || selectedDate > today)
            }
            .padding(.horizontal, SpacingTokens.lg)

            // Day pills
            HStack(spacing: 8) {
                ForEach(weekDays, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDate(date, inSameDayAs: today)
                    let isFuture = date > today

                    Button {
                        if !isFuture {
                            selectedDate = date
                            Task { await loadMemberDay() }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayOfWeekLetter(date))
                                .font(.satoshi(10, weight: .medium))
                                .foregroundColor(isSelected ? .white : ColorTokens.textMuted)

                            Text("\(calendar.component(.day, from: date))")
                                .font(.satoshi(14, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : (isFuture ? ColorTokens.textMuted : ColorTokens.textPrimary))
                        }
                        .frame(width: 40, height: 50)
                        .background(isSelected ? ColorTokens.primaryStart : (isToday ? ColorTokens.primarySoft : ColorTokens.surface))
                        .cornerRadius(RadiusTokens.md)
                    }
                    .disabled(isFuture)
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
        }
    }

    private func getWeekDays(for date: Date) -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func dayOfWeekLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    private func changeSelectedDate(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        if newDate > Date() { return }
        selectedDate = newDate
        Task { await loadMemberDay() }
    }

    // MARK: - Calendar Tab Content
    private func calendarTabContent(_ day: CrewMemberDayResponse) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            // Daily schedule header
            HStack {
                Text("📅")
                    .font(.satoshi(18))
                Text("crew.member.daily_schedule".localized)
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
            }

            // Calendar Tasks
            if let tasks = day.tasks, !tasks.isEmpty {
                tasksSection(tasks)
            }

            // Intentions for the day
            if let intentions = day.intentions, !intentions.isEmpty {
                intentionsSection(intentions)
            }

            // Focus sessions timeline
            if let sessions = day.focusSessions, !sessions.isEmpty {
                focusSessionsSection(sessions)
            }

            // Scheduled routines
            if let routines = day.routines, !routines.isEmpty {
                scheduledRoutinesSection(routines)
            }

            // Empty state for calendar
            if (day.tasks ?? []).isEmpty &&
               (day.intentions ?? []).isEmpty &&
               (day.focusSessions ?? []).isEmpty &&
               (day.routines ?? []).isEmpty {
                emptyDayState
            }
        }
    }

    // MARK: - Tasks Section
    private func tasksSection(_ tasks: [CrewTask]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Planning du Jour")
                .caption()
                .fontWeight(.semibold)
                .foregroundColor(ColorTokens.textMuted)

            ForEach(tasks) { task in
                Card {
                    HStack(spacing: SpacingTokens.md) {
                        // Area icon or lock for private tasks
                        if task.isPrivate == true {
                            Image(systemName: "lock.fill")
                                .font(.satoshi(18))
                                .foregroundColor(ColorTokens.textMuted)
                        } else {
                            Text(task.areaIcon ?? "📋")
                                .font(.satoshi(20))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.satoshi(14, weight: .medium))
                                .foregroundColor(task.isPrivate == true ? ColorTokens.textMuted : ColorTokens.textPrimary)
                                .lineLimit(1)
                                .italic(task.isPrivate == true)

                            HStack(spacing: SpacingTokens.sm) {
                                if let start = task.scheduledStart, let end = task.scheduledEnd {
                                    Text("\(start) - \(end)")
                                        .caption()
                                        .foregroundColor(ColorTokens.textMuted)
                                } else {
                                    Text(task.timeBlock.capitalized)
                                        .caption()
                                        .foregroundColor(ColorTokens.textMuted)
                                }

                                // Area name (not shown for private tasks)
                                if let areaName = task.areaName, task.isPrivate != true {
                                    Text("•")
                                        .caption()
                                        .foregroundColor(ColorTokens.textMuted)
                                    Text(areaName)
                                        .caption()
                                        .foregroundColor(ColorTokens.textMuted)
                                }
                            }
                        }

                        Spacer()

                        if task.status == "completed" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ColorTokens.success)
                        } else {
                            Circle()
                                .stroke(ColorTokens.border, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .padding(SpacingTokens.md)
                }
            }
        }
    }

    // MARK: - Intentions Section
    private func intentionsSection(_ intentions: [CrewIntention]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("crew.member.intentions".localized)
                .caption()
                .foregroundColor(ColorTokens.textMuted)

            ForEach(intentions) { intention in
                HStack(spacing: SpacingTokens.sm) {
                    Circle()
                        .fill(ColorTokens.primaryStart)
                        .frame(width: 8, height: 8)

                    Text(intention.content)
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)

                    Spacer()
                }
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
            }
        }
    }

    // MARK: - Focus Sessions Section
    private func focusSessionsSection(_ sessions: [CrewFocusSession]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("crew.member.focus_sessions".localized)
                .caption()
                .foregroundColor(ColorTokens.textMuted)

            ForEach(sessions) { session in
                HStack(spacing: SpacingTokens.md) {
                    Circle()
                        .fill(ColorTokens.primaryStart)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.description ?? "Focus Session")
                            .bodyText()
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textPrimary)

                        Text("\(session.durationMinutes) min")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)
                    }

                    Spacer()

                    Text(session.startedAt, style: .time)
                        .caption()
                        .foregroundColor(ColorTokens.textMuted)
                }
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
            }
        }
    }

    // MARK: - Routines Section
    private func scheduledRoutinesSection(_ routines: [CrewRoutine]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("crew.member.routines".localized)
                .caption()
                .foregroundColor(ColorTokens.textMuted)

            ForEach(routines) { routine in
                HStack(spacing: SpacingTokens.md) {
                    Text(routine.icon ?? "✨")
                        .font(.satoshi(18))

                    Text(routine.title)
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)
                        .strikethrough(routine.completed)

                    Spacer()

                    Image(systemName: routine.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(routine.completed ? ColorTokens.success : ColorTokens.textMuted)
                        .font(.satoshi(16))
                }
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
            }
        }
    }

    // MARK: - Empty State
    private var emptyDayState: some View {
        Card {
            VStack(spacing: SpacingTokens.md) {
                Image(systemName: "calendar.badge.clock")
                    .font(.satoshi(40))
                    .foregroundColor(ColorTokens.textMuted)

                Text("crew.member.no_activity".localized)
                    .bodyText()
                    .foregroundColor(ColorTokens.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.lg)
        }
    }
}

// MARK: - Invite To Group View
struct InviteToGroupView: View {
    @ObservedObject var viewModel: CrewViewModel
    @Environment(\.dismiss) var dismiss

    @State private var searchQuery = ""
    @State private var selectedUserId: String?
    @State private var isInviting = false
    @State private var searchResults: [SearchUserResult] = []
    @State private var isSearching = false

    private let crewService = CrewService()

    // Get members who are not already in the group and can be invited
    private var availableMembers: [CrewMemberResponse] {
        let existingMemberIds = Set(viewModel.selectedGroup?.members?.map { $0.memberId } ?? [])
        return viewModel.crewMembers.filter { !existingMemberIds.contains($0.memberId) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                VStack(spacing: SpacingTokens.md) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ColorTokens.textMuted)

                        TextField("crew.search_placeholder".localized, text: $searchQuery)
                            .foregroundColor(ColorTokens.textPrimary)
                            .onChange(of: searchQuery) { _, newValue in
                                searchUsers(query: newValue)
                            }

                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                    }
                    .padding(SpacingTokens.md)
                    .background(ColorTokens.surface)
                    .cornerRadius(RadiusTokens.md)
                    .padding(.horizontal, SpacingTokens.lg)

                    if isSearching {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                        Spacer()
                    } else if !searchResults.isEmpty {
                        // Show search results
                        ScrollView {
                            VStack(spacing: SpacingTokens.sm) {
                                ForEach(searchResults) { user in
                                    InviteUserRow(
                                        user: user,
                                        isSelected: selectedUserId == user.id,
                                        onSelect: {
                                            selectedUserId = user.id
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, SpacingTokens.lg)
                        }
                    } else if searchQuery.isEmpty {
                        // Show crew members who can be invited
                        if availableMembers.isEmpty {
                            Spacer()
                            VStack(spacing: SpacingTokens.lg) {
                                Image(systemName: "person.badge.plus")
                                    .font(.satoshi(50))
                                    .foregroundColor(ColorTokens.textMuted)

                                Text("crew.groups.no_members_to_invite".localized)
                                    .bodyText()
                                    .foregroundColor(ColorTokens.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            Spacer()
                        } else {
                            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                Text("crew.groups.invite_from_crew".localized)
                                    .caption()
                                    .foregroundColor(ColorTokens.textMuted)
                                    .padding(.horizontal, SpacingTokens.lg)

                                ScrollView {
                                    VStack(spacing: SpacingTokens.sm) {
                                        ForEach(availableMembers) { member in
                                            InviteCrewMemberRow(
                                                member: member,
                                                isSelected: selectedUserId == member.memberId,
                                                onSelect: {
                                                    selectedUserId = member.memberId
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, SpacingTokens.lg)
                                }
                            }
                        }
                    } else {
                        Spacer()
                        Text("crew.no_users_found".localized)
                            .bodyText()
                            .foregroundColor(ColorTokens.textMuted)
                        Spacer()
                    }
                }
                .padding(.top, SpacingTokens.md)
            }
            .navigationTitle("crew.groups.invite".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        inviteUser()
                    } label: {
                        if isInviting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("crew.groups.send_invite".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                    .disabled(selectedUserId == nil || isInviting)
                }
            }
        }
    }

    private func searchUsers(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // Debounce
                let results = try await crewService.searchUsers(query: query, limit: 20)
                searchResults = results
            } catch {
                print("Search error: \(error)")
                searchResults = []
            }
            isSearching = false
        }
    }

    private func inviteUser() {
        guard let groupId = viewModel.selectedGroup?.id,
              let userId = selectedUserId else { return }

        isInviting = true
        Task {
            let success = await viewModel.inviteToGroup(groupId: groupId, userId: userId)
            isInviting = false
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Invite User Row
struct InviteUserRow: View {
    let user: SearchUserResult
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Card {
                HStack(spacing: SpacingTokens.md) {
                    AvatarView(
                        name: user.displayName,
                        avatarURL: user.avatarUrl,
                        size: 44
                    )

                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text(user.displayName)
                            .bodyText()
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textPrimary)

                        if user.isCrewMember {
                            Text("crew.in_crew".localized)
                                .caption()
                                .foregroundColor(ColorTokens.success)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.satoshi(22))
                        .foregroundColor(isSelected ? ColorTokens.primaryStart : ColorTokens.textMuted)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Invite Crew Member Row
struct InviteCrewMemberRow: View {
    let member: CrewMemberResponse
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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

                        if let sessions = member.totalSessions7d {
                            Text("\(sessions) \("crew.sessions".localized)")
                                .caption()
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.satoshi(22))
                        .foregroundColor(isSelected ? ColorTokens.primaryStart : ColorTokens.textMuted)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
// MARK: - Routine Like Button
struct RoutineLikeButton: View {
    let isLiked: Bool
    let likeCount: Int
    let action: () -> Void

    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        Button(action: {
            hapticGenerator.impactOccurred()
            action()
        }) {
            HStack(spacing: 4) {
                Text(isLiked ? "❤️" : "🤍")
                    .font(.satoshi(16))
                    .scaleEffect(isLiked ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)

                if likeCount > 0 {
                    Text("\(likeCount)")
                        .font(.satoshi(12, weight: .medium))
                        .foregroundColor(isLiked ? ColorTokens.primaryStart : ColorTokens.textMuted)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            hapticGenerator.prepare()
        }
    }
}

// MARK: - Group Routine Row

struct GroupRoutineRow: View {
    let routine: GroupRoutine
    let currentUserId: String
    let onToggle: (Bool, @escaping () -> Void, @escaping () -> Void) -> Void  // (currentState, onSuccess, onError)
    let onRemove: () -> Void

    @State private var localCompletionState: Bool? = nil  // Optimistic UI state

    private var currentUserCompletion: GroupRoutineMemberCompletion? {
        routine.safeCompletions.first { $0.userId.lowercased() == currentUserId.lowercased() }
    }

    private var serverCompletedByMe: Bool {
        currentUserCompletion?.completed ?? false
    }

    // Use local state if set (optimistic), otherwise use server state
    private var isCompletedByMe: Bool {
        localCompletionState ?? serverCompletedByMe
    }

    // Members who completed the routine
    private var completedMembers: [GroupRoutineMemberCompletion] {
        routine.safeCompletions.filter { $0.completed }
    }

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Icon
            Text(routine.icon ?? "🔄")
                .font(.satoshi(20))
                .frame(width: 36, height: 36)
                .background(isCompletedByMe ? ColorTokens.success.opacity(0.15) : ColorTokens.primarySoft)
                .cornerRadius(RadiusTokens.sm)

            // Title (with strikethrough if completed by me)
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.title)
                    .font(.satoshi(14, weight: isCompletedByMe ? .medium : .semibold))
                    .foregroundColor(isCompletedByMe ? ColorTokens.textMuted : ColorTokens.textPrimary)
                    .strikethrough(isCompletedByMe, color: ColorTokens.textMuted)

                if let time = routine.scheduledTime {
                    Text(time)
                        .font(.satoshi(11))
                        .foregroundColor(ColorTokens.textMuted)
                }
            }

            Spacer()

            // Inline avatars of people who completed it
            HStack(spacing: -8) {
                ForEach(completedMembers.prefix(4)) { member in
                    AvatarView(
                        name: member.displayName,
                        avatarURL: member.avatarUrl,
                        size: 24
                    )
                    .overlay(
                        Circle()
                            .stroke(ColorTokens.surface, lineWidth: 2)
                    )
                }
                // Show +N if more than 4
                if completedMembers.count > 4 {
                    Text("+\(completedMembers.count - 4)")
                        .font(.satoshi(10, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(ColorTokens.surface, lineWidth: 2)
                        )
                }
            }

            // My completion button
            Button(action: {
                let currentState = isCompletedByMe
                HapticFeedback.light()

                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    localCompletionState = !currentState
                }

                onToggle(
                    currentState,
                    {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            localCompletionState = nil
                        }
                    },
                    {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            localCompletionState = currentState
                        }
                    }
                )
            }) {
                Image(systemName: isCompletedByMe ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isCompletedByMe ? ColorTokens.success : ColorTokens.textMuted)
            }
            .buttonStyle(PlainButtonStyle())
            .onChange(of: serverCompletedByMe) { _, _ in
                localCompletionState = nil
            }
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .stroke(isCompletedByMe ? ColorTokens.success.opacity(0.3) : ColorTokens.border, lineWidth: 1)
        )
    }
}

// Keep old expanded view as separate component for detail view if needed
struct GroupRoutineDetailRow: View {
    let routine: GroupRoutine
    let currentUserId: String
    let onToggle: (Bool, @escaping () -> Void, @escaping () -> Void) -> Void
    let onRemove: () -> Void

    @State private var isExpanded = false
    @State private var localCompletionState: Bool? = nil

    private var currentUserCompletion: GroupRoutineMemberCompletion? {
        routine.safeCompletions.first { $0.userId.lowercased() == currentUserId.lowercased() }
    }

    private var serverCompletedByMe: Bool {
        currentUserCompletion?.completed ?? false
    }

    private var isCompletedByMe: Bool {
        localCompletionState ?? serverCompletedByMe
    }

    var body: some View {
        Card {
            VStack(spacing: SpacingTokens.sm) {
                HStack(spacing: SpacingTokens.md) {
                    Text(routine.icon ?? "🔄")
                        .font(.satoshi(24))
                        .frame(width: 40, height: 40)
                        .background(ColorTokens.primarySoft)
                        .cornerRadius(RadiusTokens.sm)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.title)
                            .font(.satoshi(14, weight: .semibold))
                            .foregroundColor(ColorTokens.textPrimary)

                        if let time = routine.scheduledTime {
                            Text(time)
                                .font(.satoshi(12))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(routine.safeCompletionCount)/\(routine.safeTotalMembers)")
                            .font(.satoshi(14, weight: .semibold))
                            .foregroundColor(routine.safeCompletionCount == routine.safeTotalMembers ? ColorTokens.success : ColorTokens.textSecondary)

                        Text("fait")
                            .font(.satoshi(10))
                            .foregroundColor(ColorTokens.textMuted)
                    }

                    Button(action: {
                        let currentState = isCompletedByMe
                        HapticFeedback.light()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            localCompletionState = !currentState
                        }
                        onToggle(currentState, {
                            withAnimation { localCompletionState = nil }
                        }, {
                            withAnimation { localCompletionState = currentState }
                        })
                    }) {
                        Image(systemName: isCompletedByMe ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 26))
                            .foregroundColor(isCompletedByMe ? ColorTokens.success : ColorTokens.textMuted)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onChange(of: serverCompletedByMe) { _, _ in
                        localCompletionState = nil
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

                if isExpanded {
                    Divider()

                    VStack(spacing: SpacingTokens.xs) {
                        ForEach(routine.safeCompletions) { member in
                            HStack(spacing: SpacingTokens.sm) {
                                AvatarView(
                                    name: member.displayName,
                                    avatarURL: member.avatarUrl,
                                    size: 28
                                )

                                Text(member.displayName)
                                    .font(.satoshi(13))
                                    .foregroundColor(ColorTokens.textPrimary)

                                Spacer()

                                if member.completed {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.satoshi(18))
                                        .foregroundColor(ColorTokens.success)
                                } else {
                                    Image(systemName: "circle")
                                        .font(.satoshi(18))
                                        .foregroundColor(ColorTokens.textMuted)
                                }
                            }
                            .padding(.vertical, SpacingTokens.xs)
                        }
                    }

                    if let sharer = routine.sharedBy {
                        HStack {
                            Text("crew.groups.shared_by".localized)
                                .font(.satoshi(11))
                                .foregroundColor(ColorTokens.textMuted)
                            Text(sharer.displayName)
                                .font(.satoshi(11, weight: .medium))
                                .foregroundColor(ColorTokens.textSecondary)
                            Spacer()

                            // Remove button (only for sharer)
                            if sharer.id == currentUserId {
                                Button(action: onRemove) {
                                    Text("common.remove".localized)
                                        .font(.satoshi(11))
                                        .foregroundColor(ColorTokens.error)
                                }
                            }
                        }
                        .padding(.top, SpacingTokens.xs)
                    }
                }
            }
            .padding(SpacingTokens.md)
        }
    }
}

// MARK: - Share Routine Sheet

struct ShareRoutineSheet: View {
    @ObservedObject var viewModel: CrewViewModel
    @EnvironmentObject var store: FocusAppStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedRoutineId: String?
    @State private var isSharing = false
    @State private var showCreateRoutine = false
    @StateObject private var ritualsViewModel = RitualsViewModel()

    // Filter out routines already shared with this group
    private var availableRoutines: [RoutineResponse] {
        let sharedRoutineIds = Set(viewModel.groupRoutines.map { $0.routineId })
        return viewModel.userRoutines.filter { !sharedRoutineIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                contentView
            }
            .navigationTitle("Partager une routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        viewModel.closeShareRoutine()
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }

                ToolbarItem(placement: .primaryAction) {
                    if !availableRoutines.isEmpty {
                        Button("crew.groups.share".localized) {
                            shareRoutine()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.primaryStart)
                        .disabled(selectedRoutineId == nil || isSharing)
                        .opacity(selectedRoutineId == nil ? 0.5 : 1)
                    }
                }
            }
            .overlay {
                if isSharing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .sheet(isPresented: $showCreateRoutine) {
                AddRitualSheet(viewModel: ritualsViewModel, areas: store.areas)
                    .onDisappear {
                        Task {
                            await viewModel.loadUserRoutinesForSharing()
                        }
                    }
            }
            .onAppear {
                ritualsViewModel.refresh()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.userRoutines.isEmpty {
            emptyStateView
        } else if availableRoutines.isEmpty {
            allSharedStateView
        } else {
            routinesListView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: SpacingTokens.lg) {
            Image(systemName: "sparkles")
                .font(.satoshi(50))
                .foregroundColor(ColorTokens.primaryStart)

            Text("Aucune routine")
                .subtitle()
                .foregroundColor(ColorTokens.textSecondary)

            Text("Crée une routine pour la partager avec ton groupe")
                .bodyText()
                .foregroundColor(ColorTokens.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)

            PrimaryButton("Créer une routine", icon: "plus") {
                showCreateRoutine = true
            }
            .padding(.horizontal, SpacingTokens.xl)
        }
    }

    private var allSharedStateView: some View {
        VStack(spacing: SpacingTokens.lg) {
            Image(systemName: "checkmark.circle")
                .font(.satoshi(50))
                .foregroundColor(ColorTokens.success)

            Text("crew.groups.all_shared".localized)
                .subtitle()
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: { showCreateRoutine = true }) {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "plus.circle")
                    Text("Créer une nouvelle routine")
                }
                .font(.satoshi(14, weight: .medium))
                .foregroundColor(ColorTokens.primaryStart)
            }
            .padding(.top, SpacingTokens.md)
        }
    }

    private var routinesListView: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sm) {
                createNewRoutineButton

                Text("Ou sélectionne une routine existante")
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textMuted)
                    .padding(.vertical, SpacingTokens.sm)

                ForEach(availableRoutines) { routine in
                    routineRow(routine)
                }
            }
            .padding(SpacingTokens.md)
        }
    }

    private var createNewRoutineButton: some View {
        Button(action: { showCreateRoutine = true }) {
            HStack(spacing: SpacingTokens.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.sm)
                        .stroke(ColorTokens.primaryStart, style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.satoshi(20, weight: .medium))
                        .foregroundColor(ColorTokens.primaryStart)
                }

                Text("Créer une nouvelle routine")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.primaryStart)

                Spacer()
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.primarySoft.opacity(0.5))
            .cornerRadius(RadiusTokens.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func routineRow(_ routine: RoutineResponse) -> some View {
        Button {
            selectedRoutineId = routine.id
        } label: {
            Card {
                HStack(spacing: SpacingTokens.md) {
                    Text(routine.icon ?? "🔄")
                        .font(.satoshi(24))
                        .frame(width: 44, height: 44)
                        .background(ColorTokens.primarySoft)
                        .cornerRadius(RadiusTokens.sm)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.title)
                            .font(.satoshi(14, weight: .semibold))
                            .foregroundColor(ColorTokens.textPrimary)

                        Text(routine.frequency)
                            .font(.satoshi(12))
                            .foregroundColor(ColorTokens.textMuted)
                    }

                    Spacer()

                    Image(systemName: selectedRoutineId == routine.id ? "checkmark.circle.fill" : "circle")
                        .font(.satoshi(22))
                        .foregroundColor(selectedRoutineId == routine.id ? ColorTokens.primaryStart : ColorTokens.textMuted)
                }
                .padding(SpacingTokens.sm)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func shareRoutine() {
        guard let routineId = selectedRoutineId,
              let groupId = viewModel.selectedGroup?.id else { return }

        isSharing = true
        Task {
            let success = await viewModel.shareRoutineWithGroup(groupId: groupId, routineId: routineId)
            isSharing = false
            if success {
                viewModel.closeShareRoutine()
                dismiss()
            }
        }
    }
}

#Preview {
    CrewView()
        .environmentObject(FocusAppStore.shared)
}
