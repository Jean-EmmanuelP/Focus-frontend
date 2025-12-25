import SwiftUI

struct FullScreenImageView: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var retryCount = 0
    @State private var loadFailed = false
    @State private var isRetrying = false

    private let maxRetries = 3

    private var currentURL: URL? {
        guard var components = URLComponents(string: imageUrl) else {
            return URL(string: imageUrl)
        }
        if retryCount > 0 {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "_r", value: "\(retryCount)")]
        }
        return components.url
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if loadFailed && !isRetrying {
                // Error state with retry button
                VStack(spacing: SpacingTokens.md) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("community.image_load_failed".localized)
                        .foregroundColor(.gray)

                    Button(action: retry) {
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
                }
            } else {
                AsyncImage(url: currentURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 1), 4)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale < 1 {
                                            withAnimation {
                                                scale = 1
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                        if scale <= 1 {
                                            withAnimation {
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if scale > 1 {
                                        scale = 1
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2
                                    }
                                }
                            }
                            .onAppear {
                                loadFailed = false
                                retryCount = 0
                            }

                    case .failure:
                        ProgressView()
                            .tint(.white)
                            .onAppear {
                                handleFailure()
                            }

                    case .empty:
                        ProgressView()
                            .tint(.white)

                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .padding()
            }
        }
        .overlay(alignment: .bottom) {
            Text("community.double_tap_zoom".localized)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 40)
                .opacity(scale == 1 ? 1 : 0)
        }
        .statusBarHidden()
    }

    // MARK: - Retry Logic
    private func handleFailure() {
        print("⚠️ FullScreen image load failed (attempt \(retryCount + 1)/\(maxRetries)): \(imageUrl)")

        if retryCount < maxRetries - 1 {
            retryCount += 1
            isRetrying = true

            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                await MainActor.run {
                    isRetrying = false
                }
            }
        } else {
            loadFailed = true
            isRetrying = false
            print("❌ FullScreen image load failed after \(maxRetries) attempts")
        }
    }

    private func retry() {
        HapticFeedback.light()
        retryCount = 0
        loadFailed = false
        isRetrying = true

        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            await MainActor.run {
                isRetrying = false
            }
        }
    }
}

#Preview {
    FullScreenImageView(imageUrl: "https://picsum.photos/800/600")
}
