"""
Focus Voice Agent — LiveKit + Gradium TTS + Speechmatics STT + Backboard AI
Handles real-time voice conversations for the Focus (Volta) iOS app.
"""

import os
import re
import json
import logging
from datetime import datetime

import httpx
from livekit.agents import AgentSession, Agent, RunContext, WorkerOptions, cli, StopResponse
from livekit.agents import room_io
from livekit.plugins import speechmatics, gradium, silero, noise_cancellation
from livekit.plugins.turn_detector.multilingual import MultilingualModel

logger = logging.getLogger("focus-agent")
logger.setLevel(logging.DEBUG)

BACKBOARD_URL = "https://app.backboard.io/api"
BACKBOARD_API_KEY = os.environ.get("BACKBOARD_API_KEY", "")
FOCUS_API_URL = os.environ.get("FOCUS_API_URL", "https://firelevel-api.onrender.com")


def _split_sentences(text: str) -> list[str]:
    """Split text into sentences for incremental TTS."""
    parts = re.split(r'(?<=[.!?])\s+', text.strip())
    return [s.strip() for s in parts if s.strip()]


class FocusCoachAgent(Agent):
    """Voice coach agent for Focus app. Routes through Backboard AI."""

    def __init__(self):
        super().__init__(
            instructions=(
                "Tu es Volta, un coach de productivité bienveillant et motivant. "
                "Tu parles en français. Tu aides les utilisateurs à planifier leur journée, "
                "rester concentrés et atteindre leurs objectifs. "
                "Sois concis dans tes réponses (2-3 phrases max). "
                "Utilise un ton chaleureux et encourageant."
            ),
        )
        self._assistant_id: str | None = None
        self._user_token: str | None = None
        self._thread_id: str | None = None
        self._lang: str = "fr"
        self._metadata_extracted = False
        self._http: httpx.AsyncClient | None = None
        self._headers: dict = {}

    async def on_enter(self):
        """Called when agent joins the room. Set up HTTP client and greet."""
        # Persistent HTTP client — reuse connections, skip TLS handshake
        self._http = httpx.AsyncClient(
            timeout=httpx.Timeout(30.0, connect=5.0),
        )
        self._headers = {
            "X-API-Key": BACKBOARD_API_KEY,
            "Content-Type": "application/json",
        }

        room = self.session.room_io.room
        participants = list(room.remote_participants.values())
        logger.info(f"on_enter: {len(participants)} remote participants")

        mode = self._extract_metadata_from_participants(participants)

        # Pre-fetch assistant ID and create thread while greeting plays
        if not self._assistant_id:
            await self._fetch_assistant_id()
        if self._assistant_id and not self._thread_id:
            try:
                self._thread_id = await self._create_thread()
                logger.info(f"Pre-created thread: {self._thread_id}")
            except Exception as e:
                logger.error(f"Failed to pre-create thread: {e}")

        greeting = self._build_greeting(mode)
        self.session.say(greeting)

    def _build_greeting(self, mode: str) -> str:
        """Build greeting based on language, mode, and time of day."""
        hour = datetime.now().hour
        is_fr = self._lang.startswith("fr")

        if mode == "start_day":
            return ("Salut ! Dis-moi ce que tu veux faire aujourd'hui, avec les horaires si possible."
                    if is_fr else "Hi! Tell me what you want to do today, with times if possible.")
        if mode == "voice_assistant":
            return ("Bonjour ! Je suis prêt à t'aider. Quelles sont tes priorités ?"
                    if is_fr else "Hello! I'm ready to help. What are your priorities?")

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

    def _extract_metadata_from_participants(self, participants) -> str:
        """Extract assistant ID and mode from participant metadata."""
        mode = "voice_call"
        for p in participants:
            if not p.metadata:
                continue
            logger.info(f"  participant: {p.identity}, metadata: {p.metadata[:100]}")
            try:
                meta = json.loads(p.metadata)
                mode = meta.get("mode", "voice_call")
                bid = meta.get("bid", "")
                self._assistant_id = bid if bid else None
                self._user_token = meta.get("at")
                self._lang = meta.get("lang", "fr")
                logger.info(f"Metadata keys: {list(meta.keys())}, bid={repr(bid)}")
                if self._assistant_id:
                    logger.info(f"Got assistant_id: {self._assistant_id}")
                else:
                    logger.warning("No assistant_id (bid) in metadata")
                if self._user_token:
                    logger.info("Got auth token from metadata")
                logger.info(f"User language: {self._lang}")
                self._metadata_extracted = True
                return mode
            except json.JSONDecodeError:
                if p.metadata in ("voice_call", "voice_assistant", "start_day"):
                    mode = p.metadata
        return mode

    def _ensure_metadata(self):
        """Lazily extract metadata if not done yet (handles race condition)."""
        if self._metadata_extracted:
            return
        room = self.session.room_io.room
        participants = list(room.remote_participants.values())
        self._extract_metadata_from_participants(participants)

    async def _fetch_assistant_id(self):
        """Fetch assistant ID from user profile if not in metadata."""
        if self._assistant_id:
            return
        if not self._user_token:
            logger.error("No auth token — cannot fetch assistant ID")
            return

        client = self._http or httpx.AsyncClient(timeout=10)
        try:
            resp = await client.get(
                f"{FOCUS_API_URL}/me",
                headers={"Authorization": f"Bearer {self._user_token}"},
            )
            if resp.status_code == 200:
                data = resp.json()
                self._assistant_id = data.get("backboard_assistant_id")
                if self._assistant_id:
                    logger.info(f"Fetched assistant_id from /me: {self._assistant_id}")
                else:
                    logger.warning(f"/me response keys: {list(data.keys())}")
            else:
                logger.error(f"/me failed: {resp.status_code} {resp.text[:200]}")
        except Exception as e:
            logger.error(f"Failed to fetch /me: {e}")
        finally:
            if not self._http:
                await client.aclose()

    async def llm_node(self, chat_ctx, tools, model_settings):
        """No built-in LLM — we route through Backboard instead."""
        return
        yield  # noqa: unreachable — makes this an async generator

    async def on_user_turn_completed(self, turn_ctx, new_message):
        """Called when user finishes speaking. Filter noise, then send to Backboard."""
        user_text = new_message.text_content

        # Filter empty / very short / noise transcriptions
        if not user_text or not user_text.strip():
            raise StopResponse()

        stripped = user_text.strip()

        # Ignore single words or very short fragments (echo / noise)
        if len(stripped) < 3 or len(stripped.split()) < 2:
            logger.debug(f"Ignoring short transcript: {repr(stripped)}")
            raise StopResponse()

        # Ignore common French filler / noise words
        _noise = {"le", "la", "les", "a", "à", "de", "du", "un", "une",
                  "et", "euh", "ah", "oh", "hm", "hmm", "ok", "au"}
        if stripped.lower() in _noise:
            logger.debug(f"Ignoring noise word: {repr(stripped)}")
            raise StopResponse()

        self._ensure_metadata()

        if not self._assistant_id:
            await self._fetch_assistant_id()

        logger.info(f"User said: {stripped[:100]}")

        try:
            reply = await self._call_backboard(user_text)
            logger.info(f"Backboard reply ({len(reply)} chars): {reply[:100]}")

            # Split into sentences → TTS starts on first sentence immediately
            sentences = _split_sentences(reply)
            if len(sentences) <= 1:
                self.session.say(reply)
            else:
                for sentence in sentences:
                    self.session.say(sentence)

            logger.info(f"Queued {len(sentences)} sentence(s) for TTS")

        except Exception as e:
            logger.error(f"Backboard call failed: {type(e).__name__}: {e}")
            import traceback
            logger.error(traceback.format_exc())
            try:
                err_msg = ("Désolé, j'ai un petit souci technique. Tu peux répéter ?"
                           if self._lang.startswith("fr") else "Sorry, I had a small technical issue. Can you repeat?")
                self.session.say(err_msg)
            except RuntimeError:
                pass

    async def _call_backboard(self, text: str) -> str:
        """Send message to Backboard and return AI reply, handling tool call loops."""
        if not self._assistant_id:
            logger.error("No assistant_id — cannot call Backboard")
            return "Désolé, je n'ai pas pu me connecter. Réessaie."

        if not BACKBOARD_API_KEY:
            logger.error("BACKBOARD_API_KEY not set")
            return "Désolé, la configuration est incomplète."

        if not self._thread_id:
            self._thread_id = await self._create_thread()
            logger.info(f"Created Backboard thread: {self._thread_id}")

        url = f"{BACKBOARD_URL}/threads/{self._thread_id}/messages"
        payload = {"content": text, "stream": False, "memory": "Auto"}

        logger.info(f"Calling Backboard: {url}")
        resp = await self._http.post(url, json=payload, headers=self._headers)
        logger.info(f"Backboard response: {resp.status_code}")
        if resp.status_code != 200:
            logger.error(f"Backboard error: {resp.text[:500]}")
        resp.raise_for_status()
        data = resp.json()

        logger.info(f"Backboard status={data.get('status')}, has_tool_calls={bool(data.get('tool_calls'))}")

        # Tool call loop
        max_rounds = 5
        round_num = 0

        while data.get("status") == "REQUIRES_ACTION" and round_num < max_rounds:
            round_num += 1
            tool_calls = data.get("tool_calls") or []
            run_id = data.get("run_id")

            if not tool_calls or not run_id:
                logger.warning("Missing tool_calls or run_id, breaking.")
                break

            logger.info(f"Tool round {round_num}: {[tc.get('function', {}).get('name', '?') for tc in tool_calls]}")

            outputs = []
            for tc in tool_calls:
                func = tc.get("function", {})
                tool_name = func.get("name", "unknown")
                tool_args = func.get("arguments", "{}")
                tool_id = tc.get("id")
                result = self._execute_tool(tool_name, tool_args)
                outputs.append({"tool_call_id": tool_id, "output": result})

            submit_url = f"{BACKBOARD_URL}/threads/{self._thread_id}/runs/{run_id}/submit-tool-outputs"
            submit_resp = await self._http.post(submit_url, json={"tool_outputs": outputs}, headers=self._headers)
            submit_resp.raise_for_status()
            data = submit_resp.json()
            logger.info(f"After submit: status={data.get('status')}, content={repr(data.get('content'))[:100]}")

        content = data.get("content")
        if content and isinstance(content, str) and content.strip():
            return content.strip()

        logger.warning(f"No content after {round_num} rounds, status={data.get('status')}")
        return ("Hmm, je n'ai pas compris. Tu peux répéter ?"
                if self._lang.startswith("fr") else "Hmm, I didn't understand. Can you repeat?")

    def _execute_tool(self, name: str, arguments: str) -> str:
        """Execute a Backboard tool call in voice mode (simplified responses)."""
        if name == "get_user_context":
            hour = datetime.now().hour
            time_of_day = "morning" if hour < 12 else "afternoon" if hour < 18 else "evening" if hour < 22 else "night"
            return json.dumps({
                "user_name": "utilisateur",
                "streak": 0,
                "tasks_today": 0,
                "tasks_completed": 0,
                "rituals_today": 0,
                "rituals_completed": 0,
                "focus_minutes_today": 0,
                "time_of_day": time_of_day,
                "apps_blocked": False,
                "source": "voice_call",
            })
        elif name in ("get_today_tasks", "get_rituals", "get_quests"):
            return json.dumps([])
        elif name == "show_card":
            return json.dumps({"status": "shown"})
        else:
            logger.info(f"Unhandled tool in voice mode: {name}")
            return json.dumps({"status": "not_available_in_voice_mode"})

    async def _create_thread(self) -> str:
        """Create a new Backboard thread for this voice session."""
        url = f"{BACKBOARD_URL}/assistants/{self._assistant_id}/threads"
        resp = await self._http.post(url, json={}, headers=self._headers)
        resp.raise_for_status()
        data = resp.json()
        return data.get("threadId") or data.get("thread_id") or data["id"]

    async def _send_coach_action(self, action: dict):
        """Send coach action to iOS client via LiveKit data channel."""
        room = self.session.room_io.room
        data = json.dumps(action).encode("utf-8")
        for participant in room.remote_participants.values():
            await room.local_participant.publish_data(
                data,
                topic="coach_action",
                destination_identities=[participant.identity],
            )
        logger.info(f"Sent coach action: {action.get('type', 'unknown')}")


