import SwiftUI

struct FocusPulseUserCard: View {
    let user: NearbyUser
    let alreadySent: Bool
    let onSendEncouragement: (String, String) -> Void
    let onDismiss: () -> Void

    @State private var showEncouragementOptions = false
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 0) {
            // Snapchat-style header: big avatar + info overlay
            ZStack(alignment: .bottomLeading) {
                // Gradient background
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                user.isInFocusSession ? .orange.opacity(0.6) : ColorTokens.accent.opacity(0.4),
                                Color(red: 0.08, green: 0.08, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 160)

                // Big initial in center
                Text(user.initial)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.15))
                    .frame(maxWidth: .infinity, maxHeight: 160)

                // Info overlay at bottom
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anonyme")
                        .font(.satoshi(20, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        if user.isInFocusSession {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 6, height: 6)
                                Text("En focus \(user.focusMinutesElapsed) min")
                                    .font(.satoshi(12, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                        }

                        if user.totalMinutesToday > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10))
                                Text("\(user.totalMinutesToday) min")
                                    .font(.satoshi(12, weight: .semibold))
                            }
                            .foregroundColor(ColorTokens.accent)
                        }

                        if let streak = user.currentStreak, streak > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                Text("\(streak)j")
                                    .font(.satoshi(12, weight: .semibold))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer().frame(height: 20)

            // Action button
            if alreadySent || showCheckmark {
                alreadySentView
            } else {
                encourageButton
            }

            Spacer().frame(height: 20)
        }
        .confirmationDialog(
            "Envoyer un encouragement",
            isPresented: $showEncouragementOptions,
            titleVisibility: .visible
        ) {
            ForEach(encouragementPresets) { preset in
                Button("\(preset.emoji) \(preset.message)") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCheckmark = true
                    }
                    onSendEncouragement(preset.emoji, preset.message)
                }
            }
            Button("Annuler", role: .cancel) { }
        }
    }

    // MARK: - Encourage Button

    private var encourageButton: some View {
        Button {
            showEncouragementOptions = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 14))
                Text("Encourager")
                    .font(.satoshi(15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule()
                    .fill(.orange)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Already Sent

    private var alreadySentView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("Deja encourage")
                .font(.satoshi(15, weight: .bold))
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
