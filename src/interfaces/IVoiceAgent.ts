import { EventEmitter } from 'events';

// Define specific types for payloads
export type VoiceAgentStatus = 'idle' | 'listening' | 'processing' | 'speaking' | 'error';

export interface McpToolRequest {
    /** Unique identifier for this tool request, used to correlate results. */
    requestId: string;
    /** Name of the target MCP server. */
    serverName: string;
    /** Name of the tool to execute on the server. */
    toolName: string;
    /** Arguments required by the tool. */
    arguments: any;
}

/**
 * Defines the contract for a Voice Agent module within the VOX UI system.
 * Each agent implementation (e.g., UltraVox, Phi-4) must adhere to this interface.
 * Agents are responsible for processing user input (text or audio),
 * interacting with underlying AI models/services, managing their state,
 * requesting MCP tool usage, and emitting responses (text or audio) and status updates.
 */
export interface IVoiceAgent extends EventEmitter {
    /**
     * Initializes the voice agent with the provided configuration.
     * This may involve connecting to external services, loading models, etc.
     * Should be called before any other processing methods.
     * @param config Agent-specific configuration object.
     * @throws {Error} If initialization fails.
     */
    initialize(config: any): Promise<void>;

    /**
     * Shuts down the voice agent, releasing any resources.
     * This may involve disconnecting from services, unloading models, etc.
     * @throws {Error} If shutdown encounters issues.
     */
    shutdown(): Promise<void>;

    /**
     * Processes a complete text message from the user.
     * @param message The text message input.
     * @throws {Error} If processing fails.
     */
    processTextMessage(message: string): Promise<void>;

    /**
     * Processes a chunk of audio data as part of a stream.
     * The agent should handle buffering or immediate processing as appropriate.
     * @param chunk A Buffer containing the audio data chunk.
     * @throws {Error} If processing fails.
     */
    processAudioChunk(chunk: Buffer): Promise<void>;

    /**
     * Signals the end of the incoming audio stream.
     * The agent should finalize any processing related to the completed stream.
     * @throws {Error} If finalization fails.
     */
    endAudioStream(): Promise<void>;

    /**
     * Provides the result of a previously requested MCP tool execution back to the agent.
     * The agent can use this result to continue its processing or generate a response.
     * @param requestId The unique identifier originally provided in the 'request_mcp_tool' event.
     * @param result The data returned by the MCP tool. Can be any type, including errors from the tool.
     */
    provideMcpToolResult(requestId: string, result: any): void;

    // --- Event Emitter Signatures ---

    /**
     * Emitted when the agent's status changes.
     * @param event 'status_update'
     * @param listener Callback function receiving the new status.
     */
    on(event: 'status_update', listener: (status: VoiceAgentStatus) => void): this;

    /**
     * Emitted when the agent generates a complete text response.
     * @param event 'text_response'
     * @param listener Callback function receiving the text response.
     */
    on(event: 'text_response', listener: (response: string) => void): this;

    /**
     * Emitted when the agent generates a chunk of audio response data (e.g., TTS).
     * @param event 'audio_response_chunk'
     * @param listener Callback function receiving the audio chunk.
     */
    on(event: 'audio_response_chunk', listener: (chunk: Buffer) => void): this;

    /**
     * Emitted when the agent needs the backend to execute an MCP tool.
     * The backend should handle the execution and call `provideMcpToolResult` with the outcome.
     * @param event 'request_mcp_tool'
     * @param listener Callback function receiving the tool request details.
     */
    on(event: 'request_mcp_tool', listener: (request: McpToolRequest) => void): this;

    /**
     * Emitted when an error occurs within the agent's processing.
     * @param event 'error'
     * @param listener Callback function receiving the Error object.
     */
    on(event: 'error', listener: (error: Error) => void): this;

    // Define off signatures for completeness
    off(event: 'status_update', listener: (status: VoiceAgentStatus) => void): this;
    off(event: 'text_response', listener: (response: string) => void): this;
    off(event: 'audio_response_chunk', listener: (chunk: Buffer) => void): this;
    off(event: 'request_mcp_tool', listener: (request: McpToolRequest) => void): this;
    off(event: 'error', listener: (error: Error) => void): this;

    // Define emit signatures for type safety when implementing
    emit(event: 'status_update', status: VoiceAgentStatus): boolean;
    emit(event: 'text_response', response: string): boolean;
    emit(event: 'audio_response_chunk', chunk: Buffer): boolean;
    emit(event: 'request_mcp_tool', request: McpToolRequest): boolean;
    emit(event: 'error', error: Error): boolean;
}