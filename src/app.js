// Audio Visualizer Class
class AudioVisualizer {
    constructor() {
        this.audioContext = null;
        this.analyser = null;
        this.dataArray = null;
        this.source = null;
        this.animationFrame = null;
        this.isInitialized = false;
        
        // Get DOM elements
        this.orbElement = document.querySelector('.orb');
        this.talkButton = document.querySelector('.talk-button');
        this.statusDisplay = document.getElementById('status-display');
        
        // Audio analysis settings
        this.fftSize = 2048; // Larger FFT for better frequency resolution
        this.smoothingTimeConstant = 0.8;
        this.energyThresholds = {
            low: 0.1,
            medium: 0.3,
            high: 0.5
        };
        
        // Frequency ranges for analysis (in Hz)
        this.frequencyRanges = {
            bass: [20, 140],
            midrange: [140, 2000],
            treble: [2000, 16000]
        };
        
        // Bind methods
        this.handleMouseDown = this.handleMouseDown.bind(this);
        this.handleMouseUp = this.handleMouseUp.bind(this);
        
        // Add event listeners
        if (this.talkButton) {
            this.talkButton.addEventListener('mousedown', this.handleMouseDown);
            this.talkButton.addEventListener('mouseup', this.handleMouseUp);
            this.talkButton.addEventListener('mouseleave', this.handleMouseUp);
        }

        // Check if we're in a secure context
        if (!window.isSecureContext) {
            console.error('Not in a secure context - microphone access requires HTTPS or localhost');
            this.updateStatus('Error: Requires HTTPS or localhost', 'error');
            return;
        }

        // Check if getUserMedia is supported
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            console.error('getUserMedia not supported on this browser');
            this.updateStatus('Error: Microphone not supported', 'error');
            return;
        }
    }
    
    async initialize() {
        if (this.isInitialized) return;
        
        try {
            console.log('Initializing audio context...');
            // Initialize audio context
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            console.log('Audio context created:', this.audioContext.state);
            
            // Create analyzer node with higher FFT size
            this.analyser = this.audioContext.createAnalyser();
            this.analyser.fftSize = this.fftSize;
            this.analyser.smoothingTimeConstant = this.smoothingTimeConstant;
            
            const bufferLength = this.analyser.frequencyBinCount;
            this.dataArray = new Uint8Array(bufferLength);
            
            console.log('Requesting microphone access...');
            // Get microphone access
            const stream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            });
            console.log('Microphone access granted');
            
            // Create and connect nodes
            this.source = this.audioContext.createMediaStreamSource(stream);
            
            // Add gain node to boost signal
            const gainNode = this.audioContext.createGain();
            gainNode.gain.value = 4.0; // Increased gain for better sensitivity
            
            // Connect nodes: source -> gain -> analyser
            this.source.connect(gainNode);
            gainNode.connect(this.analyser);
            
            this.isInitialized = true;
            this.startVisualization();
            
            // Update status
            this.updateStatus('Listening...');
            console.log('Audio initialization complete');
        } catch (error) {
            console.error('Error initializing audio:', error);
            let errorMessage = 'Error initializing microphone';
            
            // More specific error messages
            if (error.name === 'NotAllowedError') {
                errorMessage = 'Microphone access denied';
            } else if (error.name === 'NotFoundError') {
                errorMessage = 'No microphone found';
            } else if (error.name === 'NotReadableError') {
                errorMessage = 'Microphone is in use by another application';
            }
            
            this.updateStatus(errorMessage + ' - Click to retry', 'error');
            throw error;
        }
    }
    
    getFrequencyRangeValue(frequencies, rangeStart, rangeEnd) {
        const sampleRate = this.audioContext.sampleRate;
        const binCount = this.analyser.frequencyBinCount;
        const startIndex = Math.floor(rangeStart * binCount / (sampleRate / 2));
        const endIndex = Math.floor(rangeEnd * binCount / (sampleRate / 2));
        let sum = 0;
        
        for (let i = startIndex; i <= endIndex; i++) {
            sum += frequencies[i];
        }
        
        return sum / (endIndex - startIndex + 1) / 255; // Normalize to 0-1
    }
    
    startVisualization() {
        if (!this.isInitialized) return;
        
        const updateVisuals = () => {
            // Get frequency data
            this.analyser.getByteFrequencyData(this.dataArray);
            
            // Analyze different frequency ranges
            const bass = this.getFrequencyRangeValue(this.dataArray, ...this.frequencyRanges.bass);
            const midrange = this.getFrequencyRangeValue(this.dataArray, ...this.frequencyRanges.midrange);
            const treble = this.getFrequencyRangeValue(this.dataArray, ...this.frequencyRanges.treble);
            
            // Calculate weighted average (emphasize midrange for speech)
            const weightedEnergy = (bass * 0.2 + midrange * 0.6 + treble * 0.2);
            
            // Update orb visualization based on energy level
            if (weightedEnergy > this.energyThresholds.high) {
                this.orbElement.dataset.audioLevel = 'high';
            } else if (weightedEnergy > this.energyThresholds.medium) {
                this.orbElement.dataset.audioLevel = 'medium';
            } else if (weightedEnergy > this.energyThresholds.low) {
                this.orbElement.dataset.audioLevel = 'low';
            } else {
                delete this.orbElement.dataset.audioLevel;
            }
            
            this.animationFrame = requestAnimationFrame(updateVisuals);
        };
        
        updateVisuals();
    }
    
    stopVisualization() {
        if (this.animationFrame) {
            cancelAnimationFrame(this.animationFrame);
            this.animationFrame = null;
        }
        delete this.orbElement.dataset.audioLevel;
    }
    
    updateStatus(text, type = 'info') {
        if (this.statusDisplay) {
            this.statusDisplay.textContent = text;
            this.statusDisplay.className = `status-display status-${type}`;
        }
    }
    
    async handleMouseDown() {
        try {
            if (!this.isInitialized) {
                await this.initialize();
            }
            if (this.audioContext) {
                await this.audioContext.resume();
                this.talkButton.textContent = 'Release to stop';
                this.talkButton.classList.add('active');
            }
        } catch (error) {
            console.error('Error in handleMouseDown:', error);
        }
    }
    
    handleMouseUp() {
        if (this.audioContext) {
            this.audioContext.suspend();
            this.talkButton.textContent = 'Talk to interrupt';
            this.talkButton.classList.remove('active');
            this.updateStatus('Processing...');
            setTimeout(() => {
                this.updateStatus('Ready to assist...');
            }, 1500);
        }
    }
}

