import SwiftUI

struct FriendsView: View {
    var onDismiss: (() -> Void)? = nil

    @StateObject private var viewModel = FriendsViewModel()
    @EnvironmentObject var store: FocusAppStore
    @FocusState private var isSearchFocused: Bool
    @State private var appeared = false
    @State private var copiedPseudo = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#050508"), Color(hex: "#080810"), Color(hex: "#050508")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(.white).scaleEffect(1.2)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // My profile card (pseudo)
                            if viewModel.searchQuery.isEmpty {
                                myProfileCard
                                    .padding(.horizontal, 16)
                            }

                            // Search results
                            if !viewModel.searchQuery.isEmpty {
                                searchResultsSection
                            }

                            // Pending requests
                            if viewModel.hasPendingRequests && viewModel.searchQuery.isEmpty {
                                pendingRequestsSection
                            }

                            // Invite card
                            if viewModel.searchQuery.isEmpty {
                                inviteCard
                                    .padding(.horizontal, 16)
                            }

                            // Suggestions (nearby users)
                            if viewModel.searchQuery.isEmpty && viewModel.hasSuggestions {
                                suggestionsSection
                            }

                            // Friends list
                            if viewModel.searchQuery.isEmpty {
                                if viewModel.friends.isEmpty && !viewModel.hasSuggestions {
                                    emptyState
                                        .padding(.top, 40)
                                } else if !viewModel.friends.isEmpty {
                                    friendsListSection
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task {
            await viewModel.loadData()
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
        .onChange(of: viewModel.searchQuery) { _, _ in
            viewModel.search()
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

            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.accent)
                Text("Amis")
                    .font(.satoshi(18, weight: .bold))
                    .foregroundColor(.white)
                if !viewModel.friends.isEmpty {
                    Text("\(viewModel.friends.count)")
                        .font(.satoshi(11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ColorTokens.accent))
                }
            }

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSearchFocused ? ColorTokens.accent : ColorTokens.textSecondary)

            TextField("", text: $viewModel.searchQuery, prompt: Text("Rechercher par pseudo ou nom...")
                .foregroundColor(ColorTokens.textSecondary.opacity(0.6)))
                .font(.satoshi(14, weight: .medium))
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.textSecondary)
                }
                .transition(.scale.combined(with: .opacity))
            }

            if viewModel.isSearching {
                ProgressView().tint(ColorTokens.accent).scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSearchFocused ? ColorTokens.accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
        .animation(.easeOut(duration: 0.2), value: isSearchFocused)
    }

    // MARK: - My Profile Card

    private var myProfileCard: some View {
        HStack(spacing: 14) {
            // Avatar
            avatarView(
                url: store.user?.avatarURL,
                initial: String((store.user?.name ?? "U").prefix(1)).uppercased(),
                size: 46,
                accentColor: ColorTokens.accent
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(store.user?.name ?? "Utilisateur")
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(.white)

                if let pseudo = store.user?.pseudo, !pseudo.isEmpty {
                    Text("@\(pseudo)")
                        .font(.satoshi(12, weight: .medium))
                        .foregroundColor(ColorTokens.accent)
                } else {
                    Text("Aucun pseudo défini")
                        .font(.satoshi(12, weight: .medium))
                        .foregroundColor(ColorTokens.textSecondary.opacity(0.5))
                }
            }

            Spacer()

            // Copy pseudo button
            if let pseudo = store.user?.pseudo, !pseudo.isEmpty {
                Button {
                    UIPasteboard.general.string = "@\(pseudo)"
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        copiedPseudo = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedPseudo = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedPseudo ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .bold))
                        Text(copiedPseudo ? "Copié" : "Copier")
                            .font(.satoshi(11, weight: .bold))
                    }
                    .foregroundColor(copiedPseudo ? ColorTokens.success : ColorTokens.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(copiedPseudo ? ColorTokens.success.opacity(0.1) : ColorTokens.accent.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(copiedPseudo ? ColorTokens.success.opacity(0.2) : ColorTokens.accent.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Invite Card

    private var inviteCard: some View {
        ShareLink(
            item: URL(string: "https://apps.apple.com/app/id6743387301")!,
            subject: Text("Focus"),
            message: Text("Rejoins-moi sur Focus et restons productifs ensemble !")
        ) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.accent, ColorTokens.accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "link")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Invite tes amis")
                        .font(.satoshi(15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Partage ton lien et défie-les au classement")
                        .font(.satoshi(12, weight: .medium))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(ColorTokens.accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(ColorTokens.accent.opacity(0.12)))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.accent.opacity(0.08), ColorTokens.accent.opacity(0.02)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ColorTokens.accent.opacity(0.15), lineWidth: 0.5)
                    )
            )
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Résultats", count: viewModel.searchResults.count)

            if viewModel.searchResults.isEmpty && !viewModel.isSearching {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(ColorTokens.textSecondary.opacity(0.4))
                        Text("Aucun utilisateur trouvé")
                            .font(.satoshi(13, weight: .medium))
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.searchResults) { user in
                        searchResultRow(user: user)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func searchResultRow(user: Friend) -> some View {
        HStack(spacing: 12) {
            avatarView(url: user.avatarUrl, initial: user.initial, size: 40, accentColor: ColorTokens.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(.white)
                if let streak = user.currentStreak, streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        Text("\(streak)j de streak")
                            .font(.satoshi(11, weight: .medium))
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }
            }

            Spacer()

            Button {
                Task { await viewModel.sendRequest(to: user.userId) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Ajouter")
                        .font(.satoshi(12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [ColorTokens.accent, ColorTokens.accent.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                    )
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                sectionHeader(title: "Suggestions", count: nil)
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(ColorTokens.accent.opacity(0.5))
            }
            .padding(.horizontal, 16)

            Text("Utilisateurs Focus près de toi")
                .font(.satoshi(12, weight: .medium))
                .foregroundColor(ColorTokens.textSecondary.opacity(0.6))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.suggestedUsers) { user in
                        suggestionCard(user: user)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func suggestionCard(user: Friend) -> some View {
        let alreadySent = viewModel.hasAlreadySentRequest(to: user.userId)

        return VStack(spacing: 10) {
            // Avatar
            avatarView(url: user.avatarUrl, initial: user.initial, size: 52, accentColor: ColorTokens.accent)

            // Name
            Text(user.displayName)
                .font(.satoshi(13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            // Stats
            HStack(spacing: 6) {
                if let streak = user.currentStreak, streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        Text("\(streak)j")
                            .font(.satoshi(10, weight: .medium))
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }
                if let score = user.productivityScore {
                    Text("\(Int(score))pts")
                        .font(.satoshi(10, weight: .medium))
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }

            // Add button
            Button {
                Task { await viewModel.sendRequest(to: user.userId) }
            } label: {
                if alreadySent {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Envoyé")
                            .font(.satoshi(11, weight: .bold))
                    }
                    .foregroundColor(ColorTokens.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(
                        Capsule()
                            .stroke(ColorTokens.accent.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Ajouter")
                            .font(.satoshi(11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [ColorTokens.accent, ColorTokens.accent.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                }
            }
            .disabled(alreadySent)
        }
        .frame(width: 110)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Pending Requests

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                sectionHeader(title: "Demandes en attente", count: nil)
                Text("\(viewModel.pendingRequests.count)")
                    .font(.satoshi(10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        )
                    )
            }
            .padding(.horizontal, 16)

            VStack(spacing: 6) {
                ForEach(viewModel.pendingRequests) { request in
                    requestRow(request: request)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func requestRow(request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            // Avatar with orange ring
            avatarView(url: request.fromAvatarUrl, initial: request.initial, size: 42, accentColor: .orange)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.orange, .orange.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.5
                        )
                        .frame(width: 44, height: 44)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(.white)
                Text("Veut devenir ton ami")
                    .font(.satoshi(11, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()

            // Accept
            Button {
                Task { await viewModel.acceptRequest(request.id) }
            } label: {
                Text("Accepter")
                    .font(.satoshi(12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [ColorTokens.success, ColorTokens.success.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        )
                    )
            }

            // Decline
            Button {
                Task { await viewModel.declineRequest(request.id) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Friends List

    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Mes amis", count: viewModel.friends.count)
                .padding(.horizontal, 16)

            VStack(spacing: 6) {
                ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { index, friend in
                    friendRow(friend: friend)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.05), value: appeared)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func friendRow(friend: Friend) -> some View {
        HStack(spacing: 12) {
            // Avatar
            avatarView(url: friend.avatarUrl, initial: friend.initial, size: 44, accentColor: ColorTokens.accent)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 10) {
                    if let streak = friend.currentStreak, streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text("\(streak)j")
                                .font(.satoshi(11, weight: .medium))
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }

                    if let score = friend.productivityScore {
                        HStack(spacing: 3) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 9))
                                .foregroundColor(ColorTokens.accent.opacity(0.6))
                            Text(String(format: "%.0f pts", score))
                                .font(.satoshi(11, weight: .medium))
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            // Remove
            Menu {
                Button(role: .destructive) {
                    Task { await viewModel.removeFriend(friend.id) }
                } label: {
                    Label("Retirer", systemImage: "person.badge.minus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.04)))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.satoshi(11, weight: .bold))
                .foregroundColor(ColorTokens.textSecondary.opacity(0.6))
                .tracking(1.2)
            if let count = count, count > 0 {
                Text("·")
                    .foregroundColor(ColorTokens.textSecondary.opacity(0.3))
                Text("\(count)")
                    .font(.satoshi(11, weight: .bold))
                    .foregroundColor(ColorTokens.textSecondary.opacity(0.4))
            }
        }
    }

    private func avatarView(url: String?, initial: String, size: CGFloat, accentColor: Color) -> some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        ZStack {
                            Circle().fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            Text(initial)
                                .font(.satoshi(size * 0.38, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            } else {
                ZStack {
                    Circle().fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    Text(initial)
                        .font(.satoshi(size * 0.38, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(ColorTokens.accent.opacity(0.04))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(ColorTokens.accent.opacity(0.06))
                    .frame(width: 70, height: 70)
                Image(systemName: "person.2")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [ColorTokens.accent, ColorTokens.accent.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 8) {
                Text("Pas encore d'amis")
                    .font(.satoshi(18, weight: .bold))
                    .foregroundColor(.white)
                Text("Recherche des utilisateurs ou\npartage ton lien d'invitation")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
