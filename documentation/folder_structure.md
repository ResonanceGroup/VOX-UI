# VOX-UI Project Structure

This document provides a hierarchical map of the VOX-UI project folder structure for reference.

## Root Directory

- `.gitignore`
- `mcp_config.json`
- `package-lock.json`
- `package.json`
- `runpodctl.exe`
- `server.js`
- `settings.json`
- `VOX-UI.code-workspace`

## Main Directories

### `/backend`
- `__init__.py`
- `..zip`
- `kokoro.py`
- `main.py`
- `requirements.txt`
- `send_to_pod.ps1`
- `setup_pod.sh`
- `ultravox.py`
- `websocket.py`

### `/cert`
- `cert.pem`
- `key.pem`

### `/cline_docs`
- `activeContext.md`
- `backend_implementation_plan.md`
- `productContext.md`
- `progress.md`
- `runpod_setup.md`
- `status_indicator_design.md`
- `status_indicator_implementation_plan.md`
- `status_indicator_update_plan.md`
- `systemPatterns.md`
- `techContext.md`
- `ui_finalization_plan.md`
- `ui_protocol_alignment.md`
- `websocket_protocol.md`

#### `/cline_docs/research`
- `mcp_client_summary.md`
- `phi4_summary.md`
- `qwen_summary.md`
- `ultravox_kokoro_summary.md`

#### `/cline_docs/ultravox_docs`
- `elevenlabs_tools.md`
- `introduction.md`
- `web_quickstart_readme.md`

### `/documentation`
- `installing_ultravox.md`
- `folder_structure.md` (this file)

### `/hf_cache`
- Various model cache files and directories for:
  - `models--fixie-ai--ultravox-v0_4`
  - `models--hexgrad--Kokoro-82M`
  - `models--openai--whisper-medium`
- `/modules` directory with transformers modules

### `/Images`
- `Screenshot.png`

#### `/Images/Frontend`
- Multiple screenshots from April 2025

#### `/Images/MCP`
- Multiple screenshots from April 2025

### `/runpod`
- `gpu_server_setup.sh`
- `requirements.txt`
- `runpod.zip`
- `speech_server.py`
- `start.sh`

### `/src`
- `app.css`
- `app.css.map`
- `app.js`
- `audio-visualizer.js`
- `index.html`
- `mcp_config_editor.html`
- `mcp_config_editor.js`
- `mcp_servers.html`
- `mcp_servers.js`
- `mcp_settings.js`
- `orb_readme.md`
- `orb_styles.css`
- `orb.css`
- `orb.css.map`
- `orb.haml`
- `orb.js`
- `orb.scss`
- `script.js`
- `settings.html`
- `shared_ui.js`
- `style.css`
- `tool_config.html`

#### `/src/interfaces`
- `IVoiceAgent.ts`

#### `/src/server`
- `mcpApi.js`
- `mcpClient.js`
- `settingsApi.js`
- `webSocketHandler.js`

##### `/src/server/agents`
- `EchoAgent.js`
- `UltraVoxKokoroAgent.js`

### `/src-old`
- Legacy source files (backup of previous implementation)

### `/ultravox`
- `local_setup.ps1`
- `Recording.wav`
- `requirements.txt`
- `speech_server.py`
- `start_local.ps1`
- `start.sh`
- `test_ultravox_ws.py`

### `/ultravox_venv`
- Python virtual environment for Ultravox