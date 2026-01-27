# Technical Context - LiveKit Offline Agent

## Technologies Used

### Core Framework
- **LiveKit Agents** v1.2.15 (October 2025)
  - Modern voice agent framework
  - Provides Agent + AgentSession pattern
  - Built-in CLI (console, dev, start commands)
  - Automatic retry logic for API calls
  - OpenAI plugin system

### Python Environment
- **Python** 3.11+ (tested on 3.11)
- **pip** package manager
- **venv** for virtual environment isolation

### Service Stack

#### 1. STT (Speech-to-Text)
- **speaches** (formerly faster-whisper-server)
  - Docker container: `ghcr.io/speaches-ai/speaches:latest-cpu`
  - Port: 8000
  - API: OpenAI-compatible `/v1/audio/transcriptions`
  - Model: Systran/faster-whisper-large-v3 (when downloaded)
  - GitHub: https://github.com/speaches-ai/speaches

#### 2. LLM (Language Model)
- **Ollama** 
  - Native Windows/Mac/Linux application
  - Port: 11434
  - API: OpenAI-compatible `/v1/chat/completions`
  - Model: qwen2:1.5b (fast, low resource) or qwen3:4b
  - Download: https://ollama.com/

#### 3. TTS (Text-to-Speech)
- **Kokoro TTS**
  - OpenAI-compatible TTS service
  - Port: 8880
  - API: OpenAI-compatible `/v1/audio/speech`
  - Voice: af_heart (female, warm tone)
  - GitHub: https://github.com/remsky/Kokoro-FastAPI

#### 4. VAD (Voice Activity Detection)
- **Silero VAD**
  - Comes with LiveKit Agents
  - Package: `livekit-plugins-silero`
  - Detects when user is speaking
  - May show "slower than realtime" warnings (safe to ignore)

### Python Dependencies

```txt
livekit-agents~=1.0
livekit-plugins-silero~=1.0
livekit-plugins-openai~=1.0
python-dotenv~=1.0
```

**Note:** `~=1.0` means ">=1.0, <2.0" - we're on 1.2.15 currently.

### Container Technology
- **Docker Desktop** (Windows/Mac)
- **Docker CLI** for managing containers
- **Volume mounts** for persistent model storage

## Development Setup

### Prerequisites

1. **Python 3.11+** installed
2. **Docker Desktop** running
3. **Ollama** installed and running
4. **Kokoro TTS** installed and running
5. **Git** for version control

### Installation Steps

```bash
# 1. Clone repository
git clone <repo-url>
cd livekit-offline-agent

# 2. Create virtual environment
python -m venv venv

# 3. Activate virtual environment
# Windows:
.\venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

# 4. Install dependencies
pip install -r requirements.txt

# 5. Pull and run speaches container
docker pull ghcr.io/speaches-ai/speaches:latest-cpu
docker run -p 8000:8000 \
  --volume hf-hub-cache:/home/ubuntu/.cache/huggingface/hub \
  --env WHISPER__MODEL=Systran/faster-whisper-large-v3 \
  --detach \
  ghcr.io/speaches-ai/speaches:latest-cpu

# 6. Download Whisper model (CRITICAL STEP - CURRENTLY BLOCKED)
# Method TBD - need to research speaches API

# 7. Start Ollama and pull model
ollama pull qwen2:1.5b

# 8. Start Kokoro TTS (see their docs)

# 9. Copy .env.example to .env and configure
cp .env.example .env

# 10. Run agent
python src/app.py console
```

### Environment Configuration

Create `.env` file:

```env
# Whisper (speaches) Configuration
WHISPER_BASE_URL=http://127.0.0.1:8000/v1
WHISPER_API_KEY=not-needed
WHISPER_MODEL=Systran/faster-whisper-large-v3

# Ollama Configuration  
OLLAMA_BASE_URL=http://127.0.0.1:11434/v1
OLLAMA_API_KEY=ollama
LLM_MODEL=qwen2:1.5b

# Kokoro TTS Configuration
KOKORO_BASE_URL=http://127.0.0.1:8880/v1
KOKORO_API_KEY=local
KOKORO_VOICE=af_heart
```

**Critical:** Use `load_dotenv(override=True)` in code to prevent environment variable caching issues.

## Technical Constraints

### Hardware Requirements

**Minimum:**
- 8GB RAM
- 4-core CPU
- 10GB disk space (for models)

**Recommended:**
- 16GB RAM
- 8-core CPU  
- GPU for faster inference (optional)

### Performance Characteristics

**STT (speaches):**
- Large models (large-v3): ~1-2s latency
- Small models (base.en): <0.5s latency
- First inference slower (model loading)

