"""
token_service.py — VoxUI Token + Config Service

Serves LiveKit room tokens AND acts as the configuration API for the
Flutter frontend. All voice agent settings (STT/TTS/LLM endpoints, voice,
speed, LLM profile) can be read and written at runtime without restarting
the agent.

Endpoints:
    GET  /token?identity=<id>&room=<room>
         Generate a signed LiveKit JWT.

    GET  /config
         Return current effective configuration (env defaults + overrides).

    PUT  /config
         Update configuration. Body: JSON object with any subset of config keys.
         Changes are persisted to config_override.json and take effect on the
         next voice session.

    GET  /voices
         Fetch available TTS voices from the configured TTS endpoint.
         Falls back to a built-in Kokoro voice list if the endpoint doesn't
         support voice listing.

    POST /preview
         Synthesise sample text and return audio.
         Body: {"text": "...", "voice": "af_heart", "speed": 1.0}
         Response: audio/mpeg (or audio/wav depending on TTS server)

    OPTIONS *
         CORS preflight response.
"""

from __future__ import annotations

import asyncio
import datetime
import json
import logging
import os
import threading
import time
import urllib.request
import urllib.error
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

from livekit.api import AccessToken, LiveKitAPI, VideoGrants
from livekit.protocol.agent_dispatch import CreateAgentDispatchRequest
from livekit.protocol.room import (
    CreateRoomRequest,
    ListParticipantsRequest,
    RoomConfiguration,
    RoomParticipantIdentity,
)

from config import config

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

AGENT_NAME   = "ai-assistant"
DEFAULT_ROOM = os.environ.get("LIVEKIT_ROOM", "vox-ui-room")
PORT         = int(os.environ.get("TOKEN_SERVICE_PORT", "7882"))
TOKEN_TTL    = int(os.environ.get("TOKEN_TTL_SECONDS", "86400"))

# Path to the config override file (relative to CWD where this is launched)
CONFIG_OVERRIDE_FILE = "config_override.json"

# Fallback Kokoro voice list (used when TTS endpoint doesn't support listing)
KOKORO_DEFAULT_VOICES = [
    {"id": "af_heart",    "name": "Heart (AF)"},
    {"id": "af_bella",    "name": "Bella (AF)"},
    {"id": "af_nicole",   "name": "Nicole (AF)"},
    {"id": "af_sarah",    "name": "Sarah (AF)"},
    {"id": "af_sky",      "name": "Sky (AF)"},
    {"id": "am_adam",     "name": "Adam (AM)"},
    {"id": "am_michael",  "name": "Michael (AM)"},
    {"id": "bf_emma",     "name": "Emma (BF)"},
    {"id": "bf_isabella", "name": "Isabella (BF)"},
    {"id": "bm_george",   "name": "George (BM)"},
    {"id": "bm_lewis",    "name": "Lewis (BM)"},
]


# ---------------------------------------------------------------------------
# Cloudflare TURN credentials (auto-refreshed, 23-hour cache)
# ---------------------------------------------------------------------------

_CF_TURN_KEY_ID    = 'f987a58e93164e3195a10116fbcdc30e'
_CF_TURN_KEY_TOKEN = '4b266c1563392917ce9756451df8d966b2d750c8a49d421eae788436061635f1'
_TURN_CACHE: dict = {'ice_servers': None, 'expires': 0.0}
_TURN_LOCK = threading.Lock()


