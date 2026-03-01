"""
Focus Voice Bot — Pipecat + Daily + Speechmatics STT + Gemini LLM + Cartesia TTS
Spawned per-session by bot_runner.py.
"""

import asyncio
import json
import os
import sys
from datetime import datetime

import httpx
from dotenv import load_dotenv
from loguru import logger

from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.frames.frames import LLMRunFrame, TransportMessageFrame, TransportMessageUrgentFrame
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import (
    LLMContextAggregatorPair,
    LLMUserAggregatorParams,
)
from pipecat.services.google.llm import GoogleLLMService
from pipecat.services.google.tts import GeminiTTSService
from pipecat.services.speechmatics.stt import SpeechmaticsSTTService
from pipecat.transports.daily.transport import DailyParams, DailyTransport

load_dotenv(override=True)

logger.remove(0)
logger.add(sys.stderr, level="DEBUG")

FOCUS_API_URL = os.environ.get("FOCUS_API_URL", "https://firelevel-api.onrender.com")

# Gemini TTS voices
GEMINI_VOICE_FR = "Aoede"    # Good for French
GEMINI_VOICE_EN = "Kore"     # Default English


def _build_system_prompt(lang: str, user_context: dict | None = None) -> str:
    """Build system prompt with user context baked in."""
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


async def _fetch_user_context(token: str | None) -> dict | None:
    """Fetch user context from Focus backend before session starts."""
    if not token:
        logger.warning("No auth token, skipping context fetch")
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
                logger.info(f"Fetched /me: name={ctx['name']}")
        except Exception as e:
            logger.warning(f"Failed to fetch /me: {e}")

        today = datetime.now().strftime("%Y-%m-%d")
        try:
            resp = await client.get(f"{FOCUS_API_URL}/calendar/tasks?date={today}", headers=headers)
            if resp.status_code == 200:
                ctx["tasks"] = resp.json() if isinstance(resp.json(), list) else []
                logger.info(f"Fetched tasks: {len(ctx['tasks'])}")
        except Exception as e:
            logger.warning(f"Failed to fetch tasks: {e}")

        try:
            resp = await client.get(f"{FOCUS_API_URL}/routines", headers=headers)
            if resp.status_code == 200:
                ctx["rituals"] = resp.json() if isinstance(resp.json(), list) else []
                logger.info(f"Fetched rituals: {len(ctx['rituals'])}")
        except Exception as e:
            logger.warning(f"Failed to fetch rituals: {e}")

    return ctx if ctx else None


def _build_greeting(lang: str) -> str:
    hour = datetime.now().hour
    is_fr = lang.startswith("fr")
    if is_fr:
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


async def run_bot(room_url: str, token: str, config: dict):
    """Main bot entry point — creates pipeline and runs until participant leaves."""
    lang = config.get("lang", "fr")
    mode = config.get("mode", "voice_call")
    auth_token = config.get("auth_token")

    logger.info(f"Starting bot: room={room_url}, lang={lang}, mode={mode}")

    # Pre-fetch user context
    user_context = await _fetch_user_context(auth_token)
    system_prompt = _build_system_prompt(lang, user_context)

    # Transport
    transport = DailyTransport(
        room_url,
        token,
        "Volta",
        DailyParams(
            audio_in_enabled=True,
            audio_out_enabled=True,
            transcription_enabled=False,  # We use Speechmatics directly
        ),
    )

    # STT — Speechmatics
    stt = SpeechmaticsSTTService(
        api_key=os.getenv("SPEECHMATICS_API_KEY", ""),
        params=SpeechmaticsSTTService.InputParams(
            language=lang,
        ),
    )

    # LLM — Gemini Flash
    llm = GoogleLLMService(
        api_key=os.getenv("GOOGLE_API_KEY", ""),
        model="gemini-2.0-flash",
    )

    # TTS — Gemini
    voice_id = GEMINI_VOICE_FR if lang.startswith("fr") else GEMINI_VOICE_EN
    tts = GeminiTTSService(
        api_key=os.getenv("GOOGLE_API_KEY", ""),
        voice_id=voice_id,
    )

    # Context
    messages = [{"role": "system", "content": system_prompt}]
    context = LLMContext(messages)
    user_aggregator, assistant_aggregator = LLMContextAggregatorPair(
        context,
        user_params=LLMUserAggregatorParams(vad_analyzer=SileroVADAnalyzer()),
    )

    # Pipeline
    pipeline = Pipeline(
        [
            transport.input(),
            stt,
            user_aggregator,
            llm,
            tts,
            transport.output(),
            assistant_aggregator,
        ]
    )

    task = PipelineTask(
        pipeline,
        params=PipelineParams(
            enable_metrics=True,
            enable_usage_metrics=True,
        ),
    )

    @transport.event_handler("on_first_participant_joined")
    async def on_first_participant_joined(transport, participant):
        logger.info(f"Participant joined: {participant['id']}")
        # Greet the user
        greeting = _build_greeting(lang)
        messages.append({"role": "assistant", "content": greeting})
        # Send transcription to iOS via app message
        await transport.send_app_message(
            {"type": "agent_transcription", "text": greeting},
            participant["id"],
        )
        # Trigger the LLM to speak the greeting
        await task.queue_frames([LLMRunFrame()])

    @transport.event_handler("on_participant_left")
    async def on_participant_left(transport, participant, reason):
        logger.info(f"Participant left: {participant['id']}, reason: {reason}")
        await task.cancel()

    @transport.event_handler("on_app_message")
    async def on_app_message(transport, message, sender):
        logger.info(f"App message from {sender}: {message}")

    runner = PipelineRunner()
    await runner.run(task)
    logger.info("Bot finished")


if __name__ == "__main__":
    # For local testing: python bot.py <room_url> <token>
    if len(sys.argv) < 3:
        print("Usage: python bot.py <room_url> <token> [config_json]")
        sys.exit(1)

    room_url = sys.argv[1]
    token = sys.argv[2]
    config = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}

    asyncio.run(run_bot(room_url, token, config))
