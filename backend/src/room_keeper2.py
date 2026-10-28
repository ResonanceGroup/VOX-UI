#!/usr/bin/env python3
"""Room keeper v2 — keeps vox-ui-room alive but YIELDS the agent link.

Why: LiveKit deletes rooms with no client-kind participants (agent sessions
die mid-turn -> zombie churn). But the agent's RoomInput LINKS to the first
participant it sees — if the keeper is that participant, test clients' mic
tracks are ignored. So the keeper:
  - stays connected while the room is otherwise empty (keeps room alive)
  - DISCONNECTS the moment a non-agent participant joins (yields the link;
    the RoomInput re-links to the new participant)
  - reconnects once the room is empty again

Run in tmux: python3 room_keeper2.py
"""
import asyncio
import json
import time
import urllib.request

from livekit import rtc

HTTP = "http://localhost:3000"
POLL = 2.0


def get_token():
    with urllib.request.urlopen(f"{HTTP}/api/token?identity=room-keeper") as resp:
        data = json.loads(resp.read().decode())
    return data["token"], data.get("wsUrl") or "ws://localhost:7880"


async def list_non_agents():
    """Return identities of non-agent remote participants (via token svc is
    not available here — we track via room events instead)."""
    return None


async def main():
    while True:
        room = None
        try:
            token, ws_url = get_token()
            room = rtc.Room()
            yielded = False

            @room.on("participant_connected")
            def _on_join(p):
                nonlocal yielded
                if not p.identity.startswith("agent-"):
                    print(f"[keeper] real participant {p.identity} joined — yielding", flush=True)
                    yielded = True

            await room.connect(ws_url, token)
            print(f"[keeper] connected {time.strftime('%H:%M:%S')}", flush=True)

            # if someone is already in the room besides agents, yield immediately
            others = [p for p in room.remote_participants if not p.startswith("agent-")]
            if others:
                print(f"[keeper] room already has {others} — disconnecting to yield", flush=True)
                await room.disconnect()
                await asyncio.sleep(POLL)
                continue

            # stay until a real participant joins
            while not yielded:
                await asyncio.sleep(0.5)

            print("[keeper] disconnecting (yield)", flush=True)
            await room.disconnect()

            # wait for the room to be free of real participants, then reclaim
            while True:
                await asyncio.sleep(POLL)
                token2, _ = get_token()
                r2 = rtc.Room()
                await r2.connect(ws_url, token2)
                others = [p for p in r2.remote_participants if not p.startswith("agent-")]
                agents = [p for p in r2.remote_participants if p.startswith("agent-")]
                await r2.disconnect()
                if not others:
                    print(f"[keeper] room free (agents={len(agents)}) — reclaiming", flush=True)
                    break
                print(f"[keeper] still occupied by {others} — waiting", flush=True)
        except Exception as e:
            print(f"[keeper] error: {e} — retry in 5s", flush=True)
            if room and room.isconnected():
                try:
                    await room.disconnect()
                except Exception:
                    pass
            await asyncio.sleep(5)


if __name__ == "__main__":
    asyncio.run(main())
