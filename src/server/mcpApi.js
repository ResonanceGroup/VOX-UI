const express = require('express');
const fs = require('fs').promises; // Using promises for async operations
const path = require('path');
const { exec } = require('child_process'); // For opening the config file

const router = express.Router();

// Helper function to read MCP config
async function readMcpConfig() {
    const configPath = path.join(__dirname, '..', '..', 'mcp_config.json');
    try {
        const configData = await fs.readFile(configPath, 'utf8');
        return JSON.parse(configData);
    } catch (error) {
        console.error(`Error reading MCP config file at ${configPath}:`, error);
        if (error.code === 'ENOENT') {
            throw new Error('MCP config file not found.');
        } else if (error instanceof SyntaxError) {
            throw new Error('Error parsing MCP config file (invalid JSON).');
        } else {
            throw new Error('Could not read MCP config file.');
        }
    }
}

// Helper function to write MCP config
async function writeMcpConfig(config) {
    const configPath = path.join(__dirname, '..', '..', 'mcp_config.json');
    try {
        await fs.writeFile(configPath, JSON.stringify(config, null, 2), 'utf8');
    } catch (error) {
        console.error(`Error writing MCP config file at ${configPath}:`, error);
        throw new Error('Could not write MCP config file.');
    }
}

// GET /api/mcp/servers - Retrieve MCP server configurations
router.get('/servers', async (req, res) => {
    try {
        const mcpConfig = await readMcpConfig();
        // TODO: Enhancement - Augment with status from MCPClientManager
        res.json(mcpConfig.servers || []);
    } catch (error) {
        console.error('GET /api/mcp/servers error:', error.message);
        res.status(500).json({ error: `Failed to get MCP servers: ${error.message}` });
    }
});

// POST /api/mcp/servers/:serverName/toggle - Toggle server enabled status
router.post('/servers/:serverName/toggle', async (req, res) => {
    const serverName = req.params.serverName;
    try {
        const mcpConfig = await readMcpConfig();
        const serverIndex = mcpConfig.servers.findIndex(s => s.name === serverName);

        if (serverIndex === -1) {
            return res.status(404).json({ error: `Server '${serverName}' not found.` });
        }

        // Toggle enabled status
        mcpConfig.servers[serverIndex].enabled = !mcpConfig.servers[serverIndex].enabled;
        const newStatus = mcpConfig.servers[serverIndex].enabled;

        await writeMcpConfig(mcpConfig);

        // TODO: Enhancement - Trigger MCPClientManager to connect/disconnect

        console.log(`Toggled server '${serverName}' to enabled: ${newStatus}`);
        res.json({ success: true, serverName: serverName, enabled: newStatus });

    } catch (error) {
        console.error(`POST /api/mcp/servers/${serverName}/toggle error:`, error.message);
        res.status(500).json({ error: `Failed to toggle server '${serverName}': ${error.message}` });
    }
});

// POST /api/mcp/servers/:serverName/refresh - Refresh server discovery
router.post('/servers/:serverName/refresh', async (req, res) => {
    const serverName = req.params.serverName;
    try {
        // TODO: Enhancement - Trigger MCPClientManager discovery for this server
        console.log(`Placeholder: Refresh requested for server '${serverName}'`);
        // In a real implementation, you'd interact with MCPClientManager here
        res.json({ success: true, message: `Refresh initiated for server '${serverName}'.` });
    } catch (error) {
        console.error(`POST /api/mcp/servers/${serverName}/refresh error:`, error.message);
        res.status(500).json({ error: `Failed to refresh server '${serverName}': ${error.message}` });
    }
});

// POST /api/mcp/config/open - Open the MCP config file
router.post('/config/open', async (req, res) => {
    try {
        const configPath = path.join(__dirname, '..', '..', 'mcp_config.json');
        let command;

        // Determine the command based on the OS
        // Using process.platform which is a standard Node.js property
        switch (process.platform) {
            case 'win32': // Windows
                command = `start "" "${configPath}"`; // Use start command, empty title needed for paths with spaces
                break;
            case 'darwin': // macOS
                command = `open "${configPath}"`;
                break;
            default: // Linux and other POSIX
                command = `xdg-open "${configPath}"`;
        }

        console.log(`Attempting to open MCP config: ${command}`);

        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error executing command: ${error.message}`);
                // Don't send a 500 for this, as the server itself is fine
                // The client can decide how to handle the inability to open the file
                return res.status(400).json({ error: `Failed to open config file: ${error.message}` });
            }
            if (stderr) {
                console.warn(`Command stderr: ${stderr}`); // Log stderr as a warning
            }
            console.log(`Opened MCP config file: ${configPath}`);
            res.json({ success: true, message: 'Attempted to open MCP config file.' });
        });

    } catch (error) {
        console.error('POST /api/mcp/config/open error:', error.message);
        res.status(500).json({ error: `Failed to open MCP config: ${error.message}` });
    }
});


module.exports = router;