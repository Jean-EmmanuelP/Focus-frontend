# SPEC : Timer Inline dans le Chat

## Résumé

Permettre à l'utilisateur de lancer une session focus **directement depuis le chat**, sans quitter la conversation. Le coach IA (Kai) propose un timer inline avec sélection de tâche, création inline, choix de durée, blocage d'apps automatique et confetti à la fin.

---

## 1. User Flow Complet

### Flow principal
1. L'utilisateur dit au coach : "Je veux me concentrer", "Lance un timer", "Focus 25 min sur Lire 20 pages"
2. Le coach appelle le tool `start_focus_session` (existant) avec les params enrichis
3. **Au lieu d'ouvrir FireModeView en fullscreen**, un **timer card inline** apparaît dans le chat
4. La card montre : tâche associée (ou sélecteur), durée, bouton Start
5. L'utilisateur lance le timer depuis la card
6. La card se met à jour en temps réel (countdown, progress ring)
7. L'utilisateur peut pause/resume/stop depuis la card
8. À la fin : confetti + message de célébration du coach
9. Si une tâche était liée : prompt "Tu as terminé la tâche ?" dans la card

### Flow avec sélection de tâche
1. Le coach appelle `start_focus_session` sans `task_id`
2. La card inline affiche un picker avec les tâches du jour (non complétées)
3. L'utilisateur sélectionne une tâche OU crée une nouvelle tâche inline
4. Le timer démarre

### Flow création de tâche inline
1. Dans la card timer (avant le start), l'utilisateur tape "Ajouter une tâche"
2. Un text field apparaît dans la card
3. La tâche est créée via l'API existante
4. Le timer démarre lié à cette nouvelle tâche

---

## 2. Architecture Existante à Réutiliser

### 2.1 Système de Cards Inline (ChatCardData)

**Fichier** : `Focus/ViewModels/ChatViewModel.swift:19-64`

Le chat a déjà un système de cards interactives attachées aux messages :

```swift
enum ChatCardData: Codable {
    case taskList([CardTask])
    case routineList([CardRoutine])
    case planning([CardTask], [CardRoutine])
    case actionButton(ActionButton)
    case videoCard(VideoCard)
    case videoSuggestions(VideoSuggestionsData)
    // AJOUTER:
    // case focusTimer(FocusTimerCardData)
}
```

Les cards sont rendues dans `ReplikaMessageBubble` (ChatView.swift:657-689) via un `switch` sur `cardData`.

### 2.2 Side Effects (BackboardSideEffect)

**Fichier** : `Focus/Models/BackboardModels.swift:89-101`

```swift
enum BackboardSideEffect {
    // ... existants ...
    case startFocusSession(Int?) // duration in minutes — ACTUELLEMENT ouvre FireModeView
}
```

**Actuellement** : `startFocusSession` ouvre `focus://firemode` via deep link (ChatViewModel.swift:742-746).
**Nouveau comportement** : au lieu d'ouvrir FireModeView, attacher un `FocusTimerCard` au message.

### 2.3 Tool `start_focus_session` (Backend/Backboard)

**Fichier** : `Focus/Services/BackboardService.swift:285-287`

```swift
case "start_focus_session":
    let duration = args["duration_minutes"] as? Int
    return (toJSON(["started": true, "duration_minutes": duration ?? 25]), [.startFocusSession(duration)])
```

**Tool definition** (BackboardService.swift, dans `assistantTemplate`) :
```swift
tool("start_focus_session", "Démarre une session de focus.", {
    "duration_minutes": param("integer", "Durée en minutes (25, 50, 90 ou personnalisé)"),
})
```

### 2.4 FireModeViewModel (logique timer à extraire)

**Fichier** : `Focus/ViewModels/FireModeViewModel.swift`

Méthodes clés à réutiliser/extraire :

| Méthode | Lignes | Ce qu'elle fait |
|---------|--------|-----------------|
| `startTimer()` | 166-203 | Crée session backend, démarre Live Activity, widget, app blocking, loop timer |
| `pauseTimer()` | 227-241 | Pause + update Live Activity |
| `resumeTimer()` | 243-256 | Resume + update Live Activity |
| `stopTimer()` | 258-293 | Stop + cancel backend + validation prompt si tâche liée |
| `completeSession()` | 304-342 | Timer à zéro : complete backend, stop blocking, validation |
| `tick()` | 388-409 | Décrémente chaque seconde, update Live Activity tous les 5s |
| `validateLinkedTask()` | 345-370 | Marque tâche/rituel comme complété |

