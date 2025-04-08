# VOX UI Backend Architecture &amp; Implementation Plan

**Version:** 1.0
**Date:** 2025-04-08

**Overall Goal:** Build a robust Node.js backend for VOX UI that manages WebSocket connections with the frontend, interacts with swappable Voice Agents via a common interface, and leverages MCP servers for enhanced capabilities.

**Core Architecture:**
-   **Frontend:** HTML/CSS/JS (`src/`) served by Node.js. Communicates via WebSocket.
-   **Backend:** Node.js/Express (`server.js`) acting as:
    -   WebSocket Gateway for Frontend.
    -   Voice Agent Manager (using `IVoiceAgent` abstraction).
    -   MCP Client (connecting to servers defined in `mcp_config.json`).
-   **Voice Agents:** Pluggable modules (UltraVox+Kokoro, Phi4, Qwen, etc.) implementing `IVoiceAgent`.
-   **MCP Servers:** External servers (including future Roo Code server) providing tools/resources accessible via the backend.

**Diagram:**

```mermaid
sequenceDiagram
    participant FE as Frontend (Browser)
    participant BE as Backend (Node.js)
    participant VA as Active Voice Agent (e.g., UltraVox)
    participant MCP as External MCP Server(s)
    participant RC as Roo Code MCP (Future)

    Note over FE, BE: Initial Setup &amp; Session Start
    FE->>BE: Establish WebSocket
    BE-->>FE: WebSocket Opened
    FE->>BE: start_session (config: use UltraVox)
    BE->>VA: Initialize UltraVox Agent
    VA-->>BE: Agent Ready
    BE->>MCP: Connect to configured MCP Servers (reads mcp_config.json)
    MCP-->>BE: MCP Connections Ready
    BE-->>FE: session_started (agent: UltraVox)

    Note over FE, BE, VA: User Sends Voice Input
    FE->>BE: audio_chunk (via WebSocket)
    BE->>VA: processAudioStream(chunk)
    Note right of VA: Agent processes audio (STT)
    VA->>BE: Request: Use 'brave_search' MCP tool (query: "weather")
    BE->>MCP: use_mcp_tool(server: 'brave', tool: 'brave_web_search', args: {query: "weather"})
    MCP-->>BE: MCP Tool Result (weather info)
    BE->>VA: provideToolResult(weather info)
    Note right of VA: Agent incorporates result, generates response (TTS)
    VA->>BE: audio_response_chunk
    BE-->>FE: audio_chunk (via WebSocket)
    FE->>FE: Play TTS Audio

    Note over FE, BE, RC: User sends command for Roo Code (via Text)
    FE->>BE: text_input (command: "Roo: read file main.py")
    BE->>VA: processText("Roo: read file main.py")
    Note right of VA: Agent identifies Roo Code target
    VA->>BE: Request: Use 'roo_code' MCP tool (tool: 'read_file', args: {path: 'main.py'})
    BE->>RC: use_mcp_tool(server: 'roo_code_server', tool: 'read_file', args: {path: 'main.py'})
    RC-->>BE: MCP Tool Result (file content)
    BE->>VA: provideToolResult(file content)
    VA->>BE: text_response ("Okay, here is main.py: ...")
    BE-->>FE: text_response (via WebSocket)
```

---

## Phased Implementation Plan

### Phase 1: Research &amp; Definition (Laying the Groundwork)

*   **Objective:** Gather necessary information and define the core interfaces and data structures before implementation begins.

*   **Task 1.1: Research MCP Protocol**
    *   **Goal:** Understand MCP client best practices (connection, tool use, resource access, status, errors) relevant to this project.
    *   **Instructions for Delegation (Researcher Mode):**
        ```
        Research the Model Context Protocol (MCP). Focus on the client-side perspective. Find official documentation or reliable resources explaining:
        1. How an MCP client connects to an MCP server (including handling configuration files).
        2. The standard way to invoke tools (`use_mcp_tool`) and handle responses/errors.
        3. The standard way to access resources (`access_mcp_resource`).
        4. How status updates might be pushed from server to client (if defined in the protocol).
        5. Common error handling patterns.
        Summarize findings in a markdown document, highlighting aspects relevant for a Node.js client facilitating tool use for a voice agent.
        ```
    *   **Deliverable:** Markdown document summarizing MCP client implementation details.

