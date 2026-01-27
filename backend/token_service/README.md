# LiveKit Token Service (Local)

Minimal HTTP service that mints LiveKit JWTs for the VOX-UI app.

## Why
The LiveKit API secret must not be shipped in the mobile app. This service keeps it on your LAN machine and returns short-lived tokens.

## Environment
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `LIVEKIT_WS_URL` (optional, informational)

## Run
```bash
cd backend/token_service
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export LIVEKIT_API_KEY=...
export LIVEKIT_API_SECRET=...
export LIVEKIT_WS_URL=ws://localhost:7880

uvicorn app:app --host 0.0.0.0 --port 8787
```

## API
- `GET /health`
- `POST /token`

Example:
```bash
curl -s http://localhost:8787/token \
  -H 'content-type: application/json' \
  -d '{"room":"vox","identity":"phone","name":"Jason","canPublish":true,"canSubscribe":true}'
```


## Clawdbot agent discovery

If you run Clawdbot Gateway on your network, you can expose a safe agent list to the UI (without putting the gateway token in the browser):

- `GET /clawdbot/agents` → `{ "agents": ["main", ...] }`

Environment variables:
- `CLAWDBOT_GATEWAY_BASE_URL` (example: `http://10.0.0.50:1234`)
- `CLAWDBOT_GATEWAY_TOKEN` (Bearer token, keep server-side)
- `CLAWDBOT_AGENT_ID` (default agent id, default `main`)
- `CLAWDBOT_AGENTS` (optional comma list fallback)
