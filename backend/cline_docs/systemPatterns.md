# System Patterns - LiveKit Offline Agent

## Architecture Overview

The system is a **fully offline voice agent** that:
1. Listens to microphone input
2. Detects speech using Voice Activity Detection (VAD)
3. Transcribes speech to text (STT)
4. Generates responses using Large Language Model (LLM)
5. Synthesizes speech from text (TTS)
6. Plays audio back to user

**Key Design Decision:** Use LiveKit's built-in `openai` plugin for ALL services (STT, LLM, TTS) by pointing to local OpenAI-compatible endpoints. This eliminates the need for custom plugins entirely.

## Core Pattern: Agent + AgentSession

### Modern LiveKit Agents v1.2.15 Pattern

```python
from livekit.agents import Agent, AgentSession, function_tool
from livekit.plugins import openai, silero

# 1. Define agent entry point
agent = Agent()

@agent.on("agent_started")
async def on_agent_started(session: AgentSession):
    # 2. Configure session with all components
    session.set_config(
        vad=silero.VAD.load(),
        stt=openai.STT(...),
        llm=openai.LLM(...),
        tts=openai.TTS(...),
    )
    
    # 3. Optional: Update context
    await session.say("Hello!", allow_interruptions=True)

# 4. Run with built-in CLI
if __name__ == "__main__":
    from livekit import agents
    agents.cli.run_app(agent)
```

**Key Components:**
- **Agent**: Entry point, handles lifecycle events
- **AgentSession**: Manages conversation state, coordinates VAD/STT/LLM/TTS
- **VAD**: Voice Activity Detection (Silero)
- **STT**: Speech-to-Text (OpenAI plugin → speaches)
- **LLM**: Large Language Model (OpenAI plugin → Ollama)
- **TTS**: Text-to-Speech (OpenAI plugin → Kokoro)

### Old Pattern (v0.12.21) - DEPRECATED

```python
# DON'T USE THIS - OLD API
from livekit.agents import VoiceAssistant
assistant = VoiceAssistant(...)
```

The old `VoiceAssistant` class is completely gone in v1.0+. It's been replaced by the Agent + AgentSession pattern.

## Service Integration Pattern

### The OpenAI Plugin Flexibility

**Discovery:** Many local AI services implement OpenAI-compatible APIs. We can use LiveKit's built-in `openai` plugin by just changing the `base_url` parameter.

```python
from livekit.plugins import openai

# STT: Point to speaches (faster-whisper)
stt = openai.STT(
    base_url="http://127.0.0.1:8000/v1",  # speaches endpoint
    api_key="not-needed",                  # speaches doesn't check
    model="Systran/faster-whisper-large-v3"
)

# LLM: Point to Ollama
llm = openai.LLM(
    base_url="http://127.0.0.1:11434/v1",  # Ollama endpoint
    api_key="ollama",                       # Ollama requires any non-empty key
    model="qwen2:1.5b"
)

# TTS: Point to Kokoro
tts = openai.TTS(
    base_url="http://127.0.0.1:8880/v1",   # Kokoro endpoint
    api_key="local",                        # Kokoro requires any non-empty key
    voice="af_heart"
)
```

**Why This Works:**
- speaches exposes `/v1/audio/transcriptions` (OpenAI Whisper API)
- Ollama exposes `/v1/chat/completions` (OpenAI Chat API)
- Kokoro exposes `/v1/audio/speech` (OpenAI TTS API)

**Benefits:**
- ✅ No custom plugin code needed
- ✅ Follows OpenAI API standards
- ✅ Easy to swap services (just change base_url)
- ✅ Well-tested plugin code (from LiveKit)

## Tool System Pattern

### Function Tools

Tools are Python functions decorated with `@function_tool`:

```python
from livekit.agents import function_tool

@function_tool
def get_weather(location: str) -> dict:
    """Get the current weather for a location.
    
    Args:
        location: The city and state, e.g., 'San Francisco, CA'
        
    Returns:
        dict: Weather information
    """
    # Implementation here
    return {"temp": "72°F", "condition": "sunny"}
```

**Key Points:**
- The docstring becomes the tool description (LLM sees this)
- Type hints define the tool schema
- Return value is sent back to LLM
- Tools are automatically discovered and registered

### Passing Tools to AgentSession

```python
session = AgentSession(
    vad=...,
    stt=...,
    llm=...,
    tts=...,
    # Tools are automatically discovered if defined in same module
)
```

LiveKit automatically finds all `@function_tool` decorated functions in your code.

## VAD Pattern

**Voice Activity Detection (VAD)** determines when the user is speaking:

