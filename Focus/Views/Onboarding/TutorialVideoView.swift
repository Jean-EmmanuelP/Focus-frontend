import SwiftUI
import WebKit

// MARK: - Tutorial Video View
struct TutorialVideoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var hasError = false

    private let videoId = "DmWWqogr_r8"

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Video player
                    ZStack {
                        if hasError {
                            // Fallback view when video fails to load
                            VStack(spacing: SpacingTokens.md) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(ColorTokens.textMuted)

                                Text("tutorial.video_error".localized)
                                    .font(.satoshi(14))
                                    .foregroundColor(ColorTokens.textSecondary)
                                    .multilineTextAlignment(.center)

                                Button(action: {
                                    if let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: SpacingTokens.xs) {
                                        Image(systemName: "arrow.up.right.square")
                                        Text("tutorial.open_youtube".localized)
                                    }
                                    .font(.satoshi(14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, SpacingTokens.lg)
                                    .padding(.vertical, SpacingTokens.sm)
                                    .background(Color.red)
                                    .cornerRadius(RadiusTokens.md)
                                }
                            }
                            .frame(height: UIScreen.main.bounds.height * 0.35)
                            .frame(maxWidth: .infinity)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.lg)
                        } else {
                            YouTubeVideoPlayer(
                                videoId: videoId,
                                isLoading: $isLoading,
                                hasError: $hasError
                            )
                            .frame(height: UIScreen.main.bounds.height * 0.35)
                            .cornerRadius(RadiusTokens.lg)
                        }

                        if isLoading && !hasError {
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                                    .scaleEffect(1.2)
                                Text("common.loading".localized)
                                    .caption()
                                    .foregroundColor(ColorTokens.textMuted)
                                    .padding(.top, SpacingTokens.sm)
                            }
                            .frame(height: UIScreen.main.bounds.height * 0.35)
                            .frame(maxWidth: .infinity)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.lg)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.top, SpacingTokens.md)

                    // Content below video
                    ScrollView {
                        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                            // Title
                            Text("tutorial.title".localized)
                                .font(.satoshi(24, weight: .bold))
                                .foregroundColor(ColorTokens.textPrimary)

                            // Description
                            Text("tutorial.description".localized)
                                .bodyText()
                                .foregroundColor(ColorTokens.textSecondary)

                            // Features list
                            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                                TutorialFeatureRow(
                                    icon: "calendar",
                                    title: "tutorial.feature_calendar".localized,
                                    description: "tutorial.feature_calendar_desc".localized
                                )

                                TutorialFeatureRow(
                                    icon: "flame.fill",
                                    title: "tutorial.feature_focus".localized,
                                    description: "tutorial.feature_focus_desc".localized
                                )

                                TutorialFeatureRow(
                                    icon: "checkmark.circle.fill",
                                    title: "tutorial.feature_rituals".localized,
                                    description: "tutorial.feature_rituals_desc".localized
                                )

                                TutorialFeatureRow(
                                    icon: "flag.fill",
                                    title: "tutorial.feature_quests".localized,
                                    description: "tutorial.feature_quests_desc".localized
                                )
                            }
                            .padding(.top, SpacingTokens.sm)
                        }
                        .padding(SpacingTokens.lg)
                    }
                }
            }
            .navigationTitle("settings.watch_tutorial".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
            }
        }
    }
}

// MARK: - Tutorial Feature Row
struct TutorialFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.md) {
            Image(systemName: icon)
                .font(.satoshi(18))
                .foregroundColor(ColorTokens.primaryStart)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text(title)
                    .font(.satoshi(15, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text(description)
                    .font(.satoshi(13))
                    .foregroundColor(ColorTokens.textSecondary)
            }
        }
    }
}

// MARK: - YouTube Video Player (WebView)
struct YouTubeVideoPlayer: UIViewRepresentable {
    let videoId: String
    @Binding var isLoading: Bool
    @Binding var hasError: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Set preferences for better compatibility
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // Load the video
        context.coordinator.loadVideo(webView: webView, videoId: videoId)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Don't reload on every update
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YouTubeVideoPlayer
        private var hasLoaded = false

        init(_ parent: YouTubeVideoPlayer) {
            self.parent = parent
        }

