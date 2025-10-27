// Core elements
const talkButton = document.querySelector('.talk-button');
const orb = document.querySelector('.orb');
const statusDisplay = document.getElementById('status-display');
const textInput = document.querySelector('.text-input');
const sendButton = document.querySelector('.send-button');
const uploadButton = document.querySelector('.upload-button');
const muteButton = document.querySelector('.mute-button');
const sidebarToggle = document.getElementById('sidebar-toggle');
const sidebar = document.querySelector('.sidebar');
const sidebarItems = document.querySelectorAll('.sidebar-item');

// Create overlay element
let overlay = document.querySelector('.overlay');
if (!overlay) {
    overlay = document.createElement('div');
    overlay.className = 'overlay';
    document.body.appendChild(overlay);
}

// State
let isMuted = false;
let activeSection = 'chat';
let isSidebarOpen = false;

// Status display functions
function updateStatus(text, type = 'info') {
    if (statusDisplay) {
        statusDisplay.textContent = text;
        statusDisplay.className = `status-display status-${type}`;
    }
}

// Talk button interaction
if (talkButton && orb) {
    talkButton.addEventListener('mousedown', () => {
        if (isMuted) {
            updateStatus('Microphone is muted');
            return;
        }
        talkButton.classList.add('active');
        talkButton.textContent = 'Release to stop';
        orb.dataset.audioLevel = 'high';
        updateStatus('Listening...');
    });

    talkButton.addEventListener('mouseup', () => {
        if (isMuted) return;
        talkButton.classList.remove('active');
        talkButton.textContent = 'Talk to interrupt';
        delete orb.dataset.audioLevel;
        updateStatus('Processing...');
        // Simulate AI response
        setTimeout(() => {
            updateStatus('Ready to assist...');
        }, 1500);
    });
}


// Text input handling
function handleSendMessage() {
    if (!textInput || !orb) return;
    const message = textInput.value.trim();
    if (message) {
        updateStatus(`You: ${message}`);
        textInput.value = '';
        orb.dataset.audioLevel = 'medium';
        
        // Simulate AI response
        setTimeout(() => {
            updateStatus('AI is responding...');
            setTimeout(() => {
                updateStatus('AI: I received your message.');
                delete orb.dataset.audioLevel;
            }, 1500);
        }, 500);
    }
}

// Send button click
if (sendButton) {
    sendButton.addEventListener('click', handleSendMessage);
}
if (textInput) {
    textInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            handleSendMessage();
        }
    });
}

// Upload button (placeholder)
if (uploadButton) {
    uploadButton.addEventListener('click', () => {
        updateStatus('File upload will be available in a future update');
        setTimeout(() => {
            updateStatus('Ready to assist...');
        }, 2000);
    });
}

// Mute button icons
const micOnIcon = 'M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.91-3c-.49 0-.9.36-.98.85C16.52 14.2 14.47 16 12 16s-4.52-1.8-4.93-4.15c-.08-.49-.49-.85-.98-.85-.61 0-1.09.54-1 1.14.49 3 2.89 5.35 5.91 5.78V20c0 .55.45 1 1 1s1-.45 1-1v-2.08c3.02-.43 5.42-2.78 5.91-5.78.1-.6-.39-1.14-1-1.14z';
const micOffIcon = 'M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3z';

// Mute button
if (muteButton) {
    muteButton.addEventListener('click', () => {
        isMuted = !isMuted;
        muteButton.title = isMuted ? 'Unmute microphone' : 'Mute microphone';
        const path = muteButton.querySelector('path');
        if (path) {
            path.setAttribute('d', isMuted ? micOffIcon : micOnIcon);
        }
        updateStatus(isMuted ? 'Microphone muted' : 'Microphone active');
        setTimeout(() => {
            updateStatus('Ready to assist...');
        }, 1500);
    });
}

// Sidebar logic moved to shared_ui.js

// Accordion logic moved to shared_ui.js
