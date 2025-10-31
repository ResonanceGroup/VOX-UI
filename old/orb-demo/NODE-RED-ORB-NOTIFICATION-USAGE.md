# Node-RED Orb Overlay - Notification Version

This version uses Node-RED's notification system to create a **global overlay** that appears on all dashboard pages and can receive continuous updates.

## Key Features

- **Global Display**: Appears on all dashboard pages (not limited to specific groups)
- **Persistent Overlay**: Stays active and can receive continuous updates
- **Smart Update System**: Prevents duplicate overlays, updates existing one instead
- **Full Orb Animation**: Complete VOX-UI orb with swirling elements and state animations
- **Double-tap to Dismiss**: User can hide overlay by double-tapping
- **Audio Level Visualization**: Real-time audio level affects orb intensity

## Setup Instructions

### 1. Add Function Node
Create a **Function** node with the following configuration:

**Name**: `Orb Overlay Controller`

**Code**: Copy the entire contents of `node-red-orb-notification.js` into the function node.

### 2. Connect to Notification Node
1. Add a **Notification** node after the function node
2. Configure the notification node:
   - **Topic**: Leave empty or set to "Orb"
   - **Position**: Any position (the overlay will cover the entire screen)
   - **Timeout**: Set to 0 (never auto-dismiss)
   - **Raw HTML**: ✅ **ENABLE THIS** (critical for HTML content)

### 3. Wire the Flow
```
[Input] → [Function: Orb Overlay Controller] → [Notification]
```

## Message Payload Structure

Send messages with this payload structure:

```javascript
{
    "command": "show",        // "show" or "hide"
    "state": "executing",     // AI state
    "status": "Processing your request...", // Status text
    "theme": "dark",          // "dark" or "light"
    "level": 0.7             // Audio level (0.0 to 1.0)
}
```

### Payload Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `command` | string | No | "show" to display overlay, "hide" to hide it |
| `state` | string | No | AI state: "idle", "executing", "processing", "notifying", "muted", "disconnected" |
| `status` | string | No | Status text to display below the orb |
| `theme` | string | No | "dark" (default) or "light" theme |
| `level` | number | No | Audio level from 0.0 to 1.0 (affects orb intensity) |

## Usage Examples

### Initial Display
```javascript
msg.payload = {
    "command": "show",
    "state": "idle",
    "status": "Ready to assist...",
    "theme": "dark"
};
return msg;
```

### Continuous Updates
```javascript
// Update state and status (overlay stays visible)
msg.payload = {
    "state": "executing",
    "status": "Processing your request...",
    "level": 0.8
};
return msg;
```

### Audio Level Updates
```javascript
// Send frequent audio level updates
msg.payload = {
    "level": 0.6  // Only update audio level
};
return msg;
```

### Hide Overlay
```javascript
msg.payload = {
    "command": "hide"
};
return msg;
```

### Theme Changes
```javascript
// Switch to dark theme
msg.payload = {
    "theme": "dark"
};
return msg;

// Switch to light theme
msg.payload = {
    "theme": "light"
};
return msg;

// Combine with other properties
msg.payload = {
    "command": "show",
    "theme": "dark",
    "state": "idle",
    "status": "Dark mode enabled"
};
return msg;
```

## State Behaviors

| State | Icon | Color | Animation |
|-------|------|-------|-----------|
| `idle` | ● | Green | Gentle pulse |
| `executing` | ⚙️ | Purple | Pulsing ring effect |
| `processing` | ⟳ | Blue | Rotating indicator |
| `notifying` | 🔔 | Light Blue | Attention pulse |
| `muted` | 🔇 | Orange | Dimmed animation |
| `disconnected` | ❌ | Red | Error state |

## Audio Level Effects

- **0.0 - 0.25**: Minimal orb activity
- **0.25 - 0.5**: Low intensity swirling
- **0.5 - 0.75**: Medium intensity effects
- **0.75 - 1.0**: High intensity, maximum visual activity

## Advanced Usage

### Automated State Machine
```javascript
// Example: Cycle through states
var states = ["idle", "executing", "processing", "notifying"];
var currentState = context.get("currentState") || 0;

msg.payload = {
    "state": states[currentState],
    "status": "State: " + states[currentState],
    "level": Math.random()
};

context.set("currentState", (currentState + 1) % states.length);
return msg;
```

### Real-time Audio Monitoring
```javascript
// Connect to audio input and send frequent updates
msg.payload = {
    "level": msg.payload.audioLevel || 0,
    "status": "Audio Level: " + Math.round((msg.payload.audioLevel || 0) * 100) + "%"
};
return msg;
```

## Troubleshooting

### Overlay Not Appearing
1. ✅ Verify **Raw HTML** is enabled in the notification node
2. ✅ Check browser console for JavaScript errors
3. ✅ Ensure function node code is complete and error-free

### Multiple Overlays
- The system prevents duplicates automatically
- If you see multiple overlays, refresh the dashboard page

### Updates Not Working
- The overlay must be shown first with `"command": "show"`
- Subsequent messages can omit the command and just update properties
- Check browser console for update logs (🔵 Updating orb overlay)

### Performance
- Audio level updates can be sent frequently (10-30 times per second)
- State/status updates should be sent only when values change
- The overlay is optimized for smooth animations

## Benefits Over Template Node Approach

1. **Global Visibility**: Works on all dashboard pages
2. **No Group Assignment**: Doesn't require dashboard group configuration
3. **Persistent Updates**: Can receive continuous message streams
4. **Better Performance**: Single overlay instance, efficient updates
5. **User Control**: Double-tap to dismiss functionality

## Browser Compatibility

- Modern browsers with CSS Grid and Flexbox support
- Chrome, Firefox, Safari, Edge (recent versions)
- Mobile browsers supported