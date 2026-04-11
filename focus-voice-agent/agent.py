"""
Focus Voice Agent — LiveKit Agents + Gradium STT/TTS + Blackbox AI LLM
Pre-call: Fetch Backboard memories + Focus API context → enriched system prompt
During: Fast LLM (gemini-2.5-flash via Blackbox) for real-time voice
Post-call: Send transcript to Backboard for memory update + tool execution
"""

import asyncio
import json
import logging
import os
import time
from datetime import datetime, timedelta

import httpx
from dotenv import load_dotenv
from livekit import agents, rtc
from livekit.agents import AgentSession, RoomInputOptions, RunContext, function_tool
from livekit.plugins import openai, gradium, silero

logger = logging.getLogger("volta-agent")
logger.setLevel(logging.DEBUG)


def _elapsed(start: float) -> str:
    return f"{(time.time() - start) * 1000:.0f}ms"

load_dotenv(override=True)

FOCUS_API_URL = os.environ.get("FOCUS_API_URL", "https://firelevel-api.onrender.com")
BACKBOARD_API_URL = "https://app.backboard.io/api"
BACKBOARD_API_KEY = os.environ.get("BACKBOARD_API_KEY", "")

# Gradium voice IDs
GRADIUM_VOICE_FR = "b35yykvVppLXyw_l"
GRADIUM_VOICE_EN = "YTpq7expH9539ERJ"


# =============================================================================
# Backboard Integration
# =============================================================================

async def fetch_backboard_memories(assistant_id: str) -> list[str]:
    """Fetch memories from Backboard for the user's assistant."""
    if not assistant_id or not BACKBOARD_API_KEY:
        logger.info("Skipping Backboard memories (no assistant_id or API key)")
        return []

    headers = {"X-API-Key": BACKBOARD_API_KEY}
    t0 = time.time()
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.get(
                f"{BACKBOARD_API_URL}/assistants/{assistant_id}/memories",
                headers=headers,
            )
            logger.info("Backboard memories fetch: %s (status=%d)", _elapsed(t0), resp.status_code)
            if resp.status_code == 200:
                data = resp.json()
                memories = data.get("memories", [])
                result = [m.get("content", "") for m in memories if m.get("content")]
                logger.info("Got %d memories", len(result))
                return result
            else:
                logger.warning("Backboard memories error: %s", resp.text[:200])
        except Exception as e:
            logger.error("Backboard memories EXCEPTION after %s: %s", _elapsed(t0), e)
    return []


async def execute_tool_via_api(name: str, args: dict, auth_token: str) -> str:
    """Execute a Backboard tool call by calling the Focus API directly."""
    t0 = time.time()
    headers = {"Authorization": f"Bearer {auth_token}", "Content-Type": "application/json"}

    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            if name == "get_user_context":
                resp = await client.get(f"{FOCUS_API_URL}/me", headers=headers)
                result = json.dumps(resp.json()) if resp.status_code == 200 else '{"error": "failed"}'

            elif name == "get_today_tasks":
                today = datetime.now().strftime("%Y-%m-%d")
                resp = await client.get(f"{FOCUS_API_URL}/calendar/tasks?date={today}", headers=headers)
                result = json.dumps({"tasks": resp.json()}) if resp.status_code == 200 else '{"tasks": []}'

            elif name == "get_rituals":
                resp = await client.get(f"{FOCUS_API_URL}/routines", headers=headers)
                result = json.dumps({"rituals": resp.json()}) if resp.status_code == 200 else '{"rituals": []}'

            elif name == "get_quests":
                resp = await client.get(f"{FOCUS_API_URL}/quests", headers=headers)
                result = json.dumps({"quests": resp.json()}) if resp.status_code == 200 else '{"quests": []}'

            elif name == "create_task":
                body = {
                    "title": args.get("title", "Nouvelle tâche"),
                    "date": args.get("date", datetime.now().strftime("%Y-%m-%d")),
                }
                if args.get("priority"):
                    body["priority"] = args["priority"]
                if args.get("time_block"):
                    body["time_block"] = args["time_block"]
                if args.get("quest_id"):
                    body["quest_id"] = args["quest_id"]
                resp = await client.post(f"{FOCUS_API_URL}/calendar/tasks", headers=headers, json=body)
                result = json.dumps({"created": resp.status_code in (200, 201), "title": body["title"]})

            elif name == "complete_task":
                task_id = args.get("task_id", "")
                resp = await client.post(f"{FOCUS_API_URL}/calendar/tasks/{task_id}/complete", headers=headers)
                result = json.dumps({"completed": resp.status_code == 200, "task_id": task_id})

            elif name == "uncomplete_task":
                task_id = args.get("task_id", "")
                resp = await client.post(f"{FOCUS_API_URL}/calendar/tasks/{task_id}/uncomplete", headers=headers)
                result = json.dumps({"uncompleted": resp.status_code == 200, "task_id": task_id})

            elif name == "create_routine":
                body = {
                    "title": args.get("title", "Nouveau rituel"),
                    "icon": args.get("icon", "star"),
                    "frequency": args.get("frequency", "daily"),
                }
                if args.get("scheduled_time"):
                    body["scheduled_time"] = args["scheduled_time"]
                resp = await client.post(f"{FOCUS_API_URL}/routines", headers=headers, json=body)
                result = json.dumps({"created": resp.status_code in (200, 201), "title": body["title"]})

            elif name == "complete_routine":
                routine_id = args.get("routine_id", "")
                resp = await client.post(f"{FOCUS_API_URL}/routines/{routine_id}/complete", headers=headers)
                result = json.dumps({"completed": resp.status_code == 200, "routine_id": routine_id})

            elif name == "create_quest":
                body = {
                    "title": args.get("title", "Nouvel objectif"),
                    "area": args.get("area", "other"),
                }
                if args.get("target_date"):
                    body["target_date"] = args["target_date"]
                resp = await client.post(f"{FOCUS_API_URL}/quests", headers=headers, json=body)
                result = json.dumps({"created": resp.status_code in (200, 201), "title": body["title"]})

            else:
                logger.info("Tool '%s' not mapped, acknowledged in %s", name, _elapsed(t0))
                return json.dumps({"status": "acknowledged", "note": f"Tool {name} not available in voice agent"})

            logger.info("Tool '%s' executed in %s", name, _elapsed(t0))
            return result

        except Exception as e:
            logger.error("Tool '%s' EXCEPTION after %s: %s", name, _elapsed(t0), e)
            return json.dumps({"error": str(e)})


