import requests
import websockets
import asyncio
import json
import sounddevice as sd
import numpy as np
import queue
import threading

SAMPLE_RATE = 16000
CHUNK_SIZE = 512  # Silero VAD expects 512 samples at 16kHz
CHANNELS = 1

def create_call():
    url = "http://localhost:7860/api/calls"
    payload = {
        "systemPrompt": "Test connection",
        "temperature": 0.8,
        "voice": "Bella (US Female)",
        "medium": {
            "serverWebSocket": {
                "inputSampleRate": SAMPLE_RATE,
                "outputSampleRate": SAMPLE_RATE,
                "clientBufferSizeMs": 30000
            }
        },
        "selectedTools": [],
        "firstSpeaker": "FIRST_SPEAKER_AGENT",
        "initialOutputMedium": "MESSAGE_MEDIUM_SPEECH"
    }
    resp = requests.post(url, json=payload)
    print("POST /api/calls response:", resp.status_code, resp.text)
    resp.raise_for_status()
    data = resp.json()
    return data["callId"], data["joinUrl"]

async def stream_audio(ws, audio_q, stop_event):
    """Send audio chunks from the queue to the websocket in real time."""
    while not stop_event.is_set() or not audio_q.empty():
        try:
            chunk = audio_q.get(timeout=0.1)
            await ws.send(chunk)
        except queue.Empty:
            await asyncio.sleep(0.01)

def play_audio_stream(audio_q, stop_event):
    """Play audio chunks from the queue in real time using sounddevice."""
    def callback(outdata, frames, time, status):
        try:
            chunk = audio_q.get_nowait()
            audio_np = np.frombuffer(chunk, dtype=np.int16)
            # Ensure chunk is exactly frames in length
            if len(audio_np) < frames:
                outdata[:len(audio_np)] = audio_np.reshape(-1, 1)
                outdata[len(audio_np):] = 0
            else:
                outdata[:] = audio_np[:frames].reshape(-1, 1)
        except queue.Empty:
            outdata.fill(0)
    with sd.OutputStream(samplerate=SAMPLE_RATE, channels=CHANNELS, dtype='int16', blocksize=CHUNK_SIZE, callback=callback):
        while not stop_event.is_set() or not audio_q.empty():
            sd.sleep(10)

class MicChunker:
    """Buffers incoming audio and yields 512-sample chunks."""
    def __init__(self, chunk_size):
        self.chunk_size = chunk_size
        self.buffer = np.zeros((0,), dtype=np.int16)
    def add(self, data):
        self.buffer = np.concatenate([self.buffer, data])
        chunks = []
        while len(self.buffer) >= self.chunk_size:
            chunks.append(self.buffer[:self.chunk_size])
            self.buffer = self.buffer[self.chunk_size:]
        return chunks

async def test_websocket(join_url):
    print(f"Connecting to websocket: {join_url}")
    async with websockets.connect(join_url) as ws:
        # Receive initial state and greeting
        for _ in range(2):
            msg = await ws.recv()
            print("Received:", msg)

        # Set up queues and stop events for audio streaming
        mic_q = queue.Queue()
        ai_q = queue.Queue()
        stop_mic = threading.Event()
        stop_ai = threading.Event()

        # Start playback thread for AI audio
        playback_thread = threading.Thread(target=play_audio_stream, args=(ai_q, stop_ai), daemon=True)
        playback_thread.start()

        # Start audio streaming coroutine
        audio_stream_task = asyncio.create_task(stream_audio(ws, mic_q, stop_mic))

        # Start microphone stream in a separate thread
        chunker = MicChunker(CHUNK_SIZE)
        def audio_callback(indata, frames, time, status):
            if status:
                print(status)
            flat = indata.flatten()
            for chunk in chunker.add(flat):
                mic_q.put(chunk.astype(np.int16).tobytes())

        with sd.InputStream(samplerate=SAMPLE_RATE, channels=CHANNELS, dtype='int16', callback=audio_callback):
            print("Speak into the mic (Ctrl+C to stop)...")
            try:
                while True:
                    msg = await ws.recv()
                    if isinstance(msg, bytes):
                        ai_q.put(msg)
                    else:
                        print("Received:", msg)
            except KeyboardInterrupt:
                print("Stopping streaming...")
            finally:
                stop_mic.set()
                stop_ai.set()
                await audio_stream_task
                playback_thread.join()

if __name__ == "__main__":
    call_id, join_url = create_call()
    asyncio.run(test_websocket(join_url))