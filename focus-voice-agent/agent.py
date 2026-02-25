"""
Focus Voice Agent — LiveKit + Speechmatics STT + Google TTS
Handles real-time voice conversations for the Focus (Volta) iOS app.
"""

import os
import json
import logging
from datetime import datetime

import httpx
from livekit.agents import AgentSession, Agent, RoomInputOptions, RunContext, WorkerOptions, cli
from livekit.plugins import speechmatics, google

logger = logging.getLogger("focus-agent")
logger.setLevel(logging.INFO)

FOCUS_API_URL = os.environ.get("FOCUS_API_URL", "https://api.firelevel.app/v1")


class FocusCoachAgent(Agent):
    """Voice coach agent for Focus app. Handles STT → Backend AI → TTS loop."""

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
        self._user_token: str | None = None

    async def on_enter(self):
        """Called when agent joins the room. Send initial greeting."""
        # Get metadata from room to determine mode and user context
        room = self.session.room
        metadata = room.metadata or ""
        mode = "voice_call"

        try:
            meta = json.loads(metadata) if metadata else {}
            mode = meta.get("mode", "voice_call")
            self._user_token = meta.get("user_token")
        except json.JSONDecodeError:
            pass

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

    async def on_user_turn_completed(self, turn):
        """Called when user finishes speaking. Process with Focus backend."""
        user_text = turn.text
        if not user_text or not user_text.strip():
            return

        logger.info(f"User said: {user_text[:100]}")

        try:
            response = await self._call_focus_backend(user_text)
            reply = response.get("reply", "Désolé, je n'ai pas compris. Tu peux répéter ?")

            # Speak the reply
            self.session.say(reply)

            # Handle coach actions (send to iOS via data channel)
            action = response.get("action")
            if action:
                await self._send_coach_action(action)

        except Exception as e:
            logger.error(f"Backend call failed: {e}")
            self.session.say("Désolé, j'ai un petit souci technique. Tu peux répéter ?")

    async def _call_focus_backend(self, text: str) -> dict:
        """Send user message to Focus backend and get AI response."""
        headers = {"Content-Type": "application/json"}
        if self._user_token:
            headers["Authorization"] = f"Bearer {self._user_token}"

        payload = {
            "content": text,
            "source": "voice_call",
        }

        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{FOCUS_API_URL}/chat/message",
                json=payload,
                headers=headers,
            )
            resp.raise_for_status()
            return resp.json()

    async def _send_coach_action(self, action: dict):
        """Send coach action to iOS client via LiveKit data channel."""
        room = self.session.room
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
        ),
        tts=google.TTS(
            language="fr-FR",
        ),
    )

    await session.start(
        agent=FocusCoachAgent(),
        room=ctx.room,
        room_input_options=RoomInputOptions(
            # Transcribe user's audio
            transcription_enabled=True,
        ),
    )


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=run_agent))
