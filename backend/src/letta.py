"""
letta.py — Letta LLM Plugin for LiveKit Agents v1.4.5

MCP tool calling pattern:
- Letta server = brain (memory + reasoning + tool calling via MCP)
- Client harness = voice interface (just streams text)

Tools are called via MCP server (mcp_server.py), not through LiveKit.
The plugin just streams text responses from Letta.

Flow with LiveKit:
1. chat() returns LLMStream instance
2. LLMStream._run() calls Letta streaming API
3. For AssistantMessage: emit text chunk
4. Tool calls are handled by Letta directly via MCP
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Any, List, Optional

from livekit.agents import llm
from livekit.agents.llm import ChatContext, ChatChunk, ChoiceDelta
from livekit.agents.llm.llm import DEFAULT_API_CONNECT_OPTIONS, APIConnectOptions

logger = logging.getLogger(__name__)


@dataclass
class LettaLLMConfig:
    """Configuration for Letta LLM plugin."""
    agent_id: str
    letta_url: str = "http://localhost:8283"
    letta_api_key: Optional[str] = None
    timeout: float = 60.0


class LettaLLMStream(llm.LLMStream):
    """
    LLMStream implementation for Letta with MCP tool calling.
    
    Just streams text responses from Letta. Tool calls are handled
    by Letta directly via MCP server.
    """

    def __init__(
        self,
        llm: "LettaLLM",
        *,
        chat_ctx: ChatContext,
        conn_options: APIConnectOptions,
        client: Any,
        agent_id: str,
    ) -> None:
        super().__init__(llm, chat_ctx=chat_ctx, tools=[], conn_options=conn_options)
        self._client = client
        self._agent_id = agent_id
        self._parent_llm = llm
        self._prompt_preview = ""
        self._chunk_types: list[str] = []
        self._tool_names: set[str] = set()
        self._tool_returns: list[dict[str, str]] = []
        self._saw_tool_call = False
        self._saw_tool_return = False

    async def _run(self) -> None:
        """Main execution loop - called by LLMStream base class."""
        try:
            # Ensure client is initialized (lazy init from parent LLM)
            if self._client is None:
                await self._parent_llm._ensure_initialized()
                self._client = self._parent_llm._client

            # Build Letta messages - only latest user message
            letta_messages = self._build_letta_messages()

            if not letta_messages:
                logger.warning("No messages to send to Letta — aborting stream call")
                return

            logger.debug(f"Sending {len(letta_messages)} messages to Letta agent {self._agent_id}")
            
            # Use streaming API
            stream = await self._client.agents.messages.stream(
                agent_id=self._agent_id,
                messages=letta_messages,
                streaming=True,
                include_return_message_types=[
                    "assistant_message",
                    "tool_call_message",
                    "tool_return_message",
                ],
            )
            
            # Process the stream
            chunk_count = 0
            async for chunk in stream:
                chunk_count += 1
                await self._process_chunk(chunk)

            logger.info(
                "LETTA_TURN_SUMMARY prompt=%r saw_tool_call=%s saw_tool_return=%s tool_names=%s tool_returns=%s chunk_types=%s",
                self._prompt_preview,
                self._saw_tool_call,
                self._saw_tool_return,
                sorted(self._tool_names),
                self._tool_returns,
                self._chunk_types,
            )
            logger.info(
                "LETTA_TURN_SUMMARY_JSON %s",
                json.dumps(
                    {
                        "prompt": self._prompt_preview,
                        "saw_tool_call": self._saw_tool_call,
                        "saw_tool_return": self._saw_tool_return,
                        "tool_names": sorted(self._tool_names),
                        "tool_returns": self._tool_returns,
                        "chunk_types": self._chunk_types,
                    },
                    ensure_ascii=False,
                ),
            )
            logger.info(f"Letta stream completed: {chunk_count} chunks processed")
                
        except Exception as e:
            logger.error(f"LettaLLM stream error: {e}", exc_info=True)

    async def _process_chunk(self, chunk: Any) -> None:
        """Process a single chunk from the Letta stream."""
        msg_type = getattr(chunk, 'message_type', None)
        self._chunk_types.append(msg_type or chunk.__class__.__name__)
        logger.debug(f"Letta chunk: {msg_type}")

        if msg_type == "assistant_message":
            # Text response from agent - emit as-is
            raw_content = getattr(chunk, 'content', '')
            if isinstance(raw_content, list):
                content = " ".join(
                    item.text for item in raw_content
                    if hasattr(item, 'text') and item.text
                ).strip()
            else:
                content = raw_content or ''
            
            if content:
                logger.debug(f"assistant_message: {content[:120]}")
                self._event_ch.send_nowait(
                    ChatChunk(
                        id="response",
                        delta=ChoiceDelta(
                            role="assistant",
                            content=content,
                        ),
                    )
                )
        
        elif msg_type == "tool_call_message":
            # Tool called via MCP - just log it
            self._saw_tool_call = True
            tool_call = getattr(chunk, 'tool_call', None)
            if tool_call:
                tool_name = getattr(tool_call, 'name', '')
                if tool_name:
                    self._tool_names.add(tool_name)
                logger.info(f"MCP tool called: {tool_name}")
        
        elif msg_type == "tool_return_message":
            # Tool return result - log it
            self._saw_tool_return = True
            tool_name = getattr(chunk, 'name', '')
            if tool_name:
                self._tool_names.add(tool_name)
            tool_return = getattr(chunk, 'tool_return', '')
            tool_return_text = str(tool_return or '')
            self._tool_returns.append(
                {
                    "name": tool_name,
                    "output": tool_return_text,
                }
            )
            logger.debug(f"Tool return: {tool_return_text[:100] if tool_return_text else '(empty)'}")
        
        elif msg_type == "reasoning_message":
            reasoning = getattr(chunk, 'reasoning', '')
            if reasoning:
                logger.debug(f"Reasoning: {reasoning[:200]}...")
        
        elif msg_type == "stop_reason":
            reason = getattr(chunk, 'reason', None)
            logger.debug(f"Stop reason: {reason}")

    def _build_letta_messages(self) -> List[Any]:
        """
        Build Letta message format from chat context.
        
        Sends only the latest user message.
        Let Letta server manage its own message history.
        """
        messages = []

        # Find latest user message
        for item in reversed(self._chat_ctx.items):
            if hasattr(item, 'role') and item.role == 'user':
                content = item.content

                if isinstance(content, str):
                    letta_content = content
                elif isinstance(content, list):
                    letta_content_parts = []
                    for c in content:
                        if isinstance(c, str):
                            letta_content_parts.append(c)
                        elif hasattr(c, 'type') and c.type == 'text':
                            letta_content_parts.append(c.text)
                        else:
                            letta_content_parts.append(str(c))
                    letta_content = " ".join(letta_content_parts)
                else:
                    letta_content = str(content)

                messages.append({
                    "role": "user",
                    "content": letta_content
                })
                self._prompt_preview = letta_content[:200]
                logger.debug(f"User message: {letta_content[:100]}...")
                break

        if not messages:
            # Check for instruction-only turn (e.g., greeting)
            for item in reversed(self._chat_ctx.items):
                if hasattr(item, 'role') and item.role in ('developer', 'system'):
                    content = item.content
                    if isinstance(content, str):
                        letta_content = content
                    elif isinstance(content, list):
                        parts = []
                        for c in content:
                            if isinstance(c, str):
                                parts.append(c)
                            elif hasattr(c, 'type') and c.type == 'text':
                                parts.append(c.text)
                            else:
                                parts.append(str(c))
                        letta_content = " ".join(parts)
                    else:
                        letta_content = str(content)

                    letta_content = letta_content.strip()
                    if not letta_content:
                        continue

                    # Skip long developer messages (base instructions)
                    if len(letta_content) > 500:
                        logger.debug(f"Skipping long developer message ({len(letta_content)} chars)")
                        continue

                    messages.append({
                        "role": "user",
                        "content": f"SYSTEM: {letta_content}",
                    })
                    self._prompt_preview = f"SYSTEM: {letta_content}"[:200]
                    logger.debug(f"Instruction: {letta_content[:100]}")
                    break

        return messages


class LettaLLM(llm.LLM):
    """
    OpenAI-compatible LLM interface for Letta agents.
    
    Tools are handled by Letta directly via MCP server.
    """

    def __init__(self, config: LettaLLMConfig) -> None:
        super().__init__()
        self.config = config
        self._client: Optional[Any] = None
        self._initialized = False

    @property
    def model(self) -> str:
        return f"letta/{self.config.agent_id}"

    @property
    def provider(self) -> str:
        return "letta"

    async def _ensure_initialized(self) -> None:
        """Lazy initialization of Letta client."""
        if self._initialized:
            return
        
        try:
            from letta_client import AsyncLetta
            
            self._client = AsyncLetta(
                base_url=self.config.letta_url,
                **({'api_key': self.config.letta_api_key} if self.config.letta_api_key else {})
            )
            self._initialized = True
            logger.info(f"LettaLLM initialized (agent: {self.config.agent_id})")
        except Exception as e:
            logger.error(f"Failed to initialize Letta client: {e}")
            raise

    def chat(
        self,
        *,
        chat_ctx: ChatContext,
        tools: Optional[List[llm.Tool]] = None,
        conn_options: APIConnectOptions = DEFAULT_API_CONNECT_OPTIONS,
        **kwargs,
    ) -> llm.LLMStream:
        """
        Main entry point for chat completions.
        
        Tools are ignored - they're handled by Letta via MCP.
        """
        logger.info(f"LettaLLM.chat called (tools handled by MCP)")
        
        stream = LettaLLMStream(
            self,
            chat_ctx=chat_ctx,
            conn_options=conn_options,
            client=self._client,
            agent_id=self.config.agent_id,
        )
        return stream

    async def aclose(self) -> None:
        """Clean up resources."""
        pass
