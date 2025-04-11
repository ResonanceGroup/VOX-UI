# Status Indicator Design Implementation Plan

**Date:** 2025-04-10

**Objective:** Apply the updates defined in `cline_docs/status_indicator_update_plan.md` to the existing design document `cline_docs/status_indicator_design.md`.

**Target File:** `cline_docs/status_indicator_design.md`

## Implementation Steps

1.  **Integrate New States into "Primary Feedback (Orb Animations)":**
    *   Add a new subsection for `Listening` (after `Idle` or `Transitioning`, maintaining logical flow) detailing its visual identity with `Idle`.
    *   Add a new subsection for `Speaking`, describing its orb behavior (pulse/glow).
    *   Add a new subsection for `Error`, describing its static, colored orb behavior.

2.  **Integrate New States into "Secondary Feedback (Enhanced Status Bar)":**
    *   Add `Listening` to the list, noting its visual identity with `Idle` (`[●] Ready to assist...`).
    *   Add `Speaking` with its icon and text (`[🔊] Speaking...`).
    *   Add `Error` with its icon and text (`[⚠️] Error`).

3.  **Update "Processing" State in "Secondary Feedback":**
    *   Modify the description for `Processing` to explicitly mention using `context.label` from the WebSocket message for the status text when available.
    *   Specify the fallback behavior (animated "Processing....") when `context.label` is not provided.

4.  **Update "CSS Styling & Animations":**
    *   Add `.state-listening`, `.state-speaking`, and `.state-error` to the list of state classes (currently around line 88).

5.  **Update "JavaScript Logic":**
    *   Add a brief note under the `updateUIState(newState)` function description (currently around line 104) mentioning that it needs to handle the new `listening`, `speaking`, and `error` states.

6.  **Replace Data Flow Diagram:**
    *   Remove the existing Mermaid diagram (currently lines 108-122).
    *   Insert the updated Mermaid diagram provided in `status_indicator_update_plan.md`:

        ```mermaid
        graph TD
            subgraph Event Sources
                WS[WebSocket `status_update`]
                MCP[MCP Message]
                BTN[Button Click (e.g., Mute)]
                CONN[Connection Status]
                TMR[Timer/Internal]
            end

            subgraph UI Update Logic
                B{JS Event Listener}
                C[updateUIState(newState)]
                D[HTML Elements (Orb, Status Bar)]
                E[CSS State Classes]
                F[CSS Animations & Styles]
                G(Updated Icon & Text)
                H(Orb Effects)
            end

            WS -- status: idle, listening, processing, speaking, error --> B;
            MCP -- tool execution --> B;
            BTN -- mute toggle --> B;
            CONN -- connected/disconnected --> B;
            TMR -- notification timeout --> B;

            B -- Triggers --> C;

            C -- Updates --> D;
            C -- Adds/Removes --> E;

            E -- Activates --> F;

            D -- Displays --> G;
            F -- Displays --> H;

            classDef state fill:#f9f,stroke:#333,stroke-width:2px;
            class E state;
            classDef trigger fill:#ccf,stroke:#333,stroke-width:1px;
            class WS,MCP,BTN,CONN,TMR trigger;