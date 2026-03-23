# Frontend Code Review -- Focus iOS App

## CRITICAL -- Fix Immediately

### 1. LocationService double continuation resume (CRASH)

**File:** `Focus/Services/LocationService.swift:83-114`

Both the timeout (`DispatchQueue.main.asyncAfter`) and the Combine `.sink` can resume the same `withCheckedThrowingContinuation` continuation. The `cancelled` flag is checked without synchronization, creating a race window where both paths pass the guard and call `continuation.resume(...)`. This is undefined behavior and **will crash at runtime**. Additionally, the `cancellable` returned by `.sink` is immediately discarded (`_ = cancellable`), so the subscription may be deallocated before it fires.

---

### 2. Broken alert binding in VoiceCallView

**File:** `Focus/Views/VoiceCall/VoiceCallView.swift:42`

```swift
.alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil && viewModel.callState != .offline)) {
```

`.constant(...)` creates a binding SwiftUI cannot write to. When the user taps "OK", SwiftUI attempts to set `isPresented` to `false` but cannot. The alert may re-appear immediately if the condition remains true. The button action sets `viewModel.errorMessage = nil`, but there is a race: SwiftUI evaluates the constant binding before the action runs. This should use a proper `Binding` or a `@State` bool.

---

### 3. `@ObservedObject` instead of `@StateObject` on subscriptionManager

**File:** `Focus/App/FocusApp.swift:20`

```swift
@ObservedObject private var subscriptionManager = SubscriptionManager.shared
```

`@ObservedObject` does not own the lifecycle of the object. If SwiftUI reinitializes the `FocusApp` struct, the observation binding can be silently dropped. The other three properties on lines 18, 19, and 21 correctly use `@StateObject`. This one should as well.

---

### 4. APILogger data race

**File:** `Focus/Core/APIClient.swift:13, 163-166`

`APILogger` is a plain class (not `@MainActor`, not `Sendable`) with a mutable `requestCounter` property. `nextRequestId()` increments it without synchronization. `APILogger.shared` is accessed from the `@MainActor`-isolated `APIClient` but `APILogger` itself has no isolation, so concurrent calls race on `requestCounter`. The `DateFormatter` at lines 7-11 is also not thread-safe.

---

### 5. Location throttle logic is inverted -- backend save never triggers

**File:** `Focus/Services/LocationService.swift:198-209`

`lastUpdateTime` is set to `Date()` at line 200 unconditionally on every location update, but `shouldUpdate()` at line 206 checks if enough time has passed since `lastUpdateTime`. Because `lastUpdateTime` was just set two lines above, `shouldUpdate()` will always return `false`. The backend save will never trigger via this code path.

---

### 6. MessageQueueService / SyncManager race condition

**Files:** `Focus/Services/MessageQueueService.swift:87-119`, `Focus/Core/SyncManager.swift:121-155`

The `isProcessing` / `isSyncing` guard is not atomic. Between the check and the set, another caller (fired from `Task` at line 79/96) can also pass the guard. Multiple concurrent processing loops can interleave and mutate the same array simultaneously, leading to duplicated operations or index-out-of-bounds crashes.

---

### 7. `@StateObject` wrapping pre-existing singletons creates ambiguous ownership

**Files:** `Focus/App/FocusApp.swift:18-19`, `Focus/Navigation/Navigation.swift:73`

```swift
@StateObject private var router = AppRouter.shared
@StateObject private var store = FocusAppStore.shared
```

`@StateObject` is designed to own a newly created object. Wrapping a singleton defeats this: the object lives forever regardless, and multiple views claiming `@StateObject` ownership of the same instance creates contradictory ownership semantics. For singletons, `@ObservedObject` or `@EnvironmentObject` is the correct wrapper.

---

## HIGH -- Performance

### 8. ChatView is 2,216 lines -- monolithic view

**File:** `Focus/Views/Chat/ChatView.swift`

Contains the main `ChatView` (744 lines), `SatisfactionGaugeView`, `ReplikaMessageBubble` (with card views, voice bubble, inline task list, inline routine list, inline planning card, video cards, typing dots, checkbox view, and more) all in a single file. It has 15 `@State` properties (lines 12-27), 6 `.overlay` modifiers chained consecutively (lines 85-158), and 7 `.animation` modifiers on the same view hierarchy. Every state change triggers re-evaluation of the entire 744-line body.

---

### 9. SettingsView is 2,356 lines with 13 `@State` boolean flags

**File:** `Focus/Views/Settings/SettingsView.swift:50-77`

Thirteen separate `@State` booleans control overlay navigation (`showAccount`, `showVoicePicker`, `showEditName`, etc.). Each has its own `.animation()` modifier (lines 108-119 -- 12 chained `.animation` modifiers). Changing any one boolean triggers a full re-evaluation of the entire 2,356-line body. This is a `NavigationStack` use case.

---

### 10. Recording timer fires 10x/sec, causing excessive re-renders

**File:** `Focus/Views/Chat/ChatView.swift:724`

```swift
recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    recordingTime += 0.1
}
```

The timer fires 10 times per second. `recordingTime` is a `@State` property, so every 100ms triggers a full re-evaluation of `ChatView`. The `waveformScale(for:)` function (line 689) depends on `recordingTime` and renders 25 animated circles, producing ~250 view updates per second.

---

### 11. `recalculateGroupedMessages()` runs synchronously in `didSet`, causing double publish

**File:** `Focus/ViewModels/ChatViewModel.swift:239-241`

```swift
@Published var messages: [SimpleChatMessage] = [] {
    didSet { recalculateGroupedMessages() }
}
```

Every mutation to `messages` triggers a full re-grouping of all messages by date. The function iterates the entire array and allocates new `MessageGroup` arrays, then triggers a `@Published` update on `groupedMessages`, causing two separate SwiftUI update passes for every single message change.

---

### 12. 3D Avatar renders continuously as chat background

**File:** `Focus/Views/Chat/ChatView.swift:211-221`

A SceneKit/3D avatar is rendered as the background of the main chat screen at all times. While there is an `isPaused` mechanism, it only pauses during keyboard animation. The 3D renderer runs continuously during normal chat interaction, consuming GPU resources on every frame.

---

### 13. 3D Avatar also rendered in SettingsView promo banner

**File:** `Focus/Views/Settings/SettingsView.swift:315-322`

An `Avatar3DView` (SceneKit/WebView) is instantiated inside a `ScrollView` in the settings promo banner. This 3D view is created and rendered even when scrolled off screen.

---

### 14. `syncParticipants()` called excessively with no diffing

**File:** `Focus/Services/FocusRoomLiveKitService.swift:119-243`

`syncParticipants()` is called from every single delegate callback (connect, disconnect, publish, unpublish, subscribe, unsubscribe, muted, speaking, connection state), plus `syncAfterDelay` schedules additional delayed calls. A 2-second repeating timer at line 158 calls it continuously. Each call rebuilds the entire `participants` array and publishes it. There is no diffing -- even if nothing changed, a new array is published.

---

### 15. `ParticipantState` allocated inside the view body on every render

**File:** `Focus/Views/FocusRoom/FocusRoomView.swift:134-145`

A new `ParticipantState` object is created every time the body is evaluated. This should be a computed property on the view model.

---

### 16. `NearbyUser` constructed inline inside Map annotations on every render

**File:** `Focus/Views/Discover/DiscoverMapView.swift:217-233`

The current-user `Annotation` closure constructs a `NearbyUser` with 14 parameters on every body evaluation, triggered by any `@Published` property change on the DiscoverMapViewModel.

---

## HIGH -- Architecture

### 17. FocusAppStore is a 1,353-line God Object

**File:** `Focus/Core/AppStore.swift`

