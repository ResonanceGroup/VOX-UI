# Product Context

## Purpose
A web-based interface designed primarily to act as a voice interface for the Roo Code VSCode extension, enabling remote control and interaction via the Model Context Protocol (MCP). Key features include:
- Voice and text chat capabilities (interfacing with Roo Code via MCP)
- Visual feedback through an orb visualization
- Configurable settings, including MCP server management
- Theme customization options

## Core Features

### Chat Interface
- Text-based chat interaction (relayed via MCP)
- Voice input/output capability (relayed via MCP)
- Visual orb feedback
- Real-time response indicators (reflecting MCP communication status)

### Settings Management
- Theme customization (Light/Dark/System)
- MCP Server Management
  - Viewing configured MCP servers and their status
  - Enabling/disabling servers
  - Configuring server details (tools, resources, permissions)
  - Editing the underlying MCP configuration file
- Persistent settings storage (for themes, potentially MCP config path)

### Visual Elements
- Interactive orb visualization
- Responsive layout
- Smooth transitions
- Accessibility considerations

## User Experience Goals
1. Intuitive voice control over Roo Code operations
2. Clear visual feedback on Roo Code status and MCP connections
3. Seamless theme switching
4. Easy configuration of MCP servers
5. Mobile-friendly interface
6. Accessible to all users

## Integration Points
- Model Context Protocol (MCP) for communication with external tools/servers (primarily Roo Code)
- WebSocket connections (potentially for local backend relay or direct MCP communication if applicable)
- Local storage for settings (theme, MCP config path)
- System theme detection

## Current Focus (Project Pivot - April 2025)
The project has pivoted to focus on integrating VOX UI with the Roo Code VSCode extension using MCP. The previous plan involving a dedicated Python backend with UltraVox/Kokoro on RunPod is deferred. The current focus is on implementing the UI and necessary connections for MCP-based control of Roo Code.

**Current Development Phase:** Phase 1 - MCP Server Page UI
- Design and implement the user interface for managing MCP server configurations within VOX UI, mirroring the Roo Code MCP settings screen.
- Focus on HTML structure and CSS styling first.
