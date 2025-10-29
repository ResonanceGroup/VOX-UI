# Active Context

## Current Status: MCP Servers Screen Redesign - Phase 2

**Last Updated**: October 29, 2025
**Current Task**: Implementing additional improvements to MCP Servers screen based on user feedback
**Session Status**: Phase 1 complete, moving to Phase 2 refinements

## What We Just Completed (Phase 1)

### Major MCP Servers Screen Updates ✅
1. **Enable MCP Servers Section** - Fixed checkbox to be checked by default, improved text brightness in dark mode
2. **Network Timeout Dropdown** - Added complete dropdown with all timeout options (15s-60min)
3. **Connected Servers Heading** - Fixed text brightness in dark mode (#E0E0E0)
4. **Server List Items** - Added blue server icons, replaced status text with colored dots, added toggle switches
5. **Tools/Resources Tabs** - Redesigned with Roo Code style (underline for active tab, proper colors)
6. **Tool Details Card** - Added PARAMETERS section with formatted parameter list matching Roo Code design

### Files Modified in Phase 1
- `lib/screens/mcp_servers_screen.dart` - Complete redesign of MCP server accordion and tool display

## Current Work (Phase 2 - In Progress)

### Pending Improvements Based on User Feedback
1. **Network Timeout Placement** - Move from top to end of each MCP server entry
2. **Dropdown Height Fix** - Investigate and fix tall dropdown issue
3. **Tool Icon Change** - Replace search icon with wrench icon for tools
4. **Tool Description** - Add description field below tool name
5. **Background Colors** - Add distinction between tool card and server group box backgrounds
6. **Widget Refactoring** - Create dedicated McpServerWidget and McpToolWidget for better structure
7. **Smooth Animations** - Add animated expand/collapse to accordions

## Key Technical Decisions Made

### MCP Servers Screen Architecture
- Accordion-style server list with expandable details
- Status indicators: colored dots (green=connected, red=disconnected)
- Toggle switches for enable/disable functionality
- Tab-based navigation for Tools/Resources
- PARAMETERS section with formatted parameter display

### Color Scheme (Current)
```dart
// Server Icons
Blue: #347AB8 with 10% opacity background

// Status Indicators
Connected: Green dot
Disconnected: Red dot

// Text Colors (Dark Mode)
Headings: #E0E0E0
Body Text: #CCCCCC
Parameters: #DDA0DD (purple/pink for names)

// Backgrounds (Dark Mode)
Main Panel: #252526
Server Card: #2C2C2C
Tool Card: #2C2C2C (needs distinction - Phase 2)
```

## Next Steps for Phase 2

### Immediate Actions
1. Update activeContext.md with Phase 1 changes ✅
2. Move Network Timeout to individual server entries
3. Fix dropdown height styling
4. Implement widget refactoring for better code organization
5. Add smooth accordion animations
6. Update tool display with wrench icons and descriptions

### Code Structure Plan
```dart
// New widget hierarchy
McpServersScreen
├── Enable MCP Servers checkbox
├── Connected Servers list
│   └── McpServerWidget (custom, reusable)
│       ├── Server header (icon, name, status dot, toggle)
│       ├── Tools/Resources tabs
│       ├── McpToolWidget (custom, reusable)
│       │   ├── Tool icon (wrench)
│       │   ├── Tool name
│       │   ├── Tool description
│       │   ├── Parameters section
│       │   └── Always allow toggle
│       └── Network Timeout dropdown
└── Edit MCP Servers button
```

## File Structure Reference

```
lib/
├── main.dart
├── providers/
│   └── theme_provider.dart
├── theme/
│   └── app_theme.dart
├── widgets/
│   ├── navigation_drawer.dart
│   ├── orb_widget.dart
│   └── mcp/ (to be created in Phase 2)
│       ├── mcp_server_widget.dart (new)
│       └── mcp_tool_widget.dart (new)
└── screens/
    ├── chat_screen.dart
    ├── mcp_servers_screen.dart (major refactor needed)
    └── settings_screen.dart
```

## Known Issues & To-Do

### Phase 2 Issues to Fix
1. Network Timeout dropdown too tall (height styling issue)
2. Tool cards need different background color from server box
3. Missing tool descriptions
4. No animation on accordion expand/collapse
5. Code needs refactoring into dedicated widgets

### Design Goals (Phase 2)
- Better visual hierarchy with background color distinction
- Smoother UX with animated accordions
- More maintainable code with dedicated widgets
- Prepare for future config file parsing integration

## Success Criteria

| Criteria | Phase 1 | Phase 2 |
|----------|---------|---------|
| Visual match to old design | ✅ 90% | ⏳ Target 100% |
| Roo Code style match | ✅ Complete | ⏳ Refinements |
| Code maintainability | ⚠️ Basic | ⏳ Refactored |
| Smooth animations | ❌ | ⏳ Pending |
| Ready for config parsing | ❌ | ⏳ Pending |

## Memory Bank Update Notes
This document reflects the current state after Phase 1 completion. Phase 2 work is in progress focusing on refinements, better code structure, and preparation for future config file integration.