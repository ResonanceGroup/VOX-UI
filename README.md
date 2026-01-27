# agent-zero-voice-ui

Monorepo containing:

- `frontend/`: VOX-UI Flutter app (LiveKit client + orb UI)
- `backend/`: LiveKit Agent worker (STT/TTS + A2A call to Agent Zero)

## High-level run order

1. Start a local LiveKit server (Docker)
2. Generate a LiveKit token for the room/user
3. Run Agent Zero A2A endpoint (your Agent Zero instance)
4. Run the backend worker (joins the room and drives the agent)
5. Run the Flutter app (connects with LiveKit URL + token)

## Notes
- Don’t commit secrets: backend `.env` should stay local.
