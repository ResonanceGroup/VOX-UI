// src/mcp_config_editor.js

document.addEventListener('DOMContentLoaded', () => {
    const textarea = document.getElementById('mcp-config-textarea');
    const saveBtn = document.getElementById('save-btn');
    const cancelBtn = document.getElementById('cancel-btn');
    const copyBtn = document.getElementById('copy-btn');

    let originalConfig = '';
    let returnPage = sessionStorage.getItem('mcp_config_return_page') || 'settings.html';

    // Fetch current config
    fetch('/api/mcp/config')
        .then(res => res.json())
        .then(config => {
            const configText = typeof config === 'string' ? config : JSON.stringify(config, null, 2);
            textarea.value = configText;
            originalConfig = configText;
            saveBtn.disabled = true;
        })
        .catch(err => {
            textarea.value = '// Failed to load MCP config: ' + err.message;
            textarea.style.color = 'red';
            saveBtn.disabled = true;
        });

    // Enable Save only if changed
    textarea.addEventListener('input', () => {
        saveBtn.disabled = (textarea.value === originalConfig);
    });

    // Save handler
    saveBtn.addEventListener('click', () => {
        let configObj;
        try {
            configObj = JSON.parse(textarea.value);
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
                window.location.href = returnPage;
            } else {
                alert('Failed to save config: ' + (result.error || 'Unknown error'));
            }
        })
        .catch(err => {
            alert('Failed to save config: ' + err.message);
        });
    });

    // Cancel handler
    cancelBtn.addEventListener('click', () => {
        window.location.href = returnPage;
    });

    // Copy handler
    copyBtn.addEventListener('click', () => {
        textarea.select();
        document.execCommand('copy');
        copyBtn.classList.add('copied');
        setTimeout(() => copyBtn.classList.remove('copied'), 1000);
    });
});