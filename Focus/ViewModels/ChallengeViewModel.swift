import Foundation
import SwiftUI
import Combine

@MainActor
class ChallengeViewModel: ObservableObject {

    // MARK: - Published State
    @Published var challenges: [Challenge] = []
    @Published var activeChallenge: Challenge?
    @Published var challengeDetail: ChallengeDetailResponse?
    @Published var taunts: [ChallengeTaunt] = []
    @Published var isLoading = false
    @Published var error: String?

    private let api = APIClient.shared

    /// Current user ID from the global app store
    var currentUserId: String {
        FocusAppStore.shared.user?.id ?? ""
    }

    // MARK: - Derived Challenge

    /// Derives a `Challenge` from `challengeDetail` so views can use a single model.
    var challenge: Challenge? {
        guard let d = challengeDetail else { return nil }
        return Challenge(id: d.id, challengeType: "wakeup", alarmTime: d.alarmTime, durationDays: d.durationDays, status: d.status, creatorId: d.creatorId, opponentId: d.opponentId, creatorName: d.creatorName, opponentName: d.opponentName, creatorScore: d.creatorScore, opponentScore: d.opponentScore, creatorStreak: d.creatorStreak, opponentStreak: d.opponentStreak, startDate: d.startDate, customTitle: nil, inviteCode: d.inviteCode, mantra: d.mantra, title: d.title)
    }

    // MARK: - Load Challenges

    /// Fetches all wake-up challenges for the current user.
    /// Sets `activeChallenge` to the first active challenge found.
    func loadChallenges() async {
        isLoading = true
        error = nil

        do {
            let result: [Challenge] = try await api.request(
                endpoint: .challenges,
                method: .get
            )
            challenges = result
            activeChallenge = result.first(where: { $0.isActive })
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Load Challenge Detail

    /// Fetches detailed info for a specific challenge, including entries.
    /// Also loads taunts in parallel.
    func loadChallengeDetail(id: String) async {
        isLoading = true
        error = nil

        do {
            async let detailRequest: ChallengeDetailResponse = api.request(
                endpoint: .getChallenge(id),
                method: .get
            )
            async let tauntsRequest: Void = loadTaunts(challengeId: id)

            let detail = try await detailRequest
            _ = await tauntsRequest

            challengeDetail = detail
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create Challenge

    /// Creates a new wake-up challenge and returns it (with invite_code).
    /// Reloads the challenge list on success.
    func createChallenge(title: String, alarmTime: String, durationDays: Int, mantra: String?) async -> Challenge? {
        isLoading = true
        error = nil

        let body = CreateChallengeRequest(
            alarmTime: alarmTime,
            durationDays: durationDays,
            title: title,
            mantra: mantra
        )

        do {
            let created: Challenge = try await api.request(
                endpoint: .createChallenge,
                method: .post,
                body: body
            )
            await loadChallenges()
            isLoading = false
            return created
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    // MARK: - Join by Invite Code

    /// Joins a challenge using an invite code. Returns `true` on success.
    func joinByCode(_ code: String) async -> Bool {
        isLoading = true
        error = nil

        let body = JoinByCodeRequest(inviteCode: code)

        do {
            let _: Challenge = try await api.request(
                endpoint: .joinByCode,
                method: .post,
                body: body
            )
            await loadChallenges()
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Check In (after voice validation)

    /// Records a check-in for today. Uses the current time as `wake_up_time`.
    func checkIn(challengeId: String, photoUrl: String?, mantraValidated: Bool, exercisesDone: Bool) async {
        isLoading = true
        error = nil

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let wakeUpTime = formatter.string(from: Date())

        let body = ChallengeCheckInRequest(
            wakeUpTime: wakeUpTime,
            photoUrl: photoUrl,
            mantraValidated: mantraValidated,
            exercisesDone: exercisesDone
        )

        do {
            try await api.request(
                endpoint: .challengeCheckIn(challengeId),
                method: .post,
                body: body
            ) as ChallengeEntry

            // Refresh detail to reflect updated scores/entries
            await loadChallengeDetail(id: challengeId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Send Taunt

    /// Sends a taunt message to the opponent in a challenge.
    func sendTaunt(challengeId: String, message: String) async {
        error = nil

        let body = SendTauntRequest(message: message)

        do {
            let _: ChallengeTaunt = try await api.request(
                endpoint: .sendTaunt(challengeId),
                method: .post,
                body: body
            )
            await loadTaunts(challengeId: challengeId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Load Taunts

    /// Fetches all taunts for a given challenge.
    func loadTaunts(challengeId: String) async {
        do {
            let result: [ChallengeTaunt] = try await api.request(
                endpoint: .getTaunts(challengeId),
                method: .get
            )
            taunts = result
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Invite Link

    /// Builds a deep link URL from a challenge's invite code.
    func inviteLink(for challenge: Challenge) -> String? {
        guard let code = challenge.inviteCode else { return nil }
        return "focus://challenge/\(code)"
    }

    // MARK: - Has Validated Today

    /// Checks whether a user has already submitted an entry for today's day number.
    func hasValidatedToday(entries: [ChallengeEntry], userId: String) -> Bool {
        guard let detail = challengeDetail,
              let startDateString = detail.startDate else {
            return false
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        guard let startDate = fmt.date(from: startDateString) else { return false }

        let todayDayNumber = max(1, Int(Date().timeIntervalSince(startDate) / 86400) + 1)

        return entries.contains { entry in
            entry.userId == userId && entry.dayNumber == todayDayNumber
        }
    }
}