async def send_transcript_to_backboard(
    assistant_id: str,
    transcript: list[dict],
    auth_token: str | None = None,
    mode: str = "voice_call",
    planning_scope: str = "",
):
    """Send the voice conversation transcript to Backboard for memory and tool execution."""
    if not assistant_id or not BACKBOARD_API_KEY or not transcript:
        return

    headers = {
        "X-API-Key": BACKBOARD_API_KEY,
        "Content-Type": "application/json",
    }

    t_total = time.time()
    async with httpx.AsyncClient(timeout=60.0) as client:
        # Create a new thread for this voice session
        t0 = time.time()
        try:
            resp = await client.post(
                f"{BACKBOARD_API_URL}/assistants/{assistant_id}/threads",
                headers=headers,
                json={},
            )
            logger.info("Backboard create thread: %s (status=%d)", _elapsed(t0), resp.status_code)
            if resp.status_code not in (200, 201):
                logger.warning("Thread creation error: %s", resp.text[:200])
                return
            thread_id = resp.json().get("thread_id")
            if not thread_id:
                logger.warning("No thread_id in response")
                return
            logger.info("Thread created: %s", thread_id)
        except Exception as e:
            logger.error("Thread creation EXCEPTION after %s: %s", _elapsed(t0), e)
            return

        # Format transcript as a summary message
        lines = []
        for msg in transcript:
            role = "Utilisateur" if msg["role"] == "user" else "Coach"
            lines.append(f"{role}: {msg['text']}")

        summary = (
            "Voici la conversation vocale qu'on vient d'avoir:\n\n"
            + "\n".join(lines)
            + "\n\nAnalyse cette conversation et effectue les actions demandées "
            "(créer des tâches, compléter des rituels, etc.) si nécessaire. "
            "Mets aussi à jour ta mémoire avec les informations importantes."
        )

        if mode == "planning":
            scope_label = {"today": "aujourd'hui", "tomorrow": "demain", "2days": "les 2 prochains jours", "week": "la semaine"}.get(planning_scope, "aujourd'hui")
            summary += (
                f"\n\nIMPORTANT: C'était une session de PLANIFICATION pour {scope_label}. "
                "Utilise create_tasks_batch pour créer TOUTES les tâches mentionnées d'un coup. "
                "Puis appelle show_card(\"planning\") pour afficher le résultat."
            )

        # Send summary as a message (Backboard will process with memory + tool calls)
        t0 = time.time()
        try:
            resp = await client.post(
                f"{BACKBOARD_API_URL}/threads/{thread_id}/messages",
                headers=headers,
                json={
                    "content": summary,
                    "stream": False,
                    "memory": "Auto",
                },
            )
            logger.info("Backboard send transcript: %s (status=%d)", _elapsed(t0), resp.status_code)
            if resp.status_code != 200:
                logger.warning("Transcript error: %s", resp.text[:300])
                return

            logger.info("Transcript sent to Backboard (thread: %s)", thread_id)

            # Handle tool call loop (Backboard may want to execute actions)
            response_data = resp.json()
            max_rounds = 10
            round_num = 0

            while (
                response_data.get("status") == "REQUIRES_ACTION"
                and response_data.get("tool_calls")
                and round_num < max_rounds
            ):
                round_num += 1
                run_id = response_data.get("run_id")
                if not run_id:
                    break

                tool_outputs = []
                for tc in response_data["tool_calls"]:
                    tool_name = tc.get("function", {}).get("name", "")
                    tool_args_str = tc.get("function", {}).get("arguments", "{}")
                    tool_args = json.loads(tool_args_str) if tool_args_str else {}

                    logger.info("Executing post-call tool: %s (args=%s)", tool_name, tool_args_str[:100])

                    if auth_token:
                        output = await execute_tool_via_api(tool_name, tool_args, auth_token)
                    else:
                        output = json.dumps({"status": "acknowledged"})

                    tool_outputs.append({
                        "tool_call_id": tc["id"],
                        "output": output,
                    })

                t_submit = time.time()
                resp = await client.post(
                    f"{BACKBOARD_API_URL}/threads/{thread_id}/runs/{run_id}/submit-tool-outputs",
                    headers=headers,
                    json={"tool_outputs": tool_outputs},
                )
                logger.info("Submit tool outputs round %d: %s (status=%d)", round_num, _elapsed(t_submit), resp.status_code)
                if resp.status_code == 200:
                    response_data = resp.json()
                else:
                    logger.warning("Submit error: %s", resp.text[:200])
                    break

            logger.info("Backboard post-call complete (rounds=%d, total=%s)", round_num, _elapsed(t_total))

        except Exception as e:
            logger.error("Transcript processing EXCEPTION after %s: %s", _elapsed(t_total), e)


