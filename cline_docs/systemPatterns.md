# System Patterns - VOX-UI

## Architecture Overview

VOX-UI is built as a standalone HTML/CSS/JavaScript application with no external framework dependencies. The architecture follows a component-based approach with:

- **Core Orb Component**: Central animated orb with state management
- **CSS-Driven Animations**: All animations handled through CSS keyframes and transitions
- **State-Based Styling**: Different visual states controlled through CSS classes
- **Event-Driven Updates**: JavaScript handles state changes and DOM updates

## Key Technical Decisions

### 1. Vanilla JavaScript Approach
- **Decision**: No frameworks (React, Vue, etc.)
- **Rationale**: Lightweight, fast loading, no build dependencies
- **Trade-off**: More manual DOM manipulation required

### 2. CSS Variables for Dynamic Styling
- **Decision**: Use CSS custom properties (--intensity) for dynamic values
- **Rationale**: Better performance than JavaScript-driven animations
- **Implementation**: Audio levels mapped to CSS variables for real-time effects

### 3. Notification-Based Overlay System
- **Decision**: Use Node-RED notification system for global overlay
- **Rationale**: Appears on all dashboard pages without group assignment
- **Benefit**: Persistent overlay that can receive continuous updates

### 4. State Machine Design
- **Decision**: Predefined AI states (idle, executing, processing, notifying, muted, disconnected)
- **Rationale**: Clear visual communication of AI assistant status
- **Implementation**: Each state has unique animations and color schemes

## Component Architecture

### Orb Component
```
.orb
├── .wrap (rotation container)
│   ├── .c (swirling shape 1)
│   ├── .c (swirling shape 2)  
│   └── .c (swirling shape 3)
├── .orb-status-effects
│   ├── .orb-status-ring (for executing state)
│   └── .orb-particles (for notifying state)
└── ::before/::after (glass effects and ripples)
```

### State Management
- Global state variables track current and underlying states
- CSS classes applied to document.body for state-based styling
- Automatic transitions between states with flash effects

### Audio Level Integration
- Real-time audio level visualization through intensity mapping
- Three-tier system (low, medium, high) for different visual effects
- CSS animations triggered by data attributes

## Node-RED Integration Patterns

### Notification Node Pattern
- Function node generates HTML payload
- Notification node displays overlay
- Raw HTML mode required for proper rendering

### Message Payload Structure
```javascript
{
  "command": "show|hide",
  "state": "idle|executing|processing|notifying|muted|disconnected",
  "status": "Custom status text",
  "theme": "dark|light",
  "level": 0.0-1.0 // Audio level
}
```

## Performance Considerations

### Animation Optimization
- CSS transforms and GPU acceleration
- Animation-play-state for pausing disconnected state
- Efficient CSS variable updates for real-time effects

### Memory Management
- Automatic cleanup of particle effects
- Proper DOM element removal on hide
- Event listener cleanup to prevent memory leaks

### Browser Compatibility
- Modern CSS features (Grid, Flexbox, Custom Properties)
- Fallbacks for older browsers where possible
- Hardware acceleration requirements noted