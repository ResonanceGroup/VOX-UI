# Status Indicator Design Plan (Hybrid Concept)

This document outlines the agreed-upon design and frontend architecture for status indicators in the VOX UI, combining orb animations with an enhanced status bar below the orb.

## Core Idea
- Use dynamic orb animations for primary, attention-grabbing feedback.
- Use an enhanced status bar (icons + text below orb) for secondary, clearer context.

## Visual States & Feedback

### Primary Feedback (Orb Animations)

1.  **Executing Tools (MCP):**
    *   **Visual:** Soft, pulsing ring of light around the orb, slightly detached.
    *   **Animation:** Gentle, slow pulse (opacity fade in/out).
    *   **Light Mode:** Ring color: `#7E57C2`. Opacity pulse: 30-70%.
    *   **Dark Mode:** Ring color: `#9575CD`. Opacity pulse: 40-80%.
    *   **Transition:** Ring fades in (300ms) on start, fades out on end.

2.  **Receiving Notifications:**
    *   **Visual:** Small, bright particles briefly emanate outwards from the orb.
    *   **Animation:** Quick (500ms) burst of 5-7 particles fading out as they expand.
    *   **Light Mode:** Particle color: `#42A5F5`.
    *   **Dark Mode:** Particle color: `#64B5F6`.
    *   **Transition:** Instantaneous burst.

3.  **Processing Information:**
    *   **Visual:** Orb's internal nebula/gradient swirls/rotates faster than idle.
    *   **Animation:** Internal flow animation speed increases.
    *   **Light/Dark Mode:** Uses existing orb colors.
    *   **Transition:** Speed ramps up (200ms) on start, slows on end.

4.  **Muted:**
    *   **Visual:** No change to the orb itself. Feedback is via the mute button and status bar.

5.  **Disconnected:**
    *   **Visual:** Orb becomes static and desaturated (grayscale). All animations stop.
    *   **Transition:** Applies instantly on disconnect, reverts on reconnect.

6.  **Transitioning Between States:**
    *   **Visual:** Quick, soft cross-fade effect on orb brightness/saturation or color wash (except for Muted state changes).
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
    *   **Idle:** `[●] Ready to assist...` (or `[✓]`)
    *   **Executing Tools:** `[⚙️] Executing: [Tool Name]...`
    *   **Receiving Notification:** `[🔔] Notification Received` (Briefly shown)
    *   **Processing:** No icon, only animated ellipsis: `Processing....` with 1-4 dots that animate in sequence
    *   **Processing (Custom):** Supports custom labels: `CustomLabel....` with same animated dots
    *   **Muted:** `[🎙️🚫] Microphone Muted` (Orange/muted grey icon color suggested)
    *   **Disconnected:** `[❌] Disconnected` (Red icon/text color suggested)
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
    *   **State Classes:** Define `.state-idle`, `.state-executing`, `.state-notifying`, `.state-processing`, `.state-muted`, `.state-disconnected` (applied to `body` or main container).
    *   **Orb Animations:** Define `@keyframes` for ring pulse, particle burst (if feasible in pure CSS), swirl speed change, transition flash. Style `.orb-status-ring`. Add rules for `.state-disconnected .orb` (grayscale, stop animations).
    *   **Status Bar Styling:** Style `#status-display`, `.status-icon`, `.status-text`. Use state classes to set icon content (e.g., `.state-executing .status-icon::before { content: '⚙️'; }`) and colors. Define fade transitions.
    *   **Processing State Animation:** Hide the status icon with `.state-processing .status-icon { display: none; }`. Use custom keyframes for dots animation that progresses from 1 to 4 dots and then resets:
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
    *   **`updateUIState(newState)` Function:** Central controller to add/remove state classes, update status bar icon/text, trigger transition flash, and manage particle effects. Handles storing/restoring state when muting/unmuting.
    *   **Event Handling:** Mute button listener calls `updateUIState`. Connection logic calls `updateUIState`. Other events (MCP messages) will trigger calls to `updateUIState`.

4.  **Data Flow Diagram:**
    ```mermaid
    graph TD
        A[External Event (MCP/WebSocket/Timer/Button)] --> B{JS Event Listener};
        Conn[Connection Status Change] --> B;

        B -- Triggers --> C[updateUIState(newState)];

        C -- Updates --> D[HTML Elements (Orb Container, Status Bar)];
        C -- Adds/Removes --> E[CSS State Classes];

        E -- Activates --> F[CSS Animations & Styles];

        D -- Displays --> G(Updated Icon & Text);
        F -- Displays --> H(Orb Effects: Ring/Particles/Swirl/Grayscale/Static);
    ```

## Implementation Notes
-   Use CSS animations (keyframes) and SVGs (for icons).
-   JavaScript manages state and applies CSS classes.
-   Use CSS variables for theme colors.

## Accessibility
-   Provide tooltips or aria-labels for orb states.
-   Ensure sufficient contrast for all elements.
-   Use explicit icons in the status bar.
-   Respect `prefers-reduced-motion`.