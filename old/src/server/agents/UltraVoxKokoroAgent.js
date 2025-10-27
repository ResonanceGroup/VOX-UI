// UltraVoxKokoroAgent.js
// Real-time networked agent for self-hosted UltraVox + Kokoro (cloud GPU) using WebSocket.
// Implements IVoiceAgent interface via EventEmitter, strictly following the self-hosted protocol.

const EventEmitter = require('events');
const axios = require('axios');
const WebSocket = require('ws');

/**
 * UltraVoxKokoroAgent
 * - Streams 16kHz int16 PCM audio to a self-hosted UltraVox server via WebSocket.
 * - Receives text and audio responses as per the open-source protocol.
 * - Strictly implements IVoiceAgent for agentManager.js compatibility.
 * - Emits: status_update, text_response, audio_response_chunk, error.
 */
class UltraVoxKokoroAgent extends EventEmitter {
    /**
     * @param {object} config - {
     *   serverUrl: 'http://<host>:7860', // Base URL of the self-hosted server
     *   systemPrompt: 'You are a helpful assistant...',
     *   voice: 'Bella (US Female)',      // Optional, must match server's voice list
     * }
     */
    constructor(config = {}) {
        super();
        this.config = config;
        this.ws = null;
        this.audioQueue = [];
        this.audioStreaming = false;
        this.initialized = false;
        this.sessionActive = false;
        this.reconnectAttempts = 0;
        this.maxReconnects = 3;
        this.reconnectDelay = 2000;
    }

    async initialize(config) {
        this.config = config || this.config;
        this.emit('status_update', { status: 'initializing' });
        try {
            // Step 1: Create a call session to get joinUrl
            const apiUrl = (this.config.serverUrl || 'http://localhost:7860') + '/api/calls';
            const payload = {
                systemPrompt: this.config.systemPrompt || "You are a helpful assistant.",
            };
            if (this.config.voice) payload.voice = this.config.voice;
            const response = await axios.post(apiUrl, payload, {
                headers: { 'Content-Type': 'application/json' }
            });
            this.joinUrl = response.data.joinUrl;
            if (!this.joinUrl) throw new Error('No joinUrl returned from UltraVox server');
            await this._connectWebSocket();
            this.initialized = true;
            this.emit('status_update', { status: 'idle' });
        } catch (err) {
            this.emit('error', new Error('Failed to initialize UltraVoxKokoroAgent: ' + err.message));
            this.emit('status_update', { status: 'error' });
            throw err;
        }
    }

    async shutdown() {
        this.audioQueue = [];
        this.audioStreaming = false;
        this.initialized = false;
        this.sessionActive = false;
        if (this.ws) {
            this.ws.terminate();
            this.ws = null;
        }
        this.emit('status_update', { status: 'shutdown' });
    }

    async processTextMessage(message) {
        // The self-hosted protocol does NOT support text input over WebSocket.
        // If the server is extended to support it, implement here.
        this.emit('error', new Error('Text input is not supported by the self-hosted UltraVox protocol.'));
        // TODO: If server adds support for text input, send as JSON here.
    }

    async processAudioChunk(chunk) {
        if (!this.initialized || !this.sessionActive) throw new Error('Agent not initialized or session not active');
        // Queue audio for streaming
        this.audioQueue.push(chunk);
        if (!this.audioStreaming) {
            this._startAudioStreaming();
        }
    }

    async endAudioStream() {
        // No explicit end-of-stream message; just stop streaming.
        this.audioStreaming = false;
        this.emit('status_update', { status: 'processing' });
        // TODO: If server adds explicit end-of-stream, send it here.
    }

    provideMcpToolResult(requestId, result) {
        // The self-hosted protocol does NOT support MCP tool invocation.
        // This is a no-op unless the server is extended to support it.
        // TODO: If server adds support, implement here.
    }

    // --- Private methods ---

    async _connectWebSocket() {
        return new Promise((resolve, reject) => {
            this.ws = new WebSocket(this.joinUrl);
            this.ws.binaryType = 'arraybuffer';

            this.ws.on('open', () => {
                this.sessionActive = true;
                this.reconnectAttempts = 0;
                this.emit('status_update', { status: 'listening' });
                resolve();
            });

            this.ws.on('message', (data, isBinary) => {
                if (isBinary) {
                    // Audio response from agent (TTS)
                    this.emit('audio_response_chunk', Buffer.from(data));
                } else {
                    try {
                        const msg = JSON.parse(data.toString());
                        this._handleDataMessage(msg);
                    } catch (err) {
                        this.emit('error', new Error('Failed to parse data message: ' + err.message));
                    }
                }
            });

            this.ws.on('close', (code, reason) => {
                this.sessionActive = false;
                this.emit('status_update', { status: 'disconnected' });
                if (this.reconnectAttempts < this.maxReconnects) {
                    setTimeout(() => {
                        this.reconnectAttempts++;
                        this._connectWebSocket();
                    }, this.reconnectDelay);
                } else {
                    this.emit('error', new Error('WebSocket connection closed: ' + reason));
                }
            });

            this.ws.on('error', (err) => {
                this.emit('error', new Error('WebSocket error: ' + err.message));
            });
        });
    }

    _startAudioStreaming() {
        if (this.audioStreaming) return;
        this.audioStreaming = true;
        const streamInterval = 20; // ms, ~20ms of audio per frame
        const sendNextChunk = () => {
            if (!this.audioStreaming || !this.ws || this.ws.readyState !== WebSocket.OPEN) return;
            if (this.audioQueue.length > 0) {
                const chunk = this.audioQueue.shift();
                try {
                    this.ws.send(chunk);
                } catch (err) {
                    this.emit('error', new Error('Failed to stream audio chunk: ' + err.message));
                }
            }
            if (this.audioStreaming) {
                setTimeout(sendNextChunk, streamInterval);
            }
        };
        sendNextChunk();
    }

    _handleDataMessage(msg) {
        switch (msg.type) {
            case 'transcript':
                // { type, role, text, final, ... }
                if (msg.role === 'agent') {
                    let text = msg.text || '';
                    if (typeof text === 'string' && text.length > 0) {
                        this.emit('text_response', text);
                    }
                }
                break;
            case 'state':
                // { type: 'state', state: ... }
                this.emit('status_update', { status: msg.state });
                break;
            case 'error':
                // { type: 'error', error: ... }
                this.emit('error', new Error(msg.error || 'Unknown error from UltraVox server'));
                break;
            default:
                // Unknown message type; ignore
                break;
        }
    }
}

module.exports = UltraVoxKokoroAgent;