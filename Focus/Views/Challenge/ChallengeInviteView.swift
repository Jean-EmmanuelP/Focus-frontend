import SwiftUI

// MARK: - Challenge Invite Picker (In-App)

struct ChallengeInviteView: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var suggestions: [Friend] = []
    @State private var isLoading = true
    @State private var inviteSent = false
    @State private var invitedUser: Friend?

    private let socialService = SocialService()

    var body: some View {
        NavigationView {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundColor(ColorTokens.textMuted)
                        TextField("Chercher un ami...", text: $searchText)
                            .font(.satoshi(15, weight: .regular))
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    if inviteSent, let user = invitedUser {
                        // Success state
                        inviteSuccessView(user)
                    } else if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                        Text("Recherche d'utilisateurs...")
                            .font(.satoshi(14, weight: .medium))
                            .foregroundColor(ColorTokens.textMuted)
                            .padding(.top, 12)
                        Spacer()
                    } else if filteredUsers.isEmpty {
                        emptySearchState
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 2) {
                                ForEach(filteredUsers) { friend in
                                    userRow(friend)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Share link fallback
                    if !inviteSent {
                        shareLinkButton
                            .padding(16)
                    }
                }
            }
            .navigationTitle("Inviter un ami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ColorTokens.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(ColorTokens.surface)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadSuggestions() }
        .onChange(of: searchText) { _, query in
            if !query.isEmpty {
                searchUsers(query)
            }
        }
    }

    private var filteredUsers: [Friend] {
        if searchText.isEmpty {
            return suggestions
        }
        return suggestions.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - User Row

    private func userRow(_ friend: Friend) -> some View {
        Button {
            inviteUser(friend)
        } label: {
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(ColorTokens.surfaceElevated)
                        .frame(width: 44, height: 44)
                    if let url = friend.avatarUrl, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                initialCircle(friend)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        initialCircle(friend)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.satoshi(15, weight: .medium))
                        .foregroundColor(.white)
                    if let streak = friend.currentStreak, streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(streak)j de streak")
                                .font(.satoshi(12, weight: .regular))
                        }
                        .foregroundColor(ColorTokens.warning.opacity(0.7))
                    }
                }

                Spacer()

                Text("Inviter")
                    .font(.satoshi(13, weight: .bold))
                    .foregroundColor(ColorTokens.primaryStart)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(ColorTokens.primarySoft)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private func initialCircle(_ friend: Friend) -> some View {
        ZStack {
            Circle()
                .fill(ColorTokens.primarySoft)
                .frame(width: 44, height: 44)
            Text(String(friend.displayName.prefix(1)).uppercased())
                .font(.satoshi(16, weight: .bold))
                .foregroundColor(ColorTokens.primaryStart)
        }
    }

    // MARK: - Empty Search

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 36))
                .foregroundColor(ColorTokens.textMuted)
            Text("Aucun utilisateur trouve")
                .font(.satoshi(16, weight: .medium))
                .foregroundColor(ColorTokens.textSecondary)
            Text("Partage ton lien d'invitation ci-dessous")
                .font(.satoshi(13, weight: .regular))
                .foregroundColor(ColorTokens.textMuted)
            Spacer()
        }
    }

    // MARK: - Invite Success

    private func inviteSuccessView(_ user: Friend) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(ColorTokens.success)
            }

            Text("Invitation envoyee !")
                .font(.satoshi(22, weight: .bold))
                .foregroundColor(.white)

            Text("\(user.displayName) va recevoir ton invitation au challenge")
                .font(.satoshi(15, weight: .regular))
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Fermer")
                    .font(.satoshi(16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ColorTokens.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Share Link Fallback

    private var shareLinkButton: some View {
        Button {
            shareLink()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                Text("Partager le lien d'invitation")
                    .font(.satoshi(14, weight: .medium))
            }
            .foregroundColor(ColorTokens.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTokens.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private func loadSuggestions() {
        Task {
            do {
                suggestions = try await socialService.fetchSuggestedUsers()
            } catch {
                print("Failed to load suggestions: \(error)")
            }
            isLoading = false
        }
    }

    private func searchUsers(_ query: String) {
        Task {
            do {
                let results = try await socialService.searchUsers(query: query)
                suggestions = results
            } catch {
                print("Search error: \(error)")
            }
        }
    }

    private func inviteUser(_ friend: Friend) {
        // Share the invite link to this specific user
        // For now, open share sheet pre-targeted. When backend friend system is ready,
        // this can become a direct in-app notification.
        if let code = challenge.inviteCode, !code.isEmpty {
            let text = "Hey \(friend.displayName) ! Je te challenge sur Focali : focus://challenge/\(code)"
            let ac = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let vc = scene.windows.first?.rootViewController {
                vc.present(ac, animated: true)
            }
            invitedUser = friend
            inviteSent = true
        } else {
            shareLink()
        }
    }

    private func shareLink() {
        let code = challenge.inviteCode ?? ""
        let text: String
        if !code.isEmpty {
            text = "Je te challenge sur Focali ! Rejoins-moi : focus://challenge/\(code)"
        } else {
            text = "Je te challenge sur Focali ! Telecharge l'app et prouve que tu tiens."
        }
        let items: [Any] = [text]
        if let url = URL(string: "https://apps.apple.com/app/focali/id6742245252") {
            let allItems: [Any] = items + [url]
            let ac = UIActivityViewController(activityItems: allItems, applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let vc = scene.windows.first?.rootViewController {
                vc.present(ac, animated: true)
            }
        }
    }
}
