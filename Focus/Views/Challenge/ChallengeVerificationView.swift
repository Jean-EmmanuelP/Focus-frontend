import SwiftUI
import AVFoundation

// MARK: - Challenge Verification (Live Camera + Gesture)

struct ChallengeVerificationView: View {
    let challenge: Challenge
    var onVerified: (String?) -> Void // photo URL
    var onDismiss: () -> Void

    @State private var gesture = VerificationGesture.random
    @State private var countdown = 3
    @State private var isCapturing = false
    @State private var isVerified = false
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    private var typeColor: Color {
        switch challenge.type {
        case .wakeup: return .orange
        case .gym: return .red
        case .meditation: return .purple
        case .reading: return .blue
        case .custom: return .green
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isVerified {
                verifiedView
            } else if showCamera {
                cameraView
            } else {
                instructionView
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Instruction

    private var instructionView: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: challenge.type.icon)
                .font(.system(size: 50))
                .foregroundColor(typeColor)

            Text("Validation du challenge")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text("L'IA va te demander de faire un geste pour prouver que c'est bien toi.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Text("Ton geste du jour :")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))

                HStack(spacing: 12) {
                    Text(gesture.emoji)
                        .font(.system(size: 40))
                    Text(gesture.instruction)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer()

            Button {
                showCamera = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Ouvrir la caméra")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(typeColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 30)

            Button("Annuler") { onDismiss() }
                .foregroundColor(.white.opacity(0.4))
                .padding(.bottom, 30)
        }
    }

    // MARK: - Camera View

    private var cameraView: some View {
        VStack(spacing: 0) {
            // Gesture reminder at top
            HStack(spacing: 8) {
                Text(gesture.emoji)
                    .font(.system(size: 20))
                Text(gesture.instruction)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(typeColor.opacity(0.3))
            .clipShape(Capsule())
            .padding(.top, 60)

            Spacer()

            // Camera preview placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 280, height: 370)

                if isCapturing {
                    // Countdown
                    Text("\(countdown)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Caméra frontale")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }

            Spacer()

            // Capture button
            if !isCapturing {
                Button {
                    startCapture()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(typeColor)
                            .frame(width: 60, height: 60)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Verified

    private var verifiedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Challenge validé !")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Jour \(challenge.dayNumber) complété")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onVerified(nil) // photo URL would come from camera capture
            }
        }
    }

    // MARK: - Capture Logic

    private func startCapture() {
        isCapturing = true
        countdown = 3

        // Countdown timer
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if countdown > 1 {
                countdown -= 1
            } else {
                timer.invalidate()
                // "Take photo" — in real implementation, capture from camera
                isVerified = true
            }
        }
    }
}
