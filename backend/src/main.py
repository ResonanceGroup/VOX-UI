"""
main.py — RV Voice Agent Entry Point (LiveKit Agents v1.x)

Standard AgentServer pattern following the official LiveKit starter:
  https://github.com/livekit-examples/agent-starter-python

Voice pipeline: STT (Speaches/Whisper) → LLM (Ollama or Letta) → TTS (Kokoro)
                + VAD (Silero) + turn detection

Usage:
  # Console mode (offline test, no LiveKit server needed):
  python main.py console

  # Development mode (colored logs, auto-reload):
  python main.py dev

  # Production mode:
  python main.py start

Dispatch:
  This agent is kept resident in the default room by the token service startup
  dispatch and watchdog. Clients join the room normally; they do not need to
  request a fresh per-client dispatch in their token.

Environment variables (see config.py for full list):
  LIVEKIT_URL          Default: ws://localhost:7880
  LIVEKIT_API_KEY      Default: devkey
  LIVEKIT_API_SECRET   Default: devsecret
  LLM_PROVIDER         Default: ollama  (or "letta" for Phase 2+)
  BACKEND_ENABLED      Default: True    (set False for Phase 1 voice-only)
  TOOLS_ENABLED        Default: False   (set True for Phase 3+ with device control)
  MCP_ENABLED          Default: True    (MCP server for tool calling)
  MCP_PORT             Default: 8284    (MCP server port)
"""

from __future__ import annotations

import asyncio
import base64
import json
import logging
import time
import threading

import httpx

from livekit.agents import (
    Agent,
    AgentServer,
    AgentSession,
    JobContext,
    JobProcess,
    cli,
    function_tool,
    get_job_context,
)
from livekit.agents.voice import room_io
from livekit.agents.llm import ChatMessage, ImageContent
from livekit.plugins import openai, silero

from api import BackendClient
from config import config


try:
    from token_service import get_effective_config, load_config_override
    load_config_override()
except Exception:
    def get_effective_config(): return {}