### 2.5 AppRouter (navigation FireMode)

**Fichier** : `Focus/Navigation/Navigation.swift:50-100`

```swift
@Published var showFireModeSession = false
@Published var fireModePresetDuration: Int?
@Published var fireModePresetTaskId: String?

func navigateToFireMode(duration: Int?, description: String?, taskId: String?, ritualId: String?) {
    fireModePresetDuration = duration
    fireModePresetDescription = description
    fireModePresetTaskId = taskId
    fireModePresetRitualId = ritualId
    showFireModeSession = true
}
```

### 2.6 Store (tâches + sessions)

**Fichier** : `Focus/Core/AppStore.swift`

```swift
@Published var todaysTasks: [CalendarTask] = []

func startSession(durationMinutes: Int, description: String?) async throws -> FocusSession
func completeSession(sessionId: String) async throws
func cancelSession(sessionId: String) async throws
func toggleTask(taskId: String, completed: Bool) async throws
func refreshTodaysTasks() async
```

### 2.7 Modèles existants

**CalendarTask** (`Focus/Models/CalendarModels.swift:18`) :
```swift
struct CalendarTask: Codable, Identifiable {
    let id: String
    var title: String
    var status: String          // "pending", "completed"
    var estimatedMinutes: Int?
    var timeBlock: String       // "morning", "afternoon", "evening"
    var priority: String        // "high", "medium", "low"
}
```

**FocusSession** (`Focus/Models/Models.swift:51-96`) :
```swift
struct FocusSession: Codable, Identifiable {
    let id: String
    let durationMinutes: Int
    let startTime: Date
    let endTime: Date?
    let description: String?
}
```

---

## 3. Modifications à Effectuer

### 3.1 NOUVEAU : `FocusTimerCardData` model

**Fichier à modifier** : `Focus/ViewModels/ChatViewModel.swift`

Ajouter un nouveau case à `ChatCardData` :

```swift
enum ChatCardData: Codable {
    // ... existants ...
    case focusTimer(FocusTimerCardData)

    struct FocusTimerCardData: Codable {
        var duration: Int                     // minutes (défaut: 25)
        var taskId: String?                   // tâche liée (optionnelle)
        var taskTitle: String?                // titre affiché
        var state: FocusTimerState            // idle, running, paused, completed
        var timeRemaining: Int?               // secondes restantes (nil = pas démarré)
        var sessionId: String?                // ID backend de la session
    }

    enum FocusTimerState: String, Codable {
        case idle       // Prêt à démarrer (sélection tâche/durée)
        case running    // Timer actif
        case paused     // Timer en pause
        case completed  // Session terminée
    }
}
```

### 3.2 MODIFIER : `BackboardSideEffect` handling

**Fichier** : `Focus/ViewModels/ChatViewModel.swift:742-746`

**Avant** :
```swift
case .startFocusSession:
    if let url = URL(string: "focus://firemode") {
        await UIApplication.shared.open(url)
    }
```

**Après** : Ne plus ouvrir FireModeView. Au lieu de ça, le timer card inline sera attaché au message AI (voir section 3.4).

### 3.3 MODIFIER : Card attachment dans `sendToAI`

**Fichier** : `Focus/ViewModels/ChatViewModel.swift:661-670`

Ajouter la détection de `startFocusSession` dans la logique d'attachment de card :

```swift
// Après les checks existants (video, videoSuggestions, showCard)
if let focusSession = sideEffects.firstStartFocusSession {
    let tasks = store?.todaysTasks.filter { $0.status != "completed" } ?? []
    aiMessage.cardData = .focusTimer(ChatCardData.FocusTimerCardData(
        duration: focusSession ?? 25,
        taskId: nil,     // L'utilisateur choisira dans la card
        taskTitle: nil,
        state: .idle,
        timeRemaining: nil,
        sessionId: nil
    ))
}
```

Ajouter un helper sur `[BackboardSideEffect]` :
```swift
extension Array where Element == BackboardSideEffect {
    var firstStartFocusSession: Int?? {
        for effect in self {
            if case .startFocusSession(let duration) = effect { return .some(duration) }
        }
        return nil
    }
}
```

