# Product Context

## Purpose
A web-based interface for interacting with an AI assistant, featuring:
- Voice and text chat capabilities
- Visual feedback through an orb visualization
- Configurable settings for integrations
- Theme customization options

## Core Features

### Chat Interface
- Text-based chat interaction
- Voice input/output capability
- Visual orb feedback
- Real-time response indicators

### Settings Management
- Theme customization (Light/Dark/System)
- Integration configurations
  - n8n webhook setup
  - UltraVOX API connection
- Persistent settings storage

### Visual Elements
- Interactive orb visualization
- Responsive layout
- Smooth transitions
- Accessibility considerations

## User Experience Goals
1. Intuitive navigation
2. Clear visual feedback
3. Seamless theme switching
4. Easy configuration
5. Mobile-friendly interface
6. Accessible to all users

## Integration Points
- Python backend for audio processing and routing
- WebSocket connections for real-time audio streaming
- UltraVOX for speech-to-text and response generation
- Kokoro TTS for text-to-speech conversion
- Local storage for settings
- System theme detection

## Current Focus
- Implementing Python backend with WebSocket support
- Integrating UltraVox SDK for voice processing
- Setting up Kokoro TTS for audio generation
- Creating bidirectional audio streaming
- Handling connection management and error cases
