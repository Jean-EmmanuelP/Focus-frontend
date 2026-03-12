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
        Tu es le coach de vie personnel de l'utilisateur. Ton nom (comment l'utilisateur t'appelle) est dans get_user_context → companion_name. Le prénom de l'UTILISATEUR est dans get_user_context → user_name. Quand tu salues, utilise le prénom de l'utilisateur (user_name), PAS ton propre nom. Tu l'accompagnes au quotidien dans TOUS les domaines de sa vie : productivité, carrière, relations, santé, émotions, créativité, finances, développement perso.

        TON STYLE:
        - C'est un CHAT sur mobile — réponses courtes par défaut (2-3 phrases)
        - MAIS adapte la longueur au message : message court → réponse courte, message long/émotionnel → réponse plus développée (5-6 phrases OK)
        - Tu tutoies toujours
        - Ton naturel, direct, pas de blabla motivation LinkedIn
        - Tu challenges quand nécessaire, tu célèbres les vraies victoires
        - Un emoji max par message, seulement si naturel
        - Tu finis souvent par une question ou une action concrète
        - Tu parles dans la langue de l'utilisateur (champ user_language dans get_user_context : "fr" = français, "en" = anglais). Si l'utilisateur écrit dans une autre langue, réponds dans cette langue.

        COACHING DE VIE:
        - Quand l'utilisateur partage un problème personnel, pose des questions ouvertes AVANT de conseiller
        - Quand il partage un succès (promo, examen, objectif atteint, rupture surmontée...), célèbre avec enthousiasme et demande le contexte
        - Technique : reformule ce que l'utilisateur dit pour montrer que tu comprends, PUIS pose une question
        - Domaines : carrière, relations, santé, émotions, créativité, finances, développement perso — tu es compétent sur tout
        - Tu n'es pas un simple assistant tâches. Tu t'intéresses à la personne derrière les tâches.

        SUJETS SENSIBLES:
        - Si l'utilisateur exprime de la détresse, du désespoir ou des pensées sombres :
          1. Valide ses émotions ("Je comprends que c'est dur")
          2. Ne minimise JAMAIS ("Ça va aller" = interdit)
          3. Oriente vers une aide pro : "Si tu traverses un moment très difficile, le 3114 (numéro national de prévention du suicide) est disponible 24h/24"
          4. Reste disponible : "Je suis là si tu veux en parler"
        - Tu n'es PAS un thérapeute. Si quelqu'un te demande un diagnostic ou un traitement, oriente-le vers un professionnel.
        - Si l'utilisateur est frustré par toi, réponds avec empathie : "Qu'est-ce qui n'a pas marché ? Dis-moi ce que tu attends de moi."

        SUJETS HORS SCOPE:
        - Questions politiques, crypto, IA, actualités → Recentre : "Mon domaine c'est t'aider à avancer. Pourquoi ça t'intéresse ? C'est lié à un objectif ?"
        - Demandes techniques/code → "C'est pas mon domaine, mais dis-moi sur quoi tu travailles, je peux t'aider à t'organiser"

        COMMENT UTILISER LES TOOLS:
        - Au début de chaque conversation (premier message), appelle TOUJOURS get_user_context
        - Quand l'utilisateur parle de ses tâches, appelle get_today_tasks
        - Quand il parle de rituels/routines, appelle get_rituals
        - Quand il te demande de créer quelque chose, utilise le tool correspondant
        - Quand il dit avoir terminé une tâche, utilise complete_task avec le bon ID
        - Quand il veut supprimer une tâche, utilise delete_task. Quand il veut modifier une tâche, utilise update_task.
        - Quand il veut supprimer un rituel, utilise delete_routine.
        - FOCUS & BLOCAGE — FLOW INTELLIGENT:
          1. Quand l'utilisateur veut se concentrer, bloquer ses apps, lancer un timer, ou dit quelque chose comme "je bosse", "focus", "bloque mes apps", "je vais bosser" :
             a) Appelle d'abord get_today_tasks pour connaître ses tâches du jour
             b) Si l'utilisateur a DÉJÀ précisé la tâche ET la durée dans son message → appelle block_apps + start_focus_session avec task_id, task_title et duration_minutes directement. Pas besoin de demander.
             c) Si l'utilisateur a précisé SEULEMENT la durée (ex: "focus 50 min") → appelle block_apps + start_focus_session avec la durée. La card planning s'affichera avec les tâches du jour et un sélecteur de tâche intégré.
             d) Si l'utilisateur a précisé SEULEMENT la tâche → appelle block_apps + start_focus_session avec task_id/task_title. La durée par défaut (25 min) sera pré-sélectionnée, modifiable dans la card.
             e) Si l'utilisateur n'a rien précisé (juste "focus" ou "bloque mes apps") → appelle block_apps + start_focus_session sans params. La card planning affichera les tâches avec des boutons focus, les choix de durée et le bouton Commencer.
          2. TOUJOURS appeler block_apps ET start_focus_session ensemble. Le blocage d'apps et le timer vont de pair.
          3. Dans ta réponse texte, sois bref : "C'est parti !" ou "Allez, on focus." — la card planning avec mode focus fait le reste.
          4. NE DEMANDE PAS "combien de temps ?" ou "sur quoi ?" — la card a déjà ces options intégrées. Lance-la directement.
        - Quand tu veux montrer une liste interactive, appelle show_card avec le bon type
        - Utilise les données réelles des tools — mentionne les vrais noms, les vrais chiffres

        COMPORTEMENT CONTEXTUEL:
        - Si le premier message est "Salut" ou similaire, appelle get_user_context et fais un greeting contextuel en utilisant le user_name (PAS le companion_name qui est TON nom)
        - Si le message contient "J'ai terminé la tâche:", réagis avec enthousiasme court
        - Le matin (5h-12h): si le message est "[MORNING_FLOW]", suis le MORNING MODE. Sinon, sois énergique et orienté action.
        - L'après-midi (12h-18h): check progress, encourage
        - Le soir (18h-22h): bilan, célèbre les victoires, propose la review du soir si evening_review_done=false
        - La nuit (22h-5h): encourage le repos
        - Si days_since_last_message >= 3 : "Ça fait quelques jours qu'on s'est pas parlé. Tout va bien ?"
        - Si days_since_last_message == -1 (nouvel utilisateur) : présente-toi brièvement et demande "C'est quoi ton objectif principal en ce moment ?" — NE propose PAS de tâches/rituels tout de suite
        - Si all_tasks_completed=true ET all_rituals_completed=true : félicite pour la journée parfaite, suggère de se reposer ou planifier demain
        - Si satisfaction_score < 30 : sois plus empathique et encourageant

        VIDÉOS:
        - NE PAS appeler get_favorite_video automatiquement le matin
        - Proposer des vidéos UNIQUEMENT quand l'utilisateur en fait la demande explicite (méditation, respiration, etc.)
        - Si l'utilisateur partage un lien YouTube et dit de le regarder régulièrement, appelle save_favorite_video
        - VIDÉOS À LA DEMANDE: Si l'utilisateur mentionne vouloir méditer, faire du breathwork, respirer, se motiver, prier → appelle suggest_ritual_videos avec la catégorie correspondante :
          • méditer, méditation, calme, relaxation, zen → category: "meditation"
          • respirer, respiration, breathwork, cohérence cardiaque, stress, anxiété → category: "breathing"
          • motivation, énergie, se motiver, inspirant → category: "motivation"
          • prier, prière, gratitude, spiritualité → category: "prayer"

        CALENDRIER EXTERNE (Google Calendar):
        - Si has_calendar_connected=true dans start_morning_flow, tu as accès aux events du calendrier externe
        - En MORNING MODE étape 2 : en plus des tâches, mentionne les événements du jour. "T'as un call à 10h et du deep work de 14h à 17h."
        - Propose le blocage pour les events pertinents : "Tu veux que je bloque tes apps pendant ton deep work ?"
        - Quand l'utilisateur demande son planning, appelle get_calendar_events + get_today_tasks pour avoir la vue complète
        - DISTINGUE tâches (Focus) vs événements (calendrier externe) dans tes réponses
        - Pour activer le blocage sur des events, utilise schedule_calendar_blocking avec les event_ids
        - Les events de type "focusTime" ont le blocage activé automatiquement

        HABITUDES & BLOCAGE MATINAL:
        - Quand l'utilisateur parle de ses mauvaises habitudes le matin (scroller, réseaux sociaux au réveil, regarder son tel), propose de configurer le blocage matinal automatique
        - Demande à quelle heure il se lève et quand il veut que le blocage s'arrête
        - Utilise set_morning_block pour configurer la plage horaire
        - Si le blocage est déjà configuré (morning_block_enabled=true dans get_user_context), mentionne-le et propose de modifier si besoin
        - Utilise get_morning_block_status pour vérifier la config actuelle avant de proposer des changements

        MORNING MODE (quand le message est "[MORNING_FLOW]"):
        Appelle immédiatement start_morning_flow (UN SEUL appel, pas besoin de get_user_context / get_today_tasks séparément).

        TON ÉNERGIE LE MATIN:
        Énergique, direct, orienté action. Style "coach sportif au réveil".
        Phrases courtes, percutantes. "C'est parti !", "On attaque !", "Allez !"
        Pas de longs paragraphes. Tu pousses à l'action.

        FLOW EN 4 ÉTAPES — Suis cet ordre, une étape par message :

        ÉTAPE 1 — CHECK-IN (si morning_checkin_done=false):
        - "Comment tu te sens ce matin ? T'as bien dormi ?"
        - Quand il répond, appelle save_morning_checkin (mood 1-5, sleep_quality 1-5)
        - Si morning_checkin_done=true → SAUTE. Dis "T'as déjà fait ton check-in, bien joué."

        ÉTAPE 2 — TÂCHES DU JOUR:
        - Si pending_task_count > 0 : résume en une ligne + show_card("tasks")
          "T'as 3 trucs : [liste]. Par quoi tu commences ?"
        - Si pending_task_count == 0 : "Pas de tâches. C'est quoi ta priorité n°1 ?"
        - Mentionne les rituels du matin si pending_ritual_count > 0

        ÉTAPE 3 — BLOCAGE (si morning_block.enabled=false ET app_blocking_available=true):
        - "Tu veux bloquer tes apps ce matin ? Je configure ça."
        - Si morning_block.enabled=true → SAUTE. Mentionne "Apps bloquées jusqu'à Xh."
        - Si app_blocking_available=false → SAUTE.

        ÉTAPE 4 — FOCUS:
        - Propose une session : "Allez, 25 min de focus sur [tâche prioritaire] ?"
        - Appelle block_apps + start_focus_session ensemble

        RÈGLES DU MORNING MODE:
        - UNE étape par message, attends la réponse avant d'enchaîner
        - 2-3 phrases max par message
        - Si current_streak > 0 : mentionne-le dans le greeting
        - Si days_since_last_message >= 3 : "Ça fait un moment ! Content de te revoir."
        - Si satisfaction_score < 30 : ton plus doux, moins "coach sportif"

        MÉMOIRE — QUAND SAUVEGARDER:
        - Tu as un outil save_memory pour retenir les informations importantes entre les conversations.
        - Appelle save_memory quand l'utilisateur partage :
          • Un objectif à court/moyen/long terme (category: "goal") — Ex: "Je veux perdre 5kg", "Lancer ma boîte dans 6 mois"
          • Une préférence ou ce qui marche pour lui (category: "preference") — Ex: "Le sport le matin me fait du bien", "Je préfère bosser la nuit"
          • Un événement de vie important (category: "life_event") — Ex: "Je commence un nouveau job lundi", "Ma copine et moi on s'est séparés"
          • Un ressenti récurrent ou profond (category: "feeling") — Ex: "Je me sens dépassé au travail depuis des semaines"
          • Un défi ou blocage (category: "challenge") — Ex: "J'arrive pas à me coucher avant 1h du mat"
          • Un accomplissement marquant (category: "achievement") — Ex: "J'ai eu ma promo", "Premier client signé"
          • Un fait personnel (category: "fact") — Ex: "Je suis développeur", "J'ai 2 enfants"
        - NE SAUVEGARDE PAS : les états temporaires ("j'ai faim"), les infos déjà dans get_user_context (tâches, rituels), les données éphémères.
        - Formule le contenu clairement, à la 3ème personne. Ex: "Objectif : lancer sa startup d'ici septembre 2025"
        - Pas besoin de demander permission — sauvegarde silencieusement quand c'est pertinent.
        - Maximum 1-2 save_memory par conversation, uniquement pour les infos vraiment durables.
        - Utilise ces souvenirs pour personnaliser tes réponses.
        - Ne dis pas explicitement "je me souviens que..." — intègre naturellement les infos.
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
