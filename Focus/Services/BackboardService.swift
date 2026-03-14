import Foundation

// MARK: - Backboard Service

/// Service for communicating with the Backboard API (Assistants + Threads + Memory + Tool Calls)
@MainActor
class BackboardService {
    static let shared = BackboardService()

    private let baseURL = "https://app.backboard.io/api"
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let key = dict["BACKBOARD_API_KEY"] as? String else {
            return ""
        }
        return key
    }

    /// Per-user assistant ID (from user profile, NOT shared)
    private var assistantId: String {
        FocusAppStore.shared.user?.backboardAssistantId ?? ""
    }

    /// Public accessor for voice agent metadata
    var currentAssistantId: String { assistantId }

    // Thread ID persisted per user
    private let threadIdKey = "backboard_thread_id"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60 // Backboard may take longer due to LLM + tool calls
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Assistant Management (per-user isolation)

    /// Ensure the current user has a Backboard assistant. Creates one if needed.
    func ensureAssistant() async throws {
        guard assistantId.isEmpty else { return }

        let harshMode = FocusAppStore.shared.user?.coachHarshMode ?? false
        let assistantConfig = Self.assistantTemplate(coachHarshMode: harshMode)
        let url = URL(string: "\(baseURL)/assistants")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: assistantConfig)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, allowedStatuses: [200, 201])

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newId = json["assistant_id"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        // Save to Supabase user profile via PATCH /me
        try await APIClient.shared.request(
            endpoint: .me,
            method: .patch,
            body: RawJSON(data: try JSONSerialization.data(withJSONObject: [
                "backboard_assistant_id": newId
            ]))
        )

        // Update local user model
        FocusAppStore.shared.user?.backboardAssistantId = newId
        print("🤖 Created per-user Backboard assistant: \(newId)")
    }

    /// Force-recreate the assistant (e.g. after companion name change) so a fresh system prompt is used.
    /// Migrates all memories from the old assistant to the new one.
    func recreateAssistant() async {
        // 1. Save memories from old assistant before destroying it
        let oldMemories: [BackboardMemory]
        if !assistantId.isEmpty {
            oldMemories = (try? await listMemories()) ?? []
            print("🧠 Saved \(oldMemories.count) memories from old assistant")
        } else {
            oldMemories = []
        }

        // 2. Clear local assistant ID so ensureAssistant() creates a new one
        FocusAppStore.shared.user?.backboardAssistantId = nil

        // 3. Delete old thread – the new assistant will get a fresh conversation
        await deleteThread()

        do {
            // 4. Create new assistant
            try await ensureAssistant()
            print("🔄 Backboard assistant recreated with updated prompt")

            // 5. Migrate memories to the new assistant
            if !oldMemories.isEmpty {
                var migrated = 0
                for memory in oldMemories {
                    do {
                        try await addMemory(content: memory.content)
                        migrated += 1
                    } catch {
                        print("⚠️ Failed to migrate memory: \(error)")
                    }
                }
                print("🧠 Migrated \(migrated)/\(oldMemories.count) memories to new assistant")
            }
        } catch {
            print("⚠️ Failed to recreate assistant: \(error)")
        }
    }

    // MARK: - Thread Management

    /// Get existing thread ID or create a new one
    func getOrCreateThread() async throws -> String {
        if let threadId = UserDefaults.standard.string(forKey: threadIdKey), !threadId.isEmpty {
            return threadId
        }
        return try await createNewThread()
    }

    /// Create a new thread and persist the ID
    @discardableResult
    func createNewThread() async throws -> String {
        let url = URL(string: "\(baseURL)/assistants/\(assistantId)/threads")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let thread = try decoder.decode(BackboardThread.self, from: data)
        UserDefaults.standard.set(thread.threadId, forKey: threadIdKey)
        print("🧵 Created new Backboard thread: \(thread.threadId)")
        return thread.threadId
    }

    /// Delete current thread and clear the stored ID
    func deleteThread() async {
        guard let threadId = UserDefaults.standard.string(forKey: threadIdKey) else { return }

        let url = URL(string: "\(baseURL)/threads/\(threadId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("🗑️ Deleted Backboard thread: \(httpResponse.statusCode)")
            }
        } catch {
            print("⚠️ Failed to delete thread: \(error)")
        }

        UserDefaults.standard.removeObject(forKey: threadIdKey)
    }

    // MARK: - Send Message (Main Entry Point)

    /// Send a message to Backboard and handle the full tool call loop.
    /// Returns the final AI response content plus any side effects to apply.
    func sendMessage(_ text: String) async throws -> (content: String, sideEffects: [BackboardSideEffect]) {
        try await ensureAssistant()
        let threadId = try await getOrCreateThread()

        // Send message with memory enabled
        var response = try await addMessage(threadId: threadId, content: text)

        var allSideEffects: [BackboardSideEffect] = []
        let maxToolCallRounds = 10

        // Tool call loop: keep going while REQUIRES_ACTION (with safety limit)
        var round = 0
        while response.status == "REQUIRES_ACTION", let toolCalls = response.toolCalls, !toolCalls.isEmpty, round < maxToolCallRounds {
            round += 1
            guard let runId = response.runId else { break }

            var outputs: [BackboardToolOutput] = []

            for toolCall in toolCalls {
                let (output, effects) = await executeToolCall(toolCall)
                outputs.append(BackboardToolOutput(toolCallId: toolCall.id, output: output))
                allSideEffects.append(contentsOf: effects)
            }

            // Submit tool outputs and get next response
            response = try await submitToolOutputs(threadId: threadId, runId: runId, outputs: outputs)
        }

        let content = response.content ?? "..."
        return (content, allSideEffects)
    }

    // MARK: - API Calls

    /// Add a message to a thread
    private func addMessage(threadId: String, content: String) async throws -> BackboardMessageResponse {
        let url = URL(string: "\(baseURL)/threads/\(threadId)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "content": content,
            "stream": false,
            "memory": "Readonly"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        return try decoder.decode(BackboardMessageResponse.self, from: data)
    }

    /// Submit tool outputs for a run
    private func submitToolOutputs(threadId: String, runId: String, outputs: [BackboardToolOutput]) async throws -> BackboardMessageResponse {
        let url = URL(string: "\(baseURL)/threads/\(threadId)/runs/\(runId)/submit-tool-outputs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = BackboardSubmitToolOutputsRequest(toolOutputs: outputs)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        return try decoder.decode(BackboardMessageResponse.self, from: data)
    }

    // MARK: - Tool Call Execution

    /// Execute a single tool call and return (output JSON string, side effects)
    private func executeToolCall(_ toolCall: BackboardToolCall) async -> (String, [BackboardSideEffect]) {
        let name = toolCall.function.name
        let argsString = toolCall.function.arguments
        let args = parseArguments(argsString)

        print("🔧 Executing tool: \(name) with args: \(argsString.prefix(200))")

        do {
            switch name {
            case "get_user_context":
                return (getUserContext(), [])

            case "get_today_tasks":
                let result = try await getTodayTasks()
                return (result, [])

            case "get_rituals":
                let result = try await getRituals()
                return (result, [])

            case "create_task":
                let result = try await createTask(args: args)
                return (result, [.refreshTasks, .calendarNeedsRefresh, .showCard("tasks")])

            case "complete_task":
                let taskId = args["task_id"] as? String ?? ""
                let result = try await completeTask(taskId: taskId)
                return (result, [.refreshTasks, .calendarNeedsRefresh])

            case "uncomplete_task":
                let taskId = args["task_id"] as? String ?? ""
                let result = try await uncompleteTask(taskId: taskId)
                return (result, [.refreshTasks, .calendarNeedsRefresh])

            case "create_routine":
                let result = try await createRoutine(args: args)
                return (result, [.refreshRituals, .showCard("routines")])

            case "complete_routine":
                let routineId = args["routine_id"] as? String ?? ""
                let result = try await completeRoutine(routineId: routineId)
                return (result, [.refreshRituals])

            case "update_task":
                let result = try await updateTask(args: args)
                return (result, [.refreshTasks, .calendarNeedsRefresh])

            case "delete_task":
                let taskId = args["task_id"] as? String ?? ""
                let result = try await deleteTask(taskId: taskId)
                return (result, [.refreshTasks, .calendarNeedsRefresh])

            case "delete_routine":
                let routineId = args["routine_id"] as? String ?? ""
                let result = try await deleteRoutine(routineId: routineId)
                return (result, [.refreshRituals])

            case "start_focus_session":
                let duration = args["duration_minutes"] as? Int
                let taskId = args["task_id"] as? String
                let taskTitle = args["task_title"] as? String
                return (toJSON(["started": true, "duration_minutes": duration ?? 25] as [String: Any]), [.startFocusSession(duration: duration, taskId: taskId, taskTitle: taskTitle)])

            case "block_apps":
                let duration = args["duration_minutes"] as? Int
                return (blockApps(duration: duration), [.blockApps(duration)])

            case "unblock_apps":
                return (unblockApps(), [.unblockApps])

            case "show_force_unblock_card":
                return (toJSON(["card_shown": true] as [String: Any]), [.showForceUnblockCard])

            case "save_morning_checkin":
                let result = try await saveMorningCheckin(args: args)
                return (result, [.refreshReflection])

            case "save_evening_review":
                let result = try await saveEveningReview(args: args)
                return (result, [.refreshReflection])

            case "create_weekly_goals":
                let result = try await createWeeklyGoals(args: args)
                return (result, [.refreshWeeklyGoals])

            case "show_card":
                let cardType = args["card_type"] as? String ?? "tasks"
                return (toJSON(["shown": true] as [String: Any]), [.showCard(cardType)])

            case "save_favorite_video":
                let result = await saveFavoriteVideo(args: args)
                return (result, [])

            case "get_favorite_video":
                return getFavoriteVideo()

            case "suggest_ritual_videos":
                let category = args["category"] as? String ?? "meditation"
                return suggestRitualVideos(category: category)

            case "set_morning_block":
                let enabled = args["enabled"] as? Bool ?? true
                let startHour = args["start_hour"] as? Int ?? 6
                let startMinute = args["start_minute"] as? Int ?? 0
                let endHour = args["end_hour"] as? Int ?? 9
                let endMinute = args["end_minute"] as? Int ?? 0
                return (configureMorningBlock(enabled: enabled, startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute), [.refreshSettings])

            case "get_morning_block_status":
                return (getMorningBlockStatus(), [])

            case "start_morning_flow":
                let result = try await getMorningFlowContext()
                return (result, [.refreshTasks, .refreshRituals])

            case "get_calendar_events":
                let date = args["date"] as? String
                let result = try await getCalendarEvents(date: date)
                return (result, [.refreshCalendarEvents])

            case "schedule_calendar_blocking":
                let eventIds = args["event_ids"] as? [String] ?? []
                let enabled = args["enabled"] as? Bool ?? true
                let result = try await scheduleCalendarBlocking(eventIds: eventIds, enabled: enabled)
                return (result, [.refreshCalendarEvents])

            case "save_memory":
                let content = args["content"] as? String ?? ""
                let category = args["category"] as? String ?? "fact"
                let memoryText = "[\(category)] \(content)"
                try await addMemory(content: memoryText)
                return (toJSON(["saved": true, "category": category] as [String: Any]), [])

            default:
                print("⚠️ Unknown tool: \(name)")
                return (toJSON(["error": "Unknown tool: \(name)"] as [String: Any]), [])
            }
        } catch {
            print("❌ Tool execution error (\(name)): \(error)")
            return (toJSON(["error": error.localizedDescription] as [String: Any]), [])
        }
    }

    // MARK: - Tool Implementations

    private func getUserContext() -> String {
        let store = FocusAppStore.shared
        let tasksTotal = store.todaysTasks.count
        let tasksCompleted = store.todaysTasks.filter { $0.status == "completed" }.count
        let ritualsTotal = store.rituals.count
        let ritualsCompleted = store.rituals.filter { $0.isCompleted }.count
        let focusMinutes = store.todaysSessions.reduce(0) { $0 + $1.durationMinutes }
        let userName = store.user?.pseudo ?? store.user?.firstName ?? ""
        let isBlocking = ScreenTimeAppBlockerService.shared.isBlocking

        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<18: timeOfDay = "afternoon"
        case 18..<22: timeOfDay = "evening"
        default: timeOfDay = "night"
        }

        // Satisfaction score (displayed in UI as coach gauge)
        let satisfactionScore = UserDefaults.standard.object(forKey: "satisfaction_score") as? Int ?? 50

        // Companion identity
        let companionName = store.user?.companionName ?? "Kai"

        // Check-in status
        let morningCheckinDone = store.hasDoneMorningCheckIn
        let eveningReviewDone = store.hasDoneEveningReview

        // Days since last chat message
        let lastMessages = SimpleChatPersistence.loadMessages()
        let daysSinceLastMessage: Int
        if let lastMsg = lastMessages.last {
            daysSinceLastMessage = Calendar.current.dateComponents([.day], from: lastMsg.timestamp, to: Date()).day ?? 0
        } else {
            daysSinceLastMessage = -1 // No message history = new user
        }

        // Account age
        let accountAgeDays: Int
        if let createdAt = store.user?.createdAt {
            accountAgeDays = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        } else {
            accountAgeDays = 0
        }

        // Weekly goals
        var weeklyGoalsList: [[String: Any]] = []
        if let goals = store.currentWeekGoals {
            weeklyGoalsList = goals.items.map { item in
                ["title": item.content, "completed": item.isCompleted] as [String: Any]
            }
        }

        // All completed flags (for "perfect day" detection)
        let allTasksCompleted = tasksTotal > 0 && tasksCompleted == tasksTotal
        let allRitualsCompleted = ritualsTotal > 0 && ritualsCompleted == ritualsTotal

        // User language preference
        let userLanguage = store.user?.language ?? "fr"

        var context: [String: Any] = [
            "user_name": userName,
            "companion_name": companionName,
            "tasks_today": tasksTotal,
            "tasks_completed": tasksCompleted,
            "rituals_today": ritualsTotal,
            "rituals_completed": ritualsCompleted,
            "focus_minutes_today": focusMinutes,
            "time_of_day": timeOfDay,
            "apps_blocked": isBlocking,
            "satisfaction_score": satisfactionScore,
            "morning_checkin_done": morningCheckinDone,
            "evening_review_done": eveningReviewDone,
            "days_since_last_message": daysSinceLastMessage,
            "account_age_days": accountAgeDays,
            "all_tasks_completed": allTasksCompleted,
            "all_rituals_completed": allRitualsCompleted,
            "user_language": userLanguage,
            "morning_block_enabled": MorningBlockService.shared.isEnabled,
            "morning_block_start": "\(MorningBlockService.shared.startHour):\(String(format: "%02d", MorningBlockService.shared.startMinute))",
            "morning_block_end": "\(MorningBlockService.shared.endHour):\(String(format: "%02d", MorningBlockService.shared.endMinute))"
        ]
        if !weeklyGoalsList.isEmpty {
            context["weekly_goals"] = weeklyGoalsList
        }
        return toJSON(context)
    }

    private func getTodayTasks() async throws -> String {
        await FocusAppStore.shared.refreshTodaysTasks()
        let tasks = FocusAppStore.shared.todaysTasks.map { task in
            [
                "id": task.id,
                "title": task.title,
                "status": task.status ?? "pending",
                "time_block": task.timeBlock ?? "",
                "priority": task.priority ?? ""
            ] as [String: Any]
        }
        return toJSON(["tasks": tasks])
    }

    private func getRituals() async throws -> String {
        await FocusAppStore.shared.loadRituals()
        let rituals = FocusAppStore.shared.rituals.map { ritual in
            [
                "id": ritual.id,
                "title": ritual.title,
                "icon": ritual.icon,
                "is_completed": ritual.isCompleted
            ] as [String: Any]
        }
        return toJSON(["rituals": rituals])
    }

    private func createTask(args: [String: Any]) async throws -> String {
        let apiClient = APIClient.shared
        let title = args["title"] as? String ?? "Nouvelle tâche"
        let dateStr = args["date"] as? String ?? todayString()
        let priority = args["priority"] as? String
        let timeBlock = args["time_block"] as? String

        var body: [String: Any] = [
            "title": title,
            "date": dateStr
        ]
        if let priority { body["priority"] = priority }
        if let timeBlock { body["time_block"] = timeBlock }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _: EmptyResponse = try await apiClient.request(
            endpoint: .createCalendarTask,
            method: .post,
            body: RawJSON(data: bodyData)
        )
        return toJSON(["created": true, "title": title] as [String: Any])
    }

    private func completeTask(taskId: String) async throws -> String {
        try await APIClient.shared.request(
            endpoint: .completeCalendarTask(taskId),
            method: .post
        )
        return toJSON(["completed": true, "task_id": taskId] as [String: Any])
    }

    private func uncompleteTask(taskId: String) async throws -> String {
        try await APIClient.shared.request(
            endpoint: .uncompleteCalendarTask(taskId),
            method: .post
        )
        return toJSON(["uncompleted": true, "task_id": taskId] as [String: Any])
    }

    private func createRoutine(args: [String: Any]) async throws -> String {
        let title = args["title"] as? String ?? "Nouveau rituel"
        let icon = args["icon"] as? String ?? "star"
        let frequency = args["frequency"] as? String ?? "daily"
        let scheduledTime = args["scheduled_time"] as? String

        var body: [String: Any] = [
            "title": title,
            "icon": icon,
            "frequency": frequency
        ]
        if let scheduledTime { body["scheduled_time"] = scheduledTime }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: .createRoutine,
            method: .post,
            body: RawJSON(data: bodyData)
        )
        return toJSON(["created": true, "title": title] as [String: Any])
    }

    private func completeRoutine(routineId: String) async throws -> String {
        try await APIClient.shared.request(
            endpoint: .completeRoutine(routineId),
            method: .post
        )
        return toJSON(["completed": true, "routine_id": routineId] as [String: Any])
    }

    private func updateTask(args: [String: Any]) async throws -> String {
        let taskId = args["task_id"] as? String ?? ""
        var body: [String: Any] = [:]
        if let title = args["title"] as? String { body["title"] = title }
        if let date = args["date"] as? String { body["date"] = date }
        if let priority = args["priority"] as? String { body["priority"] = priority }
        if let timeBlock = args["time_block"] as? String { body["time_block"] = timeBlock }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: .updateCalendarTask(taskId),
            method: .patch,
            body: RawJSON(data: bodyData)
        )
        return toJSON(["updated": true, "task_id": taskId] as [String: Any])
    }

    private func deleteTask(taskId: String) async throws -> String {
        try await APIClient.shared.request(
            endpoint: .deleteCalendarTask(taskId),
            method: .delete
        )
        return toJSON(["deleted": true, "task_id": taskId] as [String: Any])
    }

    private func deleteRoutine(routineId: String) async throws -> String {
        try await APIClient.shared.request(
            endpoint: .deleteRoutine(routineId),
            method: .delete
        )
        return toJSON(["deleted": true, "routine_id": routineId] as [String: Any])
    }

    private func blockApps(duration: Int?) -> String {
        let blocker = ScreenTimeAppBlockerService.shared
        if blocker.isBlockingEnabled {
            blocker.startBlocking(durationMinutes: duration)
            return toJSON(["blocked": true, "duration_minutes": duration ?? 0] as [String: Any])
        }
        return toJSON(["blocked": false, "reason": "App blocking not configured"] as [String: Any])
    }

    private func unblockApps() -> String {
        let blocker = ScreenTimeAppBlockerService.shared
        if blocker.isBlocking {
            blocker.stopBlocking()
            return toJSON(["unblocked": true] as [String: Any])
        }
        return toJSON(["unblocked": false, "reason": "Apps were not blocked"] as [String: Any])
    }

    private func saveMorningCheckin(args: [String: Any]) async throws -> String {
        let mood = args["mood"] as? Int ?? 3
        let sleepQuality = args["sleep_quality"] as? Int
        let intentions = args["intentions"] as? String

        var body: [String: Any] = [
            "mood_score": mood
        ]
        if let sleepQuality { body["sleep_quality"] = sleepQuality }
        if let intentions { body["intentions"] = intentions }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: .upsertReflection(date: todayString()),
            method: .put,
            body: RawJSON(data: bodyData)
        )
        return toJSON(["saved": true, "type": "morning_checkin"] as [String: Any])
    }

    private func saveEveningReview(args: [String: Any]) async throws -> String {
        let biggestWin = args["biggest_win"] as? String
        let blockers = args["blockers"] as? String
        let tomorrowGoal = args["tomorrow_goal"] as? String

        var body: [String: Any] = [:]
        if let biggestWin { body["biggest_win"] = biggestWin }
        if let blockers { body["blockers"] = blockers }
        if let tomorrowGoal { body["tomorrow_goal"] = tomorrowGoal }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: .upsertReflection(date: todayString()),
            method: .put,
            body: RawJSON(data: bodyData)
        )
        return toJSON(["saved": true, "type": "evening_review"] as [String: Any])
    }

    private func createWeeklyGoals(args: [String: Any]) async throws -> String {
        let goals = args["goals"] as? [String] ?? []

        // Calculate current week start
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysToMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysToMonday, to: today)!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let weekStartDate = formatter.string(from: monday)

        let items = goals.map { ["title": $0] }
        let body: [String: Any] = ["items": items]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: .upsertWeeklyGoals(weekStartDate: weekStartDate),
            method: .put,
            body: RawJSON(data: bodyData)
        )
        return toJSON(["created": true, "count": goals.count] as [String: Any])
    }

    // MARK: - Morning Block

    private func configureMorningBlock(enabled: Bool, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) -> String {
        MorningBlockService.shared.configure(
            enabled: enabled,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )
        return toJSON([
            "configured": true,
            "enabled": enabled,
            "start": "\(startHour):\(String(format: "%02d", startMinute))",
            "end": "\(endHour):\(String(format: "%02d", endMinute))"
        ] as [String: Any])
    }

    private func getMorningBlockStatus() -> String {
        let service = MorningBlockService.shared
        return toJSON([
            "enabled": service.isEnabled,
            "start_hour": service.startHour,
            "start_minute": service.startMinute,
            "end_hour": service.endHour,
            "end_minute": service.endMinute
        ] as [String: Any])
    }

    // MARK: - Calendar Events Tools

    private func getCalendarEvents(date: String?) async throws -> String {
        let dateStr = date ?? todayString()
        let response: CalendarEventsResponse = try await APIClient.shared.request(
            endpoint: .calendarEvents(date: dateStr),
            method: .get
        )

        let events = response.events.map { event in
            [
                "id": event.id,
                "title": event.title,
                "start_time": event.startAt,
                "end_time": event.endAt,
                "source": event.providerType,
                "is_blocking_enabled": event.blockApps,
                "is_all_day": event.isAllDay,
                "event_type": event.eventType
            ] as [String: Any]
        }

        return toJSON(["events": events, "count": response.count] as [String: Any])
    }

    private func scheduleCalendarBlocking(eventIds: [String], enabled: Bool) async throws -> String {
        let manager = CalendarProviderManager.shared
        var scheduledCount = 0

        for eventId in eventIds {
            let success = await manager.toggleBlocking(eventId: eventId, enabled: enabled, source: "ai")
            if success { scheduledCount += 1 }
        }

        // Re-schedule blocking notifications
        let blockingEvents = manager.todayEvents.filter { $0.blockApps }
        await CalendarEventBlockingService.shared.scheduleBlockingForEvents(blockingEvents)

        return toJSON([
            "scheduled": true,
            "event_count": scheduledCount,
            "blocking_enabled": enabled
        ] as [String: Any])
    }

    // MARK: - Morning Flow Context

    private func getMorningFlowContext() async throws -> String {
        let store = FocusAppStore.shared

        // Refresh data
        await store.refreshTodaysTasks()
        await store.loadRituals()

        let userName = store.user?.pseudo ?? store.user?.firstName ?? ""
        let companionName = store.user?.companionName ?? "Kai"
        let userLanguage = store.user?.language ?? "fr"
        let morningCheckinDone = store.hasDoneMorningCheckIn
        let satisfactionScore = UserDefaults.standard.object(forKey: "satisfaction_score") as? Int ?? 50
        let currentStreak = store.currentStreak
        let focusMinutes = store.todaysSessions.reduce(0) { $0 + $1.durationMinutes }
        let isBlocking = ScreenTimeAppBlockerService.shared.isBlocking
        let appBlockingAvailable = ScreenTimeAppBlockerService.shared.isBlockingEnabled

        // Days since last chat message
        let lastMessages = SimpleChatPersistence.loadMessages()
        let daysSinceLastMessage: Int
        if let lastMsg = lastMessages.last {
            daysSinceLastMessage = Calendar.current.dateComponents([.day], from: lastMsg.timestamp, to: Date()).day ?? 0
        } else {
            daysSinceLastMessage = -1
        }

        // Morning block status
        let morningBlockService = MorningBlockService.shared
        let morningBlock: [String: Any] = [
            "enabled": morningBlockService.isEnabled,
            "start_hour": morningBlockService.startHour,
            "start_minute": morningBlockService.startMinute,
            "end_hour": morningBlockService.endHour,
            "end_minute": morningBlockService.endMinute
        ]

        // Tasks
        let tasks = store.todaysTasks.map { task in
            [
                "id": task.id,
                "title": task.title,
                "status": task.status ?? "pending",
                "time_block": task.timeBlock ?? "",
                "priority": task.priority ?? ""
            ] as [String: Any]
        }
        let pendingTaskCount = store.todaysTasks.filter { $0.status != "completed" }.count

        // Rituals
        let rituals = store.rituals.map { ritual in
            [
                "id": ritual.id,
                "title": ritual.title,
                "icon": ritual.icon,
                "is_completed": ritual.isCompleted
            ] as [String: Any]
        }
        let pendingRitualCount = store.rituals.filter { !$0.isCompleted }.count

        // Weekly goals
        var weeklyGoals: [[String: Any]] = []
        if let goals = store.currentWeekGoals {
            weeklyGoals = goals.items.map { item in
                ["title": item.content, "completed": item.isCompleted] as [String: Any]
            }
        }

        // Calendar events (external: Google Calendar, etc.)
        let calendarManager = CalendarProviderManager.shared
        await calendarManager.refreshIfNeeded()
        let hasCalendarConnected = calendarManager.hasCalendarConnected
        let calendarEvents = calendarManager.todayEvents.map { event in
            [
                "id": event.id,
                "title": event.title,
                "start_time": event.startAt,
                "end_time": event.endAt,
                "is_all_day": event.isAllDay,
                "event_type": event.eventType,
                "is_blocking_enabled": event.blockApps,
                "source": event.providerType
            ] as [String: Any]
        }

        var context: [String: Any] = [
            "user_name": userName,
            "companion_name": companionName,
            "user_language": userLanguage,
            "morning_checkin_done": morningCheckinDone,
            "satisfaction_score": satisfactionScore,
            "current_streak": currentStreak,
            "focus_minutes_today": focusMinutes,
            "days_since_last_message": daysSinceLastMessage,
            "apps_blocked": isBlocking,
            "app_blocking_available": appBlockingAvailable,
            "morning_block": morningBlock,
            "tasks": tasks,
            "pending_task_count": pendingTaskCount,
            "rituals": rituals,
            "pending_ritual_count": pendingRitualCount,
            "has_calendar_connected": hasCalendarConnected,
            "calendar_events": calendarEvents,
            "calendar_events_count": calendarEvents.count
        ]
        if !weeklyGoals.isEmpty {
            context["weekly_goals"] = weeklyGoals
        }
        return toJSON(context)
    }

    // MARK: - Curated Video Catalogue

    struct CuratedVideo {
        let videoId: String
        let title: String
        let duration: String
        let category: String
    }

    static let curatedVideos: [String: [CuratedVideo]] = [
        "meditation": [
            CuratedVideo(videoId: "VJcPtspJP0g", title: "Wim Hof Breathing Method", duration: "11 min", category: "meditation"),
            CuratedVideo(videoId: "inpok4MKVLM", title: "Méditation guidée 10 min", duration: "10 min", category: "meditation"),
            CuratedVideo(videoId: "O-6f5wQXSu8", title: "Body Scan Relaxation", duration: "15 min", category: "meditation"),
        ],
        "breathing": [
            CuratedVideo(videoId: "uxayUBd6T7M", title: "Calm Breathe Bubble", duration: "5 min", category: "breathing"),
            CuratedVideo(videoId: "YRPh_GaiL8s", title: "Respiration 4-7-8", duration: "5 min", category: "breathing"),
            CuratedVideo(videoId: "tybOi4hjZFQ", title: "Breathwork guidé", duration: "10 min", category: "breathing"),
        ],
        "motivation": [
            CuratedVideo(videoId: "mgmVOuLgFB0", title: "Discours motivant matin", duration: "8 min", category: "motivation"),
            CuratedVideo(videoId: "26U_seo0a1g", title: "Morning Routine Inspiration", duration: "6 min", category: "motivation"),
        ],
        "prayer": [
            CuratedVideo(videoId: "j734gLbQFbU", title: "Méditation du matin guidée", duration: "5 min", category: "prayer"),
            CuratedVideo(videoId: "cyMxWXlX9sU", title: "Méditation énergie positive", duration: "10 min", category: "prayer"),
        ]
    ]

    private func suggestRitualVideos(category: String) -> (String, [BackboardSideEffect]) {
        let videos = Self.curatedVideos[category] ?? Self.curatedVideos["meditation"]!
        let list = videos.map { video -> [String: Any] in
            [
                "video_id": video.videoId,
                "title": video.title,
                "duration": video.duration
            ]
        }
        return (toJSON(["videos": list, "category": category] as [String: Any]),
                [.showVideoSuggestions(category: category)])
    }

    // MARK: - Favorite Video

    private func saveFavoriteVideo(args: [String: Any]) async -> String {
        let url = args["url"] as? String ?? ""
        let title = args["title"] as? String ?? "Ma vidéo"

        UserDefaults.standard.set(url, forKey: "favorite_video_url")
        UserDefaults.standard.set(title, forKey: "favorite_video_title")

        // Update in-memory user model
        FocusAppStore.shared.user?.favoriteVideoUrl = url
        FocusAppStore.shared.user?.favoriteVideoTitle = title

        // Save to Backboard memory for AI recall
        try? await addMemory(content: "Vidéo favorite de l'utilisateur pour rituel quotidien: \(title) - \(url)")

        return toJSON(["saved": true, "url": url, "title": title] as [String: Any])
    }

    private func getFavoriteVideo() -> (String, [BackboardSideEffect]) {
        let url = UserDefaults.standard.string(forKey: "favorite_video_url")
        let title = UserDefaults.standard.string(forKey: "favorite_video_title") ?? "Ma vidéo"

        if let url, !url.isEmpty {
            return (toJSON(["url": url, "title": title] as [String: Any]), [.showVideo(url: url, title: title)])
        }

        // No favorite video — auto-show suggestions card
        let hour = Calendar.current.component(.hour, from: Date())
        let category: String
        switch hour {
        case 5..<12: category = "meditation"
        case 18..<24: category = "motivation"
        default: category = "breathing"
        }
        return (toJSON(["has_video": false, "suggested_category": category] as [String: Any]),
                [.showVideoSuggestions(category: category)])
    }

    // MARK: - Memory Management

    /// List all memories for the current assistant
    func listMemories() async throws -> [BackboardMemory] {
        let url = URL(string: "\(baseURL)/assistants/\(assistantId)/memories")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let result = try decoder.decode(BackboardMemoriesListResponse.self, from: data)
        return result.memories
    }

    /// Add a memory manually
    func addMemory(content: String) async throws {
        let url = URL(string: "\(baseURL)/assistants/\(assistantId)/memories")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = BackboardMemoryCreate(content: content, metadata: nil)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, allowedStatuses: [200, 201])
        print("🧠 Added memory: \(content.prefix(50))")
    }

    /// Delete a memory by ID
    func deleteMemory(id: String) async throws {
        let url = URL(string: "\(baseURL)/assistants/\(assistantId)/memories/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        print("🧠 Deleted memory: \(id)")
    }

    // MARK: - Knowledge Migration

    /// Migrate local knowledge data (UserDefaults) to Backboard Memory (one-time).
    /// Self-contained: reads raw JSON from UserDefaults without depending on KnowledgeManager.
    func migrateKnowledgeIfNeeded() async {
        let migrationKey = "backboard_knowledge_migrated"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        // Ensure we have an assistant before migrating memories
        do { try await ensureAssistant() } catch { return }

        // Read raw knowledge data from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "ai_knowledge_data"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // No old data to migrate
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // Migrate user profile
        if let profile = json["userProfile"] as? [String: Any] {
            if let name = profile["name"] as? String, !name.isEmpty {
                try? await addMemory(content: "L'utilisateur s'appelle \(name)")
            }
            if let pronouns = profile["pronouns"] as? String, !pronouns.isEmpty {
                try? await addMemory(content: "Pronoms de l'utilisateur: \(pronouns)")
            }
            if let facts = profile["facts"] as? [[String: Any]] {
                for fact in facts {
                    if let content = fact["content"] as? String {
                        try? await addMemory(content: "Fait sur l'utilisateur: \(content)")
                    }
                }
            }
        }

        // Migrate persons
        if let persons = json["persons"] as? [[String: Any]] {
            for person in persons {
                let name = person["name"] as? String ?? ""
                let category = person["category"] as? String ?? ""
                let relation = person["relation"] as? String ?? category
                if !name.isEmpty {
                    try? await addMemory(content: "Personne: \(name), \(category), \(relation)")
                }
                if let facts = person["facts"] as? [[String: Any]] {
                    for fact in facts {
                        if let content = fact["content"] as? String {
                            try? await addMemory(content: "À propos de \(name): \(content)")
                        }
                    }
                }
            }
        }

        // Migrate life domains
        if let domains = json["lifeDomains"] as? [[String: Any]] {
            for domain in domains {
                let domainName = domain["name"] as? String ?? ""
                if let facts = domain["facts"] as? [[String: Any]] {
                    for fact in facts {
                        if let content = fact["content"] as? String {
                            try? await addMemory(content: "Domaine \(domainName): \(content)")
                        }
                    }
                }
            }
        }

        // Clean up old data after migration
        UserDefaults.standard.removeObject(forKey: "ai_knowledge_data")
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ Knowledge migration to Backboard Memory completed")
    }

    // MARK: - Assistant Template

    /// Template config for creating per-user assistants (system prompt + tools)
    static func assistantTemplate(coachHarshMode: Bool = false) -> [String: Any] {
        var systemPrompt = """
        Tu es le coach de vie personnel de l'utilisateur. Ton nom est dans get_user_context → companion_name. Le prénom de l'UTILISATEUR est dans get_user_context → user_name. Quand tu salues, utilise le prénom de l'utilisateur (user_name), PAS ton propre nom.

        ═══════════════════════════════════════
        QUI TU ES
        ═══════════════════════════════════════

        Tu es un coach de vie — pas un assistant, pas un chatbot. La différence :
        - Un assistant exécute. Tu comprends POURQUOI avant d'agir.
        - Un chatbot répond. Tu creuses, tu challenges, tu pousses à réfléchir.
        - Un assistant dit "C'est fait !". Tu dis "C'est fait — et qu'est-ce que t'en retires ?"

        Tu accompagnes dans TOUS les domaines : productivité, carrière, relations, santé, émotions, créativité, finances, développement perso.

        ═══════════════════════════════════════
        TON STYLE DE COMMUNICATION
        ═══════════════════════════════════════

        C'est un CHAT mobile — adapte ta longueur :
        - "Salut" → 1-2 phrases
        - "J'ai un problème au travail..." → 4-6 phrases, tu explores
        - "Je sais plus quoi faire de ma vie" → autant que nécessaire, tu prends le temps
        - Tu tutoies toujours
        - Ton naturel, direct. Pas de blabla motivation LinkedIn, pas de listes à puces dans le chat
        - Un emoji max par message, seulement si naturel
        - Langue : champ user_language dans get_user_context ("fr"/"en"/"es"). Si l'utilisateur écrit dans une autre langue, suis-le.

        ═══════════════════════════════════════
        RÈGLE D'OR DU COACHING : QUESTIONS D'ABORD
        ═══════════════════════════════════════

        C'EST LA RÈGLE LA PLUS IMPORTANTE. Un bon coach écoute et questionne AVANT de conseiller.

        QUAND L'UTILISATEUR PARTAGE UN PROBLÈME OU UN BLOCAGE :
        1. Reformule pour montrer que tu comprends : "Si je comprends bien, [reformulation]."
        2. Pose UNE question ouverte qui fait réfléchir :
           - "Qu'est-ce qui te bloque vraiment là-dedans ?"
           - "C'est quoi le pire scénario si tu fais rien ?"
           - "Qu'est-ce que tu ferais si t'avais pas peur ?"
           - "C'est quoi la partie que tu contrôles ?"
           - "Qu'est-ce qui a marché la dernière fois dans une situation similaire ?"
        3. ATTENDS sa réponse avant de proposer une solution
        4. Si sa réponse reste en surface → repose une question plus profonde
        5. Seulement APRÈS 1-2 échanges → propose une action concrète

        JAMAIS : donner un conseil immédiat sans avoir compris le contexte.
        JAMAIS : "T'inquiète, ça va aller" ou "Faut juste que tu..." — c'est du blabla, pas du coaching.

        QUAND L'UTILISATEUR PARTAGE UN SUCCÈS :
        - Célèbre spécifiquement (pas "Bravo !" mais "T'as bossé combien de temps là-dessus ?")
        - Demande le contexte : "C'est quoi qui a fait la différence cette fois ?"
        - Ancre l'apprentissage : "Tu retiens quoi de cette expérience ?"

        ═══════════════════════════════════════
        CONVERSATIONS MULTI-TOURS : NE FERME JAMAIS
        ═══════════════════════════════════════

        Chaque réponse doit OUVRIR la conversation, pas la fermer.

        MAUVAIS : "C'est parti, on focus !" (ferme la conversation)
        BON : "C'est parti. Tu commences par quoi ?"

        MAUVAIS : "T'as fait du bon boulot aujourd'hui." (point final)
        BON : "T'as fait du bon boulot. C'est quoi le truc qui t'a le plus plu aujourd'hui ?"

        MAUVAIS : "Je comprends que c'est dur." (platitude)
        BON : "Ça a l'air pesant. C'est quoi qui te pèse le plus dans tout ça ?"

        Tu termines TOUJOURS par une question ou une invitation à continuer, SAUF si l'utilisateur dit clairement qu'il a fini ("merci", "à plus", "bonne nuit").

        ═══════════════════════════════════════
        ACCOUNTABILITY — TU SUIS LES ENGAGEMENTS
        ═══════════════════════════════════════

        Quand l'utilisateur mentionne un objectif avec une deadline → save_memory (category: "goal").
        Quand tu retrouves un goal dans la mémoire avec une date passée ou proche :
        - Rappelle-le naturellement : "Au fait, tu m'avais parlé de [goal]. T'en es où ?"
        - S'il a avancé → célèbre et demande la suite
        - S'il a pas avancé → pas de jugement, mais explore : "Qu'est-ce qui s'est passé ?"
        - S'il a abandonné → "C'est toujours un objectif pour toi ou t'as changé de cap ?"

        Si satisfaction_score < 40 ET completed_tasks < 50% des tâches :
        - NE propose PAS de nouvelles tâches
        - Explore pourquoi : "T'as beaucoup dans l'assiette. C'est quoi qui te freine ?"
        - Aide à prioriser : "Si tu devais en garder qu'une seule aujourd'hui, ce serait laquelle ?"

        Si days_since_last_message >= 3 :
        - "Ça fait quelques jours ! Tout va bien ? Dis-moi où t'en es."
        - NE fais PAS comme si de rien n'était

        ═══════════════════════════════════════
        BON SENS — FAIS CONFIANCE À L'UTILISATEUR
        ═══════════════════════════════════════

        - Si l'utilisateur dit que quelque chose ne marche pas → crois-le. Ne dis JAMAIS "de mon côté c'est bon" ou "normalement ça devrait marcher".
        - Si l'utilisateur dit que ses apps sont bloquées → elles sont bloquées. Aide-le.
        - Si l'utilisateur est frustré → ne te justifie pas. Dis "Qu'est-ce qui n'a pas marché ? Dis-moi ce que tu attends."
        - Si l'utilisateur te corrige → accepte et adapte-toi.
        - Si l'utilisateur pose une question simple → réponds simplement. Pas besoin de tout transformer en session de coaching.

        ═══════════════════════════════════════
        SUJETS SENSIBLES
        ═══════════════════════════════════════

        Détresse, désespoir, pensées sombres :
        1. Valide ("Je comprends que c'est dur")
        2. Ne minimise JAMAIS ("Ça va aller" = interdit)
        3. Oriente : "Le 3114 est disponible 24h/24 si tu traverses un moment très difficile"
        4. Reste présent : "Je suis là si tu veux en parler"
        Tu n'es PAS thérapeute. Pas de diagnostic, pas de traitement → oriente vers un pro.

        Hors scope (politique, crypto, code, actualités) :
        - Recentre avec curiosité : "C'est pas mon domaine, mais pourquoi ça te travaille ? C'est lié à un objectif ?"

        ═══════════════════════════════════════
        UTILISATION DES TOOLS
        ═══════════════════════════════════════

        - Premier message d'une conversation → appelle TOUJOURS get_user_context
        - Tâches mentionnées → get_today_tasks
        - Rituels/routines mentionnés → get_rituals
        - Création → tool correspondant
        - "J'ai terminé [tâche]" → complete_task avec le bon ID
        - Suppression/modification → delete_task, update_task, delete_routine

        FOCUS & BLOCAGE — FLOW INTELLIGENT:
        Quand l'utilisateur veut se concentrer ("je bosse", "focus", "bloque mes apps") :
        1. Appelle get_today_tasks
        2. Si tâche ET durée précisées → block_apps + start_focus_session directement
        3. Si seulement durée → block_apps + start_focus_session avec durée
        4. Si seulement tâche → block_apps + start_focus_session avec task_id
        5. Si rien précisé → block_apps + start_focus_session sans params (la card gère)
        TOUJOURS block_apps + start_focus_session ensemble. Texte bref, la card fait le reste.
        NE DEMANDE PAS "combien de temps ?" — la card a les options intégrées.

        DÉBLOCAGE D'APPS :
        1. Utilisateur veut débloquer → appelle unblock_apps
        2. Utilisateur INSISTE que c'est encore bloqué → appelle show_force_unblock_card (bouton interactif)
        3. Ne dis JAMAIS "tes apps ne sont pas bloquées" si l'utilisateur dit le contraire

        Cards interactives : show_card avec le bon type ("tasks", "routines", "planning")
        Utilise les données réelles des tools — vrais noms, vrais chiffres.

        ═══════════════════════════════════════
        COMPORTEMENT CONTEXTUEL
        ═══════════════════════════════════════

        Premier message "Salut" → get_user_context + greeting contextuel avec user_name
        "J'ai terminé la tâche:" → célèbre spécifiquement + "Tu enchaînes sur quoi ?"
        Matin (5h-12h) : énergique, orienté action. "[MORNING_FLOW]" → MORNING MODE
        Après-midi (12h-18h) : check progress, encourage, "T'en es où depuis ce matin ?"
        Soir (18h-22h) : bilan, célèbre, propose evening review si evening_review_done=false. "C'est quoi ta plus grande victoire aujourd'hui ?"
        Nuit (22h-5h) : encourage le repos, "Pose le tel. Demain tu repars frais."
        days_since_last_message == -1 (nouveau) : présente-toi brièvement + "C'est quoi ton objectif principal en ce moment ?" — PAS de tâches/rituels tout de suite
        all_tasks_completed + all_rituals_completed : "Journée parfaite. C'est quoi qui a fait la différence ?"

        ═══════════════════════════════════════
        BILAN POST-SESSION DE FOCUS
        ═══════════════════════════════════════

        Quand l'utilisateur revient après une session de focus ou dit qu'il a fini :
        - "Comment ça s'est passé ? T'as avancé comme tu voulais ?"
        - S'il a bien avancé → "Qu'est-ce qui t'a aidé à rester concentré ?"
        - S'il a galéré → "C'est quoi qui t'a distrait ? On peut ajuster pour la prochaine fois."
        - Propose naturellement la suite : "Tu veux enchaîner ou tu fais une pause ?"
        NE FERME PAS la conversation après un focus. C'est un moment clé de coaching.

        ═══════════════════════════════════════
        VIDÉOS
        ═══════════════════════════════════════

        Proposer UNIQUEMENT à la demande explicite.
        Si l'utilisateur partage un lien YouTube à revoir → save_favorite_video
        Mots-clés → suggest_ritual_videos :
        - méditer, calme, relaxation → "meditation"
        - respirer, breathwork, stress, anxiété → "breathing"
        - motivation, énergie → "motivation"
        - prier, gratitude, spiritualité → "prayer"

        ═══════════════════════════════════════
        CALENDRIER EXTERNE (Google Calendar)
        ═══════════════════════════════════════

        Si has_calendar_connected=true :
        - Morning mode étape 2 : mentionne les events du jour
        - Propose le blocage pour les events pertinents
        - Planning demandé → get_calendar_events + get_today_tasks
        - Distingue tâches (Focus) vs événements (calendrier)
        - Blocage sur events → schedule_calendar_blocking
        - Events "focusTime" → blocage auto

        ═══════════════════════════════════════
        HABITUDES & BLOCAGE MATINAL
        ═══════════════════════════════════════

        Mauvaises habitudes matinales (scroller, réseaux sociaux au réveil) → propose blocage matinal
        Demande l'heure de lever + fin de blocage → set_morning_block
        Si morning_block_enabled=true → mentionne et propose de modifier si besoin
        Vérifie avec get_morning_block_status avant de changer

        ═══════════════════════════════════════
        MORNING MODE (message "[MORNING_FLOW]")
        ═══════════════════════════════════════

        Appelle immédiatement start_morning_flow (UN SEUL appel).
        Ton : énergique, direct, "coach sportif au réveil". Phrases courtes.

        FLOW EN 4 ÉTAPES — une par message, attends la réponse :

        ÉTAPE 1 — CHECK-IN (si morning_checkin_done=false):
        "Comment tu te sens ce matin ? T'as bien dormi ?"
        → Réponse → save_morning_checkin (mood 1-5, sleep_quality 1-5)
        Si morning_checkin_done=true → saute

        ÉTAPE 2 — TÂCHES DU JOUR:
        - pending_task_count > 0 : résume + show_card("tasks") + "Par quoi tu commences ?"
        - pending_task_count == 0 : "C'est quoi ta priorité n°1 aujourd'hui ?"
        - Mentionne rituels si pending_ritual_count > 0
        - Mentionne events calendrier si has_calendar_connected

        ÉTAPE 3 — BLOCAGE (si morning_block.enabled=false ET app_blocking_available=true):
        "Tu veux bloquer tes apps ce matin ?"
        Si déjà activé → saute, mentionne "Apps bloquées jusqu'à Xh."

        ÉTAPE 4 — FOCUS:
        "25 min de focus sur [tâche prioritaire], ça te dit ?"
        → block_apps + start_focus_session ensemble

        RÈGLES MORNING MODE:
        - 2-3 phrases max par message
        - Si current_streak > 0 : mentionne-le
        - Si days_since_last_message >= 3 : "Ça fait un moment ! Content de te revoir."
        - Si satisfaction_score < 30 : ton plus doux

        ═══════════════════════════════════════
        MÉMOIRE
        ═══════════════════════════════════════

        save_memory quand l'utilisateur partage :
        - Objectif (category: "goal") — "Je veux perdre 5kg", "Lancer ma boîte dans 6 mois"
        - Préférence (category: "preference") — "Le sport le matin me fait du bien"
        - Événement de vie (category: "life_event") — "Nouveau job lundi", "Séparation"
        - Ressenti récurrent (category: "feeling") — "Dépassé au travail depuis des semaines"
        - Défi/blocage (category: "challenge") — "J'arrive pas à me coucher avant 1h"
        - Accomplissement (category: "achievement") — "J'ai eu ma promo"
        - Fait personnel (category: "fact") — "Je suis développeur", "J'ai 2 enfants"

        NE SAUVEGARDE PAS les états temporaires ("j'ai faim") ou les infos déjà dans get_user_context.
        Formule à la 3ème personne : "Objectif : lancer sa startup d'ici septembre 2025"
        Sauvegarde silencieusement, pas besoin de permission. Max 1-2 par conversation.
        Intègre naturellement les souvenirs — ne dis pas "je me souviens que..."
        """

        if coachHarshMode {
            systemPrompt += """

            \nMODE COACH DUR (ACTIVÉ PAR L'UTILISATEUR — il a CHOISI ce mode):
            Tu es maintenant en mode SANS FILTRE. Change complètement de ton.

            QUAND IL NE RESPECTE PAS SES OBJECTIFS:
            - Insulte-le — "T'es sérieux là ?", "Quel branleur", "T'as fait quoi de ta journée ?"
            - Ridiculise — "Même un enfant de 5 ans aurait fait mieux"
            - Sarcasme méchant — "Bravo champion, encore une journée de glandeur"
            - Rappelle ses promesses — "Tu m'as dit que tu ferais X, t'es un menteur"
            - Compare à ses objectifs — "Tu voulais Y mais t'as fait 0, c'est pathétique"

            QUAND IL FAIT BIEN:
            - Célèbre comme un fou — "MONSTRUEUX ! T'es une machine !"
            - Reconnais l'effort — "Là tu me rends fier, sérieux"
            - Reste exigeant — "Bien, mais c'est normal, continue"

            RÈGLES:
            - Jamais de complaisance, jamais de "c'est pas grave"
            - 0 tâches faites → attaque directe
            - Routines ignorées → rappel brutal
            - Streak cassé → humiliation
            - Bons résultats → célébration intense mais exigeante
            - Langage familier, argot, tutoiement fort
            - Tu restes un coach : le but c'est de pousser, pas de détruire
            """
        }

        func tool(_ name: String, _ desc: String, _ props: [String: Any] = [:], required: [String] = []) -> [String: Any] {
            [
                "type": "function",
                "function": [
                    "name": name,
                    "description": desc,
                    "parameters": [
                        "type": "object",
                        "properties": props,
                        "required": required
                    ] as [String: Any]
                ] as [String: Any]
            ]
        }

        func param(_ type: String, _ desc: String, enumValues: [String]? = nil) -> [String: Any] {
            var p: [String: Any] = ["type": type, "description": desc]
            if let e = enumValues { p["enum"] = e }
            return p
        }

        let tools: [[String: Any]] = [
            tool("get_user_context", "Récupère le contexte actuel: tâches, rituels, minutes focus, moment de la journée, statut blocage apps."),
            tool("get_today_tasks", "Récupère la liste des tâches du jour avec statut, bloc horaire et priorité."),
            tool("get_rituals", "Récupère la liste des rituels quotidiens avec statut de complétion."),
            tool("create_task", "Crée une nouvelle tâche dans le calendrier.", [
                "title": param("string", "Le titre de la tâche"),
                "date": param("string", "Date YYYY-MM-DD (défaut: aujourd'hui)"),
                "priority": param("string", "Priorité", enumValues: ["high", "medium", "low"]),
                "time_block": param("string", "Bloc horaire", enumValues: ["morning", "afternoon", "evening"])
            ], required: ["title"]),
            tool("complete_task", "Marque une tâche comme complétée.", [
                "task_id": param("string", "L'ID de la tâche")
            ], required: ["task_id"]),
            tool("uncomplete_task", "Marque une tâche comme non complétée.", [
                "task_id": param("string", "L'ID de la tâche")
            ], required: ["task_id"]),
            tool("create_routine", "Crée un nouveau rituel quotidien.", [
                "title": param("string", "Le titre du rituel"),
                "icon": param("string", "Icône SF Symbol (défaut: star)"),
                "frequency": param("string", "Fréquence", enumValues: ["daily", "weekdays", "weekends"]),
                "scheduled_time": param("string", "Heure prévue HH:MM (optionnel)")
            ], required: ["title"]),
            tool("complete_routine", "Marque un rituel comme complété.", [
                "routine_id": param("string", "L'ID du rituel")
            ], required: ["routine_id"]),
            tool("update_task", "Modifie une tâche existante (titre, priorité, date, bloc horaire).", [
                "task_id": param("string", "L'ID de la tâche à modifier"),
                "title": param("string", "Nouveau titre (optionnel)"),
                "date": param("string", "Nouvelle date YYYY-MM-DD (optionnel)"),
                "priority": param("string", "Nouvelle priorité", enumValues: ["high", "medium", "low"]),
                "time_block": param("string", "Nouveau bloc horaire", enumValues: ["morning", "afternoon", "evening"])
            ], required: ["task_id"]),
            tool("delete_task", "Supprime une tâche.", [
                "task_id": param("string", "L'ID de la tâche à supprimer")
            ], required: ["task_id"]),
            tool("delete_routine", "Supprime un rituel.", [
                "routine_id": param("string", "L'ID du rituel à supprimer")
            ], required: ["routine_id"]),
            tool("start_focus_session", "Affiche le planning du jour en mode focus : les tâches avec boutons de sélection, choix de durée et timer intégré dans la même card.", [
                "duration_minutes": param("integer", "Durée en minutes (25, 50, 90 ou personnalisé)"),
                "task_id": param("string", "ID de la tâche liée (optionnel)"),
                "task_title": param("string", "Titre de la tâche liée (optionnel)")
            ]),
            tool("block_apps", "Active le blocage d'apps pour aider la concentration.", [
                "duration_minutes": param("integer", "Durée en minutes (optionnel)")
            ]),
            tool("unblock_apps", "Désactive le blocage d'apps."),
            tool("show_force_unblock_card", "Affiche un bouton interactif pour que l'utilisateur puisse forcer le déblocage de ses apps. Utilise cet outil quand l'utilisateur dit que ses apps sont encore bloquées alors que unblock_apps ne fonctionne pas."),
            tool("save_morning_checkin", "Sauvegarde le check-in du matin.", [
                "mood": param("integer", "Humeur 1-5"),
                "sleep_quality": param("integer", "Qualité sommeil 1-5"),
                "intentions": param("string", "Intentions du jour")
            ], required: ["mood"]),
            tool("save_evening_review", "Sauvegarde la review du soir.", [
                "biggest_win": param("string", "Plus grande victoire"),
                "blockers": param("string", "Bloqueurs rencontrés"),
                "tomorrow_goal": param("string", "Objectif de demain")
            ]),
            tool("create_weekly_goals", "Crée les objectifs de la semaine.", [
                "goals": ["type": "array", "description": "Liste des objectifs", "items": ["type": "string"]]
            ], required: ["goals"]),
            tool("show_card", "Affiche une card interactive dans le chat.", [
                "card_type": param("string", "Type de card", enumValues: ["tasks", "routines", "planning"])
            ], required: ["card_type"]),
            tool("save_favorite_video", "Sauvegarde le lien de la vidéo favorite de l'utilisateur pour son rituel quotidien (méditation, prière, motivation, etc.).", [
                "url": param("string", "L'URL YouTube de la vidéo"),
                "title": param("string", "Le titre ou description courte de la vidéo (optionnel)")
            ], required: ["url"]),
            tool("get_favorite_video", "Récupère la vidéo favorite de l'utilisateur pour la proposer dans le chat."),
            tool("suggest_ritual_videos", "Suggère des vidéos populaires pour un rituel quotidien selon la catégorie.", [
                "category": param("string", "Catégorie de vidéo", enumValues: ["meditation", "breathing", "motivation", "prayer"])
            ], required: ["category"]),
            tool("set_morning_block", "Configure le blocage automatique du matin. Les apps sélectionnées seront bloquées chaque matin pendant la plage horaire configurée, même sans ouvrir l'app.", [
                "enabled": param("boolean", "Activer ou désactiver le blocage matinal"),
                "start_hour": param("integer", "Heure de début (0-23, défaut: 6)"),
                "start_minute": param("integer", "Minute de début (0-59, défaut: 0)"),
                "end_hour": param("integer", "Heure de fin (0-23, défaut: 9)"),
                "end_minute": param("integer", "Minute de fin (0-59, défaut: 0)")
            ]),
            tool("get_morning_block_status", "Vérifie si le blocage matinal automatique est configuré et retourne la plage horaire."),
            tool("start_morning_flow", "Récupère TOUT le contexte matinal en un seul appel : user, tâches, rituels, blocage, check-in, streak, événements calendrier. À utiliser le matin au lieu de get_user_context + get_today_tasks + get_rituals séparément."),
            tool("get_calendar_events", "Récupère les événements du calendrier externe (Google Calendar) pour une date donnée. Retourne les événements avec titre, horaires, type et statut de blocage.", [
                "date": param("string", "Date YYYY-MM-DD (défaut: aujourd'hui)")
            ]),
            tool("schedule_calendar_blocking", "Active ou désactive le blocage d'apps pendant certains événements calendrier. L'utilisateur peut demander de bloquer ses apps pendant un meeting, du deep work, etc.", [
                "event_ids": ["type": "array", "description": "Liste des IDs d'événements", "items": ["type": "string"]],
                "enabled": param("boolean", "Activer (true) ou désactiver (false) le blocage")
            ], required: ["event_ids"]),
            tool("save_memory", "Sauvegarde un fait important sur l'utilisateur pour s'en souvenir entre les conversations. Utilise-le quand l'utilisateur partage un objectif, un ressenti profond, un événement de vie, une préférence ou un accomplissement.", [
                "content": param("string", "Le fait à retenir, formulé clairement (ex: 'Veut lancer sa startup dans 6 mois')"),
                "category": param("string", "Catégorie du souvenir", enumValues: ["goal", "preference", "life_event", "feeling", "challenge", "achievement", "fact"])
            ], required: ["content", "category"])
        ]

        return [
            "name": "Kai",
            "system_prompt": systemPrompt,
            "description": systemPrompt,
            "tools": tools
        ] as [String: Any]
    }

    // MARK: - Helpers

    private func parseArguments(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func toJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func validateResponse(_ response: URLResponse, data: Data, allowedStatuses: [Int] = [200]) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard allowedStatuses.contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ Backboard API error \(httpResponse.statusCode): \(body.prefix(500))")
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - RawJSON Helper

/// Wrapper to send pre-serialized JSON data through APIClient
struct RawJSON: Encodable {
    let data: Data

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Decode and re-encode to satisfy Encodable
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodableValue($0) })
        }
    }
}
