import SwiftUI

/// Animated splash screen with growing flame effect
struct SplashView: View {
    @State private var flameScale: CGFloat = 0.3
    @State private var flameOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var showPulse: Bool = false

    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 700
            let flameSize: CGFloat = isSmallScreen ? 60 : 80
            let glowSize: CGFloat = isSmallScreen ? 220 : 300
            let pulseSize: CGFloat = isSmallScreen ? 150 : 200

            ZStack {
                // Clean gradient background for light mode
                LinearGradient(
                    colors: [
                        ColorTokens.background,
                        ColorTokens.primaryLight,
                        ColorTokens.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Radial glow behind flame
                RadialGradient(
                    colors: [
                        ColorTokens.primaryStart.opacity(0.4),
                        ColorTokens.primaryEnd.opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: glowRadius
                )
                .frame(width: glowSize, height: glowSize)
                .blur(radius: 30)

                // Pulse effect
                if showPulse {
                    Circle()
                        .stroke(ColorTokens.primaryStart.opacity(0.3), lineWidth: 2)
                        .frame(width: pulseSize, height: pulseSize)
                        .scaleEffect(showPulse ? 2 : 1)
                        .opacity(showPulse ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 1.0),
                            value: showPulse
                        )
                }

                // Main flame
                VStack(spacing: SpacingTokens.lg) {
                    Text("🔥")
                        .font(.system(size: flameSize))
                        .scaleEffect(flameScale)
                        .opacity(flameOpacity)
                        .shadow(color: ColorTokens.primaryStart.opacity(0.8), radius: 20, x: 0, y: 0)
                        .shadow(color: ColorTokens.primaryEnd.opacity(0.5), radius: 40, x: 0, y: 10)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Phase 1: Fade in and grow
        withAnimation(.easeOut(duration: 0.6)) {
            flameOpacity = 1
            flameScale = 1.0
            glowRadius = 150
        }

        // Phase 2: Heartbeat pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.3)) {
                flameScale = 1.15
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.3)) {
                flameScale = 1.0
            }
        }

        // Phase 3: Second heartbeat
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.25)) {
                flameScale = 1.2
                glowRadius = 200
            }
            showPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeInOut(duration: 0.25)) {
                flameScale = 1.0
            }
        }

        // Phase 4: Final grow and fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.5)) {
                flameScale = 3.0
                flameOpacity = 0
                glowRadius = 400
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            onComplete()
        }
    }
}

#Preview {
    SplashView {
        print("Splash complete")
    }
}
