// src/server/webSocketHandler.js
const path = require('path');
const WebSocket = require('ws'); // Ensure WebSocket is available if needed, though usually passed in
const { MCPClientManager } = require('./mcpClient'); // Import the MCP manager
const settingsApi = require('../utils/settingsApi'); // Assuming settings API location

function initializeWebSocketHandling(wss) {
    console.log('Initializing WebSocket connection handling...');

    // --- MCP Client Setup ---
    let mcpClientManager;
    try {
        const settings = settingsApi.loadSettings(); // Load settings
        // Ensure the path is absolute or correctly relative from project root if needed
        const configPath = path.resolve(__dirname, '../../', settings.mcp_config_path || 'mcp_config.json'); // Default to root mcp_config.json
        console.log(`[WebSocketHandler] Resolved MCP Config Path: ${configPath}`);
        mcpClientManager = new MCPClientManager({ ...settings, mcp_config_path: configPath });
        mcpClientManager.initializeConnections().catch(err => {
            console.error("[WebSocketHandler] Failed to initialize MCP connections on startup:", err);
            // Decide if server should fail to start or just log the error
        });
    } catch (error) {
        console.error("[WebSocketHandler] Failed to instantiate MCPClientManager:", error);
        // Handle error appropriately - maybe the server shouldn't start without MCP?
        // For now, we'll log and continue, but MCP features will be unavailable.
        mcpClientManager = null; // Ensure it's null if setup fails
    }
    // --- End MCP Client Setup ---

    wss.on('connection', (ws, req) => { // Added req for potential future use (e.g., getting IP)
        console.log(`Client connected via WebSocket from ${req.socket.remoteAddress}`);
        ws.voiceAgent = null; // Initialize voice agent storage for this connection

        // Listener for messages from this client
        ws.on('message', async (message) => { // Make handler async for await
            console.log('Received WebSocket message:', message.toString());
            let parsedMessage;
            try {
                parsedMessage = JSON.parse(message.toString());
            } catch (e) {
                console.error('Failed to parse WebSocket message or invalid JSON:', e);
                ws.send(JSON.stringify({ type: 'error_message', payload: { message: 'Invalid JSON received' } }));
                return; // Stop processing if JSON is invalid
            }

            // --- Agent Initialization Logic ---
            if (parsedMessage.type === 'init_session') {
                if (ws.voiceAgent) {
                    console.warn('Session already initialized for this client. Ignoring new init_session request.');
                    ws.send(JSON.stringify({ type: 'error_message', payload: { message: 'Session already initialized.' } }));
                    return;
                }

                const { agentType, config } = parsedMessage.payload;
                if (!agentType) {
                    console.error('init_session message missing agentType.');
                    ws.send(JSON.stringify({ type: 'error_message', payload: { message: 'Missing agentType in init_session payload.' } }));
                    return;
                }

                const agentFileName = `${agentType}Agent.js`;
                // IMPORTANT: Construct path relative to *this file's location*
                const agentPath = path.join(__dirname, 'agents', agentFileName);
                console.log(`Attempting to load agent from: ${agentPath}`);

                try {
                    // Check if file exists before requiring
                    // Note: require.resolve throws if not found, so direct check isn't strictly needed here
                    // but good practice in some scenarios. Let's rely on require's throw.
                    // if (!require.resolve(agentPath)) {
                    //      throw new Error(`Agent module not found at ${agentPath}`);
                    // }

                    const AgentClass = require(agentPath);
                    console.log(`Loading agent type: ${agentType}`);
                    const agentInstance = new AgentClass(config || {}); // Pass config or empty object
                    ws.voiceAgent = agentInstance; // Store agent instance

                    console.log(`Initializing agent: ${agentType}`);
                    let initialized = false;
                    if (typeof ws.voiceAgent.initialize === 'function') {
                        await ws.voiceAgent.initialize(); // Await async initialization
                        console.log(`Agent ${agentType} initialized successfully.`);
                        ws.send(JSON.stringify({ type: 'session_confirmed', payload: {} }));
                        initialized = true;
                    } else {
                         console.warn(`Agent ${agentType} does not have an initialize method, assuming synchronous setup.`);
                         // Still confirm session, but note lack of async init
                         ws.send(JSON.stringify({ type: 'session_confirmed', payload: { warning: 'Agent has no initialize method.' } }));
                         initialized = true; // Assume ready if no init method
                    }

                    // --- Agent Event Handling (Attach listeners AFTER successful init) ---
                    if (initialized && ws.voiceAgent) {
                        console.log(`Attaching event listeners for agent ${agentType}`);

                        // Helper to safely send JSON messages
                        const sendWsJson = (data) => {
                            try {
                                ws.send(JSON.stringify(data));
                            } catch (sendError) {
                                console.error('Failed to send WebSocket message:', sendError);
                            }
                        };

                        ws.voiceAgent.on('status_update', (payload) => {
                            console.log('Agent status update:', payload);
                            sendWsJson({ type: 'status_update', payload });
                        });

                        ws.voiceAgent.on('text_response', (payload) => {
                            console.log('Agent text response:', payload);
                            sendWsJson({ type: 'text_response', payload });
                        });

                        ws.voiceAgent.on('audio_response_chunk', (payload) => {
                            // Don't log every chunk, could be noisy
                            // console.log('Agent audio response chunk received');
                            sendWsJson({ type: 'audio_response_chunk', payload });
                        });

                        ws.voiceAgent.on('error', (payload) => {
                            console.error('Agent reported error:', payload);
                            sendWsJson({ type: 'error_message', payload: { message: payload.message || 'Agent error occurred', details: payload } });
                        });

                        ws.voiceAgent.on('request_mcp_tool', async (payload) => {
                            console.log('Agent requested MCP tool:', payload);
                            const { request_id, server_name, tool_name, args } = payload;

                            if (!mcpClientManager) {
                                console.error("MCPClientManager not available. Cannot handle tool request.");
                                if (typeof ws.voiceAgent.provideMcpToolResult === 'function') {
                                    ws.voiceAgent.provideMcpToolResult(request_id, { isError: true, message: "MCP Client Manager is not initialized." });
                                }
                                return;
                            }

                            if (!request_id || !server_name || !tool_name) {
                                console.error("Invalid 'request_mcp_tool' payload:", payload);
                                if (typeof ws.voiceAgent.provideMcpToolResult === 'function') {
                                     ws.voiceAgent.provideMcpToolResult(request_id || 'unknown', { isError: true, message: "Invalid MCP tool request payload from agent." });
                                }
                                return;
                            }

                            try {
                                const resultOrError = await mcpClientManager.handleToolRequest(request_id, server_name, tool_name, args || {});
                                console.log(`MCP tool request ${request_id} completed. Result/Error:`, resultOrError);
                                if (typeof ws.voiceAgent.provideMcpToolResult === 'function') {
                                    ws.voiceAgent.provideMcpToolResult(request_id, resultOrError);
                                } else {
                                    console.error(`Agent ${ws.voiceAgent.constructor.name} does not have a provideMcpToolResult method.`);
                                    // Optionally send an error back to the client if the agent can't handle the result
                                    sendWsJson({ type: 'error_message', payload: { message: `Agent cannot process MCP result for request ${request_id}.` } });
                                }
                            } catch (error) {
                                console.error(`Error handling MCP tool request ${request_id}:`, error);
                                if (typeof ws.voiceAgent.provideMcpToolResult === 'function') {
                                    // Send a generic error back to the agent
                                    ws.voiceAgent.provideMcpToolResult(request_id, { isError: true, message: `Internal server error handling MCP request: ${error.message}` });
                                }
                            }
                        });

                        console.log(`Event listeners attached for agent ${agentType}`);
                    }

                } catch (error) {
                    console.error(`Failed to load or initialize agent ${agentType}:`, error);
                    ws.voiceAgent = null; // Clear any partial assignment
                    ws.send(JSON.stringify({
                        type: 'error_message',
                        payload: { message: `Failed to initialize session with agent ${agentType}. Error: ${error.message}` }
                    }));
                }
            } 
            // --- Handle other message types (Routing) ---
            else if (ws.voiceAgent) { // Check if agent exists *first*
                // Agent is initialized, route message based on type
                console.log(`Routing message type '${parsedMessage.type}' to active agent: ${ws.voiceAgent.constructor.name}`);
                try {
                    switch (parsedMessage.type) {
                        case 'text_input':
                            if (parsedMessage.payload && typeof parsedMessage.payload.text === 'string') {
                                if (typeof ws.voiceAgent.processTextMessage === 'function') {
                                    await ws.voiceAgent.processTextMessage(parsedMessage.payload.text);
                                } else {
                                     console.error(`Agent ${ws.voiceAgent.constructor.name} does not have a processTextMessage method.`);
                                     ws.send(JSON.stringify({ type: 'error_message', payload: { message: 'Agent cannot process text input.' } }));
                                }
                            } else {
                                console.warn('Invalid text_input payload:', parsedMessage.payload);
                                ws.send(JSON.stringify({ type: 'error_message', payload: { message: 'Invalid payload for text_input' } }));
                            }
                            break;
                        case 'audio_chunk':
                            if (parsedMessage.payload && parsedMessage.payload.chunk) {
                                if (typeof ws.voiceAgent.processAudioChunk === 'function') {
                                    // Assuming chunk is in a format the agent expects (e.g., base64 string or Buffer)
                                    await ws.voiceAgent.processAudioChunk(parsedMessage.payload.chunk);
                                } else {
                                    console.error(`Agent ${ws.voiceAgent.constructor.name} does not have a processAudioChunk method.`);
                                    ws.send(JSON.stringify({ type: 'error_message', payload: { message: 'Agent cannot process audio chunks.' } }));
                                }
                            } else {
                                console.warn('Invalid audio_chunk payload:', parsedMessage.payload);
                                ws.send(JSON.stringify({ type: 'error_message', payload: { message: 'Invalid payload for audio_chunk' } }));
                            }
                            break;
                        case 'end_audio_stream':
                            if (typeof ws.voiceAgent.endAudioStream === 'function') {
                                await ws.voiceAgent.endAudioStream();
                            } else {
                                console.error(`Agent ${ws.voiceAgent.constructor.name} does not have an endAudioStream method.`);
                                ws.send(JSON.stringify({ type: 'error_message', payload: { message: 'Agent cannot process end_audio_stream.' } }));
                            }
                            break;
                        default:
                            console.warn(`Received unknown message type '${parsedMessage.type}' from initialized client.`);
                            ws.send(JSON.stringify({ type: 'error_message', payload: { message: `Unknown message type: ${parsedMessage.type}` } }));
                    }
                } catch (agentError) {
                    console.error(`Agent error processing message type '${parsedMessage.type}':`, agentError);
                    // Use the helper function for sending errors
                    const sendWsJson = (data) => {
                        if (ws.readyState === WebSocket.OPEN) {
                            try { ws.send(JSON.stringify(data)); } catch (e) { console.error('WS Send Error:', e); }
                        } else {
                             console.warn('Attempted to send message on closed WebSocket during agent error handling.');
                        }
                    };
                    sendWsJson({ type: 'error_message', payload: { message: `Agent error: ${agentError.message}`, details: agentError.stack } });
                }
            } else {
                // Agent not initialized, and message is not 'init_session'
                console.warn(`Received message type '${parsedMessage.type}' before session initialization. Ignoring.`);
                ws.send(JSON.stringify({ type: 'error_message', payload: { message: 'Session not initialized. Send init_session first.' } }));
            }
        });

        // Listener for client disconnection
        ws.on('close', async () => { // Make handler async
            console.log(`Client disconnected: ${req.socket.remoteAddress}`);
            if (ws.voiceAgent) {
                console.log(`Shutting down agent for disconnected client...`);
                try {
                    if (typeof ws.voiceAgent.shutdown === 'function') {
                        await ws.voiceAgent.shutdown(); // Await async shutdown
                        console.log('Agent shutdown complete.');
                    } else {
                        console.warn('Connected agent does not have a shutdown method.');
                    }
                } catch (error) {
                    console.error('Error during agent shutdown:', error);
                } finally {
                    ws.voiceAgent = null; // Clean up reference regardless of shutdown success
                }
            } else {
                console.log('No active agent for disconnected client.');
            }
        });

        // Listener for errors on this connection
        ws.on('error', (error) => {
            console.error(`WebSocket error for ${req.socket.remoteAddress}:`, error);
            // Attempt graceful shutdown if agent exists
            if (ws.voiceAgent && typeof ws.voiceAgent.shutdown === 'function') {
                console.log('Attempting agent shutdown due to WebSocket error...');
                 ws.voiceAgent.shutdown().catch(shutdownError => {
                     console.error('Error during agent shutdown after WebSocket error:', shutdownError);
                 }).finally(() => {
                     ws.voiceAgent = null;
                 });
            } else {
                 ws.voiceAgent = null; // Ensure cleanup even if no shutdown method
            }
        });

        // Send a welcome message
        ws.send(JSON.stringify({ type: 'welcome', payload: { message: 'WebSocket connection established. Please send init_session to start.' } }));
    });

    console.log('WebSocket connection handler attached.');
}

module.exports = initializeWebSocketHandling;