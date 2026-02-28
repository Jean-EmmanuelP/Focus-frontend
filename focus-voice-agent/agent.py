"""
Focus Voice Agent — LiveKit + Speechmatics STT/TTS + Backboard AI
Handles real-time voice conversations for the Focus (Volta) iOS app.
"""

import os
import json
import logging
from datetime import datetime

import httpx
from livekit.agents import AgentSession, Agent, RunContext, WorkerOptions, cli
from livekit.plugins import speechmatics

logger = logging.getLogger("focus-agent")
logger.setLevel(logging.INFO)

BACKBOARD_URL = "https://app.backboard.io/api"
BACKBOARD_API_KEY = os.environ.get("BACKBOARD_API_KEY", "")
FOCUS_API_URL = os.environ.get("FOCUS_API_URL", "https://firelevel-api.onrender.com")


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
        self._metadata_extracted = False

    async def on_enter(self):
        """Called when agent joins the room. Send initial greeting."""
        room = self.session.room_io.room

        participants = list(room.remote_participants.values())
        logger.info(f"on_enter: {len(participants)} remote participants")

        mode = self._extract_metadata_from_participants(participants)

        # Greeting based on time of day
        hour = datetime.now().hour
        if hour < 12:
            greeting = "Bonjour ! Comment ça va ce matin ?"
        elif hour < 18:
            greeting = "Bon après-midi ! Comment se passe ta journée ?"
        else:
            greeting = "Bonsoir ! Comment s'est passée ta journée ?"

        if mode == "start_day":
            greeting = "Salut ! Dis-moi ce que tu veux faire aujourd'hui, avec les horaires si possible."
        elif mode == "voice_assistant":
            greeting = "Bonjour ! Je suis prêt à t'aider à planifier ta journée. Quelles sont tes priorités ?"

        self.session.say(greeting)

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
                self._assistant_id = meta.get("bid")
                self._user_token = meta.get("at")
                if self._assistant_id:
                    logger.info(f"Got assistant_id: {self._assistant_id}")
                if self._user_token:
                    logger.info("Got auth token from metadata")
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
        try:
            async with httpx.AsyncClient(timeout=10) as client:
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
                        logger.warning(f"/me response has no backboard_assistant_id, keys: {list(data.keys())}")
                else:
                    logger.error(f"/me failed: {resp.status_code} {resp.text[:100]}")
        except Exception as e:
            logger.error(f"Failed to fetch /me: {e}")

    async def llm_node(self, chat_ctx, tools, model_settings):
        """No built-in LLM — we route through Backboard instead."""
        return
        yield  # noqa: unreachable — makes this an async generator

    async def on_user_turn_completed(self, turn_ctx, new_message):
        """Called when user finishes speaking. Send to Backboard AI."""
        self._ensure_metadata()

        # Fallback: fetch assistant_id from /me if not in metadata
        if not self._assistant_id:
            await self._fetch_assistant_id()

        user_text = new_message.text_content
        if not user_text or not user_text.strip():
            return

        logger.info(f"User said: {user_text[:100]}")

        try:
            reply = await self._call_backboard(user_text)
            logger.info(f"Backboard reply: {reply[:100]}")

            self.session.say(reply)
            logger.info("session.say() OK")

        except Exception as e:
            logger.error(f"Backboard call failed: {type(e).__name__}: {e}")
            import traceback
            logger.error(traceback.format_exc())
            self.session.say("Désolé, j'ai un petit souci technique. Tu peux répéter ?")

    async def _call_backboard(self, text: str) -> str:
        """Send message to Backboard and return AI reply, handling tool call loops."""
        if not self._assistant_id:
            logger.error("No assistant_id — cannot call Backboard")
            return "Désolé, je n'ai pas pu me connecter. Réessaie."

        if not BACKBOARD_API_KEY:
            logger.error("BACKBOARD_API_KEY not set")
            return "Désolé, la configuration est incomplète."

        headers = {
            "X-API-Key": BACKBOARD_API_KEY,
            "Content-Type": "application/json",
        }

        # Create thread if needed
        if not self._thread_id:
            self._thread_id = await self._create_thread()
            logger.info(f"Created Backboard thread: {self._thread_id}")

        # Send message
        url = f"{BACKBOARD_URL}/threads/{self._thread_id}/messages"
        payload = {"content": text, "stream": False, "memory": "Auto"}

        logger.info(f"Calling Backboard: {url}")
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(url, json=payload, headers=headers)
            logger.info(f"Backboard response: {resp.status_code}")
            if resp.status_code != 200:
                logger.error(f"Backboard error: {resp.text[:200]}")
            resp.raise_for_status()
            data = resp.json()

            # Tool call loop — handle REQUIRES_ACTION (max 5 rounds)
            max_rounds = 5
            round_num = 0
            while data.get("status") == "REQUIRES_ACTION" and round_num < max_rounds:
                round_num += 1
                tool_calls = data.get("toolCalls", [])
                run_id = data.get("runId")
                if not tool_calls or not run_id:
                    break

                logger.info(f"Tool call round {round_num}: {[tc['function']['name'] for tc in tool_calls]}")

                # Execute each tool call with voice-mode responses
                outputs = []
                for tc in tool_calls:
                    tool_name = tc["function"]["name"]
                    result = self._execute_tool(tool_name, tc["function"].get("arguments", "{}"))
                    outputs.append({"toolCallId": tc["id"], "output": result})

                # Submit tool outputs
                submit_url = f"{BACKBOARD_URL}/threads/{self._thread_id}/runs/{run_id}/submit-tool-outputs"
                submit_resp = await client.post(submit_url, json={"toolOutputs": outputs}, headers=headers)
                submit_resp.raise_for_status()
                data = submit_resp.json()
                logger.info(f"After tool submit: status={data.get('status')}, has_content={bool(data.get('content'))}")

            content = data.get("content")
            if content:
                return content

            logger.warning(f"No content after {round_num} tool rounds, keys: {list(data.keys())}")
            return "Hmm, je n'ai pas compris. Tu peux répéter ?"

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
        headers = {
            "X-API-Key": BACKBOARD_API_KEY,
            "Content-Type": "application/json",
        }
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(url, json={}, headers=headers)
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


async def run_agent(ctx: RunContext):
    """Entry point for the LiveKit agent."""
    session = AgentSession(
        stt=speechmatics.STT(
            language="fr",
            base_url="wss://us.rt.speechmatics.com/v2",
        ),
        tts=speechmatics.TTS(
            voice="sarah",
        ),
    )
    await session.start(agent=FocusCoachAgent(), room=ctx.room)


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=run_agent))
