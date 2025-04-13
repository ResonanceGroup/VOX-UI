class AudioVisualizer {
    constructor() {
        this.audioContext = null;
        this.analyser = null;
        this.dataArray = null;
        this.source = null;
        this.animationFrame = null;
        this.isInitialized = false;
        this.testMode = false;
        this.testStartTime = 0;
        
        // External analyzer integration
        this.externalAnalyser = null;
        this.isUsingExternalAnalyser = false;
        this.externalDataArray = null;
        
        // Get DOM elements
        this.orbElement = document.querySelector('.orb');
        this.talkButton = document.querySelector('.talk-button');
        this.statusDisplay = document.getElementById('status-display');
        
        // Audio analysis settings
        this.fftSize = 2048;
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

        // Add test mode
        this.setupTestMode();
    }

    setupTestMode() {
        // Add keyboard shortcuts for testing animations
        document.addEventListener('keydown', (e) => {
            if (e.key === 't') {
                this.testMode = !this.testMode;
                if (this.testMode) {
                    this.testStartTime = performance.now();
                    this.startTestAnimation();
                    this.updateStatus('Test mode: Sine wave simulation');
                } else {
                    delete this.orbElement.dataset.audioLevel;
                    this.orbElement.style.removeProperty('--intensity');
                    this.updateStatus('Test mode: Off');
                }
            }
        });
    }

    startTestAnimation() {
        if (!this.testMode) return;

        const animate = () => {
            if (!this.testMode) {
                delete this.orbElement.dataset.audioLevel;
                this.orbElement.style.removeProperty('--intensity');
                return;
            }

            // Create a slow sine wave that cycles every 8 seconds
            const time = (performance.now() - this.testStartTime) / 8000;
            const value = (Math.sin(time * Math.PI * 2) + 1) / 2; // Normalize to 0-1

            // Map the sine wave to audio levels with smooth transitions
            this.orbElement.style.setProperty('--intensity', value.toFixed(3));
            
            if (value > this.energyThresholds.high) {
                this.orbElement.dataset.audioLevel = 'high';
            } else if (value > this.energyThresholds.medium) {
                this.orbElement.dataset.audioLevel = 'medium';
            } else if (value > this.energyThresholds.low) {
                this.orbElement.dataset.audioLevel = 'low';
            } else {
                delete this.orbElement.dataset.audioLevel;
            }

            requestAnimationFrame(animate);
        };

        animate();
    }
    
    async initialize() {
        if (this.isInitialized) return;
        
        try {
            console.log('Initializing audio context...');
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            console.log('Audio context created:', this.audioContext.state);
            
            this.analyser = this.audioContext.createAnalyser();
            this.analyser.fftSize = this.fftSize;
            this.analyser.smoothingTimeConstant = this.smoothingTimeConstant;
            
            const bufferLength = this.analyser.frequencyBinCount;
            this.dataArray = new Uint8Array(bufferLength);
            
            console.log('Requesting microphone access...');
            const stream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            });
            console.log('Microphone access granted');
            
            this.source = this.audioContext.createMediaStreamSource(stream);
            
            const gainNode = this.audioContext.createGain();
            gainNode.gain.value = 4.0;
            
            this.source.connect(gainNode);
            gainNode.connect(this.analyser);
            
            this.isInitialized = true;
            this.startVisualization();
            
            this.updateStatus('Listening...');
            console.log('Audio initialization complete');
        } catch (error) {
            console.error('Error initializing audio:', error);
            let errorMessage = 'Error initializing microphone';
            
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
        
        return sum / (endIndex - startIndex + 1) / 255;
    }
    
    // Method to connect an external analyser node
    connectExternalAnalyser(externalAnalyser) {
        if (!externalAnalyser) return false;
        
        console.log('AudioVisualizer: Connecting external analyser node');
        this.externalAnalyser = externalAnalyser;
        this.isUsingExternalAnalyser = true;
        
        // Create the data array for the external analyser
        const bufferLength = this.externalAnalyser.frequencyBinCount;
        this.externalDataArray = new Uint8Array(bufferLength);
        
        // If visualization is not running, start it
        if (!this.animationFrame) {
            this.startVisualization();
        }
        
        return true;
    }
    
    startVisualization() {
        const updateVisuals = () => {
            let dataArrayToUse;
            let analyserToUse;
            
            // Choose which analyser to use
            if (this.isUsingExternalAnalyser && this.externalAnalyser) {
                analyserToUse = this.externalAnalyser;
                dataArrayToUse = this.externalDataArray;
            } else if (this.isInitialized && this.analyser) {
                analyserToUse = this.analyser;
                dataArrayToUse = this.dataArray;
            } else {
                // No valid analyser available
                this.animationFrame = requestAnimationFrame(updateVisuals);
                return;
            }
            
            // Get frequency data from the active analyser
            analyserToUse.getByteFrequencyData(dataArrayToUse);
            
            // Calculate energy values
            const bass = this.getFrequencyRangeValue(dataArrayToUse, ...this.frequencyRanges.bass);
            const midrange = this.getFrequencyRangeValue(dataArrayToUse, ...this.frequencyRanges.midrange);
            const treble = this.getFrequencyRangeValue(dataArrayToUse, ...this.frequencyRanges.treble);
            
            const weightedEnergy = (bass * 0.2 + midrange * 0.6 + treble * 0.2);
            
            // Update intensity CSS variable for smooth transitions
            this.orbElement.style.setProperty('--intensity', weightedEnergy.toFixed(3));
            
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
        this.orbElement.style.removeProperty('--intensity');
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

window.AudioVisualizer = AudioVisualizer;