# =============================================================================
# System Prompt
# =============================================================================

def build_system_prompt(
    lang: str,
    user_context: dict | None = None,
    memories: list[str] | None = None,
    companion_name: str = "",
    mode: str = "voice_call",
    planning_scope: str = "",
    planning_context: dict | None = None,
) -> str:
    hour = datetime.now().hour
    time_of_day = "matin" if hour < 12 else "après-midi" if hour < 18 else "soirée"

    coach_name = companion_name or "Volta"
    base = (
        f"Tu es {coach_name}, un coach de productivité. "
        "Tu parles en français, de manière directe et chaleureuse.\n\n"
        "RÈGLES:\n"
        "- MAXIMUM 1 phrase par réponse. Sois ultra bref.\n"
        "- Ne demande JAMAIS le créneau ou la priorité. Choisis toi-même intelligemment.\n"
        "- Pas d'emojis, pas de listes, pas de markdown.\n"
        "- Crée les tâches IMMÉDIATEMENT avec create_task dès que l'utilisateur les mentionne.\n"
        "- Ne récapitule pas. Ne demande pas confirmation. Agis direct.\n\n"
        "OUTILS (utilise-les sans attendre):\n"
        "- create_task(title, date, time_block, priority): Crée une tâche. IMPORTANT: le titre doit être COURT (5 mots max). Ex: 'Finir le planning', 'Sport salle', 'Bilan associé'.\n"
        "- create_quest(title, area, term): Crée un objectif (area: career/health/relationships/learning/creativity/other, term: short/medium/long).\n"
        "- block_apps(duration_minutes): Bloque les apps.\n"
        "- unblock_apps(): Débloque les apps.\n"
        "- end_call(): Termine l'appel quand l'utilisateur a fini.\n"
    )

    ctx = f"\nCONTEXTE ACTUEL:\n- Moment: {time_of_day}\n- Langue: {lang}\n"

    if user_context:
        name = user_context.get("name", "")
        if name:
            ctx += f"- Prénom: {name}\n"
        tasks = user_context.get("tasks", [])
        if tasks:
            task_names = [t.get("title", "") for t in tasks[:5] if t.get("title")]
            if task_names:
                ctx += f"- Tâches aujourd'hui: {', '.join(task_names)}\n"
        rituals = user_context.get("rituals", [])
        if rituals:
            ritual_names = [r.get("name", "") for r in rituals[:5] if r.get("name")]
            if ritual_names:
                ctx += f"- Rituels: {', '.join(ritual_names)}\n"
        streak = user_context.get("streak", 0)
        if streak:
            ctx += f"- Streak: {streak} jours\n"
        focus_min = user_context.get("focus_minutes_today", 0)
        if focus_min:
            ctx += f"- Minutes de focus aujourd'hui: {focus_min}\n"

    # Add Backboard memories for personalized context
    if memories:
        ctx += "\nMÉMOIRE (informations des conversations précédentes):\n"
        for mem in memories[:20]:
            ctx += f"- {mem}\n"

    # Planning mode additions
    if mode == "planning" and planning_scope:
        scope_label = {
            "today": "ta journée",
            "tomorrow": "demain",
            "2days": "les 2 prochains jours",
            "week": "ta semaine",
        }.get(planning_scope, "ta journée")

        ctx += f"""
MODE PLANIFICATION — {scope_label}
L'utilisateur te dit ses tâches → tu appelles create_task IMMÉDIATEMENT pour chacune. Pas de récap, pas de confirmation.
Quand il dit une tâche, tu la crées direct et tu dis juste "OK" ou "C'est fait".
Quand il a fini ("c'est bon", "c'est tout", "merci") → end_call.
Ne pose PAS de questions sur le créneau ou la priorité. Choisis selon l'heure actuelle.
"""
        # Inject actual planning data into prompt
        if planning_context and planning_context.get("days"):
            ctx += "\nÉTAT ACTUEL DU PLANNING:\n"
            for day in planning_context["days"]:
                date_str = day.get("date", "")
                tasks = day.get("tasks", [])
                events = day.get("calendar_events", [])
                ctx += f"- {date_str}:"
                if tasks:
                    task_titles = [t.get("title", "") for t in tasks[:8] if t.get("title")]
                    ctx += f" Tâches: {', '.join(task_titles)}."
                if events:
                    event_titles = [e.get("title", "") for e in events[:5] if e.get("title")]
                    ctx += f" Calendrier: {', '.join(event_titles)}."
                if not tasks and not events:
                    ctx += " Vide."
                ctx += "\n"

    return base + ctx


