from __future__ import annotations

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
class A2ALLMOptions:
    a2a_url: str
    timeout_s: float = 120.0


class A2ALLM(LLM):
    def __init__(
        self,
        *,
        a2a_url: str,
        participant=None,
        timeout_s: float = 120.0,
        reset: bool = False,
    ):
        self._opts = A2ALLMOptions(a2a_url=a2a_url, timeout_s=timeout_s)
        self._participant = participant
        self._reset = reset

    def chat(
        self,
        chat_ctx: ChatContext,
        fnc_ctx: Optional[FunctionContext] = None,
        temperature: Optional[float] = None,
        n: Optional[int] = None,
    ) -> LLMStream:
        # Minimal bridge: no streaming and no tool-calls.
        return _A2ALLMStream(self._opts, chat_ctx, participant=self._participant, reset=self._reset)


class _A2ALLMStream(LLMStream):
    def __init__(self, opts: A2ALLMOptions, chat_ctx: ChatContext, participant=None, reset: bool = False):
        super().__init__()
        self._opts = opts
        self._chat_ctx = chat_ctx
        self._participant = participant
        self._reset = reset
        self._done = False

    def __aiter__(self):
        return self

    async def __anext__(self) -> ChatChunk:
        if self._done:
            raise StopAsyncIteration

        self._done = True
        content = await self._run()

        return ChatChunk(
            request_id=f"a2a-{uuid.uuid4().hex}",
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
        # UI treats empty strings as "unset"
        if not self._participant:
            return
        try:
            await self._participant.set_attributes({"vox.state": "", "vox.statusText": ""})
        except Exception:
            return

    async def _run(self) -> str:
        start = time.time()
        await self._set_vox("thinking", "Thinking…")

        messages = self._chat_ctx.to_dict()
        prompt_lines: list[str] = []
        for m in messages:
            role = m.get("role", "")
            content = m.get("content", "")
            if not content:
                continue
            prompt_lines.append(f"{role}: {content}")

        prompt = "\n".join(prompt_lines).strip()
        payload = {"message": prompt, "attachments": [], "reset": self._reset}

        timeout = aiohttp.ClientTimeout(total=self._opts.timeout_s)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(self._opts.a2a_url, json=payload) as resp:
                resp.raise_for_status()
                text = await resp.text()

        await self._clear_vox()

        text = (text or "").strip()
        if not text:
            return "Sorry — I didn’t get a response back."

        max_chars = int(os.getenv("MAX_SPOKEN_CHARS", "2000"))
        if max_chars > 0 and len(text) > max_chars:
            text = text[: max_chars - 3].rstrip() + "..."

        elapsed = time.time() - start
        if elapsed > 5:
            print(f"[a2a] round-trip {elapsed:.1f}s")

        return text
