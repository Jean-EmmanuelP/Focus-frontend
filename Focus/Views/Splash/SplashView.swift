import SwiftUI

/// Abstract hypnotic splash screen - Replika-style organic shapes
struct SplashView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var individualRotations: [Double] = [0, 0, 0]
    @State private var isExiting = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()

            // Abstract organic shapes
            ZStack {
                // Shape 1 - Top left blob
                AbstractBlob(rotation: individualRotations[0])
                    .fill(Color.white)
                    .frame(width: 120, height: 160)
                    .offset(x: -50, y: -60)
                    .rotationEffect(.degrees(-15))

                // Shape 2 - Top right blob
                AbstractBlob(rotation: individualRotations[1])
                    .fill(Color.white)
                    .frame(width: 130, height: 150)
                    .offset(x: 50, y: -40)
                    .rotationEffect(.degrees(20))

                // Shape 3 - Bottom center blob
                AbstractBlob(rotation: individualRotations[2])
                    .fill(Color.white)
                    .frame(width: 110, height: 140)
                    .offset(x: -10, y: 90)
                    .rotationEffect(.degrees(0))
            }
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Phase 1: Fade in and start small
        withAnimation(.easeOut(duration: 0.5)) {
            opacity = 1.0
            scale = 0.4
        }

        // Phase 2: Continuous rotation and scale up
        withAnimation(.easeInOut(duration: 2.0)) {
            rotation = 45
            scale = 1.2
        }

        // Individual blob subtle movements
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 1.5 + Double(i) * 0.3)
                .repeatForever(autoreverses: true)
            ) {
                individualRotations[i] = Double.random(in: -10...10)
            }
        }

        // Phase 3: Final expansion - zoom towards viewer
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.6)) {
                scale = 8.0
                opacity = 0
                rotation = 90
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onComplete()
        }
    }
}

// MARK: - Abstract Blob Shape

struct AbstractBlob: Shape {
    var rotation: Double = 0

    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let centerY = rect.midY

        // Create organic egg/petal shape with subtle variation
        let wobble = sin(rotation * .pi / 180) * 5

        path.move(to: CGPoint(x: centerX, y: 0))

        // Top curve
        path.addQuadCurve(
            to: CGPoint(x: width, y: centerY + wobble),
            control: CGPoint(x: width + 10, y: height * 0.2)
        )

        // Bottom right curve
        path.addQuadCurve(
            to: CGPoint(x: centerX, y: height),
            control: CGPoint(x: width - 10, y: height + 5)
        )

        // Bottom left curve
        path.addQuadCurve(
            to: CGPoint(x: 0, y: centerY - wobble),
            control: CGPoint(x: 10, y: height + 5)
        )

        // Top left curve back to start
        path.addQuadCurve(
            to: CGPoint(x: centerX, y: 0),
            control: CGPoint(x: -10, y: height * 0.2)
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Alternative: Simple Ellipse Version

struct SplashViewSimple: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.25
    @State private var opacity: Double = 0

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ZStack {
                // Three organic ellipses forming the Replika-style logo
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 100, height: 140)
                    .offset(x: -45, y: -50)
                    .rotationEffect(.degrees(-25))

                Ellipse()
                    .fill(Color.white)
                    .frame(width: 110, height: 130)
                    .offset(x: 45, y: -30)
                    .rotationEffect(.degrees(25))

                Ellipse()
                    .fill(Color.white)
                    .frame(width: 90, height: 120)
                    .offset(x: -5, y: 80)
                    .rotationEffect(.degrees(-5))
            }
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
        }
        .onAppear {
            // Fade in
            withAnimation(.easeOut(duration: 0.4)) {
                opacity = 1.0
                scale = 0.35
            }

            // Rotate and grow
            withAnimation(.easeInOut(duration: 2.0)) {
                rotation = 60
                scale = 1.5
            }

            // Final zoom out
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeIn(duration: 0.5)) {
                    scale = 10.0
                    opacity = 0
                    rotation = 120
                }
            }

            // Complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                onComplete()
            }
        }
    }
}

#Preview {
    SplashView {
        print("Splash complete")
    }
}
