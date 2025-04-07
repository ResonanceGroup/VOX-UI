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

// Initialize when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.settings = new Settings();
    
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