# =============================================================================
# Fetch User Context
# =============================================================================

async def fetch_all_context_parallel(auth_token: str | None) -> tuple[dict | None, list[str]]:
    """Fetch user context + Backboard memories with maximum parallelism.

    Phase 1: GET /me (need backboard_assistant_id for phase 2)
    Phase 2: tasks + routines + Backboard memories in parallel via asyncio.gather
    """
    if not auth_token:
        logger.info("No auth token, skipping context fetch")
        return None, []

    headers = {"Authorization": f"Bearer {auth_token}"}
    bb_headers = {"X-API-Key": BACKBOARD_API_KEY}
    ctx: dict = {}

    async with httpx.AsyncClient(timeout=10.0) as client:
        # Phase 1: GET /me (need backboard_assistant_id for memories)
        t0 = time.time()
        try:
            resp = await client.get(f"{FOCUS_API_URL}/me", headers=headers)
            logger.info("GET /me: %s (status=%d)", _elapsed(t0), resp.status_code)
            if resp.status_code == 200:
                data = resp.json()
                ctx["name"] = data.get("first_name") or data.get("name", "")
                ctx["streak"] = data.get("streak", 0)
                ctx["backboard_assistant_id"] = data.get("backboard_assistant_id", "")
                ctx["companion_name"] = data.get("companion_name", "")
                logger.info("User: %s, streak=%s, bb_id=%s", ctx["name"], ctx["streak"], ctx.get("backboard_assistant_id", "none"))
            else:
                logger.warning("/me error: %s", resp.text[:200])
        except Exception as e:
            logger.error("/me EXCEPTION: %s", e)

        # Phase 2: tasks + routines + memories in parallel
        bb_id = ctx.get("backboard_assistant_id", "")
        today = datetime.now().strftime("%Y-%m-%d")

        async def fetch_tasks():
            t = time.time()
            try:
                r = await client.get(f"{FOCUS_API_URL}/calendar/tasks?date={today}", headers=headers)
                logger.info("GET /calendar/tasks: %s (status=%d)", _elapsed(t), r.status_code)
                if r.status_code == 200:
                    data = r.json()
                    return data if isinstance(data, list) else []
            except Exception as e:
                logger.error("/calendar/tasks EXCEPTION: %s", e)
            return []

        async def fetch_routines():
            t = time.time()
            try:
                r = await client.get(f"{FOCUS_API_URL}/routines", headers=headers)
                logger.info("GET /routines: %s (status=%d)", _elapsed(t), r.status_code)
                if r.status_code == 200:
                    data = r.json()
                    return data if isinstance(data, list) else []
            except Exception as e:
                logger.error("/routines EXCEPTION: %s", e)
            return []

        async def fetch_memories():
            if not bb_id or not BACKBOARD_API_KEY:
                return []
            t = time.time()
            try:
                r = await client.get(f"{BACKBOARD_API_URL}/assistants/{bb_id}/memories", headers=bb_headers)
                logger.info("Backboard memories: %s (status=%d)", _elapsed(t), r.status_code)
                if r.status_code == 200:
                    return [m.get("content", "") for m in r.json().get("memories", []) if m.get("content")]
            except Exception as e:
                logger.error("Backboard memories EXCEPTION: %s", e)
            return []

        t0 = time.time()
        tasks, routines, memories = await asyncio.gather(fetch_tasks(), fetch_routines(), fetch_memories())
        logger.info("Phase 2 (tasks+routines+memories): %s | tasks=%d, routines=%d, memories=%d",
                     _elapsed(t0), len(tasks), len(routines), len(memories))

        ctx["tasks"] = tasks
        ctx["rituals"] = routines

    return (ctx if ctx else None), memories


