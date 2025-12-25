import SwiftUI

/// A robust async image loader with automatic retry and tap-to-retry functionality
struct RetryableAsyncImage: View {
    let url: String
    let height: CGFloat
    let onTap: (() -> Void)?

    @State private var retryCount = 0
    @State private var loadFailed = false
    @State private var isRetrying = false

    private let maxRetries = 3
    private let retryDelay: UInt64 = 1_000_000_000 // 1 second

    init(url: String, height: CGFloat = 350, onTap: (() -> Void)? = nil) {
        self.url = url
        self.height = height
        self.onTap = onTap
    }

    var body: some View {
        Group {
            if loadFailed && !isRetrying {
                failedView
            } else {
                imageLoader
            }
        }
    }

    // MARK: - Image Loader
    private var imageLoader: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap?()
                    }
                    .onAppear {
                        // Reset state on success
                        loadFailed = false
                        retryCount = 0
                    }

            case .failure(let error):
                Rectangle()
                    .fill(ColorTokens.surface)
                    .frame(height: height)
                    .overlay(ProgressView())
                    .onAppear {
                        handleFailure(error)
                    }

            case .empty:
                Rectangle()
                    .fill(ColorTokens.surface)
                    .frame(height: height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.2)
                    )

            @unknown default:
                Rectangle()
                    .fill(ColorTokens.surface)
                    .frame(height: height)
            }
        }
    }

    // MARK: - Failed View with Retry
    private var failedView: some View {
        Rectangle()
            .fill(ColorTokens.surface)
            .frame(height: height)
            .overlay(
                VStack(spacing: SpacingTokens.sm) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(ColorTokens.textMuted)

                    Text("community.image_load_failed".localized)
                        .font(.caption)
                        .foregroundColor(ColorTokens.textMuted)

                    Button(action: manualRetry) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Réessayer")
                        }
                        .font(.inter(14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ColorTokens.primaryStart)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
            )
    }

    // MARK: - URL with cache busting for retries
    private var imageURL: URL? {
        guard var urlComponents = URLComponents(string: url) else {
            return URL(string: url)
        }

        // Add cache-busting parameter on retry
        if retryCount > 0 {
            let retryParam = URLQueryItem(name: "_retry", value: "\(retryCount)")
            urlComponents.queryItems = (urlComponents.queryItems ?? []) + [retryParam]
        }

        return urlComponents.url
    }

    // MARK: - Retry Logic
    private func handleFailure(_ error: Error) {
        print("⚠️ Image load failed (attempt \(retryCount + 1)/\(maxRetries)): \(url)")
        print("   Error: \(error.localizedDescription)")

        if retryCount < maxRetries - 1 {
            // Auto-retry with delay
            retryCount += 1
            isRetrying = true

            Task {
                try? await Task.sleep(nanoseconds: retryDelay)
                await MainActor.run {
                    isRetrying = false
                }
            }
        } else {
            // Max retries reached, show error state
            loadFailed = true
            isRetrying = false
            print("❌ Image load failed after \(maxRetries) attempts: \(url)")
        }
    }

    private func manualRetry() {
        HapticFeedback.light()
        retryCount = 0
        loadFailed = false
        isRetrying = true

        // Small delay to trigger re-render
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            await MainActor.run {
                isRetrying = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        RetryableAsyncImage(
            url: "https://picsum.photos/400/300",
            height: 200
        )

        RetryableAsyncImage(
            url: "https://invalid-url-that-will-fail.com/image.jpg",
            height: 200
        )
    }
    .padding()
}