def _fetch_ice_servers() -> list:
    with _TURN_LOCK:
        if time.time() < _TURN_CACHE['expires'] and _TURN_CACHE['ice_servers'] is not None:
            return _TURN_CACHE['ice_servers']
        try:
            url = (
                'https://rtc.live.cloudflare.com/v1/turn/keys/'
                f'{_CF_TURN_KEY_ID}/credentials/generate-ice-servers'
            )
            body = json.dumps({'ttl': 86400}).encode()
            req = urllib.request.Request(
                url, data=body,
                headers={
                    'Authorization': f'Bearer {_CF_TURN_KEY_TOKEN}',
                    'Content-Type':  'application/json',
                    'User-Agent':    'VoxUI-TokenService/1.0',
                },
                method='POST',
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read())
            filtered = []
            for server in data.get('iceServers', []):
                urls = [u for u in server.get('urls', []) if ':53' not in u]
                if not urls:
                    continue
                entry: dict = {'urls': urls}
                if 'username' in server:
                    entry['username'] = server['username']
                if 'credential' in server:
                    entry['credential'] = server['credential']
                filtered.append(entry)
            _TURN_CACHE['ice_servers'] = filtered
            _TURN_CACHE['expires']     = time.time() + 82800
            logger.info('Cloudflare TURN credentials refreshed (%d servers)', len(filtered))
            return filtered
        except Exception as exc:
            logger.warning('TURN credential refresh failed: %s', exc)
            return _TURN_CACHE.get('ice_servers') or []


# Keys that are allowed to be overridden via PUT /config
CONFIGURABLE_KEYS = {
    "stt_url", "stt_model",
    "tts_url", "tts_voice", "tts_speed",
    "llm_base_url", "llm_model", "llm_api_key",
    "llm_temperature", "llm_max_completion_tokens", "llm_disable_thinking",
    "livekit_url",
    "livekit_public_url",
    "skip_greeting",
}

# ---------------------------------------------------------------------------
# Config override state (thread-safe)
# ---------------------------------------------------------------------------

_override_lock = threading.Lock()
_config_override: dict = {}


def _normalize_url(url: str) -> str:
    """Strip trailing /v1 and slashes — store base URL, append /v1 on use."""
    url = url.rstrip("/")
    if url.endswith("/v1"):
        url = url[:-3]
    return url


def load_config_override() -> None:
    """Load persisted overrides from config_override.json at startup."""
    global _config_override
    if os.path.exists(CONFIG_OVERRIDE_FILE):
        try:
            with open(CONFIG_OVERRIDE_FILE) as f:
                data = json.load(f)
            with _override_lock:
                _config_override = {k: v for k, v in data.items() if k in CONFIGURABLE_KEYS}
            logger.info(f"Loaded config overrides: {list(_config_override.keys())}")
        except Exception as e:
            logger.warning(f"Could not load {CONFIG_OVERRIDE_FILE}: {e}")


def save_config_override() -> None:
    """Persist current override dict to config_override.json."""
    with _override_lock:
        data = dict(_config_override)
    try:
        with open(CONFIG_OVERRIDE_FILE, "w") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        logger.error(f"Could not save {CONFIG_OVERRIDE_FILE}: {e}")


def get_effective_config() -> dict:
    """Return the merged config (env defaults + overrides) as a plain dict."""
    with _override_lock:
        overrides = dict(_config_override)

    def ov(key, default):
        return overrides.get(key, default)

    return {
        "stt_url":                     ov("stt_url",                     config.stt_url),
        "stt_model":                   ov("stt_model",                   config.stt_model),
        "tts_url":                     ov("tts_url",                     config.tts_url),
        "tts_voice":                   ov("tts_voice",                   config.tts_voice),
        "tts_speed":                   ov("tts_speed",                   config.tts_speed),
        "llm_base_url":                ov("llm_base_url",                config.llm_base_url),
        "llm_model":                   ov("llm_model",                   config.llm_model),
        "llm_api_key":                 ov("llm_api_key",                 config.llm_api_key),
        "llm_temperature":             ov("llm_temperature",             config.llm_temperature),
        "llm_max_completion_tokens":   ov("llm_max_completion_tokens",   config.llm_max_completion_tokens),
        "llm_disable_thinking":        ov("llm_disable_thinking",        config.llm_disable_thinking),
        "livekit_url":                 ov("livekit_url",                 config.livekit_url),
        "livekit_public_url":          ov("livekit_public_url",          config.livekit_public_url),
        "skip_greeting":               ov("skip_greeting",               config.skip_greeting),
    }


