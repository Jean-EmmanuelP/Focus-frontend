import SwiftUI

// MARK: - Challenge Detail View

struct ChallengeDetailView: View {
    let challengeId: String
    @StateObject private var viewModel = ChallengeViewModel()
    @State private var tauntText = ""
    @State private var isPulsing = false
    @Environment(\.dismiss) private var dismiss

    private var currentUserId: String {
        FocusAppStore.shared.user?.id ?? ""
    }

    private var isCreator: Bool {
        currentUserId == viewModel.challenge?.creatorId
    }

    private var entries: [ChallengeEntry] {
        viewModel.challengeDetail?.entries ?? []
    }

    private var myAvatarUrl: String? {
        FocusAppStore.shared.user?.avatarURL
    }

    private var theirAvatarUrl: String? {
        guard let challenge = viewModel.challenge, !challenge.isSolo else { return nil }
        return isCreator ? challenge.opponentAvatarUrl : challenge.creatorAvatarUrl
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading {
                loadingState
            } else if let challenge = viewModel.challenge {
                if challenge.isPending {
                    pendingState(challenge)
                } else {
                    activeState(challenge)
                }
            } else if let error = viewModel.error {
                errorState(error)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(ColorTokens.surface)
                        .clipShape(Circle())
                }
            }
        }
        .onAppear {
            Task { await viewModel.loadChallengeDetail(id: challengeId) }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                .scaleEffect(1.2)
            Text("Chargement...")
                .font(.satoshi(14, weight: .medium))
                .foregroundColor(ColorTokens.textMuted)
        }
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(ColorTokens.warning)
            Text("Erreur")
                .font(.satoshi(18, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)
            Text(message)
                .font(.satoshi(14, weight: .regular))
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                Task { await viewModel.loadChallengeDetail(id: challengeId) }
            } label: {
                Text("Reessayer")
                    .font(.satoshi(15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ColorTokens.primaryGradient)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Pending State (waiting for opponent)

    private func pendingState(_ challenge: Challenge) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                Spacer().frame(height: 40)

                // Waiting icon
                Image(systemName: "person.2.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(ColorTokens.textMuted)

                VStack(spacing: 10) {
                    Text("En attente de ton pote...")
                        .font(.satoshi(22, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Partage ce code a ton pote")
                        .font(.satoshi(14, weight: .regular))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                // Invite code card
                if let code = challenge.inviteCode {
                    VStack(spacing: 16) {
                        Text("CODE D'INVITATION")
                            .font(.satoshi(11, weight: .bold))
                            .foregroundColor(ColorTokens.textMuted)
                            .kerning(1.5)

                        Text(code.uppercased())
                            .font(.satoshi(36, weight: .black))
                            .foregroundColor(ColorTokens.textPrimary)
                            .kerning(4)

                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = code
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                    Text("Copier")
                                        .font(.satoshi(13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(ColorTokens.primaryGradient)
                                .clipShape(Capsule())
                            }

                            shareButton(challenge)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Active State (main detail view)

    private func activeState(_ challenge: Challenge) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                headerSection(challenge)

                // Validate button (hero)
                validateSection(challenge)

                // Score section
                scoreSection(challenge)

                // Progress bar
                progressSection(challenge)

                // History week
                historySection(challenge)

                // Taunts section
                tauntsSection(challenge)

                // Share link
                shareButton(challenge)

                Spacer().frame(height: 30)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Header

    private func headerSection(_ challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(challenge.displayTitle)
                .font(.satoshi(28, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            Text("Jour \(challenge.dayNumber) sur \(challenge.durationDays ?? 30)")
                .font(.satoshi(14, weight: .regular))
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Validate Section (Hero)

    private func validateSection(_ challenge: Challenge) -> some View {
        Group {
            if viewModel.hasValidatedToday(entries: entries, userId: currentUserId) {
                // Already validated — rewarding state
                let todayEntry = latestEntryToday(for: currentUserId, challenge: challenge)
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(ColorTokens.success)
                    if let time = todayEntry?.wakeUpTime {
                        Text("Valide a \(formatWakeUpTime(time))")
                            .font(.satoshi(15, weight: .medium))
                            .foregroundColor(ColorTokens.success)
                    } else {
                        Text("Valide")
                            .font(.satoshi(15, weight: .medium))
                            .foregroundColor(ColorTokens.success)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(ColorTokens.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
            } else {
                // Not yet validated — big CTA with pulse
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .openMorningVerification, object: nil)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("VALIDER MON MATIN")
                            .font(.satoshi(18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(ColorTokens.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
                    .scaleEffect(isPulsing ? 1.02 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                }
                .onAppear { isPulsing = true }
            }
        }
    }

    // MARK: - Score Section

    private func scoreSection(_ challenge: Challenge) -> some View {
        let myScore = challenge.myScore(myId: currentUserId)
        let myStreak = challenge.myStreak(myId: currentUserId)
        let isSolo = challenge.isSolo

        let theirName = isSolo ? "Best Me" : (isCreator ? (challenge.opponentName ?? "...") : (challenge.creatorName ?? "..."))
        let theirScore = isSolo ? Int(round(Double(challenge.dayNumber) * 0.75)) : challenge.partnerScore(myId: currentUserId)
        let theirStreak = isSolo ? 0 : challenge.partnerStreak(myId: currentUserId)

        return HStack(spacing: 0) {
            // My side
            VStack(spacing: 8) {
                avatarView(url: myAvatarUrl, initial: "T", size: 48)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#5AC8FA").opacity(0.5), lineWidth: 2)
                            .frame(width: 52, height: 52)
                    )

                Text("Toi")
                    .font(.satoshi(13, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)

                Text("\(myScore)")
                    .font(.satoshi(34, weight: .black))
                    .foregroundColor(ColorTokens.textPrimary)

                streakBadge(streak: myStreak, isSoloTarget: false)
            }
            .frame(maxWidth: .infinity)

            // Center divider
            Text("vs")
                .font(.satoshi(14, weight: .bold))
                .foregroundColor(ColorTokens.textMuted)
                .padding(.top, 24)

            // Their side
            VStack(spacing: 8) {
                if isSolo {
                    ZStack {
                        Circle().fill(ColorTokens.primarySoft)
                        Image(systemName: "target")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(ColorTokens.primaryStart)
                    }
                    .frame(width: 48, height: 48)
                } else {
                    avatarView(url: theirAvatarUrl, initial: String(theirName.prefix(1)).uppercased(), size: 48)
                }

                Text(theirName)
                    .font(.satoshi(13, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)

                Text("\(theirScore)")
                    .font(.satoshi(34, weight: .black))
                    .foregroundColor(ColorTokens.textPrimary)

                if isSolo {
                    Text("75% obj.")
                        .font(.satoshi(12, weight: .medium))
                        .foregroundColor(ColorTokens.textMuted)
                } else {
                    streakBadge(streak: theirStreak, isSoloTarget: false)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
    }

    // MARK: - Avatar View

    private func avatarView(url: String?, initial: String, size: CGFloat) -> some View {
        Group {
            if let urlString = url, !urlString.isEmpty, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialCircle(initial: initial, size: size)
                    }
                }
            } else {
                initialCircle(initial: initial, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func initialCircle(initial: String, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(ColorTokens.surfaceElevated)
            Text(initial)
                .font(.satoshi(size * 0.38, weight: .bold))
                .foregroundColor(ColorTokens.textSecondary)
        }
    }

    private func streakBadge(streak: Int, isSoloTarget: Bool) -> some View {
        Group {
            if streak > 0 {
                HStack(spacing: 3) {
                    Text("\u{1F525}")
                        .font(.system(size: 11))
                    Text("\(streak)j")
                        .font(.satoshi(12, weight: .bold))
                }
                .foregroundColor(ColorTokens.warning)
            } else {
                Text("0j")
                    .font(.satoshi(12, weight: .medium))
                    .foregroundColor(ColorTokens.textMuted)
            }
        }
    }

    // MARK: - Progress Section

    private func progressSection(_ challenge: Challenge) -> some View {
        let total = challenge.durationDays ?? 30
        let completed = max(0, challenge.dayNumber - 1)
        let ratio = total > 0 ? CGFloat(completed) / CGFloat(total) : 0

        return VStack(alignment: .leading, spacing: 10) {
            Text("PROGRESSION")
                .font(.satoshi(11, weight: .bold))
                .foregroundColor(ColorTokens.textMuted)
                .kerning(1.5)

            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ColorTokens.surface)
                            .frame(height: 8)

                        Capsule()
                            .fill(ColorTokens.primaryGradient)
                            .frame(width: max(0, geo.size.width * ratio), height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(completed)/\(total)")
                    .font(.satoshi(13, weight: .bold))
                    .foregroundColor(ColorTokens.textSecondary)
                    .fixedSize()
            }
        }
    }

    // MARK: - History Section (week view)

    private func historySection(_ challenge: Challenge) -> some View {
        let dayLabels = ["L", "M", "M", "J", "V", "S", "D"]
        let myId = currentUserId

        // Build the last 7 days of history
        let today = challenge.dayNumber
        let daysToShow = min(today, 7)

        return VStack(alignment: .leading, spacing: 12) {
            Text("HISTORIQUE")
                .font(.satoshi(11, weight: .bold))
                .foregroundColor(ColorTokens.textMuted)
                .kerning(1.5)

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    let dayOffset = 7 - index
                    let dayNum = today - dayOffset + 1
                    let entry = dayNum > 0 ? entries.first(where: { $0.userId == myId && $0.dayNumber == dayNum }) : nil
                    let isFuture = dayNum > today || dayNum <= 0

                    VStack(spacing: 6) {
                        Text(dayLabels[index % 7])
                            .font(.satoshi(11, weight: .medium))
                            .foregroundColor(ColorTokens.textMuted)

                        Circle()
                            .fill(historyDotColor(entry: entry, isFuture: isFuture, isToday: dayNum == today))
                            .frame(width: 12, height: 12)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
    }

    private func historyDotColor(entry: ChallengeEntry?, isFuture: Bool, isToday: Bool) -> Color {
        if isFuture {
            return ColorTokens.textMuted.opacity(0.2)
        }
        guard let entry = entry else {
            if isToday { return ColorTokens.textMuted.opacity(0.3) }
            return ColorTokens.textMuted.opacity(0.2)
        }
        return entry.isOnTime ? ColorTokens.success : ColorTokens.error
    }

    // MARK: - Taunts Section

    private func tauntsSection(_ challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MESSAGES")
                .font(.satoshi(11, weight: .bold))
                .foregroundColor(ColorTokens.textMuted)
                .kerning(1.5)

            if viewModel.taunts.isEmpty {
                HStack {
                    Spacer()
                    Text("Aucun message pour l'instant")
                        .font(.satoshi(13, weight: .medium))
                        .foregroundColor(ColorTokens.textMuted)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(viewModel.taunts.suffix(5)) { taunt in
                    tauntBubble(taunt)
                }
            }

            // Input field
            HStack(spacing: 10) {
                TextField("Envoie un taunt...", text: $tauntText)
                    .font(.satoshi(14, weight: .regular))
                    .foregroundColor(ColorTokens.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))

                Button {
                    let message = tauntText
                    tauntText = ""
                    Task { await viewModel.sendTaunt(challengeId: challengeId, message: message) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(tauntText.trimmingCharacters(in: .whitespaces).isEmpty ? ColorTokens.textMuted : ColorTokens.primaryStart)
                        .clipShape(Circle())
                }
                .disabled(tauntText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
    }

    private func tauntBubble(_ taunt: ChallengeTaunt) -> some View {
        let isFromMe = taunt.senderId == currentUserId
        return HStack {
            if isFromMe { Spacer(minLength: 40) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                Text(isFromMe ? "Toi" : (taunt.senderName ?? "Adversaire"))
                    .font(.satoshi(11, weight: .bold))
                    .foregroundColor(isFromMe ? ColorTokens.primaryStart : ColorTokens.textSecondary)

                Text(taunt.message)
                    .font(.satoshi(14, weight: .regular))
                    .foregroundColor(ColorTokens.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isFromMe ? ColorTokens.primaryStart.opacity(0.15) : ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
            }

            if !isFromMe { Spacer(minLength: 40) }
        }
    }

    // MARK: - Share Button

    private func shareButton(_ challenge: Challenge) -> some View {
        Button {
            let code = challenge.inviteCode ?? ""
            let text = "Rejoins mon challenge \"\(challenge.displayTitle)\" sur Focali ! Code: \(code)"
            let url = URL(string: "https://apps.apple.com/app/focali/id6742245252")!
            let ac = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let vc = scene.windows.first?.rootViewController {
                vc.present(ac, animated: true)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                Text("Partager le lien")
                    .font(.satoshi(14, weight: .medium))
            }
            .foregroundColor(ColorTokens.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    private func latestEntry(for userId: String, challenge: Challenge) -> ChallengeEntry? {
        entries
            .filter { $0.userId == userId }
            .sorted { ($0.dayNumber) > ($1.dayNumber) }
            .first
    }

    private func latestEntryToday(for userId: String, challenge: Challenge) -> ChallengeEntry? {
        entries
            .filter { $0.userId == userId && $0.dayNumber == challenge.dayNumber }
            .first
    }

    private func formatWakeUpTime(_ time: String) -> String {
        if time.count >= 16 {
            let start = time.index(time.startIndex, offsetBy: 11)
            let end = time.index(start, offsetBy: 5)
            return String(time[start..<end])
        }
        return time
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ChallengeDetailView(challengeId: "preview-123")
    }
}
