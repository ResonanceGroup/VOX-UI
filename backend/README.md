# LiveKit Offline Voice Agent

A simple, educational example of a fully offline voice agent using LiveKit Agents 1.0 (October 2025).

## What This Is

This is the **simplest possible** LiveKit voice agent that runs completely offline using:
- **Faster-Whisper** for speech-to-text (custom plugin)
- **Ollama** for LLM (via OpenAI-compatible API)
- **Kokoro** for text-to-speech (via OpenAI-compatible API)
- **Silero VAD** for voice activity detection

## Architecture

```
src/
├── app.py    # Main agent (81 lines)
└── stt.py    # Custom Faster-Whisper STT plugin (127 lines)
```

That's it! Just 2 files, ~200 lines total.

## Prerequisites

You need these services running locally:

1. **Ollama** at `http://localhost:11434`
   ```bash
   ollama serve
   ollama pull qwen2:1.5b  # or your preferred model
   ```

2. **Kokoro TTS** at `http://localhost:8880`
   - Follow Kokoro installation instructions

3. **LiveKit Server** (for dev mode)
   ```bash
   # Install LiveKit CLI
   brew install livekit  # or download from livekit.io
   
   # Run local server
   livekit-server --dev
   ```

## Installation

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Configuration

Edit `.env` file:
```env
OLLAMA_BASE_URL=http://127.0.0.1:11434/v1
OLLAMA_API_KEY=ollama
LLM_MODEL=qwen2:1.5b

KOKORO_BASE_URL=http://127.0.0.1:8880/v1
KOKORO_API_KEY=local
KOKORO_VOICE=af_heart

WHISPER_MODEL=base.en
WHISPER_DEVICE=cpu
```

## Usage

```bash
# Development mode (with web playground)
python src/app.py dev

# Then open the URL shown in your browser and join the room
```

## What It Does

1. Connects to LiveKit room
2. Uses Silero VAD to detect when you're speaking
3. Transcribes your speech with Faster-Whisper
4. Sends transcript to Ollama for response
5. Converts response to speech with Kokoro
6. Plays audio back to you

## Learning LiveKit Agents

This is intentionally minimal to help you understand the framework:

- **Agent**: Your AI's personality and instructions
- **AgentSession**: Coordinates STT → LLM → TTS pipeline
- **Tools**: Functions the agent can call (example included)
- **Built-in CLI**: Handles all the complexity

## Adding Tools

```python
@function_tool
async def my_tool(context: RunContext, arg: str):
    """Tool description for the LLM"""
    return {"result": "value"}

# Then add to agent:
agent = Agent(
    instructions="...",
    tools=[my_tool],
)
```

## Next Steps

- Read `src/app.py` - it's well-commented
- Read `src/stt.py` to understand custom plugins
- Experiment with different models in `.env`
- Add more tools using `@function_tool`

## Why This Approach?

1. **Simple**: Only 2 files, easy to understand
2. **Educational**: Clear examples of LiveKit 1.0 patterns
3. **Offline**: Everything runs locally
4. **Extensible**: Easy to add features

## Troubleshooting

**"Module not found"**: Make sure you installed livekit-agents 1.0+
```bash
pip install --upgrade livekit-agents
```

**"Connection failed"**: Make sure LiveKit server is running
```bash
livekit-server --dev
```

**Ollama errors**: Make sure Ollama is running and model is pulled
```bash
ollama serve
ollama list  # check if your model is available
```

## License

MIT - Do whatever you want with this