Handles: authentication, onboarding status, subscription state, user profile, sessions, rituals, tasks, calendar, weekly goals, areas, stats, streak data, dashboard loading, widget syncing, and fallback endpoint loading. It has 20+ `@Published` properties and 12 service dependencies. Should be decomposed into focused domain stores.

---

### 18. Business logic lives in the View layer (NewOnboardingView)

**File:** `Focus/Views/Onboarding/NewOnboardingView.swift`

1,353 lines. Lines 1204-1340 contain API calls (`APIClient.shared.request`), Gmail integration (`GmailService.shared.signIn`), token management, email analysis, and location service calls -- all directly in the View struct. This logic belongs in the ViewModel.

---

### 19. ChatView directly mutates ViewModel state and calls service singletons

**File:** `Focus/Views/Chat/ChatView.swift:163-169`

```swift
if !isShowing {
    let blocker = ScreenTimeAppBlockerService.shared
    if blocker.hasSelectedApps && !blocker.isBlocking {
        blocker.startBlocking()
        let confirmMsg = SimpleChatMessage(content: "Apps bloquées !...", isFromUser: false)
        viewModel.messages.append(confirmMsg)
        viewModel.saveMessages()
    }
}
```

The view creates chat messages, appends them to the ViewModel, and directly accesses `ScreenTimeAppBlockerService.shared`. This belongs in the ViewModel.

---

### 20. Direct singleton access in ViewModels breaks testability

**File:** `Focus/ViewModels/DiscoverMapViewModel.swift:51, 210, 270`

ViewModels directly access `FocusAppStore.shared` instead of receiving it via dependency injection. Unit testing is impossible without modifying global state. Same pattern in `ChatViewModel.swift:246`.

---

### 21. No request cancellation, no retry logic, no auto token refresh in APIClient

**File:** `Focus/Core/APIClient.swift`

- No `request(...)` methods accept or return a cancellation token. In-flight requests continue even after view dismissal.
- No retry logic for transient failures (timeout, 502, 503). Each caller must implement its own.
- On 401 Unauthorized, the client throws without attempting to refresh the Supabase session token. Most callers don't catch 401 specifically.

---

### 22. Force-unwrap on URL construction + unencoded query parameters

**File:** `Focus/Core/APIClient.swift:576`

```swift
URL(string: APIConfiguration.baseURL + path)!
```

Force-unwrap will crash if the composed string is not a valid URL. Several endpoint paths interpolate user-supplied parameters without URL-encoding (area IDs, task IDs at lines 358-360, lat/lon at line 557). A malformed ID or locale-dependent decimal separator could cause a crash.

---

### 23. BackboardService tool call loop -- no overall timeout

**File:** `Focus/Services/BackboardService.swift:275-293`

The tool call loop iterates up to `maxToolCallRounds = 10`, each involving HTTP requests plus tool execution (which may involve additional HTTP requests). Worst case: 10+ sequential network round-trips with a 60-second timeout each. A single `sendMessage` call could block for 10+ minutes with no overall timeout or cancellation.

---

### 24. BackboardService creates a separate URLSession

**File:** `Focus/Services/BackboardService.swift:11-44`

Creates its own `URLSession` (line 38) separate from `APIClient.shared.session`. No shared connection pooling, no shared cookie/cache policy, different timeout configuration (60s vs 30s).

---

### 25. Errors in BackboardService tool execution are silently swallowed

**File:** `Focus/Services/BackboardService.swift:479-482`

When any tool call throws, the error is caught, printed, and returned as a JSON string `{"error": "..."}`. API failures (expired auth, network errors, server 500s) are silently converted to tool output strings. The app has no way to know a critical failure occurred.

---

### 26. SyncManager.executeOperation -- task operations silently do nothing

**File:** `Focus/Core/SyncManager.swift:171-174`

The `case .createTask, .updateTask, .deleteTask:` branch hits `break`, discarding the operation entirely. Any queued task operation will appear to succeed but will not execute.

---

