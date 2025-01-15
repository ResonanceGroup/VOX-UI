// Core elements
const talkButton = document.querySelector('.talk-button');
const orb = document.querySelector('.orb-segments');
const statusDisplay = document.getElementById('status-display');
const textInput = document.querySelector('.text-input');
const sendButton = document.querySelector('.send-button');
const uploadButton = document.querySelector('.upload-button');

// Animation styles
const style = document.createElement('style');
style.textContent = `
@keyframes pulse {
    0% { transform: scale(1) rotate(0deg); }
    50% { transform: scale(1.05) rotate(180deg); }
    100% { transform: scale(1) rotate(360deg); }
}

@keyframes shimmer {
    0% { opacity: 0.7; transform: rotate(0deg); }
    50% { opacity: 1; transform: rotate(180deg); }
    100% { opacity: 0.7; transform: rotate(360deg); }
}
`;
document.head.appendChild(style);

// Status display functions
function updateStatus(text, type = 'info') {
    statusDisplay.textContent = text;
    statusDisplay.className = `status-display status-${type}`;
}

// Talk button interaction
talkButton.addEventListener('mousedown', () => {
    talkButton.classList.add('active');
    talkButton.textContent = 'Release to stop';
    orb.style.animation = 'rotate 10s linear infinite, pulse 2s ease-in-out infinite';
    updateStatus('Listening...');
});

talkButton.addEventListener('mouseup', () => {
    talkButton.classList.remove('active');
    talkButton.textContent = 'Talk to interrupt';
    orb.style.animation = 'rotate 10s linear infinite';
    updateStatus('Processing...');
    // Simulate AI response
    setTimeout(() => {
        updateStatus('Ready to assist...');
    }, 1500);
});

// Text input handling
function handleSendMessage() {
    const message = textInput.value.trim();
    if (message) {
        updateStatus(`You: ${message}`);
        textInput.value = '';
        orb.style.animation = 'rotate 10s linear infinite, shimmer 3s ease-in-out infinite';
        
        // Simulate AI response
        setTimeout(() => {
            updateStatus('AI is responding...');
            setTimeout(() => {
                updateStatus('AI: I received your message.');
                orb.style.animation = 'rotate 10s linear infinite';
            }, 1500);
        }, 500);
    }
}

// Send button click
sendButton.addEventListener('click', handleSendMessage);

// Enter key in text input
textInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        handleSendMessage();
    }
});

// Upload button (placeholder)
uploadButton.addEventListener('click', () => {
    updateStatus('File upload will be available in a future update');
    setTimeout(() => {
        updateStatus('Ready to assist...');
    }, 2000);
});
