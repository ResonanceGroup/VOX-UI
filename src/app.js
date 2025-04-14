console.log('[app.js] TOP OF FILE - script loaded');
console.log('[app.js] Script execution start.');

// Settings management
class Settings {
    constructor() {
        console.log('[Settings] Constructor called.');
        if (window.settingsInstanceCounter) { window.settingsInstanceCounter++; } else { window.settingsInstanceCounter = 1; }
        console.log(`[Settings] Instance count: ${window.settingsInstanceCounter}`);
        // Default settings
        this.settings = {
            theme: 'system',
        };

        this.debug = true;
        this._loadPromiseResolve = null; // To resolve the load promise
        this.log('Settings initialized with defaults:', this.settings);

        // Initialize settings
        // this.load(); // Correctly commented out
        this.setupListeners();
        // Apply theme only after loading settings (handled in load())

        // Handle system theme changes
        // System theme change listener moved to shared_ui.js
    }

    log(...args) {
        if (this.debug) {
            console.log('[Settings]', ...args);
        }
    }

    load(caller = 'unknown') {
        this.log(`load() called by: ${caller}. Requesting settings via WebSocket...`); // Caller tracking already added
        // Return a promise that resolves when settings are loaded via WebSocket
        return new Promise((resolve, reject) => {
            // Store the resolver function to be called by the WebSocket handler
            this._loadPromiseResolve = resolve;

            // Check if WebSocket is connected and ready
            if (window.wsClient && window.wsClient.ws && window.wsClient.ws.readyState === WebSocket.OPEN) {
                window.wsClient.sendMessage('get_settings', {});
            } else {
                // Fallback: Load from localStorage
                console.warn('WebSocket not ready, loading settings from localStorage.');
                try {
                    const local = localStorage.getItem('voxui_settings');
                    if (local) {
                        this.settings = { ...this.settings, ...JSON.parse(local) };
                        this.log('Loaded settings from localStorage:', JSON.stringify(this.settings));
                        this.log(`Theme value after localStorage load: ${this.settings.theme}`);
                        this.updateInputs();
                        if (typeof applyTheme === 'function') applyTheme(this.settings.theme);
                        resolve(this.settings);
                    } else {
                        this.log('No settings found in localStorage, using defaults.');
                        this.updateInputs();
                        if (typeof applyTheme === 'function') applyTheme(this.settings.theme);
                        resolve(this.settings);
                    }
                } catch (e) {
                    console.error('Failed to load settings from localStorage:', e);
                    reject(e);
                }
            }
        });
    }

    save() {
        this.log('Saving settings...');
        // Validate agent config before saving
        const vac = this.settings.voice_agent_config;
        let valid = true;
        if (!vac || typeof vac !== 'object') valid = false;
        else {
            for (const [agent, config] of Object.entries(vac)) {
                if (!config || typeof config !== 'object' || !config.model || !config.url) {
                    valid = false;
                    break;
                }
            }
        }
        if (!valid) {
            this.log('Invalid settings: each agent config must have model and url.');
            alert('Invalid settings: each agent config must have model and url.');
            return;
        }
        // Always save to localStorage as a fallback
        try {
            localStorage.setItem('voxui_settings', JSON.stringify(this.settings));
            this.log('Settings saved to localStorage:', this.settings);
        } catch (e) {
            console.error('Failed to save settings to localStorage:', e);
        }
        // If WebSocket is connected, also send to server
        if (window.wsClient && window.wsClient.ws && window.wsClient.ws.readyState === WebSocket.OPEN) {
            window.wsClient.sendMessage('update_settings', { settings: this.settings });
            // Note: Confirmation comes via 'settings_update_ack' message
        } else {
            console.warn('WebSocket not ready when trying to save settings. Settings saved locally only.');
        }
    }

    updateInputs() {
        // Update input values
        const n8nInput = document.getElementById('n8n-webhook');
        const ultravoxInput = document.getElementById('ultravox-url');
        
        // Removed legacy n8nwebhook and ultravoxurl input updates
        
        // Update theme radio inputs
        const themeInput = document.querySelector(`input[name="theme"][value="${this.settings.theme}"]`);
        if (themeInput) {
            themeInput.checked = true;
            this.log('Set active theme radio:', themeInput.value);
        }
    }

    // applyTheme method removed, logic moved to shared_ui.js

