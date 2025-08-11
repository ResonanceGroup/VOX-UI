# Node-RED AI Assistant Orb Overlay

This Node-RED template creates a full-screen overlay with an animated AI assistant orb that can be controlled via message payloads. Perfect for voice assistants and AI interaction interfaces.

## Installation

1. In Node-RED, drag a **Template** node onto your flow
2. Double-click the Template node to open its configuration
3. Copy the entire contents of `node-red-orb-overlay.html` into the Template field
4. Set the Template node to output to `All msg properties`
5. Deploy your flow

## Message Payload Structure

Send messages to the template node with a `msg.payload` object containing any of these properties:

```javascript
{
  "command": "show",           // "show" or "hide" - controls overlay visibility
  "state": "processing",       // AI state (see states below)
  "status": "Analyzing data...", // Custom status text
  "theme": "dark",            // "light" or "dark"
  "level": 0.75               // Audio level 0.0 to 1.0
}
```

### Available States

- **`idle`** - Ready state with green indicator
- **`executing`** - Shows animated gear, purple ring effect
- **`processing`** - Animated ellipsis, enhanced colors
- **`notifying`** - Particle burst effect with blue colors
- **`muted`** - Grayscale with muted microphone icon
- **`disconnected`** - Static noise effect, red indicator

### Example Messages

#### Show overlay with processing state
```javascript
msg.payload = {
  "command": "show",
  "state": "processing",
  "status": "Analyzing your request...",
  "theme": "dark"
};
return msg;
```

#### Update audio level in real-time
```javascript
msg.payload = {
  "level": 0.8  // High audio activity
};
return msg;
```

#### Show notification
```javascript
msg.payload = {
  "state": "notifying",
  "status": "New message received"
};
return msg;
```

#### Hide overlay
```javascript
msg.payload = {
  "command": "hide"
};
return msg;
```

## Features

### 🎨 **Visual States**
- Each state has unique animations and visual effects
- Smooth transitions between states
- Audio-reactive intensity scaling

### 🌓 **Theme Support**
- Light and dark themes
- Automatic color adjustments for optimal visibility

### 📱 **Touch Interaction**
- Double-tap anywhere on the overlay to dismiss it
- Mobile-optimized with proper touch handling

### 🔊 **Audio Visualization**
- Real-time audio level visualization
- Intensity-based scaling and glow effects
- Threshold-based visual feedback (low/medium/high)

### ✨ **Particle Effects**
- Notification state triggers particle burst
- Randomized particle trajectories and colors
- Flash and wave effects for emphasis

## Usage Patterns

### Voice Assistant Integration
```javascript
// When user starts speaking
msg.payload = { "level": 0.6, "state": "idle" };

// When processing speech
msg.payload = { "state": "processing", "status": "Understanding..." };

// When executing command
msg.payload = { "state": "executing", "status": "Running lights command" };

// When responding
msg.payload = { "level": 0.8, "state": "idle" };
```

### Notification System
```javascript
// Show notification
msg.payload = { 
  "command": "show",
  "state": "notifying", 
  "status": "Calendar reminder: Meeting in 5 minutes" 
};

// Auto-hide after delay (handled automatically by template)
// Or manually hide
setTimeout(() => {
  msg.payload = { "command": "hide" };
}, 3000);
```

### Connection Status
```javascript
// Connected
msg.payload = { "state": "idle", "status": "Connected" };

// Disconnected
msg.payload = { "state": "disconnected", "status": "Connection lost" };

// Muted
msg.payload = { "state": "muted", "status": "Microphone muted" };
```

## Styling Customization

The template includes comprehensive CSS that can be modified:

- **Colors**: Modify the gradient colors in the `.c` selectors
- **Size**: Adjust `.orb` width/height for different sizes
- **Animation Speed**: Change animation durations in keyframes
- **Blur Effects**: Modify `filter: blur()` values for different effects

## Technical Notes

- **Z-Index**: Overlay uses `z-index: 9999` to appear above all content
- **Performance**: Uses CSS transforms and GPU acceleration for smooth animations
- **Responsive**: Automatically adjusts for mobile screens
- **Memory**: Cleans up particle effects and timers automatically

## Troubleshooting

### Overlay not showing
- Check that `command: "show"` is being sent
- Verify the template node is receiving messages
- Check browser console for JavaScript errors

### Animations not working
- Ensure CSS animations are enabled in browser
- Check for conflicting CSS in your dashboard
- Verify hardware acceleration is available

### Double-tap not working
- Ensure touch events are not being intercepted
- Check that the overlay is receiving click events
- Verify the double-tap timing (300ms window)

## Browser Compatibility

- ✅ Chrome/Chromium (recommended)
- ✅ Firefox
- ✅ Safari
- ✅ Edge
- ⚠️ Internet Explorer (limited support)

## Performance Tips

1. **Limit frequent updates**: Don't send level updates more than 10-20 times per second
2. **Use appropriate states**: Don't rapidly switch between states
3. **Theme consistency**: Set theme once rather than frequently changing
4. **Clean shutdown**: Send `command: "hide"` when done to clean up resources