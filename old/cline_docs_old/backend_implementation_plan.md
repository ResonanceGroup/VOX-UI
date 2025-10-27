# VOX UI Backend Architecture & Implementation Plan

**Version:** 1.1
**Date:** 2025-04-10

**Overall Goal:** Build a robust, modular Node.js backend for VOX UI that manages WebSocket connections with the frontend, interacts with swappable Voice Agents via a common interface, and leverages MCP servers for enhanced capabilities.

**Guiding Principle:** Favor breaking functionality into smaller, separate files/modules (e.g., WebSocket handling, Agent management, MCP client logic, Settings API) rather than putting everything in `server.js`.

---

## Phase 1: Research & Definition (Complete)

*   **(Tasks 1.1-1.6):** Research conducted, interfaces (`IVoiceAgent.ts`), protocols (`websocket_protocol.md`), and settings structures (`settings.json`) defined. Research summaries available in `cline_docs/research/`.

---

## Phase 2: Core Backend Implementation (Next)

**Objective:** Implement the central Node.js server logic based on Phase 1 definitions, emphasizing modularity.

1.  **Settings API Enhancement:**
    *   **Action:** Update the `/api/settings` GET and POST endpoints in `server.js` (or a dedicated `settingsApi.js` module).
    *   **Details:** Modify endpoints to read/write the new `settings.json` structure (including `active_voice_agent`, nested `voice_agent_config`).
2.  **WebSocket Server Setup:**
    *   **Action:** Integrate `ws` library with Express in `server.js` (or a dedicated `webSocketServer.js` module).
    *   **Details:** Handle connections, disconnections, basic message listening, and errors.
3.  **Agent Lifecycle Management:**
    *   **Action:** Implement logic (e.g., in an `agentManager.js` module) to manage the active voice agent based on WebSocket messages.
    *   **Details:** Handle `init_session` (load module, instantiate, call `initialize`), handle `close`/`terminate_session` (call `shutdown`).
4.  **Message Routing & Agent Interaction:**
    *   **Action:** Implement logic (likely within the WebSocket handler or `agentManager.js`) to route messages between FE and the active agent.
    *   **Details:** Parse incoming messages (`text_input`, `audio_chunk`, `end_audio_stream`) and call corresponding agent methods. Listen for agent events (`status_update`, `text_response`, `audio_response_chunk`, `error`, `request_mcp_tool`) and forward formatted messages to the FE via WebSocket.
5.  **MCP Client Implementation:**
    *   **Action:** Implement core MCP client logic (e.g., in an `mcpClient.js` module).
    *   **Details:**
        *   Load/parse MCP config file (path from `settings.json`). Define config structure (array of server objects: name, command/url, enabled).
        *   Manage connections to enabled servers (child processes/HTTP/WS clients). Handle errors/retries, capability negotiation.
        *   Implement `tools/list`, `resources/list` discovery and store results.
        *   Handle `request_mcp_tool` event from agent: find server, validate, send `tools/call`, handle response/errors, call `agent.provideMcpToolResult`.
        *   Implement basic `resources/read`.
        *   Handle incoming notifications (`notifications/message`, etc.) and log/forward.
        *   Implement robust JSON-RPC error handling.

---

## Phase 3: Frontend Implementation

**Objective:** Implement the frontend logic to interact with the backend.

*   **(Tasks 3.1-3.4 - Original):** Implement WebSocket Client, UI State Updates (based on `status_indicator_design.md`), Real-time Audio Handling.
*   **Task 3.5: MCP Settings Page Logic (`mcp_settings.html`):**
    *   **Action:** Implement JS logic for the MCP settings page.
    *   **Details:** Fetch server list (`/api/mcp/servers`), populate list, implement accordion, enable/disable toggle, refresh button. Implement "Edit MCP Servers" button (trigger opening config file). Fetch/display discovered tools/resources. *(Delete functionality removed)*.
*   **Task 3.6: Backend API for MCP UI:**
    *   **Action:** Create API endpoints in `server.js` (or `mcpApi.js`).
    *   **Details:**
        *   `/api/mcp/servers` (GET): Return server list from config + status/discovery info.
        *   `/api/mcp/servers/:serverName/toggle` (POST): Enable/disable server.
        *   `/api/mcp/servers/:serverName/refresh` (POST): Trigger rediscovery.
        *   `/api/mcp/config/open` (POST): Trigger opening config file. *(DELETE endpoint removed)*.

---

## Phase 4: Voice Agent Module Implementation

**Objective:** Create the specific agent modules.
*   **(Tasks 4.1-4.3):** Implement `UltraVoxKokoroAgent`, `Phi4Agent`, `QwenAgent` modules adhering to `IVoiceAgent`.

---

## Phase 5: Integration & Testing

**Objective:** Ensure all components work together.
*   **(Tasks 5.1-5.4):** End-to-end testing, agent switching tests, settings tests, MCP integration tests.

---

## Conceptual Backend Diagram

```mermaid
graph TD
    subgraph Node.js Backend
        direction LR
        ServerCore[server.js/Express]
        WSHandler[webSocketHandler.js]
        AgentMgr[agentManager.js]
        MCPClient[mcpClient.js]
        SettingsAPI[settingsApi.js]
        MCPApi[mcpApi.js]
        Store[settings.json]
        MCPConf[mcp_config.json]

        ServerCore --> WSHandler;
        ServerCore --> SettingsAPI;
        ServerCore --> MCPApi;
        WSHandler <--> AgentMgr;
        AgentMgr -- Instantiates --> Agent(Active IVoiceAgent);
        Agent -- Emits Events --> AgentMgr;
        AgentMgr -- Calls Methods --> Agent;
        AgentMgr --> MCPClient;
        MCPClient -- Reads --> MCPConf;
        MCPClient -- Calls --> Agent(provideMcpToolResult);
        SettingsAPI -- Reads/Writes --> Store;
        MCPApi -- Uses --> MCPClient;
        MCPApi -- Reads/Writes --> MCPConf;


    end

    FE[Frontend (app.js)] -- WebSocket --> WSHandler;