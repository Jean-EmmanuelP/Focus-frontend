import SwiftUI
import UIKit

// MARK: - Challenge Verification (Selfie Camera)

struct ChallengeVerificationView: View {
    let challenge: Challenge
    var onVerified: (String?) -> Void
    var onDismiss: () -> Void

    @State private var gesture = VerificationGesture.random
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isUploading = false

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

            if let image = capturedImage {
                confirmationView(image)
            } else {
                instructionView
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

    // MARK: - Instruction Screen

    private var instructionView: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: challenge.type.icon)
                .font(.system(size: 50))
                .foregroundColor(typeColor)

            Text("Jour \(challenge.dayNumber)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Prends un selfie pour valider")
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.6))

            // Gesture instruction (social proof — your friend will see this)
            VStack(spacing: 8) {
                Text("Fais ce geste sur ta photo :")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))

                HStack(spacing: 10) {
                    Text(gesture.emoji)
                        .font(.system(size: 36))
                    Text(gesture.instruction)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(16)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Spacer()

            // Camera button
            Button { showCamera = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                    Text("Prendre le selfie")
                        .font(.system(size: 17, weight: .bold))
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

    // MARK: - Confirmation Screen (after photo taken)

    private func confirmationView(_ image: UIImage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // Photo preview
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 250, height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(typeColor, lineWidth: 2)
                )

            Text("C'est bon ?")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Confirm
            Button {
                isUploading = true
                // TODO: Upload to Supabase Storage, get URL, pass to onVerified
                // For now, validate without photo URL
                onVerified(nil)
            } label: {
                HStack {
                    if isUploading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Valider")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 30)

            // Retake
            Button {
                capturedImage = nil
                showCamera = true
            } label: {
                Text("Reprendre")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 30)
        }
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
