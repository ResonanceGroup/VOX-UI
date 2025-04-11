// Settings management
class Settings {
    constructor() {
        // Default settings
        this.settings = {
            theme: 'system',
            n8nwebhook: '',
            ultravoxurl: ''
        };

        this.debug = true;
        this.log('Settings initialized with defaults:', this.settings);

        // Initialize settings
        this.load();
        this.setupListeners();
        // Apply theme only after loading settings (handled in load())

        // Handle system theme changes
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
            this.applyTheme();
        });
    }

    log(...args) {
        if (this.debug) {
            console.log('[Settings]', ...args);
        }
    }

    async load() {
        try {
            const response = await fetch('/api/settings');
            if (!response.ok) throw new Error('Failed to load settings');
            const data = await response.json();
            this.settings = { ...this.settings, ...data };
            this.log('Successfully loaded settings:', this.settings); // Restore original log
        } catch (e) {
            console.error('Error loading settings:', e);
            // Keep using defaults
        }
        this.updateInputs();
        this.applyTheme();
    }

    async save() {
        try {
            const response = await fetch('/api/settings', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(this.settings)
            });
            if (!response.ok) throw new Error('Failed to save settings');
            const result = await response.json();
            this.log('Successfully saved settings:', this.settings);
        } catch (e) {
            console.error('Error saving settings:', e);
        }
    }

    updateInputs() {
        // Update input values
        const n8nInput = document.getElementById('n8n-webhook');
        const ultravoxInput = document.getElementById('ultravox-url');
        
        if (n8nInput) {
            n8nInput.value = this.settings.n8nwebhook || '';
            this.log('Updated n8n webhook input:', n8nInput.value);
        }
        if (ultravoxInput) {
            ultravoxInput.value = this.settings.ultravoxurl || '';
            this.log('Updated ultravox URL input:', ultravoxInput.value);
        }
        
        // Update theme radio inputs
        const themeInput = document.querySelector(`input[name="theme"][value="${this.settings.theme}"]`);
        if (themeInput) {
            themeInput.checked = true;
            this.log('Set active theme radio:', themeInput.value);
        }
    }

    applyTheme() {
        const theme = this.settings.theme;
        const effectiveTheme = theme === 'system' ? 
            window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
            : theme;
        document.documentElement.dataset.theme = effectiveTheme;
        this.log('Applied theme:', theme, '(effective:', effectiveTheme, ')');
    }

    setupListeners() {
        // Theme switching
        document.querySelectorAll('input[name="theme"]').forEach(radio => {
            radio.addEventListener('change', () => {
                if (radio.checked) {
                    this.settings.theme = radio.value;
                    this.applyTheme();
                    this.log('Theme changed to:', radio.value);
                }
            });
        });

        // Settings form
        const settingsForm = document.querySelector('.settings-form');
        if (settingsForm) {
            settingsForm.addEventListener('submit', async (e) => { // Make listener async
                e.preventDefault();
                await this.saveSettings(); // Await the save operation
                window.location.href = 'index.html';
            });
        }

        // Input fields
        const n8nInput = document.getElementById('n8n-webhook');
        const ultravoxInput = document.getElementById('ultravox-url');

        [n8nInput, ultravoxInput].forEach(input => {
            if (!input) return;

            const updateValue = () => {
                const key = input.id.replace(/-/g, '');
                this.settings[key] = input.value;
                this.log(`Updated ${key}:`, input.value);
            };

            ['input', 'change', 'blur'].forEach(eventType => {
                input.addEventListener(eventType, updateValue);
                this.log(`Added ${eventType} listener to:`, input.id);
            });
        });
    }

    saveSettings() {
        return this.save(); // Return the promise from save()
    }
}

// WebSocket Client Class
class WebSocketClient {
    constructor(url) {
        this.url = url;
        this.ws = null;
        this.reconnectInterval = 5000; // 5 seconds
        this.debug = true; // Enable logging
        this.log('WebSocketClient initialized.');
        this.connect();
    }

