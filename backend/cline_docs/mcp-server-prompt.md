# RooCode MCP Server Development Project

## Project Overview

**Goal**: Create an MCP (Model Context Protocol) server that exposes RooCode VSCode extension APIs, enabling voice-controlled interaction with RooCode through MCP-compatible clients like voice agents.

**Why This Matters**: Currently, there's no way to voice-control RooCode. This MCP server will bridge that gap, allowing users to speak commands that get executed by RooCode (e.g., "Create a React component", "Run tests", "Fix this bug").

**Inspiration**: Base our implementation on the excellent `vscode-mcp-server` extension (https://github.com/juehang/vscode-mcp-server), which provides 80% of what we need.

## Technical Foundation

### Existing VSCode MCP Server (Template)
- **GitHub**: https://github.com/juehang/vscode-mcp-server
- **Features We Like**:
  - Status bar toggle button to enable/disable per VSCode window
  - Existing settings infrastructure for hostname, port, etc.
  - Clean architecture with proper VSCode extension structure
  - Working MCP server implementation (we'll replace the tools)

### RooCode Extension APIs (What We Need to Expose)
From research, RooCode exposes these public API methods that we need to wrap in MCP tools:

**Core Task Management:**
- `startNewTask(text: string, images?: string[], newTab?: boolean)` - Start new coding tasks
- `cancelTask()` - Cancel running tasks
- `resumeTask()` - Resume paused tasks
- `sendMessage(message: string, images?: string[])` - Send messages to active tasks

**UI Interaction:**
- `pressPrimaryButton()` - Approve task interactions
- `pressSecondaryButton()` - Deny task interactions

**Status:**
- `isReady()` - Check if RooCode is ready

## Project Architecture

```
MCP Client → Our MCP Server → RooCode APIs
     ↓                                           ↓
Any MCP-compatible app                 VSCode Extension
```

**Implementation Approach:**
Start with the working `vscode-mcp-server` codebase and modify it by removing the existing tools and replacing them with our RooCode control tools. Keep the existing extension structure, settings, and MCP server framework intact.

## Implementation Plan

### Phase 1: Setup & Familiarization
1. Review the forked `vscode-mcp-server` codebase structure
2. Update extension metadata for RooCode-specific naming
3. Verify existing MCP server framework compiles and runs
4. Understand the existing tool implementation pattern

### Phase 2: RooCode Integration Foundation
1. Remove existing tool implementations from MCP server
2. Create RooCode API wrapper module
3. Add RooCode extension discovery logic
4. Implement error handling for unavailable RooCode

### Phase 3: Core MCP Tools Implementation
1. Define MCP tool schemas for RooCode operations:
   - `roocode_start_task` - Start new coding tasks
   - `roocode_send_message` - Send messages to active tasks
   - `roocode_cancel_task` - Cancel running tasks
   - `roocode_resume_task` - Resume paused tasks
   - `roocode_approve_action` - Approve interactive prompts
   - `roocode_deny_action` - Deny interactive prompts
   - `roocode_check_status` - Check extension readiness
2. Implement tool handlers calling RooCode APIs
3. Add error handling and clear success/failure responses

### Phase 4: Testing & Optimization
1. Test integration with actual RooCode extension
2. Verify MCP protocol compliance
3. Handle edge cases (no active task, extension unavailable, etc.)
4. Refine responses for clarity and usability

## Key Technical Decisions

### VSCode Extension Architecture
- **Status Bar Integration**: Like `vscode-mcp-server`, provide toggle per window
- **Settings**: hostname, port, authentication, auto-enable options
- **Error Handling**: Graceful degradation when RooCode unavailable

### MCP Server Design
- **Tool Organization**: Group tools by functionality (task management, messaging, etc.)
- **Response Format**: Voice-friendly responses with clear status
- **Event Streaming**: Real-time updates for long-running tasks

### RooCode API Integration
- **Extension Discovery**: `vscode.extensions.getExtension('RooVeterinaryInc.roo-cline')`
- **API Access**: `extension.exports` contains public RooCode APIs
- **Error Handling**: Handle cases where RooCode isn't installed/enabled

## Success Criteria

### Functional Requirements
- ✅ Voice agents can start RooCode tasks via MCP
- ✅ Voice agents can send messages to active tasks
- ✅ Voice agents can cancel/resume tasks
- ✅ Real-time task status updates
- ✅ Multi-window VSCode support

### Technical Requirements
- ✅ Clean MCP server implementation
- ✅ Proper VSCode extension structure
- ✅ Error handling and logging
- ✅ Settings and configuration
- ✅ Status bar toggle UI

### User Experience
- ✅ Easy installation and setup
- ✅ Clear error messages
- ✅ Voice-optimized responses
- ✅ Works with existing MCP clients

## Development Constraints

- **VSCode APIs Only**: No external dependencies beyond VSCode and MCP
- **Local Operation**: Everything runs locally, no cloud required
- **Extension Compatibility**: Must work with current RooCode versions
- **Performance**: Minimal overhead when not in use

## Integration with Voice Agent (Parent Project)

Once this MCP server is built, integration with the voice agent project is straightforward:

1. Add MCP server to voice agent's MCP configuration
2. Voice agent gets new tools: `roocode_start_task`, `roocode_send_message`, etc.
3. Voice commands like "Create a login component" translate to MCP tool calls
4. Real-time responses flow back through MCP

## Testing Strategy

1. **Unit Tests**: MCP protocol compliance, API wrapper functionality
2. **Integration Tests**: Actual RooCode extension interaction
3. **Voice Agent Tests**: End-to-end voice command flow
4. **Multi-Window Tests**: Controlling specific VSCode instances

## Documentation Requirements

- Installation and setup guide
- API reference for MCP tools
- Configuration options
- Troubleshooting guide
- Voice agent integration examples

---

## Getting Started

1. Create new workspace for this project
2. Clone `vscode-mcp-server` as base
3. Initialize memory bank with above context
4. Begin Phase 1 implementation

This project will be a valuable contribution to both the RooCode and MCP communities, enabling voice-controlled AI coding workflows!