### 3.4 NOUVEAU : `InlineFocusTimerCard` (Vue SwiftUI)

**Fichier à modifier** : `Focus/Views/Chat/ChatView.swift`

Ajouter dans le `switch cardData` de `ReplikaMessageBubble` (ligne ~689) :

```swift
case .focusTimer(let timerData):
    InlineFocusTimerCard(
        data: timerData,
        messageId: message.id,
        viewModel: chatViewModel
    )
```

**Composant `InlineFocusTimerCard`** — à ajouter dans le même fichier (comme les autres cards inline) :

#### États de la card :

**État 1 : `idle` (pré-démarrage)**
```
┌─────────────────────────────────────┐
│  🔥 Session Focus                   │
│                                     │
│  Tâche: [Dropdown tâches du jour ▼] │
│         [+ Créer une tâche]         │
│                                     │
│  Durée: [25] [50] [90] [__] min     │
│                                     │
│  [ ▶ Commencer ]                    │
└─────────────────────────────────────┘
```

- Dropdown : liste des `store.todaysTasks` non complétées
- Chips durée : `[25, 50, 90]` + champ custom
- Bouton "Créer une tâche" : affiche un TextField inline
- Si le coach a passé un `task_id` connu, pré-sélectionner
- Si le coach a passé une `duration`, pré-sélectionner

**État 2 : `running`**
```
┌─────────────────────────────────────┐
│  🔥 Focus — Lire 20 pages          │
│                                     │
│         ╭─────────╮                 │
│         │  24:35  │                 │
│         ╰─────────╯                 │
│       [progress ring animé]         │
│                                     │
│    [ ⏸ Pause ]    [ ⏹ Stop ]       │
└─────────────────────────────────────┘
```

- Timer circle avec progress ring (réutiliser le style de FireModeView:297-347)
- Mise à jour toutes les secondes
- Boutons pause et stop

**État 3 : `paused`**
```
┌─────────────────────────────────────┐
│  🔥 Focus — Lire 20 pages  (pause) │
│                                     │
│         ╭─────────╮                 │
│         │  24:35  │                 │
│         ╰─────────╯                 │
│                                     │
│    [ ▶ Reprendre ]  [ ⏹ Stop ]     │
└─────────────────────────────────────┘
```

**État 4 : `completed`**
```
┌─────────────────────────────────────┐
│  🎉 Session terminée !              │
│  25 minutes de focus                │
│                                     │
│  Tu as terminé "Lire 20 pages" ?   │
│  [ ✅ Oui ]   [ Pas encore ]       │
│                                     │
│  [confetti animation overlay]       │
└─────────────────────────────────────┘
```

- Confetti animation (réutiliser `FullScreenCelebration` de Cards.swift:88-154 ou une version inline)
- Si tâche liée : prompt de validation
- Si pas de tâche : juste célébration

### 3.5 NOUVEAU : Logique timer dans ChatViewModel

**Fichier à modifier** : `Focus/ViewModels/ChatViewModel.swift`

Ajouter les méthodes de gestion du timer inline :