def _get_lang_from_room(room) -> str:
    """Read user language from participant metadata before session starts."""
    for p in room.remote_participants.values():
        if not p.metadata:
            continue
        try:
            meta = json.loads(p.metadata)
            lang = meta.get("lang")
            if lang:
                logger.info(f"Room participant lang: {lang}")
                return lang
        except (json.JSONDecodeError, AttributeError):
            pass
    return "fr"


# French voice IDs from Gradium
GRADIUM_VOICES = {
    "fr": "b35yykvVppLXyw_l",   # Elise - Adult Feminine (France)
    "en": "YTpq7expH9539ERJ",   # Default English
}


async def run_agent(ctx: RunContext):
    """Entry point for the LiveKit agent."""
    lang = _get_lang_from_room(ctx.room)
    logger.info(f"Starting agent with language: {lang}")

    voice_id = GRADIUM_VOICES.get(lang, GRADIUM_VOICES["en"])
    logger.info(f"Using Gradium voice: {voice_id} for lang={lang}")

    session = AgentSession(
        stt=speechmatics.STT(
            language=lang,
            base_url="wss://us.rt.speechmatics.com/v2",
        ),
        tts=gradium.TTS(
            voice_id=voice_id,
            model_name="default",
        ),
        # Turn detection — dynamic model + Silero VAD for accuracy
        turn_detection=MultilingualModel(),
        vad=silero.VAD.load(),
        min_endpointing_delay=0.8,         # Wait 0.8s silence before committing turn (default 0.5)
        max_endpointing_delay=5.0,         # Allow longer thinking pauses (default 3.0)

        # Echo cancellation
        discard_audio_if_uninterruptible=True,

        # Interruption handling — require real speech, not echo/noise
        allow_interruptions=True,
        min_interruption_duration=0.8,     # Need 0.8s of speech to interrupt (default 0.5)
        min_interruption_words=2,          # Need 2+ words to interrupt (default 0)

        # False interruption recovery
        resume_false_interruption=True,
        false_interruption_timeout=1.5,
    )

    await session.start(
        agent=FocusCoachAgent(),
        room=ctx.room,
        # Server-side noise cancellation — removes echo/background voices
        room_input_options=room_io.RoomInputOptions(
            noise_cancellation=noise_cancellation.BVC(),
        ),
    )


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=run_agent))
