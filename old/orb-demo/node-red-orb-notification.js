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
            background: rgba(255, 255, 255, 1);
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
                <div class="orb">
                    <div class="orb-status-effects">
                        <div class="orb-status-ring"></div>
                        <div class="orb-particles"></div>
                    </div>
                    <div class="wrap">
                        <div class="c"></div>
                        <div class="c"></div>
                        <div class="c"></div>
                    </div>
                </div>
                <div id="status-display" class="status-display">
                    <span class="status-icon"></span>
                    <span class="status-text">Ready to assist...</span>
                </div>
            </div>
        \`;
        
        // Add complete CSS from original styles.css
        var style = document.createElement('style');
        style.textContent = \`
            /* Orb styles */
            .orb {
                position: relative;
                width: 300px;
                height: 300px;
                margin-bottom: 1rem;
                display: flex;
                justify-content: center;
                align-items: center;
                filter: drop-shadow(0 0 20px rgba(64, 206, 224, 0.3));
                transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1);
                overflow: visible;
                border-radius: 50%;
                --intensity: 0;
            }

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

            /* Inner swirl container */
            .wrap {
                position: absolute;
                top: 50%;
                left: 50%;
                width: 260px;
                height: 260px;
                margin: -130px 0 0 -130px;
                animation: rotate 40s infinite linear;
                z-index: 1;
                mix-blend-mode: screen;
                filter: contrast(1.2) saturate(1.2);
                transform-style: preserve-3d;
                perspective: 1000px;
            }

            @keyframes rotate {
                from { transform: rotate(0deg); }
                to { transform: rotate(360deg); }
            }

            /* Swirling shapes */
            .c {
                position: absolute;
                top: 50%;
                left: 50%;
                width: 220px;
                height: 220px;
                margin: -110px 0 0 -110px;
                border-radius: 60% 40% 55% 45% / 45% 55% 45% 55%;
                transform-origin: center;
                transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1);
                mix-blend-mode: plus-lighter;
                opacity: 0.85;
                animation: morph 20s infinite ease-in-out;
                filter: blur(6px) brightness(1.3) contrast(1.4);
            }

            @keyframes morph {
                0%, 100% {
                    transform: scale(calc(0.85 + var(--intensity) * 0.15)) translateY(0) rotate(0deg);
                    border-radius: 60% 40% 55% 45% / 45% 55% 45% 55%;
                    opacity: calc(0.85 + var(--intensity) * 0.15);
                }
                33% {
                    transform: scale(calc(1.1 + var(--intensity) * 0.15)) translateY(-15px) rotate(120deg);
                    border-radius: 45% 55% 40% 60% / 55% 45% 55% 45%;
                    opacity: calc(0.95 + var(--intensity) * 0.05);
                }
                66% {
                    transform: scale(calc(0.9 + var(--intensity) * 0.15)) translateY(15px) rotate(240deg);
                    border-radius: 55% 45% 60% 40% / 40% 60% 40% 60%;
                    opacity: calc(0.75 + var(--intensity) * 0.25);
                }
            }

            /* Distinct color patterns for each shape */
            .c:nth-child(1) {
                transform: rotate(0deg) translateX(20px);
                animation-delay: -0.0s;
                background: radial-gradient(
                    circle at 30% 30%,
                    rgba(255, 128, 255, calc(0.8 + var(--intensity) * 0.2)) 0%,
                    rgba(255, 64, 192, calc(0.7 + var(--intensity) * 0.2)) 30%,
                    rgba(192, 32, 255, calc(0.5 + var(--intensity) * 0.2)) 60%,
                    transparent 85%
                );
                transition: background 0.5s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .c:nth-child(2) {
                transform: rotate(120deg) translateX(25px);
                animation-delay: -6.0s;
                background: radial-gradient(
                    circle at 30% 30%,
                    rgba(64, 192, 255, calc(0.8 + var(--intensity) * 0.2)) 0%,
                    rgba(32, 128, 255, calc(0.7 + var(--intensity) * 0.2)) 30%,
                    rgba(64, 32, 255, calc(0.5 + var(--intensity) * 0.2)) 60%,
                    transparent 85%
                );
                transition: background 0.5s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .c:nth-child(3) {
                transform: rotate(240deg) translateX(22px);
                animation-delay: -12.0s;
                background: radial-gradient(
                    circle at 30% 30%,
                    rgba(255, 192, 128, calc(0.8 + var(--intensity) * 0.2)) 0%,
                    rgba(255, 128, 64, calc(0.7 + var(--intensity) * 0.2)) 30%,
                    rgba(255, 64, 128, calc(0.5 + var(--intensity) * 0.2)) 60%,
                    transparent 85%
                );
                transition: background 0.5s cubic-bezier(0.4, 0, 0.2, 1);
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
                    rgba(64, 206, 224, calc(0.15 * var(--intensity))) 0%,
                    rgba(95, 89, 255, calc(0.1 * var(--intensity))) 30%,
                    rgba(148, 255, 238, calc(0.05 * var(--intensity))) 60%,
                    transparent 80%
                );
                filter: blur(20px);
                animation: ripple 3s infinite ease-in-out;
                opacity: var(--intensity);
                z-index: -1;
                transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .orb[data-audio-level]::before {
                animation: glow 3s infinite ease-in-out;
            }

            @keyframes glow {
                0%, 100% {
                    box-shadow:
                        inset 0 0 30px rgba(255, 255, 255, calc(0.4 + var(--intensity) * 0.2)),
                        inset 0 0 60px rgba(64, 206, 224, calc(0.3 + var(--intensity) * 0.3)),
                        inset 0 0 100px rgba(95, 89, 255, calc(0.2 + var(--intensity) * 0.2));
                }
                50% {
                    box-shadow:
                        inset 0 0 40px rgba(255, 255, 255, calc(0.5 + var(--intensity) * 0.2)),
                        inset 0 0 80px rgba(64, 206, 224, calc(0.4 + var(--intensity) * 0.3)),
                        inset 0 0 120px rgba(95, 89, 255, calc(0.3 + var(--intensity) * 0.2));
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

            /* Audio level animations */
            .orb[data-audio-level] {
                animation: pulse 3s infinite ease-in-out;
            }

            .orb[data-audio-level="low"] {
                filter: drop-shadow(0 0 25px rgba(64, 206, 224, calc(0.4 + var(--intensity) * 0.2)));
            }

            .orb[data-audio-level="medium"] {
                filter: drop-shadow(0 0 35px rgba(64, 206, 224, calc(0.5 + var(--intensity) * 0.3)));
            }

            .orb[data-audio-level="high"] {
                filter: drop-shadow(0 0 45px rgba(64, 206, 224, calc(0.6 + var(--intensity) * 0.4)));
            }

            @keyframes pulse {
                0%, 100% {
                    transform: scale(1);
                }
                50% {
                    transform: scale(calc(1 + var(--intensity) * 0.05));
                }
            }

            /* Styles for Orb Effects Container */
            .orb-status-effects {
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                pointer-events: none;
                z-index: 1;
            }

            /* Ring effect for Executing state */
            .orb-status-ring {
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                width: calc(100% + 16px);
                height: calc(100% + 16px);
                border-radius: 50%;
                border: 3px solid transparent;
                opacity: 0;
                transition: border-color 0.3s ease, opacity 0.3s ease;
            }

            /* Particle container for Notifying state */
            .orb-particles {
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                pointer-events: none;
                z-index: 2;
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

            /* Animations for status indicators */
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

            /* Status indicator state classes */
            .state-executing .orb-status-ring {
                border-color: #7E57C2;
                border-width: 3px;
                box-shadow: 0 0 15px rgba(126, 87, 194, 0.6);
                opacity: 0.5;
                animation: pulse-ring 1.5s infinite ease-in-out;
            }

            .state-executing .orb {
                position: relative;
                overflow: visible;
            }

            .state-executing .orb .c {
                opacity: 0.35;
            }

            .state-executing .orb::before {
                content: '';
                position: absolute;
                width: 100%;
                height: 100%;
                border-radius: 50%;
                background: radial-gradient(
                    circle at 30% 25%,
                    rgba(255, 255, 255, 0.9) 0%,
                    rgba(255, 255, 255, 0.7) 5%,
                    rgba(255, 255, 255, 0.4) 15%,
                    rgba(200, 200, 255, 0.1) 40%,
                    rgba(200, 200, 255, 0) 70%
                );
                box-shadow:
                    inset 0 0 20px rgba(255, 255, 255, 0.4),
                    0 0 15px rgba(126, 87, 194, 0.5);
                opacity: 0.95;
                z-index: 5;
                pointer-events: none;
                mix-blend-mode: overlay;
            }

            .state-executing .orb-status-ring {
                border-color: rgba(126, 87, 194, 0.7);
                border-width: 3px;
                box-shadow:
                    inset 0 0 10px rgba(126, 87, 194, 0.2),
                    0 0 15px rgba(126, 87, 194, 0.4);
            }

            .state-executing .orb::after {
                content: '';
                position: absolute;
                top: 50%;
                left: 50%;
                width: 60%;
                height: 60%;
                transform: translate(-50%, -50%) scale(0.1);
                transform-origin: center center;
                background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Cdefs%3E%3ClinearGradient id='gearGradient' x1='0%25' y1='0%25' x2='100%25' y2='100%25'%3E%3Cstop offset='0%25' stop-color='%23EEEEEE' /%3E%3Cstop offset='45%25' stop-color='%23AAAAAA' /%3E%3Cstop offset='100%25' stop-color='%23666666' /%3E%3C/linearGradient%3E%3C/defs%3E%3Cpath d='M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z' fill='url(%23gearGradient)' stroke='%23444444' stroke-width='0.4'/%3E%3C/svg%3E");
                background-size: 80% 80%;
                background-repeat: no-repeat;
                background-position: center center;
                opacity: 0;
                filter: drop-shadow(0 0 8px rgba(126, 87, 194, 0.5));
                pointer-events: none;
                z-index: 3;
                animation:
                    appear-from-center 0.8s forwards ease-out,
                    rotate-gear 5s infinite linear 0.8s;
            }

            @keyframes appear-from-center {
                0% {
                    transform: translate(-50%, -50%) scale(0.1);
                    opacity: 0;
                }
                60% {
                    transform: translate(-50%, -50%) scale(1.15);
                    opacity: 0.95;
                }
                100% {
                    transform: translate(-50%, -50%) scale(1);
                    opacity: 0.9;
                }
            }

            @keyframes rotate-gear {
                0% { transform: translate(-50%, -50%) rotate(0deg); }
                100% { transform: translate(-50%, -50%) rotate(360deg); }
            }

            .state-executing .orb .c {
                animation-duration: 1.8s;
            }

            .state-processing .wrap {
                animation-duration: 15s;
            }

            .state-processing .c {
                animation-duration: 12s;
                filter: blur(6px) brightness(1.5) contrast(1.5);
            }

            .state-muted .orb {
                filter: grayscale(1);
                transition: filter 0.3s ease-in-out;
            }

            .state-disconnected .orb {
                filter: grayscale(1) !important;
            }

            /* Light mode: Washed out version (lighter against white background) */
            @media (prefers-color-scheme: light) {
                .state-disconnected .orb {
                    filter: grayscale(1) brightness(1.6) !important;
                }
            }

            .state-disconnected .wrap,
            .state-disconnected .wrap *,
            .state-disconnected .c,
            .state-disconnected .orb::before,
            .state-disconnected .orb::after {
                animation-play-state: paused !important;
                transition: none !important;
            }

            /* Add subtle static noise effect to disconnected state */
            .state-disconnected .orb::before {
                background-image: url("data:image/svg+xml,%3Csvg width='100%25' height='100%25' xmlns='http://www.w3.org/2000/svg'%3E%3Cdefs%3E%3Cfilter id='noise' x='0%25' y='0%25' width='100%25' height='100%25'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3CfeColorMatrix type='saturate' values='0'/%3E%3CfeComponentTransfer%3E%3CfeFuncR type='linear' slope='0.1'/%3E%3CfeFuncG type='linear' slope='0.1'/%3E%3CfeFuncB type='linear' slope='0.1'/%3E%3C/feComponentTransfer%3E%3CfeComponentTransfer%3E%3CfeFuncR type='linear' slope='3' intercept='-0.9'/%3E%3CfeFuncG type='linear' slope='3' intercept='-0.9'/%3E%3CfeFuncB type='linear' slope='3' intercept='-0.9'/%3E%3C/feComponentTransfer%3E%3C/filter%3E%3C/defs%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E"), radial-gradient(
                    circle at 25% 25%,
                    rgba(255, 255, 255, 0.95) 0%,
                    rgba(255, 255, 255, 0.9) 4%,
                    rgba(148, 148, 148, 0.5) 8%,
                    rgba(64, 64, 64, 0.3) 12%,
                    rgba(64, 64, 64, 0.1) 20%,
                    transparent 30%
                );
                opacity: 0.9;
                mix-blend-mode: overlay;
            }

            .transitioning .orb {
                animation: state-transition-flash 0.15s ease-in-out;
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
            
            @keyframes pulse {
                0%, 100% {
                    transform: scale(1);
                }
                50% {
                    transform: scale(calc(1 + var(--intensity, 0) * 0.05));
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
            
            /* Audio level animations - copied exactly from original styles.css */
            .orb[data-audio-level]::before {
                animation: glow 3s infinite ease-in-out;
            }
            
            .orb[data-audio-level] {
                animation: pulse 3s infinite ease-in-out;
            }
            
            .orb[data-audio-level="low"] {
                filter: drop-shadow(0 0 25px rgba(64, 206, 224, calc(0.4 + var(--intensity) * 0.2)));
            }
            
            .orb[data-audio-level="medium"] {
                filter: drop-shadow(0 0 35px rgba(64, 206, 224, calc(0.5 + var(--intensity) * 0.3)));
            }
            
            .orb[data-audio-level="high"] {
                filter: drop-shadow(0 0 45px rgba(64, 206, 224, calc(0.6 + var(--intensity) * 0.4)));
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
                font-size: 0.9rem !important;
                opacity: 0.9 !important;
                display: inline-flex !important;
                align-items: center !important;
                justify-content: center !important;
                gap: 6px !important;
                text-align: center !important;
                line-height: 1.5 !important;
                min-height: 1.5em !important;
                margin-top: 5px !important;
            }
            
            #persistent-orb-overlay .status-text {
                display: inline-block !important;
                transition: opacity 0.3s ease !important;
            }
            
            #persistent-orb-overlay .status-icon {
                display: inline-block !important;
                transition: color 0.3s ease !important;
            }
            
            /* Hide the toast notification body element */
            md-toast, md-toast .md-toast-content {
                visibility: hidden;
            }

            /* Dark theme - more specific selectors to override inline styles */
            #persistent-orb-overlay.overlay-dark {
                background: rgba(0, 0, 0, 1) !important;
                color: #fff !important;
            }
            
            #persistent-orb-overlay[data-theme="dark"] {
                background: rgba(0, 0, 0, 1) !important;
                color: #fff !important;
            }
            
            .overlay-dark .overlay-content {
                background: radial-gradient(circle at center, rgba(64, 206, 224, 0.05) 0%, transparent 70%) !important;
            }
            
            .overlay-dark .status-display {
                color: #D0D0D0 !important;
                opacity: 0.85 !important;
            }
            
            .overlay-dark .status-text {
                color: #D0D0D0 !important;
                display: inline-block !important;
            }
            
            .overlay-dark .status-icon {
                color: #81C784 !important; /* Match original VOX-UI dark mode idle color */
                display: inline-block !important;
            }
            
            /* Disconnected state styling */
            .state-disconnected .status-icon,
            .state-disconnected .status-text {
                color: #F44336 !important;
                font-weight: bold !important;
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

            // Manage State Classes on Body (like the original working code)
            ALL_STATES.forEach(state => document.body.classList.remove('state-' + state));
            document.body.classList.add('state-' + newState);
            
            console.log('🔵 Applied state class "state-' + newState + '" to document.body');
            
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
                    break;
                case 'executing':
                    textContent = 'Executing: ' + (detail || 'Task') + '...';
                    iconContent = '⚙️';
                    break;
                case 'processing':
                    textContent = detail || 'Processing';
                    iconContent = '';
                    break;
                case 'notifying':
                    textContent = detail || 'Notification Received';
                    iconContent = '🔔';
                    
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
                    break;
                case 'disconnected':
                    textContent = 'Disconnected';
                    iconContent = '❌';
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
                // Try to find any overlay with similar ID
                var allOverlays = document.querySelectorAll('[id*="orb-overlay"]');
                console.log('🔍 Found overlays:', allOverlays.length, allOverlays);
                return;
            }
            console.log('🔵 Found overlay:', currentOverlay.id, 'display:', currentOverlay.style.display, 'opacity:', currentOverlay.style.opacity);
            
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
                    console.log('🔵 Hiding overlay and notification container...');
                    
                    try {
                        // First, fade out the overlay
                        if (currentOverlay) {
                            console.log('🔵 Fading out overlay');
                            currentOverlay.style.opacity = '0';
                            // Wait for fade animation to complete before removing from DOM
                            setTimeout(() => {
                                if (currentOverlay && currentOverlay.parentNode) {
                                    console.log('🔵 Removing overlay from DOM after fade:', currentOverlay);
                                    currentOverlay.parentNode.removeChild(currentOverlay);
                                    console.log('🔵 Overlay successfully removed from DOM');
                                }
                            }, 500); // Match the CSS transition time
                        }
                        
                        // Now find and remove the parent notification container
                        var notificationContainers = document.querySelectorAll('.ui-pnotify, .toast, [class*="notification"], .ui-pnotify-container, .pnotify, .notification-container');
                        console.log('🔵 Found notification containers:', notificationContainers.length);
                        
                        notificationContainers.forEach(function(container, index) {
                            try {
                                // Check if this container is empty or only contains our removed overlay
                                if (container && (container.children.length === 0 || container.textContent.trim() === '')) {
                                    console.log('🔵 Removing empty notification container', index, ':', container);
                                    if (container.parentNode) {
                                        container.parentNode.removeChild(container);
                                    }
                                } else if (container) {
                                    // Hide the container if it's not empty
                                    console.log('🔵 Hiding notification container', index, ':', container);
                                    container.style.display = 'none';
                                    container.style.opacity = '0';
                                    container.style.visibility = 'hidden';
                                }
                            } catch (e) {
                                console.log('🔴 Error handling container', index, ':', e);
                            }
                        });
                        
                        // Clear the global flag
                        window.orbOverlayActive = false;
                        
                    } catch (e) {
                        console.log('🔴 Error in hide command:', e);
                        // Fallback: hide everything we can find
                        if (currentOverlay) {
                            currentOverlay.style.opacity = '0';
                            // Wait for fade animation to complete before hiding
                            setTimeout(() => {
                                if (currentOverlay) {
                                    currentOverlay.style.visibility = 'hidden';
                                    currentOverlay.style.display = 'none';
                                }
                            }, 500); // Match the CSS transition time
                        }
                        window.orbOverlayActive = false;
                    }
                    
                    console.log('🔵 Hide command completed - overlay and containers should be hidden');
                    return; // Exit early for hide command only - don't process other properties
                }
            }
            
            // Handle theme
            if (payload.theme) {
                console.log('🔵 Processing theme:', payload.theme);
                if (payload.theme === 'dark') {
                    currentOverlay.classList.add('overlay-dark');
                    console.log('🔵 Applied dark theme');
                } else {
                    currentOverlay.classList.remove('overlay-dark');
                    console.log('🔵 Applied light theme');
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
            
            // Handle audio level - support both 'level' and 'audioLevel' property names
            var audioLevel = payload.level !== undefined ? payload.level : payload.audioLevel;
            if (audioLevel !== undefined) {
                var currentOrbElement = currentOverlay.querySelector('.orb');
                if (currentOrbElement) {
                    var level = parseFloat(audioLevel) || 0;
                    console.log('🎵 Setting audio level:', level, 'from payload property:', payload.level !== undefined ? 'level' : 'audioLevel');
                    console.log('🎵 Full payload:', payload);
                    console.log('🎵 Target element:', currentOrbElement);
                    
                    currentOrbElement.style.setProperty('--intensity', level.toFixed(3));
                    console.log('🎵 Set --intensity CSS property to:', level.toFixed(3));
                    
                    // Set audio level data attribute
                    if (level > 0.75) {
                        currentOrbElement.dataset.audioLevel = 'high';
                        console.log('🎵 Set data-audio-level="high"');
                    } else if (level > 0.5) {
                        currentOrbElement.dataset.audioLevel = 'medium';
                        console.log('🎵 Set data-audio-level="medium"');
                    } else if (level > 0.25) {
                        currentOrbElement.dataset.audioLevel = 'low';
                        console.log('🎵 Set data-audio-level="low"');
                    } else {
                        delete currentOrbElement.dataset.audioLevel;
                        console.log('🎵 Removed data-audio-level attribute (level was', level, ')');
                    }
                    
                    // Debug: Check computed styles
                    var computedStyle = window.getComputedStyle(currentOrbElement);
                    console.log('🎵 Current orb transform:', computedStyle.transform);
                    console.log('🎵 Current orb animation:', computedStyle.animation);
                    console.log('🎵 Current orb filter:', computedStyle.filter);
                    console.log('🎵 Current --intensity value:', computedStyle.getPropertyValue('--intensity'));
                } else {
                    console.error('🎵 Could not find .orb element in overlay');
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