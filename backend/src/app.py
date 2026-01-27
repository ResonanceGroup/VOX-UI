"""
Simple LiveKit Offline Voice Agent - October 2025
Uses LiveKit Agents 1.2.15 with local Ollama, Kokoro, and Faster-Whisper
All services accessed via OpenAI-compatible APIs - NO custom plugins needed!
"""
import os
from dotenv import load_dotenv

from livekit.agents import (
    Agent,
    AgentSession,
    JobContext,
    WorkerOptions,
    cli,
    function_tool,
    RunContext,
)
from livekit.agents.voice.agent_session import SessionConnectOptions
from livekit.agents.types import APIConnectOptions
from livekit.plugins import silero, openai

from a2a_llm import A2ALLM

load_dotenv(override=True)

A2A_URL = os.getenv("A2A_URL")

# Simple example tool
@function_tool
async def get_system_info(context: RunContext):
    """Get basic system information"""
    import platform
    return {
        "platform": platform.system(),
        "python_version": platform.python_version(),
    }


async def entrypoint(ctx: JobContext):
    """Main entrypoint - connects and starts the voice agent"""
    
    # Connect to LiveKit room
    await ctx.connect()

    try:
        await ctx.room.local_participant.set_attributes({"vox.state": "idle", "vox.statusText": "Ready"})
    except Exception:
        pass
    
    # Create agent with instructions and tools
    agent = Agent(
        instructions=(
            "You are a helpful offline voice assistant. "
            "Be concise and friendly. Greet the user and wait for their response."
        ),
        # TODO: Re-enable this tool later after fixing initial greeting behavior
        # tools=[get_system_info],
        tools=[],
    )
    
    # Create session with offline services
    # ALL services use OpenAI-compatible APIs - no custom plugins!
    session = AgentSession(
        # VAD for voice activity detection
        vad=silero.VAD.load(),
        
        # Faster-Whisper STT via OpenAI-compatible server
        # Use faster-whisper-server: https://github.com/fedirz/faster-whisper-server
        stt=openai.STT(
            base_url=os.getenv("WHISPER_BASE_URL", "http://127.0.0.1:8000/v1"),
            api_key=os.getenv("WHISPER_API_KEY", "not-needed"),
            model=os.getenv("WHISPER_MODEL", "Systran/faster-whisper-large-v3"),
        ),
        # LLM: Agent Zero via A2A (preferred) or local Ollama fallback
        llm=(
            A2ALLM(
                a2a_url=A2A_URL,
                participant=ctx.room.local_participant,
                timeout_s=float(os.getenv("A2A_TIMEOUT_S", "120")),
            )
            if A2A_URL
            else openai.LLM.with_ollama(
                model=os.getenv("LLM_MODEL", "granite4:1b-h"),
                base_url=os.getenv("OLLAMA_BASE_URL", "http://127.0.0.1:11434/v1"),
            )
        ),

        # Kokoro TTS via OpenAI-compatible API
        tts=openai.TTS(
            base_url=os.getenv("KOKORO_BASE_URL", "http://127.0.0.1:8880/v1"),
            api_key=os.getenv("KOKORO_API_KEY", "local"),
            model=os.getenv("KOKORO_MODEL", "kokoro"),
            voice=os.getenv("KOKORO_VOICE", "af_heart"),
        ),
        
        # Connection options with reasonable LLM timeout and better error handling
        conn_options=SessionConnectOptions(
            llm_conn_options=APIConnectOptions(timeout=60.0),  # Reduced to 1 minute timeout
        ),
    )

    # Start the agent
    await session.start(agent=agent, room=ctx.room)
    
    # Generate initial greeting
    await session.generate_reply(
        instructions="Greet the user and let them know you're ready to help"
    )


if __name__ == "__main__":
    # Run with built-in CLI
    # Usage: python src/app.py console
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))