# Project Pivot (April 2025)

## Recent Changes
- **Project Direction Shift:** The project's focus has pivoted from building a standalone voice assistant backend (RunPod/UltraVox/Kokoro) to creating a voice UI (VOX UI) that acts as a frontend controller for the Roo Code VSCode extension via the Model Context Protocol (MCP).
- **Previous Backend Work Deferred:** All work related to the RunPod infrastructure, UltraVox, and Kokoro TTS integration is now deferred indefinitely.
- **Phase 1 (MCP Page HTML/CSS) Complete:** The initial HTML structure and CSS styling for the MCP Server settings page (`src/mcp_servers.html`) are complete, including sample data. JS logic and minor CSS tweaks deferred.
- **UI Finalization - Phases A, B, C Complete:** Settings page overhaul, MCP icon integration, and theme persistence bug fixed.
- **Backend Plan - Phase 1 Complete:** Research & Definition for backend architecture, interfaces, and protocols completed and documented.
- **Backend Plan - Phase 2 Complete:** Core backend implementation in Node.js finished, including modularized Settings API, WebSocket handler, Agent Lifecycle Management, Message Routing, and MCP Client logic.
- **Backend Plan - Phase 3 Complete:** Frontend implementation finished (WebSocket client, MCP page logic, UI state updates, Audio handling, Settings save/load via WebSocket).
- **Backend Plan - Phase 4 (Tasks 1 & 2):** Implemented `EchoAgent.js` and `UltraVoxKokoroAgent.js` (networked version). Created `gpu_server_setup.sh`.
- **Code Review Fixes:** Addressed issues found in code review (MCP client cleanup bug, JS filename inconsistency (`mcp_servers.js`), `app.js` race condition).

## Current Focus: Phase 5 - Integration & Testing

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
- **Goal:** Implement specific `IVoiceAgent` modules.
- **Completed Tasks:**
    1. Implemented `EchoAgent.js`.
    2. Implemented `UltraVoxKokoroAgent.js` (networked).
    3. Created `gpu_server_setup.sh`.
- **Remaining Tasks:**
    1. Implement other desired agent modules (Phi4, Qwen). (Deferred)

### Backend Plan - Phase 5: Integration & Testing (In Progress)
- **Goal:** Ensure all components work together. (Next Step)
- **Tasks:**
    1. Set up cloud GPU environment using `gpu_server_setup.sh`.
    2. Configure VOX UI settings (`settings.json`, `mcp_config.json`) to point to the GPU services and select the `UltraVoxKokoroAgent`.
    3. Perform end-to-end testing of voice input/output flow.
    4. Debug any issues found during testing.

### Original Plan - Phase 2: Enhance Visualizations (Deferred)
- Further UI enhancements deferred.

### Original Plan - Phase 4: MCP Server for Roo Code (Deferred)
- Building the dedicated Roo Code MCP server deferred.


# Next Steps

1.  **Begin Backend Plan - Phase 5:** Set up the cloud GPU environment and configure VOX UI for end-to-end testing with the `UltraVoxKokoroAgent`.
