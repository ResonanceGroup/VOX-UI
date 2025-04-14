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
    if (browseButton) {
        browseButton.addEventListener('click', () => {
            // NOTE: Standard browser JS cannot directly open a file dialog for path selection.
            // This would typically require backend integration (e.g., in Electron)
            // or using an <input type="file"> for uploads.
            alert('File browsing requires backend integration (e.g., Electron) or file upload mechanism.');
            // Example: Trigger a hidden file input if using upload approach
            // document.getElementById('hidden-file-input')?.click();
        });
    }