**LLM (Ollama):**
- qwen2:1.5b: ~0.5s per response token
- qwen3:4b: ~1s per response token
- Token generation is sequential

**TTS (Kokoro):**
- ~0.5s latency for short phrases
- Streaming not yet implemented

**VAD (Silero):**
- Real-time processing
- May show warnings on slow hardware (safe to ignore)

### Network Requirements

**None!** Everything runs locally:
- No internet connection needed (after setup)
- No API keys required (for remote services)
- No data leaves the machine

### Known Limitations

1. **Model Download Issue** (CURRENT BLOCKER)
   - speaches container doesn't auto-download models
   - Need to manually download before first use
   - API endpoint unclear from documentation

2. **VAD Performance Warnings**
   - Silero VAD may show "slower than realtime" warnings
   - This is cosmetic - doesn't break functionality
   - More likely on slower hardware

3. **First Run Latency**
   - First STT request loads model into memory
   - Can take 5-10 seconds
   - Subsequent requests are faster

4. **Resource Usage**
   - All services running simultaneously uses ~4GB RAM
   - CPU usage spikes during inference
   - Models take up disk space

### Platform-Specific Notes

**Windows:**
- Use PowerShell for commands
- Docker Desktop must be running
- Path separators: `\` (but Python handles both)
- Virtual environment activation: `.\venv\Scripts\activate`

**Mac:**
- Use Terminal for commands
- Docker Desktop must be running
- Path separators: `/`
- Virtual environment activation: `source venv/bin/activate`

**Linux:**
- Use bash/zsh for commands
- Can use Docker or Podman
- Path separators: `/`
- Virtual environment activation: `source venv/bin/activate`

## API Specifications

### OpenAI-Compatible Endpoints

All three services implement OpenAI-compatible APIs:

**STT (speaches):**
```
POST /v1/audio/transcriptions
Content-Type: multipart/form-data

file: <audio file>
model: "Systran/faster-whisper-large-v3"
response_format: "json" | "text" | "srt" | "vtt"
```

**LLM (Ollama):**
```
POST /v1/chat/completions
Content-Type: application/json

{
  "model": "qwen2:1.5b",
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "..."}
  ]
}
```

**TTS (Kokoro):**
```
POST /v1/audio/speech
Content-Type: application/json

{
  "model": "kokoro",
  "voice": "af_heart",
  "input": "Text to speak"
}
```

### Health Check Endpoints

```bash
# Check if services are running
curl http://localhost:8000/v1/models   # speaches
curl http://localhost:11434/v1/models  # Ollama
curl http://localhost:8880/v1/models   # Kokoro (if available)
```

## Debugging Tools

### Useful Commands

```bash
# Check Docker containers
docker ps
docker logs <container-id>
docker exec -it <container-id> bash

# Check Ollama models
ollama list

# Test endpoints
curl http://localhost:8000/v1/models
curl http://localhost:11434/v1/models

# View Python logs
python src/app.py console --log-level DEBUG
```

### Common Issues

1. **Import errors**
   - Check virtual environment is activated
   - Run `pip install -r requirements.txt`

2. **Service connection refused**
   - Check service is running: `docker ps`, `ollama list`
   - Check port isn't already in use

3. **Model not found**
   - Ollama: Run `ollama pull <model-name>`
   - speaches: Model must be downloaded first (TBD)

4. **Environment variables not loading**
   - Ensure `.env` file exists
   - Use `load_dotenv(override=True)` in code
   - Restart Python process

## Version History

### October 2025 (Current)
- **LiveKit Agents**: 1.2.15
- **Python**: 3.11+
- **speaches**: latest-cpu (exact version TBD)
- **Ollama**: Latest stable
- **Kokoro**: Latest from GitHub

### April 2025 (Old/Deprecated)
- **LiveKit Agents**: 0.12.21 (pre-v1.0)
- Used old `VoiceAssistant` class
- Required custom plugins for everything
- Much more complex setup

## Migration Notes

### Breaking Changes from v0.12 to v1.0

1. **`VoiceAssistant` removed** → Use `Agent` + `AgentSession`
2. **Plugin API changed** → Most plugins now unnecessary (use OpenAI plugin)
3. **CLI changed** → Now uses `agents.cli.run_app()`
4. **Import paths changed** → `from livekit.agents import ...`
5. **Session config changed** → Use `session.set_config()` not constructor

### Why Update?

- Simpler code (500+ lines → 86 lines)
- Better maintained (v1.0 is actively developed)
- No custom plugins needed (use OpenAI plugin)
- Built-in CLI (no need to implement yourself)
- Better error handling and retry logic