# ---------------------------------------------------------------------------
# Logging (moved before conditional imports so logger is available)
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=getattr(logging, config.log_level.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# LettaLLM plugin — always available; used when profile points to a Lettabot API
from letta import LettaLLM, LettaLLMConfig
logger.info("LettaLLM plugin available (used when profile LLM URL matches Lettabot)")

# Conditional import for MCP server
if config.mcp_enabled:
    from mcp_server import RVMCPServer
    logger.info("MCP server enabled on port %s", config.mcp_port)


def _session_can_generate_reply(session: AgentSession) -> bool:
    """Return True when the session is still active enough to accept generate_reply()."""
    return (
        getattr(session, "_activity", None) is not None
        and getattr(session, "_closing_task", None) is None
    )


# ---------------------------------------------------------------------------
# MCP Server thread
# ---------------------------------------------------------------------------

def run_mcp_server(backend: BackendClient, port: int) -> None:
    """Run MCP server in a background thread."""
    try:
        mcp_server = RVMCPServer(backend=backend, port=port)
        mcp_server.run()
    except Exception as e:
        logger.error(f"MCP server error: {e}")


# ---------------------------------------------------------------------------
# Agent class
# ---------------------------------------------------------------------------

class RVAgent(Agent):
    """RV voice agent - Milo, conversational assistant for RV systems."""

    # Tracks pending approval futures keyed by approval_id.
    # Class-level so the on_data_received handler can resolve them.
    _pending_approvals: dict[str, asyncio.Future] = {}

    def __init__(self) -> None:
        self._image_tasks: list = []  # keep tasks alive (prevent GC)
        self._max_ctx_items = 10  # keep last N turns (system prompt preserved)
        super().__init__(
            instructions="",  # Hermes manages its own system prompt
        )
        logger.info("RVAgent ready (tool calling enabled)")

    def llm_node(self, chat_ctx, tools, model_settings):
        # Override to truncate chat context before LLM call.
        # Prevents unbounded context growth which causes:
        # - Response cutoff (max_completion_tokens squeezed out)
        # - Slow LLM inference (processing old history)
        # - API errors (context exceeds model limit)
        eff = get_effective_config()
        max_items = int(eff.get("max_context_items", self._max_ctx_items))

        # For Milo (Lettabot) profile: slim context to system + latest user msg
        # The Lettabot agent handles its own full conversation state internally
        # Slim context for agents that manage their own conversation state
        # (Lettabot agents, etc.) - set max_context_items=1 in profile
        slim_ctx = max_items <= 1

        if slim_ctx and len(chat_ctx.items) > 3:
            # Keep only: system prompt + latest user message
            system_msgs = [i for i in chat_ctx.items if i.type == "message" and getattr(i, "role", None) in ("system", "developer")]
            user_msgs = [i for i in chat_ctx.items if i.type == "message" and getattr(i, "role", None) == "user"]
            if user_msgs:
                chat_ctx.items[:] = system_msgs + [user_msgs[-1]]
                logger.info("[CTX] Slim context: reduced to %d items (system + latest user)", len(chat_ctx.items))
        elif len(chat_ctx.items) > max_items:
            chat_ctx.truncate(max_items=max_items)
            logger.info("[CTX] Truncated context to %d items", max_items)

        return super().llm_node(chat_ctx, tools, model_settings)

    # ------------------------------------------------------------------
    # Tool approval gating
    # ------------------------------------------------------------------

    @classmethod
    def resolve_approval(cls, approval_id: str, approved: bool) -> None:
        """Called by on_data_received when the user approves/rejects a tool call."""
        fut = cls._pending_approvals.pop(approval_id, None)
        if fut and not fut.done():
            fut.set_result(approved)
        else:
            logger.warning("resolve_approval: unknown or already-resolved id=%s", approval_id)

    async def _require_approval(
        self, tool_name: str, args: dict, description: str
    ) -> bool:
        """Publish an approval request to the Flutter client and wait up to 60 s."""
        approval_id = f"appr_{int(time.time() * 1000)}"
        loop = asyncio.get_event_loop()
        fut: asyncio.Future = loop.create_future()
        RVAgent._pending_approvals[approval_id] = fut

        room = get_job_context().room
        try:
            await room.local_participant.publish_data(
                json.dumps({
                    "type": "tool_approval_request",
                    "approval_id": approval_id,
                    "tool_name": tool_name,
                    "tool_args": args,
                    "description": description,
                }).encode(),
                reliable=True,
            )
        except Exception as e:
            logger.error("Failed to publish tool_approval_request: %s", e)
            RVAgent._pending_approvals.pop(approval_id, None)
            return False

        try:
            result: bool = await asyncio.wait_for(asyncio.shield(fut), timeout=60.0)
            return result
        except asyncio.TimeoutError:
            RVAgent._pending_approvals.pop(approval_id, None)
            logger.info("Tool approval timed out for %s (id=%s)", tool_name, approval_id)
            return False

    # ------------------------------------------------------------------
    # Built-in tools
    # ------------------------------------------------------------------

    @function_tool
    async def get_current_time(self) -> str:
        """Return the current date and time in the user's local timezone (Eastern)."""
        from datetime import datetime, timezone
        from zoneinfo import ZoneInfo
        et = ZoneInfo("America/New_York")
        now = datetime.now(et)
        return now.strftime("It is %A, %B %d, %Y at %I:%M %p Eastern Time.")

    @function_tool
    async def web_search(self, query: str) -> str:
        """Search the web for current information and return a concise summary.

        Args:
            query: The search query string.
        """
        approved = await self._require_approval(
            "web_search",
            {"query": query},
            f'Search the web for: "{query}"',
        )
        if not approved:
            return "The user did not approve this web search."

        try:
            # DuckDuckGo instant-answer JSON API (no key required)
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    "https://api.duckduckgo.com/",
                    params={"q": query, "format": "json", "no_html": "1", "skip_disambig": "1"},
                    headers={"User-Agent": "VoxUI/1.0"},
                    timeout=10,
                )
            resp.raise_for_status()
            data = resp.json()
            parts: list[str] = []
            if data.get("AbstractText"):
                parts.append(data["AbstractText"])
            for topic in (data.get("RelatedTopics") or [])[:3]:
                if isinstance(topic, dict) and topic.get("Text"):
                    parts.append(topic["Text"])
            if parts:
                return "\n\n".join(parts[:3])
            return f"No instant answer found for '{query}'. I can try a more specific search if you'd like."
        except Exception as e:
            logger.error("web_search failed: %s", e)
            return f"Web search failed: {e}"

    # ------------------------------------------------------------------
    # Room setup
    # ------------------------------------------------------------------

    async def on_enter(self) -> None:
        """Register byte-stream handler for images when agent enters the room."""
        logger.info("RVAgent.on_enter() called — registering image_input handler")
        def _handler(reader, participant_identity: str) -> None:
            task = asyncio.create_task(
                self._receive_image(reader, participant_identity)
            )
            self._image_tasks.append(task)
            task.add_done_callback(lambda t: self._image_tasks.remove(t))

        get_job_context().room.register_byte_stream_handler("image_input", _handler)

    async def _receive_image(self, reader, participant_identity: str) -> None:
        """Collect image bytes, add to chat context, then trigger a reply."""
        try:
            chunks: list[bytes] = []
            total = 0
            async for chunk in reader:
                total += len(chunk)
                if total > 6 * 1024 * 1024:
                    logger.warning(
                        "Image upload from %s too large (%d bytes), dropping",
                        participant_identity, total,
                    )
                    return
                chunks.append(chunk)

            image_bytes = b"".join(chunks)
            mime_type = reader.info.mime_type or "image/jpeg"
            if not mime_type.startswith("image/"):
                logger.warning(
                    "Ignoring non-image stream from %s: %s",
                    participant_identity, mime_type,
                )
                return

            prompt = (reader.info.attributes or {}).get("prompt") or "Please describe what you see in this image."
            data_url = f"data:{mime_type};base64,{base64.b64encode(image_bytes).decode('ascii')}"
            logger.info(
                "Image received from %s: %s, %d bytes",
                participant_identity, mime_type, len(image_bytes),
            )

            # Official LiveKit v1 pattern: add image to chat context, then
            # call generate_reply() with no user_input so the context is used.
            chat_ctx = self.chat_ctx.copy()
            chat_ctx.add_message(
                role="user",
                content=[prompt, ImageContent(image=data_url, mime_type=mime_type)],
            )
            await self.update_chat_ctx(chat_ctx)
            logger.info("Image added to chat_ctx, calling generate_reply()")
            self.session.generate_reply()

        except RuntimeError as e:
            logger.debug("Image handler: session unavailable: %s", e)
        except Exception as e:
            logger.error("Image handler error: %s", e)


