import SwiftUI

struct CrewView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var viewModel = CrewViewModel()
    @State private var showingShareSheet = false
    @State private var showingSignOutAlert = false

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
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                store.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .task {
            await viewModel.loadInitialData()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("👥")
                    .font(.system(size: 28))

                Text("CREW")
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

            Text("Build together. Grow together.")
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

                Text(tab.rawValue)
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
                Text("Top Builders This Week")
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
                    title: "No activity yet",
                    subtitle: "Start a focus session to appear on the leaderboard"
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
                Text("Your Crew")
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()

                Text("\(viewModel.crewMembers.count) members")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            if viewModel.isLoadingMembers {
                loadingView
            } else if viewModel.crewMembers.isEmpty {
                emptyStateCard(
                    icon: "person.2",
                    title: "No crew members yet",
                    subtitle: "Search for users and send them a crew request"
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
                    Text("Received Requests")
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
                        title: "No pending requests",
                        subtitle: "When someone wants to join your crew, it will appear here"
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
                    Text("Sent Requests")
                        .subtitle()
                        .fontWeight(.semibold)
                        .foregroundColor(ColorTokens.textPrimary)
                    Spacer()
                }

                if viewModel.sentRequests.isEmpty {
                    emptyStateCard(
                        icon: "paperplane",
                        title: "No sent requests",
                        subtitle: "Search for users to send crew requests"
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

                    TextField("Search users...", text: $viewModel.searchQuery)
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
                    Text("No users found")
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
                    Text("Close")
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

                            Text(user.email.isEmpty ? "Guest Account" : user.email)
                                .caption()
                                .foregroundColor(ColorTokens.textMuted)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                            Text("Level \(user.level)")
                                .bodyText()
                                .fontWeight(.medium)
                                .foregroundColor(ColorTokens.primaryStart)

                            Text("🔥 \(user.currentStreak) day streak")
                                .caption()
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }
                }
            }

            // Sign out button
            Button(action: {
                showingSignOutAlert = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(ColorTokens.error)

                    Text("Sign Out")
                        .bodyText()
                        .foregroundColor(ColorTokens.error)

                    Spacer()
                }
                .padding(SpacingTokens.md)
                .background(ColorTokens.surface)
                .cornerRadius(RadiusTokens.md)
            }

            // Version info
            Text("Volta v1.0.0")
                .caption()
                .foregroundColor(ColorTokens.textMuted)
                .padding(.top, SpacingTokens.sm)
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
                    Text("#\(entry.rank)")
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

                            if entry.isCrewMember {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(ColorTokens.success)
                            }
                        }

                        HStack(spacing: SpacingTokens.sm) {
                            Label("\(entry.totalSessions7d)", systemImage: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(ColorTokens.textMuted)

                            Label(entry.formattedFocusTime, systemImage: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }

                    Spacer()

                    // Action button
                    if !entry.isCrewMember {
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
        switch entry.rank {
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
                                Label("\(sessions) sessions", systemImage: "flame.fill")
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
        .alert("Remove from Crew?", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Are you sure you want to remove \(member.displayName) from your crew?")
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
                        Label("\(sessions) sessions this week", systemImage: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }

                Spacer()

                // Action button
                if result.isCrewMember {
                    Text("In Crew")
                        .caption()
                        .foregroundColor(ColorTokens.success)
                } else if result.hasPendingRequest {
                    Text(result.requestDirection == "outgoing" ? "Pending" : "Respond")
                        .caption()
                        .foregroundColor(ColorTokens.warning)
                } else {
                    Button {
                        onSendRequest()
                    } label: {
                        Text("Add")
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

                            // Intentions
                            if let intentions = day.intentions, !intentions.isEmpty {
                                intentionsSection(intentions)
                            }

                            // Focus sessions
                            if let sessions = day.focusSessions, !sessions.isEmpty {
                                focusSessionsSection(sessions)
                            }

                            // Completed routines
                            if let routines = day.completedRoutines, !routines.isEmpty {
                                routinesSection(routines)
                            }

                            // Empty state
                            if (day.intentions ?? []).isEmpty &&
                               (day.focusSessions ?? []).isEmpty &&
                               (day.completedRoutines ?? []).isEmpty {
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

                        Text("Day Not Visible")
                            .subtitle()
                            .fontWeight(.bold)
                            .foregroundColor(ColorTokens.textPrimary)

                        Text("This user has their day set to private")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle(viewModel.selectedMember?.displayName ?? "Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
            return "Today"
        } else if Calendar.current.isDateInYesterday(viewModel.selectedDate) {
            return "Yesterday"
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

                    Text("Crew Member")
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
                Text("Intentions")
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

    private func focusSessionsSection(_ sessions: [CrewFocusSession]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("🔥")
                    .font(.system(size: 18))
                Text("Focus Sessions")
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text("\(sessions.count) sessions")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }

            VStack(spacing: SpacingTokens.sm) {
                ForEach(sessions) { session in
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
            }
        }
    }

    private func routinesSection(_ routines: [CrewCompletedRoutine]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("✅")
                    .font(.system(size: 18))
                Text("Completed Routines")
                    .subtitle()
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                Text("\(routines.count) done")
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

    private var emptyDayState: some View {
        Card {
            VStack(spacing: SpacingTokens.md) {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 40))
                    .foregroundColor(ColorTokens.textMuted)

                Text("No activity this day")
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

// MARK: - Date Extension
extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)

        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Preview
#Preview {
    CrewView()
        .environmentObject(FocusAppStore.shared)
}