    setupListeners() {
        // Theme switching
        document.querySelectorAll('input[name="theme"]').forEach(radio => {
            radio.addEventListener('change', () => {
                if (radio.checked) {
                    this.settings.theme = radio.value;
                    if (typeof applyTheme === 'function') applyTheme(radio.value);
                    this.log('Theme radio changed. this.settings.theme is now:', this.settings.theme); // ADDED LOG
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

// Helper function to convert Blob to Base64
function blobToBase64(blob) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onloadend = () => {
            // Remove the data URL prefix (e.g., "data:audio/webm;base64,")
            const base64String = reader.result.split(',')[1];
            resolve(base64String);
        };
        reader.onerror = reject;
        reader.readAsDataURL(blob);
    });
}

// Audio Manager Class
class AudioManager {
    constructor(wsClient) {
        this.wsClient = wsClient;
        this.audioContext = null;
        this.mediaStream = null;
        this.mediaRecorder = null;
        this.audioQueue = [];
        this.isPlaying = false;
        this.isRecording = false;
        this.isMuted = false; // Internal mute state
        this.audioWorkletNode = null;
        this.nextStartTime = 0; // For scheduling playback
        
        // Visualizer integration properties
        this.visualizerAnalyzer = null;
        this.visualizerSource = null;
        this.activeVisualizer = null;

        this.debug = true;
        this.log('AudioManager initialized.');

        // Initialize AudioContext lazily on first playback/capture needed
        
        // Try to find existing visualizer
        this.connectToExistingVisualizer();
    }
    
    // Connect to any existing AudioVisualizer instance
    connectToExistingVisualizer() {
        if (window.audioVisualizer) {
            this.log('Found existing AudioVisualizer instance');
            this.activeVisualizer = window.audioVisualizer;
        }
    }

    log(...args) {
        if (this.debug) {
            console.log('[AudioManager]', ...args);
        }
    }

    _ensureAudioContext() {
        if (!this.audioContext || this.audioContext.state === 'closed') {
            this.log('Creating new AudioContext.');
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            this.nextStartTime = this.audioContext.currentTime; // Reset start time
        } else if (this.audioContext.state === 'suspended') {
            this.log('Resuming suspended AudioContext.');
            this.audioContext.resume();
        }
        return this.audioContext;
    }

    async initAudio() {
        if (this.mediaStream) {
            this.log('Audio already initialized.');
            return true;
        }
        try {
            this.log('Requesting microphone access...');
            this.mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
            this.log('Microphone access granted.');
            this._ensureAudioContext(); // Ensure context is ready for potential recording
            return true;
        } catch (err) {
            console.error('[AudioManager] Error accessing microphone:', err);
            // TODO: Update UI to show error state
            updateUIState('error', { label: 'Microphone access denied.' });
            return false;
        }
    }

    async startRecording() {
        if (this.isRecording) {
            this.log('Already recording.');
            return;
        }
        if (this.isMuted) {
            this.log('Cannot start recording: Muted.');
            // Optionally provide feedback to the user
            return;
        }

        const hasMicAccess = await this.initAudio();
        if (!hasMicAccess || !this.mediaStream) {
            this.log('Cannot start recording: No microphone access or stream.');
            return;
        }

        try {
            this._ensureAudioContext(); // Ensure context is active
            this.log('Starting recording...');
            // Experiment with timeslice for smaller chunks
            const options = { mimeType: 'audio/webm;codecs=opus', audioBitsPerSecond: 16000, timeslice: 250 }; // 250ms chunks
            this.mediaRecorder = new MediaRecorder(this.mediaStream, options);

            this.mediaRecorder.ondataavailable = async (event) => {
                if (event.data.size > 0) {
                    this.log(`Audio data available, size: ${event.data.size}`);
                    try {
                        const base64String = await blobToBase64(event.data);
                        this.wsClient.sendMessage('audio_chunk', { chunk: base64String });
                        this.log('Sent audio chunk.');
                    } catch (error) {
                        console.error('[AudioManager] Error converting blob to Base64:', error);
                    }
                }
            };

            this.mediaRecorder.onstop = () => {
                this.log('Recording stopped.');
                this.isRecording = false;
                // Send end stream message only if recording was actually started
                if (this.mediaRecorder.state !== 'inactive') { // Check state before sending
                   this.wsClient.sendMessage('end_audio_stream', {});
                   this.log('Sent end_audio_stream message.');
                }
                 // Clean up stream tracks? Maybe not here, keep stream for reuse?
                // this.mediaStream.getTracks().forEach(track => track.stop());
                // this.mediaStream = null;
                // this.mediaRecorder = null; // Clean up recorder instance
                if (typeof updateUIState === 'function' && currentAIState === 'listening') { // Check global state
                    updateUIState('idle'); // Or revert to previous state if needed
                }
            };

            this.mediaRecorder.onerror = (event) => {
                console.error('[AudioManager] MediaRecorder error:', event.error);
                this.isRecording = false;
                 if (typeof updateUIState === 'function') {
                    updateUIState('error', { label: 'Recording error.' });
                }
            };

            this.mediaRecorder.start(options.timeslice); // Start recording with timeslice
            this.isRecording = true;
            if (typeof updateUIState === 'function') {
                updateUIState('listening');
            }
            this.log('MediaRecorder started.');

        } catch (error) {
            console.error('[AudioManager] Error starting MediaRecorder:', error);
             if (typeof updateUIState === 'function') {
                updateUIState('error', { label: 'Failed to start recording.' });
            }
        }
    }

    stopRecording() {
        if (!this.isRecording || !this.mediaRecorder || this.mediaRecorder.state === 'inactive') {
            this.log('Not recording or recorder inactive.');
            return;
        }
        this.log('Stopping recording...');
        try {
            this.mediaRecorder.stop(); // This will trigger the onstop event
        } catch (error) {
             console.error('[AudioManager] Error stopping MediaRecorder:', error);
             // Force state update if stop fails
             this.isRecording = false;
             if (typeof updateUIState === 'function' && currentAIState === 'listening') {
                 updateUIState('idle');
             }
        }
        // Note: onstop handles sending the end_audio_stream message
    }

    async handleAudioResponse(base64Chunk) {
        this.log('Received audio response chunk.');
        try {
            const audioContext = this._ensureAudioContext();
            const binaryString = window.atob(base64Chunk);
            const len = binaryString.length;
            const bytes = new Uint8Array(len);
            for (let i = 0; i < len; i++) {
                bytes[i] = binaryString.charCodeAt(i);
            }
            const audioBuffer = await audioContext.decodeAudioData(bytes.buffer);
            this.log('Decoded audio buffer.');
            this.schedulePlayback(audioBuffer);

            // Connect to visualizer if available
            if (window.audioVisualizer) {
                try {
                    // Create analyzer if we don't have one
                    if (!this.visualizerAnalyzer) {
                        this.visualizerAnalyzer = this.audioContext.createAnalyser();
                        this.visualizerAnalyzer.fftSize = 2048;
                        this.visualizerAnalyzer.smoothingTimeConstant = 0.8;
                    }
                    
                    // Connect our playback to the analyser node
                    if (this.visualizerSource) {
                        this.visualizerSource.connect(this.visualizerAnalyzer);
                        this.log('Connected playback to visualizer analyzer node');
                    }
                } catch (error) {
                    console.error('[AudioManager] Error connecting to visualizer:', error);
                }
            }

        } catch (error) {
            console.error('[AudioManager] Error decoding or scheduling audio:', error);
             if (typeof updateUIState === 'function') {
                updateUIState('error', { label: 'Audio playback error.' });
            }
        }
    }

    schedulePlayback(audioBuffer) {
        const audioContext = this._ensureAudioContext();
        const source = audioContext.createBufferSource();
        source.buffer = audioBuffer;
        
        // Store this source for visualization
        this.visualizerSource = source;
        
        // Create analyzer node if needed (ensuring compatible visualization)
        if (window.audioVisualizer && !this.visualizerAnalyzer) {
            this.visualizerAnalyzer = audioContext.createAnalyser();
            this.visualizerAnalyzer.fftSize = 2048;
            this.visualizerAnalyzer.smoothingTimeConstant = 0.8;
            this.log('Created analyzer node for visualization');
        }
        
        // Connect to analyzer if it exists
        if (this.visualizerAnalyzer) {
            source.connect(this.visualizerAnalyzer);
            this.log('Connected source to visualizer analyzer');
            
            // If visualizer is running, make sure it has our analyzer
            if (window.audioVisualizer && this.activeVisualizer) {
                if (typeof this.activeVisualizer.connectExternalAnalyser === 'function') {
                    this.activeVisualizer.connectExternalAnalyser(this.visualizerAnalyzer);
                    this.log('Connected analyzer to AudioVisualizer');
                }
            }
        }
        
        // Connect to speakers (always do this)
        source.connect(audioContext.destination);

        const currentTime = audioContext.currentTime;
        const scheduleTime = Math.max(currentTime, this.nextStartTime);

        this.log(`Scheduling playback at: ${scheduleTime.toFixed(2)}s (Current: ${currentTime.toFixed(2)}s, NextStart: ${this.nextStartTime.toFixed(2)}s)`);
        source.start(scheduleTime);

        // Update the start time for the *next* buffer
        this.nextStartTime = scheduleTime + audioBuffer.duration;

        // Trigger UI state update if needed
        if (currentAIState !== 'speaking' && typeof updateUIState === 'function') {
            updateUIState('speaking');
        }

        source.onended = () => {
            this.log('Audio chunk playback finished.');
            // Cleanup and check if there are more chunks
            if (this.audioQueue.length === 0 && currentAIState === 'speaking') {
                // If no more chunks and we're still in speaking state, revert to idle
                if (typeof updateUIState === 'function') {
                    updateUIState('idle');
                }
            }
        };
    }

    toggleMute(forceState = null) {
        const newState = (forceState !== null) ? !!forceState : !this.isMuted;
        if (newState === this.isMuted) return; // No change needed

        this.isMuted = newState;
        this.log(`Mute set to: ${this.isMuted}`);
        // Persist mute state
        try {
            localStorage.setItem('voxui_mute_state', JSON.stringify(this.isMuted));
        } catch (e) {
            console.warn('Failed to save mute state to localStorage:', e);
        }
        if (this.isMuted && this.isRecording) {
            this.log('Muting while recording, stopping recording.');
            this.stopRecording();
        }
        // Update UI (This should ideally be coordinated with the main UI update logic)
        // For now, just log. The main app.js should handle the visual mute state.
        console.log(`[AudioManager] Mute state is now: ${this.isMuted}`);
        // TODO: Coordinate this internal state with the global updateUIState function
        // Maybe AudioManager should emit events or call updateUIState directly?
    }
}


// WebSocket Client Class
class WebSocketClient {
    constructor(url) {
        this.url = url;
        this.ws = null;
        this.reconnectInterval = 5000; // 5 seconds
        this.debug = true; // Enable logging
        this.messageQueue = []; // Queue for messages sent before connection is open
        this.sessionConfirmed = false; // Flag to track if session is active
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
            // Flush queued messages
            if (this.messageQueue.length > 0) {
                this.log(`Flushing ${this.messageQueue.length} queued WebSocket messages...`);
                for (const { type, payload } of this.messageQueue) {
                    this.sendMessage(type, payload);
                }
                this.messageQueue = [];
            }

            // Request settings from backend as the primary source
            this.log('Requesting settings from backend via get_settings...');
            this.sendMessage('get_settings', {});
        };

        this.ws.onmessage = (event) => {
            this.log('Received message:', event.data); // Log raw message
            try {
                const message = JSON.parse(event.data);
                this.log('Parsed message:', message); // Log parsed message

                // Ensure payload exists, default to empty object if not
                const payload = message.payload || {}; // Declare payload ONCE here

                switch (message.type) {
                    // --- EXISTING HANDLERS ---
                    case 'audio_chunk': // This seems like a response chunk, renaming for clarity? Assuming it's playback.
                    case 'audio_response_chunk': // Keep original name if used elsewhere
                        this.log('Received audio chunk for playback.');
                        // Update UI state to "speaking" if we weren't already
                        if (currentAIState !== 'speaking' && typeof updateUIState === 'function') {
                            updateUIState('speaking');
                        }
                        if (window.audioManager && payload.chunk) {
                            window.audioManager.handleAudioResponse(payload.chunk);
                        } else {
                             this.log('Received audio_chunk but audioManager or chunk data missing.');
                        }
                        break;
                    case 'transcription_update':
                         this.log('Received transcription update.');
                        if (payload.text) {
                            // Assuming updateTranscription is globally available
                            if (typeof updateTranscription === 'function') {
                                updateTranscription(payload.text, payload.is_final);
                            } else {
                                this.log('updateTranscription function not found.');
                            }
                        } else {
                            this.log('Received transcription_update but text data missing.');
                        }
                        break;
                    case 'ai_state': // Handles general AI state changes
                    case 'status_update': // Keep original name if used elsewhere
                         this.log('Received AI state/status update.');
                         if (payload.state || payload.status) { // Check both possible keys
                             const state = payload.state || payload.status;
                             const context = payload.context || {};
                             // Assuming updateUIState is globally available
                             if (typeof updateUIState === 'function') {
                                 updateUIState(state, context);
                             } else {
                                 this.log('updateUIState function not found.');
                             }
                         } else {
                             this.log('Received ai_state/status_update message but state/status data missing.');
                         }
                         break;
                    case 'error': // General WebSocket/Server error
                    case 'error_message': // Keep original name if used elsewhere
                        const errorMessage = payload.message || 'Unknown error from server';
                        console.error('[WebSocket Error]', errorMessage, payload);
                        // Optionally update UI to show error
                        if (typeof updateUIState === 'function') {
                            updateUIState('error', { label: errorMessage });
                        }
                        break;
                     case 'text_response':
                        // Display text response if needed (future expansion)
                        console.log('[WebSocketClient] Text response received:', payload.text);
                        break;
                     case 'session_confirmed': // ADDED THIS CASE BACK
                        console.log('[WebSocketClient] Session confirmed');
                        this.sessionConfirmed = true; // Set flag
                        // Potentially update UI to show connected status
                        break;

                    // --- NEW SETTINGS HANDLERS ---
                    case 'settings_data':
                        this.log('Received settings_data:', payload.settings);
                        if (window.settings && payload.settings) {
                            // Merge received settings with existing ones
                            window.settings.settings = { ...window.settings.settings, ...payload.settings };
                            window.settings.log('Updated settings from WebSocket:', window.settings.settings);
                            window.settings.updateInputs(); // Update form fields
                            if (typeof applyTheme === 'function') applyTheme(window.settings.settings.theme); // Apply theme using shared function
                            // After applying settings, check if voice agent config is valid
                            const settingsData = window.settings.settings;
                            const agentType = settingsData.active_voice_agent;
                            const agentConfig = settingsData.voice_agent_config?.[agentType];
                            const isAgentValid = agentType && agentConfig && agentConfig.model && agentConfig.url;

                            if (isAgentValid) {
                                this.log('Voice agent config is valid. Sending init_session...');
                                this.sendMessage('init_session', {
                                    agentType: agentType,
                                    config: agentConfig
                                });
                            } else {
                                this.log('Voice agent config is missing or invalid. Not sending init_session.');
                                if (typeof updateUIState === 'function') {
                                    updateUIState('disconnected', 'Voice agent not configured');
                                }
                            }

                            // Resolve the promise from the load() call
                            if (typeof window.settings._loadPromiseResolve === 'function') {
                                window.settings._loadPromiseResolve(window.settings.settings);
                                window.settings._loadPromiseResolve = null; // Clear resolver
                                window.settings.log('Resolved settings load promise.');
                            }
                        } else {
                            console.error('Received settings_data but window.settings or payload.settings missing.');
                        }
                        break;
                    case 'settings_update_ack':
                        if (payload.success) {
                            this.log('Settings update successful (acknowledged by server).');
                            // After settings are saved, if we were previously disconnected due to missing voice agent config,
                            // and the new config is now valid, send init_session.
                            try {
                                const prevState = window.currentAIState;
                                const settingsData = window.settings.settings;
                                const agentType = settingsData.active_voice_agent;
                                const agentConfig = settingsData.voice_agent_config?.[agentType];
                                const isAgentValid = agentType && agentConfig && agentConfig.model && agentConfig.url;
                                if (
                                    prevState === 'disconnected' &&
                                    isAgentValid
                                ) {
                                    this.log('Settings updated: previously disconnected, now valid agent config. Sending init_session...');
                                    this.sendMessage('init_session', {
                                        agentType: agentType,
                                        config: agentConfig
                                    });
                                }
                            } catch (e) {
                                console.error('Error checking for auto-init_session after settings update:', e);
                            }
                            // Optional: Add user feedback (e.g., toast notification)
                        } else {
                            console.error('Settings update failed (acknowledged by server):', payload.error || 'Unknown error');
                            // Optional: Add user feedback
                        }
                        break;
                    // --- END NEW SETTINGS HANDLERS ---

                    default:
                        this.log(`Received unhandled message type: ${message.type}`);
                }
            } catch (error) {
                console.error('[WebSocketClient] Error processing message:', error, 'Raw data:', event.data);
            }
        };

        this.ws.onerror = (error) => {
            console.error('[WebSocketClient] WebSocket error:', error);
            // If session wasn't confirmed, force mute
            if (!this.sessionConfirmed && window.audioManager) {
                console.warn('[WebSocketClient] WebSocket error before session confirmed. Forcing mute.');
                window.audioManager.toggleMute(true);
                // Also update UI state if possible
                 if (typeof updateUIState === 'function') {
                    updateUIState('disconnected', 'Connection error');
                 }
            }
            // Fallback: If settings not loaded from backend, load from localStorage
            const s = window.settings && window.settings.settings;
            if (s && (!s.active_voice_agent || !s.voice_agent_config)) {
                console.warn('[WebSocketClient] WebSocket error before settings loaded. Falling back to localStorage.');
                window.settings.load('WebSocketErrorFallback');
            }
            // onclose will likely be called next, triggering reconnection.
        };

        this.ws.onclose = (event) => {
            this.log(`Connection closed. Code: ${event.code}, Reason: '${event.reason}'. Reconnecting in ${this.reconnectInterval / 1000}s...`);
            // If session wasn't confirmed, force mute
            if (!this.sessionConfirmed && window.audioManager) {
                console.warn('[WebSocketClient] WebSocket closed before session confirmed. Forcing mute.');
                window.audioManager.toggleMute(true);
                // Also update UI state if possible
                 if (typeof updateUIState === 'function') {
                    updateUIState('disconnected', 'Connection closed');
                 }
            }
            // Fallback: If settings not loaded from backend, load from localStorage
            const s = window.settings && window.settings.settings;
            if (s && (!s.active_voice_agent || !s.voice_agent_config)) {
                console.warn('[WebSocketClient] WebSocket closed before settings loaded. Falling back to localStorage.');
                window.settings.load('WebSocketErrorFallback');
            }
            this.sessionConfirmed = false; // Reset flag on close
            this.ws = null; // Clear the old socket object
            this.scheduleReconnect();
        };
    }

    scheduleReconnect() {
        this.log(`Scheduling reconnect in ${this.reconnectInterval / 1000}s...`);
        setTimeout(() => {
            this.log('Attempting to reconnect...');
            this.connect();
        }, this.reconnectInterval);
    }

    sendMessage(type, payload) {
        if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
            this.log(`WebSocket not open. Queuing message: ${type}`, payload);
            this.messageQueue.push({ type, payload });
            return;
        }
        try {
            const message = JSON.stringify({ type, payload });
            this.log(`Sending message: ${type}`, payload);
            this.ws.send(message);
        } catch (error) {
            console.error('[WebSocketClient] Error sending message:', error);
        }
    }
}


// --- Particle Effect ---
function createParticles(orbParticles) {
    if (!orbParticles) return;
    const particleCount = 15;
    for (let i = 0; i < particleCount; i++) {
        const particle = document.createElement('div');
        particle.classList.add('particle');
        
        // Random position within the orb's bounds (approximate)
        const angle = Math.random() * 2 * Math.PI;
        const radius = Math.random() * 40; // Adjust radius as needed
        const x = Math.cos(angle) * radius;
        const y = Math.sin(angle) * radius;
        
        // Set initial position relative to center
        particle.style.setProperty('--x', `${x}px`);
        particle.style.setProperty('--y', `${y}px`);
        
        // Random size and duration
        const size = Math.random() * 5 + 2; // 2px to 7px
        const duration = Math.random() * 800 + 400; // 400ms to 1200ms
        
        particle.style.width = `${size}px`;
        particle.style.height = `${size}px`;
        particle.style.backgroundColor = 'var(--notify-color, rgba(33, 150, 243, 0.8))'; // Use notify color
        
        // Apply animation
        particle.style.animation = `particle-burst ${duration}ms forwards ease-out`;
        
        orbParticles.appendChild(particle);
        
        // Remove particle after animation
        setTimeout(() => {
            particle.remove();
        }, duration);
    }
}

// --- Transition Effect ---
function triggerTransitionEffect(body) {
    if (!body) return;
    body.classList.add('transitioning');
    setTimeout(() => {
        body.classList.remove('transitioning');
    }, 150); // Duration of the flash animation
}

// --- Ensure Animation Styles ---
function ensureAnimationStyles() {
    if (document.getElementById('vox-animation-styles')) return; // Already added

    const style = document.createElement('style');
    style.id = 'vox-animation-styles';
    style.textContent = `
        /* Orb Status Ring Glow */
        .orb-status-ring {
            position: absolute;
            top: 50%;
            left: 50%;
            width: 100%;
            height: 100%;
            border-radius: 50%;
            transform: translate(-50%, -50%);
            box-shadow: 0 0 10px 5px var(--orb-glow-color, rgba(33, 150, 243, 0.5));
            opacity: 0.5;
            transition: box-shadow 0.3s ease-out, opacity 0.3s ease-out;
            pointer-events: none; /* Allow clicks to pass through */
        }

        /* State-specific Glow Adjustments */
        .state-listening .orb-status-ring { opacity: 0.7; box-shadow: 0 0 15px 7px var(--orb-glow-color); }
        .state-processing .orb-status-ring { opacity: 0.7; box-shadow: 0 0 15px 7px var(--orb-glow-color); }
        .state-speaking .orb-status-ring { opacity: 0.7; box-shadow: 0 0 15px 7px var(--orb-glow-color); }
        .state-error .orb-status-ring { opacity: 0.7; box-shadow: 0 0 15px 7px var(--orb-glow-color); }
        .state-muted .orb-status-ring { opacity: 0.3; }
        .state-notifying .orb-status-ring { opacity: 0.8; box-shadow: 0 0 20px 10px var(--orb-glow-color); }

        /* Particle Container */
        .orb-particles {
            position: absolute;
            top: 0; left: 0; width: 100%; height: 100%;
            pointer-events: none;
        }

        /* Individual Particle */
        .particle {
            position: absolute;
            top: 50%; left: 50%;
            border-radius: 50%;
            transform-origin: center center;
        }

        /* Particle Animation */
        @keyframes particle-burst {
            0% { transform: translate(0, 0) scale(1); opacity: 1; }
            100% { transform: translate(var(--x), var(--y)) scale(0); opacity: 0; }
        }

        /* Processing Ellipsis Animation */
        .processing-container {
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .processing-text {
            margin-right: 2px;
            white-space: nowrap;
        }
        .ellipsis-dots {
            display: inline-block;
            width: 18px; /* Adjust width based on font size */
            text-align: left;
        }
        .ellipsis-dots::after {
            content: '.';
            display: inline-block;
            margin-left: 2px;  /* Space between text and dots */
            animation: ellipsis-animation 1.5s infinite;
        }
        @keyframes ellipsis-animation {
            0% { content: '.'; }
            33% { content: '..'; }
            66% { content: '...'; }
            100% { content: '.'; }
        }

        /* Transition Flash Animation */
        .transitioning .orb-status-ring {
            animation: transition-flash 0.15s ease-out;
        }
        @keyframes transition-flash {
            0%, 100% { box-shadow: 0 0 10px 5px var(--orb-glow-color); opacity: 0.5; }
            50% { box-shadow: 0 0 20px 10px var(--orb-glow-color); opacity: 1; }
        }
    `;
    document.head.appendChild(style);
    console.log('Added animation styles to document head');
}

// Initialize when the page loads
console.log('[app.js] DOMContentLoaded handler registered');
document.addEventListener('DOMContentLoaded', () => {
    window.settings = new Settings();

    // Initialize AudioVisualizer first so it's available for AudioManager
    if (typeof AudioVisualizer !== "undefined") {
        window.audioVisualizer = new AudioVisualizer();
        console.log('AudioVisualizer initialized. Access via window.audioVisualizer.');
    } else {
        window.audioVisualizer = null;
        console.log('AudioVisualizer not available on this page.');
    }

    // Fetch latest settings via HTTP first for faster initial load
    console.log('[DOMContentLoaded] Fetching initial settings via HTTP...');
    fetch('/api/settings')
        .then(res => {
            if (!res.ok) {
                throw new Error(`HTTP error! status: ${res.status}`);
            }
            return res.json();
        })
        .then(settings => {
            console.log('[DOMContentLoaded] Initial settings loaded via HTTP:', settings);
            window.settings.settings = { ...window.settings.settings, ...settings }; // Merge with defaults/existing
            if (typeof applyTheme === 'function') {
                applyTheme(window.settings.settings.theme); // Apply fetched theme
            } else {
                 console.warn('applyTheme function not found when applying HTTP settings.');
            }
            // Now initialize WebSocket
            initializeMainAppLogic();
        })
        .catch(err => {
            console.error('[DOMContentLoaded] Failed to fetch initial settings via HTTP. Falling back to WebSocket/localStorage:', err);
            // Proceed with WebSocket initialization anyway, it will handle fallback
            initializeMainAppLogic();
        });
// Function to handle hash-based accordion expansion on settings pages
function handleSettingsHashNavigation() {
    // Check if we are on a settings-related page
    if (window.location.pathname.endsWith('settings.html') || window.location.pathname.endsWith('mcp_settings.html')) {
        const hash = window.location.hash;
        if (hash) {
            try {
                const targetId = hash.substring(1); // Remove '#'
                const targetElement = document.getElementById(targetId);

                if (targetElement) {
                    // Find the closest ancestor that is an accordion group
                    const accordionGroup = targetElement.closest('.settings-group.accordion');

                    if (accordionGroup && !accordionGroup.classList.contains('open')) {
                        console.log(`[App.js] Expanding accordion for hash: ${hash}`);
                        accordionGroup.classList.add('open');
                        // The CSS should handle making the details visible when .open is added
                    } else if (accordionGroup) {
                         console.log(`[App.js] Accordion for hash ${hash} already open.`);
                    } else {
                         console.warn(`[App.js] No accordion group found for element with ID "${targetId}".`);
                    }
                } else {
                    console.warn(`[App.js] Element with ID "${targetId}" not found for hash navigation.`);
                }
            } catch (error) {
                console.error(`[App.js] Error handling hash navigation: ${error}`);
            }
        }
    }
}



    // Function to contain the rest of the initialization logic
    function initializeMainAppLogic() {
        console.log('[DOMContentLoaded] Initializing WebSocket client and main app logic...');
        const websocketUrl = `wss://${window.location.hostname}:3002`; // Use hostname and specific port
        // Fallback for local development if hostname isn't resolving correctly or for file:// protocol
        // const websocketUrl = 'wss://localhost:3002';
        window.wsClient = new WebSocketClient(websocketUrl);
        // Helper for easy console access
        window.sendWebSocketMessage = (type, payload) => window.wsClient.sendMessage(type, payload);
        console.log('WebSocket client setup complete. Access via window.wsClient or sendWebSocketMessage(type, payload).');

        window.audioManager = new AudioManager(window.wsClient);
        // Restore mute state from localStorage
        try {
            const storedMute = localStorage.getItem('voxui_mute_state');
            if (storedMute !== null) {
                const isMuted = JSON.parse(storedMute);
                window.audioManager.toggleMute(!!isMuted);
                // Update mute button UI if present
                const muteButton = document.querySelector('.mute-button');
                if (muteButton) {
                    muteButton.classList.toggle('muted', !!isMuted);
                    muteButton.title = isMuted ? 'Unmute microphone' : 'Mute microphone';
                    muteButton.querySelector('svg path')?.setAttribute('d', isMuted ? micOffIcon : micOnIcon);
                }
            }
        } catch (e) {
            console.warn('Failed to restore mute state from localStorage:', e);
        }
        console.log('AudioManager initialized. Access via window.audioManager.');

        // Automatically start recording after initialization
        // We add a small delay to ensure the UI is settled and mic access prompt doesn't feel too abrupt
        setTimeout(() => {
             console.log('Attempting to auto-start recording...');
             window.audioManager.startRecording();
        }, 500); // 500ms delay
        
        // Initialize global state variables
        window.currentAIState = 'idle'; // The current AI state, used for UI updates
        window.underlyingAIState = null; // Remembers the state when temporarily muted

        // Ensure animation styles are added
        ensureAnimationStyles();

        // --- Orb Interaction (Listeners Removed for Auto-Start) ---
        // Recording now starts automatically after initialization.
        // The orb interaction might be repurposed later for other actions if needed.
        const orbElement = document.querySelector('.orb');
        if (!orbElement) {
             console.error('Orb element not found.');
        }

        // --- Mute Button Logic (Moved/Refined) ---
        const muteButton = document.querySelector('.mute-button');
        // Define icons here for use in the listener
        const micOnIcon = 'M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.91-3c-.49 0-.9.36-.98.85C16.52 14.2 14.47 16 12 16s-4.52-1.8-4.93-4.15c-.08-.49-.49-.85-.98-.85-.61 0-1.09.54-1 1.14.49 3 2.89 5.35 5.91 5.78V20c0 .55.45 1 1 1s1-.45 1-1v-2.08c3.02-.43 5.42-2.78 5.91-5.78.1-.6-.39-1.14-1-1.14z';
        const micOffIcon = 'M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3z';

        if (muteButton) {
            // Initialize button state based on AudioManager's initial state
            const initialMuteState = window.audioManager.isMuted;
            muteButton.title = initialMuteState ? 'Unmute microphone' : 'Mute microphone';
            muteButton.querySelector('svg path')?.setAttribute('d', initialMuteState ? micOffIcon : micOnIcon);
            if (initialMuteState) {
                muteButton.classList.add('muted'); // Add class for potential CSS styling
            }

            muteButton.addEventListener('click', () => {
                window.audioManager.toggleMute();
                const isNowMuted = window.audioManager.isMuted;

                // Update button appearance
                muteButton.title = isNowMuted ? 'Unmute microphone' : 'Mute microphone';
                muteButton.querySelector('svg path')?.setAttribute('d', isNowMuted ? micOffIcon : micOnIcon);
                muteButton.classList.toggle('muted', isNowMuted); // Toggle class based on state

                // Update global UI state
                updateUIState(isNowMuted ? 'muted' : (underlyingAIState || 'idle'));
                console.log(`Mute button clicked. AudioManager is now muted: ${isNowMuted}`);
            });
        } else {
            console.error('Mute button not found.');
        }
        
        // End the muteButton section
        
        // Add a function to create notification particles for updateUIState
        function createNotificationEffect() {
            const orbParticles = document.querySelector('.orb-particles');
            if (orbParticles) {
                createParticles(orbParticles);
            }
        }

        // Define the updateUIState function to handle AI state transitions and UI updates
        function updateUIState(newState, context = {}) {
            console.log(`Updating UI state: ${newState}`, context);
            
            // Get UI elements
            const body = document.body;
            const orb = document.querySelector('.orb');
            const statusText = document.querySelector('.status-text');
            const statusRing = document.querySelector('.orb-status-ring');
            
            // Store previous state to detect actual transitions
            const previousState = currentAIState;
            
            // Special case: if we're muted, remember the "real" AI state
            // but don't change the UI from muted
            if (newState !== 'muted' && currentAIState === 'muted') {
                underlyingAIState = newState;
                // If we're muted, don't update the UI state further
                if (window.audioManager && window.audioManager.isMuted) {
                    return;
                }
            }
            
            // Update global state
            currentAIState = newState;
            
            // Clear any existing state classes
            const states = ['idle', 'listening', 'processing', 'speaking', 'error', 'muted', 'notifying'];
            states.forEach(state => body.classList.remove(`state-${state}`));
            
            // Apply new state class
            body.classList.add(`state-${newState}`);
            
            // Apply transition effect between meaningful states
            if (previousState !== newState) {
                triggerTransitionEffect(body);
            }
            
            // Handle specific states with special UI needs
            switch (newState) {
                case 'idle':
                    if (statusText) statusText.textContent = 'Ready';
                    break;
                    
                case 'listening':
                    if (statusText) statusText.textContent = 'Listening...';
                    // If we have AudioVisualizer, make sure it's active
                    if (window.audioVisualizer && !window.audioVisualizer.isInitialized) {
                        window.audioVisualizer.initialize().catch(err => {
                            console.error('Error initializing audio visualizer:', err);
                        });
                    }
                    break; // Missing break for 'listening' case

                case 'speaking':
                    if (statusText) statusText.textContent = 'Speaking...';
                    break;

                case 'processing':
                    const label = context.label || 'Processing';
                    if (statusText) {
                        statusText.innerHTML = `
                            <div class="processing-container">
                                <span class="processing-text">${label}</span><span class="ellipsis-dots"></span>
                            </div>
                        `;
                    }
                    break;

                case 'error':
                    if (statusText) statusText.textContent = context.label || 'Error';
                    console.error('UI Error State:', context);
                    break;

                case 'notifying':
                    createNotificationEffect();
                    // Automatically revert to previous state after notification
                    setTimeout(() => {
                        updateUIState(underlyingAIState || 'idle');
                    }, 1500);
                    break;

                case 'muted':
                    if (statusText) statusText.textContent = 'Muted';
                    break;
            } // End switch

            // Update orb glow color based on state
            if (statusRing) {
                let glowColor = '';
                switch (newState) {
                    case 'idle': glowColor = 'var(--idle-color, rgba(33, 150, 243, 0.5))'; break;
                    case 'listening': glowColor = 'var(--listening-color, rgba(76, 175, 80, 0.7))'; break;
                    case 'processing': glowColor = 'var(--processing-color, rgba(255, 152, 0, 0.7))'; break;
                    case 'speaking': glowColor = 'var(--speaking-color, rgba(33, 150, 243, 0.7))'; break;
                    case 'error': glowColor = 'var(--error-color, rgba(244, 67, 54, 0.7))'; break;
                    case 'muted': glowColor = 'var(--muted-color, rgba(158, 158, 158, 0.5))'; break;
                    case 'notifying': glowColor = 'var(--notify-color, rgba(33, 150, 243, 0.8))'; break;
                }
                statusRing.style.setProperty('--orb-glow-color', glowColor);
            }
        } // End updateUIState function

        // Make updateUIState accessible from within WebSocket messages
        window.updateUIState = updateUIState;

    } // End of initializeMainAppLogic

}); // End of DOMContentLoaded

        // Hash navigation handled in shared_ui.js
