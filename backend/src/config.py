"""
config.py — RV Voice Agent Configuration

All settings are read from environment variables with sensible defaults.
Override any value by setting the corresponding environment variable.

Usage:
    from config import config
    print(config.backend_host)
    print(config.mcp_port)
"""

import os
from dataclasses import dataclass, field
from dotenv import load_dotenv

# Load .env file (single source of truth)
load_dotenv('.env', override=True)


def _env(name: str, default):
    """Read an env var, coercing to the type of the default value."""
    val = os.getenv(name)
    if val is None:
        return default
    if isinstance(default, bool):
        return val.lower() in ("1", "true", "yes", "on")
    if isinstance(default, int):
        try:
            return int(val)
        except ValueError:
            return default
    if isinstance(default, float):
        try:
            return float(val)
        except ValueError:
            return default
    return val


@dataclass
class AgentConfig:
    # ----------------------------------------------------------------
    # LiveKit server (running locally on Jetson)
    # ----------------------------------------------------------------
    livekit_url:    str = field(default_factory=lambda: _env("LIVEKIT_URL",    "ws://localhost:7880"))
    livekit_api_key: str = field(default_factory=lambda: _env("LIVEKIT_API_KEY", "devkey"))
    livekit_api_secret: str = field(default_factory=lambda: _env("LIVEKIT_API_SECRET", "devsecret"))

    # ----------------------------------------------------------------
    # STT: Speaches / faster-whisper (running on port 9010)
    # ----------------------------------------------------------------
    stt_url:    str = field(default_factory=lambda: _env("STT_URL",    "http://localhost:9010"))
    stt_model:  str = field(default_factory=lambda: _env("STT_MODEL",  "Systran/faster-distil-whisper-small.en"))

    # ----------------------------------------------------------------
    # TTS: Kokoro (running on port 8880)
    # ----------------------------------------------------------------
    tts_url:    str = field(default_factory=lambda: _env("TTS_URL",    "http://localhost:8880"))
    tts_voice:  str = field(default_factory=lambda: _env("TTS_VOICE",  "af_heart"))
    tts_speed:  float = field(default_factory=lambda: _env("TTS_SPEED", 1.0))

    # ----------------------------------------------------------------
    # LLM: Ollama (Phase 1) or Letta (Phase 2+)
    #
    # Switch LLM_PROVIDER to control which backend to use:
    #   "ollama" — Use Ollama at localhost:11433 (Phase 1)
    #   "letta"  — Use Letta at localhost:8283 (Phase 2+)
    # ----------------------------------------------------------------
    llm_provider:   str = field(default_factory=lambda: _env("LLM_PROVIDER", "ollama"))
    ollama_model:   str = field(default_factory=lambda: _env("OLLAMA_MODEL", "qwen3-30b-a1.5b-q4_k_m:latest"))
    letta_agent_id: str = field(default_factory=lambda: _env("LETTA_AGENT_ID", ""))
    letta_conversation_id: str = field(default_factory=lambda: _env("LETTA_CONVERSATION_ID", ""))
    llm_api_key:    str = field(default_factory=lambda: _env("LLM_API_KEY",    "dummy"))
    llm_temperature: float = field(default_factory=lambda: _env("LLM_TEMPERATURE", 0.1))
    llm_max_completion_tokens: int = field(default_factory=lambda: _env("LLM_MAX_COMPLETION_TOKENS", 512))
    # Set True to inject {"think": false} into every LLM request body.
    # Disables chain-of-thought thinking on models that support it (e.g. Qwen3, Nemotron).
    # Only applies when LLM_PROVIDER=ollama.
    llm_disable_thinking: bool = field(default_factory=lambda: _env("LLM_DISABLE_THINKING", False))

    @property
    def llm_url(self) -> str:
        """Return the LLM endpoint URL based on the configured provider."""
        if self.llm_provider == "letta":
            return "http://localhost:8283/v1"
        else:
            return "http://localhost:11433/v1"

    @property
    def llm_model(self) -> str:
        """Return the LLM model/agent ID based on the configured provider."""
        if self.llm_provider == "letta":
            return self.letta_agent_id
        else:
            return self.ollama_model

    # ----------------------------------------------------------------
    # Backend: RG Smart Control Backend TCP socket
    # The backend provides device state and control via TCP JSON-RPC.
    # ----------------------------------------------------------------
    backend_enabled: bool = field(default_factory=lambda: _env("BACKEND_ENABLED", True))
    backend_host:   str = field(default_factory=lambda: _env("BACKEND_HOST",   "10.0.0.2"))
    backend_port:   int = field(default_factory=lambda: _env("BACKEND_PORT",   9001))
    
    # Backend connection retry strategy (exponential backoff)
    backend_connect_timeout: float = field(default_factory=lambda: _env("BACKEND_CONNECT_TIMEOUT", 10.0))
    backend_min_backoff: float = field(default_factory=lambda: _env("BACKEND_MIN_BACKOFF", 0.5))
    backend_max_backoff: float = field(default_factory=lambda: _env("BACKEND_MAX_BACKOFF", 60.0))

    # ----------------------------------------------------------------
    # Tools: Enable/disable tool calling
    # When True, Letta agent can control RV devices via MCP.
    # ----------------------------------------------------------------
    tools_enabled:  bool = field(default_factory=lambda: _env("TOOLS_ENABLED", False))
    skip_greeting:   bool = field(default_factory=lambda: _env("SKIP_GREETING", False))

    # ----------------------------------------------------------------
    # MCP Server: Model Context Protocol for tool calling
    # 
    # The MCP server exposes RV tools (read_parameter, write_parameter, etc.)
    # to the Letta agent. Tools are defined in mcp_server.py with full
    # descriptions that Letta uses automatically - no need to duplicate
    # tool documentation in memory blocks.
    # ----------------------------------------------------------------
    mcp_enabled: bool = field(default_factory=lambda: _env("MCP_ENABLED", True))
    mcp_port: int = field(default_factory=lambda: _env("MCP_PORT", 8284))

    # ----------------------------------------------------------------
    # Logging
    # ----------------------------------------------------------------
    log_level:  str = field(default_factory=lambda: _env("LOG_LEVEL",  "INFO"))


# Singleton — import and use directly: 
config = AgentConfig()


if __name__ == "__main__":
    # Quick sanity check: print all config values
    import dataclasses
    for f in dataclasses.fields(config):
        print(f"  {f.name}: {getattr(config, f.name)!r}")
