# RooCode Prompt — VOX UI (Flutter) Frontend-Only Mock (with VS Code project init)

**Mission**  
Build a **Flutter app** that faithfully matches the existing VOX UI visually and interactively (menus, accordions, light/dark theme).  
This is **frontend-only**: **no backend, no WebSockets, no audio, no LiveKit, no MCP**.

---

## 0) Preparation — Inspect the Live Web UI

Before coding:

1. **Open the running web app** using RooCode’s built-in browser tool. (I’ll have VS Code **Live Server** running.)  
   - Likely URL: `http://127.0.0.1:5500/src/index.html` (adjust if needed).
2. **Explore**: sidebar open/close + blur overlay, page transitions (Chat / MCP Servers / Settings), accordion expand/collapse, light/dark theme visuals.  
3. **Cross-reference** with source for visual values only:
   - `src/index.html`, `src/mcp_servers.html`, `src/settings.html`
   - `src/app.css`, `src/orb.css`, and related UI JS
4. Capture **approximate timings/easings/opacities** to replicate in Flutter (note any approximations inline with `// approx`).

---

## 1) Create the Flutter Project (VS Code default)

Use **standard VS Code Flutter commands** to scaffold a fresh project (templates, configs, etc.):

- Command Palette → **Flutter: New Project** → **Application**  
- Project name (e.g.): `vox_ui_flutter`  
- After creation, use the generated structure as the base.  
- Add any additional files/folders as needed; **don’t rigidly follow any prescribed structure** here—use your best judgment and Flutter best practices.

> Goal: let the tool apply its preferred layout while keeping things clean and modular.

---

## 2) Scope (Phase 1 — Visual & Navigation Only)

- **Orb**: use a **custom widget** (see §3) that currently renders a **solid circle** only (no state/animation yet).
- **Navigation**: hamburger → slide-in **sidebar** with **overlay scrim**, routes for:
  - **Chat** (orb + status text + input bar stub)
  - **MCP Servers** (accordion UI only, static items)
  - **Settings** (accordion groups: Voice Agent, MCP, n8n, General UI)
- **UI interactions**: accordions open/close; tabs toggle content; **theme switcher** updates **light/dark/system** live.
- **No data/persistence/network**. All state is in-memory view state only.

**Strictly Out of Scope (now):** WebSockets, audio, LiveKit, MCP tools, orb state machine/animations beyond a plain circle.

---

## 3) Orb as a Custom Widget (placeholder now, future-ready)

Create `OrbWidget` as its **own custom widget** (and file). For now it **only draws a circle**.

- Public API (document, but can be no-op until Phase 2):
  - `OrbController` (class/interface): future surface for `setState(status)`, `setAmplitude(level)`, etc. (currently unused).
  - `OrbWidget({ OrbController? controller })`
  - Optional params for size and theme color (read but can be unused).
- Add `// TODO(phase-2)` notes where the LiveKit/MCP/state logic will later connect.
- Keep internals simple; do **not** import any backend code.

---

## 4) Theming & Visual Fidelity

- Implement **system/light/dark** themes via Flutter theming (Material 3 if convenient).
- Centralize color/spacing tokens (single source of truth).  
- Match live UI’s **spacing, radii, opacities, overlay blur feel, typography scale**.  
- If an exact value is unknown, use a close Material value and comment `// approx`.

---

## 5) Minimal Architecture (flexible)

Keep it clean, but you choose the final structure. General guidance (non-binding):

- **State mgmt**: Riverpod *or* Provider for:
  - theme mode (system/light/dark)
  - sidebar open/close, accordion state
- **Routing**: GoRouter *or* Navigator 2.0 with named routes:
  - `/chat`, `/mcp-servers`, `/settings`
- **Widgets** to include (names flexible):
  - `OrbWidget` (custom)  
  - `StatusBar` (icon+text, static “Ready”)  
  - `SidebarDrawer` + `OverlayScrim`  
  - `AccordionGroup`  
  - `ThemeSelector` (radio/toggle)  
  - `McpServersList` (static examples; toggles are visual only)  
  - `JsonEditorPlaceholder` (multiline TextField, no parsing/saving)  
  - `InputBarStub` (no-op send)

---

## 6) Deliverables

- A **running Flutter app** that:
  - Visually matches the existing web UI (based on the **browser inspection** step).  
  - Navigates between Chat/MCP Servers/Settings.  
  - Opens/closes the sidebar with an overlay scrim.  
  - Shows a **solid-circle `OrbWidget`** on Chat.  
  - Switches themes (system/light/dark) live.  
  - Has working accordions/tabs (visual only).
- **Readable, commented code**:
  - Short, focused files; doc comments at top of custom widgets.  
  - `// TODO(phase-2)` markers at future integration seams (orb controller, LiveKit/MCP).

---

## 7) Acceptance Checklist

- [ ] Project created via **VS Code Flutter: New Project** (default template).  
- [ ] **No backend** logic or imports added.  
- [ ] `OrbWidget` exists and renders **only a solid circle**.  
- [ ] Sidebar opens/closes with overlay; routes switch pages.  
- [ ] All accordions expand/collapse; tabs swap content (visual only).  
- [ ] Theme switcher toggles system/light/dark instantly.  
- [ ] Visuals are **close to the live web UI**; approximations annotated.  
- [ ] Code is modular, commented, and easy to extend.

---

## 8) Notes

- Start by **opening and exploring the running web UI** inside RooCode’s browser tool (see §0).  
- Use source files **only for visual tokens**; **do not** copy backend or JS logic.  
- Keep it simple and maintainable; we’ll integrate the real **orb logic** (from the separate branch) and **LiveKit** in **Phase 2**.
