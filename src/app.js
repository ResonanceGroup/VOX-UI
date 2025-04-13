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
        this._loadPromiseResolve = null; // To resolve the load promise
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

    load() {
        this.log('Requesting settings via WebSocket...');
        // Return a promise that resolves when settings are loaded via WebSocket
        return new Promise((resolve, reject) => {
            // Store the resolver function to be called by the WebSocket handler
            this._loadPromiseResolve = resolve;

            // Check if WebSocket is connected and ready
            if (window.wsClient && window.wsClient.ws && window.wsClient.ws.readyState === WebSocket.OPEN) {
                window.wsClient.sendMessage('get_settings', {});
            } else {
                // Handle case where WebSocket is not ready yet
                // Maybe wait for connection or reject the promise
                console.error('WebSocket not ready when trying to load settings.');
                // Reject or wait? For now, let's log and rely on connect logic to eventually load.
                // If the connection fails permanently, settings won't load.
                // We could add a timeout here if needed.
                // Alternative: Queue the request until WS is open.
            }
            // Note: The actual update (updateInputs, applyTheme) happens
            // in the WebSocket onmessage handler for 'settings_data'.
        });
    }

    save() {
        this.log('Saving settings...');
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

    toggleMute() {
        this.isMuted = !this.isMuted;
        this.log(`Mute toggled. New state: ${this.isMuted}`);
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

            // Send the init_session message using loaded settings
            try {
                if (!window.settings || !window.settings.settings) {
                    throw new Error('Settings not available on window object.');
                }
                const settingsData = window.settings.settings;
                const agentType = settingsData.active_voice_agent;
                const agentConfig = settingsData.voice_agent_config?.[agentType] || {}; // Use optional chaining and default to empty object

                if (!agentType) {
                     console.warn('[WebSocketClient] No active_voice_agent found in settings. Cannot send init_session.');
                     return; // Don't send if no agent type is set
                }

                this.log(`Sending init_session for agentType: ${agentType}`, agentConfig);
                this.sendMessage('init_session', {
                    agentType: agentType,
                    config: agentConfig
                });

            } catch (error) {
                console.error('[WebSocketClient] Error preparing or sending init_session message:', error);
                // Optionally, close the connection or notify the user
            }
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
                     case 'session_confirmed':
                        console.log('[WebSocketClient] Session confirmed');
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
                            window.settings.applyTheme();   // Apply theme

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
            // Queue the message to be sent when the connection is open
            this.messageQueue.push({ type, payload });
            if (this.debug) {
                this.log('WebSocket not open. Queuing message:', { type, payload });
            }
        }
    }
}

// Global state variables for UI coordination
let currentAIState = 'idle'; // Tracks current UI state
let underlyingAIState = 'idle'; // Stores state before mute/notify

