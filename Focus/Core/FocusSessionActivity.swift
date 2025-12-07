import ActivityKit
import SwiftUI
import Combine

// MARK: - Focus Session Activity Attributes
struct FocusSessionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state that updates during the session
        var timeRemaining: Int // seconds
        var progress: Double // 0.0 to 1.0
        var isPaused: Bool
    }

    // Static data that doesn't change during the session
    var sessionId: String
    var totalDuration: Int // minutes
    var description: String?
    var questTitle: String?
    var questEmoji: String?
    var startTime: Date
}

// MARK: - Live Activity Manager
@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published var currentActivity: Activity<FocusSessionActivityAttributes>?

    private init() {}

    // MARK: - Start Live Activity
    func startLiveActivity(
        sessionId: String,
        totalDuration: Int,
        description: String?,
        questTitle: String?,
        questEmoji: String?
    ) {
        // Check if Live Activities are supported and enabled
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("Live Activities are not enabled on this device")
            return
        }

        // Check if the app supports Live Activities (requires Info.plist configuration)
        #if targetEnvironment(simulator)
        print("Live Activities may not work properly in simulator")
        #endif

        let attributes = FocusSessionActivityAttributes(
            sessionId: sessionId,
            totalDuration: totalDuration,
            description: description,
            questTitle: questTitle,
            questEmoji: questEmoji,
            startTime: Date()
        )

        let initialState = FocusSessionActivityAttributes.ContentState(
            timeRemaining: totalDuration * 60,
            progress: 0.0,
            isPaused: false
        )

        let activityContent = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(TimeInterval(totalDuration * 60 + 60))
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            currentActivity = activity
            print("Started Live Activity: \(activity.id)")
        } catch let error as ActivityAuthorizationError {
            print("Live Activity authorization error: \(error.localizedDescription)")
            // Live Activities not configured in Info.plist - this is expected during development
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
            // Continue without Live Activity - the timer will still work
        }
    }

    // MARK: - Update Live Activity
    func updateLiveActivity(timeRemaining: Int, progress: Double, isPaused: Bool) {
        guard let activity = currentActivity else { return }

        let updatedState = FocusSessionActivityAttributes.ContentState(
            timeRemaining: timeRemaining,
            progress: progress,
            isPaused: isPaused
        )

        let updatedContent = ActivityContent(
            state: updatedState,
            staleDate: Date().addingTimeInterval(TimeInterval(timeRemaining + 60))
        )

        Task {
            await activity.update(updatedContent)
        }
    }

    // MARK: - End Live Activity
    func endLiveActivity(completed: Bool = true) {
        guard let activity = currentActivity else { return }

        let finalState = FocusSessionActivityAttributes.ContentState(
            timeRemaining: 0,
            progress: completed ? 1.0 : 0.0,
            isPaused: false
        )

        let finalContent = ActivityContent(
            state: finalState,
            staleDate: Date().addingTimeInterval(60)
        )

        Task {
            await activity.end(finalContent, dismissalPolicy: .after(.now + 30))
            await MainActor.run {
                currentActivity = nil
            }
        }
    }

    // MARK: - End All Activities
    func endAllActivities() {
        Task {
            for activity in Activity<FocusSessionActivityAttributes>.activities {
                let finalState = FocusSessionActivityAttributes.ContentState(
                    timeRemaining: 0,
                    progress: 0.0,
                    isPaused: false
                )
                let finalContent = ActivityContent(
                    state: finalState,
                    staleDate: Date()
                )
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
            await MainActor.run {
                currentActivity = nil
            }
        }
    }
}
