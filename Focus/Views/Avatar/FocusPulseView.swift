import SwiftUI

/// A gentle pulsing orb that represents the Focus coach.
/// Replaces the 3D avatar (.glb) with a calm, ambient animation.
struct FocusPulseView: View {
    @State private var pulse1 = false
    @State private var pulse2 = false
    @State private var pulse3 = false
    @State private var breathe = false

    private let bgColor = Color(red: 0.10, green: 0.12, blue: 0.20)
    private let accentBlue = Color(red: 0.20, green: 0.45, blue: 1.0)

    var body: some View {
        ZStack {
            bgColor

            // Outer pulse ring 3 (slowest, largest)
            Circle()
                .fill(accentBlue.opacity(0.04))
                .frame(width: pulse3 ? 320 : 240, height: pulse3 ? 320 : 240)
                .blur(radius: 30)
                .opacity(pulse3 ? 0.0 : 0.6)

            // Outer pulse ring 2
            Circle()
                .fill(accentBlue.opacity(0.06))
                .frame(width: pulse2 ? 260 : 180, height: pulse2 ? 260 : 180)
                .blur(radius: 20)
                .opacity(pulse2 ? 0.0 : 0.7)

            // Outer pulse ring 1
            Circle()
                .fill(accentBlue.opacity(0.08))
                .frame(width: pulse1 ? 200 : 140, height: pulse1 ? 200 : 140)
                .blur(radius: 12)
                .opacity(pulse1 ? 0.0 : 0.8)

            // Core orb (breathing)
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentBlue.opacity(0.35),
                                accentBlue.opacity(0.15),
                                accentBlue.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: breathe ? 70 : 55
                        )
                    )
                    .frame(width: breathe ? 140 : 110, height: breathe ? 140 : 110)

                // Inner bright core
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
                            endRadius: 35
                        )
                    )
                    .frame(width: breathe ? 60 : 48, height: breathe ? 60 : 48)
                    .shadow(color: accentBlue.opacity(0.5), radius: breathe ? 30 : 20)

                // Flame icon
                Image(systemName: "flame.fill")
                    .font(.system(size: breathe ? 22 : 18, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .onAppear {
            // Breathing animation (core)
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathe = true
            }

            // Pulse ring 1 (fastest)
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
                pulse1 = true
            }

            // Pulse ring 2 (medium)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 3.0).repeatForever(autoreverses: false)) {
                    pulse2 = true
                }
            }

            // Pulse ring 3 (slowest)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 3.5).repeatForever(autoreverses: false)) {
                    pulse3 = true
                }
            }
        }
    }
}

#Preview {
    FocusPulseView()
}
