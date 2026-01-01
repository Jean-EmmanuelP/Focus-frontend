import SwiftUI

/// Minimal splash screen with focus text effect
struct SplashView: View {
    @State private var textOpacities: [Double] = Array(repeating: 0.15, count: 9)
    @State private var centerLineOpacity: Double = 0.15
    @State private var animationComplete = false

    let onComplete: () -> Void

    private let focusText = "FOCUS ON THE MISSION"
    private let lineCount = 9
    private let centerIndex = 4

    var body: some View {
        ZStack {
            // Pure black background
            Color(hex: "#050508")
                .ignoresSafeArea()

            // Stacked text effect
            VStack(spacing: 4) {
                ForEach(0..<lineCount, id: \.self) { index in
                    Text(focusText)
                        .font(.system(size: 16, weight: index == centerIndex ? .bold : .medium, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(.white)
                        .opacity(textOpacities[index])
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Phase 1: Show all lines faintly
        withAnimation(.easeIn(duration: 0.3)) {
            for i in 0..<lineCount {
                textOpacities[i] = 0.15
            }
        }

        // Phase 2: Wave animation from top to center
        for i in 0...centerIndex {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.08) {
                withAnimation(.easeOut(duration: 0.15)) {
                    textOpacities[i] = 0.4
                }
                // Fade back
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if i != centerIndex {
                        withAnimation(.easeIn(duration: 0.2)) {
                            textOpacities[i] = 0.15
                        }
                    }
                }
            }
        }

        // Phase 3: Wave animation from bottom to center
        for i in (centerIndex..<lineCount).reversed() {
            let delay = Double(lineCount - 1 - i) * 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + delay) {
                withAnimation(.easeOut(duration: 0.15)) {
                    textOpacities[i] = 0.4
                }
                // Fade back
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if i != centerIndex {
                        withAnimation(.easeIn(duration: 0.2)) {
                            textOpacities[i] = 0.15
                        }
                    }
                }
            }
        }

        // Phase 4: Center line brightens and stays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                textOpacities[centerIndex] = 1.0
            }
        }

        // Phase 5: Hold, then fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.4)) {
                for i in 0..<lineCount {
                    textOpacities[i] = 0
                }
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
