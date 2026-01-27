# Status Indicator Design Plan (Hybrid Concept)

This document outlines the agreed-upon design and frontend architecture for status indicators in the VOX UI, combining orb animations with an enhanced status bar below the orb.

## Core Idea
- Use dynamic orb animations for primary, attention-grabbing feedback.
- Use an enhanced status bar (icons + text below orb) for secondary, clearer context.

## Visual States & Feedback

### Primary Feedback (Orb Animations)

1.  **Idle / Listening:**
    *   **Visual:** Standard idle orb appearance (gentle internal flow/gradient animation).
    *   **Rationale:** The agent is considered always listening when idle and not muted, so no distinct visual change is needed between 'idle' and 'listening'. The state is handled internally for logic but visually identical.

2.  **Executing Tools (MCP):**
    *   **Visual:** Soft, pulsing ring of light around the orb, slightly detached.
    *   **Animation:** Gentle, slow pulse (opacity fade in/out).
    *   **Light Mode:** Ring color: `#7E57C2`. Opacity pulse: 30-70%.
    *   **Dark Mode:** Ring color: `#9575CD`. Opacity pulse: 40-80%.
    *   **Transition:** Ring fades in (300ms) on start, fades out on end.

3.  **Receiving Notifications:**
    *   **Visual:** Small, bright particles briefly emanate outwards from the orb.
    *   **Animation:** Quick (500ms) burst of 5-7 particles fading out as they expand.
    *   **Light Mode:** Particle color: `#42A5F5`.
    *   **Dark Mode:** Particle color: `#64B5F6`.
    *   **Transition:** Instantaneous burst.

4.  **Processing Information:**
    *   **Visual:** Orb's internal nebula/gradient swirls/rotates faster than idle.
    *   **Animation:** Internal flow animation speed increases.
    *   **Light/Dark Mode:** Uses existing orb colors.
    *   **Transition:** Speed ramps up (200ms) on start, slows on end.

5.  **Speaking:**
    *   **Visual:** Gentle, rhythmic outward pulse or consistent brighter glow/saturation (potentially with a slight green tint).
    *   **Animation:** Slow, rhythmic pulse or sustained brighter state.
    *   **Transition:** Fades in/out smoothly (200ms).

6.  **Muted:**
    *   **Visual:** No change to the orb itself. Feedback is via the mute button and status bar.

7.  **Disconnected:**
    *   **Visual:** Orb becomes static and desaturated (grayscale). All animations stop.
    *   **Transition:** Applies instantly on disconnect, reverts on reconnect.

8.  **Error (Persistent):**
    *   **Visual:** Static (no animation), with a noticeable red/orange glow or a desaturated look with a static red border/ring (distinct from `Disconnected` grayscale).
    *   **Transition:** Applies instantly on error state trigger.

9.  **Transitioning Between States:**
    *   **Visual:** Quick, soft cross-fade effect on orb brightness/saturation or color wash (except for Muted/Error/Disconnected state changes).
    *   **Animation:** Brief (150ms) fade/flash effect.
    *   **Light Mode:** Brief desaturation or faint white overlay flash.
    *   **Dark Mode:** Brief slight dimming or faint dark grey overlay flash.
    *   **Transition:** Occurs instantly as primary state changes.

### Secondary Feedback (Enhanced Status Bar)

-   **Target Element:** `#status-display`
-   **Enhancements:**
    *   Slightly increase font size (e.g., `0.9rem`).
    *   Adjust opacity/color for better visibility (e.g., Light: `#555`, Dark: `#D0D0D0`).
    *   Add relevant icon *before* the status text within a `<span class="status-icon">`.
    *   Place text within a `<span class="status-text">`.
