"""
config.py — VoxUI Voice Agent Configuration

All settings are read from environment variables with sensible defaults.
Override any value by setting the corresponding environment variable or
creating a .env file (see .env.example).

Usage:
    from config import config
    print(config.llm_url)
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
        return val.lower() in ('1', 'true', 'yes', 'on')
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


def _normalize_base_url(url: str) -> str:
    """Ensure URL ends with /v1, tolerating trailing slashes or bare host."""
    url = url.rstrip('/')
    if not url.endswith('/v1'):
        url = url + '/v1'
    return url


@dataclass
class AgentConfig:
    # ----------------------------------------------------------------
    # LiveKit server
    # ----------------------------------------------------------------
    livekit_url:        str   = field(default_factory=lambda: _env('LIVEKIT_URL',        'ws://localhost:7880'))
    livekit_api_key:    str   = field(default_factory=lambda: _env('LIVEKIT_API_KEY',    'devkey'))
    livekit_api_secret: str   = field(default_factory=lambda: _env('LIVEKIT_API_SECRET', 'devsecret'))
    livekit_room:       str   = field(default_factory=lambda: _env('LIVEKIT_ROOM',       'vox-ui-room'))

    # ----------------------------------------------------------------
    # STT: OpenAI-compatible Whisper endpoint
    # STT_URL should be the base URL without /v1 — it will be appended.
    # ----------------------------------------------------------------
    stt_url:   str = field(default_factory=lambda: _env('STT_URL',   'http://localhost:9010'))
    stt_model: str = field(default_factory=lambda: _env('STT_MODEL', 'Systran/faster-distil-whisper-small.en'))

    @property
    def stt_base_url(self) -> str:
        """STT endpoint with /v1 appended."""
        return _normalize_base_url(self.stt_url)

    # ----------------------------------------------------------------
    # TTS: OpenAI-compatible Kokoro/TTS endpoint
    # TTS_URL should be the base URL without /v1 — it will be appended.
    # ----------------------------------------------------------------
    tts_url:   str   = field(default_factory=lambda: _env('TTS_URL',   'http://localhost:8880'))
    tts_voice: str   = field(default_factory=lambda: _env('TTS_VOICE', 'af_heart'))
    tts_speed: float = field(default_factory=lambda: _env('TTS_SPEED', 1.0))

    @property
    def tts_base_url(self) -> str:
        """TTS endpoint with /v1 appended."""
        return _normalize_base_url(self.tts_url)

    # ----------------------------------------------------------------
    # LLM: Any OpenAI-compatible endpoint
    #
    # LLM_PROVIDER controls which preset URL to use:
    #   'openai'  — Use LLM_BASE_URL directly (Hermes, vLLM, any custom)
    #   'ollama'  — Use Ollama at localhost:11433
    #   'letta'   — Use Letta at localhost:8283 (legacy, requires TOOLS_ENABLED)
    #
    # Set LLM_BASE_URL to override the URL for any provider.
    # The /v1 suffix is added automatically if missing.
    # ----------------------------------------------------------------
    llm_provider:              str   = field(default_factory=lambda: _env('LLM_PROVIDER',              'openai'))
    llm_base_url:              str   = field(default_factory=lambda: _env('LLM_BASE_URL',              'http://localhost:8642'))
    llm_model:                 str   = field(default_factory=lambda: _env('LLM_MODEL',                 'qwen3-30b-a3b-instruct'))
    llm_api_key:               str   = field(default_factory=lambda: _env('LLM_API_KEY',               'dummy'))
    llm_temperature:           float = field(default_factory=lambda: _env('LLM_TEMPERATURE',           0.3))
    llm_max_completion_tokens: int   = field(default_factory=lambda: _env('LLM_MAX_COMPLETION_TOKENS', 512))
    # Inject {"think": false} into LLM requests (Qwen3 / Nemotron thinking suppression)
    llm_disable_thinking:      bool  = field(default_factory=lambda: _env('LLM_DISABLE_THINKING',      True))

    # Legacy Letta fields (only used when LLM_PROVIDER=letta)
    letta_agent_id:        str = field(default_factory=lambda: _env('LETTA_AGENT_ID',        ''))
    letta_conversation_id: str = field(default_factory=lambda: _env('LETTA_CONVERSATION_ID', ''))

    @property
    def llm_url(self) -> str:
        """Return the LLM endpoint base URL (with /v1) based on provider."""
        if self.llm_provider == 'letta':
            return 'http://localhost:8283/v1'
        elif self.llm_provider == 'ollama':
            return _normalize_base_url(_env('LLM_BASE_URL', 'http://localhost:11433'))
        else:
            # 'openai' or any custom provider — use LLM_BASE_URL directly
            return _normalize_base_url(self.llm_base_url)

    @property
    def llm_model_id(self) -> str:
        """Return the model identifier for the LLM request."""
        if self.llm_provider == 'letta':
            return self.letta_agent_id
        return self.llm_model

    # ----------------------------------------------------------------
    # RV backend (disabled for VoxUI — no device control)
    # ----------------------------------------------------------------
    backend_enabled: bool = field(default_factory=lambda: _env('BACKEND_ENABLED', False))
    backend_host:    str  = field(default_factory=lambda: _env('BACKEND_HOST',    'localhost'))
    backend_port:    int  = field(default_factory=lambda: _env('BACKEND_PORT',    9001))
    backend_connect_timeout: float = field(default_factory=lambda: _env('BACKEND_CONNECT_TIMEOUT', 10.0))
    backend_min_backoff:     float = field(default_factory=lambda: _env('BACKEND_MIN_BACKOFF', 0.5))
    backend_max_backoff:     float = field(default_factory=lambda: _env('BACKEND_MAX_BACKOFF', 60.0))

    # ----------------------------------------------------------------
    # Tool calling (disabled for VoxUI — voice only)
    # ----------------------------------------------------------------
    tools_enabled: bool = field(default_factory=lambda: _env('TOOLS_ENABLED', False))
    mcp_enabled:   bool = field(default_factory=lambda: _env('MCP_ENABLED',   False))
    mcp_port:      int  = field(default_factory=lambda: _env('MCP_PORT',      8284))
    skip_greeting: bool = field(default_factory=lambda: _env('SKIP_GREETING', False))

    # ----------------------------------------------------------------
    # Token service
    # ----------------------------------------------------------------
    token_service_port: int = field(default_factory=lambda: _env('TOKEN_SERVICE_PORT', 7882))

    # ----------------------------------------------------------------
    # Logging
    # ----------------------------------------------------------------
    log_level: str = field(default_factory=lambda: _env('LOG_LEVEL', 'INFO'))


# Singleton — import and use directly:
config = AgentConfig()


if __name__ == '__main__':
    # Quick sanity check: print all config values
    import dataclasses
    for f in dataclasses.fields(config):
        print(f'  {f.name}: {getattr(config, f.name)!r}')
    print()
    print('Computed properties:')
    print(f'  llm_url:      {config.llm_url!r}')
    print(f'  llm_model_id: {config.llm_model_id!r}')
    print(f'  stt_base_url: {config.stt_base_url!r}')
    print(f'  tts_base_url: {config.tts_base_url!r}')
