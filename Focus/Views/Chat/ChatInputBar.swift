import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isRecording: Bool
    let isLoading: Bool
    let onSend: () -> Void
    let onMicTap: () -> Void
    let onMicRelease: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            // Mic button
            micButton

            // Text field
            textField

            // Send button
            if !text.isEmpty {
                sendButton
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(
            Rectangle()
                .fill(ColorTokens.background)
                .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
        )
    }

    // MARK: - Mic Button

    private var micButton: some View {
        Button {
            // Toggle recording
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? ColorTokens.error : ColorTokens.surface)
                    .frame(width: 44, height: 44)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isRecording ? .white : ColorTokens.primaryStart)
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onEnded { _ in
                    onMicTap()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if isRecording {
                        onMicRelease()
                    }
                }
        )
        .disabled(isLoading)
    }

    // MARK: - Text Field

    private var textField: some View {
        HStack {
            TextField("Message...", text: $text, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.textPrimary)
                .focused($isTextFieldFocused)
                .lineLimit(1...5)
                .onSubmit {
                    if !text.isEmpty {
                        onSend()
                    }
                }

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            onSend()
            isTextFieldFocused = false
        } label: {
            ZStack {
                Circle()
                    .fill(ColorTokens.primaryStart)
                    .frame(width: 36, height: 36)

                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .disabled(isLoading)
    }
}

// MARK: - Recording Overlay

struct VoiceRecordingOverlay: View {
    let isRecording: Bool
    let onCancel: () -> Void

    @State private var pulseAnimation = false

    var body: some View {
        if isRecording {
            VStack(spacing: SpacingTokens.lg) {
                Spacer()

                // Recording indicator
                ZStack {
                    // Pulse effect
                    Circle()
                        .fill(ColorTokens.error.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)

                    Circle()
                        .fill(ColorTokens.error)
                        .frame(width: 80, height: 80)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                        pulseAnimation = true
                    }
                }

                Text("Enregistrement en cours...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Relâche pour envoyer")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTokens.textSecondary)

                Spacer()

                // Cancel button
                Button {
                    onCancel()
                } label: {
                    Text("Annuler")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ColorTokens.error)
                        .padding(.vertical, SpacingTokens.md)
                        .padding(.horizontal, SpacingTokens.xl)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(ColorTokens.surface)
                        )
                }
                .padding(.bottom, SpacingTokens.xxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ColorTokens.background.opacity(0.95)
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ColorTokens.background
            .ignoresSafeArea()

        VStack {
            Spacer()

            ChatInputBar(
                text: .constant(""),
                isRecording: false,
                isLoading: false,
                onSend: {},
                onMicTap: {},
                onMicRelease: {}
            )
        }
    }
}
