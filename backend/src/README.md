# LiveKit Offline Voice Agent

A completely local, privacy-focused voice agent using LiveKit Agents 1.2.15 (October 2025).

## Architecture

This agent uses **zero custom plugins** - all services are accessed via OpenAI-compatible APIs:

- **STT**: Faster-Whisper via [faster-whisper-server](https://github.com/fedirz/faster-whisper-server)
- **LLM**: Ollama (any model)
- **TTS**: Kokoro TTS via [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI)
- **VAD**: Silero (built-in LiveKit plugin)

## Prerequisites

### 1. Install faster-whisper-server

```bash
# Using Docker (recommended)
docker run --gpus all -p 8000:8000 -v ~/.cache/huggingface:/root/.cache/huggingface fedirz/faster-whisper-server:latest-cuda

# Or with pip
pip install faster-whisper-server
faster-whisper-server --host 0.0.0.0 --port 8000
```

### 2. Install and Run Ollama

```bash
# Download from https://ollama.com
ollama serve

# Pull a model
ollama pull qwen2:1.5b
```

### 3. Install and Run Kokoro TTS

```bash
git clone https://github.com/remsky/Kokoro-FastAPI
cd Kokoro-FastAPI
pip install -r requirements.txt
python main.py  # Runs on port 8880
```

## Installation

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install LiveKit Agents
pip install -r requirements.txt
```

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
# Faster-Whisper STT
WHISPER_BASE_URL=http://127.0.0.1:8000/v1
WHISPER_API_KEY=not-needed
WHISPER_MODEL=Systran/faster-whisper-large-v3

# Ollama LLM
OLLAMA_BASE_URL=http://127.0.0.1:11434/v1
OLLAMA_API_KEY=ollama
LLM_MODEL=qwen2:1.5b

# Kokoro TTS
KOKORO_BASE_URL=http://127.0.0.1:8880/v1
KOKORO_API_KEY=local
KOKORO_VOICE=af_heart
```

## Running

### Console Mode (for testing)
```bash
python src/app.py console
```

Press `Ctrl+B` to toggle between text/audio mode, `Q` to quit.

### Production Mode
```bash
python src/app.py start
```

### Development Mode
```bash
python src/app.py dev
```

## Code Structure

```
src/
├── app.py          # Main agent (83 lines - that's it!)
└── README.md       # This file
```

The entire agent fits in a single file because all services use OpenAI-compatible APIs!

## How It Works

1. **Audio Input** → Silero VAD detects speech
2. **Speech** → Faster-Whisper transcribes to text
3. **Text** → Ollama LLM generates response
4. **Response** → Kokoro TTS converts to speech
5. **Audio Output** → Plays to user

All processing happens locally, no cloud APIs required.

## Troubleshooting

### Check Service Status

```bash
# Test Faster-Whisper
curl http://localhost:8000/v1/models

# Test Ollama
curl http://localhost:11434/v1/models

# Test Kokoro
curl http://localhost:8880/v1/models
```

### Common Issues

**"Connection refused" errors**: Make sure all services are running (faster-whisper-server, ollama serve, kokoro).

**Slow transcription**: First run downloads the Whisper model (~3GB). Use CPU mode if no GPU available.

**Audio issues**: Check microphone permissions and that no other app is using the mic.

## Performance Tips

- **GPU**: Use CUDA for faster-whisper-server (5-10x faster)
- **Model Size**: Use `base.en` for speed, `large-v3` for accuracy
- **LLM**: Smaller models (1.5B-3B params) work great for voice

## References

- [LiveKit Agents Docs](https://docs.livekit.io/agents/)
- [faster-whisper-server](https://github.com/fedirz/faster-whisper-server)
- [Ollama](https://ollama.com)
- [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI)