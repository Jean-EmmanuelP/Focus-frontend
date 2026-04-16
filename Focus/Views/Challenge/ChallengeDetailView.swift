import SwiftUI

// MARK: - Challenge Detail View

struct ChallengeDetailView: View {
    let challengeId: String
    @StateObject private var viewModel = ChallengeViewModel()
    @State private var tauntText = ""
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

    private let orangeGradient = LinearGradient(
        colors: [Color(hex: "#FF9500"), Color(hex: "#FF6B00")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
                Text("Recessayer")
                    .font(.satoshi(15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(orangeGradient)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Pending State (waiting for opponent)

    private func pendingState(_ challenge: Challenge) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                // Waiting illustration
                VStack(spacing: 16) {
                    Text("--")
                        .font(.system(size: 56))

                    Text("En attente de ton pote...")
                        .font(.satoshi(22, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("Partage le code ci-dessous pour que ton ami rejoigne le challenge")
                        .font(.satoshi(14, weight: .regular))
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Invite code card
                if let code = challenge.inviteCode {
                    VStack(spacing: 12) {
                        Text("CODE D'INVITATION")
                            .font(.satoshi(11, weight: .bold))
                            .foregroundColor(ColorTokens.textMuted)
                            .kerning(1.5)

                        Text(code.uppercased())
                            .font(.satoshi(36, weight: .black))
                            .foregroundColor(ColorTokens.textPrimary)
                            .kerning(4)

                        Button {
                            UIPasteboard.general.string = code
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                Text("Copier le code")
                                    .font(.satoshi(13, weight: .medium))
                            }
                            .foregroundColor(ColorTokens.primaryStart)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
                }

                // Share button
                shareButton(challenge)

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

                // Participant cards
                participantCards(challenge)

                // History grid
                historyGrid(challenge)

                // Taunts section
                tauntsSection(challenge)

                // Action buttons
                actionButtons(challenge)

                Spacer().frame(height: 30)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Header

    private func headerSection(_ challenge: Challenge) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.displayTitle)
                    .font(.satoshi(24, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                if let alarm = challenge.alarmTime {
                    HStack(spacing: 6) {
                        Image(systemName: "alarm.fill")
                            .font(.system(size: 11))
                        Text(alarm)
                            .font(.satoshi(13, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#FF9500"))
                }
            }

            Spacer()

            Text("Jour \(challenge.dayNumber)/\(challenge.durationDays)")
                .font(.satoshi(13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(orangeGradient)
                .clipShape(Capsule())
        }
        .padding(.top, 8)
    }

    // MARK: - Participant Cards

    private func participantCards(_ challenge: Challenge) -> some View {
        let myName = isCreator ? (challenge.creatorName ?? "Moi") : (challenge.opponentName ?? "Moi")
        let myScore = challenge.myScore(myId: currentUserId)
        let myStreak = challenge.myStreak(myId: currentUserId)
        let myEntry = latestEntry(for: currentUserId, challenge: challenge)

        let hasOpponent = challenge.opponentId != nil && !challenge.opponentId!.isEmpty

        return HStack(spacing: 12) {
            participantCard(
                name: myName,
                score: myScore,
                streak: myStreak,
                entry: myEntry,
                isMe: true,
                isShadow: false,
                dayNumber: challenge.dayNumber
            )

            if hasOpponent {
                let theirName = isCreator ? (challenge.opponentName ?? "...") : (challenge.creatorName ?? "...")
                let theirScore = challenge.partnerScore(myId: currentUserId)
                let theirStreak = challenge.partnerStreak(myId: currentUserId)
                let theirId = isCreator ? (challenge.opponentId ?? "") : (challenge.creatorId ?? "")
                let theirEntry = latestEntry(for: theirId, challenge: challenge)

                participantCard(
                    name: theirName,
                    score: theirScore,
                    streak: theirStreak,
                    entry: theirEntry,
                    isMe: false,
                    isShadow: false,
                    dayNumber: challenge.dayNumber
                )
            } else {
                // Solo mode: shadow card with 75% target score
                let shadowScore = Int(round(Double(challenge.dayNumber) * 0.75))
                shadowCard(
                    name: "Shadow",
                    shadowScore: shadowScore,
                    dayNumber: challenge.dayNumber
                )
            }
        }
    }

    // MARK: - Shadow Card (Solo Mode)

    private func shadowCard(name: String, shadowScore: Int, dayNumber: Int) -> some View {
        let shadowGradient = LinearGradient(
            colors: [Color(hex: "#6B5B95"), Color(hex: "#3D3552")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return VStack(spacing: 10) {
            // Shadow avatar
            ZStack {
                Circle()
                    .fill(shadowGradient)
                    .frame(width: 52, height: 52)

                Circle()
                    .stroke(Color(hex: "#6B5B95").opacity(0.4), lineWidth: 2)
                    .frame(width: 56, height: 56)

                Image(systemName: "figure.stand")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Name
            Text(name.uppercased())
                .font(.satoshi(11, weight: .bold))
                .foregroundColor(Color(hex: "#6B5B95"))
                .kerning(1)
                .lineLimit(1)

            // Shadow target score
            Text("\(shadowScore)")
                .font(.satoshi(20, weight: .black))
                .foregroundColor(ColorTokens.textPrimary)

            // Label
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.system(size: 12))
                Text("75% objectif")
                    .font(.satoshi(11, weight: .medium))
            }
            .foregroundColor(Color(hex: "#6B5B95"))

            // Score
            Text("Score: \(shadowScore)")
                .font(.satoshi(13, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg)
                        .stroke(Color(hex: "#6B5B95").opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func participantCard(
        name: String,
        score: Int,
        streak: Int,
        entry: ChallengeEntry?,
        isMe: Bool,
        isShadow: Bool,
        dayNumber: Int
    ) -> some View {
        VStack(spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(isMe ? orangeGradient : LinearGradient(colors: [ColorTokens.surfaceElevated, ColorTokens.surfaceElevated], startPoint: .top, endPoint: .bottom))
                    .frame(width: 52, height: 52)

                if isMe {
                    Circle()
                        .stroke(Color(hex: "#FF9500").opacity(0.4), lineWidth: 2)
                        .frame(width: 56, height: 56)
                }

                Text(String(name.prefix(1)).uppercased())
                    .font(.satoshi(22, weight: .bold))
                    .foregroundColor(isMe ? .white : ColorTokens.textSecondary)
            }

            // Name
            Text(isMe ? "MOI" : name.uppercased())
                .font(.satoshi(11, weight: .bold))
                .foregroundColor(isMe ? Color(hex: "#FF9500") : ColorTokens.textSecondary)
                .kerning(1)
                .lineLimit(1)

            // Wake-up time
            if let time = entry?.wakeUpTime {
                Text(formatWakeUpTime(time))
                    .font(.satoshi(20, weight: .black))
                    .foregroundColor(ColorTokens.textPrimary)
            } else {
                Text("--:--")
                    .font(.satoshi(20, weight: .black))
                    .foregroundColor(ColorTokens.textMuted)
            }

            // Validation status
            if let entry = entry, entry.dayNumber == dayNumber {
                HStack(spacing: 4) {
                    Image(systemName: entry.isOnTime ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text(entry.isOnTime ? "Valide" : "En retard")
                        .font(.satoshi(11, weight: .medium))
                }
                .foregroundColor(entry.isOnTime ? ColorTokens.success : ColorTokens.error)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("En attente")
                        .font(.satoshi(11, weight: .medium))
                }
                .foregroundColor(ColorTokens.textMuted)
            }

            // Streak
            if streak > 0 {
                HStack(spacing: 3) {
                    Text("\u{1F525}")
                        .font(.system(size: 11))
                    Text("\(streak) jour\(streak > 1 ? "s" : "")")
                        .font(.satoshi(11, weight: .bold))
                }
                .foregroundColor(ColorTokens.warning)
            }

            // Score
            Text("Score: \(score)")
                .font(.satoshi(13, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg)
                        .stroke(isMe ? Color(hex: "#FF9500").opacity(0.3) : ColorTokens.border, lineWidth: 1)
                )
        )
    }

    // MARK: - History Grid

    private func historyGrid(_ challenge: Challenge) -> some View {
        let daysToShow = min(challenge.dayNumber, 14)
        let myId = currentUserId
        let hasOpponent = challenge.opponentId != nil && !challenge.opponentId!.isEmpty
        let theirId = isCreator ? (challenge.opponentId ?? "") : (challenge.creatorId ?? "")

        return VStack(alignment: .leading, spacing: 12) {
            Text("HISTORIQUE")
                .font(.satoshi(11, weight: .bold))
                .foregroundColor(ColorTokens.textMuted)
                .kerning(1.5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                ForEach((0..<daysToShow).reversed(), id: \.self) { offset in
                    let day = challenge.dayNumber - offset
                    let myEntry = entries.first { $0.userId == myId && $0.dayNumber == day }

                    HStack(spacing: 6) {
                        Text("J\(day)")
                            .font(.satoshi(11, weight: .bold))
                            .foregroundColor(ColorTokens.textMuted)
                            .frame(width: 24, alignment: .leading)

                        Circle()
                            .fill(historyDotColor(entry: myEntry, day: day, currentDay: challenge.dayNumber))
                            .frame(width: 10, height: 10)

                        if hasOpponent {
                            let theirEntry = entries.first { $0.userId == theirId && $0.dayNumber == day }
                            Circle()
                                .fill(historyDotColor(entry: theirEntry, day: day, currentDay: challenge.dayNumber))
                                .frame(width: 10, height: 10)
                        } else {
                            // Solo mode: shadow dot — 75% chance of "success" color for past days
                            Circle()
                                .fill(shadowDotColor(day: day, currentDay: challenge.dayNumber))
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.sm))
                }
            }
        }
        .padding(16)
        .background(ColorTokens.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
    }

    private func shadowDotColor(day: Int, currentDay: Int) -> Color {
        if day >= currentDay {
            return ColorTokens.textMuted.opacity(0.3)
        }
        // Deterministic 75% success: every 4th day is a "miss"
        return day % 4 == 0 ? ColorTokens.error : ColorTokens.success
    }

    private func historyDotColor(entry: ChallengeEntry?, day: Int, currentDay: Int) -> Color {
        if day > currentDay {
            return ColorTokens.textMuted.opacity(0.3)
        }
        guard let entry = entry else {
            if day == currentDay { return ColorTokens.textMuted.opacity(0.3) }
            return ColorTokens.error
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
                    VStack(spacing: 8) {
                        Text("\u{1F4AC}")
                            .font(.system(size: 28))
                        Text("Aucun message pour l'instant")
                            .font(.satoshi(13, weight: .medium))
                            .foregroundColor(ColorTokens.textMuted)
                    }
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
                        .background(tauntText.trimmingCharacters(in: .whitespaces).isEmpty ? ColorTokens.textMuted : Color(hex: "#FF9500"))
                        .clipShape(Circle())
                }
                .disabled(tauntText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .background(ColorTokens.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
    }

    private func tauntBubble(_ taunt: ChallengeTaunt) -> some View {
        let isFromMe = taunt.senderId == currentUserId
        return HStack {
            if isFromMe { Spacer(minLength: 40) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                Text(isFromMe ? "Toi" : (taunt.senderName ?? "Adversaire"))
                    .font(.satoshi(11, weight: .bold))
                    .foregroundColor(isFromMe ? Color(hex: "#FF9500") : ColorTokens.textSecondary)

                Text(taunt.message)
                    .font(.satoshi(14, weight: .regular))
                    .foregroundColor(ColorTokens.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isFromMe ? Color(hex: "#FF9500").opacity(0.15) : ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
            }

            if !isFromMe { Spacer(minLength: 40) }
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(_ challenge: Challenge) -> some View {
        VStack(spacing: 12) {
            // Validate morning button
            if !viewModel.hasValidatedToday(entries: entries, userId: currentUserId) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .openMorningVerification, object: nil)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("\u{1F305}")
                            .font(.system(size: 20))
                        Text("Valider mon matin")
                            .font(.satoshi(17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(orangeGradient)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
                    .shadow(color: Color(hex: "#FF9500").opacity(0.4), radius: 12, y: 4)
                }
            }

            // Send taunt shortcut (scrolls to taunt input)
            Button {
                // No-op: taunt input is always visible in the taunts section
            } label: {
                HStack(spacing: 10) {
                    Text("\u{1F608}")
                        .font(.system(size: 18))
                    Text("Envoyer un taunt")
                        .font(.satoshi(15, weight: .bold))
                }
                .foregroundColor(ColorTokens.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
            }

            // Share link
            shareButton(challenge)
        }
    }

    // MARK: - Share Button

    private func shareButton(_ challenge: Challenge) -> some View {
        Button {
            let code = challenge.inviteCode ?? ""
            let text = "Rejoins mon challenge \"\(challenge.displayTitle)\" sur Focali ! Code: \(code) \u{1F4AA}\u{1F525}"
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

    private func formatWakeUpTime(_ time: String) -> String {
        // Handle ISO format or HH:mm format
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