```python
from livekit.plugins import silero

vad = silero.VAD.load()
```

**How It Works:**
1. Continuously analyzes audio input
2. Detects when speech starts
3. Buffers audio while speech continues
4. Detects when speech ends
5. Sends buffered audio to STT

**Performance Note:** Silero VAD can show "slower than realtime" warnings on low-end hardware. This is normal and doesn't break functionality.

## Configuration Pattern

### Environment Variables

Use `.env` file with `python-dotenv`:

```python
from dotenv import load_dotenv
import os

# CRITICAL: Use override=True to replace cached env vars
load_dotenv(override=True)

# Then access with os.getenv()
whisper_url = os.getenv("WHISPER_BASE_URL", "http://127.0.0.1:8000/v1")
```

**Common Pitfall:** Without `override=True`, Python won't replace environment variables that are already set in the shell/IDE. This causes "ghost values" where code updates don't take effect.

### Service Defaults

```python
# Always provide sensible defaults
base_url=os.getenv("SERVICE_URL", "http://localhost:8000/v1")
model=os.getenv("MODEL", "default-model-name")
```

## CLI Pattern

### Built-in CLI Commands

LiveKit Agents provides three built-in commands:

1. **console** - Interactive console mode (best for development)
   ```bash
   python src/app.py console
   ```

2. **dev** - Development server (connects to LiveKit server)
   ```bash
   python src/app.py dev
   ```

3. **start** - Production server
   ```bash
   python src/app.py start
   ```

**Usage:**
```python
if __name__ == "__main__":
    from livekit import agents
    agents.cli.run_app(agent)  # This enables all three commands
```

No need to implement CLI yourself - it's built into the framework.

## Error Handling Pattern

### Service Connection Errors

The framework automatically retries failed requests:

```
2025-10-26 22:15:06,173 - WARNING livekit.agents - failed to recognize speech, retrying in 0.1s
2025-10-26 22:15:06,533 - WARNING livekit.agents - failed to recognize speech, retrying in 2.0s
2025-10-26 22:15:08,917 - WARNING livekit.agents - failed to recognize speech, retrying in 2.0s
```

After 4 attempts, it raises `APIConnectionError` and closes the session.

### Session Lifecycle

```python
@agent.on("agent_started")
async def on_agent_started(session: AgentSession):
    # Session starts
    session.set_config(...)
    
    # Session runs until:
    # 1. User quits
    # 2. Unrecoverable error
    # 3. Connection lost
```

## File Organization Pattern

### Single File Implementation

For simple agents, everything goes in `src/app.py`:

```
src/
├── app.py          # Main agent code (entry point)
└── README.md       # Setup documentation
```

**Advantages:**
- Easy to understand
- No import complexity
- Fast iteration
- Clear entry point

### Multi-File Pattern (for complex agents)

```
src/
├── app.py          # Agent entry point
├── tools.py        # Function tools
├── config.py       # Configuration
└── README.md
```

## Docker Pattern (for Services)

### speaches (STT Service)

```bash
# Pull image
docker pull ghcr.io/speaches-ai/speaches:latest-cpu

# Run container
docker run \
  -p 8000:8000 \
  --volume hf-hub-cache:/home/ubuntu/.cache/huggingface/hub \
  --env WHISPER__MODEL=Systran/faster-whisper-large-v3 \
  --detach \
  ghcr.io/speaches-ai/speaches:latest-cpu
```

**Key Points:**
- Volume mount preserves downloaded models
- `WHISPER__MODEL` env var sets default model
- Model must be downloaded separately (not automatic on startup)
- OpenAI-compatible API on `/v1/audio/transcriptions`

### Checking Service Health

```bash
# List running containers
docker ps

# View logs
docker logs <container-id>

# Test endpoint
curl http://localhost:8000/v1/models
```

## Debugging Pattern

### Enable Debug Logging

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Common Issues

1. **"Model not installed"** → Model needs to be downloaded first
2. **"inference is slower than realtime"** → VAD warning, can ignore
3. **Connection refused** → Service not running
4. **404 errors** → Wrong endpoint or model name

## Key Takeaways

1. **No custom plugins needed** - Use `openai` plugin for everything
2. **Agent + AgentSession** - Modern pattern, replaces old `VoiceAssistant`
3. **OpenAI-compatible APIs** - Let you use local services with standard plugins
4. **Built-in CLI** - Framework provides console/dev/start commands
5. **Environment variables** - Use `load_dotenv(override=True)`
6. **Function tools** - Simple `@function_tool` decorator
7. **Single file is fine** - For simple agents, one file is enough