    log(...args) {
        if (this.debug) {
            console.log('[WebSocketClient]', ...args);
        }
    }

    connect() {
        this.log(`Attempting to connect WebSocket to ${this.url}...`);
        try {
            this.ws = new WebSocket(this.url);
        } catch (error) {
            console.error('[WebSocketClient] Error creating WebSocket:', error);
            this.scheduleReconnect();
            return;
        }


        this.ws.onopen = () => {
            this.log('Connection established.');
            // Future: Send init_session message here
            // this.sendMessage('init_session', {});
        };

        this.ws.onmessage = (event) => {
            try {
                const message = JSON.parse(event.data);
                this.log('Message received:', message);
                // TODO: Add logic to handle different message types based on protocol
            } catch (error) {
                console.error('[WebSocketClient] Failed to parse message:', error, 'Raw data:', event.data);
            }
        };

        this.ws.onerror = (error) => {
            console.error('[WebSocketClient] WebSocket error:', error);
            // onclose will likely be called next, triggering reconnection.
        };

        this.ws.onclose = (event) => {
            this.log(`Connection closed. Code: ${event.code}, Reason: '${event.reason}'. Reconnecting in ${this.reconnectInterval / 1000}s...`);
            this.ws = null; // Clear the old socket object
            this.scheduleReconnect();
        };
    }

    scheduleReconnect() {
         // Avoid multiple reconnect timers
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
        }
        this.reconnectTimer = setTimeout(() => {
            this.log('Attempting reconnect...');
            this.connect();
        }, this.reconnectInterval);
    }

    sendMessage(type, payload) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            try {
                const message = JSON.stringify({ type, payload });
                this.log('Sending message:', { type, payload });
                this.ws.send(message);
            } catch (error) {
                 console.error('[WebSocketClient] Error sending message:', error, { type, payload });
            }
        } else {
            console.error('[WebSocketClient] WebSocket not open. Cannot send message:', { type, payload });
            // Optional: Implement message queuing if needed
        }
    }
}

// Initialize when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.settings = new Settings();
    // Initialize WebSocket Client
    console.log('Initializing WebSocket client...');
    const websocketUrl = `wss://${window.location.hostname}:3002`; // Use hostname and specific port
    // Fallback for local development if hostname isn't resolving correctly or for file:// protocol
    // const websocketUrl = 'wss://localhost:3002'; 
    window.wsClient = new WebSocketClient(websocketUrl);
    // Helper for easy console access
    window.sendWebSocketMessage = (type, payload) => window.wsClient.sendMessage(type, payload);
    console.log('WebSocket client setup complete. Access via window.wsClient or sendWebSocketMessage(type, payload).');

    
    // Get UI elements
    const menuButton = document.querySelector('.menu-button');
    const sidebar = document.querySelector('.sidebar');
    const overlay = document.querySelector('.overlay');



    
    // Handle sidebar toggle
    function toggleSidebar() {
        sidebar.classList.toggle('open');
        overlay.classList.toggle('visible');
    }
    
    menuButton?.addEventListener('click', toggleSidebar);
    overlay?.addEventListener('click', toggleSidebar);

    // Set active sidebar item based on current page
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    document.querySelectorAll('.sidebar-item').forEach(item => {
        const itemPage = item.getAttribute('href').split('/').pop();
        if (itemPage === currentPage) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });


    // Accordion logic for settings page
    document.querySelectorAll('.settings-group-header').forEach(header => {
        header.addEventListener('click', () => {
            const group = header.closest('.settings-group.accordion');
            if (group) {
                group.classList.toggle('open');
                const details = group.querySelector('.settings-group-details');
                if (details) {
                    // Toggle display based on 'open' class presence
                    details.style.display = group.classList.contains('open') ? 'block' : 'none';
                }
            }
        });
    });

    // Initialize audio visualizer if on chat page
    if (currentPage === 'index.html' && window.AudioVisualizer) {
        window.audioVisualizer = new AudioVisualizer();
    }
});
