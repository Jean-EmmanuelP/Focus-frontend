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
            LongPressGesture(minimumDuration: 0.3)
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
