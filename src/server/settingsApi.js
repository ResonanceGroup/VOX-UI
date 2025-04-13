// src/server/settingsApi.js
const express = require('express');
const fs = require('fs');
const path = require('path');

const router = express.Router();

// Define the path to settings.json relative to the project root
const SETTINGS_FILE = path.join(__dirname, '..', '..', 'settings.json'); // Adjust path relative to src/server

// Default settings structure
const DEFAULT_SETTINGS = {
    theme: 'light',
    mcp_config_path: '', // Default empty path
    active_voice_agent: null, // Default to null or a sensible default agent name
    voice_agent_config: {}, // Default empty config object
    // Include old defaults just in case, though they might be overwritten
    n8nwebhook: '',
    ultravoxurl: ''
};

// Routes removed as settings are now handled via WebSocket

module.exports = router;