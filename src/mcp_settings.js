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

    // --- Accordion Logic ---
    const groups = document.querySelectorAll('.settings-group.accordion');
    groups.forEach(group => {
        const header = group.querySelector('.settings-group-header');
        const details = group.querySelector('.settings-group-details');
        if (header && details) {
            header.addEventListener('click', () => {
                const isOpen = group.classList.toggle('open');
                if (isOpen) {
                    details.style.display = '';
                } else {
                    details.style.display = 'none';
                }
            });
            // Ensure initial state matches class
            if (!group.classList.contains('open')) {
                details.style.display = 'none';
            }
        }
    });
});

// Add event listener for theme radio buttons
document.querySelectorAll('input[name="theme"]').forEach(radio => {
    radio.addEventListener('change', () => {
        if (radio.checked && typeof applyTheme === 'function') {
            applyTheme(radio.value);
        }
    });
});

    // --- Browse Button Placeholder ---
    const browseButton = document.getElementById('browse-mcp-config');
    const fileInput = document.getElementById('hidden-mcp-file-input');
    const configPathInput = document.getElementById('mcp-config-path');
    if (browseButton && fileInput && configPathInput) {
        browseButton.addEventListener('click', () => {
            fileInput.value = ''; // Reset file input
            fileInput.click();
        });
        fileInput.addEventListener('change', (e) => {
            if (fileInput.files && fileInput.files.length > 0) {
                // Browsers only provide the file name, not the full path
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
            .then(res => res.json())
            .then(config => {
                const configText = typeof config === 'string' ? config : JSON.stringify(config, null, 2);
                mcpTextarea.value = configText;
                originalConfig = configText;
                saveBtn.disabled = true;
                syncHighlight();
            })
            .catch(err => {
                mcpTextarea.value = '// Failed to load MCP config: ' + err.message;
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
            .then(res => res.json())
            .then(result => {
                if (result.success) {
                    originalConfig = mcpTextarea.value;
                    saveBtn.disabled = true;
                    if (typeof showToast === 'function') showToast('MCP config saved!');
                } else {
                    alert('Failed to save config: ' + (result.error || 'Unknown error'));
                }
            })
            .catch(err => {
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


                configPathInput.value = fileInput.files[0].name;
            }
        });
    }
// --- MCP Config Syntax Highlighting ---

// --- Open MCP group if hash is #mcp ---
if (window.location.hash === '#mcp') {
    const mcpGroup = Array.from(document.querySelectorAll('.settings-group.accordion')).find(g => g.querySelector('.settings-group-header')?.textContent?.toLowerCase().includes('mcp'));
    if (mcpGroup) {
        mcpGroup.classList.add('open');
        const details = mcpGroup.querySelector('.settings-group-details');
        if (details) details.style.display = '';
        mcpGroup.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
}
