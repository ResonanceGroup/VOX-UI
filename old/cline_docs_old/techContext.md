# Technical Context

## Development Stack

### Frontend
- HTML5 for structure
- CSS3 for styling
  - Custom properties for theming
  - Flexbox and Grid for layouts
  - Media queries for responsiveness
- Vanilla JavaScript for functionality
  - ES6+ features
  - WebSocket API for audio streaming
  - Local storage API
  - Event handling

### Backend
- Python for server implementation
  - FastAPI/websockets for WebSocket server
  - UltraVox Python SDK for voice processing
  - Kokoro TTS for speech synthesis
  - JSON for structured responses
  - GPU acceleration support

### Infrastructure
- RunPod instance hosting
  - NVIDIA RTX 3090 GPU
  - CUDA and cuDNN support
  - SSH access via RSA key
  - Command: `ssh gana4hxiljs2mn-64410b18@ssh.runpod.io -i ~/.ssh/id_ed25519`
  - API Key: rpa_6Z64QX45BBE1GW8MYDSW659GBG5X643MQKPP6DT611gr1f
  - File transfer: runpodctl utility
  - Persistence: Only /workspace directory persists between pod restarts
- GPU-accelerated processing
  - UltraVox speech-to-text
  - Kokoro TTS synthesis
  - High-throughput capabilities

## Development Environment
- VSCode as primary editor
- Python virtual environment
- Chrome DevTools for debugging
- Git for version control
- PowerShell for CLI operations

## Project Structure
```
src/                 # Frontend code
├── app.css          # Main application styles
├── app.js           # Core application logic
├── index.html       # Main chat interface
├── settings.html    # Settings page
├── orb.js          # Orb visualization
└── style.css        # Additional styles

backend/            # Python backend
├── main.py         # FastAPI application
├── websocket.py    # WebSocket handling
├── ultravox.py     # UltraVox integration
├── kokoro.py       # Kokoro TTS integration
└── requirements.txt # Python dependencies
```

## External Services
- UltraVox API for voice processing
- Kokoro TTS for speech synthesis
- WebSocket connections for streaming
- Local storage for settings persistence

## Browser Support
- Modern browsers with CSS Grid support
- CSS custom properties support required
- Flexbox support required
- Local storage API support required

## Development Practices
- Mobile-first responsive design
- Progressive enhancement
- Semantic HTML
- Accessible markup
- Performance optimization

## Current Technical Challenges
1. Theme switching performance
2. Form validation implementation
3. API integration error handling
4. Mobile responsiveness
5. Loading state management
6. Browser compatibility

## Development Setup Requirements
- Node.js for development tools
- Local development server
- Modern web browser
- Git for version control
- VSCode extensions for HTML/CSS/JS
