"""
Focus Bot Runner — FastAPI server that spawns Pipecat bot processes.
Called by the Go backend when a user requests a voice session.

POST /start_bot {room_url, token, config}
"""

import asyncio
import json
import os
import subprocess
import sys

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

load_dotenv(override=True)

app = FastAPI(title="Focus Voice Bot Runner")


class StartBotRequest(BaseModel):
    room_url: str
    token: str
    config: dict = {}


class StartBotResponse(BaseModel):
    status: str
    pid: int


@app.post("/start_bot", response_model=StartBotResponse)
async def start_bot(req: StartBotRequest):
    """Spawn a bot subprocess that joins the Daily room."""
    config_json = json.dumps(req.config)

    try:
        proc = subprocess.Popen(
            [sys.executable, "bot.py", req.room_url, req.token, config_json],
            cwd=os.path.dirname(os.path.abspath(__file__)),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return StartBotResponse(status="started", pid=proc.pid)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start bot: {e}")


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", "7860"))
    uvicorn.run("bot_runner:app", host="0.0.0.0", port=port, log_level="info")
