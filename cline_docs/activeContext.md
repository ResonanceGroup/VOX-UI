# Project Pivot (April 2025)

## Recent Changes
- **Project Direction Shift:** The project's focus has pivoted from building a standalone voice assistant backend (RunPod/UltraVox/Kokoro) to creating a voice UI (VOX UI) that acts as a frontend controller for the Roo Code VSCode extension via the Model Context Protocol (MCP).
- **Previous Backend Work Deferred:** All work related to the RunPod infrastructure, UltraVox, and Kokoro TTS integration is now deferred indefinitely.
- **Phase 1 (MCP Page HTML/CSS) Complete:** The initial HTML structure and CSS styling for the MCP Server settings page (`src/mcp_settings.html`) are complete, including sample data. JS logic and minor CSS tweaks deferred.
- **UI Finalization - Phases A, B, C Complete:** Settings page overhaul, MCP icon integration, and theme persistence bug fixed.
- **Backend Plan - Phase 1 Complete:** Research & Definition for backend architecture, interfaces, and protocols completed and documented.
- **Backend Plan - Phase 2 Complete:** Core backend implementation in Node.js finished, including modularized Settings API, WebSocket handler, Agent Lifecycle Management, Message Routing, and MCP Client logic.

## Current Focus: Phase 3 - Frontend Implementation

Following the plan outlined in `cline_docs/backend_implementation_plan.md`:

### UI Finalization (Phases A, B, C) (Complete)
- **Status:** Settings page updated, MCP icon integrated, theme bug fixed.

### Backend Plan - Phase 1: Research & Definition (Complete)
- **Status:** Interfaces, protocols, and settings structures defined.

### Backend Plan - Phase 2: Core Backend Implementation (Complete)
- **Status:** Node.js server logic implemented (Settings API, WS Handler, Agent Manager, Message Routing, MCP Client).

### Backend Plan - Phase 3: Frontend Implementation (In Progress)
- **Goal:** Implement the frontend JavaScript logic to communicate with the backend via WebSockets and manage UI state.
- **Tasks:**
    1. Implement WebSocket Client connection logic in `src/app.js`. (Next Step)
    2. Implement MCP Settings Page Logic (`src/mcp_settings.html` JS).
    3. Implement UI State Updates based on `status_indicator_design.md` and WebSocket messages.
    4. Implement Real-time Audio Handling (capture, streaming to backend, playback from backend).
    5. Implement Settings Page save/load logic using WebSocket or updated API.

### Backend Plan - Phase 4: Voice Agent Module Implementation (Deferred)
- Implement specific `IVoiceAgent` modules (UltraVox, Phi4, Qwen).

### Backend Plan - Phase 5: Integration & Testing (Deferred)
- End-to-end testing.

### Original Plan - Phase 2: Enhance Visualizations (Deferred)
- Further UI enhancements deferred.

### Original Plan - Phase 4: MCP Server for Roo Code (Deferred)
- Building the dedicated Roo Code MCP server deferred.


# Next Steps

1.  **Begin Backend Plan - Phase 3:** Implement the frontend WebSocket client connection logic in `src/app.js`.
