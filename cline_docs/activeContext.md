# Project Pivot (April 2025)

## Recent Changes

- **Project Direction Shift:** The project's focus has pivoted from building a standalone voice assistant backend (RunPod/UltraVox/Kokoro) to creating a voice UI (VOX UI) that acts as a frontend controller for the Roo Code VSCode extension via the Model Context Protocol (MCP).
- **Previous Backend Work Deferred:** All work related to the RunPod infrastructure, UltraVox, and Kokoro TTS integration is now deferred indefinitely.
- **Phase 1 (MCP Page HTML/CSS) Complete:** The initial HTML structure and CSS styling for the MCP Server settings page (`src/mcp_servers.html`) are complete, including sample data. JS logic and minor CSS tweaks deferred.
- **UI Finalization - Phases A, B, C Complete:** Settings page overhaul, MCP icon integration, and theme persistence bug fixed.
- **Backend Plan - Phase 1 Complete:** Research & Definition for backend architecture, interfaces, and protocols completed and documented.
- **Backend Plan - Phase 2 Complete:** Core backend implementation in Node.js finished, including modularized Settings API, WebSocket handler, Agent Lifecycle Management, Message Routing, and MCP Client logic.
- **Backend Plan - Phase 3 Complete:** Frontend implementation finished (WebSocket client, MCP page logic, UI state updates, Audio handling, Settings save/load via WebSocket).
- **Backend Plan - Phase 4 (Task 1):** Implemented basic `EchoAgent.js` for testing.
- **Code Review Fixes:** Addressed issues found in code review (MCP client cleanup bug, JS filename inconsistency (`mcp_servers.js`), `app.js` race condition).

## Current Focus: Phase 4 - Voice Agent Module Implementation

Following the plan outlined in `cline_docs/backend_implementation_plan.md`:

### UI Finalization (Phases A, B, C) (Complete)

- **Status:** Settings page updated, MCP icon integrated, theme bug fixed.

### Backend Plan - Phase 1: Research & Definition (Complete)

- **Status:** Interfaces, protocols, and settings structures defined.

### Backend Plan - Phase 2: Core Backend Implementation (Complete)

- **Status:** Node.js server logic implemented.

### Backend Plan - Phase 3: Frontend Implementation (Complete)

- **Status:** Frontend JavaScript logic implemented.

### Backend Plan - Phase 4: Voice Agent Module Implementation (In Progress)

- **Goal:** Implement specific `IVoiceAgent` modules (UltraVox, Phi4, Qwen).
- **Completed Tasks:**
    1. Implemented `EchoAgent.js` for testing.
    2. Fixed bugs identified in code review.
- **Remaining Tasks:**
    1. Implement the first *real* Voice Agent module (UltraVoxKokoroAgent recommended). (Next Step)
    2. Implement other desired agent modules (Phi4, Qwen).

### Backend Plan - Phase 5: Integration & Testing (Deferred)

- End-to-end testing.

### Original Plan - Phase 2: Enhance Visualizations (Deferred)

- Further UI enhancements deferred.

### Original Plan - Phase 4: MCP Server for Roo Code (Deferred)

- Building the dedicated Roo Code MCP server deferred.

# Next Steps

1. **Continue Backend Plan - Phase 4:** Implement the first real Voice Agent module (UltraVoxKokoroAgent recommended) adhering to the `IVoiceAgent` interface.
