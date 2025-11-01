# LiveKit Integration Guide for VOX-UI

## Overview
This guide provides the essential information needed to integrate LiveKit Agents with the existing VOX-UI orb widget system, focusing on the core requirements and leveraging existing infrastructure.

## State Mapping Requirements

Based on user feedback, here are the exact state mappings needed:

### LiveKit States → Orb States:
- **Disconnected** → Orb "off" state
- **Connecting** → Orb "muted" state 
- **Connected (Agent Present)** → Orb "idle" state
- **Connected (No Agent)** → Orb "off" state (same as disconnected)
- **Talking** → Orb "active" state
- **Silent** → Orb "idle" state (when connected)

### Special Cases:
- **Microphone Muted**: Show orb in "muted" state regardless of connection
- Always maintain persistent room connection while UI is running
- Auto-connect to single agent when available

## Key Integration Points

### 1. Existing Infrastructure to Leverage:
The current `LiveKitOrbController` already provides:
- State mapping system (`updateFromLiveKit()`)
- Audio level visualization (`updateAudioLevel()`)
- Theme management
- Status text updates
- Protected states (muted/disconnected ignore audio)

### 2. Required Enhancements:
- Add LiveKit client connection logic
- Implement agent participant detection
- Add event listeners for state changes
- Connect text input to message sending
- Integrate mute button with microphone control

## Implementation Approach

### Core Components Needed:

1. **LiveKit Service** (`lib/services/livekit_service.dart`):
   - Handle room connection to local server
   - Manage token authentication (hardcoded for development)
   - Set up event listeners for states and audio levels
   - Provide mute/unmute functionality

2. **Enhanced Chat Screen Integration** (`lib/screens/chat_screen.dart`):
   - Initialize LiveKit service on startup
   - Connect text input to message sending
   - Link existing mute button to LiveKit microphone control
   - Proper cleanup on dispose

## Essential Code Structure

### LiveKit Service Implementation:
```dart
class LiveKitService {
  Room? _room;
  final LiveKitOrbController _orbController;
  
  LiveKitService(this._orbController);
  
  Future<void> connect(String url, String token) async {
    // Connect to local LiveKit server
    _room = await LiveKitClient.connect(url, token);
    _setupEventListeners();
    await _room!.localParticipant.setMicrophoneEnabled(true);
  }
  
  void _setupEventListeners() {
    // Room state changes
    _room!.on<RoomStateChangedEvent>((event) {
      // Map to orb states based on connection status
    });
    
    // Participant events (agent detection)
    _room!.on<ParticipantConnectedEvent>((event) {
      // Check if participant is agent and update state
    });
    
    // Audio level monitoring
    _room!.on<AudioLevelsUpdateEvent>((event) {
      // Convert to orb audio levels for visualization
    });
  }
  
  Future<void> sendMessage(String text) async {
    // Send text message to agent via data channels
  }
  
  Future<void> toggleMute() async {
    // Toggle local microphone state
  }
  
  Future<void> disconnect() async {
    // Clean disconnect
  }
}
```

### Chat Screen Integration:
```dart
class _ChatScreenState extends ConsumerState<ChatScreen> {
  late LiveKitOrbController _orbController;
  late LiveKitService _liveKitService;
  
  @override
  void initState() {
    super.initState();
    _orbController = LiveKitOrbController();
    _liveKitService = LiveKitService(_orbController);
    _connectToLiveKit();
  }
  
  Future<void> _connectToLiveKit() async {
    try {
      // Connect to local server (hardcoded for now)
      await _liveKitService.connect('ws://localhost:7880', 'DEVELOPMENT_TOKEN');
      _orbController.updateFromLiveKit('initializing');
    } catch (e) {
      _orbController.updateFromLiveKit('disconnected');
    }
  }
}
```

## State Mapping Logic

The existing `_mapLiveKitToOrbState()` function in `LiveKitOrbController` needs to be updated to match the new requirements:

```dart
String _mapLiveKitToOrbState(String liveKitState) {
  switch (liveKitState) {
    case 'disconnected':
      return 'off';
    case 'connecting':
    case 'muted':
      return 'muted';
    case 'connected_with_agent':
      return 'idle';
    case 'connected_no_agent':
      return 'off';
    case 'talking':
      return 'active';
    case 'silent':
      return 'idle';
    default:
      return 'off';
  }
}
```

## User Interface Requirements

### Features to Implement:
1. **Text Messaging**: Allow user to type and send messages to agent
2. **Microphone Control**: Use existing mute button to control LiveKit microphone
3. **Visual Feedback**: Orb state changes based on LiveKit connection/audio states

### Features NOT Needed:
1. No transcription display of agent's responses
2. No message history display
3. No multiple agent support

## Dependencies to Add

Add to `pubspec.yaml`:
```yaml
dependencies:
  livekit_client: ^2.0.0  # Latest stable version
  permission_handler: ^10.0.0  # For microphone permissions
```

## Testing Checklist

### Core Functionality:
- [ ] Local LiveKit server connection
- [ ] Automatic agent detection and connection
- [ ] Correct orb state mapping
- [ ] Audio level visualization working
- [ ] Text message sending capability
- [ ] Microphone mute/unmute functionality

### State Transitions:
- [ ] Disconnected → "off" state
- [ ] Connecting → "muted" state
- [ ] Connected (agent) → "idle" state
- [ ] Connected (no agent) → "off" state
- [ ] Talking → "active" state
- [ ] Silent → "idle" state

## Key Benefits of This Approach

1. **Minimal Custom Code**: Leverage existing LiveKit capabilities and VOX-UI infrastructure
2. **Seamless Integration**: Use built-in audio detection and state management
3. **Maintainable**: Follow standard LiveKit patterns and practices
4. **Extensible**: Easy to add features later without major refactoring

This focused approach ensures successful integration while keeping the implementation clean and maintainable.