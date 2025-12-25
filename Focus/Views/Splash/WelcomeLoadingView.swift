import SwiftUI

/// Welcome loading screen with text at top and animated flame
struct WelcomeLoadingView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    @State private var textOpacity: Double = 0
    @State private var flameOffset: CGFloat = -100
    @State private var flameOpacity: Double = 0
    @State private var flameRotation: Double = -30
    @State private var showLoader: Bool = false
    @State private var loadingProgress: CGFloat = 0

    private var welcomeText: String { "welcome.title".localized }
    private var subtitleText: String { "welcome.subtitle".localized }

    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700
            let flameSize: CGFloat = isSmallScreen ? 60 : 80
            let titleSize: CGFloat = isSmallScreen ? 20 : 24

            ZStack {
                // Dark background matching app theme
                ColorTokens.background
                    .ignoresSafeArea()

                VStack {
                    // Top text section
                    VStack(spacing: SpacingTokens.md) {
                        Text(welcomeText + ",")
                            .font(.inter(titleSize, weight: .medium))
                            .foregroundColor(ColorTokens.textPrimary)

                        Text(subtitleText + ".")
                            .font(.inter(titleSize, weight: .medium))
                            .foregroundColor(ColorTokens.primaryStart)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xl)
                    .padding(.top, geometry.safeAreaInsets.top + SpacingTokens.xxl)
                    .opacity(textOpacity)

                    Spacer()

                    // Animated flame going from bottom-left to right
                    ZStack {
                        // Flame trail/glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        ColorTokens.primaryStart.opacity(0.3),
                                        ColorTokens.primaryStart.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 100
                                )
                            )
                            .frame(width: isSmallScreen ? 150 : 200, height: isSmallScreen ? 150 : 200)
                            .blur(radius: 20)

                        // Main flame
                        Text("🔥")
                            .font(.system(size: flameSize))
                            .shadow(color: ColorTokens.primaryStart.opacity(0.8), radius: 20, x: 0, y: 0)
                            .rotationEffect(.degrees(flameRotation))
                    }
                    .offset(x: flameOffset, y: isSmallScreen ? 30 : 50)
                    .opacity(flameOpacity)

                    Spacer()

                    // Loading indicator at bottom
                    if showLoader {
                        VStack(spacing: SpacingTokens.sm) {
                            // Circular loader
                            Circle()
                                .stroke(ColorTokens.surface, lineWidth: 2)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .trim(from: 0, to: loadingProgress)
                                        .stroke(
                                            ColorTokens.primaryStart,
                                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                )
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + SpacingTokens.xl)
                    }
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Fade in text
        withAnimation(.easeOut(duration: 0.8)) {
            textOpacity = 1
        }

        // Animate flame from bottom-left to center-right
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 1.2)) {
                flameOpacity = 1
                flameOffset = 50
                flameRotation = 15
            }
        }

        // Show loader
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showLoader = true
            animateLoading()
        }
    }

    private func animateLoading() {
        withAnimation(.easeInOut(duration: 1.5)) {
            loadingProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            onComplete()
        }
    }
}

// MARK: - Stars Background
struct StarsBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.1...0.4)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
            }
        }
    }
}

#Preview {
    WelcomeLoadingView {
        print("Loading complete")
    }
}
