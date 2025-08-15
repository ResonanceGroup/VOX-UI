# Technical Context - VOX-UI

## Technologies Used

### Core Technologies
- **HTML5**: Structure and semantic markup
- **CSS3**: Styling, animations, and visual effects
- **Vanilla JavaScript**: Client-side logic and DOM manipulation
- **Node-RED**: Flow-based programming integration

### CSS Features
- **CSS Custom Properties (--intensity)**: Dynamic styling variables
- **CSS Keyframe Animations**: Complex orbital and morphing animations
- **CSS Transitions**: Smooth state transitions
- **CSS Filters**: Glass effects, blurs, and visual enhancements
- **CSS Grid/Flexbox**: Layout and positioning
- **CSS Blend Modes**: Color mixing for visual effects

### JavaScript Features
- **ES6+ Features**: Modern JavaScript syntax
- **DOM Manipulation**: Direct element control and updates
- **Event Handling**: Click, touch, and state change events
- **Template Literals**: Dynamic HTML generation
- **JSON Payload Processing**: Message handling for Node-RED

### Node-RED Integration
- **Notification Nodes**: Global overlay display system
- **Function Nodes**: Custom JavaScript processing
- **Template Nodes**: Alternative HTML template approach
- **MQTT Integration**: Real-time message handling

## Development Setup

### Local Development
- **No Build Process**: Direct HTML/CSS/JS files
- **Local File Serving**: Can run directly from file system
- **Browser Development Tools**: Chrome DevTools for debugging
- **Node-RED Dashboard**: For Node-RED integration testing

### File Structure
```
VOX-UI/
├── index.html (Main interface)
├── styles.css (Core styling)
├── main.js (Main JavaScript logic)
├── node-red-orb-notification.js (Node-RED function implementation)
├── NODE-RED-ORB-NOTIFICATION-USAGE.md (Documentation)
├── NODE-RED-ORB-OVERLAY-USAGE.md (Documentation)
└── cline_docs/ (Documentation files)
```

## Technical Constraints

### Browser Compatibility
- **Modern Browsers Required**: CSS Grid, Custom Properties, Flexbox
- **No IE Support**: Internet Explorer not supported
- **Mobile Optimization**: Touch events and responsive design required
- **Hardware Acceleration**: GPU acceleration recommended for smooth animations

### Performance Constraints
- **Animation Frame Rate**: Target 60fps for smooth animations
- **Memory Usage**: Efficient DOM manipulation to prevent leaks
- **CPU Usage**: CSS-driven animations preferred over JavaScript
- **Network**: Minimal external dependencies for fast loading

### Node-RED Constraints
- **Payload Size**: Large HTML payloads may affect performance
- **Update Frequency**: Audio level updates should be rate-limited
- **State Management**: Proper state transitions to prevent visual glitches
- **Error Handling**: Graceful degradation for JavaScript errors

### Security Considerations
- **Content Security Policy**: Inline scripts may require CSP adjustments
- **Cross-Origin Requests**: Local file access restrictions
- **DOM Sanitization**: Raw HTML injection requires careful payload validation
- **Event Listener Management**: Prevent memory leaks from improper cleanup

### Integration Requirements
- **Node-RED Dashboard**: Must work within Node-RED dashboard environment
- **Notification System**: Requires proper notification node configuration
- **Raw HTML Support**: Notification nodes must enable raw HTML mode
- **Global Scope Access**: JavaScript must access window object for persistence

## Development Tools

### Code Editors
- **VS Code**: Primary development environment
- **Live Server**: Local development server
- **Browser DevTools**: Debugging and performance monitoring

### Testing Environments
- **Chrome/Chromium**: Primary testing browser
- **Firefox**: Secondary testing browser
- **Safari**: iOS compatibility testing
- **Mobile Browsers**: Touch interaction testing

### Debugging
- **Console Logging**: Detailed console output for debugging
- **CSS Inspector**: Real-time style inspection
- **Network Tab**: Payload and message flow monitoring
- **Performance Tab**: Animation frame rate analysis

## Deployment Considerations

### Static Deployment
- **No Server Required**: Can run from file system
- **CDN Friendly**: Static assets can be served via CDN
- **Caching**: Proper cache headers for static assets
- **Compression**: Gzip/Brotli compression recommended

### Node-RED Deployment
- **Dashboard Integration**: Must work within Node-RED dashboard context
- **Flow Persistence**: Node-RED flows must persist configuration
- **Error Recovery**: Graceful handling of Node-RED restarts
- **Performance Monitoring**: Resource usage within Node-RED environment