-   **States & Text/Icons (Examples):**
    *   **Idle / Listening:** `[●] Ready to assist...` (or `[✓]`)
    *   **Executing Tools:** `[⚙️] Executing: [Tool Name]...`
    *   **Receiving Notification:** `[🔔] Notification Received` (Briefly shown)
    *   **Processing:** Uses `context.label` from WebSocket `status_update` if provided (e.g., `[⏳] Transcribing...`, `[⏳] Generating Response...`). If no label, shows animated ellipsis: `Processing....` (no icon, 1-4 dots animate).
    *   **Speaking:** `[🔊] Speaking...`
    *   **Muted:** `[🎙️🚫] Microphone Muted` (Orange/muted grey icon color suggested)
    *   **Disconnected:** `[❌] Disconnected` (Red icon/text color suggested)
    *   **Error:** `[⚠️] Error` (Red icon/text color suggested)
-   **Animation:** Smooth cross-fades for text/icon changes (~150ms), synchronized with orb transitions.

## Frontend Architecture

1.  **HTML Structure (`src/index.html`)**
    *   **Orb Container (`.orb`):** Add child element(s) for effects:
        ```html
        <div class="orb">
            <!-- Existing orb structure -->
            <div class="orb-status-effects">
                <div class="orb-status-ring"></div>
                <!-- Particle container managed by JS -->
            </div>
            <!-- ... -->
        </div>
        ```
    *   **Status Display (`#status-display`):** Structure for icon and text:
        ```html
        <div id="status-display" class="status-display">
            <span class="status-icon">●</span>
            <span class="status-text">Ready to assist...</span>
        </div>
        ```

2.  **CSS Styling & Animations (`src/app.css`, `src/orb.css`)**
    *   **State Classes:** Define `.state-idle`, `.state-listening`, `.state-executing`, `.state-notifying`, `.state-processing`, `.state-speaking`, `.state-muted`, `.state-disconnected`, `.state-error` (applied to `body` or main container).
    *   **Orb Animations:** Define `@keyframes` for ring pulse, particle burst, swirl speed change, speaking pulse/glow, transition flash. Style `.orb-status-ring`. Add rules for `.state-disconnected .orb` (grayscale, stop animations) and `.state-error .orb` (static color/border).
    *   **Status Bar Styling:** Style `#status-display`, `.status-icon`, `.status-text`. Use state classes to set icon content (e.g., `.state-executing .status-icon::before { content: '⚙️'; }`) and colors. Define fade transitions.
    *   **Processing State Animation:** Hide the status icon with `.state-processing .status-icon { display: none; }` when using the ellipsis fallback. Use custom keyframes for dots animation that progresses from 1 to 4 dots and then resets:
        ```css
        @keyframes ellipsis-animation {
            0% { content: '.'; }
            20% { content: '..'; }
            40% { content: '...'; }
            60% { content: '....'; }
            80%, 100% { content: '.'; }
        }
        ```

3.  **JavaScript Logic (`src/app.js`)**
    *   **State Management:** Use `currentAIState` and potentially `underlyingAIState` (for mute).
    *   **`updateUIState(newState)` Function:** Central controller to add/remove state classes, update status bar icon/text (handling `context.label` for processing), trigger transition flash, and manage particle/orb effects. Handles storing/restoring state when muting/unmuting. Needs to handle `idle`, `listening`, `processing`, `speaking`, `executing`, `notifying`, `muted`, `disconnected`, and `error` states.
    *   **Event Handling:** Mute button listener calls `updateUIState`. Connection logic calls `updateUIState`. WebSocket `status_update` messages trigger calls to `updateUIState`. Other events (MCP messages) will trigger calls to `updateUIState`.

4.  **Data Flow Diagram:**
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
    ```

## Implementation Notes
-   Use CSS animations (keyframes) and SVGs/Emoji (for icons).
-   JavaScript manages state and applies CSS classes.
-   Use CSS variables for theme colors.

## Accessibility
-   Provide tooltips or aria-labels for orb states.
-   Ensure sufficient contrast for all elements.
-   Use explicit icons in the status bar.
-   Respect `prefers-reduced-motion`.