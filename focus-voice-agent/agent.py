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
from datetime import datetime

import httpx
from dotenv import load_dotenv
from livekit import agents, rtc
from livekit.agents import AgentSession, RoomInputOptions
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
GRADIUM_VOICE_FR = "YTpq7expH9539ERJ"
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
                resp = await client.post(f"{FOCUS_API_URL}/calendar/tasks/{task_id}/complete", headers=headers)
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
            role = "Utilisateur" if msg["role"] == "user" else "Volta"
            lines.append(f"{role}: {msg['text']}")

        summary = (
            "Voici la conversation vocale qu'on vient d'avoir:\n\n"
            + "\n".join(lines)
            + "\n\nAnalyse cette conversation et effectue les actions demandées "
            "(créer des tâches, compléter des rituels, etc.) si nécessaire. "
            "Mets aussi à jour ta mémoire avec les informations importantes."
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
) -> str:
    hour = datetime.now().hour
    time_of_day = "matin" if hour < 12 else "après-midi" if hour < 18 else "soirée"

    base = (
        "Tu es Volta, un coach de productivité bienveillant et motivant. "
        "Tu parles en français de manière naturelle et chaleureuse. "
        "Tu aides les utilisateurs à planifier leur journée, rester concentrés et atteindre leurs objectifs.\n\n"
        "RÈGLES IMPORTANTES:\n"
        "- Sois TRÈS concis: 1-2 phrases max par réponse\n"
        "- Parle naturellement, comme un ami bienveillant\n"
        "- Pas d'emojis (c'est de la voix)\n"
        "- Pas de listes ou de formatage markdown\n"
        "- Pose une question de suivi pour garder la conversation\n\n"
        "ACTIONS POSSIBLES:\n"
        "Quand l'utilisateur te demande d'effectuer une action, confirme naturellement que c'est fait. "
        "Par exemple: créer une tâche, compléter un rituel, bloquer les apps, créer un objectif, etc. "
        "Dis simplement que c'est noté ou fait. Les actions seront exécutées automatiquement après l'appel.\n"
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

    return base + ctx


# =============================================================================
# Fetch User Context
# =============================================================================

async def fetch_user_context(token: str | None) -> dict | None:
    if not token:
        logger.info("No auth token, skipping user context fetch")
        return None

    headers = {"Authorization": f"Bearer {token}"}
    ctx = {}

    async with httpx.AsyncClient(timeout=10.0) as client:
        t0 = time.time()
        try:
            resp = await client.get(f"{FOCUS_API_URL}/me", headers=headers)
            logger.info("GET /me: %s (status=%d)", _elapsed(t0), resp.status_code)
            if resp.status_code == 200:
                data = resp.json()
                ctx["name"] = data.get("first_name") or data.get("name", "")
                ctx["streak"] = data.get("streak", 0)
                ctx["backboard_assistant_id"] = data.get("backboard_assistant_id", "")
                logger.info("User: %s, streak=%s, bb_id=%s", ctx["name"], ctx["streak"], ctx.get("backboard_assistant_id", "none"))
            else:
                logger.warning("/me error: %s", resp.text[:200])
        except Exception as e:
            logger.error("/me EXCEPTION: %s", e)

        today = datetime.now().strftime("%Y-%m-%d")
        t0 = time.time()
        try:
            resp = await client.get(f"{FOCUS_API_URL}/calendar/tasks?date={today}", headers=headers)
            logger.info("GET /calendar/tasks: %s (status=%d)", _elapsed(t0), resp.status_code)
            if resp.status_code == 200:
                ctx["tasks"] = resp.json() if isinstance(resp.json(), list) else []
                logger.info("Tasks today: %d", len(ctx["tasks"]))
        except Exception as e:
            logger.error("/calendar/tasks EXCEPTION: %s", e)

        t0 = time.time()
        try:
            resp = await client.get(f"{FOCUS_API_URL}/routines", headers=headers)
            logger.info("GET /routines: %s (status=%d)", _elapsed(t0), resp.status_code)
            if resp.status_code == 200:
                ctx["rituals"] = resp.json() if isinstance(resp.json(), list) else []
                logger.info("Rituals: %d", len(ctx["rituals"]))
        except Exception as e:
            logger.error("/routines EXCEPTION: %s", e)

    return ctx if ctx else None


def build_greeting(lang: str, name: str = "") -> str:
    hour = datetime.now().hour
    if lang.startswith("fr"):
        if hour < 12:
            return f"Salut {name} ! Comment tu vas ce matin ?" if name else "Salut ! Comment tu vas ce matin ?"
        elif hour < 18:
            return f"Salut {name} ! Comment se passe ta journée ?" if name else "Salut ! Comment se passe ta journée ?"
        else:
            return f"Salut {name} ! Comment s'est passée ta journée ?" if name else "Salut ! Comment s'est passée ta journée ?"
    else:
        if hour < 12:
            return f"Hey {name}! How are you doing this morning?" if name else "Hey! How are you doing this morning?"
        elif hour < 18:
            return f"Hey {name}! How's your day going?" if name else "Hey! How's your day going?"
        else:
            return f"Hey {name}! How was your day?" if name else "Hey! How was your day?"


# =============================================================================
# Volta Agent
# =============================================================================

class VoltaAgent(agents.Agent):
    def __init__(self, instructions: str, lang: str = "fr") -> None:
        super().__init__(instructions=instructions)
        self._lang = lang


# =============================================================================
# Entrypoint
# =============================================================================

async def entrypoint(ctx: agents.JobContext):
    t_entry = time.time()
    logger.info("=== VOLTA AGENT STARTING ===")
    await ctx.connect(auto_subscribe=agents.AutoSubscribe.AUDIO_ONLY)
    logger.info("Connected to room in %s", _elapsed(t_entry))

    # Read metadata from room (set by backend) or participant fallback
    metadata_str = ctx.room.metadata or "{}"
    try:
        meta = json.loads(metadata_str)
    except json.JSONDecodeError:
        meta = {}

    # Also check job metadata (from dispatch)
    if not meta.get("auth_token") and ctx.job.metadata:
        try:
            dispatch_meta = json.loads(ctx.job.metadata)
            meta.update(dispatch_meta)
        except json.JSONDecodeError:
            pass

    # Wait for the user participant
    participant = await ctx.wait_for_participant()
    # Merge participant metadata if room metadata was empty
    if not meta.get("auth_token") and participant.metadata:
        try:
            p_meta = json.loads(participant.metadata)
            meta.update(p_meta)
        except json.JSONDecodeError:
            pass

    lang = meta.get("lang", "fr")
    auth_token = meta.get("auth_token")
    logger.info("Room metadata: lang=%s, has_auth_token=%s", lang, bool(auth_token))

    # Fetch user context from backend (includes backboard_assistant_id)
    t0 = time.time()
    user_context = await fetch_user_context(auth_token)
    logger.info("Focus API user context fetched in %s", _elapsed(t0))

    # Fetch Backboard memories for enriched context
    backboard_assistant_id = (user_context or {}).get("backboard_assistant_id", "")
    memories = []
    if backboard_assistant_id:
        logger.info("Backboard assistant_id: %s", backboard_assistant_id)
        memories = await fetch_backboard_memories(backboard_assistant_id)
        logger.info("Loaded %d Backboard memories", len(memories))
    else:
        logger.info("No backboard_assistant_id found in user context")

    system_prompt = build_system_prompt(lang, user_context, memories)
    logger.info("System prompt length: %d chars", len(system_prompt))

    # Choose voice
    voice_id = GRADIUM_VOICE_FR if lang.startswith("fr") else GRADIUM_VOICE_EN

    # Create session: Gradium STT + Blackbox AI LLM (fast model) + Gradium TTS
    llm_model = "blackboxai/google/gemini-2.5-flash"
    logger.info("LLM model: %s via Blackbox AI", llm_model)
    session = AgentSession(
        stt=gradium.STT(sample_rate=24000),
        llm=openai.LLM(
            model=llm_model,
            base_url="https://api.blackbox.ai",
            api_key=os.environ.get("BLACKBOX_API_KEY", ""),
        ),
        tts=gradium.TTS(voice_id=voice_id),
        vad=silero.VAD.load(),
    )

    # Track conversation for post-call Backboard sync
    transcript: list[dict] = []

    @session.on("user_speech_committed")
    def on_user_speech(msg):
        text = getattr(msg, "content", "") or getattr(msg, "text", "") or str(msg)
        if text:
            transcript.append({"role": "user", "text": text})
            logger.info("USER: %s", text[:120])

    @session.on("agent_speech_committed")
    def on_agent_speech(msg):
        text = getattr(msg, "content", "") or getattr(msg, "text", "") or str(msg)
        if text:
            transcript.append({"role": "agent", "text": text})
            logger.info("AGENT: %s", text[:120])

    t0 = time.time()
    await session.start(
        room=ctx.room,
        agent=VoltaAgent(instructions=system_prompt, lang=lang),
    )
    logger.info("Session started in %s", _elapsed(t0))

    # Send greeting with user's first name
    user_name = (user_context or {}).get("name", "")
    greeting = build_greeting(lang, user_name)
    logger.info("Greeting: %s", greeting)
    t0 = time.time()
    await session.generate_reply(instructions=f"Dis exactement: {greeting}")
    logger.info("Greeting generated in %s", _elapsed(t0))
    logger.info("=== AGENT READY === (total setup: %s)", _elapsed(t_entry))

    # Register shutdown callback: send transcript to Backboard when call ends
    async def on_shutdown():
        logger.info("=== SHUTDOWN CALLBACK === (transcript: %d messages)", len(transcript))
        if transcript and backboard_assistant_id:
            logger.info("Sending voice transcript (%d messages) to Backboard...", len(transcript))
            t0 = time.time()
            await send_transcript_to_backboard(
                assistant_id=backboard_assistant_id,
                transcript=transcript,
                auth_token=auth_token,
            )
            logger.info("Post-call Backboard sync total: %s", _elapsed(t0))
        else:
            logger.info("No transcript to send (empty or no Backboard assistant)")

    ctx.add_shutdown_callback(on_shutdown)


if __name__ == "__main__":
    agents.cli.run_app(
        agents.WorkerOptions(entrypoint_fnc=entrypoint),
    )
