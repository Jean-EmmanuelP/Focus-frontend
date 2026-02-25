# Focus Voice Agent (LiveKit)

Real-time voice agent for the Focus (Volta) iOS app.
Uses **Speechmatics** for STT (French) and **OpenAI** for TTS via LiveKit.

## Setup

```bash
cd focus-voice-agent
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Copy `.env` and fill in missing keys (OPENAI_API_KEY).

## Run locally

```bash
python agent.py dev
```

## Deploy to LiveKit Cloud

```bash
lk cloud deploy
```

## Architecture

```
iOS App ←→ LiveKit Room ←→ Agent (this)
                              ├── Speechmatics STT (fr)
                              ├── Focus Backend (/chat/message)
                              └── OpenAI TTS (nova)
```
