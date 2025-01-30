#!/usr/bin/env python3
import os
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import logging
from .websocket import WebSocketManager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Get UltraVox API key from environment
ULTRAVOX_API_KEY = os.getenv("ULTRAVOX_API_KEY")
if not ULTRAVOX_API_KEY:
    raise ValueError("ULTRAVOX_API_KEY environment variable is required")

# Initialize WebSocket manager
manager = WebSocketManager(ULTRAVOX_API_KEY)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Receive audio data
            data = await websocket.receive_bytes()
            
            # Process the message
            await manager.process_message(websocket, data)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"Error in WebSocket connection: {str(e)}")
        manager.disconnect(websocket)

@app.get("/voices")
async def list_voices():
    """Get list of available TTS voices."""
    return {"voices": manager.list_voices()}

@app.post("/voice/{voice_name}")
async def change_voice(voice_name: str):
    """Change the TTS voice."""
    success = manager.change_voice(voice_name)
    if success:
        return {"status": "success", "message": f"Changed voice to {voice_name}"}
    return {"status": "error", "message": "Failed to change voice"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=8000, 
        ssl_keyfile="../cert/key.pem", 
        ssl_certfile="../cert/cert.pem"
    )
