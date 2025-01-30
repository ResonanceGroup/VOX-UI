# System Architecture and Design Patterns

## Backend Architecture

### Deployment Architecture
- RunPod instance hosting all backend services
- GPU acceleration for speech processing
- Secure SSH access for deployment and management
- High-throughput WebSocket server

### Resource Management
- GPU memory allocation for UltraVox and Kokoro TTS
- CUDA acceleration for speech processing
- Efficient audio stream handling
- Process monitoring and logging

### Service Organization
- UltraVox and Kokoro TTS co-located on GPU instance
- WebSocket server managing client connections
- Local service communication for minimal latency
- Error handling and recovery mechanisms

### WebSocket Communication
- Bidirectional audio streaming between frontend and backend
- JSON message format for structured communication
- Connection management and error handling
- Reconnection logic for dropped connections

### Audio Processing Pipeline
1. Frontend audio capture and streaming
2. Backend WebSocket message routing
3. UltraVox integration for speech-to-text
4. Response type determination (audio/tool_call)
5. Kokoro TTS processing for audio responses
6. Audio streaming back to frontend

### Data Flow Patterns
- Audio chunks streamed via WebSocket
- Structured JSON responses from UltraVox
- Binary audio data from Kokoro TTS
- Error and status messages for UI feedback

## Frontend Structure

### Layout Structure
- Main container with flex layout for vertical organization
- Fixed header with navigation controls
- Scrollable content area with padding management
- Absolute positioning for overlay elements

## Theme System
- CSS variables for consistent theming
- Theme-specific gradients and colors
- Dark/light mode support with system preference detection
- Theme switching with persistent storage

## Component Organization
- Settings form with sections for logical grouping
- Reusable button components with consistent styling
- Form inputs with standardized styling and behavior
- Navigation sidebar with icon + text layout

## CSS Architecture
- Base styles for reset and typography
- Component-specific styles with BEM-like naming
- Theme variables for color management
- Media queries for responsive design
- Transition effects for interactive elements

## State Management
- Local storage for theme preferences
- Form state management with input validation
- Loading and error states for async operations
- Navigation state for menu visibility

## Responsive Design
- Mobile-first approach
- Breakpoints for different screen sizes
- Flexible layouts with CSS Grid and Flexbox
- Touch-friendly interaction targets

## Technical Decisions
- CSS custom properties for theme switching
- Flexbox for layout management
- CSS Grid for form organization
- Local storage for persistence
- Event delegation for form handling

## Areas for Improvement
- Consider CSS modules for better scoping
- Implement proper form validation
- Add loading states for async operations
- Improve accessibility features
- Optimize theme transitions
- Standardize spacing system
