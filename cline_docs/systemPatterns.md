# System Patterns

## Architecture
The system will follow a client-server architecture. The front-end (VOX-UI) will be a web application built using HTML, CSS, and JavaScript. It will use the UltraVox Client SDK to handle voice processing and will communicate with n8n via webhooks for backend functionality.

## Key Technical Decisions
- Use of UltraVox for voice processing.
- Use of n8n for backend workflow automation.
- Emulation of the ElevenLabs UI design for a clean and intuitive user experience.
- Implementation of an animated element that responds to voice activity.
- Responsive design to support both desktop and mobile browsers.

## Architecture Patterns
- **Client-Server:** The front-end will act as a client, sending requests to the backend (n8n) and receiving responses.
- **API Integration:** The front-end will integrate with the UltraVox API for voice processing.
- **Webhook Integration:** The front-end will use webhooks to communicate with n8n.
