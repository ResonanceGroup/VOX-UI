# Active Context - Voice Interface for RooCode Plugin

## Current Status (November 7, 2025 - 1:41 AM)

### What We're Working On
Expanding the LiveKit offline voice agent into a **voice interface for controlling the RooCode Agentic coding plugin**. The goal is to create a voice-controlled bridge that allows the user to interact with RooCode through natural speech.

### Project Evolution
The base LiveKit voice agent (v1.2.15) is now the foundation for a new voice interface that will:
- Listen to voice commands from the user
- Translate them into RooCode plugin actions via IPC socket communication
- Provide voice feedback on plugin responses
- Act as an intelligent go-between for hands-free coding assistance

### ✅ COMPLETED: Research & Planning Phase

**Major Discovery**: Two viable approaches for voice-controlled RooCode:

**Option A: Direct LiveKit Integration (Current Path)**
- Python wrapper for RooCode APIs
- LiveKit function tools for voice control
- HTTP server approach for local communication

**Option B: MCP Server Approach (Recommended for Community)**
- VSCode extension providing MCP server
- Standardized MCP protocol
- Works with any MCP-compatible client
- Valuable contribution to MCP/RooCode communities

**Created Detailed Implementation Plan**: `cline_docs/mcp-server-prompt.md`
- Complete technical specification
- Step-by-step implementation guide
- Ready for fresh workspace execution

### Next Steps: Choose Implementation Path

**Available Options:**
1. **Continue Current LiveKit Integration** - Complete the Python wrapper approach
2. **Switch to MCP Server** - Start new workspace with MCP server implementation
3. **Hybrid Approach** - Implement both for maximum flexibility

Ready to proceed with either approach based on your preference!

### Technical Foundation
The existing voice agent infrastructure provides:
- ✅ **STT**: speaches Docker container (faster-whisper via OpenAI-compatible API)
- ✅ **LLM**: Ollama (via OpenAI-compatible API)
- ✅ **TTS**: Kokoro (via OpenAI-compatible API)
- ✅ **VAD**: Silero for voice activity detection
- ✅ **Agent Framework**: LiveKit Agents v1.2.15 with function tools

### Next Steps: Research & Discovery

**Critical Research Tasks:**
1. **RooCode Plugin Investigation**
   - Find RooCode plugin repository and documentation
   - Understand plugin architecture and capabilities
   - Identify all available features and commands

2. **RooCode IPC Socket Analysis**
   - Research Windows IPC pipes/sockets implementation
   - Document IPC protocol and message formats
   - Find existing Python examples or libraries
   - Map all available RPC functions

3. **Integration Planning**
   - Design wrapper class architecture
   - Plan tool integration with LiveKit function system
   - Design callback mechanism for real-time communication

### Historical Context (October 2025)
The original LiveKit agent modernization was completed with:
- ✅ Upgraded from v0.12.21 to v1.2.15
- ✅ All services running (Ollama, Kokoro, speaches)
- ❌ Whisper model download issue (may need resolution for voice interface)

**Previous Blocker (Resolved):**
The speaches Docker container needed the Whisper model downloaded:
- ✅ Container running: `ghcr.io/speaches-ai/speaches:latest-cpu`
- ✅ Started with proper configuration
- ❌ Model needed download via `POST /v1/models` (API format unclear)
- ❌ Tried `uvx speaches-cli` commands (uvx not available)
- ❌ Tried various API endpoints (got 404 errors)

### What's Working
- ✅ Code modernized to LiveKit Agents v1.2.15
- ✅ All three services accessible on their ports:
  - speaches (STT): http://localhost:8000 (but model not downloaded)
  - Ollama (LLM): http://localhost:11434 (working)
  - Kokoro TTS: http://localhost:8880 (working)
- ✅ [`src/app.py`](../src/app.py) - 86 lines, uses modern Agent/AgentSession pattern
- ✅ [`.env`](../.env) - Updated with correct model: `WHISPER_MODEL=Systran/faster-whisper-large-v3`
- ✅ `load_dotenv(override=True)` added to force env var override

### What Needs to Happen Next

**CRITICAL NEXT STEP:** Download the Whisper model into the speaches container.

**Options to Try:**

1. **Check speaches API documentation** - Need to find the correct API endpoint and payload format for downloading models
   - The error says `POST /v1/models` but we need the exact request format
   - Search speaches documentation at https://speaches.ai or GitHub

2. **Alternative: Use Python to download inside container:**
   ```bash
   docker exec -it 53ac734cf091 python -m pip install uvx
   docker exec -it 53ac734cf091 uvx speaches-cli model download Systran/faster-whisper-large-v3
   ```

3. **Alternative: Restart container with auto-download on first use**
   - The documentation mentions models download "on first use"
   - But we're getting 404 errors, so something is wrong

4. **Alternative: Try a smaller model that might already be included:**
   - Change `WHISPER_MODEL` to `tiny.en` or `base.en`
   - These smaller models might work immediately

### Recent Changes

**Files Modified:**
1. [`src/app.py`](../src/app.py) - Complete rewrite (86 lines)
   - Changed from old `VoiceAssistant` to `Agent` + `AgentSession`
   - Uses `openai.STT()`, `openai.LLM()`, `openai.TTS()` with custom base URLs
   - Added `load_dotenv(override=True)` to force env var override
   - Uses `silero.VAD.load()` for voice activity detection
   - Added `@function_tool` example

2. [`.env`](../.env) - Updated configuration
   ```
   WHISPER_BASE_URL=http://127.0.0.1:8000/v1
   WHISPER_API_KEY=not-needed
   WHISPER_MODEL=Systran/faster-whisper-large-v3
   ```

3. [`src/README.md`](../src/README.md) - Updated with speaches setup

**Files Deleted:**
- `src/stt.py` - No longer needed (using openai.STT instead of custom plugin)

### Key Technical Details

**speaches Container:**
- Image: `ghcr.io/speaches-ai/speaches:latest-cpu`
- Port: 8000
- Volume: `hf-hub-cache:/home/ubuntu/.cache/huggingface/hub`
- Environment: `WHISPER__MODEL=Systran/faster-whisper-large-v3`
- Container ID: `53ac734cf091`
- Status: Running but model not downloaded

**Agent Configuration:**
```python
session = AgentSession(
    vad=silero.VAD.load(),
    stt=openai.STT(
        base_url="http://127.0.0.1:8000/v1",
        api_key="not-needed", 
        model="Systran/faster-whisper-large-v3"
    ),
    llm=openai.LLM(
        base_url="http://127.0.0.1:11434/v1",
        api_key="ollama",
        model="qwen2:1.5b"  # or qwen3:4b
    ),
    tts=openai.TTS(
        base_url="http://127.0.0.1:8880/v1",
        api_key="local",
        voice="af_heart"
    ),
)
```

### Important URLs

- **speaches GitHub**: https://github.com/speaches-ai/speaches
- **speaches Docs**: https://speaches.ai/
- **STT Docs**: https://speaches.ai/usage/text-to-speech/
- **Container Registry**: ghcr.io/speaches-ai/speaches

### Commands to Remember

**Check if container is running:**
```powershell
docker ps
```

**View container logs:**
```powershell
docker logs 53ac734cf091
```

**Access container shell:**
```powershell
docker exec -it 53ac734cf091 bash
```

**Test speaches endpoint:**
```powershell
curl http://localhost:8000/v1/models
```

**Run the agent:**
```powershell
python src/app.py console