def build_greeting(lang: str, name: str = "", coach_name: str = "", mode: str = "voice_call", planning_scope: str = "", planning_context: dict | None = None) -> str:
    hour = datetime.now().hour
    intro = f"Salut, c'est {coach_name}" if coach_name else "Salut"
    intro_en = f"Hey, it's {coach_name}" if coach_name else "Hey"

    # Planning mode greeting
    if mode == "planning" and lang.startswith("fr"):
        scope_label = {
            "today": "ta journée",
            "tomorrow": "demain",
            "2days": "les deux prochains jours",
            "week": "ta semaine",
        }.get(planning_scope, "ta journée")

        greeting = f"{intro} ! Dis-moi tes tâches"
        if name:
            greeting = f"{intro} {name} ! Dis-moi tes tâches"
        return greeting

    if lang.startswith("fr"):
        if hour < 12:
            return f"{intro} ! Comment tu vas ce matin {name} ?" if name else f"{intro} ! Comment tu vas ce matin ?"
        elif hour < 18:
            return f"{intro} ! Comment se passe ta journée {name} ?" if name else f"{intro} ! Comment se passe ta journée ?"
        else:
            return f"{intro} ! Comment s'est passée ta journée {name} ?" if name else f"{intro} ! Comment s'est passée ta journée ?"
    else:
        if hour < 12:
            return f"{intro_en}! How are you doing this morning {name}?" if name else f"{intro_en}! How are you doing this morning?"
        elif hour < 18:
            return f"{intro_en}! How's your day going {name}?" if name else f"{intro_en}! How's your day going?"
        else:
            return f"{intro_en}! How was your day {name}?" if name else f"{intro_en}! How was your day?"


# =============================================================================
# Planning Context Fetcher
# =============================================================================

