// UltraVoxKokoroAgent.js
// Production-ready networked agent for UltraVox STT + Kokoro TTS (cloud GPU).
// Implements IVoiceAgent interface via EventEmitter.

const EventEmitter = require('events');
const axios = require('axios');
const WebSocket = require('ws');

// Placeholder: import types if using TypeScript, otherwise document types in comments.

/**
 * UltraVoxKokoroAgent
 * - Uses remote UltraVox STT and Kokoro TTS via HTTP/WebSocket APIs.
 * - All endpoints/API keys are provided via the config object.
 * - Implements all IVoiceAgent methods/events.
 */
class UltraVoxKokoroAgent extends EventEmitter {
    /**
     * @param {object} config - Configuration object with endpoints, API keys, etc.
     *   {
     *     ultravoxUrl: 'http://<gpu-server-ip>:5000/ultravox',
     *     kokoroUrl: 'http://<gpu-server-ip>:5001/kokoro',
     *     ultravoxApiKey: '...',
     *     kokoroApiKey: '...',
     *     ...other config...
     *   }
     */
    constructor(config) {
        super();
        this.config = config;
        this.audioChunks = [];
        this.initialized = false;
        this.ultravoxSocket = null;
        this.status = 'idle';
    }

    /**
     * Initializes the agent (connects to services if needed).
     */
    async initialize(config) {
        this.config = config || this.config;
        this.audioChunks = [];
        this.initialized = true;
        this.status = 'ready';
        this.emit('status_update', { status: 'ready' });
        // Optionally, test connectivity to UltraVox/Kokoro here.
        try {
            await axios.get(this.config.ultravoxUrl + '/health');
            await axios.get(this.config.kokoroUrl + '/health');
        } catch (err) {
            this.emit('error', new Error('Failed to connect to UltraVox or Kokoro: ' + err.message));
            throw err;
        }
    }

    /**
     * Shuts down the agent (cleanup).
     */
    async shutdown() {
        this.audioChunks = [];
        this.initialized = false;
        this.status = 'shutdown';
        this.emit('status_update', { status: 'shutdown' });
        if (this.ultravoxSocket) {
            this.ultravoxSocket.close();
            this.ultravoxSocket = null;
        }
    }

    /**
     * Processes a complete text message (send to Kokoro TTS).
     * Emits 'audio_response_chunk' events with TTS audio.
     */
    async processTextMessage(message) {
        if (!this.initialized) throw new Error('Agent not initialized');
        this.emit('status_update', { status: 'processing_text' });
        try {
            const response = await axios.post(
                this.config.kokoroUrl + '/tts',
                { text: message },
                {
                    headers: {
                        'Authorization': `Bearer ${this.config.kokoroApiKey || ''}`,
                        'Content-Type': 'application/json'
                    },
                    responseType: 'arraybuffer'
                }
            );
            // Emit audio as a single chunk (or split if needed)
            this.emit('audio_response_chunk', Buffer.from(response.data));
            this.emit('status_update', { status: 'idle' });
        } catch (err) {
            this.emit('error', new Error('Kokoro TTS failed: ' + err.message));
            this.emit('status_update', { status: 'error' });
        }
    }

    /**
     * Processes a chunk of audio data (buffer for UltraVox STT).
     */
    async processAudioChunk(chunk) {
        if (!this.initialized) throw new Error('Agent not initialized');
        this.audioChunks.push(chunk);
        this.emit('status_update', { status: 'receiving_audio' });
    }

    /**
     * Signals end of audio stream, sends to UltraVox STT, emits 'text_response'.
     */
    async endAudioStream() {
        if (!this.initialized) throw new Error('Agent not initialized');
        this.emit('status_update', { status: 'processing_audio' });
        const audioBuffer = Buffer.concat(this.audioChunks);
        this.audioChunks = [];
        try {
            // POST audio to UltraVox STT
            const response = await axios.post(
                this.config.ultravoxUrl + '/stt',
                audioBuffer,
                {
                    headers: {
                        'Authorization': `Bearer ${this.config.ultravoxApiKey || ''}`,
                        'Content-Type': 'audio/wav'
                    }
                }
            );
            const text = response.data && response.data.text ? response.data.text : response.data;
            this.emit('text_response', text);
            this.emit('status_update', { status: 'idle' });
        } catch (err) {
            this.emit('error', new Error('UltraVox STT failed: ' + err.message));
            this.emit('status_update', { status: 'error' });
        }
    }

    /**
     * Receives MCP tool result (for advanced workflows).
     */
    provideMcpToolResult(requestId, result) {
        // Implement as needed for your workflow.
        // For now, just log.
        console.log(`[UltraVoxKokoroAgent] MCP tool result for ${requestId}:`, result);
    }
}

module.exports = UltraVoxKokoroAgent;