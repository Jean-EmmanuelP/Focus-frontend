import SwiftUI
import PhotosUI

// MARK: - Community View
struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var showCreatePost = false

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: SpacingTokens.md) {
                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        loadingView
                    } else if viewModel.posts.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.posts) { post in
                            CommunityPostCard(
                                post: post,
                                onLike: { viewModel.toggleLike(postId: post.id) },
                                onReport: { viewModel.showReportSheet(for: post) },
                                onDelete: { viewModel.deletePost(postId: post.id) },
                                isOwnPost: viewModel.isOwnPost(post)
                            )
                        }

                        // Load more indicator
                        if viewModel.hasMore {
                            ProgressView()
                                .padding()
                                .onAppear {
                                    viewModel.loadMore()
                                }
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.top, SpacingTokens.sm)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .navigationTitle("community.feed".localized)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreatePost = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.reportingPost) { post in
            ReportPostSheet(
                post: post,
                onSubmit: { reason, details in
                    viewModel.reportPost(postId: post.id, reason: reason, details: details)
                }
            )
        }
        .alert("community.error".localized, isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            await viewModel.loadFeed()
        }
    }

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.lg) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .fill(ColorTokens.surface)
                    .frame(height: 300)
                    .shimmer()
            }
        }
        .padding(.top, SpacingTokens.xl)
    }

    private var emptyStateView: some View {
        VStack(spacing: SpacingTokens.lg) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(ColorTokens.textSecondary)

            Text("community.empty_title".localized)
                .font(.headline)
                .foregroundColor(ColorTokens.textPrimary)

            Text("community.empty_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: { showCreatePost = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("community.create_first_post".localized)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, SpacingTokens.xl)
                .padding(.vertical, SpacingTokens.md)
                .background(
                    LinearGradient(
                        colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(RadiusTokens.full)
            }
            .padding(.top, SpacingTokens.md)
        }
        .padding(.horizontal, SpacingTokens.xl)
        .padding(.top, 100)
    }
}

// MARK: - Shimmer Effect
extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .animation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: phase
                )
            )
            .clipped()
            .onAppear {
                phase = 400
            }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CommunityView()
    }
}
