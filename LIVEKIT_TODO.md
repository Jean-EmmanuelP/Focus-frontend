# LiveKit Voice Mode - TODO

## Remaining Steps

### 1. OpenAI API Key (required for TTS)
- [ ] Add your OpenAI API key to `focus-voice-agent/.env`
- Replace `<your-openai-api-key>` with your actual key
- This is used by the Python agent for text-to-speech (OpenAI TTS, voice "nova")

### 2. Deploy Python Agent
- [ ] Local test: `cd focus-voice-agent && python agent.py dev`
- [ ] Production: `lk cloud deploy`

### 3. Deploy Backend
- [ ] Deploy backend with new LiveKit env vars (LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
- [ ] New endpoint: `POST /voice/livekit-token`

### 4. Test End-to-End
- [ ] Build iOS app in Xcode (Cmd+B)
- [ ] Open VoiceCallView, test connection + STT + TTS
- [ ] Open VoiceAssistantView, test conversation flow
- [ ] Open StartTheDayVoiceView, test voice planning
- [ ] Test interruptions (talk while agent speaks)
- [ ] Test coach actions (ask to create a task)

## Implementation Summary (Completed)

| Component | Status |
|-----------|--------|
| LiveKitVoiceService.swift | Done |
| VoiceCallViewModel refactor | Done |
| VoiceAssistantView refactor | Done |
| StartTheDayVoiceView refactor | Done |
| Python agent (focus-voice-agent/) | Done |
| Backend POST /voice/livekit-token | Done |
| LiveKit SPM linked to target | Done |
| Config.plist + .env.local | Done |