def apply_config_update(updates: dict) -> tuple[dict, list[str]]:
    """
    Apply validated updates to the in-memory override dict.
    Returns (new_effective_config, list_of_rejected_keys).
    """
    rejected = []
    accepted = {}

    for k, v in updates.items():
        if k not in CONFIGURABLE_KEYS:
            rejected.append(k)
            continue
        # Normalise URL fields
        if k.endswith("_url") and isinstance(v, str):
            v = _normalize_url(v)
        accepted[k] = v

    with _override_lock:
        _config_override.update(accepted)

    save_config_override()
    return get_effective_config(), rejected


# ---------------------------------------------------------------------------
# Token generation
# ---------------------------------------------------------------------------

def create_token(identity: str, room: str) -> str:
    eff = get_effective_config()
    livekit_api_key    = config.livekit_api_key
    livekit_api_secret = config.livekit_api_secret
    token = (
        AccessToken(livekit_api_key, livekit_api_secret)
        .with_identity(identity)
        .with_name(identity)
        .with_grants(VideoGrants(
            room_join=True,
            room=room,
            can_publish=True,
            can_subscribe=True,
        ))
        .with_room_config(RoomConfiguration(agents=[]))
        .with_ttl(datetime.timedelta(seconds=TOKEN_TTL))
    )
    return token.to_jwt()


# ---------------------------------------------------------------------------
# LiveKit room / agent management
# ---------------------------------------------------------------------------

async def ensure_room_and_agent() -> None:
    api_url = config.livekit_url
    async with LiveKitAPI(api_url, config.livekit_api_key, config.livekit_api_secret) as lk:
        try:
            await lk.room.create_room(CreateRoomRequest(
                name=DEFAULT_ROOM, empty_timeout=86400, max_participants=20,
            ))
            logger.info(f"Room '{DEFAULT_ROOM}' created/confirmed")
        except Exception as e:
            logger.info(f"Room '{DEFAULT_ROOM}': {e}")

        try:
            resp = await lk.room.list_participants(
                ListParticipantsRequest(room=DEFAULT_ROOM)
            )
            existing = [p for p in resp.participants if p.identity.startswith("agent-")]
            if existing:
                logger.info(f"Agent already in room — skipping dispatch")
                return
        except Exception as e:
            logger.warning(f"Could not check participants: {e}")

        try:
            await lk.agent_dispatch.create_dispatch(
                CreateAgentDispatchRequest(agent_name=AGENT_NAME, room=DEFAULT_ROOM)
            )
            logger.info(f"Agent '{AGENT_NAME}' dispatched to '{DEFAULT_ROOM}'")
        except Exception as e:
            logger.error(f"Agent dispatch failed: {e}")


async def watchdog_check() -> None:
    async with LiveKitAPI(
        config.livekit_url, config.livekit_api_key, config.livekit_api_secret
    ) as lk:
        try:
            resp = await lk.room.list_participants(
                ListParticipantsRequest(room=DEFAULT_ROOM)
            )
            agents = [p for p in resp.participants if p.identity.startswith("agent-")]
            if not agents:
                logger.warning(f"No agent in '{DEFAULT_ROOM}' — re-dispatching")
                # Recreate room with 24h timeout. LiveKit deletes empty rooms
                # after ~300s even with agent-kind participants present.
                try:
                    await lk.room.create_room(CreateRoomRequest(
                        name=DEFAULT_ROOM, empty_timeout=86400, max_participants=20,
                    ))
                except Exception:
                    pass  # room already exists, that's fine
                await lk.agent_dispatch.create_dispatch(
                    CreateAgentDispatchRequest(agent_name=AGENT_NAME, room=DEFAULT_ROOM)
                )
            elif len(agents) > 1:
                for p in agents[:-1]:
                    await lk.room.remove_participant(
                        RoomParticipantIdentity(room=DEFAULT_ROOM, identity=p.identity)
                    )
        except Exception as e:
            logger.warning(f"Watchdog: {e}")


WATCHDOG_INTERVAL = 60


def run_watchdog() -> None:
    time.sleep(WATCHDOG_INTERVAL)
    while True:
        asyncio.run(watchdog_check())
        time.sleep(WATCHDOG_INTERVAL)


# ---------------------------------------------------------------------------
# TTS helpers
# ---------------------------------------------------------------------------

