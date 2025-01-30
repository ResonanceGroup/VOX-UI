#!/usr/bin/env python3
import logging
from typing import Optional, Generator
import numpy as np
from kokoro_onnx import TextToSpeech, Voice

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class KokoroTTSHandler:
    def __init__(self, voice_name: str = "en_US/amy"):
        """
        Initialize Kokoro TTS handler.
        
        Args:
            voice_name: Name of the voice to use (default: "en_US/amy")
        """
        try:
            self.tts = TextToSpeech()
            self.voice = Voice(voice_name)
            logger.info(f"Initialized Kokoro TTS with voice: {voice_name}")
        except Exception as e:
            logger.error(f"Failed to initialize Kokoro TTS: {str(e)}")
            raise

    async def text_to_speech(self, text: str) -> Optional[bytes]:
        """
        Convert text to speech using Kokoro TTS.
        
        Args:
            text: Text to convert to speech
            
        Returns:
            Audio data as bytes, or None if conversion fails
        """
        try:
            # Generate audio using Kokoro TTS
            audio_data = self.tts.synthesize(text, self.voice)
            
            # Convert numpy array to bytes
            if isinstance(audio_data, np.ndarray):
                # Ensure audio is in float32 format
                audio_data = audio_data.astype(np.float32)
                
                # Convert to bytes
                return audio_data.tobytes()
            
            return None
            
        except Exception as e:
            logger.error(f"Text-to-speech error: {str(e)}")
            return None

    async def stream_text_to_speech(self, text: str) -> Generator[bytes, None, None]:
        """
        Stream text-to-speech conversion using Kokoro TTS.
        
        Args:
            text: Text to convert to speech
            
        Yields:
            Chunks of audio data as bytes
        """
        try:
            # Generate audio using Kokoro TTS with streaming
            for audio_chunk in self.tts.stream(text, self.voice):
                if isinstance(audio_chunk, np.ndarray):
                    # Ensure audio is in float32 format
                    audio_chunk = audio_chunk.astype(np.float32)
                    
                    # Convert to bytes and yield
                    yield audio_chunk.tobytes()
                    
        except Exception as e:
            logger.error(f"Streaming text-to-speech error: {str(e)}")
            return None

    def change_voice(self, voice_name: str) -> bool:
        """
        Change the TTS voice.
        
        Args:
            voice_name: Name of the voice to use
            
        Returns:
            True if voice change successful, False otherwise
        """
        try:
            self.voice = Voice(voice_name)
            logger.info(f"Changed voice to: {voice_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to change voice: {str(e)}")
            return False

    @staticmethod
    def list_available_voices() -> list[str]:
        """
        Get list of available voices.
        
        Returns:
            List of voice names
        """
        try:
            # TODO: Implement actual voice listing
            # This is a placeholder - implement using actual Kokoro voice listing
            return ["en_US/amy", "en_US/joe", "en_US/sara"]
        except Exception as e:
            logger.error(f"Failed to list voices: {str(e)}")
            return []