// Notification animation and UI functions
function createParticles(orbParticles) {
    if (!orbParticles) return;
    
    // Clear any existing particles
    orbParticles.innerHTML = '';
    
    // Create 5-7 particles
    const particleCount = Math.floor(Math.random() * 3) + 7; // 7-10 particles
    
    for (let i = 0; i < particleCount; i++) {
        const particle = document.createElement('div');
        particle.className = 'particle';
        
        // Random angle for trajectory
        const angle = Math.random() * Math.PI * 2;
        // Random distance (40-100px)
        const distance = 40 + Math.random() * 60;
        
        // Calculate x,y destination based on angle and distance
        const x = Math.cos(angle) * distance;
        const y = Math.sin(angle) * distance;
        
        // Set random color from options
        const colors = ['#42A5F5', '#64B5F6', '#29B6F6', '#03A9F4', '#00BCD4'];
        const color = colors[Math.floor(Math.random() * colors.length)];
        
        // Apply styles
        particle.style.setProperty('--x', `${x}px`);
        particle.style.setProperty('--y', `${y}px`);
        particle.style.backgroundColor = color;
        
        // Larger particles (8-16px)
        const size = 8 + Math.random() * 8;
        particle.style.width = `${size}px`;
        particle.style.height = `${size}px`;
        
        // Animation duration (500-700ms)
        const duration = 500 + Math.random() * 200;
        particle.style.animation = `particle-burst ${duration}ms forwards ease-out`;
        
        // Add to container
        orbParticles.appendChild(particle);
    }
    
    // Create a flash effect
    const flash = document.createElement('div');
    flash.className = 'notification-flash';
    flash.style.position = 'absolute';
    flash.style.inset = '0';
    flash.style.backgroundColor = 'rgba(100, 181, 246, 0.3)';
    flash.style.borderRadius = '50%';
    flash.style.animation = 'fade-out 400ms forwards';
    orbParticles.appendChild(flash);
    
    // Create expanding wave effect
    const wave = document.createElement('div');
    wave.className = 'notification-wave';
    wave.style.position = 'absolute';
    wave.style.top = '50%';
    wave.style.left = '50%';
    wave.style.transform = 'translate(-50%, -50%)';
    wave.style.width = '100%';
    wave.style.height = '100%';
    wave.style.borderRadius = '50%';
    wave.style.border = '3px solid rgba(100, 181, 246, 0.8)';
    wave.style.boxShadow = '0 0 15px rgba(100, 181, 246, 0.6)';
    wave.style.animation = 'expand-wave 1s forwards ease-out';
    orbParticles.appendChild(wave);
}

function triggerTransitionEffect(body) {
    if (!body) return;
    body.classList.add('transitioning');
    setTimeout(() => body.classList.remove('transitioning'), 150);
}

function ensureAnimationStyles() {
    if (document.querySelector('#animation-styles')) return;
    
    const style = document.createElement('style');
    style.id = 'animation-styles';
    style.textContent = `
        @keyframes fade-out {
            from { opacity: 1; }
            to { opacity: 0; }
        }
        
        @keyframes expand-wave {
            0% {
                width: 100%;
                height: 100%;
                opacity: 0.8;
            }
            100% {
                width: 200%;
                height: 200%;
                opacity: 0;
            }
        }
        
        @keyframes particle-burst {
            0% { transform: translate(0, 0) scale(1); opacity: 1; }
            100% { transform: translate(var(--x), var(--y)) scale(0); opacity: 0; }
        }
        
        @keyframes ellipsis-animation {
            0% { content: '.'; }
            33% { content: '..'; }
            66% { content: '...'; }
            100% { content: '.'; }
        }
        
        .processing-container {
            display: inline-flex;
            justify-content: center;
            align-items: center;
        }
        
        .processing-text {
            display: inline;
            white-space: nowrap;
        }
        
        .ellipsis-dots {
            display: inline-block;
            width: 18px;
            text-align: left;
            overflow: hidden;
        }
        
        .ellipsis-dots::after {
            content: '.';
            display: inline-block;
            margin-left: 2px;  /* Space between text and dots */
            animation: ellipsis-animation 1.5s infinite;
        }
        
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

    // Load settings first, then initialize WebSocket and the rest of the UI logic
    window.settings.load().then(() => {
        window.settings.applyTheme();
        console.log('Settings loaded, initializing WebSocket client...');
        const websocketUrl = `wss://${window.location.hostname}:3002`; // Use hostname and specific port
        // Fallback for local development if hostname isn't resolving correctly or for file:// protocol
        // const websocketUrl = 'wss://localhost:3002';
        window.wsClient = new WebSocketClient(websocketUrl);
        // Helper for easy console access
        window.sendWebSocketMessage = (type, payload) => window.wsClient.sendMessage(type, payload);
        console.log('WebSocket client setup complete. Access via window.wsClient or sendWebSocketMessage(type, payload).');

        window.audioManager = new AudioManager(window.wsClient);
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
                    break;
                    
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
            }
            
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
        }

        // Make updateUIState accessible from within WebSocket messages
        window.updateUIState = updateUIState;
        
    }).catch(error => {
        console.error("Failed to load settings before initializing WebSocket:", error);
        // Show user-friendly error
        document.body.classList.add('state-error');
    });
});  // Close the DOMContentLoaded event handler
