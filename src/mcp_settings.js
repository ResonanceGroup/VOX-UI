// src/mcp_settings.js

document.addEventListener('DOMContentLoaded', () => {
    // --- Settings Fetch & Populate ---
    fetch('/api/settings')
        .then(res => res.json())
        .then(settings => {
            // Populate theme radio
            if (settings.theme) {
                const themeInput = document.querySelector(`input[name="theme"][value="${settings.theme}"]`);
                if (themeInput) {
                    themeInput.checked = true;
                    // Apply initial theme
                    if (typeof applyTheme === 'function') applyTheme(settings.theme);
                }
            }
            // Populate agent config fields
            const agentType = settings.active_voice_agent;
            const agentConfig = settings.voice_agent_config?.[agentType] || {};

            const urlInput = document.getElementById('voice-agent-url');
            const promptInput = document.getElementById('voice-agent-prompt');
            const modelSelect = document.getElementById('voice-agent-model');
            const voiceInput = document.getElementById('voice-agent-voice');
            const languageSelect = document.getElementById('voice-agent-language');
            const mcpPathInput = document.getElementById('mcp-config-path'); // Get MCP path input

            if (urlInput) urlInput.value = agentConfig.url || '';
            if (promptInput) promptInput.value = agentConfig.prompt || ''; // Assuming prompt is part of config
            if (modelSelect) modelSelect.value = agentConfig.model || '';
            if (voiceInput) voiceInput.value = agentConfig.voice_id || agentConfig.voice || ''; // Check both possible keys
            if (languageSelect) languageSelect.value = agentConfig.language || 'en'; // Default to 'en'
            if (mcpPathInput) mcpPathInput.value = settings.mcp_config_path || ''; // Populate MCP path

        })
        .catch(err => {
            console.error('Failed to load settings:', err);
            alert('Failed to load settings from server.');
        });

    // --- Settings Form Submission ---
    const form = document.querySelector('.settings-form');
    if (form) {
        form.addEventListener('submit', function (e) {
            e.preventDefault();
            // Gather settings from form
            const theme = document.querySelector('input[name="theme"]:checked')?.value || 'light';
            const url = document.getElementById('voice-agent-url')?.value || '';
            const prompt = document.getElementById('voice-agent-prompt')?.value || '';
            const model = document.getElementById('voice-agent-model')?.value || '';
            const voice = document.getElementById('voice-agent-voice')?.value || '';
            const language = document.getElementById('voice-agent-language')?.value || 'en';
            const mcp_config_path = document.getElementById('mcp-config-path')?.value || ''; // Get MCP path

            // Determine active agent (assuming model select determines this for now)
            const active_voice_agent = model; // Or get from a dedicated selector if available

            const settings = {
                theme,
                mcp_config_path,
                active_voice_agent,
                voice_agent_config: {
                    [active_voice_agent]: { model, url, prompt, voice, language } // Use correct keys
                }
            };

            // Basic frontend validation (matching backend)
            if (!model || !url) {
                alert('Agent Model and URL are required.');
                return;
            }

            fetch('/api/settings', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(settings)
            })
            .then(res => res.json())
            .then(result => {
                if (result.success) {
                    if (typeof showToast === 'function') showToast('Settings saved!');
                    // Navigate back to index.html after successful save
                    window.location.href = 'index.html';
                } else {
                    alert('Failed to save settings: ' + (result.error || 'Unknown error'));
                }
            })
            .catch(err => {
                alert('Failed to save settings: ' + err.message);
            });
        });
    }

    // Sidebar logic moved to shared_ui.js

    // Accordion logic moved to shared_ui.js
});

// Add event listener for theme radio buttons
document.querySelectorAll('input[name="theme"]').forEach(radio => {
    radio.addEventListener('change', () => {
        if (radio.checked && typeof applyTheme === 'function') {
            applyTheme(radio.value);
        }
    });
});

