const fs = require('fs').promises;
const path = require('path');
const { spawn } = require('child_process');
const { randomUUID } = require('crypto'); // For generating request IDs

// Placeholder for a potential WebSocket client library if needed later
// const WebSocket = require('ws');

// Placeholder for a potential HTTP client library if needed later
// const fetch = require('node-fetch'); // Or use built-in fetch in newer Node versions

/**
 * Manages connections to and interactions with MCP (Model Context Protocol) servers.
 */
class MCPClientManager {
    /**
     * Creates an instance of MCPClientManager.
     * @param {object} settings - Application settings, including mcp_config_path.
     */
    constructor(settings) {
        console.log('[MCPClientManager] Initializing...');
        if (!settings || !settings.mcp_config_path) {
            throw new Error("MCPClientManager requires settings object with 'mcp_config_path'.");
        }
        this.configPath = settings.mcp_config_path;
        this.config = []; // Holds the loaded MCP server configurations
        this.connections = new Map(); // Stores active connection details (process, state, capabilities, etc.)
        this.pendingRequests = new Map(); // Stores callbacks for pending JSON-RPC requests { requestId: { resolve, reject, timeout } }
        console.log(`[MCPClientManager] Config path set to: ${this.configPath}`);
    }

    /**
     * Loads the MCP server configuration from the JSON file.
     */
    async loadConfig() {
        console.log(`[MCPClientManager] Loading config from ${this.configPath}...`);
        try {
            const rawData = await fs.readFile(this.configPath, 'utf-8');
            this.config = JSON.parse(rawData);
            console.log(`[MCPClientManager] Config loaded successfully: ${this.config.length} servers defined.`);
            // Basic validation could be added here (e.g., check for required fields)
        } catch (error) {
            if (error.code === 'ENOENT') {
                console.warn(`[MCPClientManager] Config file not found at ${this.configPath}. Creating an empty one.`);
                this.config = [];
                await fs.writeFile(this.configPath, '[]', 'utf-8'); // Create empty config if not found
            } else if (error instanceof SyntaxError) {
                console.error(`[MCPClientManager] Error parsing config file ${this.configPath}:`, error);
                throw new Error(`Invalid JSON in MCP config file: ${this.configPath}`);
            } else {
                console.error(`[MCPClientManager] Error loading config file ${this.configPath}:`, error);
                throw error; // Re-throw other errors
            }
        }
    }

    /**
     * Initializes connections to all enabled MCP servers defined in the config.
     */
    async initializeConnections() {
        console.log('[MCPClientManager] Initializing server connections...');
        await this.loadConfig(); // Ensure config is loaded first

        if (!Array.isArray(this.config)) {
             console.error('[MCPClientManager] Invalid config format: Expected an array of server configurations.');
             this.config = []; // Reset to empty array to prevent further errors
             return;
        }

        for (const serverConfig of this.config) {
            if (!serverConfig.enabled) {
                console.log(`[MCPClientManager] Server '${serverConfig.name}' is disabled. Skipping.`);
                continue;
            }

            if (this.connections.has(serverConfig.name)) {
                console.warn(`[MCPClientManager] Server '${serverConfig.name}' connection already initialized or pending. Skipping duplicate.`);
                continue;
            }

            console.log(`[MCPClientManager] Initializing connection for server: ${serverConfig.name} (Type: ${serverConfig.type})`);
            this.connections.set(serverConfig.name, {
                config: serverConfig,
                status: 'connecting', // connecting, connected, disconnected, error
                process: null, // For stdio
                client: null, // For http/ws
                capabilities: null,
                tools: new Map(),
                resources: new Map(),
                buffer: '', // For stdio message buffering
            });

            try {
                if (serverConfig.type === 'stdio') {
                    await this._initializeStdioConnection(serverConfig);
                } else if (serverConfig.type === 'http' || serverConfig.type === 'websocket') {
                    // TODO: Implement HTTP/WebSocket connection logic
                    console.warn(`[MCPClientManager] Connection type '${serverConfig.type}' for server '${serverConfig.name}' is not yet implemented.`);
                     this.connections.get(serverConfig.name).status = 'error';
                     this.connections.get(serverConfig.name).error = new Error(`Connection type '${serverConfig.type}' not implemented.`);
                } else {
                    console.error(`[MCPClientManager] Unknown server type '${serverConfig.type}' for server '${serverConfig.name}'.`);
                     this.connections.get(serverConfig.name).status = 'error';
                     this.connections.get(serverConfig.name).error = new Error(`Unknown server type: ${serverConfig.type}`);
                }
            } catch (error) {
                 console.error(`[MCPClientManager] Failed to initialize connection for server '${serverConfig.name}':`, error);
                 if (this.connections.has(serverConfig.name)) {
                    this.connections.get(serverConfig.name).status = 'error';
                    this.connections.get(serverConfig.name).error = error;
                 }
            }
        }
        console.log('[MCPClientManager] Finished initializing connections.');
    }

