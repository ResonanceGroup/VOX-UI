# RG Smart Control AI Backend

LiveKit-based voice agent for the Resonance Group smart RV control system.

**Current Status**: Phase 3B — First Stable Version (2026-03-23)

## Overview

A real-time voice interface ("Milo") for monitoring and controlling RV onboard systems via natural language commands. Runs on an NVIDIA Jetson Orin with LiveKit Agents, Letta persistent memory, Ollama local LLM, and the RG Smart Control Backend.

## Architecture

![RV Voice Agent Architecture](docs/references/rv-voice-agent-architecture.jpg)

For detailed architecture documentation, see [docs/SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md).

**System Components:**
- **STT:** Speaches/faster-whisper (port 9010)
- **LLM:** Letta Server (port 8283) + Ollama (port 11433) — `qwen3-coder-30b-instruct:8k`
- **TTS:** Kokoro (port 8880)
- **Backend:** RG Smart Control Backend (TCP port 9001)
- **Clients:** Flutter Dashboard & App, LiveKit Playground, text client

**Key Services:**
- **Letta Server**: Persistent memory, agent reasoning, proxy tool registry, sliding window compaction
- **LiveKit Agent Worker**: Voice pipeline (STT → LLM → TTS), tool execution, session management
- **RG Backend**: Device state management, JSON-RPC 2.0 over TCP

## Features

- Natural language control of RV devices (battery, lights, climate, water, etc.)
- Device state monitoring and querying via voice or text
- Persistent memory across sessions (Letta memory blocks)
- Proxy tool pattern: Letta reasons, LiveKit executes tools locally
- Receipt printer integration (diagnostics, custom content)
- Device name validation with fuzzy matching fallback
- Headless text client for automated testing/benchmarking

## Quick Start

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Ensure services are running: Letta, Ollama, LiveKit, STT, TTS, Backend

3. Configure `.env.phase2` (see [docs/SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md))

4. Run:
   ```bash
   python src/main.py dev        # Development mode (hot reload)
   python src/main.py start      # Production mode
   ```

5. Test:
   ```bash
   # Text client
   python3 src/livekit_text_client.py \
     --api-key "rv-agent-dev" --api-secret "<secret>" \
     --room "rv-test-$(date +%s)" \
     --prompt "What is the battery level?"

   # Voice: connect via agents-playground.livekit.io
   ```

## Phases

- **Phase 1:** Voice loop (STT → LLM → TTS) — COMPLETE
- **Phase 2:** Letta integration (persistent memory + reasoning) — COMPLETE
- **Phase 3A:** Validator + mock tool test harness (19/19 checks) — COMPLETE
- **Phase 3B:** Real backend tool execution via voice — STABLE
- **Phase 4:** Memory, heartbeat, sleep agent, production hardening — NEXT

## Key Files

| File | Purpose |
|------|---------|
| `src/main.py` | Entry point, AgentSession, RVAgent class |
| `src/letta.py` | LettaLLM plugin, proxy tool pattern, message building |
| `src/api.py` | BackendClient (JSON-RPC 2.0 over TCP) |
| `src/tools.py` | Tool definitions (read/write/list/print) |
| `src/validator.py` | Device name resolver with fuzzy matching |
| `src/config.py` | AgentConfig, environment-driven settings |
| `src/livekit_text_client.py` | Headless test/benchmark client |

## Documentation

- [System Architecture](docs/SYSTEM_ARCHITECTURE.md) — Detailed system design and how everything works
- [Letta Agent Setup](docs/configuration/letta-agent-setup.md) — Agent configuration, memory blocks, troubleshooting
- [Phase 1 Quickstart](PHASE1_QUICKSTART.md) — Voice-only setup
- [Phase 2 Quickstart](PHASE2_QUICKSTART.md) — Letta integration setup
