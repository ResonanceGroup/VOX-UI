const EventEmitter = require('events');

/**
 * EchoAgent - A simple voice agent that echoes back text and audio.
 * Implements the conceptual IVoiceAgent interface for testing purposes.
 */
class EchoAgent extends EventEmitter {
    /**
     * Constructor for EchoAgent.
     * @param {object} [config] - Optional configuration object.
     */
    constructor(config = {}) {
        super();
        this.config = config;
        console.log('[EchoAgent] Initialized with config:', this.config);
    }

    /**
     * Initializes the agent.
     * Emits an initial 'idle' status update.
     */
    async initialize() {
        console.log('[EchoAgent] Initializing...');
        // Simulate async initialization if needed
        await new Promise(resolve => setTimeout(resolve, 10)); // Small delay
        this.emit('status_update', { status: 'idle', message: 'Echo Agent ready.' });
        console.log('[EchoAgent] Initialized and ready.');
    }

    /**
     * Shuts down the agent.
     */
    async shutdown() {
        console.log('[EchoAgent] Shutting down...');
        // Perform any cleanup here
        this.emit('status_update', { status: 'inactive', message: 'Echo Agent shut down.' });
        console.log('[EchoAgent] Shutdown complete.');
    }

    /**
     * Processes an incoming text message by echoing it back.
     * @param {string} text - The text message received.
     */
    processTextMessage(text) {
        console.log(`[EchoAgent] Processing text message: "${text}"`);
        this.emit('status_update', { status: 'processing', message: 'Echoing text...' });
        // Echo the text back immediately
        this.emit('text_response', { text: `Echo: ${text}` });
        this.emit('status_update', { status: 'idle', message: 'Waiting for input.' });
        console.log(`[EchoAgent] Echoed text message.`);
    }

    /**
     * Processes an incoming audio chunk by echoing it back.
     * @param {Buffer|any} chunk - The audio chunk received.
     */
    processAudioChunk(chunk) {
        // Direct echo of the audio chunk
        this.emit('audio_response_chunk', { chunk });
        // Note: No status update here to avoid flooding; handled in endAudioStream
    }

    /**
     * Handles the end of the incoming audio stream.
     */
    endAudioStream() {
        console.log('[EchoAgent] Audio stream ended.');
        this.emit('text_response', { text: 'Echo Agent: Audio stream ended.' });
        this.emit('status_update', { status: 'idle', message: 'Waiting for input.' });
    }

    /**
     * Handles the result or error received from an MCP tool request.
     * @param {string} requestId - The ID of the original MCP request.
     * @param {object|Error} resultOrError - The result or error object.
     */
    provideMcpToolResult(requestId, resultOrError) {
        console.log(`[EchoAgent] Received MCP result/error for request ${requestId}:`, resultOrError);
        if (resultOrError instanceof Error) {
            this.emit('text_response', { text: `Echo Agent: Received error for MCP request ${requestId}.` });
            // Optionally emit an error event specific to the agent?
            // this.emit('error', { message: `MCP Error for ${requestId}: ${resultOrError.message}`, error: resultOrError });
        } else {
            this.emit('text_response', { text: `Echo Agent: Received result for MCP request ${requestId}.` });
        }
        // No status change needed here, agent remains idle or processing other inputs.
    }
}

module.exports = EchoAgent;