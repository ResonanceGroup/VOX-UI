# LiveKit Integration Implementation Plan

## Overview
Implementation plan for integrating LiveKit Agents with VOX-UI orb widget system, following the official LiveKit reference implementation patterns while meeting specific requirements.

## Phase 1: Core LiveKit Integration

### 1.1 LiveKit Client Setup
- Create `LiveKitClient` service for local server connection
- Implement persistent room connection management
- Set up token service for local authentication (hardcoded for development)
- Configure room options with audio visualization enabled

### 1.2 State Management Controller
- Enhance `LiveKitOrbController` to handle:
  - Room connection events
  - Participant detection (auto-connect to single agent)
  - Audio level monitoring
  - Microphone mute control
- Implement state mapping using constants from `livekit_orb_state_mapping.md`

### 1.3 Event Listeners
- Room state changes (connected/disconnected/connecting)
- Participant join/leave events
- Audio level updates from LiveKit visualizer
- Microphone mute/unmute events

## Phase 2: Orb Widget Integration

### 2.1 State Mapping Implementation
- Map LiveKit states to orb visual states:
  - Disconnected → "off"
  - Connecting/Muted → "muted" 
  - Connected (agent present) → "idle"
  - Connected (no agent) → "off"
  - Talking (audio active) → "active"
  - Silent (audio inactive) → "idle"

### 2.2 Audio Level Integration
- Use LiveKit's built-in audio level detection
- Convert audio levels to orb brightness/size parameters
- Implement smooth transitions between audio states

### 2.3 Control Integration
- Connect mute button to LiveKit microphone control
- Implement message sending functionality
- Add connection status indicators

## Phase 3: User Interface Features

### 3.1 Text Messaging
- Create message input field in chat screen
- Implement send button functionality
- Send text messages to LiveKit agent via data channels
- No display of received messages (per requirements)

### 3.2 Microphone Control
- Mute button toggles local microphone state
- Visual feedback in orb widget
- Proper state synchronization between UI and LiveKit

## Technical Implementation Details

### Class Structure:
```
LiveKitClient (Service)
├── TokenService (local auth)
├── RoomConnectionManager
└── EventHandlers

LiveKitOrbController (Controller) 
├── StateMapper
├── AudioLevelMonitor
└── ParticipantDetector

OrbWidget (View)
├── StateRenderer
├── AudioVisualizer
└── ControlInterface
```

### Key Integration Points:

1. **Room Management**:
   ```dart
   // Persistent connection to local LiveKit server
   await room.connect(serverUrl, token);
   await room.localParticipant?.setMicrophoneEnabled(true);
   ```

2. **Agent Detection**:
   ```dart
   // Auto-detect single agent participant
   final agentParticipant = room.remoteParticipants.values
     .firstWhere((p) => p.isAgent, orElse: () => null);
   ```

3. **Audio Monitoring**:
   ```dart
   // Use LiveKit's built-in audio visualization
   roomOptions: const RoomOptions(enableVisualizer: true)
   ```

4. **State Synchronization**:
   ```dart
   // Map LiveKit states to orb states
   void updateOrbState(LiveKitState state) {
     final orbState = mapLiveKitToOrbState(state);
     orbController.updateState(orbState);
   }
   ```

## Development Steps

### Step 1: Environment Setup
- [ ] Configure local LiveKit server connection
- [ ] Set up development authentication (hardcoded token)
- [ ] Test basic room connection

### Step 2: Controller Implementation  
- [ ] Create LiveKitOrbController with state mapping
- [ ] Implement participant detection logic
- [ ] Add audio level monitoring
- [ ] Test state transitions

### Step 3: Widget Integration
- [ ] Connect controller to existing orb widget
- [ ] Implement state mapping constants
- [ ] Test visual state changes
- [ ] Verify audio level feedback

### Step 4: User Features
- [ ] Add message input field to chat screen
- [ ] Implement message sending to agent
- [ ] Connect mute button to microphone control
- [ ] Test end-to-end functionality

## Testing Requirements

### Connection Scenarios:
- [ ] Local server connection success
- [ ] Agent auto-detection and connection
- [ ] Persistent room membership
- [ ] Graceful disconnection handling

### State Transitions:
- [ ] Disconnected → Off state
- [ ] Connecting → Muted state
- [ ] Connected (agent) → Idle state
- [ ] Connected (no agent) → Off state
- [ ] Audio active → Active state
- [ ] Audio inactive → Idle state

### User Controls:
- [ ] Mute button toggles microphone
- [ ] Text input sends messages
- [ ] Visual feedback for all states

## Future Considerations

### Enhanced Features (Post MVP):
- Message history display
- Transcription visualization
- Multiple agent support
- Advanced audio processing
- Connection quality indicators

### Architecture Improvements:
- Configuration service for server URLs
- Environment-based token management
- Advanced state persistence
- Error handling and recovery

## Risk Mitigation

### Potential Issues:
1. **Local Server Connectivity**: Ensure robust reconnection logic
2. **Agent Detection Timing**: Handle race conditions in participant detection
3. **Audio Level Sensitivity**: Calibrate audio detection thresholds
4. **State Synchronization**: Prevent state conflicts between systems

### Solutions:
- Implement connection retry mechanisms
- Add participant detection timeouts
- Provide audio level calibration options
- Use single source of truth for state management

## Dependencies

### Required LiveKit Components:
- `livekit_client` - Core SDK
- `livekit_components` - UI components and audio visualization
- `provider` - State management (already in use)

### Existing VOX-UI Components:
- `OrbWidget` - Visual state display
- `ChatScreen` - Message input interface
- `LiveKitOrbController` - Existing controller to enhance

## Success Criteria

### Functional Requirements:
✅ Persistent local LiveKit connection
✅ Automatic single agent detection
✅ Correct orb state mapping
✅ Microphone mute control
✅ Text message sending capability

### Technical Requirements:
✅ Following LiveKit reference implementation patterns
✅ Proper state management and event handling
✅ Smooth audio level visualization
✅ Robust error handling and recovery
✅ Maintainable and extensible code structure

## Next Steps

1. Review state mapping constants in `livekit_orb_state_mapping.md`
2. Begin implementation of LiveKit client service
3. Enhance LiveKitOrbController with mapping logic
4. Integrate with existing orb widget
5. Test end-to-end functionality
6. Document final implementation details