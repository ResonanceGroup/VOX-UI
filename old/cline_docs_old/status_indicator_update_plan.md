# Status Indicator Design Update Plan

**Date:** 2025-04-10

**Objective:** Update `cline_docs/status_indicator_design.md` to align with `cline_docs/ui_protocol_alignment.md` by adding missing states and clarifying existing ones.

## Finalized Plan

The following changes will be made to `cline_docs/status_indicator_design.md`:

1.  **Add `Listening` State Definition:**
    *   **Trigger:** WebSocket `status_update` with `status: 'listening'`.
    *   **Orb Behavior:** Visually identical to the `Idle` state (no unique animation/effect).
    *   **Status Bar:** Visually identical to the `Idle` state (e.g., `[●] Ready to assist...`).
    *   **CSS Class:** Define `.state-listening` but apply no unique styles compared to `.state-idle`.
    *   **Rationale:** The agent is considered always listening when idle and not muted, so no distinct visual change is needed. The state is handled internally.

2.  **Add `Speaking` State Definition:**
    *   **Trigger:** WebSocket `status_update` with `status: 'speaking'`.
    *   **Orb Behavior:** Gentle, rhythmic outward pulse or consistent brighter glow/saturation (potentially with a slight green tint).
    *   **Status Bar:** `[🔊] Speaking...` (Icon: Speaker emoji or similar SVG).
    *   **CSS Class:** `.state-speaking`.

3.  **Add `Error` State Definition (Persistent):**
    *   **Trigger:** WebSocket `status_update` with `status: 'error'`.
    *   **Orb Behavior:** Static (no animation), with a noticeable red/orange glow or a desaturated look with a static red border/ring (distinct from `Disconnected` grayscale).
    *   **Status Bar:** `[⚠️] Error` (Icon/text in red/error color). Text could potentially include details if provided by the backend in the future.
    *   **CSS Class:** `.state-error`.

4.  **Update `Processing` State Definition:**
    *   **Clarification:** Modify the description in the "Secondary Feedback (Enhanced Status Bar)" section. Explicitly state that the status bar text should use the `context.label` from the WebSocket `status_update` message (e.g., "Transcribing...", "Generating Response...", "Thinking...") when provided.
    *   **Fallback:** If no `context.label` is available, the status bar should display the generic animated "Processing....".

5.  **Update Document Structure:**
    *   Add new subsections/items for `Listening`, `Speaking`, and `Error` under the "Primary Feedback" and "Secondary Feedback" sections.
    *   Add `.state-listening`, `.state-speaking`, `.state-error` to the list of state classes in the "CSS Styling & Animations" section.
    *   Briefly mention handling these new states in the `updateUIState` description under "JavaScript Logic".
    *   Update the Mermaid diagram to reflect these changes.

## Updated Data Flow Diagram

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