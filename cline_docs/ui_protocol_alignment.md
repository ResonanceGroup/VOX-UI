# UI State &amp; WebSocket Protocol Alignment

**Date:** 2025-04-10

## Purpose

This document summarizes the analysis comparing the agent status updates defined in `cline_docs/websocket_protocol.md` with the UI visual states defined in `cline_docs/status_indicator_design.md`. It identifies gaps and outlines the agreed-upon changes required to ensure alignment between the backend protocol and the frontend UI representation.

## Alignment Analysis Table

| Protocol Status (`status_update.payload.status`) | Protocol Context (`status_update.payload.context`) | UI Design State (`status_indicator_design.md`) | CSS Class Trigger | Alignment Notes                                                                                                                               |
| :----------------------------------------------- | :------------------------------------------------- | :--------------------------------------------- | :---------------- | :-------------------------------------------------------------------------------------------------------------------------------------------- |
| `idle`                                           | N/A                                                | Idle                                           | `.state-idle`     | ✅ **Aligned.**                                                                                                                               |
| `listening`                                      | N/A                                                | *Missing*                                      | *Missing*         | ⚠️ **Gap:** UI design lacks a 'Listening' state.                                                                                              |
| `processing`                                     | `type: 'tool_execution'`, `label: 'Executing...'`  | Executing Tools                                | `.state-executing`| ✅ **Aligned.** Protocol context maps well.                                                                                                   |
| `processing`                                     | `type: 'transcribing'`, `label: 'Transcribing...'` | Processing                                     | `.state-processing`| 🤔 **Partial:** UI shows generic "Processing....". Could leverage protocol context for more specific text (e.g., "Transcribing...").           |
| `processing`                                     | `type: 'generating_response'`, `label: 'Thinking...'`| Processing                                     | `.state-processing`| 🤔 **Partial:** UI shows generic "Processing....". Could leverage protocol context for more specific text (e.g., "Generating Response..."). |
| `processing`                                     | `type: 'custom'`, `label: 'Custom...'`             | Processing (Custom)                            | `.state-processing`| ✅ **Aligned.** UI design supports custom labels.                                                                                             |
| `processing`                                     | *None*                                             | Processing                                     | `.state-processing`| ✅ **Aligned.** Generic processing state.                                                                                                     |
| `speaking`                                       | N/A                                                | *Missing*                                      | *Missing*         | ⚠️ **Gap:** UI design lacks a 'Speaking' state.                                                                                               |
| `error`                                          | N/A                                                | *Missing* (as persistent state)                | *Missing*         | ⚠️ **Gap:** UI lacks a persistent 'Error' state triggered by protocol (distinct from 'Disconnected').                                        |
| *N/A (Needs Protocol Change)*                    | *N/A*                                              | Receiving Notification                         | `.state-notifying`| ⚠️ **Gap:** Protocol cannot trigger this UI state.                                                                                            |
| *UI Only*                                        | *N/A*                                              | Muted                                          | `.state-muted`    | N/A (UI-triggered state)                                                                                                                      |
| *Connection Only*                                | *N/A*                                              | Disconnected                                   | `.state-disconnected`| N/A (WebSocket connection state)                                                                                                              |

## Summary of Gaps &amp; Required Changes

1.  **`status_indicator_design.md` Updates:**
    *   Add definitions (orb behavior, status bar text/icon, CSS class) for `Listening` state (triggered by `listening` status).
    *   Add definitions for `Speaking` state (triggered by `speaking` status).
    *   Add definitions for a persistent `Error` state (triggered by `error` status), distinct from `Disconnected`.
    *   Update the `Processing` state definition to explicitly mention using the `context.label` from the protocol for the status bar text when available (e.g., "Transcribing...", "Generating Response...").

2.  **`websocket_protocol.md` Updates:**
    *   Add `'notifying'` as a valid value for the `status` field within the `status_update` message payload definition to allow triggering the UI's `Receiving Notification` state.