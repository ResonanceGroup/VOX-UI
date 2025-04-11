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

// GET /api/settings
router.get('/', (req, res) => {
    try {
        let settings = {};
        if (fs.existsSync(SETTINGS_FILE)) {
            const fileContent = fs.readFileSync(SETTINGS_FILE, 'utf8');
            // Handle potentially empty file
            settings = fileContent ? JSON.parse(fileContent) : {};
        }

        // Merge defaults with loaded settings to ensure all keys exist
        const completeSettings = { ...DEFAULT_SETTINGS, ...settings };

        res.json(completeSettings);
    } catch (err) {
        console.error('Error loading settings:', err);
        // Differentiate between parse error and file read error if needed
        if (err instanceof SyntaxError) {
            res.status(500).json({ error: 'Failed to parse settings file (invalid JSON)' });
        } else {
            res.status(500).json({ error: 'Failed to load settings' });
        }
    }
});

// POST /api/settings
router.post('/', (req, res) => {
    const newSettings = req.body;

    // Basic validation: Check if required keys exist
    const requiredKeys = ['theme', 'mcp_config_path', 'active_voice_agent', 'voice_agent_config'];
    const missingKeys = requiredKeys.filter(key => !(key in newSettings));

    if (missingKeys.length > 0) {
        return res.status(400).json({
            error: `Missing required settings fields: ${missingKeys.join(', ')}`
        });
    }

    // More specific validation could be added here (e.g., type checking)

    try {
        // Write the entire validated object back
        fs.writeFileSync(SETTINGS_FILE, JSON.stringify(newSettings, null, 2), 'utf8');
        res.json({ success: true, message: 'Settings saved successfully.' });
    } catch (err) {
        console.error('Error saving settings:', err);
        res.status(500).json({ error: 'Failed to save settings' });
    }
});

module.exports = router;