# ---------------------------------------------------------------------------
# Agent server
# ---------------------------------------------------------------------------

server = AgentServer(num_idle_processes=1, port=0)


# ---------------------------------------------------------------------------
# Prewarm: load expensive resources once per worker process
# ---------------------------------------------------------------------------

def prewarm(proc: JobProcess) -> None:
    """Load Silero VAD and optionally create BackendClient before any job runs."""
    logger.info("[PREWARM] Starting prewarm - backend_enabled=%s", config.backend_enabled)
    proc.userdata["vad"] = silero.VAD.load()
    logger.info("Silero VAD loaded.")
    logger.info("[PREWARM] Silero VAD loaded")

    if config.backend_enabled:
        logger.info("[PREWARM] Creating BackendClient - host=%s, port=%s", config.backend_host, config.backend_port)
        backend = BackendClient(
            host=config.backend_host,
            port=config.backend_port,
            connect_timeout=config.backend_connect_timeout,
            min_backoff=config.backend_min_backoff,
            max_backoff=config.backend_max_backoff,
        )
        proc.userdata["backend"] = backend
        
        # Start persistent connection in dedicated background thread
        # (owns its own event loop — survives prewarm and handles reconnection)
        backend.start_in_background()
        
        # Wait for initial TCP connect + cache burst
        time.sleep(3)
        if backend.connected:
            logger.info("Backend connected in prewarm.")
            logger.info("[PREWARM] Backend connected — %d devices cached", len(backend.cache.device_ids()))
        else:
            logger.warning("Backend still connecting (will keep trying in background)")
            logger.info("[PREWARM] Backend still connecting (will retry automatically)")
        
    else:
        logger.info("Backend disabled (BACKEND_ENABLED=false).")
        logger.info("[PREWARM] Backend disabled")


