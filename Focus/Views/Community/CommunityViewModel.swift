import SwiftUI
import PhotosUI
import Combine

@MainActor
class CommunityViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var posts: [CommunityPostResponse] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var showError = false
    @Published var errorMessage = ""

    // Create post state
    @Published var selectedImage: UIImage?
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var caption: String = ""
    @Published var selectedTaskId: String?
    @Published var selectedRoutineId: String?
    @Published var isCreatingPost = false

    // Available tasks/routines for linking
    @Published var availableTasks: [CalendarTask] = []
    @Published var availableRoutines: [RoutineResponse] = []
    @Published var isLoadingOptions = false

    // Report state
    @Published var reportingPost: CommunityPostResponse?

    // MARK: - Private Properties
    private let communityService = CommunityService()
    private let calendarService = CalendarService()
    private let routineService = RoutineService()
    private var currentOffset = 0
    private let pageSize = 20
    private var currentUserId: String?

    // MARK: - Load Feed
    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            // Get current user ID
            if currentUserId == nil {
                let userService = UserService()
                let user = try await userService.fetchMe()
                currentUserId = user.id
            }

            let response = try await communityService.fetchFeed(limit: pageSize, offset: 0)
            posts = response.posts
            hasMore = response.hasMore
            currentOffset = posts.count
        } catch {
            // Don't show error for empty feed, not found, or cancelled requests
            let errorString = error.localizedDescription.lowercased()
            let isCancelled = (error as? URLError)?.code == .cancelled || errorString.contains("cancel") || errorString.contains("annul")
            let isNotFound = errorString.contains("not found") || errorString.contains("404")

            if !isCancelled && !isNotFound {
                showError(message: error.localizedDescription)
            }

            // Only reset posts if not cancelled (keep existing data on cancel)
            if !isCancelled {
                posts = []
                hasMore = false
            }
        }

        isLoading = false
    }

    func refresh() async {
        currentOffset = 0
        await loadFeed()
    }

    func loadMore() {
        guard !isLoading && hasMore else { return }

        Task {
            isLoading = true
            do {
                let response = try await communityService.fetchFeed(limit: pageSize, offset: currentOffset)
                posts.append(contentsOf: response.posts)
                hasMore = response.hasMore
                currentOffset = posts.count
            } catch {
                showError(message: error.localizedDescription)
            }
            isLoading = false
        }
    }

    // MARK: - Create Post
    func loadCreatePostOptions() async {
        isLoadingOptions = true
        do {
            // Load today's tasks and routines
            let dateString = DateFormatter.yyyyMMdd.string(from: Date())
            async let tasksResult = calendarService.getTasks(date: dateString)
            async let routinesResult = routineService.fetchRoutines()

            availableTasks = try await tasksResult
            availableRoutines = try await routinesResult
        } catch {
            print("Failed to load create post options: \(error)")
        }
        isLoadingOptions = false
    }

    func createPost() async -> Bool {
        guard let image = selectedImage else {
            showError(message: "community.error_no_image".localized)
            return false
        }

        // Task/routine link is now optional

        isCreatingPost = true

        do {
            // Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                showError(message: "community.error_image_processing".localized)
                isCreatingPost = false
                return false
            }

            let newPost = try await communityService.createPost(
                imageData: imageData,
                caption: caption.isEmpty ? nil : caption,
                taskId: selectedTaskId,
                routineId: selectedRoutineId,
                contentType: "image/jpeg"
            )

            // Add to the beginning of the feed
            posts.insert(newPost, at: 0)

            // Reset form
            resetCreatePostForm()
            isCreatingPost = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isCreatingPost = false
            return false
        }
    }

    func resetCreatePostForm() {
        selectedImage = nil
        selectedPhotoItem = nil
        caption = ""
        selectedTaskId = nil
        selectedRoutineId = nil
    }

    // MARK: - Like/Unlike
    func toggleLike(postId: String) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        let post = posts[index]
        let isCurrentlyLiked = post.isLikedByMe

        // Optimistic update
        let newLikesCount = isCurrentlyLiked ? post.likesCount - 1 : post.likesCount + 1

        // Create updated post with new values (matching backend structure)
        let updatedPost = CommunityPostResponse(
            id: post.id,
            userId: post.userId,
            taskId: post.taskId,
            routineId: post.routineId,
            imageUrl: post.imageUrl,
            caption: post.caption,
            likesCount: max(0, newLikesCount),
            createdAt: post.createdAt,
            user: post.user,
            taskTitle: post.taskTitle,
            routineTitle: post.routineTitle,
            isLikedByMe: !isCurrentlyLiked
        )
        posts[index] = updatedPost

        // API call
        Task {
            do {
                if isCurrentlyLiked {
                    try await communityService.unlikePost(id: postId)
                } else {
                    try await communityService.likePost(id: postId)
                }
            } catch {
                // Revert on failure
                posts[index] = post
                showError(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Delete Post
    func deletePost(postId: String) {
        Task {
            do {
                try await communityService.deletePost(id: postId)
                posts.removeAll { $0.id == postId }
            } catch {
                showError(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Report Post
    func showReportSheet(for post: CommunityPostResponse) {
        reportingPost = post
    }

    func reportPost(postId: String, reason: String, details: String?) {
        Task {
            do {
                try await communityService.reportPost(id: postId, reason: reason, details: details)
                reportingPost = nil
                // Show success feedback
            } catch {
                showError(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers
    func isOwnPost(_ post: CommunityPostResponse) -> Bool {
        return post.userId == currentUserId
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