    /**
     * Initializes a connection to an MCP server via Standard I/O.
     * @param {object} serverConfig - The configuration for the stdio server.
     * @private
     */
    _initializeStdioConnection(serverConfig) {
        return new Promise((resolve, reject) => {
            const connection = this.connections.get(serverConfig.name);
            if (!connection) return reject(new Error(`Connection state not found for ${serverConfig.name}`));

            console.log(`[MCPClientManager] Spawning stdio process for '${serverConfig.name}': ${serverConfig.command}`);

            // Basic command parsing (handle spaces in paths, etc.) - might need refinement
            const parts = serverConfig.command.match(/(?:[^\s"]+|"[^"]*")+/g) || [];
            const command = parts[0];
            const args = parts.slice(1).map(arg => arg.replace(/^"|"$/g, '')); // Remove surrounding quotes

            try {
                const childProcess = spawn(command, args, {
                    stdio: ['pipe', 'pipe', 'pipe'], // stdin, stdout, stderr
                    shell: false // More secure and predictable
                });

                connection.process = childProcess;
                connection.status = 'connecting'; // Explicitly set status

                childProcess.stdout.setEncoding('utf8');
                childProcess.stdout.on('data', (data) => {
                    connection.buffer += data;
                    this._processStdioBuffer(serverConfig.name);
                });

                childProcess.stderr.setEncoding('utf8');
                childProcess.stderr.on('data', (data) => {
                    console.error(`[MCP Server STDERR - ${serverConfig.name}]: ${data.trim()}`);
                });

                childProcess.on('spawn', () => {
                    console.log(`[MCPClientManager] Process spawned successfully for '${serverConfig.name}' (PID: ${childProcess.pid}).`);
                    // Don't assume connection is ready yet, wait for capabilities/hello
                    // Resolve might happen after receiving initial capabilities message
                });


                childProcess.on('error', (err) => {
                    console.error(`[MCPClientManager] Failed to spawn process for '${serverConfig.name}':`, err);
                    connection.status = 'error';
                    connection.error = err;
                    connection.process = null;
                    this._cleanupPendingRequests(serverConfig.name, new Error(`Server process failed to start: ${err.message}`));
                    reject(err); // Reject the promise for initialization failure
                });

                childProcess.on('exit', (code, signal) => {
                    console.warn(`[MCPClientManager] Process for '${serverConfig.name}' exited with code ${code}, signal ${signal}.`);
                    connection.status = 'disconnected';
                    connection.process = null;
                    this._cleanupPendingRequests(serverConfig.name, new Error(`Server process exited unexpectedly (code: ${code}, signal: ${signal})`));
                    // Optionally attempt reconnect based on config/strategy
                });

                 // Send initial capabilities request after a short delay to allow the process to start
                 // A better approach is to wait for the server to send a 'ready' or initial message if the protocol supports it.
                 // For now, we'll just assume it's ready and try to get capabilities.
                 setTimeout(async () => {
                    try {
                        console.log(`[MCPClientManager] Requesting capabilities from ${serverConfig.name}...`);
                        const capabilities = await this._sendRequest(serverConfig.name, 'mcp/negotiateCapabilities', {}); // Standard MCP method
                        connection.capabilities = capabilities; // Store negotiated capabilities
                        connection.status = 'connected'; // Mark as connected *after* successful negotiation
                        console.log(`[MCPClientManager] Connected to '${serverConfig.name}'. Capabilities:`, capabilities);

                        // Discover tools and resources
                        await this._discoverFeatures(serverConfig.name);
                        resolve(); // Resolve the promise upon successful connection and discovery

                    } catch (error) {
                         console.error(`[MCPClientManager] Failed initial capability negotiation or discovery for '${serverConfig.name}':`, error);
                         connection.status = 'error';
                         connection.error = error;
                         if (connection.process) {
                             connection.process.kill(); // Kill the process if initial communication fails
                         }
                         reject(error); // Reject the initialization promise
                    }
                 }, 500); // Small delay, adjust as needed


            } catch (error) {
                 console.error(`[MCPClientManager] Error during spawn for '${serverConfig.name}':`, error);
                 connection.status = 'error';
                 connection.error = error;
                 reject(error);
            }
        });
    }

     /**
     * Processes the buffered stdout data from a stdio server, looking for complete JSON-RPC messages.
     * @param {string} serverName - The name of the server whose buffer to process.
     * @private
     */
    _processStdioBuffer(serverName) {
        const connection = this.connections.get(serverName);
        if (!connection || connection.type !== 'stdio') return;

        // Naive JSON parsing: Assumes one JSON object per line or separated by newlines.
        // A more robust parser would handle partial messages and potential framing issues.
        let boundary = connection.buffer.indexOf('\n');
        while (boundary !== -1) {
            const messageStr = connection.buffer.substring(0, boundary).trim();
            connection.buffer = connection.buffer.substring(boundary + 1);

            if (messageStr) {
                try {
                    const message = JSON.parse(messageStr);
                    this._handleIncomingMessage(serverName, message);
                } catch (error) {
                    console.error(`[MCPClientManager - ${serverName}] Error parsing JSON message: ${error}. Message: "${messageStr}"`);
                    // Decide how to handle parse errors (e.g., ignore, disconnect)
                }
            }
            boundary = connection.buffer.indexOf('\n');
        }
        // Keep the remaining partial message in the buffer for the next data event.
    }

    /**
     * Handles an incoming JSON-RPC message (response or notification).
     * @param {string} serverName - The name of the server that sent the message.
     * @param {object} message - The parsed JSON-RPC message object.
     * @private
     */
    _handleIncomingMessage(serverName, message) {
        if (!message || typeof message !== 'object') {
            console.warn(`[MCPClientManager - ${serverName}] Received invalid message format.`);
            return;
        }

        // Check if it's a response to a pending request
        if (message.id && this.pendingRequests.has(message.id)) {
            const { resolve, reject, timeout } = this.pendingRequests.get(message.id);
            clearTimeout(timeout); // Clear the timeout timer

            if (message.error) {
                console.error(`[MCPClientManager - ${serverName}] Received error response for request ${message.id}:`, message.error);
                reject(new Error(`MCP Error (${message.error.code || 'unknown'}): ${message.error.message || 'Unknown error'}`));
            } else {
                 // Check for MCP-specific error structure within result
                 if (message.result && typeof message.result === 'object' && message.result.isError === true) {
                    console.error(`[MCPClientManager - ${serverName}] Received MCP tool error for request ${message.id}:`, message.result);
                    reject(new Error(`MCP Tool Error: ${message.result.message || 'Tool execution failed'}`));
                 } else {
                    console.log(`[MCPClientManager - ${serverName}] Received result for request ${message.id}.`);
                    resolve(message.result);
                 }
            }
            this.pendingRequests.delete(message.id);
        }
        // Check if it's a notification
        else if (message.method && !message.id) {
            console.log(`[MCPClientManager - ${serverName}] Received notification: ${message.method}`, message.params || '');
            // TODO: Implement specific notification handling logic (e.g., emit events)
            if (message.method === 'mcp/serverStatus') {
                // Handle server status updates
            } else if (message.method === 'mcp/log') {
                 console.log(`[MCP Server Log - ${serverName} - ${message.params?.level || 'info'}]:`, message.params?.message);
            }
            // Add more notification handlers as needed
        }
        // Unknown message type
        else {
            console.warn(`[MCPClientManager - ${serverName}] Received unexpected message:`, message);
        }
    }

     /**
     * Cleans up pending requests associated with a server when it disconnects or errors.
     * @param {string} serverName - The name of the server.
     * @param {Error} error - The error to reject pending requests with.
     * @private
     */
    _cleanupPendingRequests(serverName, error) {
        console.warn(`[MCPClientManager] Cleaning up pending requests for disconnected/errored server '${serverName}'...`);
        const requestsToClean = [];
        for (const [requestId, pending] of this.pendingRequests.entries()) {
            // Assuming request IDs or some context allows linking to the server
            // This might need refinement if request IDs aren't server-specific
            // For now, we'll clear all if *any* server disconnects, which isn't ideal.
            // A better approach: Store serverName with the pending request.
             requestsToClean.push({ requestId, pending });
        }

        for(const { requestId, pending } of requestsToClean) {
             console.warn(`[MCPClientManager] Rejecting pending request ${requestId} due to server '${serverName}' issue.`);
             clearTimeout(pending.timeout);
             pending.reject(error);
             this.pendingRequests.delete(requestId);
        }
    }

    /**
     * Sends a JSON-RPC request to a specific MCP server.
     * @param {string} serverName - The name of the target server.
     * @param {string} method - The JSON-RPC method name (e.g., 'tools/call', 'resources/read').
     * @param {object|array} params - The parameters for the method.
     * @param {number} timeoutMs - Timeout duration in milliseconds.
     * @returns {Promise<any>} A promise that resolves with the result or rejects with an error.
     * @private
     */
    _sendRequest(serverName, method, params, timeoutMs = 15000) { // 15 second default timeout
        return new Promise((resolve, reject) => {
            const connection = this.connections.get(serverName);
            if (!connection || connection.status !== 'connected') {
                return reject(new Error(`Server '${serverName}' is not connected or available.`));
            }

            const requestId = randomUUID();
            const request = {
                jsonrpc: '2.0',
                id: requestId,
                method: method,
                params: params || {}, // Ensure params is at least an empty object
            };

            const requestString = JSON.stringify(request) + '\n'; // Add newline for stdio framing

            // Set up timeout
            const timeout = setTimeout(() => {
                this.pendingRequests.delete(requestId);
                reject(new Error(`Request ${requestId} (${method}) to server '${serverName}' timed out after ${timeoutMs}ms.`));
            }, timeoutMs);

            // Store the pending request details
            this.pendingRequests.set(requestId, { resolve, reject, timeout });

            try {
                if (connection.type === 'stdio' && connection.process && connection.process.stdin) {
                    console.log(`[MCPClientManager -> ${serverName}] Sending request ${requestId}: ${method}`);
                    connection.process.stdin.write(requestString, 'utf8', (err) => {
                        if (err) {
                             console.error(`[MCPClientManager -> ${serverName}] Error writing to stdin for request ${requestId}:`, err);
                             clearTimeout(timeout);
                             this.pendingRequests.delete(requestId);
                             reject(new Error(`Failed to send request to '${serverName}': ${err.message}`));
                        }
                    });
                } else if (connection.type === 'http' || connection.type === 'websocket') {
                    // TODO: Implement sending logic for HTTP/WebSocket
                    clearTimeout(timeout);
                    this.pendingRequests.delete(requestId);
                    reject(new Error(`Sending via ${connection.type} to '${serverName}' is not yet implemented.`));
                } else {
                    clearTimeout(timeout);
                    this.pendingRequests.delete(requestId);
                    reject(new Error(`Cannot send request: Unknown connection type for server '${serverName}'.`));
                }
            } catch (error) {
                console.error(`[MCPClientManager -> ${serverName}] Exception during sendRequest for ${requestId}:`, error);
                clearTimeout(timeout);
                this.pendingRequests.delete(requestId);
                reject(error);
            }
        });
    }

     /**
     * Discovers tools and resources from a connected server.
     * @param {string} serverName - The name of the server.
     * @private
     */
    async _discoverFeatures(serverName) {
        const connection = this.connections.get(serverName);
         if (!connection || connection.status !== 'connected') {
             console.warn(`[MCPClientManager] Cannot discover features for '${serverName}', not connected.`);
             return;
         }

        try {
            console.log(`[MCPClientManager] Discovering tools for ${serverName}...`);
            const toolsList = await this._sendRequest(serverName, 'tools/list', {});
            if (Array.isArray(toolsList)) {
                 connection.tools.clear();
                 toolsList.forEach(tool => connection.tools.set(tool.name, tool));
                 console.log(`[MCPClientManager] Discovered ${connection.tools.size} tools for ${serverName}.`);
            } else {
                 console.warn(`[MCPClientManager] Invalid tools/list response from ${serverName}:`, toolsList);
            }
        } catch (error) {
             console.error(`[MCPClientManager] Failed to discover tools for ${serverName}:`, error);
             // Decide if this should mark the connection as errored
        }

         try {
            console.log(`[MCPClientManager] Discovering resources for ${serverName}...`);
            const resourcesList = await this._sendRequest(serverName, 'resources/list', {});
             if (Array.isArray(resourcesList)) {
                 connection.resources.clear();
                 resourcesList.forEach(resource => connection.resources.set(resource.uri, resource)); // Use URI as key
                 console.log(`[MCPClientManager] Discovered ${connection.resources.size} resources for ${serverName}.`);
            } else {
                 console.warn(`[MCPClientManager] Invalid resources/list response from ${serverName}:`, resourcesList);
            }
        } catch (error) {
             console.error(`[MCPClientManager] Failed to discover resources for ${serverName}:`, error);
             // Decide if this should mark the connection as errored
        }
    }


    /**
     * Retrieves the connection details for a specific server.
     * @param {string} serverName - The name of the server.
     * @returns {object | undefined} The connection object or undefined if not found.
     */
    getServerConnection(serverName) {
        return this.connections.get(serverName);
    }

    /**
     * Handles a request from the agent to call an MCP tool.
     * @param {string} agentRequestId - The unique ID generated by the agent for this request.
     * @param {string} serverName - The name of the target MCP server.
     * @param {string} toolName - The name of the tool to call.
     * @param {object} args - The arguments for the tool.
     * @returns {Promise<object>} A promise that resolves with the tool's result or rejects with an error object.
     */
    async handleToolRequest(agentRequestId, serverName, toolName, args) {
        console.log(`[MCPClientManager] Handling tool request ${agentRequestId}: ${serverName}/${toolName}`);
        const connection = this.connections.get(serverName);

        if (!connection) {
            console.error(`[MCPClientManager] Tool request ${agentRequestId} failed: Server '${serverName}' not found.`);
            return { isError: true, message: `MCP server '${serverName}' not configured or found.` };
        }

        if (connection.status !== 'connected') {
             console.error(`[MCPClientManager] Tool request ${agentRequestId} failed: Server '${serverName}' is not connected (status: ${connection.status}).`);
             return { isError: true, message: `MCP server '${serverName}' is not connected (status: ${connection.status}).`, details: connection.error?.message };
        }

        const toolInfo = connection.tools.get(toolName);
        if (!toolInfo) {
             console.error(`[MCPClientManager] Tool request ${agentRequestId} failed: Tool '${toolName}' not found or available on server '${serverName}'.`);
             // Optional: Refresh tools list if suspecting stale data?
             // await this._discoverFeatures(serverName);
             // toolInfo = connection.tools.get(toolName);
             // if (!toolInfo) { ... }
             return { isError: true, message: `Tool '${toolName}' not found on server '${serverName}'.` };
        }

        // TODO: Add input schema validation using toolInfo.inputSchema if available

        try {
            const result = await this._sendRequest(serverName, 'tools/call', { tool_name: toolName, arguments: args });
            console.log(`[MCPClientManager] Tool request ${agentRequestId} successful.`);
            // The _handleIncomingMessage already checks for result.isError,
            // but we might want additional processing or logging here.
            return result; // Return the direct result from the server
        } catch (error) {
            console.error(`[MCPClientManager] Tool request ${agentRequestId} (${serverName}/${toolName}) failed:`, error);
            // Format the error into the expected structure for the agent
            return { isError: true, message: error.message || 'MCP tool call failed.', code: error.code };
        }
    }

    /**
     * Handles a request to read an MCP resource. (Basic Implementation)
     * @param {string} uri - The URI of the resource to read.
     * @returns {Promise<any>} A promise resolving with the resource content or rejecting with an error.
     */
    async handleResourceRequest(uri) {
        console.log(`[MCPClientManager] Handling resource request for URI: ${uri}`);
        // Basic URI parsing to find server (needs improvement for robust routing)
        // Example: mcp://server-name/path/to/resource
        let serverName = null;
        try {
            const url = new URL(uri);
            if (url.protocol === 'mcp:') {
                serverName = url.hostname;
            }
        } catch (e) {
            console.error(`[MCPClientManager] Invalid resource URI format: ${uri}`);
            return { isError: true, message: `Invalid resource URI format: ${uri}` };
        }


        if (!serverName || !this.connections.has(serverName)) {
             console.error(`[MCPClientManager] Resource request failed: Cannot determine server or server '${serverName}' not found for URI '${uri}'.`);
             return { isError: true, message: `Could not find server for resource URI: ${uri}` };
        }

         const connection = this.connections.get(serverName);
         if (connection.status !== 'connected') {
             console.error(`[MCPClientManager] Resource request failed: Server '${serverName}' is not connected (status: ${connection.status}).`);
             return { isError: true, message: `MCP server '${serverName}' is not connected.` };
         }

         // Optional: Check if resource URI exists in discovered resources connection.resources.has(uri)

        try {
            const result = await this._sendRequest(serverName, 'resources/read', { uri: uri });
            console.log(`[MCPClientManager] Resource request successful for URI: ${uri}`);
            return result; // Assuming result is the content or { content: ..., metadata: ... }
        } catch (error) {
            console.error(`[MCPClientManager] Resource request for URI '${uri}' failed:`, error);
            return { isError: true, message: error.message || 'MCP resource read failed.' };
        }
    }

    /**
     * Gracefully shuts down all active MCP connections and processes.
     */
    async shutdown() {
        console.log('[MCPClientManager] Shutting down connections...');
        const shutdownPromises = [];

        for (const [name, connection] of this.connections.entries()) {
            console.log(`[MCPClientManager] Shutting down connection to '${name}'...`);
            if (connection.process) {
                // Attempt graceful shutdown first? (e.g., send a shutdown notification)
                // For now, just kill the process.
                console.log(`[MCPClientManager] Terminating process for '${name}' (PID: ${connection.process.pid}).`);
                 const promise = new Promise((resolve) => {
                     connection.process.on('exit', () => {
                         console.log(`[MCPClientManager] Process for '${name}' terminated.`);
                         resolve();
                     });
                     connection.process.kill('SIGTERM'); // Send termination signal
                     // Force kill after a timeout if SIGTERM doesn't work
                     setTimeout(() => {
                         if (!connection.process.killed) {
                             console.warn(`[MCPClientManager] Process for '${name}' did not exit gracefully, sending SIGKILL.`);
                             connection.process.kill('SIGKILL');
                             resolve(); // Resolve anyway after attempting SIGKILL
                         }
                     }, 2000); // 2 second timeout
                 });
                 shutdownPromises.push(promise);

            } else if (connection.client) {
                // TODO: Implement shutdown for HTTP/WebSocket clients
                console.log(`[MCPClientManager] Closing client connection for '${name}' (not fully implemented).`);
                // connection.client.close(); or similar
            }
             connection.status = 'disconnected';
        }

        await Promise.allSettled(shutdownPromises); // Wait for all shutdowns to complete or timeout
        this.connections.clear();
        this.pendingRequests.clear(); // Clear any remaining pending requests
        console.log('[MCPClientManager] All connections shut down.');
    }
}

module.exports = { MCPClientManager };