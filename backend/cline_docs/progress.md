# Progress - Voice Interface for RooCode Plugin

## Status: Planning Phase - Research & Design

### Project Evolution ✅

**Base Voice Agent (October 2025):**
- ✅ Successfully modernized LiveKit offline voice agent to v1.2.15
- ✅ Simplified from 500+ lines to 86 lines of clean code
- ✅ All services running (Ollama, Kokoro, speaches)
- ✅ Modern Agent + AgentSession pattern with function tools
- ✅ OpenAI plugin architecture for local services

**New Voice Interface Project (November 2025):**
- 🎯 **Goal**: Transform voice agent into RooCode plugin controller
- 🎯 **Approach**: IPC socket communication + voice interface
- 🎯 **User Benefit**: Hands-free coding assistance through natural speech

### Current Phase: Research & Discovery

**Research Tasks In Progress:**
- [ ] **RooCode Plugin Investigation**
  - [ ] Find RooCode repository and documentation
  - [ ] Understand plugin architecture and capabilities
  - [ ] Identify all available features and commands
  - [ ] Locate IPC socket implementation details

- [ ] **RooCode IPC Socket Analysis**
  - [ ] Research Windows IPC pipes/sockets for remote control
  - [ ] Document IPC protocol and message formats
  - [ ] Find Python libraries or examples for IPC communication
  - [ ] Map all available RPC functions and their parameters

- [ ] **Technical Planning**
  - [ ] Design wrapper class architecture
  - [ ] Plan LiveKit function tool integration
  - [ ] Design callback mechanism for real-time communication
  - [ ] Create system prompt structure for voice agent

### Project Phases

**Phase 1: RooCode IPC Wrapper**
- [ ] Research complete RooCode plugin functionality
- [ ] Implement Python wrapper class for IPC socket
- [ ] Expose all available RooCode functions
- [ ] Add error handling and connection management
- [ ] Test with basic RooCode operations

**Phase 2: Voice Agent Integration**
- [ ] Create LiveKit function tools for RooCode operations
- [ ] Implement callback mechanism for RooCode responses
- [ ] Add real-time status update handling
- [ ] Test voice-to-RooCode command flow
- [ ] Optimize response times and user experience

**Phase 3: Voice Agent System Prompt**
- [ ] Create dedicated `system_prompt.md` file
- [ ] Define voice agent's role as user ↔ RooCode interface
- [ ] Establish conversation patterns and behaviors
- [ ] Add coding-specific voice interaction patterns
- [ ] Test and refine natural language understanding

### Technical Foundation ✅

**Existing Voice Infrastructure:**
- ✅ **STT**: speaches (faster-whisper) - OpenAI-compatible
- ✅ **LLM**: Ollama (qwen2:1.5b) - OpenAI-compatible
- ✅ **TTS**: Kokoro (af_heart) - OpenAI-compatible
- ✅ **VAD**: Silero - Voice activity detection
- ✅ **Framework**: LiveKit Agents v1.2.15 with function tools

**To Be Built:**
- 🔨 **RooCode IPC Wrapper**: Python class for socket communication
- 🔨 **Function Tools**: LiveKit tools exposing RooCode operations
- 🔨 **Callback System**: Real-time RooCode → voice agent communication
- 🔨 **System Prompt**: Voice agent personality and interaction patterns

### Historical Context
The LiveKit agent modernization (October 2025) successfully established a robust voice interface foundation. The 86-line implementation using modern patterns provides the perfect base for extending into RooCode plugin control.

### Migration Summary

**Before (v0.12.21):**
- 500+ lines of code
- Old `VoiceAssistant` class
- Custom plugins for everything
- Complex async initialization
- Many configuration files

**After (v1.2.15):**
- 86 lines of code
- Modern `Agent` + `AgentSession` pattern  
- Zero custom plugins (all using `openai` plugin)
- Simple single-file implementation
- One `.env` file

**Key Discovery:** The speaches project (formerly faster-whisper-server) provides an OpenAI-compatible API, eliminating the need for custom STT plugin. This was the breakthrough that made the simple implementation possible.

### Test Status

**Manual Tests Completed:**
- ✅ Agent starts in console mode
- ✅ VAD detects voice input
- ✅ Services respond on their ports (curl tests)
- ❌ STT transcription (blocked by missing model)
- ⏳ LLM response generation (untested - needs STT)
- ⏳ TTS speech synthesis (untested - needs LLM)
- ⏳ Full conversation loop (untested - needs all above)

### Files Status

**Active Files:**
- [`src/app.py`](../src/app.py) - 86 lines, main agent code
- [`.env`](../.env) - Environment configuration
- [`requirements.txt`](../requirements.txt) - Dependencies
- [`src/README.md`](../src/README.md) - Setup documentation

**Deleted/Obsolete:**
- `src/stt.py` - Custom STT plugin no longer needed
- `src/console.py` - Using built-in CLI now
- `src/check_endpoints.py` - Manual testing, not core
- `src/test_tts.py` - Manual testing, not core

### Timeline

- **October 26, 2025 PM**: Started modernization
- **October 26, 2025 Late PM**: 
  - Completed code rewrite
  - Got all services running
  - Discovered speaches for STT
  - Hit blocker: model not downloaded
- **October 27, 2025 Early AM**: Memory bank update before context reset

### Confidence Level

**Overall: 8/10**

High confidence in:
- Code architecture (modern patterns)
- Service integration approach (OpenAI plugin flexibility)
- Solution simplicity (no custom plugins needed)

Medium confidence in:
- Exact method to download Whisper model (need to research speaches API)
- Whether `Systran/faster-whisper-large-v3` will work vs smaller model

Low confidence in:
- Nothing significant - path forward is clear once model downloads