def _tts_base_url() -> str:
    """Get the current TTS base URL (without /v1) from effective config."""
    return get_effective_config()["tts_url"].rstrip("/")


def fetch_voices() -> list[dict]:
    """
    Try to fetch the voice list from the TTS endpoint.
    Falls back to the built-in Kokoro list on any error.
    """
    base = _tts_base_url()
    url  = f"{base}/v1/audio/voices"
    try:
        req  = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            # Accept list of strings or list of {id,name} dicts
            voices = data if isinstance(data, list) else data.get("voices", [])
            if voices and isinstance(voices[0], str):
                return [{"id": v, "name": v} for v in voices]
            return voices
    except Exception as e:
        logger.info(f"TTS /voices not available ({e}), using defaults")
        return KOKORO_DEFAULT_VOICES


def synthesise_preview(text: str, voice: str, speed: float) -> tuple[bytes, str]:
    """
    Call the TTS endpoint and return (audio_bytes, content_type).
    Raises on failure.
    """
    base = _tts_base_url()
    url  = f"{base}/v1/audio/speech"
    body = json.dumps({
        "model":  "tts-1",
        "input":  text,
        "voice":  voice,
        "speed":  speed,
        "response_format": "mp3",
    }).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type":  "application/json",
            "Authorization": "Bearer dummy",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        content_type = resp.headers.get("Content-Type", "audio/mpeg")
        return resp.read(), content_type


# ---------------------------------------------------------------------------
# HTTP handler
# ---------------------------------------------------------------------------

class ReuseAddrHTTPServer(HTTPServer):
    allow_reuse_address = True


