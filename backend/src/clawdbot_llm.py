from __future__ import annotations

import json
import os
import time
import uuid
from dataclasses import dataclass
from typing import Optional

import aiohttp
from livekit.agents.llm import ChatChunk, Choice, ChoiceDelta
from livekit.agents.llm.chat_context import ChatContext
from livekit.agents.llm.function_context import FunctionContext
from livekit.agents.llm.llm import LLM, LLMStream


@dataclass
class ClawdbotLLMOptions:
    base_url: str
    token: str
    agent_id: str = "main"
    timeout_s: float = 120.0


class ClawdbotLLM(LLM):
    def __init__(
        self,
        *,
        base_url: str,
        token: str,
        agent_id: str = "main",
        participant=None,
        timeout_s: float = 120.0,
    ):
        self._opts = ClawdbotLLMOptions(
            base_url=base_url.rstrip("/"),
            token=token,
            agent_id=agent_id,
            timeout_s=timeout_s,
        )
        self._participant = participant

    def chat(
        self,
        chat_ctx: ChatContext,
        fnc_ctx: Optional[FunctionContext] = None,
        temperature: Optional[float] = None,
        n: Optional[int] = None,
    ) -> LLMStream:
        # Minimal bridge: non-streamed reply, no tool calls.
        return _ClawdbotLLMStream(self._opts, chat_ctx, participant=self._participant)


class _ClawdbotLLMStream(LLMStream):
    def __init__(self, opts: ClawdbotLLMOptions, chat_ctx: ChatContext, participant=None):
        super().__init__()
        self._opts = opts
        self._chat_ctx = chat_ctx
        self._participant = participant
        self._done = False

    def __aiter__(self):
        return self

    async def __anext__(self) -> ChatChunk:
        if self._done:
            raise StopAsyncIteration

        self._done = True
        content = await self._run()

        return ChatChunk(
            request_id=f"clawdbot-{uuid.uuid4().hex}",
            choices=[
                Choice(
                    delta=ChoiceDelta(content=content, role="assistant"),
                    index=0,
                    finish_reason="stop",
                )
            ],
            usage=None,
        )

    async def aclose(self) -> None:
        self._done = True

    async def _set_vox(self, state: Optional[str], status_text: Optional[str]) -> None:
        if not self._participant:
            return

        attrs: dict[str, str] = {}
        if state is not None:
            attrs["vox.state"] = state
        if status_text is not None:
            attrs["vox.statusText"] = status_text

        if not attrs:
            return

        try:
            await self._participant.set_attributes(attrs)
        except Exception:
            return

    async def _clear_vox(self) -> None:
        if not self._participant:
            return
        try:
            await self._participant.set_attributes({"vox.state": "", "vox.statusText": ""})
        except Exception:
            return

    @staticmethod
    def _chat_ctx_to_messages(chat_ctx: ChatContext) -> list[dict[str, str]]:
        # LiveKit gives us a list of messages; keep it in OpenAI format.
        messages = []
        for m in chat_ctx.to_dict():
            role = (m.get("role") or "").strip()
            content = m.get("content")
            if not role or not content:
                continue
            messages.append({"role": role, "content": content})
        return messages

    async def _run(self) -> str:
        start = time.time()
        await self._set_vox("thinking", "Thinking…")

        url = f"{self._opts.base_url}/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self._opts.token}",
            "Content-Type": "application/json",
        }

        model = f"agent:{self._opts.agent_id}" if self._opts.agent_id else "agent:main"
        messages = self._chat_ctx_to_messages(self._chat_ctx)

        # The gateway derives session affinity from `user` if provided.
        user = os.getenv("CLAWDBOT_SESSION_USER")

        payload: dict[str, object] = {
            "model": model,
            "messages": messages,
            "stream": False,
        }
        if user:
            payload["user"] = user

        timeout = aiohttp.ClientTimeout(total=self._opts.timeout_s)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(url, headers=headers, json=payload) as resp:
                body = await resp.text()
                resp.raise_for_status()

        await self._clear_vox()

        try:
            data = json.loads(body)
            content = (
                (data.get("choices") or [{}])[0]
                .get("message", {})
                .get("content")
            )
        except Exception:
            content = None

        content = (content or "").strip()
        if not content:
            return "Sorry — I didn’t get a response back."

        max_chars = int(os.getenv("MAX_SPOKEN_CHARS", "2000"))
        if max_chars > 0 and len(content) > max_chars:
            content = content[: max_chars - 3].rstrip() + "..."

        elapsed = time.time() - start
        if elapsed > 5:
            print(f"[clawdbot] round-trip {elapsed:.1f}s")

        return content
