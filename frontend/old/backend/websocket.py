#!/usr/bin/env python3
import json
import logging
from typing import Dict, Optional, Set
from fastapi import WebSocket
from .ultravox import UltraVoxHandler
from .kokoro import KokoroTTSHandler

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class WebSocketManager:
    def __init__(self, ultravox_api_key: str, kokoro_voice: str = "en_US/amy"):
        """
        Initialize WebSocket manager with UltraVox and Kokoro TTS handlers.
        
        Args:
            ultravox_api_key: API key for UltraVox
            kokoro_voice: Voice to use for Kokoro TTS
        """
        self.active_connections: Set[WebSocket] = set()
        self.ultravox = UltraVoxHandler(ultravox_api_key)
        self.kokoro = KokoroTTSHandler(kokoro_voice)
        # Simple settings store (replace with file/db as needed)
        self.settings = {
            "theme": "system",
            "active_voice_agent": "",
            "voice_agent_config": {}
        }

    async def connect(self, websocket: WebSocket):
        """
        Handle new WebSocket connection.
        
        Args:
            websocket: WebSocket connection to manage
        """
        await websocket.accept()
        self.active_connections.add(websocket)
        logger.info(f"Client connected. Total connections: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        """
        Handle WebSocket disconnection.
        
        Args:
            websocket: WebSocket connection to remove
        """
        self.active_connections.remove(websocket)
        logger.info(f"Client disconnected. Total connections: {len(self.active_connections)}")

    async def process_message(self, websocket: WebSocket, message_data: bytes) -> None:
        """
        Process incoming WebSocket messages.
        """
        try:
            # Try to decode as JSON for message type routing
            try:
                msg = json.loads(message_data)
            except Exception:
                msg = None

            if msg and isinstance(msg, dict) and "type" in msg:
                msg_type = msg["type"]
                if msg_type == "get_settings":
                    # Respond with current settings
                    await websocket.send_json({
                        "type": "settings_data",
                        "payload": {
                            "settings": self.settings
                        }
                    })
                    return
                # Add more message types here as needed

            # Fallback: Process audio with UltraVox (legacy path)
            response = await self.ultravox.process_audio(message_data)
            
            if not response or not self.ultravox.validate_response(response):
                await self.send_error(websocket, "Invalid response format from UltraVox")
                return

            if response["type"] == "audio":
                # Generate audio response using Kokoro TTS
                audio_stream = self.kokoro.stream_text_to_speech(response["content"])
                
                # Send initial response type
                await websocket.send_json({
                    "type": "audio_start",
                    "format": "float32"
                })
                
                # Stream audio chunks
                async for chunk in audio_stream:
                    await websocket.send_bytes(chunk)
                
                # Send end marker
                await websocket.send_json({
                    "type": "audio_end"
                })
                
            elif response["type"] == "tool_call":
                # Send tool call response directly
                await websocket.send_json({
                    "type": "tool_call",
                    "content": response["content"]
                })
                
        except Exception as e:
            logger.error(f"Error processing message: {str(e)}")
            await self.send_error(websocket, "Error processing your request")

    async def send_error(self, websocket: WebSocket, message: str):
        """
        Send error message to client.
        
        Args:
            websocket: WebSocket connection
            message: Error message to send
        """
        try:
            await websocket.send_json({
                "type": "error",
                "message": message
            })
        except Exception as e:
            logger.error(f"Error sending error message: {str(e)}")

    async def broadcast(self, message: str):
        """
        Broadcast message to all connected clients.
        
        Args:
            message: Message to broadcast
        """
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception as e:
                logger.error(f"Error broadcasting message: {str(e)}")
                self.disconnect(connection)

    def change_voice(self, voice_name: str) -> bool:
        """
        Change the TTS voice.
        
        Args:
            voice_name: Name of the voice to use
            
        Returns:
            True if voice change successful, False otherwise
        """
        return self.kokoro.change_voice(voice_name)

    def list_voices(self) -> list[str]:
        """
        Get list of available voices.
        
        Returns:
            List of voice names
        """
        return self.kokoro.list_available_voices()
