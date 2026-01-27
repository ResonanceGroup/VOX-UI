// Node-RED Function Node for JSON Payload to Orb Overlay Integration
// Processes JSON payload objects and generates appropriate orb overlay messages

// Store previous state to avoid unnecessary updates
let previousState = null;
let previousAudioLevel = null;

// Valid AI states for the orb overlay
const VALID_STATES = ["idle", "executing", "processing", "muted", "notifying", "disconnected"];

// State descriptions for better status text
const STATE_DESCRIPTIONS = {
    "idle": "Ready to assist...",
    "executing": "Executing command",
    "processing": "Processing request",
    "muted": "Microphone muted",
    "notifying": "Notification received",
    "disconnected": "Disconnected"
};

// Process incoming JSON payload
function processJSONPayload(msg) {
    // Initialize payload if it doesn't exist
    if (!msg.payload) {
        node.warn("No payload in message");
        return null;
    }
    
    // Work with the payload directly
    const payload = msg.payload;
    
    // Initialize output payload
    const outputPayload = {};
    let shouldShowOverlay = false;
    let hasChanges = false;
    
    node.log("Processing JSON payload: " + JSON.stringify(payload));
    
    // Handle state parameter
    if (payload.state !== undefined) {
        let state = payload.state.toString().toLowerCase().trim();
        
        // Validate state
        if (VALID_STATES.includes(state)) {
            // Only trigger show overlay if state actually changed
            if (state !== previousState) {
                node.log("State changed from " + previousState + " to " + state);
                previousState = state;
                shouldShowOverlay = true;
                hasChanges = true;
                
                // Add state and descriptive status
                outputPayload.state = state;
                outputPayload.status = STATE_DESCRIPTIONS[state] || "State: " + state;
            } else {
                // State unchanged - just update without showing overlay
                outputPayload.state = state;
                outputPayload.status = STATE_DESCRIPTIONS[state] || "State: " + state;
                hasChanges = true;
            }
        } else {
            node.warn("Invalid state received: " + state);
            // Still process invalid state
            outputPayload.state = state;
            hasChanges = true;
        }
    }
    
    // Handle audio level parameter
    if (payload.audioLevel !== undefined || payload.level !== undefined) {
        let audioLevel = payload.audioLevel !== undefined ? parseFloat(payload.audioLevel) : parseFloat(payload.level);
        
        // Validate audio level (should be between 0 and 1)
        if (!isNaN(audioLevel) && audioLevel >= 0 && audioLevel <= 1) {
            // Only update if audio level changed significantly (avoid spam)
            if (previousAudioLevel === null || Math.abs(audioLevel - previousAudioLevel) > 0.01) {
                node.log("Audio level updated: " + audioLevel);
                previousAudioLevel = audioLevel;
                outputPayload.level = audioLevel;
                hasChanges = true;
            }
        } else {
            node.warn("Invalid audio level received: " + audioLevel);
        }
    }
    
    // Handle theme parameter
    if (payload.theme !== undefined) {
        const theme = payload.theme.toString().toLowerCase().trim();
        if (theme === "dark" || theme === "light") {
            outputPayload.theme = theme;
            hasChanges = true;
        } else {
            node.warn("Invalid theme received: " + theme);
        }
    }
    
    // Handle status parameter (custom status text)
    if (payload.status !== undefined) {
        outputPayload.status = payload.status.toString();
        hasChanges = true;
    }
    
    // Handle command parameter
    if (payload.command !== undefined) {
        const command = payload.command.toString().toLowerCase().trim();
        if (command === "show" || command === "hide") {
            outputPayload.command = command;
            hasChanges = true;
        } else {
            node.warn("Invalid command received: " + command);
        }
    }
    
    // If we have changes to report
    if (hasChanges) {
        // If we should show overlay due to state change, add command
        if (shouldShowOverlay) {
            outputPayload.command = "show";
        }
        
        // Set the output payload
        msg.payload = outputPayload;
        return msg;
    }
    
    // No changes to report
    return null;
}

// Main function node execution
try {
    const result = processJSONPayload(msg);
    if (result !== null) {
        return result;
    } else {
        // No output - this will cause the node to not send a message
        return null;
    }
} catch (error) {
    node.error("Error processing JSON payload: " + error.message, msg);
    return null;
}