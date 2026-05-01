import SwiftUI
import UIKit
import AVFoundation

// MARK: - Challenge Verification

struct ChallengeVerificationView: View {
    let challenge: Challenge
    var onVerified: (String?) -> Void
    var onDismiss: () -> Void

    @State private var gesture = VerificationGesture.random
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var breatheScale: CGFloat = 1.0

    private var userId: String {
        FocusAppStore.shared.user?.id ?? ""
    }

    var body: some View {
        ZStack {
            if !challenge.isInValidationWindow() {
                lockedState
            } else if let image = capturedImage {
                confirmationView(image)
            } else {
                // Type-specific instruction/camera screen
                switch challenge.type {
                case .wakeup:
                    wakeupInstructionView
                case .meditation:
                    meditationInstructionView
                default:
                    defaultInstructionView
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showCamera) {
            SelfieCamera { image in
                capturedImage = image
                showCamera = false
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Wakeup: Camera-first experience

    private var wakeupInstructionView: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#000000"),
                    Color(hex: "#0A0A0A"),
                    Color(hex: "#141414"),
                    Color(hex: "#1A1A1A"),
                    Color(hex: "#222222")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top: time + day
                VStack(spacing: 8) {
                    Text(currentTimeString)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Jour \(challenge.dayNumber) — \(challenge.type.verificationMessage)")
                        .font(.satoshi(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 70)

                Spacer()

                // Gesture instruction
                gestureCard

                Spacer()

                // Camera button — big, prominent
                Button { showCamera = true } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.white.opacity(0.4), radius: 20, y: 4)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                .padding(.bottom, 12)

                Text("Prends ton selfie du matin")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 8)

                Button("Annuler") { onDismiss() }
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Meditation: Zen breathing experience

    private var meditationInstructionView: some View {
        ZStack {
            // Deep night background
            Color(hex: "#000000").ignoresSafeArea()

            // Breathing circles
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.08 + Double(i) * 0.03), lineWidth: 1.5)
                        .frame(
                            width: CGFloat(100 + i * 60) * breatheScale,
                            height: CGFloat(100 + i * 60) * breatheScale
                        )
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120 * breatheScale, height: 120 * breatheScale)
            }
            .offset(y: -40)

            VStack(spacing: 0) {
                // Top
                VStack(spacing: 8) {
                    Text("Jour \(challenge.dayNumber)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Le calme est une force")
                        .font(.satoshi(16, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .padding(.top, 80)

                Spacer()

                // Gesture
                gestureCard

                Spacer()

                // Camera
                Button { showCamera = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                            .frame(width: 80, height: 80)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 12)

                Text("Prends ton selfie zen")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 8)

                Button("Annuler") { onDismiss() }
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breatheScale = 1.15
            }
        }
    }

    // MARK: - Default (Gym, Reading, Custom)

    private var defaultInstructionView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Type glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [challenge.type.primaryColor.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(y: -100)

            VStack(spacing: 0) {
                Spacer()

                // Type icon
                ZStack {
                    Circle()
                        .fill(challenge.type.primaryColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: challenge.type.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(challenge.type.gradient)
                }
                .padding(.bottom, 24)

                Text("Jour \(challenge.dayNumber)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text(challenge.type.verificationMessage)
                    .font(.satoshi(17, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 32)

                gestureCard

                Spacer()

                Button { showCamera = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                        Text("Prendre le selfie")
                            .font(.satoshi(17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(challenge.type.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: challenge.type.primaryColor.opacity(0.3), radius: 12, y: 4)
                }
                .padding(.horizontal, 24)

                Button("Annuler") { onDismiss() }
                    .font(.satoshi(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 16)
                    .padding(.bottom, 34)
            }
        }
    }

    // MARK: - Shared: Gesture Card

    private var gestureCard: some View {
        VStack(spacing: 8) {
            Text("Fais ce geste")
                .font(.satoshi(12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            HStack(spacing: 12) {
                Text(gesture.emoji)
                    .font(.system(size: 32))
                Text(gesture.instruction)
                    .font(.satoshi(16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Locked State

    private var lockedState: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(challenge.type.primaryColor.opacity(0.4))

                VStack(spacing: 10) {
                    Text("Pas encore l'heure")
                        .font(.satoshi(24, weight: .bold))
                        .foregroundColor(.white)
                    Text(challenge.validationWindowText)
                        .font(.satoshi(16, weight: .medium))
                        .foregroundColor(challenge.type.primaryColor)
                    Text(challenge.type.motivationalLine)
                        .font(.satoshi(14, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 4)
                }

                Spacer()

                Button("Fermer") { onDismiss() }
                    .font(.satoshi(16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Confirmation Screen

    private func confirmationView(_ image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Subtle type glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [challenge.type.primaryColor.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)

            VStack(spacing: 0) {
                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 260, height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(challenge.type.gradient, lineWidth: 3)
                    )
                    .shadow(color: challenge.type.primaryColor.opacity(0.2), radius: 20, y: 8)

                if let error = uploadError {
                    VStack(spacing: 6) {
                        Text("Erreur d'envoi")
                            .font(.satoshi(18, weight: .bold))
                            .foregroundColor(ColorTokens.error)
                        Text(error)
                            .font(.satoshi(13, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                } else {
                    Text(isUploading ? "Envoi en cours..." : "C'est bon ?")
                        .font(.satoshi(20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        uploadAndVerify(image)
                    } label: {
                        HStack(spacing: 8) {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                Text("Valider")
                                    .font(.satoshi(17, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(isUploading ? AnyShapeStyle(Color.white.opacity(0.15)) : AnyShapeStyle(ColorTokens.successGradient))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isUploading)

                    if uploadError != nil {
                        Button { onVerified(nil) } label: {
                            Text("Valider sans photo")
                                .font(.satoshi(14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    if !isUploading {
                        Button {
                            capturedImage = nil
                            uploadError = nil
                            showCamera = true
                        } label: {
                            Text("Reprendre")
                                .font(.satoshi(15, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
    }

    // MARK: - Upload & Verify

    private func uploadAndVerify(_ image: UIImage) {
        isUploading = true
        uploadError = nil

        Task {
            do {
                guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
                    await MainActor.run {
                        uploadError = "Impossible de compresser la photo"
                        isUploading = false
                    }
                    return
                }

                let photoURL = try await SupabaseStorageService.shared.uploadChallengePhoto(
                    imageData: jpegData,
                    userId: userId,
                    challengeId: challenge.id
                )

                await MainActor.run {
                    isUploading = false
                    // Notify chat that this challenge was just validated so Kai can
                    // post a "well done" message + update the inline card.
                    NotificationCenter.default.post(
                        name: Notification.Name("challengeValidated"),
                        object: nil,
                        userInfo: [
                            "challengeId": challenge.id,
                            "photoUrl": photoURL ?? ""
                        ]
                    )
                    onVerified(photoURL)
                }
            } catch {
                await MainActor.run {
                    uploadError = "Echec de l'envoi. Reessaye ou valide sans photo."
                    isUploading = false
                }
            }
        }
    }

    // MARK: - Helpers

    private var currentTimeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: Date())
    }
}

// MARK: - Selfie Camera (UIImagePickerController wrapper)

struct SelfieCamera: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
