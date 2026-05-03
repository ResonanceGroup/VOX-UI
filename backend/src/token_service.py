"""
token_service.py — LiveKit Token Service

Lightweight HTTP server that generates signed LiveKit participant tokens
for client apps. Tokens include RoomConfiguration for Flutter compatibility,
while the AI assistant stays resident in the room via server-side dispatch.

Usage:
    python token_service.py

Endpoints:
    GET /token?identity=<id>&room=<room>
        Returns a signed JWT for the given participant identity and room.
        Both params are optional:
          - identity defaults to a UUID (unique per request)
          - room defaults to LIVEKIT_ROOM in .env (or "ai-assistant-room")

All config is read from config.py (which loads .env automatically).
Relevant .env keys:
    LIVEKIT_URL          Returned to clients so they know where to connect
    LIVEKIT_API_KEY      Used to sign tokens
    LIVEKIT_API_SECRET   Used to sign tokens
    LIVEKIT_ROOM         Default room name (default: ai-assistant-room)
    TOKEN_SERVICE_PORT   Port to listen on (default: 7882)
    TOKEN_TTL_SECONDS    Token lifetime in seconds (default: 86400 = 24h)

Example response:
    {
        "token": "<jwt>",
        "url": "ws://10.0.0.200:7880",
        "room": "ai-assistant-room",
        "identity": "tablet-001"
    }
"""

from __future__ import annotations

import datetime
import json
import logging
import os
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

import asyncio
import threading
import time

from livekit.api import AccessToken, LiveKitAPI, VideoGrants
from livekit.protocol.agent_dispatch import CreateAgentDispatchRequest
from livekit.protocol.room import CreateRoomRequest, ListParticipantsRequest, RoomParticipantIdentity, RoomConfiguration

# config.py loads .env automatically — single source of truth
from config import config

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Token service config (extends AgentConfig with token-service-specific vars)
# ---------------------------------------------------------------------------

AGENT_NAME   = "ai-assistant"
DEFAULT_ROOM = os.environ.get("LIVEKIT_ROOM", "ai-assistant-room")
PORT         = int(os.environ.get("TOKEN_SERVICE_PORT", "7882"))
TOKEN_TTL    = int(os.environ.get("TOKEN_TTL_SECONDS", "86400"))  # 24 hours


# ---------------------------------------------------------------------------
# Token generation
# ---------------------------------------------------------------------------

def create_token(identity: str, room: str) -> str:
    """
    Generate a signed LiveKit JWT for a participant.

    Grants: room_join, can_publish (mic), can_subscribe (AI audio).
    No RoomAgentDispatch — the agent is persistently in the room already.
    """
    token = (
        AccessToken(config.livekit_api_key, config.livekit_api_secret)
        .with_identity(identity)
        .with_name(identity)
        .with_grants(VideoGrants(
            room_join=True,
            room=room,
            can_publish=True,
            can_subscribe=True,
        ))
        # RoomConfiguration is still required for Flutter SDK protocol 16 negotiation.
        # Agents list stays empty because the persistent room service dispatches the
        # resident agent at startup and the watchdog keeps it present.
        .with_room_config(RoomConfiguration(agents=[]))
        .with_ttl(datetime.timedelta(seconds=TOKEN_TTL))
    )
    return token.to_jwt()


async def ensure_room_and_agent() -> None:
    """
    Create the persistent room and ensure the agent is dispatched into it.
    Called once at startup. Safe to re-run on restart.
    """
    api_url = config.livekit_url  # SDK handles ws:// -> http:// internally
    async with LiveKitAPI(api_url, config.livekit_api_key, config.livekit_api_secret) as lk:
        # Create room (idempotent — silently succeeds if already exists)
        try:
            await lk.room.create_room(CreateRoomRequest(
                name=DEFAULT_ROOM,
                empty_timeout=0,
                max_participants=20,
            ))
            logger.info(f"Room '{DEFAULT_ROOM}' created/confirmed")
        except Exception as e:
            logger.info(f"Room '{DEFAULT_ROOM}' already exists: {e}")

        # Check if agent is already in the room (check participants, not dispatch queue)
        try:
            resp = await lk.room.list_participants(ListParticipantsRequest(room=DEFAULT_ROOM))
            existing = [p for p in resp.participants if p.identity.startswith("agent-")]
            if existing:
                logger.info(f"Agent already in '{DEFAULT_ROOM}' ({existing[0].identity}) — skipping dispatch")
                return
        except Exception as e:
            logger.warning(f"Could not check room participants (will dispatch anyway): {e}")

        # Dispatch the agent
        try:
            await lk.agent_dispatch.create_dispatch(CreateAgentDispatchRequest(
                agent_name=AGENT_NAME,
                room=DEFAULT_ROOM,
            ))
            logger.info(f"Agent '{AGENT_NAME}' dispatched to room '{DEFAULT_ROOM}'")
        except Exception as e:
            logger.error(f"Agent dispatch failed: {e}")


# ---------------------------------------------------------------------------
# HTTP handler
# ---------------------------------------------------------------------------

class ReuseAddrHTTPServer(HTTPServer):
    allow_reuse_address = True


class TokenHandler(BaseHTTPRequestHandler):

    def do_GET(self) -> None:
        parsed = urlparse(self.path)

        if parsed.path != "/token":
            self._send(404, {"error": "Not found"})
            return

        params   = parse_qs(parsed.query)
        identity = params.get("identity", [str(uuid.uuid4())])[0]
        room     = params.get("room", [DEFAULT_ROOM])[0]

        try:
            jwt = create_token(identity, room)
            self._send(200, {
                "token":    jwt,
                "url":      config.livekit_url,
                "room":     room,
                "identity": identity,
            })
            logger.info(f"Token issued — identity={identity!r} room={room!r}")
        except Exception as e:
            logger.error(f"Token generation failed: {e}", exc_info=True)
            self._send(500, {"error": str(e)})

    def _send(self, status: int, body: dict) -> None:
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        pass  # Use our logger instead


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

WATCHDOG_INTERVAL = 60  # seconds between agent-presence checks


async def watchdog_check() -> None:
    """Check if the agent is in the room. Re-dispatch if absent."""
    async with LiveKitAPI(config.livekit_url, config.livekit_api_key, config.livekit_api_secret) as lk:
        try:
            resp = await lk.room.list_participants(ListParticipantsRequest(room=DEFAULT_ROOM))
            agents = [p for p in resp.participants if p.identity.startswith("agent-")]
            if not agents:
                logger.warning(f"No agent in '{DEFAULT_ROOM}' — re-dispatching")
                await lk.agent_dispatch.create_dispatch(
                    CreateAgentDispatchRequest(agent_name=AGENT_NAME, room=DEFAULT_ROOM)
                )
                logger.info(f"Agent '{AGENT_NAME}' re-dispatched to '{DEFAULT_ROOM}'")
            elif len(agents) > 1:
                # Duplicate agents — remove all but the most recently joined
                logger.warning(f"Found {len(agents)} agents in room — removing duplicates")
                for p in agents[:-1]:
                    await lk.room.remove_participant(
                        RoomParticipantIdentity(room=DEFAULT_ROOM, identity=p.identity)
                    )
                    logger.info(f"Removed duplicate agent: {p.identity}")
        except Exception as e:
            logger.warning(f"Watchdog check failed: {e}")


def run_watchdog() -> None:
    """Background thread: periodically verify agent is in the room."""
    time.sleep(WATCHDOG_INTERVAL)  # Initial delay — let startup settle
    while True:
        asyncio.run(watchdog_check())
        time.sleep(WATCHDOG_INTERVAL)


if __name__ == "__main__":
    # Ensure persistent room + agent exist before serving tokens
    asyncio.run(ensure_room_and_agent())

    # Start watchdog — re-dispatches agent if it crashes and leaves the room
    watchdog = threading.Thread(target=run_watchdog, daemon=True, name="agent-watchdog")
    watchdog.start()
    logger.info(f"Agent watchdog started (interval: {WATCHDOG_INTERVAL}s)")

    server = ReuseAddrHTTPServer(("0.0.0.0", PORT), TokenHandler)
    logger.info(f"Token service listening on port {PORT}")
    logger.info(f"Agent: {AGENT_NAME!r}  Default room: {DEFAULT_ROOM!r}  TTL: {TOKEN_TTL}s")
    logger.info(f"LiveKit URL returned to clients: {config.livekit_url}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Token service stopped.")
