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
    mcp_config_path: '',
    active_voice_agent: null,
    voice_agent_config: {}
};

// Validate settings object before saving
function validateSettings(settings) {
    if (!settings || typeof settings !== 'object') return false;
    if (!settings.theme || typeof settings.theme !== 'string') return false;
    if (!settings.voice_agent_config || typeof settings.voice_agent_config !== 'object') return false;
    // Validate each agent config
    for (const [agent, config] of Object.entries(settings.voice_agent_config)) {
        if (!config || typeof config !== 'object') return false;
        if (!config.model || typeof config.model !== 'string') return false;
        if (!config.url || typeof config.url !== 'string') return false;
    }
    // mcp_config_path and active_voice_agent can be empty, but must exist
    if (!('mcp_config_path' in settings)) return false;
    if (!('active_voice_agent' in settings)) return false;
    return true;
}

// Async function to load settings from file, merging with defaults and error recovery
async function loadSettingsAsync() {
    return new Promise((resolve) => {
        fs.readFile(SETTINGS_FILE, 'utf8', (err, data) => {
            if (err) {
                if (err.code === 'ENOENT') {
                    // File does not exist, return defaults
                    resolve({ ...DEFAULT_SETTINGS });
                } else {
                    // On read error, log and return defaults
                    console.error('[settingsApi] Error reading settings.json:', err);
                    resolve({ ...DEFAULT_SETTINGS });
                }
            } else {
                try {
                    const loaded = JSON.parse(data);
                    // Merge loaded settings with defaults
                    resolve({ ...DEFAULT_SETTINGS, ...loaded });
                } catch (e) {
                    // On parse error, log and return defaults
                    console.error('[settingsApi] Corrupted settings.json, using defaults:', e);
                    resolve({ ...DEFAULT_SETTINGS });
                }
            }
        });
    });
}

// Async function to save settings to file, with validation
async function saveSettingsAsync(settings) {
    return new Promise((resolve, reject) => {
        if (!validateSettings(settings)) {
            return reject(new Error('Invalid settings: missing required fields or agent config is incomplete (model/url required for each agent).'));
        }
        fs.writeFile(SETTINGS_FILE, JSON.stringify(settings, null, 2), 'utf8', (err) => {
            if (err) reject(err);
            else resolve();
        });
    });
}

/**
 * HTTP GET /api/settings - Returns the current settings
 */
router.get('/', async (req, res) => {
    try {
        const settings = await loadSettingsAsync();
        res.json(settings);
    } catch (err) {
router.get('/', async (req, res) => {
    console.log('[settingsApi] GET /api/settings called');
    try {
        const settings = await loadSettingsAsync();
        console.log('[settingsApi] Loaded settings:', settings);
        res.json(settings);
    } catch (err) {
        console.error('[settingsApi] Error in GET /api/settings:', err);
        res.status(500).json({ error: 'Failed to load settings', details: err.message });
    }
});
        res.status(500).json({ error: 'Failed to load settings', details: err.message });
    }
});

/**
 * HTTP POST /api/settings - Updates the settings
 * Expects JSON body with the full settings object
 */
router.post('/', async (req, res) => {
    try {
        const settings = req.body;
        await saveSettingsAsync(settings);
        res.json({ success: true });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
});

module.exports = router;

module.exports.loadSettingsAsync = loadSettingsAsync;
module.exports.saveSettingsAsync = saveSettingsAsync;
module.exports.DEFAULT_SETTINGS = DEFAULT_SETTINGS;
module.exports.SETTINGS_FILE = SETTINGS_FILE;
module.exports.validateSettings = validateSettings;