class TokenHandler(BaseHTTPRequestHandler):

    # ── CORS preflight ──────────────────────────────────────────────────────

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors_headers()
        self.send_header("Access-Control-Allow-Methods", "GET, PUT, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    # ── GET ─────────────────────────────────────────────────────────────────

    def do_GET(self) -> None:
        parsed = urlparse(self.path)

        if parsed.path == "/token":
            self._handle_token(parsed)

        elif parsed.path == "/config":
            self._send_json(200, get_effective_config())

        elif parsed.path == "/voices":
            try:
                voices = fetch_voices()
                self._send_json(200, {"voices": voices})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        elif parsed.path == "/test-stt":
            # Server-side STT connectivity test — browser cannot reach LAN IPs directly
            try:
                eff = get_effective_config()
                stt_base = eff.get("stt_url", "").rstrip("/")
                req = urllib.request.Request(f"{stt_base}/v1/models",
                                             headers={"Accept": "application/json"})
                with urllib.request.urlopen(req, timeout=8) as resp:
                    data = json.loads(resp.read())
                models = [m["id"] for m in data.get("data", [])][:3]
                self._send_json(200, {"ok": True, "models": models, "url": stt_base})
            except urllib.error.HTTPError as e:
                self._send_json(200, {"ok": False, "error": f"HTTP {e.code}: {e.reason}"})
            except Exception as e:
                self._send_json(200, {"ok": False, "error": str(e)})

        elif parsed.path == "/test-llm":
            # Server-side LLM connectivity test — browser cannot reach localhost:8001 directly
            try:
                eff = get_effective_config()
                import re as _re; llm_base = _re.sub(r"(/v1/?)+$", "", eff.get("llm_base_url", "").rstrip("/"))
                api_key = eff.get("llm_api_key") or "not-needed"
                model = eff.get("llm_model", "")
                payload = json.dumps({
                    "model": model,
                    "messages": [{"role": "user", "content": "Say: pong"}],
                    "max_tokens": 8,
                    "stream": False,
                }).encode()
                req = urllib.request.Request(
                    f"{llm_base}/v1/chat/completions",
                    data=payload,
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {api_key}",
                    },
                    method="POST",
                )
                with urllib.request.urlopen(req, timeout=20) as resp:
                    data = json.loads(resp.read())
                reply = data["choices"][0]["message"]["content"].strip()
                self._send_json(200, {"ok": True, "reply": reply[:80], "model": model})
            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8", errors="replace")[:120]
                self._send_json(200, {"ok": False, "error": f"HTTP {e.code}: {body}"})
            except Exception as e:
                self._send_json(200, {"ok": False, "error": str(e)})

        else:
            self._send_json(404, {"error": "Not found"})

    def _handle_token(self, parsed) -> None:
        params   = parse_qs(parsed.query)
        identity = params.get("identity", [str(uuid.uuid4())])[0]
        room     = params.get("room",     [DEFAULT_ROOM])[0]
        try:
            jwt = create_token(identity, room)
            ice_svrs = _fetch_ice_servers()
            self._send_json(200, {
                "token":      jwt,
                "url":        (get_effective_config().get("livekit_public_url") or get_effective_config()["livekit_url"]),
                "room":       room,
                "identity":   identity,
                "iceServers": ice_svrs,
            })
            logger.info(f"Token issued — identity={identity!r} room={room!r}")
        except Exception as e:
            logger.error(f"Token generation failed: {e}", exc_info=True)
            self._send_json(500, {"error": str(e)})

    # ── PUT /config ─────────────────────────────────────────────────────────

    def do_PUT(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/config":
            self._send_json(404, {"error": "Not found"})
            return

        body = self._read_body()
        if body is None:
            return

        try:
            updates = json.loads(body)
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON"})
            return

        if not isinstance(updates, dict):
            self._send_json(400, {"error": "Body must be a JSON object"})
            return

        new_config, rejected = apply_config_update(updates)
        response = {"config": new_config}
        if rejected:
            response["rejected_keys"] = rejected
        self._send_json(200, response)
        logger.info(f"Config updated: {list(updates.keys())}")

    # ── POST /preview ────────────────────────────────────────────────────────

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/preview":
            self._send_json(404, {"error": "Not found"})
            return

        body = self._read_body()
        if body is None:
            return

        try:
            params = json.loads(body)
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON"})
            return

        text  = params.get("text", "Hello! This is a voice preview.")
        eff   = get_effective_config()
        voice = params.get("voice", eff["tts_voice"])
        speed = float(params.get("speed", eff["tts_speed"]))

        try:
            audio_bytes, content_type = synthesise_preview(text, voice, speed)
            self.send_response(200)
            self.send_header("Content-Type",   content_type)
            self.send_header("Content-Length", str(len(audio_bytes)))
            self._cors_headers()
            self.end_headers()
            self.wfile.write(audio_bytes)
            logger.info(f"Preview synthesised — voice={voice!r} speed={speed} len={len(audio_bytes)}B")
        except Exception as e:
            logger.error(f"TTS preview failed: {e}", exc_info=True)
            self._send_json(500, {"error": str(e)})

    # ── Helpers ──────────────────────────────────────────────────────────────

    def _read_body(self) -> bytes | None:
        length_str = self.headers.get("Content-Length")
        if not length_str:
            self._send_json(411, {"error": "Content-Length required"})
            return None
        try:
            return self.rfile.read(int(length_str))
        except Exception as e:
            self._send_json(400, {"error": f"Could not read body: {e}"})
            return None

    def _send_json(self, status: int, body: dict) -> None:
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type",   "application/json")
        self.send_header("Content-Length", str(len(data)))
        self._cors_headers()
        self.end_headers()
        self.wfile.write(data)

    def _cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")

    def log_message(self, fmt, *args):
        pass  # Suppress default CLF logging — we use our own logger


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    load_config_override()

    asyncio.run(ensure_room_and_agent())

    watchdog = threading.Thread(target=run_watchdog, daemon=True, name="agent-watchdog")
    watchdog.start()
    logger.info(f"Agent watchdog started (interval: {WATCHDOG_INTERVAL}s)")

    server = ReuseAddrHTTPServer(("0.0.0.0", PORT), TokenHandler)
    logger.info(f"VoxUI token + config service on port {PORT}")
    logger.info(f"  GET  /token    — LiveKit room token")
    logger.info(f"  GET  /config   — current effective config")
    logger.info(f"  PUT  /config   — update config (JSON body)")
    logger.info(f"  GET  /voices   — available TTS voices")
    logger.info(f"  POST /preview  — TTS preview (returns audio/mpeg)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Service stopped.")