*   **Task 1.2: Research Voice Agent Implementations**
    *   **Goal:** Document technical interaction details for each target voice agent.
    *   **Instructions for Delegation (Researcher Mode - potentially 3 separate tasks):**
        *   **Task 1.2.1 (UltraVox+Kokoro):**
            ```
            Research how to interact with UltraVox (for STT) and Kokoro TTS from a Node.js application. Identify:
            1. APIs, SDKs, or libraries available.
            2. Connection methods (HTTP, WebSockets, local process?).
            3. Data formats for sending audio (for STT) and text (for TTS).
            4. Data formats for receiving text (from STT) and audio (from TTS).
            5. Methods for real-time streaming input/output.
            6. Configuration options required.
            Summarize findings in a markdown document suitable for guiding the implementation of a Node.js module. Include code snippets if available.
            ```
        *   **Task 1.2.2 (Phi-4 Multimodal):**
            ```
            Research how to interact with the Phi-4 Multimodal model from a Node.js application, focusing on voice/text interaction. Identify:
            1. Official APIs, SDKs, or libraries.
            2. Authentication methods.
            3. Data formats for sending audio/text prompts.
            4. Data formats for receiving text/audio responses.
            5. Methods for real-time streaming input/output if supported.
            6. Key configuration parameters.
            Summarize findings in a markdown document suitable for guiding the implementation of a Node.js module. Include code snippets if available.
            ```
        *   **Task 1.2.3 (Qwen2.5-Omni-7B):**
            ```
            Research how to interact with the Qwen2.5-Omni-7B model from a Node.js application, focusing on voice/text interaction. Identify:
            1. Available APIs, SDKs, or libraries (e.g., via Hugging Face, specific providers).
            2. Authentication/connection methods.
            3. Data formats for sending audio/text prompts.
            4. Data formats for receiving text/audio responses.
            5. Methods for real-time streaming input/output if supported.
            6. Configuration requirements (model endpoints, parameters).
            Summarize findings in a markdown document suitable for guiding the implementation of a Node.js module. Include code snippets if available.
            ```
    *   **Deliverable:** Separate markdown documents for each voice agent detailing interaction methods.

*   **Task 1.3: Define `IVoiceAgent` Interface**
    *   **Goal:** Create a stable TypeScript/JavaScript interface contract for all voice agent modules.
    *   **Instructions for Delegation (Code Mode):**
        ```
        Based on the research from Tasks 1.1 and 1.2 (results will be provided), and considering the need for real-time audio streaming and MCP tool integration, define a detailed TypeScript interface named `IVoiceAgent`. It should include:
        - Constructor signature (accepting agent-specific config).
        - Methods for initialization and shutdown.
        - Methods to process incoming text messages and audio chunks/streams.
        - An event emitter mechanism (`on`, `off`) to signal:
            - `status_update` (e.g., 'listening', 'processing', 'speaking')
            - `text_response`
            - `audio_response_chunk`
            - `request_mcp_tool` (payload should include requestId, serverName, toolName, arguments)
            - `error`
        - A method to receive results from executed MCP tools (`provideMcpToolResult(requestId, result)`).
        Document the interface with TSDoc comments explaining each method and event. Place the definition in a suitable new file (e.g., `src/interfaces/IVoiceAgent.ts`).
        ```
    *   **Deliverable:** `src/interfaces/IVoiceAgent.ts` file containing the interface definition.

