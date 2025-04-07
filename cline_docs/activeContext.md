# Project Pivot (April 2025)

## Recent Changes
- **Project Direction Shift:** The project's focus has pivoted from building a standalone voice assistant backend (RunPod/UltraVox/Kokoro) to creating a voice UI (VOX UI) that acts as a frontend controller for the Roo Code VSCode extension via the Model Context Protocol (MCP).
- **Previous Backend Work Deferred:** All work related to the RunPod infrastructure, UltraVox, and Kokoro TTS integration is now deferred indefinitely.
- **Phase 1 (MCP Page HTML/CSS) Complete:** The initial HTML structure and CSS styling for the MCP Server settings page (`src/mcp_settings.html`) are complete, including sample data. JS logic and minor CSS tweaks deferred.
- **UI Finalization - Phase A Complete:** Settings Page Overhaul (`src/settings.html`) completed with new sections (Voice Agent, MCP, n8n, General UI) and controls.
- **UI Finalization - Phase B Complete:** MCP Icon (`server` Codicon) identified and integrated into sidebars of `index.html`, `settings.html`, and `mcp_settings.html`.

## Current Focus: UI Finalization Plan

Following the plan outlined in `cline_docs/ui_finalization_plan.md`:

### Phase A: Settings Page Overhaul (Complete)
- **Status:** `src/settings.html` restructured with new sections and controls.

### Phase B: MCP Page Integration (Complete)
- **Status:** Sidebar links updated across pages with the correct Codicon.

### Phase C: Theme Persistence Bug Fix (In Progress)
- **Goal:** Diagnose and fix the global theme application issue. (Next Step)

### Phase 2 (Original Plan): Enhance Visualizations (Deferred)
- This phase (including status indicators) will be addressed after the UI Finalization Plan is complete.

### Phase 3 (Original Plan): Backend Implementation (Deferred)
- ... (Keep as is)

### Phase 4 (Original Plan): MCP Server for Roo Code (Deferred)
- ... (Keep as is)

# Next Steps

1.  **Begin Phase C:** Diagnose the theme persistence bug where the selected theme (light/dark) doesn't apply globally after saving settings.
