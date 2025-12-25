import SwiftUI

struct CommunityPostCard: View {
    let post: CommunityPostResponse
    let onLike: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void
    let isOwnPost: Bool

    @State private var showDeleteConfirmation = false
    @State private var showOptionsMenu = false
    @State private var showFullScreenImage = false
    @State private var imageLoadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.sm)

            // Image
            imageView

            // Actions & Caption
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                actionsView
                    .padding(.horizontal, SpacingTokens.md)

                if let caption = post.caption, !caption.isEmpty {
                    captionView(caption)
                        .padding(.horizontal, SpacingTokens.md)
                }

                // Linked task/routine
                linkedItemView
                    .padding(.horizontal, SpacingTokens.md)

                // Timestamp
                Text(post.createdAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundColor(ColorTokens.textMuted)
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.bottom, SpacingTokens.md)
            }
            .padding(.top, SpacingTokens.sm)
        }
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
        .confirmationDialog(
            "community.delete_confirm".localized,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("community.delete".localized, role: .destructive) {
                onDelete()
            }
            Button("cancel".localized, role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            FullScreenImageView(imageUrl: post.imageUrl)
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: SpacingTokens.sm) {
            // Avatar
            AsyncImage(url: URL(string: post.authorAvatarUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(ColorTokens.textSecondary)
                @unknown default:
                    Color.gray
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(post.authorPseudo ?? "User")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTokens.textPrimary)
            }

            Spacer()

            // Options button
            Button {
                showOptionsMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .confirmationDialog(
                "community.options".localized,
                isPresented: $showOptionsMenu,
                titleVisibility: .hidden
            ) {
                if isOwnPost {
                    Button("community.delete".localized, role: .destructive) {
                        showDeleteConfirmation = true
                    }
                } else {
                    Button("community.report".localized, role: .destructive) {
                        onReport()
                    }
                }
                Button("cancel".localized, role: .cancel) {}
            }
        }
    }

    // MARK: - Image
    private var imageView: some View {
        RetryableAsyncImage(
            url: post.imageUrl,
            height: 350,
            onTap: { showFullScreenImage = true }
        )
    }

    // MARK: - Actions
    private var actionsView: some View {
        HStack(spacing: SpacingTokens.lg) {
            // Like button
            Button(action: onLike) {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: post.isLikedByMe ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(post.isLikedByMe ? .red : ColorTokens.textPrimary)

                    if post.likesCount > 0 {
                        Text("\(post.likesCount)")
                            .font(.subheadline)
                            .foregroundColor(ColorTokens.textPrimary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Caption
    private func captionView(_ caption: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Text(post.authorPseudo ?? "User")
                .fontWeight(.semibold)
            +
            Text(" ")
            +
            Text(caption)
        }
        .font(.subheadline)
        .foregroundColor(ColorTokens.textPrimary)
        .lineLimit(3)
    }

    // MARK: - Linked Item
    private var linkedItemView: some View {
        Group {
            if let taskTitle = post.taskTitle {
                linkedBadge(icon: "checkmark.circle", title: taskTitle, color: ColorTokens.primaryStart)
            } else if let routineTitle = post.routineTitle {
                linkedBadge(icon: "arrow.triangle.2.circlepath", title: routineTitle, color: ColorTokens.warning)
            }
        }
    }

    private func linkedBadge(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ColorTokens.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(color.opacity(0.1))
        .cornerRadius(RadiusTokens.full)
    }
}

// MARK: - Preview
#Preview {
    CommunityPostCard(
        post: CommunityPostResponse(
            id: "1",
            userId: "user1",
            taskId: "task1",
            routineId: nil,
            imageUrl: "https://picsum.photos/400/400",
            caption: "Just finished my morning workout! Feeling great and ready to tackle the day.",
            likesCount: 42,
            createdAt: Date().addingTimeInterval(-3600),
            user: PostUser(id: "user1", pseudo: "JohnDoe", avatarUrl: nil),
            taskTitle: "Morning Workout",
            routineTitle: nil,
            isLikedByMe: true
        ),
        onLike: {},
        onReport: {},
        onDelete: {},
        isOwnPost: false
    )
    .padding()
    .background(ColorTokens.background)
}
