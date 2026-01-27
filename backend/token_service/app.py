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