// Initialize audio visualizer when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.audioVisualizer = new AudioVisualizer();
    
    // Get UI elements
    const textInput = document.querySelector('.text-input');
    const sendButton = document.querySelector('.send-button');
    const uploadButton = document.querySelector('.upload-button');
    const muteButton = document.querySelector('.mute-button');
    const menuButton = document.querySelector('.menu-button');
    const sidebar = document.querySelector('.sidebar');
    const sidebarItems = document.querySelectorAll('.sidebar-item');
    const statusDisplay = document.getElementById('status-display');
    const overlay = document.querySelector('.overlay');
    
    // State
    let isMuted = false;
    let activeSection = 'chat';
    let isSidebarOpen = false;
    
    // Mute button icons
    const micOnIcon = 'M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.91-3c-.49 0-.9.36-.98.85C16.52 14.2 14.47 16 12 16s-4.52-1.8-4.93-4.15c-.08-.49-.49-.85-.98-.85-.61 0-1.09.54-1 1.14.49 3 2.89 5.35 5.91 5.78V20c0 .55.45 1 1 1s1-.45 1-1v-2.08c3.02-.43 5.42-2.78 5.91-5.78.1-.6-.39-1.14-1-1.14z';
    const micOffIcon = 'M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3z';
    
    // Text input handling
    function handleSendMessage() {
        const message = textInput.value.trim();
        if (message) {
            updateStatus(`You: ${message}`);
            textInput.value = '';
            
            // Simulate AI response
            setTimeout(() => {
                updateStatus('AI is responding...');
                setTimeout(() => {
                    updateStatus('AI: I received your message.');
                    setTimeout(() => {
                        updateStatus('Ready to assist...');
                    }, 1500);
                }, 1500);
            }, 500);
        }
    }
    
    // Status display function
    function updateStatus(text, type = 'info') {
        statusDisplay.textContent = text;
        statusDisplay.className = `status-display status-${type}`;
    }
    
    // Event listeners
    sendButton.addEventListener('click', handleSendMessage);
    
    textInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            handleSendMessage();
        }
    });
    
    uploadButton.addEventListener('click', () => {
        updateStatus('File upload will be available in a future update');
        setTimeout(() => {
            updateStatus('Ready to assist...');
        }, 2000);
    });
    
    muteButton.addEventListener('click', () => {
        isMuted = !isMuted;
        muteButton.title = isMuted ? 'Unmute microphone' : 'Mute microphone';
        muteButton.querySelector('path').setAttribute('d', isMuted ? micOffIcon : micOnIcon);
        updateStatus(isMuted ? 'Microphone muted' : 'Microphone active');
        setTimeout(() => {
            updateStatus('Ready to assist...');
        }, 1500);
    });
    
    function toggleSidebar() {
        isSidebarOpen = !isSidebarOpen;
        sidebar.classList.toggle('open', isSidebarOpen);
        overlay.classList.toggle('visible', isSidebarOpen);
        menuButton.setAttribute('aria-expanded', isSidebarOpen);
    }
    
    menuButton.addEventListener('click', toggleSidebar);
    overlay.addEventListener('click', toggleSidebar);
    
    sidebarItems.forEach(item => {
        item.addEventListener('click', () => {
            const section = item.title.toLowerCase();
            if (section === activeSection) {
                toggleSidebar();
                return;
            }
            
            // Update active state
            sidebarItems.forEach(btn => btn.classList.remove('active'));
            item.classList.add('active');
            activeSection = section;
            
            // Show status message and close sidebar
            updateStatus(`${item.title} section will be available in a future update`);
            setTimeout(() => {
                updateStatus('Ready to assist...');
            }, 2000);
            toggleSidebar();
        });
    });
});