*   **Task 1.4: Define WebSocket Communication Protocol**
    *   **Goal:** Specify message types and structures for Frontend <-> Backend communication.
    *   **Instructions for Delegation (Architect/Code Mode):**
        ```
        Define the JSON message structures for the WebSocket communication between the VOX UI frontend and the Node.js backend. Cover the following interactions:
        - Session initiation (FE -> BE): Specify agent type, config.
        - Session confirmation (BE -> FE): Confirm agent started.
        - Text input (FE -> BE).
        - Audio input streaming (FE -> BE): `audio_chunk`, `end_audio_stream`.
        - Text response (BE -> FE).
        - Audio response streaming (BE -> FE): `audio_chunk`.
        - Agent status updates (BE -> FE): Align with states needed for UI (`status_indicator_design.md`).
        - MCP Tool results (BE -> FE): How results are relayed if needed directly by FE (or confirm if only agent needs them).
        - Error reporting (BE -> FE).
        - Settings updates (FE -> BE).
        Document this protocol clearly in a markdown file (e.g., `cline_docs/websocket_protocol.md`).
        ```
    *   **Deliverable:** `cline_docs/websocket_protocol.md` detailing the message formats.

*   **Task 1.5: Define `settings.json` Structure**
    *   **Goal:** Finalize the JSON structure for persistent settings.
    *   **Instructions for Delegation (Architect/Code Mode):**
        ```
        Define the definitive JSON structure for the `settings.json` file. It must include:
        - `theme`: string ('light', 'dark', 'system')
        - `mcp_config_path`: string (absolute or relative path)
        - `active_voice_agent`: string (e.g., 'ultravox', 'phi4', 'qwen')
        - `voice_agent_config`: object (nested object where keys are agent identifiers like 'ultravox', 'phi4', etc., and values are agent-specific configuration objects).
        Provide an example `settings.json` file content based on this structure. Update the existing `settings.json` file with this new structure and sensible defaults (leave agent configs empty initially).
        ```
    *   **Deliverable:** Updated `settings.json` file.

*   **Task 1.6: Define UI State Mapping &amp; Protocol Alignment**
    *   **Goal:** Validate `status_indicator_design.md` against agent states and ensure the WebSocket protocol enables triggering these UI states.
    *   **Instructions for Delegation (Architect/Code Mode):**
        ```
        Review `cline_docs/status_indicator_design.md` and the proposed WebSocket protocol definition (from Task 1.4).
        1. Verify that the agent status updates defined in the WebSocket protocol directly map to the UI states described in the design doc (Idle, Executing Tools, Processing, Disconnected, etc.).
        2. Identify any gaps or mismatches.
        3. Update either the WebSocket protocol definition or propose minor adjustments to the UI state design doc if necessary for alignment.
        Document findings or confirmations in a markdown file or as comments in the relevant documents.
        ```
    *   **Deliverable:** Confirmation of alignment or documented adjustments needed.

### Phase 2: Core Backend Implementation

*   **Objective:** Implement the central Node.js server logic.
*   **(Tasks 2.1-2.5):** Implement WebSocket Server, MCP Client, Agent Lifecycle, Settings API, MCP Facilitation based on Phase 1 definitions. *(Delegate to Code Mode)*

### Phase 3: Frontend Implementation

*   **Objective:** Implement the frontend logic.
*   **(Tasks 3.1-3.4):** Implement WebSocket Client, Settings Page, UI State Updates (based on `status_indicator_design.md`), Real-time Audio Handling. *(Delegate to Code Mode)*

### Phase 4: Voice Agent Module Implementation

*   **Objective:** Create the specific agent modules.
*   **(Tasks 4.1-4.3):** Implement `UltraVoxKokoroAgent`, `Phi4Agent`, `QwenAgent` modules adhering to `IVoiceAgent`. *(Delegate to Code Mode, potentially one per agent)*

### Phase 5: Integration &amp; Testing

*   **Objective:** Ensure all components work together.
*   **(Tasks 5.1-5.4):** End-to-end testing, agent switching tests, settings tests, MCP integration tests. *(Delegate to Code/Debug Mode)*