// --- MCP Config Editor Logic ---
// --- MCP Config Editor Logic (Refactored) ---
(function() {
    const mcpTextarea = document.getElementById('mcp-config-textarea');
    const saveBtn = document.getElementById('save-mcp-config-btn');
    const cancelBtn = document.getElementById('cancel-mcp-config-btn');
    const copyBtn = document.getElementById('copy-mcp-config-btn');
    const highlightPre = document.getElementById('mcp-config-highlight');
    let originalConfig = '';

    function highlightJSON(json) {
        let html = json
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/("[^"]+":)/g, '<span style="color:#9cdcfe;">$1</span>')
            .replace(/("[^"]*")/g, '<span style="color:#ce9178;">$1</span>')
            .replace(/\b(true|false|null)\b/g, '<span style="color:#569cd6;">$1</span>')
            .replace(/\b(-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)\b/g, '<span style="color:#b5cea8;">$1</span>');
        return html;
    }

    function syncHighlight() {
        if (highlightPre && mcpTextarea) {
            highlightPre.innerHTML = highlightJSON(mcpTextarea.value);
            highlightPre.scrollTop = mcpTextarea.scrollTop;
        }
    }

    function setupMcpConfigEditor() {
        if (!(mcpTextarea && saveBtn && cancelBtn && copyBtn)) return;
        fetch('/api/mcp/config')
            .then(async res => { // Make async to potentially read text body on error
                if (!res.ok) {
                    // Attempt to get more specific error text from the response body
                    let errorText = `HTTP error! status: ${res.status}`;
                    try {
                        const text = await res.text(); // Read body as text
                        errorText = `${errorText} - ${text}`;
                    } catch (e) { /* Ignore if reading text fails */ }
                    throw new Error(errorText); // Throw an error to be caught below
                }
                // Check content type before parsing JSON
                const contentType = res.headers.get("content-type");
                if (contentType && contentType.indexOf("application/json") !== -1) {
                    return res.json(); // Only parse if it's JSON
                } else {
                    // Handle non-JSON responses if necessary, or throw error
                    const text = await res.text();
                    console.warn('Received non-JSON response from /api/mcp/config:', text);
                    // Treat as empty config or show specific message? For now, treat as empty.
                    return {}; // Return empty object or handle as error
                    // throw new Error('Received non-JSON response from server');
                }
            })
            .then(config => {
                // Ensure config is an object before stringifying
                const configText = (typeof config === 'object' && config !== null)
                                    ? JSON.stringify(config, null, 2)
                                    : '{}'; // Default to empty JSON object if not valid object
                mcpTextarea.value = configText;
                originalConfig = configText;
                saveBtn.disabled = true;
                syncHighlight();
            })
            .catch(err => {
                console.error('Error fetching MCP config:', err); // Log the full error
                mcpTextarea.value = `// Failed to load MCP config:\n// ${err.message}`; // Show detailed error
                mcpTextarea.style.color = 'red';
                saveBtn.disabled = true;
                syncHighlight();
            });
        mcpTextarea.addEventListener('input', () => {
            saveBtn.disabled = (mcpTextarea.value === originalConfig);
            syncHighlight();
        });
        saveBtn.addEventListener('click', () => {
            let configObj;
            try {
                configObj = JSON.parse(mcpTextarea.value);
            } catch (e) {
                alert('Invalid JSON: ' + e.message);
                return;
            }
            fetch('/api/mcp/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(configObj)
            })
            .then(async res => { // Make async to read body on error
                if (!res.ok) {
                    // Attempt to get more specific error text from the response body
                    let errorText = `HTTP error! status: ${res.status}`;
                    try {
                        const text = await res.text(); // Read body as text
                        errorText = `${errorText} - ${text}`;
                    } catch (e) { /* Ignore if reading text fails */ }
                    throw new Error(errorText); // Throw an error to be caught below
                }
                 // Check content type before parsing JSON, although success should be JSON
                const contentType = res.headers.get("content-type");
                if (contentType && contentType.indexOf("application/json") !== -1) {
                    return res.json(); // Only parse if it's JSON
                } else {
                    // Handle unexpected non-JSON success response if necessary
                     const text = await res.text();
                     console.warn('Received non-JSON success response when saving MCP config:', text);
                     // Assume success based on status code, but log warning
                     return { success: true }; // Or handle differently
                }
            })
            .then(result => {
                if (result.success) {
                    originalConfig = mcpTextarea.value; // Update original config on successful save
                    saveBtn.disabled = true;
                    if (typeof showToast === 'function') showToast('MCP config saved!');
                } else {
                    // Use the error message from the JSON result if available
                    alert('Failed to save config: ' + (result.error || 'Save operation reported failure.'));
                }
            })
            .catch(err => {
                 console.error('Error saving MCP config:', err); // Log the full error
                // Display the detailed error message from the thrown Error
                alert('Failed to save config: ' + err.message);
            });
        });
        cancelBtn.addEventListener('click', () => {
            mcpTextarea.value = originalConfig;
            saveBtn.disabled = true;
            syncHighlight();
        });
        copyBtn.addEventListener('click', () => {
            mcpTextarea.select();
            document.execCommand('copy');
            copyBtn.classList.add('copied');
            setTimeout(() => copyBtn.classList.remove('copied'), 1000);
        });
        mcpTextarea.addEventListener('input', syncHighlight);
        mcpTextarea.addEventListener('scroll', () => {
            if (highlightPre) highlightPre.scrollTop = mcpTextarea.scrollTop;
        });
        syncHighlight();
        mcpTextarea.addEventListener('keydown', function(e) {
            if (e.key === 'Tab') {
                e.preventDefault();
                const start = this.selectionStart;
                const end = this.selectionEnd;
                const value = this.value;
                this.value = value.substring(0, start) + '    ' + value.substring(end);
                this.selectionStart = this.selectionEnd = start + 4;
                syncHighlight();
            }
        });
    }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setupMcpConfigEditor);
    } else {
        setupMcpConfigEditor();
    }
})();


// --- MCP Config Syntax Highlighting ---

