import os
import time
from typing import Optional

import jwt
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="LiveKit Token Service", version="0.1.0")


def _require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required env var: {name}")
    return value


def _split_csv(value: str) -> list[str]:
    items: list[str] = []
    for part in (value or "").split(","):
        part = part.strip()
        if part:
            items.append(part)
    return items


def _try_get_models(base_url: str, token: str, timeout_s: float = 5.0) -> Optional[list[str]]:
    """Best-effort OpenAI-style model enumeration via GET /v1/models."""
    if not base_url or not token:
        return None

    import json
    import urllib.request

    url = base_url.rstrip("/") + "/v1/models"
    req = urllib.request.Request(url, method="GET")
    req.add_header("Authorization", f"Bearer {token}")

    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            payload = resp.read().decode("utf-8", errors="replace")
    except Exception:
        return None

    try:
        data = json.loads(payload)
    except Exception:
        return None

    models = data.get("data")
    if not isinstance(models, list):
        return None

    ids: list[str] = []
    for m in models:
        if isinstance(m, dict) and isinstance(m.get("id"), str):
            ids.append(m["id"])

    return ids or None


class TokenRequest(BaseModel):
    room: str = Field(..., min_length=1)
    identity: str = Field(..., min_length=1)
    name: Optional[str] = None
    ttlSeconds: int = Field(3600, ge=60, le=24 * 3600)

    canPublish: bool = True
    canSubscribe: bool = True


class TokenResponse(BaseModel):
    token: str
    wsUrl: Optional[str] = None


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/token", response_model=TokenResponse)
def mint_token(req: TokenRequest):
    try:
        api_key = _require_env("LIVEKIT_API_KEY")
        api_secret = _require_env("LIVEKIT_API_SECRET")
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))

    now = int(time.time())
    exp = now + int(req.ttlSeconds)

    # LiveKit expects a JWT with a `video` claim containing grants.
    grants = {
        "roomJoin": True,
        "room": req.room,
        "canPublish": req.canPublish,
        "canSubscribe": req.canSubscribe,
    }

    claims = {
        "iss": api_key,
        "sub": req.identity,
        "name": req.name or req.identity,
        "nbf": now,
        "iat": now,
        "exp": exp,
        "video": grants,
    }

    token = jwt.encode(claims, api_secret, algorithm="HS256")
    return TokenResponse(token=token, wsUrl=os.getenv("LIVEKIT_WS_URL"))


@app.get("/clawdbot/agents")
def clawdbot_agents():
    """Return available Clawdbot agent ids without exposing the gateway token to clients."""

    base_url = os.getenv("CLAWDBOT_GATEWAY_BASE_URL", "").strip()
    token = os.getenv("CLAWDBOT_GATEWAY_TOKEN", "").strip()

    # 1) Best effort: OpenAI-style enumeration if gateway supports it.
    model_ids = _try_get_models(base_url, token)

    agents: list[str] = []
    if model_ids:
        for model_id in model_ids:
            model_id = (model_id or "").strip()
            if model_id.startswith("agent:"):
                agents.append(model_id.split(":", 1)[1])
            elif model_id.startswith("clawdbot:"):
                agents.append(model_id.split(":", 1)[1])
            elif model_id.startswith("clawdbot/"):
                agents.append(model_id.split("/", 1)[1])

    # 2) Fallback: env var list (useful if gateway doesn't implement /v1/models).
    if not agents:
        agents = _split_csv(os.getenv("CLAWDBOT_AGENTS", ""))

    # 3) Always ensure a sane default is present.
    if not agents:
        agents = [os.getenv("CLAWDBOT_AGENT_ID", "main").strip() or "main"]

    # De-dupe, preserve order.
    seen: set[str] = set()
    uniq: list[str] = []
    for a in agents:
        if a and a not in seen:
            seen.add(a)
            uniq.append(a)

    return {"agents": uniq}