```swift
// MARK: - Inline Focus Timer

private var focusTimer: Timer?
private var focusTimerMessageId: UUID?

func startInlineFocusTimer(messageId: UUID, taskId: String?, taskTitle: String?, duration: Int) {
    focusTimerMessageId = messageId

    // 1. Mettre à jour la card data
    updateFocusTimerCard(messageId: messageId) { data in
        data.state = .running
        data.taskId = taskId
        data.taskTitle = taskTitle
        data.duration = duration
        data.timeRemaining = duration * 60
    }

    // 2. Créer session backend
    Task {
        let session = try? await store?.startSession(durationMinutes: duration, description: taskTitle)
        if let sessionId = session?.id {
            updateFocusTimerCard(messageId: messageId) { data in
                data.sessionId = sessionId
            }
        }
    }

    // 3. Start app blocking
    let blocker = ScreenTimeAppBlockerService.shared
    if blocker.isBlockingEnabled {
        blocker.startBlocking()
    }

    // 4. Start Live Activity
    LiveActivityManager.shared.startLiveActivity(
        sessionId: UUID().uuidString,
        totalDuration: duration,
        description: taskTitle
    )

    // 5. Start widget session
    store?.startWidgetSession(durationMinutes: duration, emoji: nil, description: taskTitle)

    // 6. Start tick loop
    startFocusTimerLoop()
}

func pauseInlineFocusTimer(messageId: UUID) { ... }
func resumeInlineFocusTimer(messageId: UUID) { ... }
func stopInlineFocusTimer(messageId: UUID) { ... }
func completeFocusTimer(messageId: UUID) { ... }  // Timer reached 0

func validateFocusTimerTask(messageId: UUID, completed: Bool) {
    // Si completed: toggle task via API + coach reaction
    // Mettre à jour la card en état final
}

private func updateFocusTimerCard(messageId: UUID, mutate: (inout ChatCardData.FocusTimerCardData) -> Void) {
    guard let index = messages.firstIndex(where: { $0.id == messageId }),
          case .focusTimer(var data) = messages[index].cardData else { return }
    mutate(&data)
    messages[index].cardData = .focusTimer(data)
    saveMessages()
}

private func startFocusTimerLoop() {
    focusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.focusTimerTick()
        }
    }
}

private func focusTimerTick() {
    guard let messageId = focusTimerMessageId,
          let index = messages.firstIndex(where: { $0.id == messageId }),
          case .focusTimer(var data) = messages[index].cardData,
          data.state == .running else { return }

    data.timeRemaining = max(0, (data.timeRemaining ?? 0) - 1)

    if data.timeRemaining == 0 {
        data.state = .completed
        // Stop blocking, end Live Activity, end widget, complete backend
        completeFocusTimer(messageId: messageId)
    }

    messages[index].cardData = .focusTimer(data)

    // Update Live Activity every 5 seconds
    if (data.timeRemaining ?? 0) % 5 == 0 {
        let progress = 1.0 - Double(data.timeRemaining ?? 0) / Double(data.duration * 60)
        LiveActivityManager.shared.updateLiveActivity(
            timeRemaining: data.timeRemaining ?? 0,
            progress: progress,
            isPaused: false
        )
    }
}
```

### 3.6 MODIFIER : Tool definition (ajouter task_id et task_title)

**Fichier** : `Focus/Services/BackboardService.swift` (dans `assistantTemplate`)

**Avant** :
```swift
tool("start_focus_session", "Démarre une session de focus.", {
    "duration_minutes": param("integer", "Durée en minutes (25, 50, 90 ou personnalisé)"),
})
```

**Après** :
```swift
tool("start_focus_session", "Démarre une session de focus inline dans le chat. Le timer apparaît directement dans la conversation.", {
    "duration_minutes": param("integer", "Durée en minutes (25, 50, 90 ou personnalisé)"),
    "task_id": param("string", "ID de la tâche à associer (optionnel, obtenu via get_today_tasks)"),
    "task_title": param("string", "Titre de la tâche à associer (optionnel)"),
})
```

### 3.7 MODIFIER : BackboardSideEffect

**Fichier** : `Focus/Models/BackboardModels.swift:100`

Enrichir le case pour transporter task_id et task_title :

```swift
case startFocusSession(duration: Int?, taskId: String?, taskTitle: String?)
```

Et mettre à jour `executeToolCall` dans BackboardService.swift:285-287 :

```swift
case "start_focus_session":
    let duration = args["duration_minutes"] as? Int
    let taskId = args["task_id"] as? String
    let taskTitle = args["task_title"] as? String
    return (
        toJSON(["started": true, "duration_minutes": duration ?? 25]),
        [.startFocusSession(duration: duration, taskId: taskId, taskTitle: taskTitle)]
    )
```

### 3.8 MODIFIER : System Prompt (instructions au coach)

**Fichier** : `Focus/Services/BackboardService.swift` (dans `assistantTemplate`, system prompt)

Ajouter dans la section "COMMENT UTILISER LES TOOLS" :

```
- Quand l'utilisateur veut se concentrer ou lancer un timer, utilise start_focus_session.
  Le timer apparaîtra directement dans le chat (pas de redirection).
  Si l'utilisateur mentionne une tâche spécifique, appelle d'abord get_today_tasks pour récupérer l'ID,
  puis passe task_id et task_title à start_focus_session.
  Si pas de tâche mentionnée, passe seulement duration_minutes — l'utilisateur pourra choisir dans le timer.
```

### 3.9 MODIFIER : `InlineFocusTimerCard` — Création de tâche inline

