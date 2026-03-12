import SwiftUI
import LiveKit

struct ParticipantTile: View {
    let participant: ParticipantState
    var isLocalUser: Bool = false

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surface)

            if participant.isCameraOn, let videoTrack = participant.videoTrack {
                // Video mode
                SwiftUIVideoView(videoTrack)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // Avatar placeholder mode
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.primarySoft)
                            .frame(width: 56, height: 56)

                        Text(initials)
                            .font(.satoshi(20, weight: .bold))
                            .foregroundColor(ColorTokens.primaryStart)
                    }

                    Text(displayLabel)
                        .font(.satoshi(13, weight: .medium))
                        .foregroundColor(ColorTokens.textPrimary)
                        .lineLimit(1)
                }
            }

            // Speaking ring
            if participant.isSpeaking {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(ColorTokens.success, lineWidth: 2.5)
            }

            // Badges overlay
            VStack {
                HStack {
                    Spacer()

                    // Muted badge
                    if participant.isMuted {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                            .padding(8)
                    }
                }

                Spacer()

                HStack {
                    // "Toi" label for local user
                    if isLocalUser {
                        Text("Toi")
                            .font(.satoshi(10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(ColorTokens.primaryStart.opacity(0.8))
                            )
                            .padding(8)
                    }

                    Spacer()
                }
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
    }

    // MARK: - Helpers

    private var initials: String {
        let name = participant.displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var displayLabel: String {
        isLocalUser ? "Toi" : participant.displayName
    }
}
