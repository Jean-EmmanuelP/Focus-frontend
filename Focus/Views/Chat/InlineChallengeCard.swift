import SwiftUI

/// Daily challenge card rendered inline in the chat conversation.
/// Three visual states: open (CTA validate), done (proof + score), closed (countdown).
struct InlineChallengeCard: View {
    let data: ChatCardData.ChallengeCardData
    let onValidate: () -> Void
    let onOpenHub: () -> Void

    private var type: ChallengeType {
        ChallengeType(rawValue: data.challengeType) ?? .custom
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let mantra = data.mantra, !mantra.isEmpty {
                Text("« \(mantra) »")
                    .font(.satoshi(13, weight: .medium).italic())
                    .foregroundColor(type.primaryColor.opacity(0.85))
            }
            switch data.state {
            case .open, .urgent:
                openCTA
            case .done:
                doneState
            case .closed:
                closedState
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(type.primaryColor.opacity(0.3), lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            // Soft tint glow on top corner for ambient color
            RoundedRectangle(cornerRadius: 22)
                .fill(type.softColor)
                .frame(height: 80)
                .blur(radius: 30)
                .allowsHitTesting(false)
                .opacity(0.6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .frame(maxWidth: 320, alignment: .leading)
    }

    // MARK: - Header (icon + title + day badge)

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(type.softColor)
                    .frame(width: 40, height: 40)
                Image(systemName: type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(type.primaryColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.satoshi(16, weight: .bold))
                    .foregroundColor(.white)
                Text("Jour \(data.day)/\(data.totalDays)")
                    .font(.satoshi(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            if let opp = data.opponentName {
                versusBadge(opponent: opp)
            }
        }
    }

    private func versusBadge(opponent: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: 4) {
                Text("\(data.myScore)")
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(data.myScore >= data.opponentScore ? type.primaryColor : .white.opacity(0.6))
                Text("·")
                    .font(.satoshi(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Text("\(data.opponentScore)")
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(data.opponentScore > data.myScore ? .white : .white.opacity(0.6))
            }
            Text("vs \(opponent)")
                .font(.satoshi(10, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
        }
    }

    // MARK: - Open / Urgent CTA

    private var openCTA: some View {
        Button(action: onValidate) {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .semibold))
                if data.state == .urgent {
                    Text("Valider — \(data.validationWindowText ?? "fenêtre fermée bientôt")")
                        .font(.satoshi(14, weight: .bold))
                        .lineLimit(1)
                } else {
                    Text("Valider maintenant")
                        .font(.satoshi(14, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(type.gradient)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Done

    private var doneState: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ColorTokens.successSoft)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ColorTokens.success)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Validé aujourd'hui")
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(.white)
                Text("Bien joué — on se retrouve demain")
                    .font(.satoshi(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.successSoft)
        )
    }

    // MARK: - Closed (window not open yet, or already passed)

    private var closedState: some View {
        Button(action: onOpenHub) {
            HStack(spacing: 10) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Text(data.validationWindowText ?? "Fenêtre fermée")
                    .font(.satoshi(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ColorTokens.surfaceElevated)
            )
        }
        .buttonStyle(.plain)
    }
}
