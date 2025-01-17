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
        
        // Bind methods
        this.handleMouseDown = this.handleMouseDown.bind(this);
        this.handleMouseUp = this.handleMouseUp.bind(this);
        
        // Add event listeners
        if (this.talkButton) {
            this.talkButton.addEventListener('mousedown', this.handleMouseDown);
            this.talkButton.addEventListener('mouseup', this.handleMouseUp);
        }
    }
    
    async initialize() {
        if (this.isInitialized) return;
        
        try {
            // Initialize audio context
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            
            // Create analyzer node
            this.analyser = this.audioContext.createAnalyser();
            this.analyser.fftSize = 256;
            this.analyser.smoothingTimeConstant = 0.8;
            
            const bufferLength = this.analyser.frequencyBinCount;
            this.dataArray = new Uint8Array(bufferLength);
            
            // Get microphone access
            const stream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            });
            
            // Create and connect nodes
            this.source = this.audioContext.createMediaStreamSource(stream);
            
            // Add gain node to boost signal
            const gainNode = this.audioContext.createGain();
            gainNode.gain.value = 3.0;
            
            // Connect nodes: source -> gain -> analyser
            this.source.connect(gainNode);
            gainNode.connect(this.analyser);
            
            this.isInitialized = true;
            this.startVisualization();
            
            // Update button text
            if (this.talkButton) {
                this.talkButton.textContent = 'Listening...';
            }
        } catch (error) {
            console.error('Error initializing audio:', error);
            if (this.talkButton) {
                this.talkButton.textContent = 'Error: Click to retry';
            }
        }
    }
    
    startVisualization() {
        if (!this.isInitialized) return;
        
        const updateVisuals = () => {
            // Get frequency data
            this.analyser.getByteFrequencyData(this.dataArray);
            
            // Calculate average of vocal frequency range (85-255 Hz)
            const vocalRangeStart = Math.floor(85 * this.dataArray.length / (this.audioContext.sampleRate / 2));
            const vocalRangeEnd = Math.floor(255 * this.dataArray.length / (this.audioContext.sampleRate / 2));
            let sum = 0;
            let count = 0;
            
            for (let i = vocalRangeStart; i < vocalRangeEnd; i++) {
                sum += this.dataArray[i];
                count++;
            }
            
            const average = sum / count;
            const normalizedValue = average / 255;
            
            // Update orb visualization
            if (normalizedValue > 0.75) {
                this.orbElement.dataset.audioLevel = 'high';
            } else if (normalizedValue > 0.5) {
                this.orbElement.dataset.audioLevel = 'medium';
            } else if (normalizedValue > 0.25) {
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
    
    async handleMouseDown() {
        if (!this.isInitialized) {
            await this.initialize();
        }
        if (this.audioContext) {
            await this.audioContext.resume();
        }
    }
    
    handleMouseUp() {
        if (this.audioContext) {
            this.audioContext.suspend();
        }
    }
}

// Initialize when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.audioVisualizer = new AudioVisualizer();
});