## MEDIUM -- SwiftUI Anti-patterns

### 27. `.onAppear` used where `.task` would be more appropriate for async work

**Files:** `Focus/Views/Chat/ChatView.swift:73-76`, `Focus/Views/FocusRoom/FocusRoomView.swift:60`, `Focus/Views/VoiceCall/VoiceCallView.swift:35`

These views use `.onAppear` to trigger async work. Using `.task` instead would tie the async work to the view lifecycle and automatically cancel it when the view disappears.

---

### 28. Deprecated `onChange(of:)` single-parameter syntax mixed with iOS 17 two-parameter form

**Files:** `Focus/Views/FocusRoom/FocusRoomView.swift:62`, `Focus/Views/VoiceCall/VoiceCallView.swift:37, 335`

These use the old iOS 16 `onChange(of:perform:)` with a single parameter, while other parts of the codebase correctly use the iOS 17 `{ oldValue, newValue in }` form.

---

### 29. Redundant `.environmentObject` injection

**File:** `Focus/Navigation/Navigation.swift:80-81, 87`

`router` is injected twice -- once on `ChatView` and again on the outer `ZStack`. `FocusAppStore.shared` is already injected at the `FocusApp` level and does not need to be re-injected at `MainTabView`.

---

### 30. `print` statement in view body runs on every evaluation

**File:** `Focus/App/FocusApp.swift:51`

```swift
let _ = print("... FocusApp ready state: isAuth=\(store.isAuthenticated)...")
```

String interpolation and I/O on every state change of the root view in production builds.

---

### 31. Hardcoded `Task.sleep(2s)` for location acquisition

**File:** `Focus/ViewModels/DiscoverMapViewModel.swift:64-68`

```swift
locationService.startUpdating()
try? await Task.sleep(nanoseconds: 2_000_000_000)
if let location = locationService.currentLocation { ... }
```

If location arrives in 100ms, user waits 1.9s unnecessarily. If it takes 3s, location is missed entirely. Should use a Combine publisher or async stream with a timeout.

---

### 32. Mixed `.task` and `.onAppear` for initialization in DiscoverMapView

**File:** `Focus/Views/Discover/DiscoverMapView.swift:138-152`

`loadData()` uses `.task`, but `startEncouragementSimulation()` uses `.onAppear`. Both execute simultaneously. The encouragement simulation starts polling before `loadData()` has finished.

---

### 33. Animation value tracks Bool instead of toast value

**File:** `Focus/Views/Discover/DiscoverMapView.swift:137`

```swift
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.incomingToast != nil)
```

Tracks `!= nil` (a `Bool`) rather than the toast value itself. If one toast is replaced by another (both non-nil), SwiftUI sees no change and will not animate.

---

### 34. Nested `DispatchQueue.main.asyncAfter` chains in Cards

**File:** `Focus/DesignSystem/Components/Cards.swift:143-154, 386-405`

Three levels of nested `DispatchQueue.main.asyncAfter` in `SwipeableRitualCard`. These are impossible to cancel if the view disappears mid-animation. Should use `Task.sleep` within a `.task` modifier for cancellability.

---

## MEDIUM -- Memory Leaks and Lifecycle

### 35. AuthService.init -- unstructured Task in init with infinite loop

**File:** `Focus/Services/AuthService.swift:46-54`

The `Task` created in `init()` implicitly captures `self` strongly. `listenToAuthChanges()` at line 62-78 runs an infinite `for await` loop, meaning the Task never completes. The unstructured Task is untracked -- there is no stored reference to cancel it.

---

### 36. SubscriptionManager.listenForTransactions -- Task.detached without [weak self]

**File:** `Focus/Services/SubscriptionManager.swift:243-253`

`Task.detached` uses `self.checkVerified(result)` and `self.updateStatus()` without `[weak self]`. Infinite loop holds `self` alive forever. The `deinit` calls `updateListenerTask?.cancel()`, but it will never execute because the task prevents deallocation.

