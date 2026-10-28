#!/usr/bin/env python3
"""Room keeper — stays connected to vox-ui-room so LiveKit never deletes it.

The LiveKit server deletes rooms when all *client-kind* participants leave
(agent-kind participants don't keep a room alive). Every room deletion kills
the agent session mid-turn (RECOVERY exit -> zombie process -> watchdog
re-dispatch churn). This keeper holds one persistent connection so the room
stays alive across test clients joining/leaving.

Usage: python3 room_keeper.py   (run in tmux, logs state changes)
"""
import asyncio
import json
import time
import urllib.request

from livekit import rtc

HTTP = "http://localhost:3000"


def get_token():
    with urllib.request.urlopen(f"{HTTP}/api/token?identity=room-keeper") as resp:
        data = json.loads(resp.read().decode())
    return data["token"], data.get("wsUrl") or "ws://localhost:7880"


async def main():
    while True:
        try:
            token, ws_url = get_token()
            room = rtc.Room()

            @room.on("participant_connected")
            def _on_join(p):
                print(f"[keeper] joined: {p.identity}", flush=True)

            @room.on("participant_disconnected")
            def _on_leave(p):
                print(f"[keeper] left: {p.identity}", flush=True)

            @room.on("data_received")
            def _on_data(packet):
                try:
                    d = json.loads(packet.data.decode())
                    if d.get("type") == "agent_state":
                        print(f"[keeper] agent state: {d.get('state')}", flush=True)
                except Exception:
                    pass

            await room.connect(ws_url, token)
            print(f"[keeper] connected {time.strftime('%H:%M:%S')} as {room.local_participant.identity}", flush=True)

            disconnected = asyncio.Event()
            room.on("disconnected")(lambda: disconnected.set())
            await disconnected.wait()
            print("[keeper] disconnected — reconnecting in 2s", flush=True)
            await asyncio.sleep(2)
        except Exception as e:
            print(f"[keeper] error: {e} — retry in 5s", flush=True)
            await asyncio.sleep(5)


if __name__ == "__main__":
    asyncio.run(main())
