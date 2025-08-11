// Node-RED Notification-based Orb Overlay - Original Design
// This creates a persistent overlay that can receive continuous updates

// Create the overlay and make it persistent
var overlayId = 'persistent-orb-overlay-' + Date.now();

var script = `
<script>
(function() {
    // Check if overlay already exists by looking for the actual DOM element
    var existingOverlay = document.getElementById('persistent-orb-overlay');
    if (existingOverlay && window.updateOrbOverlay) {
        console.log('🔵 Found existing overlay, updating...');
        window.updateOrbOverlay(${JSON.stringify(msg.payload)});
        return;
    }
    
    // Remove any old overlays first
    var oldOverlays = document.querySelectorAll('[id*="persistent-orb-overlay"]');
    oldOverlays.forEach(function(old) {
        old.remove();
    });
    
    console.log('🔵 Creating new overlay...');
    
    // Create persistent overlay with fixed ID
    var overlay = document.createElement('div');
    overlay.id = 'persistent-orb-overlay';
    overlay.style.cssText = \`
        position: fixed !important;
        top: 0 !important;
        left: 0 !important;
        width: 100vw !important;
        height: 100vh !important;
        z-index: 999999 !important;
        background: rgba(255, 255, 255, 1) !important;
        backdrop-filter: blur(2px) !important;
        display: none !important;
        opacity: 0 !important;
        transition: opacity 0.5s ease-in-out !important;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif !important;
        color: #333 !important;
        cursor: pointer !important;
        pointer-events: auto !important;
        isolation: isolate !important;
        visibility: visible !important;
    \`;
    
    overlay.innerHTML = \`
        <div class="overlay-content" style="
            flex: 1 !important;
            display: flex !important;
            flex-direction: column !important;
            align-items: center !important;
            justify-content: center !important;
            gap: 5px !important;
            padding: 4rem !important;
            min-height: 500px !important;
            background: radial-gradient(circle at center, rgba(64, 206, 224, 0.02) 0%, transparent 70%) !important;
        ">
            <div class="orb" style="
                position: relative !important;
                width: 300px !important;
                height: 300px !important;
                margin-bottom: 1rem !important;
                display: flex !important;
                justify-content: center !important;
                align-items: center !important;
                filter: drop-shadow(0 0 20px rgba(64, 206, 224, 0.3)) !important;
                transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1) !important;
                overflow: visible !important;
                border-radius: 50% !important;
                --intensity: 0;
            ">
                <div class="orb-status-effects" style="
                    position: absolute !important;
                    top: 0 !important;
                    left: 0 !important;
                    width: 100% !important;
                    height: 100% !important;
                    pointer-events: none !important;
                    z-index: 1 !important;
                ">
                    <div class="orb-status-ring" style="
                        position: absolute !important;
                        top: 50% !important;
                        left: 50% !important;
                        transform: translate(-50%, -50%) !important;
                        width: calc(100% + 16px) !important;
                        height: calc(100% + 16px) !important;
                        border-radius: 50% !important;
                        border: 3px solid transparent !important;
                        opacity: 0 !important;
                        transition: border-color 0.3s ease, opacity 0.3s ease !important;
                    "></div>
                    <div class="orb-particles" style="
                        position: absolute !important;
                        top: 0 !important;
                        left: 0 !important;
                        width: 100% !important;
                        height: 100% !important;
                        pointer-events: none !important;
                        z-index: 2 !important;
                    "></div>
                </div>
                <div class="wrap" style="
                    position: absolute !important;
                    top: 50% !important;
                    left: 50% !important;
                    width: 260px !important;
                    height: 260px !important;
                    margin: -130px 0 0 -130px !important;
                    animation: rotate 40s infinite linear !important;
                    z-index: 1 !important;
                    mix-blend-mode: screen !important;
                    filter: contrast(1.2) saturate(1.2) !important;
                    transform-style: preserve-3d !important;
                    perspective: 1000px !important;
                ">
                    <div class="c c1" style="
                        position: absolute !important;
                        top: 50% !important;
                        left: 50% !important;
                        width: 220px !important;
                        height: 220px !important;
                        margin: -110px 0 0 -110px !important;
                        border-radius: 60% 40% 55% 45% / 45% 55% 45% 55% !important;
                        transform: rotate(0deg) translateX(20px) !important;
                        transform-origin: center !important;
                        transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1) !important;
                        mix-blend-mode: plus-lighter !important;
                        opacity: 0.85 !important;
                        animation: morph 20s infinite ease-in-out !important;
                        animation-delay: -0.0s !important;
                        filter: blur(6px) brightness(1.3) contrast(1.4) !important;
                        background: radial-gradient(circle at 30% 30%, rgba(255, 128, 255, calc(0.8 + var(--intensity, 0) * 0.2)) 0%, rgba(255, 64, 192, calc(0.7 + var(--intensity, 0) * 0.2)) 30%, rgba(192, 32, 255, calc(0.5 + var(--intensity, 0) * 0.2)) 60%, transparent 85%) !important;
                    "></div>
                    <div class="c c2" style="
                        position: absolute !important;
                        top: 50% !important;
                        left: 50% !important;
                        width: 220px !important;
                        height: 220px !important;
                        margin: -110px 0 0 -110px !important;
                        border-radius: 60% 40% 55% 45% / 45% 55% 45% 55% !important;
                        transform: rotate(120deg) translateX(25px) !important;
                        transform-origin: center !important;
                        transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1) !important;
                        mix-blend-mode: plus-lighter !important;
                        opacity: 0.85 !important;
                        animation: morph 20s infinite ease-in-out !important;
                        animation-delay: -6.0s !important;
                        filter: blur(6px) brightness(1.3) contrast(1.4) !important;
                        background: radial-gradient(circle at 30% 30%, rgba(64, 192, 255, calc(0.8 + var(--intensity, 0) * 0.2)) 0%, rgba(32, 128, 255, calc(0.7 + var(--intensity, 0) * 0.2)) 30%, rgba(64, 32, 255, calc(0.5 + var(--intensity, 0) * 0.2)) 60%, transparent 85%) !important;
                    "></div>
                    <div class="c c3" style="
                        position: absolute !important;
                        top: 50% !important;
                        left: 50% !important;
                        width: 220px !important;
                        height: 220px !important;
                        margin: -110px 0 0 -110px !important;
                        border-radius: 60% 40% 55% 45% / 45% 55% 45% 55% !important;
                        transform: rotate(240deg) translateX(22px) !important;
                        transform-origin: center !important;
                        transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1) !important;
                        mix-blend-mode: plus-lighter !important;
                        opacity: 0.85 !important;
                        animation: morph 20s infinite ease-in-out !important;
                        animation-delay: -12.0s !important;
                        filter: blur(6px) brightness(1.3) contrast(1.4) !important;
                        background: radial-gradient(circle at 30% 30%, rgba(255, 192, 128, calc(0.8 + var(--intensity, 0) * 0.2)) 0%, rgba(255, 128, 64, calc(0.7 + var(--intensity, 0) * 0.2)) 30%, rgba(255, 64, 128, calc(0.5 + var(--intensity, 0) * 0.2)) 60%, transparent 85%) !important;
                    "></div>
                </div>
            </div>
            <div id="status-display" class="status-display" style="
                color: #555 !important;
                font-size: 0.9rem !important;
                opacity: 0.9 !important;
                display: inline-flex !important;
                align-items: center !important;
                justify-content: center !important;
                gap: 6px !important;
                text-align: center !important;
                line-height: 1.5 !important;
                min-height: 1.5em !important;
                transition: color 0.3s ease, opacity 0.3s ease !important;
                margin-top: 5px !important;
            ">
                <span class="status-icon" style="
                    display: inline-block !important;
                    transition: color 0.3s ease !important;
                "></span>
                <span class="status-text" style="
                    display: inline-block !important;
                    transition: opacity 0.3s ease !important;
                ">Ready to assist...</span>
            </div>
        </div>
    \`;
    
    // Add CSS animations and styles
    var style = document.createElement('style');
    style.textContent = \`
        /* Glass sphere effect */
        .orb::before {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            width: 260px;
            height: 260px;
            transform: translate(-50%, -50%);
            background: radial-gradient(
                circle at 25% 25%,
                rgba(255, 255, 255, 0.95) 0%,
                rgba(255, 255, 255, 0.9) 4%,
                rgba(148, 255, 238, 0.5) 8%,
                rgba(64, 206, 224, 0.3) 12%,
                rgba(64, 159, 255, 0.1) 20%,
                transparent 30%
            );
            border-radius: 50%;
            box-shadow: 
                inset 0 0 30px rgba(255, 255, 255, 0.4),
                inset 0 0 60px rgba(64, 206, 224, 0.3),
                inset 0 0 100px rgba(95, 89, 255, 0.2);
            z-index: 3;
            backdrop-filter: blur(2px);
            transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1);
        }
        
        /* Ripple effects */
        .orb::after {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            width: calc(100% + 40px);
            height: calc(100% + 40px);
            transform: translate(-50%, -50%);
            border-radius: 50%;
            background: radial-gradient(
                circle at center,
                rgba(64, 206, 224, calc(0.15 * var(--intensity, 0))) 0%,
                rgba(95, 89, 255, calc(0.1 * var(--intensity, 0))) 30%,
                rgba(148, 255, 238, calc(0.05 * var(--intensity, 0))) 60%,
                transparent 80%
            );
            filter: blur(20px);
            animation: ripple 3s infinite ease-in-out;
            opacity: var(--intensity, 0);
            z-index: -1;
            transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1);
        }
        
        @keyframes rotate {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }
        
        @keyframes morph {
            0%, 100% { 
                transform: scale(calc(0.85 + var(--intensity, 0) * 0.15)) translateY(0) rotate(0deg);
                border-radius: 60% 40% 55% 45% / 45% 55% 45% 55%;
                opacity: calc(0.85 + var(--intensity, 0) * 0.15);
            }
            33% { 
                transform: scale(calc(1.1 + var(--intensity, 0) * 0.15)) translateY(-15px) rotate(120deg);
                border-radius: 45% 55% 40% 60% / 55% 45% 55% 45%;
                opacity: calc(0.95 + var(--intensity, 0) * 0.05);
            }
            66% {
                transform: scale(calc(0.9 + var(--intensity, 0) * 0.15)) translateY(15px) rotate(240deg);
                border-radius: 55% 45% 60% 40% / 40% 60% 40% 60%;
                opacity: calc(0.75 + var(--intensity, 0) * 0.25);
            }
        }
        
        @keyframes ripple {
            0%, 100% {
                transform: translate(-50%, -50%) scale(1);
                filter: blur(20px) brightness(1);
            }
            50% {
                transform: translate(-50%, -50%) scale(1.1);
                filter: blur(25px) brightness(1.2);
            }
        }
        
        @keyframes glow {
            0%, 100% {
                box-shadow: 
                    inset 0 0 30px rgba(255, 255, 255, calc(0.4 + var(--intensity, 0) * 0.2)),
                    inset 0 0 60px rgba(64, 206, 224, calc(0.3 + var(--intensity, 0) * 0.3)),
                    inset 0 0 100px rgba(95, 89, 255, calc(0.2 + var(--intensity, 0) * 0.2));
            }
            50% {
                box-shadow: 
                    inset 0 0 40px rgba(255, 255, 255, calc(0.5 + var(--intensity, 0) * 0.2)),
                    inset 0 0 80px rgba(64, 206, 224, calc(0.4 + var(--intensity, 0) * 0.3)),
                    inset 0 0 120px rgba(95, 89, 255, calc(0.3 + var(--intensity, 0) * 0.2));
            }
        }
        
        .orb[data-audio-level]::before {
            animation: glow 3s infinite ease-in-out;
        }
        
        .orb[data-audio-level] {
            animation: pulse 3s infinite ease-in-out;
        }
        
        .orb[data-audio-level="low"] {
            filter: drop-shadow(0 0 25px rgba(64, 206, 224, calc(0.4 + var(--intensity, 0) * 0.2)));
        }
        
        .orb[data-audio-level="medium"] {
            filter: drop-shadow(0 0 35px rgba(64, 206, 224, calc(0.5 + var(--intensity, 0) * 0.3)));
        }
        
        .orb[data-audio-level="high"] {
            filter: drop-shadow(0 0 45px rgba(64, 206, 224, calc(0.6 + var(--intensity, 0) * 0.4)));
        }
        
        @keyframes pulse {
            0%, 100% {
                transform: scale(1);
            }
            50% {
                transform: scale(calc(1 + var(--intensity, 0) * 0.05));
            }
        }
        
        @keyframes pulse-ring {
            0% {
                opacity: 0.3;
                transform: translate(-50%, -50%) scale(1);
                border-color: #7E57C2;
            }
            50% {
                opacity: 0.7;
                transform: translate(-50%, -50%) scale(1.1);
                border-color: #9575CD;
            }
            100% {
                opacity: 0.3;
                transform: translate(-50%, -50%) scale(1);
                border-color: #7E57C2;
            }
        }
        
        @keyframes particle-burst {
            0% {
                transform: translate(-50%, -50%) scale(0.5);
                opacity: 1;
            }
            100% {
                transform: translate(-50%, -50%) translate(var(--x, 50px), var(--y, 50px)) scale(0);
                opacity: 0;
            }
        }
        
        @keyframes state-transition-flash {
            0%, 100% { filter: brightness(1); }
            50% { filter: brightness(1.3); }
        }
        
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
        
        /* State classes */
        .state-executing .orb-status-ring {
            border-color: #7E57C2 !important;
            border-width: 3px !important;
            box-shadow: 0 0 15px rgba(126, 87, 194, 0.6) !important;
            opacity: 0.5 !important;
            animation: pulse-ring 1.5s infinite ease-in-out !important;
        }
        
        .state-processing .wrap {
            animation-duration: 15s !important;
        }
        
        .state-processing .c {
            animation-duration: 12s !important;
            filter: blur(6px) brightness(1.5) contrast(1.5) !important;
        }
        
        .state-muted .orb {
            filter: grayscale(1) !important;
            transition: filter 0.3s ease-in-out !important;
        }
        
        .state-disconnected .orb {
            filter: grayscale(1) !important;
        }
        
        .state-disconnected .wrap,
        .state-disconnected .wrap *,
        .state-disconnected .c,
        .state-disconnected .orb::before,
        .state-disconnected .orb::after {
            animation-play-state: paused !important;
            transition: none !important;
        }
        
        .transitioning .orb {
            animation: state-transition-flash 0.15s ease-in-out !important;
        }
        
        /* Individual particle styling */
        .particle {
            position: absolute;
            top: 50%;
            left: 50%;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            transform: translate(-50%, -50%);
            opacity: 0;
            pointer-events: none;
            box-shadow: 0 0 8px 2px rgba(100, 181, 246, 0.8);
            z-index: 2;
        }
        
        /* Light theme (default) */
        #persistent-orb-overlay .overlay-content {
            background: radial-gradient(circle at center, rgba(64, 206, 224, 0.02) 0%, transparent 70%) !important;
        }
        
        #persistent-orb-overlay .status-display {
            color: #555 !important;
            opacity: 0.9 !important;
        }
        
        /* Dark theme */
        .overlay-dark .overlay-content {
            background: radial-gradient(circle at center, rgba(64, 206, 224, 0.05) 0%, transparent 70%) !important;
        }
        
        .overlay-dark .status-display {
            color: #D0D0D0 !important;
            opacity: 0.85 !important;
        }
    \`;
    document.head.appendChild(style);
    
    // Global variables
    let currentAIState = 'idle';
    let underlyingAIState = 'idle';
    const ALL_STATES = ['idle', 'executing', 'notifying', 'processing', 'muted', 'disconnected'];
    
    let statusIcon = null;
    let statusText = null;
    let orbElement = null;
    let orbParticles = null;
    
    // Initialize elements
    statusIcon = overlay.querySelector('.status-icon');
    statusText = overlay.querySelector('.status-text');
    orbElement = overlay.querySelector('.orb');
    orbParticles = overlay.querySelector('.orb-particles');
    
    // Create particles for notification effect
    function createParticles() {
        if (!orbParticles) return;
        
        // Clear any existing particles
        orbParticles.innerHTML = '';
        
        // Create 7-10 particles
        const particleCount = Math.floor(Math.random() * 3) + 7;
        
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
            particle.style.setProperty('--x', x + 'px');
            particle.style.setProperty('--y', y + 'px');
            particle.style.backgroundColor = color;
            
            // Larger particles (8-16px)
            const size = 8 + Math.random() * 8;
            particle.style.width = size + 'px';
            particle.style.height = size + 'px';
            
            // Animation duration (500-700ms)
            const duration = 500 + Math.random() * 200;
            particle.style.animation = 'particle-burst ' + duration + 'ms forwards ease-out';
            
            // Add to container
            orbParticles.appendChild(particle);
        }
        
        // Create a flash effect on the orb for notification emphasis
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
    
    // Add transition flash effect between states
    function triggerTransitionEffect() {
        if (!orbElement) return;
        
        // Add transitioning class
        overlay.classList.add('transitioning');
        
        // Remove it after animation completes
        setTimeout(() => {
            overlay.classList.remove('transitioning');
        }, 150);
    }
    
    // Update UI state
    function updateUIState(newState, detail = '') {
        if (!ALL_STATES.includes(newState)) {
            console.warn('Invalid AI state provided:', newState);
            return;
        }

        // If we're changing states (not just updating detail), trigger transition
        if (newState !== currentAIState) {
            triggerTransitionEffect();
        }

        console.log('Updating UI State: ' + newState + ', Detail: ' + detail);

        // Manage State Classes on Overlay
        ALL_STATES.forEach(state => overlay.classList.remove('state-' + state));
        overlay.classList.add('state-' + newState);
        
        // Store the state before mute if not already muted
        if (newState === 'muted' && currentAIState !== 'muted') {
            underlyingAIState = currentAIState === 'muted' ? 'idle' : currentAIState;
        }
        
        currentAIState = newState;

        // Update Status Bar
        if (!statusIcon || !statusText) {
            return;
        }
        
        let textContent = 'Ready to assist...';
        let iconContent = '';

        switch (newState) {
            case 'idle':
                textContent = 'Ready to assist...';
                iconContent = '●';
                statusIcon.style.color = '#4CAF50';
                break;
            case 'executing':
                textContent = 'Executing: ' + (detail || 'Task') + '...';
                iconContent = '⚙️';
                statusIcon.style.color = '#7E57C2';
                break;
            case 'processing':
                textContent = detail || 'Processing';
                iconContent = '';
                break;
            case 'notifying':
                textContent = detail || 'Notification Received';
                iconContent = '🔔';
                statusIcon.style.color = '#42A5F5';
                
                // Create particle effect with slight delay to ensure DOM is ready
                setTimeout(() => createParticles(), 10);
                
                // Revert state after a longer delay to show the full effect
                setTimeout(() => {
                    // Only revert if still in notifying state (user might have changed it)
                    if (currentAIState === 'notifying') {
                        updateUIState(underlyingAIState || 'idle');
                    }
                }, 2500);
                break;
            case 'muted':
                textContent = 'Microphone Muted';
                iconContent = '🔇';
                statusIcon.style.color = '#FFA726';
                break;
            case 'disconnected':
                textContent = 'Disconnected';
                iconContent = '❌';
                statusIcon.style.color = '#F44336';
                break;
        }

        statusIcon.textContent = iconContent;
        statusText.textContent = textContent;

        console.log('UI updated for state: ' + newState);
    }
    
    // Global update function
    window.updateOrbOverlay = function(payload) {
        console.log('🔵 Updating orb overlay:', payload);
        
        // Always get the current overlay from DOM to ensure we're working with the right element
        var currentOverlay = document.getElementById('persistent-orb-overlay');
        if (!currentOverlay) {
            console.error('🔴 Overlay not found in DOM!');
            return;
        }
        
        // Handle commands first (highest priority)
        if (payload.command) {
            console.log('🔵 Processing command:', payload.command);
            if (payload.command === 'show') {
                console.log('🔵 Showing overlay');
                // Hide original notification first
                setTimeout(hideOriginalNotification, 50);
                currentOverlay.style.display = 'flex';
                currentOverlay.offsetHeight; // Force reflow
                currentOverlay.style.opacity = '1';
                // Don't return - continue processing other properties like theme
            } else if (payload.command === 'hide') {
                console.log('🔵 Hiding overlay - current display:', currentOverlay.style.display, 'opacity:', currentOverlay.style.opacity);
                currentOverlay.style.opacity = '0';
                setTimeout(function() {
                    currentOverlay.style.display = 'none';
                    console.log('🔵 Overlay hidden - final display:', currentOverlay.style.display);
                }, 500);
                return; // Exit early for hide command only - don't process other properties
            }
        }
        
        // Handle theme
        if (payload.theme) {
            console.log('🔵 Processing theme:', payload.theme);
            if (payload.theme === 'dark') {
                currentOverlay.classList.add('overlay-dark');
                currentOverlay.style.background = 'rgba(0, 0, 0, 1)';
                currentOverlay.style.color = '#fff';
                console.log('🔵 Applied dark theme - background set to black');
            } else {
                currentOverlay.classList.remove('overlay-dark');
                currentOverlay.style.background = 'rgba(255, 255, 255, 1)';
                currentOverlay.style.color = '#333';
                console.log('🔵 Applied light theme - background set to white');
            }
        }
        
        // Handle state changes
        if (payload.state) {
            updateUIState(payload.state, payload.status || '');
        }
        
        // Handle status (if state not provided but status is)
        if (payload.status && !payload.state) {
            updateUIState(currentAIState, payload.status);
        }
        
        // Handle audio level - get orb element from current overlay
        if (payload.level !== undefined) {
            var currentOrbElement = currentOverlay.querySelector('.orb');
            if (currentOrbElement) {
                var level = parseFloat(payload.level) || 0;
                currentOrbElement.style.setProperty('--intensity', level.toFixed(3));
                
                // Set audio level data attribute
                if (level > 0.75) {
                    currentOrbElement.dataset.audioLevel = 'high';
                } else if (level > 0.5) {
                    currentOrbElement.dataset.audioLevel = 'medium';
                } else if (level > 0.25) {
                    currentOrbElement.dataset.audioLevel = 'low';
                } else {
                    delete currentOrbElement.dataset.audioLevel;
                }
            }
        }
    };
    
    // Double-tap to dismiss
    var lastTapTime = 0;
    overlay.addEventListener('click', function() {
        var currentTime = new Date().getTime();
        var timeDiff = currentTime - lastTapTime;
        
        if (timeDiff < 300 && timeDiff > 0) {
            // Double tap - hide overlay
            overlay.style.opacity = '0';
            setTimeout(() => {
                overlay.style.display = 'none';
            }, 500);
        }
        
        lastTapTime = currentTime;
    });
    
    // Hide the original notification rectangle
    function hideOriginalNotification() {
        // Find and hide the notification toast that Node-RED creates
        var notifications = document.querySelectorAll('.ui-pnotify, .toast, [class*="notification"], [class*="toast"]');
        notifications.forEach(function(notification) {
            if (notification && notification.style) {
                notification.style.display = 'none !important';
                notification.style.visibility = 'hidden !important';
                notification.style.opacity = '0 !important';
            }
        });
        
        // Also try to hide any notification containers
        var containers = document.querySelectorAll('.ui-pnotify-container, .toast-container, [class*="notification-container"]');
        containers.forEach(function(container) {
            if (container && container.style) {
                container.style.display = 'none !important';
                container.style.visibility = 'hidden !important';
            }
        });
    }
    
    // Add to page
    document.body.appendChild(overlay);
    
    // Hide original notification after a brief delay to ensure it's rendered
    setTimeout(hideOriginalNotification, 100);
    setTimeout(hideOriginalNotification, 500); // Try again after 500ms
    
    // Initial update with current payload
    window.updateOrbOverlay(${JSON.stringify(msg.payload)});
    
})();
</script>
`;

msg.payload = script;
return msg;