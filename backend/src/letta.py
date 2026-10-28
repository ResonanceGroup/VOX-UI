"""
letta.py — Lettabot LLM Plugin for LiveKit Agents v1.4.5

Uses the Lettabot OpenAI-compatible API (/v1/chat/completions) to stream
responses from a Letta agent. Tool call events in the SSE stream are
captured and published as data messages to the Flutter client for UI
display (chat tiles + status text). Each tool call event also resets
the read timeout (keepalive).

Flow:
1. chat() returns LLMStream instance
2. LLMStream._run() calls Lettabot /v1/chat/completions (streaming)
3. Text deltas → emit as ChatChunk
4. Tool call deltas → publish tool_call_status data message + reset timeout
5. Finish → done

The Lettabot API already emits tool_call chunks in the SSE stream
(server.ts line 657-664), so we parse them here.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Any, Callable, List, Optional

from livekit.agents import llm
from livekit.agents.llm import ChatContext, ChatChunk, ChoiceDelta, FunctionToolCall
from livekit.agents.llm.llm import DEFAULT_API_CONNECT_OPTIONS, APIConnectOptions

logger = logging.getLogger(__name__)


@dataclass
class LettaLLMConfig:
    """Configuration for Lettabot LLM plugin."""
    agent_name: str  # e.g., "Milo"
    api_url: str = "http://192.168.122.116:8080"
    api_key: str = ""
    timeout: float = 300.0
    # Callback to publish data messages to the LiveKit room
    publish_data: Optional[Callable[[dict], Any]] = None
    # Callback to reset the read timeout (keepalive on tool calls)
    reset_timeout: Optional[Callable[[], None]] = None


# Friendly display names for common tool names
_TOOL_DISPLAY_NAMES = {
    "web_search": "Searching the web",
    "get_current_time": "Getting the time",
    "fetch_webpage": "Fetching webpage",
    "run_python": "Running code",
    "Bash": "Running a command",
    "memory": "Updating memory",
    "archival_memory_insert": "Saving to memory",
    "archival_memory_search": "Searching memory",
    "core_memory_append": "Updating context",
    "core_memory_replace": "Updating context",
    "send_message": "Sending message",
}


def _tool_display_name(tool_name: str) -> str:
    """Return a short, human-readable phrase for a tool call."""
    if tool_name in _TOOL_DISPLAY_NAMES:
        return _TOOL_DISPLAY_NAMES[tool_name]
    # Fallback: convert snake_case to title case
    return tool_name.replace("_", " ").title()


class LettaLLMStream(llm.LLMStream):
    """
    LLMStream implementation for Lettabot OpenAI-compatible API.

    Streams text responses and publishes tool call status as data messages.
    """

    def __init__(
        self,
        llm: "LettaLLM",
        *,
        chat_ctx: ChatContext,
        conn_options: APIConnectOptions,
        client: Any,
        agent_name: str,
    ) -> None:
        super().__init__(llm, chat_ctx=chat_ctx, tools=[], conn_options=conn_options)
        self._client = client  # openai.AsyncOpenAI instance
        self._agent_name = agent_name
        self._parent_llm = llm
        self._prompt_preview = ""
        self._tool_call_count = 0
        # Track tool calls by index to match call/return
        self._active_tool_calls: dict[int, str] = {}  # index → tool_name

    async def _publish_tool_status(self, tool_name: str, status: str) -> None:
        """Publish a tool_call_status data message to the Flutter client."""
        publish_fn = self._parent_llm.config.publish_data
        if publish_fn is None:
            return
        try:
            await publish_fn({
                "type": "tool_call_status",
                "tool_name": tool_name,
                "display_name": _tool_display_name(tool_name),
                "status": status,  # "calling" or "completed"
                "count": self._tool_call_count,
            })
        except Exception as e:
            logger.debug("Failed to publish tool_call_status: %s", e)

    def _reset_timeout(self) -> None:
        """Reset the read timeout (keepalive)."""
        reset_fn = self._parent_llm.config.reset_timeout
        if reset_fn is not None:
            try:
                reset_fn()
            except Exception as e:
                logger.debug("Failed to reset timeout: %s", e)

    async def _run(self) -> None:
        """Main execution loop - called by LLMStream base class."""
        try:
            # Lazy init — ensure the OpenAI client is ready
            if self._client is None:
                await self._parent_llm._ensure_initialized()
                self._client = self._parent_llm._client

            # Build messages - only latest user message (slim context)
            user_message = self._extract_user_message()
            if not user_message:
                logger.warning("No user message to send to Lettabot — aborting stream call")
                return

            self._prompt_preview = user_message[:200]
            logger.info("LettaLLM: sending to %s (model=%s): %s...",
                        self._parent_llm.config.api_url,
                        self._agent_name,
                        user_message[:100])

            # Call Lettabot OpenAI-compatible streaming API
            response = await self._client.chat.completions.create(
                model=self._agent_name,
                messages=[{"role": "user", "content": user_message}],
                stream=True,
                timeout=self._parent_llm.config.timeout,
            )

            # Process the stream
            chunk_count = 0
            async for chunk in response:
                chunk_count += 1
                if not chunk.choices:
                    continue

                choice = chunk.choices[0]
                delta = choice.delta

                # Text content
                if delta.content:
                    self._event_ch.send_nowait(
                        ChatChunk(
                            id="response",
                            delta=ChoiceDelta(
                                role="assistant",
                                content=delta.content,
                            ),
                        )
                    )

                # Tool call events — the Lettabot API emits these in the SSE stream
                if delta.tool_calls:
                    for tc_delta in delta.tool_calls:
                        tc_index = getattr(tc_delta, 'index', 0)
                        tc_id = getattr(tc_delta, 'id', None) or f"call_{tc_index}"
                        func = getattr(tc_delta, 'function', None)
                        tool_name = getattr(func, 'name', None) or 'unknown'
                        tool_args = getattr(func, 'arguments', None) or '{}'

                        if tool_name and tool_name != 'unknown':
                            self._tool_call_count += 1
                            self._active_tool_calls[tc_index] = tool_name
                            logger.info("Lettabot tool_call: %s (index=%d)", tool_name, tc_index)

                            # Publish tool call status to Flutter
                            await self._publish_tool_status(tool_name, "calling")
                            # Reset timeout (keepalive)
                            self._reset_timeout()

                # Finish reason
                if choice.finish_reason in ("tool_calls", "stop"):
                    # Lettabot executes tools internally — by the time we get
                    # finish_reason, tools are done. Publish completed for any
                    # active tool calls we saw during the stream.
                    for idx, name in self._active_tool_calls.items():
                        await self._publish_tool_status(name, "completed")
                        self._reset_timeout()
                    self._active_tool_calls.clear()

            logger.info("LettaLLM stream completed: %d chunks, %d tool calls",
                        chunk_count, self._tool_call_count)

        except Exception as e:
            logger.error("LettaLLM stream error: %s", e, exc_info=True)

    def _extract_user_message(self) -> str:
        """Extract the latest user message from chat context."""
        for item in reversed(self._chat_ctx.items):
            if hasattr(item, 'role') and item.role == 'user':
                content = item.content
                if isinstance(content, str):
                    return content
                elif isinstance(content, list):
                    parts = []
                    for c in content:
                        if isinstance(c, str):
                            parts.append(c)
                        elif hasattr(c, 'type') and c.type == 'text':
                            parts.append(c.text)
                        else:
                            parts.append(str(c))
                    return " ".join(parts)
                else:
                    return str(content)
        return ""


class LettaLLM(llm.LLM):
    """
    OpenAI-compatible LLM interface for Lettabot agents.

    Uses the Lettabot /v1/chat/completions endpoint.
    Tool call events in the SSE stream are published as data messages
    for UI display.
    """

    def __init__(self, config: LettaLLMConfig) -> None:
        super().__init__()
        self.config = config
        self._client: Optional[Any] = None
        self._initialized = False

    @property
    def model(self) -> str:
        return f"lettabot/{self.config.agent_name}"

    @property
    def provider(self) -> str:
        return "lettabot"

    async def _ensure_initialized(self) -> None:
        """Lazy initialization of OpenAI client pointed at Lettabot."""
        if self._initialized:
            return

        try:
            from openai import AsyncOpenAI

            self._client = AsyncOpenAI(
                base_url=f"{self.config.api_url}/v1",
                api_key=self.config.api_key or "sk-placeholder",
                timeout=self.config.timeout,
            )
            self._initialized = True
            logger.info("LettaLLM initialized (agent=%s, url=%s)",
                        self.config.agent_name, self.config.api_url)
        except Exception as e:
            logger.error("Failed to initialize Lettabot client: %s", e)
            raise

    def chat(
        self,
        *,
        chat_ctx: ChatContext,
        tools: Optional[List[llm.Tool]] = None,
        conn_options: APIConnectOptions = DEFAULT_API_CONNECT_OPTIONS,
        **kwargs,
    ) -> llm.LLMStream:
        """Main entry point for chat completions."""
        logger.info("LettaLLM.chat called (model=%s)", self.config.agent_name)

        # Lazy init is handled in LettaLLMStream._run() — don't call
        # run_until_complete() here, the event loop is already running.

        stream = LettaLLMStream(
            self,
            chat_ctx=chat_ctx,
            conn_options=conn_options,
            client=self._client,
            agent_name=self.config.agent_name,
        )
        return stream

    async def aclose(self) -> None:
        """Clean up resources."""
        pass
