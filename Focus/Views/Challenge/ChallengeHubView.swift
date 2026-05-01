import SwiftUI
import UIKit

// MARK: - Daily Challenge Checklist

struct ChallengeHubView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChallengeViewModel()
    @State private var progress: [String: TodayProgress] = [:]
    @State private var showCreateChallenge = false
    @State private var showCamera = false
    @State private var cameraTarget: (challengeId: String, stepId: String)?
    @State private var showSuccess: Challenge?
    @State private var selectedChallengeDetail: Challenge?
    @State private var inviteChallenge: Challenge?
    @State private var detailEntries: [String: [ChallengeEntry]] = [:]

    private var currentUserId: String {
        FocusAppStore.shared.user?.id ?? ""
    }

    private var activeChallenges: [Challenge] {
        viewModel.challenges.filter { $0.isActive }
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading && activeChallenges.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
            } else {
                List {
                    // Header
                    header
                        .padding(.top, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 12, trailing: 20))

                    if activeChallenges.isEmpty {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    } else {
                        // Challenge rows — swipeable
                        ForEach(activeChallenges) { challenge in
                            VStack(spacing: 16) {
                                challengeChecklist(challenge)

                                evolutionGallery(challenge)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteChallenge(challenge)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }

                        // Week review
                        weekReview
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 0, trailing: 20))
                    }

                    // New challenge button
                    newChallengeButton
                        .padding(.top, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 40, trailing: 20))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                await viewModel.loadChallenges()
                initProgress()
                await autoFailMissedDays()
                await loadEntries()
            }
        }
        .sheet(isPresented: $showCreateChallenge) {
            CreateChallengeView { type, alarmTime, duration, customTitle, mantra, wantsInvite in
                Task {
                    let title = customTitle ?? type.title
                    if let created = await viewModel.createChallenge(title: title, alarmTime: alarmTime, durationDays: duration, mantra: mantra, challengeType: type.rawValue) {
                        initProgressForChallenge(created)
                        if wantsInvite {
                            inviteChallenge = created
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            SelfieCamera { image in
                showCamera = false
                handleCapturedPhoto(image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedChallengeDetail) { challenge in
            NavigationView {
                ChallengeDetailView(challengeId: challenge.id)
            }
        }
        .sheet(item: $inviteChallenge) { challenge in
            ChallengeInviteView(challenge: challenge)
        }
        .fullScreenCover(item: $showSuccess) { challenge in
            ChallengeSuccessView(
                challenge: challenge,
                dayNumber: challenge.dayNumber,
                onDismiss: { showSuccess = nil }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.satoshi(28, weight: .black))
                    .foregroundColor(.white)
                if !activeChallenges.isEmpty {
                    let done = totalCompletedSteps
                    let total = totalSteps
                    Text("\(done)/\(total) faits aujourd'hui")
                        .font(.satoshi(14, weight: .medium))
                        .foregroundColor(done == total && total > 0 ? ColorTokens.success : ColorTokens.textSecondary)
                }
                // Show mantra if any challenge has one
                if let mantra = activeChallenges.compactMap({ $0.mantra }).first(where: { !$0.isEmpty }) {
                    Text("\"\(mantra)\"")
                        .font(.satoshi(13, weight: .medium))
                        .italic()
                        .foregroundColor(ColorTokens.primaryStart.opacity(0.7))
                        .padding(.top, 2)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Bonjour !" }
        if hour < 18 { return "Bon apres-midi !" }
        return "Bonsoir !"
    }

    // MARK: - Challenge Row

    // MARK: - Challenge Row

    private func challengeChecklist(_ challenge: Challenge) -> some View {
        let day = max(challenge.dayNumber, 1)
        let isDone = challenge.hasLikelyValidatedToday(myId: currentUserId)
        let score = challenge.myScore(myId: currentUserId)

        // Hard check: if alarm exists, directly compute window from alarm time
        let nowH = Calendar.current.component(.hour, from: Date())
        let nowM = Calendar.current.component(.minute, from: Date())
        let nowMins = nowH * 60 + nowM
        let alarmParts = (challenge.alarmTime ?? "").split(separator: ":").compactMap { Int($0) }
        let hasAlarm = alarmParts.count == 2
        let alarmMins = hasAlarm ? alarmParts[0] * 60 + alarmParts[1] : 0
        let windowEndMins = alarmMins + 60

        // Direct window check — if no alarm, default to CLOSED (not open)
        let inWindow: Bool = {
            guard hasAlarm else { return false }
            if windowEndMins > 1440 {
                return nowMins >= alarmMins || nowMins <= (windowEndMins - 1440)
            }
            return nowMins >= alarmMins && nowMins <= windowEndMins
        }()

        let windowPassed: Bool = {
            guard hasAlarm else { return true }  // no alarm = assume passed
            if windowEndMins > 1440 {
                return nowMins > (windowEndMins - 1440) && nowMins < alarmMins
            }
            return nowMins > windowEndMins
        }()

        // If day 1, no score yet, and window passed → challenge starts tomorrow
        let startstomorrow = (day <= 1 && score == 0 && windowPassed)

        return VStack(spacing: 0) {
            // Main row
            HStack(spacing: 14) {
                // Type icon
                Image(systemName: challenge.type.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(challenge.type.primaryColor)
                    .frame(width: 34, height: 34)
                    .background(challenge.type.softColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.displayTitle)
                        .font(.satoshi(16, weight: .bold))
                        .foregroundColor(.white)
                    // Clear rule description
                    Text(challenge.ruleDescription)
                        .font(.satoshi(11, weight: .regular))
                        .foregroundColor(ColorTokens.textMuted)
                }

                Spacer()

                // State
                if isDone {
                    // Validated today
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Fait")
                            .font(.satoshi(13, weight: .bold))
                    }
                    .foregroundColor(ColorTokens.success)
                } else if startstomorrow {
                    // Challenge just created, first day is tomorrow
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.primaryStart)
                        if let next = challenge.nextWindowText {
                            Text(next)
                                .font(.satoshi(10, weight: .medium))
                                .foregroundColor(ColorTokens.primaryStart)
                        }
                    }
                } else if windowPassed {
                    // Window passed — FAILED for today
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Rate")
                                .font(.satoshi(12, weight: .bold))
                        }
                        .foregroundColor(ColorTokens.error)
                        if let next = challenge.nextWindowText {
                            Text(next)
                                .font(.satoshi(10, weight: .medium))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                } else if inWindow {
                    // In window — take photo + time remaining
                    VStack(alignment: .trailing, spacing: 3) {
                        Button {
                            cameraTarget = (challengeId: challenge.id, stepId: "selfie")
                            showCamera = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12))
                                Text("Photo")
                                    .font(.satoshi(13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(challenge.type.gradient)
                            .clipShape(Capsule())
                        }
                        if let remaining = challenge.minutesRemainingInWindow {
                            Text("Encore \(remaining)min")
                                .font(.satoshi(10, weight: .medium))
                                .foregroundColor(ColorTokens.primaryStart)
                        }
                    }
                } else {
                    // Window not open yet — show countdown
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.textMuted)
                        if let next = challenge.nextWindowText {
                            Text(next)
                                .font(.satoshi(10, weight: .medium))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                }
            }
            .padding(14)

            // Bottom bar
            HStack(spacing: 0) {
                Text("Jour \(day)/\(challenge.durationDays ?? 30)")
                    .font(.satoshi(11, weight: .medium))
                    .foregroundColor(ColorTokens.textMuted)

                Spacer()

                if challenge.isSolo {
                    Button { inviteChallenge = challenge } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 10))
                            Text("Inviter")
                                .font(.satoshi(11, weight: .medium))
                        }
                        .foregroundColor(ColorTokens.primaryStart)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(ColorTokens.surfaceElevated.opacity(0.3))
        }
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }

    // MARK: - Evolution Gallery

    private func evolutionGallery(_ challenge: Challenge) -> some View {
        let entries = (detailEntries[challenge.id] ?? [])
            .sorted { $0.dayNumber < $1.dayNumber }

        return Group {
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Mon journal")
                            .font(.satoshi(14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(entries.count) jour\(entries.count > 1 ? "s" : "")")
                            .font(.satoshi(12, weight: .medium))
                            .foregroundColor(ColorTokens.textMuted)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(entries) { entry in
                                VStack(spacing: 4) {
                                    // Photo or placeholder
                                    if let urlStr = entry.photoUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            default:
                                                Rectangle()
                                                    .fill(ColorTokens.surfaceElevated)
                                                    .overlay(
                                                        ProgressView()
                                                            .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.textMuted))
                                                    )
                                            }
                                        }
                                        .frame(width: 72, height: 96)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        // No photo — show status
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(ColorTokens.surfaceElevated)
                                            .frame(width: 72, height: 96)
                                            .overlay(
                                                Image(systemName: entry.isOnTime ? "checkmark" : "xmark")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(entry.isOnTime ? ColorTokens.success : ColorTokens.error)
                                            )
                                    }

                                    // Day + time
                                    Text("J\(entry.dayNumber)")
                                        .font(.satoshi(10, weight: .bold))
                                        .foregroundColor(entry.isOnTime ? ColorTokens.success : ColorTokens.error)

                                    if let time = entry.wakeUpTime, !time.isEmpty {
                                        Text(time)
                                            .font(.satoshi(9, weight: .medium))
                                            .foregroundColor(ColorTokens.textMuted)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
            }
        }
    }

    private func loadEntries() async {
        for challenge in activeChallenges {
            await viewModel.loadChallengeDetail(id: challenge.id)
            if let entries = viewModel.challengeDetail?.entries {
                detailEntries[challenge.id] = entries.filter { $0.userId == currentUserId }
            }
        }
    }

    // MARK: - Week Review

    private var weekReview: some View {
        let days = weekDays()

        return VStack(spacing: 12) {
            HStack {
                Text("Cette semaine")
                    .font(.satoshi(14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            // Day labels
            HStack(spacing: 0) {
                Color.clear.frame(width: 6) // spacer for alignment
                ForEach(days, id: \.self) { date in
                    Text(dayLabel(date))
                        .font(.satoshi(10, weight: .bold))
                        .foregroundColor(ColorTokens.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            // One row per challenge
            ForEach(activeChallenges) { challenge in
                HStack(spacing: 0) {
                    Image(systemName: challenge.type.icon)
                        .font(.system(size: 9))
                        .foregroundColor(challenge.type.primaryColor)
                        .frame(width: 16)

                    ForEach(days, id: \.self) { date in
                        let status = dayStatus(challenge: challenge, date: date)
                        Circle()
                            .fill(status == .full ? ColorTokens.success :
                                  Calendar.current.isDateInToday(date) ? ColorTokens.primaryStart.opacity(0.3) :
                                  ColorTokens.surfaceElevated)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Calendar.current.isDateInToday(date) ?
                                Circle().stroke(ColorTokens.primaryStart, lineWidth: 1.5)
                                    .frame(width: 10, height: 10) : nil
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }

    private enum DayStatus { case full, partial, none }

    private func dayStatus(challenge: Challenge, date: Date) -> DayStatus {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let startStr = challenge.startDate,
              let startDate = fmt.date(from: startStr) else { return .none }
        let dayDiff = cal.dateComponents([.day], from: startDate, to: date).day ?? -1
        guard dayDiff >= 0, date <= Date() else { return .none }
        let dayNum = dayDiff + 1
        let score = challenge.myScore(myId: currentUserId)
        if dayNum <= score { return .full }
        return .none
    }

    private func weekDays() -> [Date] {
        let cal = Calendar.current
        let today = Date()
        // Monday of this week
        let weekday = cal.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -mondayOffset, to: today) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private func dayLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "EEE"
        return String(fmt.string(from: date).prefix(1)).uppercased()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundColor(ColorTokens.primaryStart.opacity(0.3))

            VStack(spacing: 6) {
                Text("Pas encore de challenge")
                    .font(.satoshi(18, weight: .bold))
                    .foregroundColor(.white)
                Text("Cree ton premier defi et commence\na valider chaque jour.")
                    .font(.satoshi(14, weight: .regular))
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - New Challenge Button

    private var newChallengeButton: some View {
        Button { showCreateChallenge = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("Nouveau challenge")
                    .font(.satoshi(14, weight: .medium))
            }
            .foregroundColor(ColorTokens.primaryStart)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ColorTokens.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTokens.primaryStart.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Step Handling

    private func handleStepTap(challenge: Challenge, step: ChallengeStep) {
        switch step.inputType {
        case .toggle:
            markStepDone(challengeId: challenge.id, stepId: step.id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .camera:
            cameraTarget = (challengeId: challenge.id, stepId: step.id)
            showCamera = true
        }
    }

    private func markStepDone(challengeId: String, stepId: String) {
        guard var prog = progress[challengeId] else { return }

        switch stepId {
        case "mantra": prog.mantraValidated = true
        case "exercises": prog.exercisesDone = true
        default: break
        }

        progress[challengeId] = prog
        checkCompletion(challengeId: challengeId)
    }

    private func handleCapturedPhoto(_ image: UIImage) {
        guard let target = cameraTarget,
              var prog = progress[target.challengeId] else { return }

        // Upload async
        Task {
            var photoURL: String? = nil
            if let data = image.jpegData(compressionQuality: 0.7) {
                photoURL = try? await SupabaseStorageService.shared.uploadChallengePhoto(
                    imageData: data,
                    userId: currentUserId,
                    challengeId: target.challengeId
                )
            }

            await MainActor.run {
                // Only mark as done if we got a real URL (or proceed without photo)
                let url = photoURL ?? ""
                switch target.stepId {
                case "selfie": prog.selfieUrl = url.isEmpty ? nil : url
                case "photo": prog.photoUrl = url.isEmpty ? nil : url
                default: break
                }
                // Mark done even without URL — the photo was taken, check-in is valid
                if prog.selfieUrl == nil { prog.selfieUrl = "captured" }
                progress[target.challengeId] = prog
                cameraTarget = nil
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                checkCompletion(challengeId: target.challengeId)
            }
        }
    }

    private func checkCompletion(challengeId: String) {
        guard let prog = progress[challengeId], prog.isComplete else { return }
        guard let challenge = activeChallenges.first(where: { $0.id == challengeId }) else { return }

        // Verify we're still in the validation window before submitting
        let nowH = Calendar.current.component(.hour, from: Date())
        let nowM = Calendar.current.component(.minute, from: Date())
        let now = nowH * 60 + nowM
        let parts = (challenge.alarmTime ?? "").split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            let windowEnd = parts[0] * 60 + parts[1] + 60
            if now > windowEnd && windowEnd <= 1440 {
                // Window passed — don't submit, mark as late
                return
            }
        }

        // Submit to backend
        Task {
            await viewModel.submitChecklist(prog)
            await viewModel.loadChallenges()
        }

        // Show celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showSuccess = challenge
        }
    }

    // MARK: - Auto-Fail Missed Days

    /// On open: for each active challenge where today's window has passed and user hasn't validated,
    /// submit a late check-in so the backend resets the streak.
    private func autoFailMissedDays() async {
        for challenge in activeChallenges {
            let isDone = challenge.hasLikelyValidatedToday(myId: currentUserId)
            let windowPassed = challenge.hasWindowPassedToday()
            let day = max(challenge.dayNumber, 1)
            let score = challenge.myScore(myId: currentUserId)
            // Don't auto-fail day 1 if user never had a chance (created after window)
            let isFirstDayNoChance = (day <= 1 && score == 0 && windowPassed)

            if windowPassed && !isDone && !isFirstDayNoChance {
                // Submit a late check-in — backend will see it's late and reset streak
                await viewModel.checkIn(
                    challengeId: challenge.id,
                    photoUrl: nil,
                    mantraValidated: false,
                    exercisesDone: false
                )
            }
        }
        // Reload to reflect updated streaks
        await viewModel.loadChallenges()
    }

    // MARK: - Delete Challenge

    private func deleteChallenge(_ challenge: Challenge) {
        Task {
            await viewModel.cancelChallenge(id: challenge.id)
            progress.removeValue(forKey: challenge.id)
            detailEntries.removeValue(forKey: challenge.id)
        }
    }

    // MARK: - Progress Helpers

    private func initProgress() {
        for challenge in activeChallenges {
            initProgressForChallenge(challenge)
        }
    }

    private func initProgressForChallenge(_ challenge: Challenge) {
        guard progress[challenge.id] == nil else { return }
        // Check if already validated today
        let alreadyDone = challenge.hasLikelyValidatedToday(myId: currentUserId)
        if alreadyDone {
            // Mark all steps as done
            var prog = TodayProgress(challengeId: challenge.id, challengeType: challenge.type)
            prog.selfieUrl = "done"
            prog.photoUrl = "done"
            prog.mantraValidated = true
            prog.exercisesDone = true
            progress[challenge.id] = prog
        } else {
            progress[challenge.id] = TodayProgress(challengeId: challenge.id, challengeType: challenge.type)
        }
    }

    private var totalCompletedSteps: Int {
        activeChallenges.reduce(0) { $0 + (progress[$1.id]?.completedCount ?? 0) }
    }

    private var totalSteps: Int {
        activeChallenges.reduce(0) { $0 + $1.type.steps.count }
    }
}

#if DEBUG
#Preview {
    ChallengeHubView()
}
#endif