        func loadVideo(webView: WKWebView, videoId: String) {
            // Use youtube-nocookie.com domain to avoid cookie/referrer issues
            // Also use origin parameter for better compatibility
            let embedURL = "https://www.youtube-nocookie.com/embed/\(videoId)?playsinline=1&autoplay=1&rel=0&modestbranding=1&origin=https://focus-app.com"

            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <meta name="referrer" content="strict-origin-when-cross-origin">
                <style>
                    * { margin: 0; padding: 0; box-sizing: border-box; }
                    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                    .video-container {
                        position: relative;
                        width: 100%;
                        height: 100%;
                    }
                    iframe {
                        position: absolute;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100%;
                        border: none;
                    }
                </style>
            </head>
            <body>
                <div class="video-container">
                    <iframe
                        id="ytplayer"
                        src="\(embedURL)"
                        frameborder="0"
                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                        allowfullscreen>
                    </iframe>
                </div>
                <script>
                    // Detect iframe load errors
                    window.addEventListener('message', function(event) {
                        if (event.data && event.data.event === 'onError') {
                            window.webkit.messageHandlers.errorHandler.postMessage('error');
                        }
                    });
                </script>
            </body>
            </html>
            """

            // Use a valid base URL to provide proper referrer
            if let baseURL = URL(string: "https://focus-app.com") {
                webView.loadHTMLString(html, baseURL: baseURL)
            } else {
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasLoaded else { return }
            hasLoaded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
        }
    }
}

// MARK: - Onboarding Tutorial Modal (First Launch)
struct OnboardingTutorialModal: View {
    @Binding var isPresented: Bool
    @State private var isLoading = true
    @State private var hasError = false

    private let videoId = "DmWWqogr_r8"

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't dismiss on background tap
                }

            VStack(spacing: 0) {
                Spacer()

                // Modal content - full width
                VStack(spacing: SpacingTokens.md) {
                    // Header with close button
                    HStack {
                        Text("tutorial.welcome".localized)
                            .font(.satoshi(20, weight: .bold))
                            .foregroundColor(ColorTokens.textPrimary)

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                            markTutorialAsSeen()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.satoshi(24))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.top, SpacingTokens.lg)

                    // Video player
                    ZStack {
                        if hasError {
                            // Fallback view when video fails
                            VStack(spacing: SpacingTokens.sm) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(ColorTokens.textMuted)

                                Text("tutorial.video_error".localized)
                                    .font(.satoshi(13))
                                    .foregroundColor(ColorTokens.textSecondary)
                                    .multilineTextAlignment(.center)

                                Button(action: {
                                    if let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: SpacingTokens.xs) {
                                        Image(systemName: "arrow.up.right.square")
                                        Text("tutorial.open_youtube".localized)
                                    }
                                    .font(.satoshi(13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, SpacingTokens.md)
                                    .padding(.vertical, SpacingTokens.xs)
                                    .background(Color.red)
                                    .cornerRadius(RadiusTokens.sm)
                                }
                            }
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .background(ColorTokens.surface)
                            .cornerRadius(RadiusTokens.md)
                        } else {
                            YouTubeVideoPlayer(
                                videoId: videoId,
                                isLoading: $isLoading,
                                hasError: $hasError
                            )
                            .frame(height: 220)
                            .cornerRadius(RadiusTokens.md)
                        }

                        if isLoading && !hasError {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                        }
                    }
                    .padding(.horizontal, SpacingTokens.md)

                    // Description
                    Text("tutorial.onboarding_desc".localized)
                        .font(.satoshi(14))
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.lg)

                    // Buttons
                    VStack(spacing: SpacingTokens.sm) {
                        // Watch later button (dismiss)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                            markTutorialAsSeen()
                        }) {
                            Text("tutorial.watch_later".localized)
                                .font(.satoshi(16, weight: .semibold))
                                .foregroundColor(ColorTokens.primaryStart)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SpacingTokens.md)
                                .background(ColorTokens.primaryStart.opacity(0.1))
                                .cornerRadius(RadiusTokens.md)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.bottom, SpacingTokens.lg)
                }
                .background(ColorTokens.background)
                .cornerRadius(RadiusTokens.xl, corners: [.topLeft, .topRight])
            }
        }
        .transition(.opacity)
    }

    private func markTutorialAsSeen() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboardingTutorial")
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#Preview {
    TutorialVideoView()
}