---

### 37. ScreenTimeAppBlockerService -- uncancellable delayed stopBlocking

**File:** `Focus/Services/ScreenTimeAppBlockerService.swift:175`

`DispatchQueue.main.asyncAfter` block cannot be cancelled. If `stopBlocking()` is called manually before the scheduled time, the delayed block still fires. If a new blocking session starts before the old delayed block fires, it prematurely ends the new session.

---

### 38. LiveKitVoiceService and FocusRoomLiveKitService -- Room delegate strong reference

**Files:** `Focus/Services/LiveKitVoiceService.swift:68`, `Focus/Services/FocusRoomLiveKitService.swift:56`

Both call `room.add(delegate: self)` in `init()`. If LiveKit's `Room` holds a strong reference to delegates, neither service can be deallocated. Neither calls `room.remove(delegate:)` on cleanup.

---

### 39. NWPathMonitor never cancelled

**Files:** `Focus/Core/SyncManager.swift:64-78`, `Focus/Services/MessageQueueService.swift:52-66`

`SyncManager` starts an `NWPathMonitor` but has no cleanup to call `monitor.cancel()`. `MessageQueueService` has a `deinit` with `cancel()`, but since it is a singleton, `deinit` will never run.

---

### 40. NotificationService -- actor-boundary violation in completion handler

**File:** `Focus/Services/NotificationService.swift:299-306, 506-513`

`getPendingNotificationRequests` takes a completion handler that runs on an arbitrary thread. The closure accesses `self` properties and methods. Since the class is `@MainActor`, accessing `self` from a non-MainActor completion handler is a concurrency violation.

---

### 41. NotificationService.settings didSet fires during loadSettings

**File:** `Focus/Services/NotificationService.swift:57-61, 115-119`

The `@Published var settings` has a `didSet` that calls `saveSettings()`. During `init()`, `loadSettings()` sets `self.settings = decoded`, triggering `didSet` which immediately re-writes the same data back to disk. Unnecessary I/O on every launch.

---

## MEDIUM -- Accessibility

### 42. Zero accessibility labels across the entire app

No `accessibilityLabel`, `accessibilityHint`, `accessibilityValue`, or `.accessibility` modifiers found in any file under `Focus/Views/`. VoiceOver users cannot use the app. Affected interactive elements include:

- Chat send button, voice recording button
- All focus room control buttons
- Voice call end/mute buttons
- Map dismiss button
- Settings toggle rows
- All navigation buttons
- Satisfaction gauge (renders score visually with no accessible value)

---

## MEDIUM -- Code Duplication

### 43. Hardcoded background color instead of using `ColorTokens.background`

`ColorTokens.background` is defined as `Color(hex: "#050508")` in `Tokens.swift:10`, but views hardcode the same hex value:

- `FocusRoomView.swift:22` -- `Color(hex: "050508")`
- `VoiceCallView.swift:21` -- `Color(hex: "050508")`
- `DiscoverMapView.swift:18` -- `Color(hex: "#050508")`

---

### 44. Duplicated circular icon button pattern

The same button pattern is repeated across three views:

```swift
Button(action: { ... }) {
    Image(systemName: "...")
        .font(.system(size: 20))
        .foregroundColor(...)
        .frame(width: 64, height: 64)
        .background(Circle().fill(...))
}
```

- `FocusRoomView.swift:152-203` (4 instances)
- `VoiceCallView.swift:241-263` (2 instances)
- `ChatView.swift` (multiple instances)

`DesignSystem/Components/Buttons.swift` already defines an `IconButton` component (line 131) but it uses `Text(icon)` instead of `Image(systemName:)` and is never used.

---

### 45. Duplicated `formatDuration` helpers

Identical duration formatting logic in:

- `VoiceCallView.swift:496-500`
- `FocusRoomViewModel.swift:262-266`
- `ChatView.swift:696` (`formatRecordingTime`)

---

