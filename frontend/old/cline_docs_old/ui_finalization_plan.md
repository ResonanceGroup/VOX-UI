# VOX UI Finalization Plan (April 2025)

**Overall Goal:** Integrate the MCP settings page, overhaul the main settings page with new sections/controls, and fix the theme persistence bug before proceeding to backend work.

## Phase A: Settings Page Overhaul

1.  **Restructure `settings.html`:**
    *   **Action:** Modify `settings.html` to create the new sections ("Voice Agent", "MCP", "n8n Integration", "General UI"). Add the specified input controls/placeholders to the "Voice Agent" and "MCP" sections. Keep the "n8n" section. Move "Appearance" (Theme) into "General UI". Remove the old "UltraVOX" section.
    *   **Details:**
        *   *Voice Agent:* Server URL, System Prompt, Model, Voice, Language inputs.
        *   *MCP:* MCP config file path input.
    *   **Tool(s):** `read_file`, `apply_diff`/`write_to_file`.

## Phase B: MCP Page Integration

2.  **Retrieve MCP Icon SVG:**
    *   **Action:** Search within `C:\Users\Jason\source\repos\Roo-Code` for the "stacked bars" SVG icon.
    *   **Tool(s):** `search_files`, `read_file`.
3.  **Update MCP Page Sidebar Icon (`mcp_settings.html`):**
    *   **Action:** Replace the placeholder icon in the `mcp_settings.html` sidebar link with the SVG code found in the previous step.
    *   **Tool(s):** `read_file`, `apply_diff`.

## Phase C: Theme Persistence Bug Fix

4.  **Diagnose & Fix Theme Bug:**
    *   **Action:** Investigate and resolve the issue where the saved theme doesn't apply globally.
    *   **Investigation:** Analyze `app.js` (`Settings` class, `DOMContentLoaded`) and `server.js` (`/api/settings`).
    *   **Implementation:** Apply fix (likely in `app.js`).
    *   **Tool(s):** `read_file`, `apply_diff`/`write_to_file`.

## Implementation Flow

```mermaid
graph TD
    A[Start UI Finalization] --> B(Phase A: Overhaul settings.html);
    B --> C(Phase B: Find MCP Icon);
    C --> D(Update mcp_settings.html Icon);
    D --> E(Phase C: Diagnose Theme Bug);
    E --> F(Implement Theme Fix);
    F --> G{Review & Approve};