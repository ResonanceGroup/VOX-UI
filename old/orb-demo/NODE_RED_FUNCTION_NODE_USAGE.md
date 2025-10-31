# VOX-UI Node-RED Orb Overlay Function Node

This Node-RED function node processes JSON payload objects and translates them into appropriate messages for controlling the VOX-UI orb overlay. The function directly processes JSON parameters without MQTT topic parsing.

## Features

- **Direct JSON Processing**: Processes JSON payload parameters directly
- **State Processing**: Handles `state` parameter with values: "idle", "executing", "processing", "muted", "notifying", "disconnected"
- **Audio Level Integration**: Processes `audioLevel` or `level` parameters from 0 to 1 for real-time visual feedback
- **Smart Overlay Control**: Automatically shows overlay on state changes while preserving audio level updates
- **Efficient Updates**: Rate limiting to prevent message spam
- **Flexible Parameters**: Supports all orb overlay parameters (command, theme, status, etc.)

## Input Payload Structure

The function accepts a JSON object with any combination of the following parameters:

```javascript
{
  "state": "executing",           // AI state (optional)
  "audioLevel": 0.75,            // Audio input level 0.0-1.0 (optional) 
  "level": 0.75,                 // Alternative audio level parameter (optional)
  "command": "show",             // Show/hide command (optional)
  "theme": "dark",               // Theme (dark/light) (optional)
  "status": "Processing request" // Custom status text (optional)
}
```

## Output Message Structure

The function generates messages compatible with the Node-RED orb notification system:

### State Change Messages
```javascript
msg.payload = {
  "command": "show",              // Show overlay on state changes
  "state": "executing",           // AI state value
  "status": "Executing command"   // Descriptive text
}
```

### Audio Level Messages  
```javascript
msg.payload = {
  "level": 0.75                   // Audio level (0.0 to 1.0)
}
```

### Combined Messages
```javascript
msg.payload = {
  "command": "show",
  "state": "processing",
  "status": "Processing request",
  "level": 0.65,
  "theme": "dark"
}
```

## Node-RED Flow Setup

### Basic Flow
```
[JSON Source] → [Function: JSON to Orb] → [Notification Node]
```

### Configuration

1. **JSON Source Node**
   - Any node that can generate JSON payloads (HTTP, MQTT, manual inject, etc.)
   - Payload should be a JSON object with desired parameters

2. **Function Node** 
   - Copy contents of `node-red-orb-mqtt-function.js` into function
   - Name: "JSON to Orb Overlay Controller"

3. **Notification Node**
   - Topic: Leave empty or set to "Orb"
   - Position: Any position (overlay covers entire screen)
   - Timeout: Set to 0 (never auto-dismiss)
   - ✅ Enable "Raw HTML" mode

## Usage Examples

### Simple State Update
**Input JSON:**
```json
{
  "state": "processing"
}
```

**Generated Output:**
```javascript
msg.payload = {
  "command": "show",
  "state": "processing", 
  "status": "Processing request"
}
```

### Audio Level Update
**Input JSON:**
```json
{
  "audioLevel": 0.65
}
```

**Generated Output:**
```javascript
msg.payload = {
  "level": 0.65
}
```

### Combined Update
**Input JSON:**
```json
{
  "state": "executing",
  "audioLevel": 0.8,
  "status": "Running complex analysis"
}
```

**Generated Output:**
```javascript
msg.payload = {
  "command": "show",
  "state": "executing",
  "status": "Running complex analysis",
  "level": 0.8
}
```

### Theme Change
**Input JSON:**
```json
{
  "theme": "dark",
  "command": "show"
}
```

**Generated Output:**
```javascript
msg.payload = {
  "theme": "dark",
  "command": "show"
}
```

## Parameter Details

### State Parameter
- **Values**: "idle", "executing", "processing", "muted", "notifying", "disconnected"
- **Behavior**: Shows overlay with "show" command when state changes
- **Status**: Automatically generates descriptive text

### Audio Level Parameters
- **Parameters**: `audioLevel` or `level`
- **Values**: 0.0 to 1.0
- **Behavior**: Updates orb intensity visualization
- **Rate Limiting**: Only sends updates when change > 0.01

### Command Parameter
- **Values**: "show", "hide"
- **Behavior**: Controls overlay visibility
- **Auto-trigger**: Automatically added for state changes

### Theme Parameter
- **Values**: "dark", "light"
- **Behavior**: Switches orb color theme

### Status Parameter
- **Values**: Any string
- **Behavior**: Custom status text display

## Performance Considerations

- **Rate Limiting**: Audio level updates are filtered to prevent excessive messages
- **State Change Detection**: Only sends overlay show command on actual state changes
- **Memory Efficient**: Minimal variable storage and cleanup
- **No Output Optimization**: Returns null when no changes detected

## Troubleshooting

### No Overlay Display
1. ✅ Verify Notification node has "Raw HTML" enabled
2. ✅ Check browser console for JavaScript errors
3. ✅ Ensure function node code is properly copied
4. ✅ Verify JSON payload structure is correct

### Audio Level Not Updating
1. ✅ Check audio level is between 0.0 and 1.0
2. ✅ Verify parameter name is `audioLevel` or `level`
3. ✅ Check for significant value changes (> 0.01 difference)

### Overlay Shows but States Don't Change
1. ✅ Verify state values match valid options
2. ✅ Check browser console for invalid state warnings
3. ✅ Ensure orb notification JavaScript is loading properly

## Customization

You can modify the `STATE_DESCRIPTIONS` object in the function to customize the status text displayed for each state:

```javascript
const STATE_DESCRIPTIONS = {
    "idle": "Ready to assist...",
    "executing": "Executing command",
    "processing": "Processing request", 
    "muted": "Microphone muted",
    "notifying": "Notification received",
    "disconnected": "Disconnected"
};
```

## Integration with Existing System

This function works seamlessly with the existing VOX-UI orb notification system (`node-red-orb-notification.js`) and maintains compatibility with all documented features including:
- Double-tap to dismiss
- Theme support (dark/light)
- Audio level visualization
- Particle effects for notifications
- Smooth state transitions

## Example Node-RED Flows

### Voice Assistant Integration
```json
{
  "state": "processing",
  "audioLevel": 0.6,
  "status": "Understanding your request..."
}
```

### Notification System
```json
{
  "state": "notifying",
  "status": "New message received",
  "command": "show"
}
```

### Connection Status
```json
{
  "state": "disconnected",
  "status": "Connection lost"
}