async def fetch_planning_context(auth_token: str, scope: str) -> dict | None:
    """Fetch extended planning context: tasks + calendar events for the scope period."""
    headers = {"Authorization": f"Bearer {auth_token}"}
    today = datetime.now()

    # Determine dates to fetch
    if scope == "tomorrow":
        dates = [(today + timedelta(days=1)).strftime("%Y-%m-%d")]
    elif scope == "2days":
        dates = [today.strftime("%Y-%m-%d"), (today + timedelta(days=1)).strftime("%Y-%m-%d")]
    elif scope == "week":
        dates = [(today + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(7)]
    else:
        dates = [today.strftime("%Y-%m-%d")]

    days = []
    async with httpx.AsyncClient(timeout=10.0) as client:
        for date_str in dates:
            tasks = []
            events = []
            try:
                r = await client.get(f"{FOCUS_API_URL}/calendar/tasks?date={date_str}", headers=headers)
                if r.status_code == 200:
                    data = r.json()
                    tasks = data if isinstance(data, list) else []
            except Exception as e:
                logger.error("Planning context - tasks for %s: %s", date_str, e)

            try:
                r = await client.get(f"{FOCUS_API_URL}/calendar/events?date={date_str}", headers=headers)
                if r.status_code == 200:
                    data = r.json()
                    events = data if isinstance(data, list) else []
            except Exception as e:
                logger.error("Planning context - events for %s: %s", date_str, e)

            days.append({"date": date_str, "tasks": tasks, "calendar_events": events})

    logger.info("Planning context fetched: %d days, %d total tasks, %d total events",
                len(days),
                sum(len(d["tasks"]) for d in days),
                sum(len(d["calendar_events"]) for d in days))
    return {"days": days}


# =============================================================================
# Volta Agent
# =============================================================================

class VoltaAgent(agents.Agent):
    def __init__(self, instructions: str, lang: str = "fr", room: rtc.Room | None = None, auth_token: str | None = None, mode: str = "voice_call") -> None:
        super().__init__(instructions=instructions)
        self._lang = lang
        self._room = room
        self._auth_token = auth_token
        self._mode = mode
        self._tasks_created = 0
        self._http = httpx.AsyncClient(timeout=5.0)

    @function_tool(name="block_apps")
    async def tool_block_apps(self, context: RunContext, duration_minutes: int = 30) -> str:
        """Bloque les apps de distraction de l'utilisateur pendant la duree indiquee (en minutes)."""
        if not self._room:
            return "Erreur: pas de connexion a la room."
        payload = json.dumps({
            "type": "coach_action",
            "action": "block_apps",
            "duration_minutes": duration_minutes,
        }).encode()
        await self._room.local_participant.publish_data(payload, reliable=True)
        logger.info("📱 Sent block_apps data message (duration=%d)", duration_minutes)
        return f"Apps bloquees pour {duration_minutes} minutes."

    @function_tool(name="unblock_apps")
    async def tool_unblock_apps(self, context: RunContext) -> str:
        """Debloque les apps de distraction de l'utilisateur immediatement."""
        if not self._room:
            return "Erreur: pas de connexion a la room."
        payload = json.dumps({
            "type": "coach_action",
            "action": "unblock_apps",
        }).encode()
        await self._room.local_participant.publish_data(payload, reliable=True)
        logger.info("📱 Sent unblock_apps data message")
        return "Apps debloquees."

    @function_tool(name="end_call")
    async def tool_end_call(self, context: RunContext) -> str:
        """Termine l'appel vocal. En mode planning, tu DOIS avoir appele create_task au moins une fois avant."""
        if not self._room:
            return "Appel deja termine."
        # In planning mode, refuse to end if no tasks were created
        if self._mode == "planning" and self._tasks_created == 0:
            return "ERREUR: Tu n'as cree aucune tache ! Utilise create_task pour chaque tache discutee AVANT d'appeler end_call. Rappel: create_task(title, date, time_block, priority)."
        # Wait 3s to let TTS finish before disconnecting
        await asyncio.sleep(3)
        payload = json.dumps({
            "type": "coach_action",
            "action": "end_call",
        }).encode()
        await self._room.local_participant.publish_data(payload, reliable=True)
        logger.info("📱 Sent end_call data message (tasks_created=%d)", self._tasks_created)
        return "Appel termine."

    @function_tool(name="create_task")
    async def tool_create_task(
        self, context: RunContext,
        title: str,
        date: str = "",
        time_block: str = "",
        priority: str = "",
    ) -> str:
        """Cree une tache pour l'utilisateur. Utilise pendant le resume de fin pour creer toutes les taches discutees.

        Args:
            title: Le titre de la tache
            date: La date au format YYYY-MM-DD (par defaut aujourd'hui)
            time_block: Le creneau: morning, afternoon, ou evening
            priority: La priorite: low, medium, ou high
        """
        if not self._auth_token:
            return "Erreur: pas de token d'authentification."
        headers = {"Authorization": f"Bearer {self._auth_token}", "Content-Type": "application/json"}
        # Validate and sanitize params
        task_date = date if date and len(date) == 10 else datetime.now().strftime("%Y-%m-%d")
        # Auto time_block based on current hour if not specified
        if time_block not in ("morning", "afternoon", "evening"):
            hour = datetime.now().hour
            time_block = "morning" if hour < 12 else "afternoon" if hour < 18 else "evening"
        # Default priority
        if priority not in ("low", "medium", "high"):
            priority = "medium"
        body: dict = {"title": title, "date": task_date, "time_block": time_block, "priority": priority}
        try:
            resp = await self._http.post(f"{FOCUS_API_URL}/calendar/tasks", headers=headers, json=body)
            created = resp.status_code in (200, 201)
            if not created:
                logger.warning("📋 create_task FAIL: status=%d body=%s", resp.status_code, resp.text[:200])
        except Exception as e:
            logger.error("📋 create_task EXCEPTION: %s", e)
            return f"Erreur reseau lors de la creation de '{title}'. Reessaie."
        if created:
            self._tasks_created += 1
        logger.info("📋 create_task '%s' → %s (total: %d)", title, "OK" if created else f"FAIL({resp.status_code})", self._tasks_created)
        if created and self._room:
            payload = json.dumps({"type": "coach_action", "action": "task_created"}).encode()
            await self._room.local_participant.publish_data(payload, reliable=True)
        return f"Tache '{title}' creee." if created else f"Erreur lors de la creation de '{title}'."

    @function_tool(name="create_quest")
    async def tool_create_quest(
        self, context: RunContext,
        title: str,
        area: str = "other",
        term: str = "short",
    ) -> str:
        """Cree un objectif pour l'utilisateur.

        Args:
            title: Le titre de l'objectif
            area: Le domaine: health, learning, career, relationships, creativity, other
            term: L'horizon: short (court terme), medium (moyen terme), long (long terme)
        """
        if not self._auth_token:
            return "Erreur: pas de token d'authentification."
        headers = {"Authorization": f"Bearer {self._auth_token}", "Content-Type": "application/json"}
        body = {"title": title, "area": area, "term": term}
        resp = await self._http.post(f"{FOCUS_API_URL}/quests", headers=headers, json=body)
        created = resp.status_code in (200, 201)
        logger.info("🎯 create_quest '%s' (term=%s) → %s", title, term, "OK" if created else f"FAIL({resp.status_code})")
        if created and self._room:
            payload = json.dumps({"type": "coach_action", "action": "quest_created"}).encode()
            await self._room.local_participant.publish_data(payload, reliable=True)
        return f"Objectif '{title}' cree." if created else f"Erreur lors de la creation de '{title}'."


# =============================================================================
# Entrypoint
# =============================================================================

async def entrypoint(ctx: agents.JobContext):
    t_entry = time.time()
    logger.info("=== VOLTA AGENT STARTING ===")
    await ctx.connect(auto_subscribe=agents.AutoSubscribe.AUDIO_ONLY)
    logger.info("Connected to room in %s", _elapsed(t_entry))

    # Skip Focus Rooms — group sessions don't need the AI agent
    if ctx.room.name and ctx.room.name.startswith("focus-room-"):
        logger.info("Skipping Focus Room: %s (not an AI session)", ctx.room.name)
        return

    # Read metadata from room (set by backend) or job dispatch
    metadata_str = ctx.room.metadata or "{}"
    try:
        meta = json.loads(metadata_str)
    except json.JSONDecodeError:
        meta = {}

    if not meta.get("auth_token") and ctx.job.metadata:
        try:
            meta.update(json.loads(ctx.job.metadata))
        except json.JSONDecodeError:
            pass

    auth_token = meta.get("auth_token")
    lang = meta.get("lang", "fr")
    logger.info("Room metadata: lang=%s, has_auth_token=%s", lang, bool(auth_token))

    # OPTIMIZATION: Start fetching context WHILE waiting for participant
    context_task = asyncio.create_task(fetch_all_context_parallel(auth_token))

    participant = await ctx.wait_for_participant()
    logger.info("Participant joined in %s", _elapsed(t_entry))

    # Merge participant metadata if room/job metadata was empty
    if not auth_token and participant.metadata:
        try:
            p_meta = json.loads(participant.metadata)
            meta.update(p_meta)
            # If we got a new auth_token from participant, re-fetch context
            if p_meta.get("auth_token"):
                auth_token = p_meta["auth_token"]
                lang = meta.get("lang", lang)
                context_task.cancel()
                context_task = asyncio.create_task(fetch_all_context_parallel(auth_token))
        except json.JSONDecodeError:
            pass

    # Await context (likely already done — was fetching during wait_for_participant)
    user_context, memories = await context_task
    logger.info("Context ready in %s (parallel with wait)", _elapsed(t_entry))

    backboard_assistant_id = (user_context or {}).get("backboard_assistant_id", "")

    # Companion name: prefer metadata (instant), fallback to /me response
    companion_name = meta.get("companion_name") or (user_context or {}).get("companion_name", "")

    mode = meta.get("mode", "voice_call")
    planning_scope = meta.get("planning_scope", "")
    logger.info("Mode: %s, planning_scope: %s", mode, planning_scope)

    # For planning mode, fetch extended context (week tasks + calendar events)
    planning_context = None
    if mode == "planning" and auth_token:
        planning_context = await fetch_planning_context(auth_token, planning_scope)

    system_prompt = build_system_prompt(lang, user_context, memories, companion_name=companion_name, mode=mode, planning_scope=planning_scope, planning_context=planning_context)
    logger.info("System prompt length: %d chars", len(system_prompt))

    # Choose voice: prefer metadata override, fallback to lang-based default
    voice_id = meta.get("voice_id") or (GRADIUM_VOICE_FR if lang.startswith("fr") else GRADIUM_VOICE_EN)
    logger.info("TTS voice_id=%s (from_metadata=%s)", voice_id, bool(meta.get("voice_id")))

    # Create session: Gradium STT + Blackbox AI LLM (fast model) + Gradium TTS
    llm_model = "gemini-2.5-flash"
    logger.info("LLM model: %s via Google Gemini", llm_model)
    session = AgentSession(
        stt=gradium.STT(sample_rate=24000),
        llm=openai.LLM(
            model=llm_model,
            base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
            api_key=os.environ.get("GOOGLE_API_KEY", ""),
        ),
        tts=gradium.TTS(voice_id=voice_id, json_config={"speed": 1.25}),
        vad=silero.VAD.load(
            min_silence_duration=0.4,
            activation_threshold=0.45,
        ),
        max_tool_steps=20,
        # Fluidity tuning
        preemptive_generation=True,
        min_endpointing_delay=0.6,
        max_endpointing_delay=2.5,
        allow_interruptions=True,
        min_interruption_duration=0.5,
        min_consecutive_speech_delay=0.3,
        false_interruption_timeout=2.0,
        resume_false_interruption=True,
    )

    # Track conversation for post-call Backboard sync
    transcript: list[dict] = []

    @session.on("conversation_item_added")
    def on_conversation_item(event):
        item = event.item
        role = getattr(item, "role", None)
        text = getattr(item, "text_content", None) or ""
        if not text or role not in ("user", "assistant"):
            return
        transcript_role = "user" if role == "user" else "agent"
        transcript.append({"role": transcript_role, "text": text})
        label = "USER" if role == "user" else "AGENT"
        logger.info("%s: %s", label, text[:120])

    @session.on("agent_state_changed")
    def on_agent_state_changed(event):
        state = event.state
        if state == "thinking":
            payload = json.dumps({
                "type": "agent_speaking",
                "is_speaking": False,
                "state": "thinking",
            }).encode()
            asyncio.create_task(
                ctx.room.local_participant.publish_data(payload, reliable=True)
            )

    t0 = time.time()
    await session.start(
        room=ctx.room,
        agent=VoltaAgent(instructions=system_prompt, lang=lang, room=ctx.room, auth_token=auth_token, mode=mode),
    )
    logger.info("Session started in %s", _elapsed(t0))

    # In planning mode, increase patience (users pause between task items)
    if mode == "planning":
        session.update_options(min_endpointing_delay=1.0, max_endpointing_delay=4.0)

    # Send greeting with user's first name and coach name
    user_name = (user_context or {}).get("name", "")
    greeting = build_greeting(lang, user_name, coach_name=companion_name, mode=mode, planning_scope=planning_scope, planning_context=planning_context)
    logger.info("Greeting: %s", greeting)
    session.say(greeting, add_to_chat_ctx=True, allow_interruptions=False)
    logger.info("Greeting queued (direct TTS, no LLM)")
    logger.info("=== AGENT READY === (total setup: %s)", _elapsed(t_entry))

    # Register shutdown callback: send transcript to Backboard (fire-and-forget, 5s timeout)
    # Tasks are created in real-time via tools, so this is just for memory/context
    async def on_shutdown():
        logger.info("=== SHUTDOWN CALLBACK === (transcript: %d messages)", len(transcript))
        if transcript and backboard_assistant_id:
            try:
                logger.info("Sending voice transcript (%d messages) to Backboard...", len(transcript))
                await asyncio.wait_for(
                    send_transcript_to_backboard(
                        assistant_id=backboard_assistant_id,
                        transcript=transcript,
                        auth_token=auth_token,
                        mode=mode,
                        planning_scope=planning_scope,
                    ),
                    timeout=5.0,
                )
                logger.info("Post-call Backboard sync done")
            except asyncio.TimeoutError:
                logger.warning("Post-call Backboard sync timed out (5s) — skipping (tasks already created via tools)")
            except Exception as e:
                logger.warning("Post-call Backboard sync error: %s — skipping", e)
        else:
            logger.info("No transcript to send (empty or no Backboard assistant)")

    ctx.add_shutdown_callback(on_shutdown)


if __name__ == "__main__":
    agents.cli.run_app(
        agents.WorkerOptions(entrypoint_fnc=entrypoint),
    )
