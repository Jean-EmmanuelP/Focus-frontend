import Foundation
import AmplitudeSwift

@MainActor
final class AmplitudeService {
    static let shared = AmplitudeService()

    private let amplitude: Amplitude

    private init() {
        amplitude = Amplitude(configuration: Configuration(
            apiKey: "1381b24538837218e76b8695871c7b4a",
            defaultTracking: DefaultTrackingOptions.ALL
        ))

        // Note: Session Replay plugin requires additional configuration
        // See: https://www.docs.developers.amplitude.com/session-replay/
    }

    // MARK: - User Identity

    func identify(userId: String, properties: [String: Any]? = nil) {
        amplitude.setUserId(userId: userId)
        if let properties = properties {
            let identify = Identify()
            for (key, value) in properties {
                if let stringValue = value as? String {
                    identify.set(property: key, value: stringValue)
                } else if let intValue = value as? Int {
                    identify.set(property: key, value: intValue)
                } else if let boolValue = value as? Bool {
                    identify.set(property: key, value: boolValue)
                }
            }
            amplitude.identify(identify: identify)
        }
    }

    func reset() {
        amplitude.reset()
    }

    // MARK: - Generic Event Tracking

    func track(_ event: String, properties: [String: Any]? = nil) {
        amplitude.track(eventType: event, eventProperties: properties)
    }

    // MARK: - Auth Events

    func trackSignUp(method: String) {
        track("Sign Up", properties: ["method": method])
    }

    func trackLogin(method: String) {
        track("Login", properties: ["method": method])
    }

    func trackLogout() {
        track("Logout")
        reset()
    }

    // MARK: - Focus Session Events

    func trackFocusSessionStarted(duration: Int, questId: String? = nil) {
        var props: [String: Any] = ["duration_minutes": duration]
        if let questId = questId {
            props["quest_id"] = questId
        }
        track("Focus Session Started", properties: props)
    }

    func trackFocusSessionCompleted(duration: Int, actualMinutes: Int) {
        track("Focus Session Completed", properties: [
            "planned_duration": duration,
            "actual_minutes": actualMinutes
        ])
    }

    func trackFocusSessionCancelled(afterMinutes: Int) {
        track("Focus Session Cancelled", properties: ["after_minutes": afterMinutes])
    }

    // MARK: - Task Events

    func trackTaskCreated(hasQuest: Bool, priority: String?) {
        var props: [String: Any] = ["has_quest": hasQuest]
        if let priority = priority {
            props["priority"] = priority
        }
        track("Task Created", properties: props)
    }

    func trackTaskCompleted(fromFocus: Bool = false) {
        track("Task Completed", properties: ["from_focus": fromFocus])
    }

    // MARK: - Quest Events

    func trackQuestCreated(domain: String) {
        track("Quest Created", properties: ["domain": domain])
    }

    func trackQuestCompleted(domain: String) {
        track("Quest Completed", properties: ["domain": domain])
    }

    // MARK: - Routine/Ritual Events

    func trackRoutineCreated() {
        track("Routine Created")
    }

    func trackRoutineCompleted() {
        track("Routine Completed")
    }

    // MARK: - Check-in Events

    func trackMorningCheckInCompleted() {
        track("Morning Check-in Completed")
    }

    func trackEveningReviewCompleted() {
        track("Evening Review Completed")
    }

    // MARK: - Social Events

    func trackFriendRequestSent() {
        track("Friend Request Sent")
    }

    func trackFriendRequestAccepted() {
        track("Friend Request Accepted")
    }

    func trackCommunityPostCreated() {
        track("Community Post Created")
    }

    // MARK: - Subscription Events

    func trackPaywallViewed(source: String) {
        track("Paywall Viewed", properties: ["source": source])
    }

    func trackSubscriptionStarted(plan: String) {
        track("Subscription Started", properties: ["plan": plan])
    }

    // MARK: - Feature Usage

    func trackFeatureUsed(_ feature: String) {
        track("Feature Used", properties: ["feature": feature])
    }
}