Dans la card, quand l'utilisateur clique "+ Créer une tâche" :
1. Afficher un `TextField` dans la card
2. À la validation, appeler l'API existante : `apiClient.request(endpoint: .createCalendarTask(...))`
3. Rafraîchir `store.todaysTasks`
4. Pré-sélectionner la nouvelle tâche dans le picker

Réutiliser le endpoint existant de `BackboardService.createTask(args:)` (BackboardService.swift:248-250) :
```swift
// L'endpoint API est dans APIClient.swift
case .createCalendarTask(let params) // POST /calendar/tasks
```

---

## 4. Fichiers à Modifier (résumé)

| Fichier | Action | Quoi |
|---------|--------|------|
| `Focus/ViewModels/ChatViewModel.swift` | MODIFIER | Ajouter `FocusTimerCardData` dans `ChatCardData`, logique timer inline, méthodes start/pause/resume/stop/complete/validate |
| `Focus/Views/Chat/ChatView.swift` | MODIFIER | Ajouter `InlineFocusTimerCard` view, case dans `ReplikaMessageBubble` switch |
| `Focus/Models/BackboardModels.swift` | MODIFIER | Enrichir `startFocusSession` avec taskId/taskTitle |
| `Focus/Services/BackboardService.swift` | MODIFIER | Mettre à jour tool definition + `executeToolCall` + system prompt |
| `Focus/Navigation/Navigation.swift` | NON MODIFIÉ | L'AppRouter n'est plus utilisé pour le timer inline |
| `Focus/ViewModels/FireModeViewModel.swift` | NON MODIFIÉ | Reste pour le flow "calendar task → fullscreen timer" |
| `tests/test_coach_scenarios.py` | MODIFIER | Ajouter scénarios de test (voir section 5) |

---

## 5. Tests à Ajouter (`tests/test_coach_scenarios.py`)

### 5.1 Nouveau simulate_tool_output

Ajouter dans `simulate_tool_output()` (ligne ~303) le support des nouveaux args :

```python
if tool_name == "start_focus_session":
    dur = tool_args.get("duration_minutes", 25)
    task_id = tool_args.get("task_id")
    task_title = tool_args.get("task_title")
    return json.dumps({
        "started": True,
        "duration_minutes": dur,
        "task_id": task_id,
        "task_title": task_title,
    })
```

### 5.2 Nouveau check helper

Ajouter un helper pour vérifier qu'un argument optionnel est présent :

```python
def check_tool_arg_present(tool_name: str, arg_name: str):
    """A specific tool was called with the given argument present (non-None)."""
    def fn(result):
        for tc in result.get("tool_calls_log", []):
            if tc["name"] == tool_name:
                actual = tc["arguments"].get(arg_name)
                if actual is not None:
                    return True, f"{arg_name}={actual}"
                return False, f"{arg_name} not present in arguments"
        return False, f"tool '{tool_name}' not called"
    return fn
```

### 5.3 Scénarios à ajouter dans `SCENARIOS`

```python
# S13 — Focus session avec tâche spécifique
{
    "name": "S13. Focus sur tâche spécifique",
    "message": "Je veux me concentrer 25 minutes sur Lire 20 pages",
    "context": {},
    "checks": [
        ("start_focus_session called", check_tool_called("start_focus_session")),
        ("get_today_tasks called (to find task ID)", check_tool_called("get_today_tasks")),
        ("Duration is 25", check_tool_arg("start_focus_session", "duration_minutes", 25)),
        ("task_id passed", check_tool_arg_present("start_focus_session", "task_id")),
    ],
},
# S14 — Focus session sans tâche (sélection dans la card)
{
    "name": "S14. Focus sans tâche précise",
    "message": "Lance un timer de 50 minutes",
    "context": {},
    "checks": [
        ("start_focus_session called", check_tool_called("start_focus_session")),
        ("Duration is 50", check_tool_arg("start_focus_session", "duration_minutes", 50)),
    ],
},
# S15 — Focus implicite (sans durée)
{
    "name": "S15. Focus implicite sans durée",
    "message": "Je veux me concentrer",
    "context": {},
    "checks": [
        ("start_focus_session called", check_tool_called("start_focus_session")),
        ("Response not empty", check_min_length(10)),
    ],
},
# S16 — Focus avec blocage d'apps explicite
{
    "name": "S16. Focus avec demande de blocage",
    "message": "Bloque mes apps et lance un timer de 25 minutes",
    "context": {},
    "checks": [
        ("start_focus_session called", check_tool_called("start_focus_session")),
        ("block_apps called", check_tool_called("block_apps")),
    ],
},
# S17 — Focus sur tâche inexistante (doit créer)
{
    "name": "S17. Focus sur tâche à créer",
    "message": "Lance un focus de 25 min sur Préparer la présentation",
    "context": {},
    "checks": [
        ("get_today_tasks called first", check_tool_called("get_today_tasks")),
        ("start_focus_session called", check_tool_called("start_focus_session")),
        # Le coach devrait soit créer la tâche, soit lancer le focus sur une description libre
        ("Response not empty", check_min_length(10)),
    ],
},
```

