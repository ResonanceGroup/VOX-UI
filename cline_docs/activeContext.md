# Project Pivot (April 2025)

## Recent Changes
- **Project Direction Shift:** The project's focus has pivoted from building a standalone voice assistant backend (RunPod/UltraVox/Kokoro) to creating a voice UI (VOX UI) that acts as a frontend controller for the Roo Code VSCode extension via the Model Context Protocol (MCP).
- **Previous Backend Work Deferred:** All work related to the RunPod infrastructure, UltraVox, and Kokoro TTS integration is now deferred indefinitely.

## Current Focus: Phased UI Development for Roo Code Integration

The development will proceed in the following phases:

### Phase 1: MCP Server Page UI (In Progress)
- **Goal:** Implement an MCP Server settings page in the VOX UI (target file: `src/mcp_settings.html`).
- **UI Design:** Visually replicate the Roo Code MCP settings screenshots (header, intro text, enable checkboxes, accordion list for servers, expanded view with Tools/Resources tabs, parameters, allow checkbox, network timeout).
- **Styling:** Use existing VOX UI styles.
- **Simplifications:** No 'global' tags needed. No 'Global/Project MCP' edit buttons.
- **Editing:** Include a single 'Edit MCP Servers' button at the bottom. Functionality (opening JSON config) is deferred. Adding new servers via UI is also deferred.
- **JS Logic:** Defer JavaScript logic (reading JSON, refresh on change, accordion interaction) for a later phase. Focus is on HTML structure and CSS styling first.

### Phase 2: Enhance Visualizations
- Develop dynamic status indicators for the voice UI (e.g., MCP connection status, Roo Code status).
- Define common UI elements for consistency.
- Update the current UI prototype to incorporate enhanced UI elements.

### Phase 3: Backend Implementation
- Design a robust backend architecture focused on supporting the MCP-centric UI and communication with Roo Code (details TBD).
- Implement backend code needed for UI features (e.g., potentially handling MCP config file interactions, relaying commands if necessary).

### Phase 4: MCP Server for Roo Code
- Build the specific MCP server required to interact with Roo Code's WebSocket API.

# Next Steps

1.  **Create the basic HTML structure for the new MCP Settings page (`src/mcp_settings.html`) based on the Roo Code reference UI.**
