"""
Focus Voice Agent — LiveKit Agents + Gradium STT/TTS + Google Gemini LLM
Deployed to LiveKit Cloud. No Pipecat dependency.
"""

import json
import os
from datetime import datetime

import httpx
from dotenv import load_dotenv
from livekit import agents, rtc
from livekit.agents import AgentSession, RoomInputOptions
from livekit.plugins import google, gradium, silero

load_dotenv(override=True)

FOCUS_API_URL = os.environ.get("FOCUS_API_URL", "https://firelevel-api.onrender.com")

# Gradium voice IDs
GRADIUM_VOICE_FR = "YTpq7expH9539ERJ"  # Default voice (French-capable)
GRADIUM_VOICE_EN = "YTpq7expH9539ERJ"


# =============================================================================
# System Prompt
# =============================================================================

def build_system_prompt(lang: str, user_context: dict | None = None) -> str:
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
        "- Pose une question de suivi pour garder la conversation\n"
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

    return base + ctx


# =============================================================================
# Fetch User Context
# =============================================================================

async def fetch_user_context(token: str | None) -> dict | None:
    if not token:
        return None

    headers = {"Authorization": f"Bearer {token}"}
    ctx = {}

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.get(f"{FOCUS_API_URL}/me", headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                ctx["name"] = data.get("first_name") or data.get("name", "")
                ctx["streak"] = data.get("streak", 0)
        except Exception:
            pass

        today = datetime.now().strftime("%Y-%m-%d")
        try:
            resp = await client.get(f"{FOCUS_API_URL}/calendar/tasks?date={today}", headers=headers)
            if resp.status_code == 200:
                ctx["tasks"] = resp.json() if isinstance(resp.json(), list) else []
        except Exception:
            pass

        try:
            resp = await client.get(f"{FOCUS_API_URL}/routines", headers=headers)
            if resp.status_code == 200:
                ctx["rituals"] = resp.json() if isinstance(resp.json(), list) else []
        except Exception:
            pass

    return ctx if ctx else None


def build_greeting(lang: str) -> str:
    hour = datetime.now().hour
    if lang.startswith("fr"):
        if hour < 12:
            return "Bonjour ! Comment ça va ce matin ?"
        elif hour < 18:
            return "Bon après-midi ! Comment se passe ta journée ?"
        else:
            return "Bonsoir ! Comment s'est passée ta journée ?"
    else:
        if hour < 12:
            return "Good morning! How are you doing?"
        elif hour < 18:
            return "Good afternoon! How's your day going?"
        else:
            return "Good evening! How was your day?"


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
    await ctx.connect(auto_subscribe=agents.AutoSubscribe.AUDIO_ONLY)

    # Wait for the user participant and read their metadata
    participant = await ctx.wait_for_participant()
    metadata_str = participant.metadata or "{}"
    try:
        meta = json.loads(metadata_str)
    except json.JSONDecodeError:
        meta = {}

    lang = meta.get("lang", "fr")
    auth_token = meta.get("auth_token")

    # Fetch user context from backend
    user_context = await fetch_user_context(auth_token)
    system_prompt = build_system_prompt(lang, user_context)

    # Choose voice
    voice_id = GRADIUM_VOICE_FR if lang.startswith("fr") else GRADIUM_VOICE_EN

    # Create session: Gradium STT + Google Gemini LLM + Gradium TTS
    session = AgentSession(
        stt=gradium.STT(
            sample_rate=24000,
        ),
        llm=google.LLM(
            model="gemini-2.0-flash",
        ),
        tts=gradium.TTS(
            voice_id=voice_id,
        ),
        vad=silero.VAD.load(),
    )

    await session.start(
        room=ctx.room,
        agent=VoltaAgent(instructions=system_prompt, lang=lang),
    )

    # Send greeting
    greeting = build_greeting(lang)
    await session.generate_reply(instructions=f"Dis exactement: {greeting}")


if __name__ == "__main__":
    agents.cli.run_app(
        agents.WorkerOptions(entrypoint_fnc=entrypoint),
    )
