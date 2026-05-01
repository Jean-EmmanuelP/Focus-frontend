import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0
    @State private var breathe = false

    let onComplete: () -> Void

    private let bgColor = Color.black
    private let accentBlue = Color.white

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 24) {
                // Pulse orb (mini version)
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    accentBlue.opacity(0.3),
                                    accentBlue.opacity(0.1),
                                    accentBlue.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 15,
                                endRadius: breathe ? 50 : 40
                            )
                        )
                        .frame(width: breathe ? 100 : 80, height: breathe ? 100 : 80)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    accentBlue.opacity(0.6),
                                    accentBlue.opacity(0.2)
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 25
                            )
                        )
                        .frame(width: breathe ? 44 : 36, height: breathe ? 44 : 36)
                        .shadow(color: accentBlue.opacity(0.5), radius: breathe ? 20 : 12)

                    Image(systemName: "flame.fill")
                        .font(.system(size: breathe ? 16 : 14, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text("Focus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Ton coach IA de productivité")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathe = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
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
