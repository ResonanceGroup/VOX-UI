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
            // Only prevent default if we're not in the MCP settings group
            if (!e.target.closest('#mcp-settings-group')) {
                e.preventDefault();
            }
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
    let editor = null;
    let originalConfig = '';
    const saveBtn = document.getElementById('save-mcp-config-btn');
    const cancelBtn = document.getElementById('cancel-mcp-config-btn');
    const copyBtn = document.getElementById('copy-mcp-config-btn');

    function setupMonaco() {
        require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs' }});
        require(['vs/editor/editor.main'], function() {
            // Set Monaco options based on current theme
            const isDark = document.documentElement.dataset.theme === 'dark';
            
            // Override Monaco editor default styles for dark mode
            if (isDark) {
                monaco.editor.defineTheme('custom-dark', {
                    base: 'vs-dark',
                    inherit: true,
                    rules: [
                        { token: '', foreground: 'd4d4d4' },
                        { token: 'string', foreground: 'ce9178' },
                        { token: 'number', foreground: 'b5cea8' },
                        { token: 'keyword', foreground: '569cd6' }
                    ],
                    colors: {
                        'editor.background': '#1e1e1e',
                        'editor.foreground': '#d4d4d4',
                        'editorCursor.foreground': '#d4d4d4',
                        'editor.lineHighlightBackground': '#2a2d2e',
                        'editorLineNumber.foreground': '#858585'
                    }
                });
            }
            
            // Create the editor
            editor = monaco.editor.create(document.getElementById('monaco-editor'), {
                language: 'json',
                theme: isDark ? 'custom-dark' : 'vs',
                automaticLayout: true,
                minimap: { enabled: false },
                scrollBeyondLastLine: false,
                formatOnPaste: true,
                formatOnType: true,
                fontSize: 14,
                lineNumbers: 'on',
                renderLineHighlight: 'all',
                scrollbar: {
                    vertical: 'auto',
                    horizontal: 'auto',
                    verticalScrollbarSize: 10,
                    horizontalScrollbarSize: 10,
                    verticalHasArrows: false,
                    horizontalHasArrows: false,
                    useShadows: false
                }
            });

            // Load initial config
            fetch('/api/mcp/config')
                .then(async res => {
                    if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
                    return res.json();
                })
                .then(config => {
                    originalConfig = JSON.stringify(config, null, 2);
                    editor.setValue(originalConfig);
            // Handle editor focus events
            editor.onDidFocusEditorText(() => {
                const wrapper = document.querySelector('.editor-wrapper');
                if (wrapper) {
                    wrapper.style.borderColor = 'var(--settings-input-focus-border, #3498db)';
                    wrapper.style.boxShadow = '0 0 0 3px var(--settings-input-focus-shadow, rgba(52, 152, 219, 0.2))';
                }
            });
            
            editor.onDidBlurEditorText(() => {
                const wrapper = document.querySelector('.editor-wrapper');
                if (wrapper) {
                    wrapper.style.borderColor = 'var(--settings-input-border, #ccc)';
                    wrapper.style.boxShadow = 'none';
                }
            });

                    monaco.editor.getModelMarkers().forEach(marker => {
                        if (marker.severity === monaco.MarkerSeverity.Error) {
                            if (typeof showToast === 'function') showToast('Invalid JSON in config file');
                        }
                    });
                    saveBtn.disabled = true;
                    cancelBtn.disabled = true;
                })
                .catch(err => {
                    console.error('Error fetching MCP config:', err);
                    editor.setValue('// Failed to load MCP config:\n// ' + err.message);
                    if (typeof showToast === 'function') showToast('Failed to load config: ' + err.message);
                });

            // Handle changes
            editor.onDidChangeModelContent(() => {
                const currentValue = editor.getValue();
                const modified = currentValue !== originalConfig;
                saveBtn.disabled = !modified;
                cancelBtn.disabled = !modified;
            });

            // Save button handler
            saveBtn.addEventListener('click', (event) => {
                event.preventDefault();
                event.stopPropagation();
                try {
                    const content = editor.getValue();
                    const configObj = JSON.parse(content);
                    fetch('/api/mcp/config', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(configObj)
                    })
                    .then(res => res.json())
                    .then(result => {
                        if (result.success) {
                            originalConfig = content;
                            saveBtn.disabled = true;
                            cancelBtn.disabled = true;
                            if (typeof showToast === 'function') showToast('MCP config saved successfully!');
                        } else {
                            throw new Error(result.error || 'Save operation failed');
                        }
                    })
                    .catch(err => {
                        console.error('Error saving MCP config:', err);
                        if (typeof showToast === 'function') showToast('Failed to save config: ' + err.message);
                    });
                } catch (e) {
                    if (typeof showToast === 'function') showToast('Invalid JSON: ' + e.message);
                }
            });

            // Revert button handler
            cancelBtn.addEventListener('click', (event) => {
                event.preventDefault();
                event.stopPropagation();
                // Reload the config from the backend without page navigation
                fetch('/api/mcp/config')
                    .then(async res => {
                        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
                        return res.json();
                    })
                    .then(config => {
                        originalConfig = JSON.stringify(config, null, 2);
                        editor.setValue(originalConfig);
                        saveBtn.disabled = true;
                        cancelBtn.disabled = true;
                        if (typeof showToast === 'function') showToast('MCP config reverted.');
                    })
                    .catch(err => {
                        console.error('Error fetching MCP config:', err);
                        if (typeof showToast === 'function') showToast('Failed to reload config: ' + err.message);
                    });
            });

            // Copy button handler
            copyBtn.addEventListener('click', () => {
                const content = editor.getValue();
                navigator.clipboard.writeText(content).then(() => {
                    copyBtn.classList.add('copied');
                    setTimeout(() => copyBtn.classList.remove('copied'), 1000);
                    if (typeof showToast === 'function') showToast('Config copied to clipboard!');
                });
            });

            // Theme change handler
            const observer = new MutationObserver((mutations) => {
                mutations.forEach((mutation) => {
                    if (mutation.attributeName === 'data-theme') {
                        const isDark = document.documentElement.dataset.theme === 'dark';
                        
                        // Define custom dark theme if it's dark mode
                        if (isDark) {
                            monaco.editor.defineTheme('custom-dark', {
                                base: 'vs-dark',
                                inherit: true,
                                rules: [
                                    { token: '', foreground: 'd4d4d4' },
                                    { token: 'string', foreground: 'ce9178' },
                                    { token: 'number', foreground: 'b5cea8' },
                                    { token: 'keyword', foreground: '569cd6' }
                                ],
                                colors: {
                                    'editor.background': '#1e1e1e',
                                    'editor.foreground': '#d4d4d4',
                                    'editorCursor.foreground': '#d4d4d4',
                                    'editor.lineHighlightBackground': '#2a2d2e',
                                    'editorLineNumber.foreground': '#858585'
                                }
                            });
                            monaco.editor.setTheme('custom-dark');
                        } else {
                            monaco.editor.setTheme('vs');
                        }
                        
                        // Update the wrapper styles for theme changes with !important flag
                        const wrapper = document.querySelector('.editor-wrapper');
                        if (wrapper) {
                            if (isDark) {
                                wrapper.style.setProperty('border-color', '#555', 'important');
                                wrapper.style.setProperty('background-color', '#1e1e1e', 'important');
                            } else {
                                wrapper.style.setProperty('border-color', '#ccc', 'important');
                                wrapper.style.setProperty('background-color', '#fff', 'important');
                            }
                        }
                    }
                });
            });
            observer.observe(document.documentElement, { attributes: true });
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setupMonaco);
    } else {
        setupMonaco();
    }
})();


// --- MCP Config Syntax Highlighting ---

