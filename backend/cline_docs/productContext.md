# Product Context

## Why This Project Exists
This project implements a **fully offline voice agent** designed to run locally on Windows or Linux without requiring any cloud API calls. It addresses the need for privacy-conscious, self-contained AI assistants that can operate completely disconnected from the internet.

## What Problems It Solves
1. **Privacy Concerns**: Eliminates the need to send voice data or conversations to cloud services
2. **Network Dependency**: Works without internet connectivity once local services are running
3. **Latency Issues**: Reduces response times by processing everything locally
4. **Data Sovereignty**: Keeps all conversational data on the user's local machine
5. **Cost Control**: No per-API-call costs since everything runs locally

## How It Should Work
The system creates a complete voice-to-voice pipeline:

1. **Voice Input**: User speaks into microphone
2. **Speech Recognition**: Faster-Whisper + Silero VAD converts speech to text
3. **AI Processing**: Ollama with Gemma 3 model generates responses
4. **Speech Synthesis**: Kokoro-FastAPI converts text responses back to speech
5. **Voice Output**: Generated audio plays through speakers

### Key Features
- Complete offline operation capability
- Modular architecture for easy extension
- Tool integration support through MCP bridge
- CLI interface with commands: `/chat`, `/say`, `/listen`, `/stop`, `/quit`
- Developer-friendly structure for future GUI integration

## Target Users
- Privacy-conscious individuals
- Developers working on AI voice assistants
- Users in environments with limited or no internet connectivity
- Researchers exploring offline AI capabilities