### 46. Duplicated nav bar pattern in onboarding

**File:** `Focus/Views/Onboarding/NewOnboardingView.swift:131-205`

`lightNavBar()` and `blueNavBar()` are nearly identical implementations with only color and skip-action differences. Should be a single parameterized component.

---

### 47. TypographyTokens.FontStyle.font duplicates Font.satoshi() logic

**File:** `Focus/DesignSystem/Tokens.swift`

The `FontStyle.font` computed property (lines 106-129) and the `Font.satoshi()` extension (lines 142-163) contain identical weight-to-font-name mapping logic. One should delegate to the other.

---

## LOW -- Code Quality

### 48. `ProposedGoal.id` -- non-unique Identifiable ID

**File:** `Focus/Services/VoiceService.swift:151`

`var id: String { title + (scheduledStart ?? "") }` -- two proposals with the same title and start time will have identical IDs, breaking SwiftUI `ForEach`.

---

### 49. `apiKey` computed property re-reads plist from disk on every access

**File:** `Focus/Services/BackboardService.swift:15-22`

`apiKey` reads from `Bundle.main.path(forResource:)` and `NSDictionary(contentsOfFile:)` on every access. During `sendMessage`, this is accessed multiple times. Should be a stored `lazy` property.

---

### 50. EmptyResponse force cast

**File:** `Focus/Core/APIClient.swift:914`

`return EmptyResponse() as! T` -- if `T` is not `EmptyResponse` but the response body happens to be empty, this will crash.

---

### 51. BackboardService memory migration -- no rate limiting, partial migration not tracked

**File:** `Focus/Services/BackboardService.swift:1103-1149`

Iterates all facts/persons from UserDefaults and calls `addMemory()` for each one sequentially. No batching, rate limiting, or cancellation. The migration flag is only set on the "no old data" path, not on successful completion -- partial migration will be re-attempted on every launch.

---

### 52. Modulo bias in nonce generation

**File:** `Focus/Services/AuthService.swift:298-312`

`charset[Int(byte) % charset.count]` introduces modulo bias because 256 is not evenly divisible by 63 (charset length). Minor security impact for an OAuth nonce, but a best-practice violation.

---

### 53. `FocusRoomViewModel` properties have unnecessary internal access

**File:** `Focus/ViewModels/FocusRoomViewModel.swift:50, 55`

`liveKitService` and `category` are `internal` but are only used inside the ViewModel. Should be `private`.

---

### 54. Redundant `MainActor.run` inside already `@MainActor`-isolated class

**File:** `Focus/Services/NotificationService.swift:85-87, 102-104`

The class is `@MainActor`, so explicit `await MainActor.run { ... }` calls are unnecessary overhead.

---

### 55. `@StateObject` used for singletons in CalendarProvidersSettingsView

**File:** `Focus/Views/Settings/CalendarProvidersSettingsView.swift:7-8`

Same issue as #7. Singletons should not be wrapped in `@StateObject`.

---

## Recommended Priority Order

### Immediate (crashes and silent bugs)

1. LocationService double continuation resume (#1)
2. Force-unwrap URL construction (#22)
3. Broken alert binding (#2)
4. Inverted throttle logic (#5)
5. Race conditions in queue processing (#6)
6. Unimplemented sync operations (#26)

### Short-term (performance and architecture)

7. Break up ChatView and SettingsView into smaller components (#8, #9)
8. Extract business logic from views into ViewModels (#18, #19)
9. Add request cancellation and retry logic to APIClient (#21)
10. Reduce recording timer frequency or isolate waveform rendering (#10)
11. Add diffing to syncParticipants (#14)

### Medium-term (quality and compliance)

12. Add accessibility labels throughout the app (#42)
13. Decompose FocusAppStore into focused domain stores (#17)
14. Adopt dependency injection for testability (#20)
15. Consolidate duplicated code (#43-47)
16. Fix property wrapper usage for singletons (#3, #7, #55)
