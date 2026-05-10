#!/usr/bin/env python3
"""
VoxUI Test Client — injects text messages into the LiveKit room and
handles tool approval requests without a browser.

Usage:
    python test_client.py "what time is it"
    python test_client.py --auto-approve "search the web for Toledo Ohio weather"
    python test_client.py --auto-reject  "search the web for latest news"

Options:
    --auto-approve   Automatically approve any tool call requests
    --auto-reject    Automatically reject any tool call requests
    (default: prompt on stdin)

Environment:
    TOKEN_SERVICE_URL   default: http://localhost:3000
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
import time

import aiohttp
from livekit import rtc


TOKEN_SERVICE_URL = "http://localhost:3000"
RESPONSE_TIMEOUT = 45.0   # wait up to 45 s for agent reply


async def get_token(session: aiohttp.ClientSession, identity: str = "test-bot") -> tuple[str, str]:
    async with session.get(
        f"{TOKEN_SERVICE_URL}/api/token",
        params={"identity": identity},
        headers={"Accept": "application/json"},
    ) as resp:
        resp.raise_for_status()
        data = await resp.json(content_type=None)
    token = data["token"]
    # Always use internal LiveKit URL for test client (public URL goes through
    # Cloudflare and may not work from within rg-w00 itself)
    url = "ws://localhost:7880"
    return token, url


async def main() -> None:
    parser = argparse.ArgumentParser(description="VoxUI automated test client")
    parser.add_argument("message", help="Text message to send to the agent")
    parser.add_argument("--auto-approve", action="store_true", help="Auto-approve tool calls")
    parser.add_argument("--auto-reject",  action="store_true", help="Auto-reject tool calls")
    parser.add_argument("--timeout", type=float, default=RESPONSE_TIMEOUT)
    args = parser.parse_args()

    auto_approve = args.auto_approve
    auto_reject  = args.auto_reject

    print(f"[test-client] Connecting to {TOKEN_SERVICE_URL} …")
    async with aiohttp.ClientSession() as http:
        token, ws_url = await get_token(http)
    print(f"[test-client] Got token, joining room at {ws_url}")

    room = rtc.Room()
    # Track agent state transitions to detect when response is complete.
    # Done = first time we see "idle" after having seen any non-idle state,
    # OR after we've seen "speaking" at all.
    _state_history: list[str] = []
    _message_sent = False
    done_event = asyncio.Event()

    def _check_done() -> None:
        if not _message_sent:
            return
        # livekit-agents 1.4.5 state sequence: thinking → listening (no "speaking" mid-state)
        # Trigger on "listening" or "idle" after having seen "thinking"
        if _state_history and _state_history[-1] in ("listening", "idle"):
            seen_active = any(s in ("thinking", "speaking") for s in _state_history)
            if seen_active:
                done_event.set()

    @room.on("data_received")
    def on_data(packet: rtc.DataPacket) -> None:
        try:
            payload = json.loads(packet.data.decode())
        except Exception:
            return

        msg_type = payload.get("type")

        if msg_type == "tool_approval_request":
            approval_id = payload.get("approval_id", "")
            tool_name   = payload.get("tool_name", "unknown")
            description = payload.get("description", "")
            tool_args   = payload.get("tool_args", {})
            print(f"\n[TOOL CALL] {tool_name}")
            print(f"  Description: {description}")
            print(f"  Args:        {tool_args}")

            approved: bool
            if auto_approve:
                approved = True
                print("[test-client] Auto-approving.")
            elif auto_reject:
                approved = False
                print("[test-client] Auto-rejecting.")
            else:
                ans = input("  Approve? [y/N] ").strip().lower()
                approved = ans in ("y", "yes")

            resp_payload = json.dumps({
                "type": "tool_approval_response",
                "approval_id": approval_id,
                "approved": approved,
            }).encode()

            async def _send_approval() -> None:
                await room.local_participant.publish_data(resp_payload, reliable=True)
                print(f"[test-client] Approval response sent: approved={approved}")
            asyncio.ensure_future(_send_approval())

        elif msg_type == "state":
            state = payload.get("state", "")
            if state:
                _state_history.append(state)
                print(f"[state] {state}")
                _check_done()

        elif msg_type == "user_transcript":
            text = payload.get("text", "")
            if text:
                print(f"[user STT] {text}")

        else:
            # Log any unknown data messages for debugging
            print(f"[data] type={msg_type!r} payload={str(payload)[:120]}")

    @room.on("disconnected")
    def on_disconnected(reason=None) -> None:
        print(f"[test-client] Disconnected: {reason}")
        done_event.set()

    agent_joined = asyncio.Event()

    @room.on("participant_connected")
    def on_participant_connected(participant: rtc.RemoteParticipant) -> None:
        print(f"[test-client] Participant joined: {participant.identity}")
        if participant.identity.startswith("agent"):
            agent_joined.set()

    await room.connect(ws_url, token, options=rtc.RoomOptions(auto_subscribe=False))
    print(f"[test-client] Joined room: {room.name}")
    print(f"[test-client] Participants: {list(room.remote_participants.keys())}")

    # Check if agent is already in room
    if any(p.startswith("agent") for p in room.remote_participants.keys()):
        agent_joined.set()

    # Wait up to 30 s for agent to appear
    print("[test-client] Waiting for agent to join the room …")
    try:
        await asyncio.wait_for(agent_joined.wait(), timeout=30)
        print("[test-client] Agent is in the room.")
    except asyncio.TimeoutError:
        print("[test-client] ⚠️  Agent didn't join in 30s — sending anyway.")

    # Brief settle time after agent joins
    await asyncio.sleep(1.5)

    # Send text message via data channel (matches backend on_data_received handler)
    msg_bytes = json.dumps({"type": "text_input", "text": args.message}).encode()
    await room.local_participant.publish_data(msg_bytes, reliable=True)
    _message_sent = True
    print(f"\n[test-client] Sent: {args.message!r}")
    print(f"[test-client] Waiting up to {args.timeout}s for agent to finish responding …")

    # Wait for speaking→idle state cycle or timeout
    try:
        await asyncio.wait_for(done_event.wait(), timeout=args.timeout)
        print("[test-client] ✅ Response cycle complete.")
    except asyncio.TimeoutError:
        print(f"\n[test-client] ⚠️  Timed out after {args.timeout}s")
        print(f"[test-client] State history: {_state_history}")

    # Brief pause so any in-flight data lands
    await asyncio.sleep(2)
    await room.disconnect()
    print("[test-client] Done.")


if __name__ == "__main__":
    asyncio.run(main())