server.setup_fnc = prewarm


# ---------------------------------------------------------------------------
# Session entrypoint — called for each dispatched job
# ---------------------------------------------------------------------------

@server.rtc_session(agent_name="ai-assistant")
async def entrypoint(ctx: JobContext) -> None:
    """
    Standard LiveKit session entrypoint.

    Called when a client dispatches the "ai-assistant" agent to a room.
    Sets up the voice pipeline, starts the session, and lets the
    framework handle connection, lifecycle, and cleanup automatically.
    """
    ctx.log_context_fields = {"room": ctx.room.name}

    # Backend connection (managed by dedicated background thread from prewarm)
    backend: BackendClient | None = ctx.proc.userdata.get("backend")
    if backend:
        logger.info(f"Backend status: connected={backend.connected}, devices={len(backend.cache.device_ids())}")

    # Build the voice pipeline.
    # Re-read config_override.json each session so PUT /config changes
    # (voice, LLM endpoint, etc.) take effect without restarting the agent.
    load_config_override()
    eff = get_effective_config()
    logger.info("[CONFIG] tts_voice=%s llm_base_url=%s", eff.get("tts_voice"), eff.get("llm_base_url"))

    # Pre-flight LLM health check — catch unreachable endpoints early
    _llm_ok = False
    try:
        import httpx as _hx
        _check_url = eff.get("llm_base_url", config.llm_base_url).rstrip("/") + "/v1/models"
        _check_key = eff.get("llm_api_key", config.llm_api_key) or "sk-no-key-required"
        async with _hx.AsyncClient(timeout=_hx.Timeout(connect=10.0, read=10.0, write=5.0, pool=5.0)) as _c:
            _r = await _c.get(_check_url, headers={"Authorization": f"Bearer {_check_key}"})
            _llm_ok = _r.status_code < 500
    except Exception as _e:
        logger.warning("[HEALTH] LLM endpoint unreachable: %s", _e)
        _llm_ok = False

    if not _llm_ok:
        logger.error("[HEALTH] LLM endpoint %s is down — session will fail", eff.get("llm_base_url"))
        # Still proceed — the session will handle the error, but at least
        # the user gets a clear signal via the data channel
        # Send a data message to the room about the failure
        @ctx.room.on("participant_connected")
        def _warn_participant(p):
            async def _send():
                try:
                    await p.publish_data(
                        json.dumps({"type": "llm_health_error", "message": f"LLM endpoint is unreachable: {eff.get('llm_base_url')}. Please switch to a different profile."}).encode(),
                        reliable=True,
                    )
                except Exception:
                    pass
            asyncio.create_task(_send())

    def _v1(url: str) -> str:
        """Ensure URL ends with /v1."""
        url = url.rstrip("/")
        return url if url.endswith("/v1") else url + "/v1"

    stt_plugin = openai.STT(
        base_url=_v1(eff.get("stt_url", config.stt_url)),
        api_key="sk-no-key-required",
        model=eff.get("stt_model", config.stt_model),
        language="en",
    )

    # Create TTS plugin separately so we can update its voice at runtime
    tts_model = eff.get("tts_model", "tts-1")
    # Piper returns WAV; OpenAI TTS returns MP3. Match the response format.
    tts_response_format = "wav" if tts_model == "piper" else "mp3"
    tts_plugin = openai.TTS(
        base_url=_v1(eff.get("tts_url", config.tts_url)),
        api_key="sk-no-key-required",
        model=tts_model,
        voice=eff.get("tts_voice", config.tts_voice),
        speed=float(eff.get("tts_speed", config.tts_speed)),
        response_format=tts_response_format,
    )

    # Profile-level LLM settings (timeout, retries, preemption)
    _llm_url = eff.get("llm_base_url", config.llm_base_url)
    _llm_model = eff.get("llm_model", config.llm_model)
    _llm_api_key = eff.get("llm_api_key", config.llm_api_key) or "sk-no-key-required"
    _llm_read_timeout = int(eff.get("llm_read_timeout", 120))
    _llm_max_retries = int(eff.get("llm_max_retries", 3))
    _llm_timeout = httpx.Timeout(
        connect=30.0,
        read=float(_llm_read_timeout),
        write=30.0,
        pool=30.0,
    )

    # ── Detect Lettabot profile and use LettaLLM ──
    # When the LLM URL points to a Lettabot API (OpenAI-compatible wrapper
    # around Letta agents), use the native LettaLLM plugin instead of
    # openai.LLM. This gives us tool call visibility (status messages
    # to Flutter) and timeout keepalive on tool call events.
    _is_lettabot = _llm_url and ":8080" in _llm_url and "192.168.122" in _llm_url

    # Shared publish_data callback — both LettaLLM and the agent state
    # handler use this to send data messages to the Flutter client.
    async def _publish_data(data: dict) -> None:
        """Publish a data message to the LiveKit room."""
        try:
            await ctx.room.local_participant.publish_data(
                json.dumps(data).encode(), reliable=True,
            )
        except Exception as e:
            logger.debug("Failed to publish data message: %s", e)

    # Timeout reset callback — resets the httpx read timeout deadline.
    # Called by LettaLLM on each tool call event to prevent premature
    # timeout during long tool call chains (keepalive).
    _timeout_reset_time = time.monotonic()

    def _reset_timeout() -> None:
        """Reset the read timeout by updating the deadline tracker."""
        nonlocal _timeout_reset_time
        _timeout_reset_time = time.monotonic()

    if _is_lettabot:
        # Use LettaLLM — gets tool call events from Lettabot SSE stream
        _letta_url = _llm_url.rstrip("/")
        if _letta_url.endswith("/v1"):
            _letta_url = _letta_url[:-3]  # strip /v1 — OpenAI client adds it
        logger.info("[LLM] Using LettaLLM (agent=%s, url=%s)", _llm_model, _letta_url)
        _llm_instance = LettaLLM(
            LettaLLMConfig(
                agent_name=_llm_model,
                api_url=_letta_url,
                api_key=_llm_api_key,
                timeout=float(_llm_read_timeout),
                publish_data=_publish_data,
                reset_timeout=_reset_timeout,
            )
        )
    else:
        # Standard OpenAI-compatible LLM (Hermes, vLLM, etc.)
        logger.info("[LLM] Using openai.LLM (url=%s, model=%s)", _llm_url, _llm_model)
        _llm_instance = openai.LLM(
            base_url=_v1(_llm_url),
            api_key=_llm_api_key,
            model=_llm_model,
            temperature=float(eff.get("llm_temperature", config.llm_temperature)),
            max_completion_tokens=int(eff.get("llm_max_completion_tokens", config.llm_max_completion_tokens)),
            timeout=_llm_timeout,
            max_retries=_llm_max_retries,
            extra_body={"think": False} if eff.get("llm_disable_thinking", config.llm_disable_thinking) else None,
        )

    session = AgentSession(
        # VAD: Silero (pre-loaded in prewarm)
        vad=ctx.proc.userdata["vad"],

        # STT — reads live config (held as stt_plugin for runtime updates)
        stt=stt_plugin,

        # LLM — LettaLLM for Lettabot, openai.LLM for others
        llm=_llm_instance,

        # TTS — reads live config (use named ref so config watcher updates take effect)
        tts=tts_plugin,

        # Preemptive generation: let user interrupt mid-processing
        preemptive_generation=bool(eff.get("preemptive_generation", False)),
    )

    # Start session with persistent room IO.
    # Keep the agent session alive when text clients connect/disconnect between probes.
    await session.start(
        agent=RVAgent(),
        room=ctx.room,
        room_options=room_io.RoomOptions(
            close_on_disconnect=False,
        ),
    )

    # ── Forward agent state + responses back to Flutter client ──────────────

    @session.on("agent_state_changed")
    def on_agent_state_changed(ev) -> None:
        """Publish agent state as data message so Flutter orb can update."""
        state_val = ev.new_state
        logger.info("Agent state changed → %s", state_val)
        state_msg = json.dumps({"type": "state", "state": state_val}).encode()

        async def _pub():
            logger.debug("_pub() starting for state '%s'", state_val)
            try:
                await ctx.room.local_participant.publish_data(state_msg, reliable=True)
                logger.info("Published state '%s' to room ✓", state_val)
            except Exception as e:
                logger.warning("Failed to publish agent state '%s': %s", state_val, e)

        try:
            loop = asyncio.get_running_loop()
            loop.create_task(_pub())
            logger.debug("Scheduled publish task for state '%s'", state_val)
        except RuntimeError:
            logger.warning("No running event loop for state '%s'", state_val)

    @session.on("conversation_item_added")
    def on_conversation_item_added(ev) -> None:
        """Publish user transcripts so Flutter chat history gets user turns.
        Assistant turns are delivered via TranscriptionEvent (synced to TTS),
        which already populates chat history — no separate data message needed.
        Sending both caused a race condition double-text bug."""
        item = ev.item
        if not hasattr(item, "role"):
            return
        if item.role != "user":
            return  # assistant text comes via TranscriptionEvent
        content = item.content
        if isinstance(content, list):
            text = " ".join(
                c.text if hasattr(c, "text") else str(c) for c in content
            ).strip()
        else:
            text = (str(content) if content else "").strip()
        if not text:
            return
        async def _pub():
            try:
                await ctx.room.local_participant.publish_data(
                    json.dumps({"type": "user_transcript", "text": text}).encode(),
                    reliable=True,
                )
            except Exception as e:
                logger.debug("Failed to publish user_transcript: %s", e)
        asyncio.create_task(_pub())

    # Log participant and track events for debugging
    @ctx.room.on("track_subscribed")
    def on_track_subscribed(track, publication, participant):
        logger.info("Track subscribed: kind=%s from=%s", track.kind, participant.identity)

    @ctx.room.on("track_published")
    def on_track_published(publication, participant):
        logger.info("Track published: kind=%s source=%s from=%s", publication.kind, publication.source, participant.identity)

    # Log already-connected participants at session start
    for identity, participant in ctx.room.remote_participants.items():
        logger.info("Already in room: %s (tracks: %d)", identity, len(participant.track_publications))

    # Image handling is registered in RVAgent.on_enter() using the official
    # LiveKit v1 pattern (chat_ctx + update_chat_ctx + generate_reply).

    # LiveKit event emitter expects sync callbacks; schedule async work inside.
    @ctx.room.on("data_received")
    def on_data_received(packet):
        async def _handle() -> None:
            participant_identity = (
                packet.participant.identity if packet.participant else "unknown"
            )
            try:
                payload = json.loads(packet.data.decode("utf-8"))
                msg_type = payload.get("type")

                if msg_type == "tool_approval_response":
                    approval_id = payload.get("approval_id", "")
                    approved = bool(payload.get("approved", False))
                    logger.info(
                        "Tool approval response from %s: id=%s approved=%s",
                        participant_identity, approval_id, approved,
                    )
                    RVAgent.resolve_approval(approval_id, approved)
                    return

                # Debug-only: trigger a fake approval request to test the
                # client-side approval banner without LLM tool calling.
                if msg_type == "debug_trigger_approval":
                    query = payload.get("query", "test query")
                    approval_id = f"debug_{int(time.time() * 1000)}"
                    loop = asyncio.get_running_loop()
                    fut: asyncio.Future = loop.create_future()
                    RVAgent._pending_approvals[approval_id] = fut
                    await ctx.room.local_participant.publish_data(
                        json.dumps({
                            "type": "tool_approval_request",
                            "approval_id": approval_id,
                            "tool_name": "web_search",
                            "tool_args": {"query": query},
                            "description": f'Search the web for: "{query}"',
                        }).encode(),
                        reliable=True,
                    )
                    logger.info("Debug approval request sent: id=%s query=%r", approval_id, query)
                    try:
                        approved: bool = await asyncio.wait_for(asyncio.shield(fut), timeout=60.0)
                        logger.info("Debug approval result: id=%s approved=%s", approval_id, approved)
                    except asyncio.TimeoutError:
                        logger.info("Debug approval timed out: id=%s", approval_id)
                        RVAgent._pending_approvals.pop(approval_id, None)
                    return


            except json.JSONDecodeError:
                logger.warning("Invalid JSON in data message from %s", participant_identity)
            except RuntimeError as e:
                logger.debug("Skipping data message because agent session is unavailable: %s", e)
            except Exception as e:
                logger.error("Error processing data message: %s", e)

        asyncio.create_task(_handle())

    def _try_generate_reply(*, instructions: str, reason: str) -> None:
        if not _session_can_generate_reply(session):
            logger.debug("Skipping %s because agent session is not running", reason)
            return
        try:
            session.generate_reply(user_input=instructions)
        except RuntimeError as e:
            logger.debug("Skipping %s because agent session is unavailable: %s", reason, e)
        except Exception as e:
            logger.warning("%s failed (non-fatal): %s", reason, e)
    @ctx.room.on("participant_disconnected")
    def on_participant_disconnected(participant) -> None:
        identity = getattr(participant, "identity", "unknown")
        logger.info(
            "Participant '%s' disconnected — keeping agent session alive for future reconnects",
            identity,
        )


    # Watch config_override.json via inotify — hot-swaps LLM/STT/TTS on profile change.
    async def _config_watcher() -> None:
        import os
        from watchfiles import awatch
        _cfg = os.path.abspath("config_override.json")
        _cur_voice = eff.get("tts_voice", config.tts_voice)
        _cur_speed = float(eff.get("tts_speed", config.tts_speed))
        _cur_stt_model = eff.get("stt_model", config.stt_model)
        _cur_stt_url = eff.get("stt_url", config.stt_url)
        _cur_tts_url = eff.get("tts_url", config.tts_url)
        _cur_tts_model = eff.get("tts_model", "tts-1")
        _cur_llm_url = eff.get("llm_base_url", config.llm_base_url)
        _cur_llm_model = eff.get("llm_model", config.llm_model)
        _cur_llm_key = eff.get("llm_api_key", config.llm_api_key)
        async for _ in awatch(_cfg):
            try:
                load_config_override()
                _new = get_effective_config()

                # --- TTS voice/speed hot-reload (in-place update_options) ---
                tts_kw = {}
                _v = _new.get("tts_voice", config.tts_voice)
                _s = float(_new.get("tts_speed", config.tts_speed))
                if _v != _cur_voice:
                    tts_kw["voice"] = _v
                    _cur_voice = _v
                if _s != _cur_speed:
                    tts_kw["speed"] = _s
                    _cur_speed = _s
                if tts_kw:
                    tts_plugin.update_options(**tts_kw)
                    logger.info("[CONFIG] TTS voice/speed updated: %s", tts_kw)

                # --- STT model hot-reload (in-place update_options) ---
                _m = _new.get("stt_model", config.stt_model)
                _new_stt_url = _new.get("stt_url", config.stt_url)
                stt_changed = False
                if _m != _cur_stt_model:
                    stt_plugin.update_options(model=_m)
                    logger.info("[CONFIG] STT model: %s -> %s", _cur_stt_model, _m)
                    _cur_stt_model = _m
                    stt_changed = True
                if _new_stt_url != _cur_stt_url:
                    # STT URL changed — SDK update_options doesn't support base_url,
                    # so create a new STT instance and swap on the session.
                    new_stt = openai.STT(
                        base_url=_v1(_new_stt_url),
                        model=_m,
                        api_key="sk-no-key-required",
                    )
                    session._stt = new_stt
                    logger.info("[CONFIG] STT hot-swapped: url=%s", _new_stt_url)
                    _cur_stt_url = _new_stt_url
                    stt_changed = True

                # --- TTS URL/model hot-reload — rebuild TTS when endpoint or model changes ---
                _new_tts_url = _new.get("tts_url", config.tts_url)
                _new_tts_model = _new.get("tts_model", "tts-1")
                if _new_tts_url != _cur_tts_url or _new_tts_model != _cur_tts_model:
                    _new_tts_fmt = "wav" if _new_tts_model == "piper" else "mp3"
                    new_tts = openai.TTS(
                        base_url=_v1(_new_tts_url),
                        api_key="sk-no-key-required",
                        model=_new_tts_model,
                        voice=_cur_voice,
                        speed=_cur_speed,
                        response_format=_new_tts_fmt,
                    )
                    session._tts = new_tts
                    _cur_tts_url = _new_tts_url
                    _cur_tts_model = _new_tts_model
                    logger.info("[CONFIG] TTS hot-swapped: url=%s model=%s fmt=%s", _new_tts_url, _new_tts_model, _new_tts_fmt)

                # --- LLM config change (log only, applied on next session) ---
                # LLM cannot be safely hot-swapped mid-session (stateful, fragile).
                # Client reconnects on profile switch, which starts a fresh session
                # with the new config.
                _new_url = _new.get("llm_base_url", config.llm_base_url)
                _new_model = _new.get("llm_model", config.llm_model)
                _new_key = _new.get("llm_api_key", config.llm_api_key)
                if _new_url != _cur_llm_url or _new_model != _cur_llm_model or _new_key != _cur_llm_key:
                    logger.info("[CONFIG] LLM config changed: url=%s model=%s (applied on next session)", _new_url, _new_model)
                    _cur_llm_url = _new_url
                    _cur_llm_model = _new_model
                    _cur_llm_key = _new_key
            except Exception as _e:
                logger.warning("[CONFIG] Watcher error: %s", _e)

    asyncio.create_task(_config_watcher())

    # Keep job alive; exit cleanly if session crashes so watchdog redispatches
    _session_dead = asyncio.Event()

    @session.on("close")
    def _on_session_close(_ev=None):
        if not _session_dead.is_set():
            logger.warning("[RECOVERY] AgentSession closed -- exiting worker in 2s for auto-redispatch")
            async def _do_exit():
                await asyncio.sleep(2)
                _session_dead.set()
            asyncio.create_task(_do_exit())

    await _session_dead.wait()
    import os as _os
    _os._exit(1)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Start MCP server once in the main process (not per-worker)
    if config.mcp_enabled:
        _mcp_backend = BackendClient(
            host=config.backend_host,
            port=config.backend_port,
            connect_timeout=config.backend_connect_timeout,
            min_backoff=config.backend_min_backoff,
            max_backoff=config.backend_max_backoff,
        )
        _mcp_backend.start_in_background()
        time.sleep(2)  # Brief wait for initial connection
        logger.info(f"Starting MCP server on port {config.mcp_port} (main process)")
        _mcp_thread = threading.Thread(
            target=run_mcp_server,
            args=(_mcp_backend, config.mcp_port),
            daemon=True,
            name="mcp-server",
        )
        _mcp_thread.start()
        logger.info("MCP server thread started in main process")

    cli.run_app(server)
