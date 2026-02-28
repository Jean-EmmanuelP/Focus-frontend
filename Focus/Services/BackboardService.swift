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

        let assistantConfig = Self.assistantTemplate
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
            "memory": "Auto"
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

            case "get_quests":
                let result = try await getQuests()
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

            case "create_quest":
                let result = try await createQuest(args: args)
                return (result, [.refreshQuests, .showCard("quests")])

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
        let streak = store.currentStreak
        let tasksTotal = store.todaysTasks.count
        let tasksCompleted = store.todaysTasks.filter { $0.status == "completed" }.count
        let ritualsTotal = store.rituals.count
        let ritualsCompleted = store.rituals.filter { $0.isCompleted }.count
        let focusMinutes = store.todaysSessions.reduce(0) { $0 + ($1.durationMinutes ?? 0) }
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

        let context: [String: Any] = [
            "user_name": userName,
            "streak": streak,
            "tasks_today": tasksTotal,
            "tasks_completed": tasksCompleted,
            "rituals_today": ritualsTotal,
            "rituals_completed": ritualsCompleted,
            "focus_minutes_today": focusMinutes,
            "time_of_day": timeOfDay,
            "apps_blocked": isBlocking
        ]
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

    private func getQuests() async throws -> String {
        await FocusAppStore.shared.loadQuests()
        let quests = FocusAppStore.shared.quests.filter { $0.status == .active }.map { quest in
            [
                "id": quest.id,
                "title": quest.title,
                "area": quest.area.rawValue,
                "progress": quest.progress
            ] as [String: Any]
        }
        return toJSON(["quests": quests])
    }

    private func createTask(args: [String: Any]) async throws -> String {
        let apiClient = APIClient.shared
        let title = args["title"] as? String ?? "Nouvelle tâche"
        let dateStr = args["date"] as? String ?? todayString()
        let priority = args["priority"] as? String
        let timeBlock = args["time_block"] as? String
        let questId = args["quest_id"] as? String

        var body: [String: Any] = [
            "title": title,
            "date": dateStr
        ]
        if let priority { body["priority"] = priority }
        if let timeBlock { body["time_block"] = timeBlock }
        if let questId { body["quest_id"] = questId }

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

    private func createQuest(args: [String: Any]) async throws -> String {
        let title = args["title"] as? String ?? "Nouvel objectif"
        let area = args["area"] as? String ?? "other"
        let targetDate = args["target_date"] as? String

        var body: [String: Any] = [
            "title": title,
            "area": area
        ]
        if let targetDate { body["target_date"] = targetDate }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: .createQuest,
            method: .post,
            body: RawJSON(data: bodyData)
        )
        return toJSON(["created": true, "title": title] as [String: Any])
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
            endpoint: .upsertIntentions(date: todayString()),
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
    static let assistantTemplate: [String: Any] = {
        let systemPrompt = """
        Tu es Kai, le coach de vie personnel de l'utilisateur. Tu l'accompagnes au quotidien dans ses objectifs, sa productivité et son bien-être.

        TON STYLE:
        - C'est un CHAT sur mobile — réponses courtes, 2-3 phrases max
        - Tu tutoies toujours
        - Ton naturel, direct, pas de blabla motivation LinkedIn
        - Tu challenges quand nécessaire, tu célèbres les vraies victoires
        - Un emoji max par message, seulement si naturel
        - Tu finis souvent par une question ou une action concrète
        - Tu parles TOUJOURS en français

        COMMENT UTILISER LES TOOLS:
        - Au début de chaque conversation (premier message), appelle TOUJOURS get_user_context
        - Quand l'utilisateur parle de ses tâches, appelle get_today_tasks
        - Quand il parle de rituels/routines, appelle get_rituals
        - Quand il parle d'objectifs/quests, appelle get_quests
        - Quand il te demande de créer quelque chose, utilise le tool correspondant
        - Quand il dit avoir terminé une tâche, utilise complete_task avec le bon ID
        - Quand il veut se concentrer ou bloquer ses apps, utilise block_apps
        - Quand tu veux montrer une liste interactive, appelle show_card avec le bon type
        - Utilise les données réelles des tools — mentionne les vrais noms, les vrais chiffres

        COMPORTEMENT SPÉCIAL:
        - Si le premier message est "Salut" ou similaire, appelle get_user_context et fais un greeting contextuel
        - Si le message contient "J'ai terminé la tâche:", réagis avec enthousiasme court
        - Le matin (5h-12h): encourage à démarrer, demande les priorités
        - L'après-midi (12h-18h): check progress, encourage
        - Le soir (18h-22h): bilan, célèbre les victoires
        - La nuit (22h-5h): encourage le repos

        MÉMOIRE:
        - Tu as accès à une mémoire automatique. Les faits importants sont retenus entre les conversations.
        - Utilise ces souvenirs pour personnaliser tes réponses.
        - Ne dis pas explicitement "je me souviens que..." — intègre naturellement les infos.
        """

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
            tool("get_user_context", "Récupère le contexte actuel: streak, tâches, rituels, minutes focus, moment de la journée, statut blocage apps."),
            tool("get_today_tasks", "Récupère la liste des tâches du jour avec statut, bloc horaire et priorité."),
            tool("get_rituals", "Récupère la liste des rituels quotidiens avec statut de complétion."),
            tool("get_quests", "Récupère la liste des objectifs actifs avec domaine et progression."),
            tool("create_task", "Crée une nouvelle tâche dans le calendrier.", [
                "title": param("string", "Le titre de la tâche"),
                "date": param("string", "Date YYYY-MM-DD (défaut: aujourd'hui)"),
                "priority": param("string", "Priorité", enumValues: ["high", "medium", "low"]),
                "time_block": param("string", "Bloc horaire", enumValues: ["morning", "afternoon", "evening"]),
                "quest_id": param("string", "ID du quest lié (optionnel)")
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
            tool("create_quest", "Crée un nouvel objectif.", [
                "title": param("string", "Le titre de l'objectif"),
                "area": param("string", "Domaine de vie", enumValues: ["health", "learning", "career", "relationships", "creativity", "other"]),
                "target_date": param("string", "Date cible YYYY-MM-DD (optionnel)")
            ], required: ["title", "area"]),
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
                "card_type": param("string", "Type de card", enumValues: ["tasks", "routines", "quests", "planning"])
            ], required: ["card_type"])
        ]

        return [
            "name": "Kai",
            "system_prompt": systemPrompt,
            "description": systemPrompt,
            "tools": tools
        ] as [String: Any]
    }()

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