### 5.4 Mise à jour du S11 existant

Le S11 existant (`"Lance une session focus de 25 minutes"`) reste valide. Les checks sont déjà corrects :
```python
("start_focus_session tool called", check_tool_called("start_focus_session")),
("Duration is 25", check_tool_arg("start_focus_session", "duration_minutes", 25)),
```

---

## 6. Design System à Respecter

### Tokens
- Background card : `ColorTokens.surfaceElevated` ou `Color.white.opacity(0.95)` (comme les autres cards inline)
- Texte principal : `ColorTokens.textPrimary`
- Texte secondaire : `ColorTokens.textSecondary`
- Progress ring : gradient `ColorTokens.primaryStart` → `ColorTokens.primaryEnd`
- Bouton principal : gradient `ColorTokens.fireGradient`
- Coins arrondis : `RadiusTokens.lg` (16pt)
- Espacement : `SpacingTokens.md` (12pt), `SpacingTokens.lg` (16pt)
- Font : `.satoshi()` extension

### Référence visuelle (timer circle existant)
Voir `FireModeView.swift:297-347` pour le style du timer ring (background circle, progress arc, glow effect).

### Cards inline existantes (pattern à suivre)
Voir `ChatView.swift:800-1301` — toutes les cards inline utilisent :
```swift
VStack(alignment: .leading, spacing: SpacingTokens.sm) { ... }
    .padding(SpacingTokens.lg)
    .background(Color.white.opacity(0.95))
    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
```

---

## 7. Points d'Attention

1. **Persistance** : `FocusTimerCardData` doit être `Codable` car les messages sont persistés dans UserDefaults (`SimpleChatPersistence`). Le timer state sera restauré au relaunch (mais le timer sera mort — gérer le cas "session stale").

2. **Timer en background** : Quand l'app passe en background, le `Timer` Swift s'arrête. Utiliser `sessionStartTime` + `duration` pour recalculer `timeRemaining` au retour (comme FireModeViewModel le fait déjà via `checkForStaleSessions`).

3. **Live Activity** : Le timer inline doit quand même démarrer une Live Activity (via `LiveActivityManager.shared`) pour que l'utilisateur voie le countdown sur l'écran de verrouillage.

4. **Widget** : Le widget session doit aussi être mis à jour (`store.startWidgetSession()`) pour afficher le countdown en temps réel.

5. **App Blocking** : Le blocage d'apps doit être démarré automatiquement si `enableBlockingDuringFocus` est activé et si l'utilisateur a configuré ses apps (`ScreenTimeAppBlockerService.shared`).

6. **Confetti** : Réutiliser `FullScreenCelebration` (Cards.swift:88-154) ou créer une version plus petite pour la card inline. L'animation confetti existante utilise des particules avec `withAnimation(.spring())`.

7. **Coexistence avec FireModeView** : FireModeView fullscreen reste pour le flow "lancer depuis le calendrier" (tap sur tâche → timer). Le timer inline est uniquement pour le chat.

8. **Une seule session active** : S'assurer qu'on ne peut pas avoir un timer inline ET un FireModeView actif en même temps. Vérifier `FireModeViewModel.timerState != .idle` avant de permettre le start inline.

9. **ScrollView** : Quand le timer démarre, s'assurer que le `ScrollViewReader` scroll vers la card timer (le message contenant la card).

10. **Haptic feedback** : Réutiliser les mêmes haptics que FireModeViewModel (`.medium` au start, `.light` au pause/resume, `.warning` au stop, `.success` au complete).
