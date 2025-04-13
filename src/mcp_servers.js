document.addEventListener('DOMContentLoaded', () => {
    const serverListContainer = document.querySelector('.mcp-server-list');
    const editMcpServersButton = document.querySelector('.mcp-settings-actions .button.primary');

    // --- Fetch and Render Servers ---
    async function fetchAndRenderServers() {
        try {
            const response = await fetch('/api/mcp/servers');
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const servers = await response.json();
            renderServerList(servers);
        } catch (error) {
            console.error('Error fetching MCP servers:', error);
            serverListContainer.innerHTML = '<p class="error-message">Failed to load MCP server list. Please try again later.</p>';
        }
    }

    function renderServerList(servers) {
        if (!serverListContainer) return;
        serverListContainer.innerHTML = ''; // Clear existing sample data or previous list

        if (!servers || servers.length === 0) {
            serverListContainer.innerHTML = '<p>No MCP servers configured.</p>';
            return;
        }

        servers.forEach((server, index) => { // Added index for potential default open
            const serverItem = document.createElement('div');
            serverItem.classList.add('mcp-server-item', 'accordion');
            // Example: Open the first server by default
            // if (index === 0) serverItem.classList.add('open');

            // Determine status based on server properties (adjust logic as needed)
            let statusClass = 'status-error'; // Default to error
            let statusTitle = 'Unknown Status';
            if (server.enabled === false) {
                statusClass = 'status-disabled'; // Add CSS for this if needed
                statusTitle = 'Disabled';
            } else if (server.status === 'connected' || server.status === 'ok') { // Check for common success statuses
                 statusClass = 'status-ok';
                 statusTitle = 'Connected';
            } else if (server.status) { // If status exists but isn't ok/connected
                statusClass = 'status-error';
                statusTitle = `Error: ${server.status}`;
            }


            // --- Server Header ---
            const header = document.createElement('div');
            header.classList.add('mcp-server-header');
            header.innerHTML = `
                <svg class="expand-icon" viewBox="0 0 16 16" width="16" height="16" fill="currentColor"><path fill-rule="evenodd" d="M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 .708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708z"></path></svg>
                <span class="server-name">${server.name}</span>
                <div class="server-controls">
                    <button class="icon-button refresh-button" title="Refresh">🔄</button>
                    <label class="switch">
                        <input type="checkbox" ${server.enabled ? 'checked' : ''}>
                        <span class="slider round"></span>
                    </label>
                    <span class="status-dot ${statusClass}" title="${statusTitle}"></span>
                </div>
            `;

            // --- Server Details ---
            const details = document.createElement('div');
            details.classList.add('mcp-server-details');
             // Set initial display based on 'open' class (if used)
            details.style.display = serverItem.classList.contains('open') ? 'block' : 'none';

            // Tools rendering
            let toolsHtml = '<p>No tools defined.</p>';
            if (server.tools && server.tools.length > 0) {
                toolsHtml = server.tools.map(tool => `
                    <div class="tool-details">
                        <span class="tool-icon">🔧</span> <!-- Placeholder icon -->
                        <h3>${tool.name}</h3>
                        <p>${tool.description || 'No description provided.'}</p>
                        ${tool.input_schema ? `<div class="parameters"><h4>PARAMETERS</h4><pre><code>${JSON.stringify(tool.input_schema, null, 2)}</code></pre></div>` : ''}
                    </div>
                `).join('');
            }

            // Resources rendering
            let resourcesHtml = '<p>No resources defined.</p>';
             if (server.resources && server.resources.length > 0) {
                resourcesHtml = server.resources.map(resource => `
                    <div class="resource-details"> <!-- Define styling for this -->
                         <span class="resource-icon">📄</span> <!-- Placeholder icon -->
                         <h3>${resource.uri}</h3>
                         <p>${resource.description || 'No description provided.'}</p>
                    </div>
                 `).join('');
             }

            details.innerHTML = `
                <div class="details-tabs">
                    <button class="tab active" data-tab="tools">Tools (${server.tools?.length || 0})</button>
                    <button class="tab" data-tab="resources">Resources (${server.resources?.length || 0})</button>
                </div>
                <div class="details-content">
                    <div class="tab-pane active" data-pane="tools">${toolsHtml}</div>
                    <div class="tab-pane" data-pane="resources" style="display: none;">${resourcesHtml}</div>
                </div>
                 <div class="setting-item"> <!-- Example setting -->
                      <label>Network Timeout</label>
                      <select>
                          <option>1 minute</option>
                          <option>5 minutes</option>
                          <option>15 minutes</option>
                      </select>
                      <p class="description">Maximum time to wait for server responses</p>
                 </div>
            `;

            serverItem.appendChild(header);
            serverItem.appendChild(details);
            serverListContainer.appendChild(serverItem);

            // --- Add Event Listeners ---
            addAccordionListener(header, details, serverItem);
            addToggleListener(header.querySelector('.switch input'), server.name, header.querySelector('.status-dot')); // Pass status dot
            addRefreshListener(header.querySelector('.refresh-button'), server.name);
            addTabListeners(details);
        });
    }

    // --- Event Handlers ---

    function addAccordionListener(header, details, serverItem) {
        header.addEventListener('click', (event) => {
            // Prevent toggle if clicking on controls inside the header
            if (event.target.closest('.server-controls')) {
                return;
            }
            const isOpen = serverItem.classList.toggle('open');
            details.style.display = isOpen ? 'block' : 'none';
            // Optional: Rotate expand icon
            const icon = header.querySelector('.expand-icon');
            if (icon) icon.style.transform = isOpen ? 'rotate(90deg)' : 'rotate(0deg)';
        });
         // Set initial icon rotation if item starts open
         const icon = header.querySelector('.expand-icon');
         if (icon && serverItem.classList.contains('open')) {
             icon.style.transform = 'rotate(90deg)';
         }
    }

    function addToggleListener(toggleInput, serverName, statusDotElement) { // Added statusDotElement
        toggleInput.addEventListener('change', async (event) => {
            const isEnabled = event.target.checked;
            console.log(`Toggling server ${serverName} to ${isEnabled ? 'enabled' : 'disabled'}`);

            // Optimistic UI update for responsiveness
            statusDotElement.classList.remove('status-ok', 'status-error', 'status-disabled');
            statusDotElement.classList.add(isEnabled ? 'status-loading' : 'status-disabled'); // Use a loading state or directly disabled
            statusDotElement.title = isEnabled ? 'Connecting...' : 'Disabled';


            try {
                const response = await fetch(`/api/mcp/servers/${serverName}/toggle`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    // body: JSON.stringify({ enabled: isEnabled }) // Backend determines state based on toggle
                });
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                const result = await response.json();
                console.log('Toggle result:', result);

                // Update UI based on actual response state
                 statusDotElement.classList.remove('status-loading', 'status-disabled', 'status-ok', 'status-error'); // Clear previous states
                 if (result.server.enabled) {
                     const finalStatusClass = result.server.status === 'connected' || result.server.status === 'ok' ? 'status-ok' : 'status-error';
                     const finalStatusTitle = finalStatusClass === 'status-ok' ? 'Connected' : `Error: ${result.server.status || 'Unknown'}`;
                     statusDotElement.classList.add(finalStatusClass);
                     statusDotElement.title = finalStatusTitle;
                 } else {
                     statusDotElement.classList.add('status-disabled');
                     statusDotElement.title = 'Disabled';
                 }
                 // Ensure checkbox matches final state
                 event.target.checked = result.server.enabled;


                // Optional: Re-fetch might be better if toggle causes other state changes
                // fetchAndRenderServers();
            } catch (error) {
                console.error(`Error toggling server ${serverName}:`, error);
                // Revert checkbox and status dot on error
                event.target.checked = !isEnabled;
                statusDotElement.classList.remove('status-loading', 'status-disabled', 'status-ok', 'status-error');
                // Determine previous state to revert to (this is tricky without full re-render)
                // For simplicity, just show error state or re-render fully
                statusDotElement.classList.add('status-error');
                statusDotElement.title = 'Toggle Failed';
                 alert(`Failed to toggle server ${serverName}.`);
                 // Consider full re-render on error for consistency
                 fetchAndRenderServers();
            }
        });
    }

    function addRefreshListener(refreshButton, serverName) {
        refreshButton.addEventListener('click', async (event) => {
            event.stopPropagation(); // Prevent accordion toggle
            console.log(`Refreshing server ${serverName}`);
            refreshButton.disabled = true; // Provide visual feedback
            refreshButton.textContent = '⏳'; // Loading state
            refreshButton.style.cursor = 'wait';

            try {
                const response = await fetch(`/api/mcp/servers/${serverName}/refresh`, { method: 'POST' });
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                const result = await response.json();
                console.log('Refresh result:', result);
                // Re-fetch the list to show updated status/info
                fetchAndRenderServers();
            } catch (error) {
                console.error(`Error refreshing server ${serverName}:`, error);
                alert(`Failed to refresh server ${serverName}.`);
                 // Restore button state even if fetch fails
                 refreshButton.disabled = false;
                 refreshButton.textContent = '🔄';
                 refreshButton.style.cursor = 'pointer';
            }
            // Note: Button state restoration is handled by fetchAndRenderServers on success
            // Only need explicit restore here on error.
        });
    }

     function addTabListeners(detailsContainer) {
        const tabs = detailsContainer.querySelectorAll('.details-tabs .tab');
        const panes = detailsContainer.querySelectorAll('.details-content .tab-pane');

        tabs.forEach(tab => {
            tab.addEventListener('click', (event) => {
                const targetPaneId = event.target.dataset.tab;

                // Update tab active state
                tabs.forEach(t => t.classList.remove('active'));
                event.target.classList.add('active');

                // Update pane visibility
                panes.forEach(pane => {
                    if (pane.dataset.pane === targetPaneId) {
                        pane.style.display = 'block';
                        pane.classList.add('active'); // If using class-based visibility
                    } else {
                        pane.style.display = 'none';
                        pane.classList.remove('active');
                    }
                });
            });
        });
    }

    // --- Edit MCP Servers Button ---
    if (editMcpServersButton) {
        editMcpServersButton.addEventListener('click', async () => {
            console.log('Attempting to open MCP config file...');
            try {
                const response = await fetch('/api/mcp/config/open', { method: 'POST' });
                if (!response.ok) {
                     // Try to read error message from backend if available
                     let errorMsg = `HTTP error! status: ${response.status}`;
                     try {
                         const errorData = await response.json();
                         errorMsg = errorData.message || errorMsg;
                     } catch (e) { /* Ignore if response is not JSON */ }
                     throw new Error(errorMsg);
                }
                console.log('Open config request sent successfully.');
                // Optionally show a success message to the user
                // alert('Attempting to open mcp_config.json in your editor...');
            } catch (error) {
                console.error('Error opening MCP config file:', error);
                alert(`Failed to open MCP config file: ${error.message}`);
            }
        });
    } else {
        console.warn('Edit MCP Servers button not found.');
    }


    // --- Initial Load ---
    fetchAndRenderServers();

});