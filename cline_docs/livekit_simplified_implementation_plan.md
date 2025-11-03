# LiveKit Simplified Implementation Plan

## Overview
This plan outlines the simplification of the LiveKit service to eliminate over-engineered manual state management and rely on LiveKit's built-in capabilities. The goal is to fix WebRTC timeout and race condition issues by removing conflicting custom logic.

## Current Issues to Fix

### Problematic Manual State Management (Lines 24-35)
```dart
// REMOVE THESE - LiveKit handles internally
bool _isConnected = false;     // ❌ Remove
bool _isConnecting = false;    // ❌ Remove  
bool _connectionLock = Completer<void>()..complete(); // ❌ Remove
int _reconnectAttempts = 0;    // ❌ Remove
Timer? _reconnectTimer;        // ❌ Remove
bool _shouldReconnect = true;  // ❌ Remove
```

### Redundant Connection Logic (Lines 76-107, 449-500)
```dart
// REMOVE _cleanupExistingConnection() - Unnecessary complexity
Future<void> _cleanupExistingConnection() async { /* ... */ }

// REMOVE manual exponential backoff - LiveKit handles this
static const List<int> _backoffDelays = [2, 4, 8, 16, 32, 64];

// REMOVE manual reconnection scheduling - LiveKit handles this  
void _scheduleReconnect() { /* ... */ }
```

## Simplified Architecture

### Core Principle: Let LiveKit Manage Everything
The UI should only **reflect** state, not **manage** it. LiveKit has robust built-in:
- Connection state management
- Automatic reconnection with backoff
- ICE candidate gathering and connection
- Participant identity management
- Resource cleanup

### New Simplified Service Structure

```dart
class LiveKitService {
  static final LiveKitService _instance = LiveKitService._internal();
  factory LiveKitService(LiveKitOrbController orbController) => _instance;
  
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  final LiveKitOrbController _orbController;
  RemoteParticipant? _agent;
  bool _isMuted = false;
  String _serverUrl = '';
  String _authToken = '';
  
  LiveKitService._internal() : _orbController = LiveKitOrbController();
  
  /// Simple connect - let LiveKit handle everything
  Future<void> connect(String url, String token) async {
    _serverUrl = url;
    _authToken = token;
    
    try {
      // Always create fresh room - no manual cleanup needed
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      
      // Set up listeners BEFORE connecting
      _setupEventListeners();
      
      // Single connect call - LiveKit handles ICE, reconnection, etc.
      await _room!.connect(url, token);
      
      // Enable microphone
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      // Check for existing agent
      _checkForAgent();
      
    } catch (e) {
      debugPrint('[LiveKit] Connection error: $e');
      // Let LiveKit's built-in reconnection handle network issues
      _orbController.updateFromLiveKit('disconnected', 
          status: 'Connection failed - check network');
    }
  }
  
  /// Simple disconnect - let LiveKit clean up
  Future<void> disconnect() async {
    if (_room == null) return;
    
    try {
      // LiveKit handles proper cleanup sequence
      await _room!.disconnect();
      await _room!.dispose();
      
      // Clear references - no manual state management
      _room = null;
      _listener?.dispose();
      _listener = null;
      _agent = null;
      
      _orbController.updateFromLiveKit('disconnected');
      
    } catch (e) {
      debugPrint('[LiveKit] Disconnect error: $e');
      // Ensure cleanup even if disconnect fails
      _room = null;
      _listener = null;
      _agent = null;
    }
  }
  
  /// Event listeners - only for UI updates, no state management
  void _setupEventListeners() {
    if (_room == null) return;
    
    _listener = _room!.createListener();
    
    // Connection state changes - just update UI
    _listener!.on<RoomDisconnectedEvent>((event) {
      debugPrint('[LiveKit] Disconnected - let LiveKit handle reconnection');
      // Don't trigger manual reconnection - LiveKit does this automatically
      _orbController.updateFromLiveKit('disconnected');
    });
    
    // Participant events
    _listener!.on<ParticipantConnectedEvent>((event) {
      _checkForAgent();
    });
    
    _listener!.on<ParticipantDisconnectedEvent>((event) {
      if (event.participant == _agent) {
        _agent = null;
        _orbController.updateFromLiveKit('connected_no_agent');
      }
    });
    
    // Audio tracking for visualization
    _listener!.on<TrackSubscribedEvent>((event) {
      if (event.track.kind == TrackType.AUDIO) {
        _setupAudioTracking(event.track as AudioTrack);
      }
    });
    
    // Data messages
    _listener!.on<DataReceivedEvent>((event) {
      // Handle incoming data if needed
    });
  }
  
  /// Simple agent detection - no manual state validation
  void _checkForAgent() {
    if (_room == null) return;
    
    final participants = _room!.remoteParticipants.values.toList();
    if (participants.isNotEmpty) {
      _agent = participants.first;
      _orbController.updateFromLiveKit('connected_with_agent');
    } else {
      _agent = null;
      _orbController.updateFromLiveKit('connected_no_agent');
    }
  }
  
  /// Audio tracking for orb visualization
  void _setupAudioTracking(AudioTrack track) {
    track.addListener(() {
      if (track.isActive && _agent != null) {
        _orbController.updateFromLiveKit('talking');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_agent != null) {
            _orbController.updateFromLiveKit('silent');
          }
        });
      }
    });
  }
  
  /// Essential functionality preserved
  Future<void> sendMessage(String text) async {
    if (_room?.localParticipant != null) {
      final data = Uint8List.fromList(text.codeUnits);
      await _room!.localParticipant?.publishData(data, reliable: true);
    }
  }
  
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _room?.localParticipant?.setMicrophoneEnabled(!_isMuted);
    
    if (_isMuted) {
      _orbController.updateFromLiveKit('muted');
    } else if (_agent != null) {
      _orbController.updateFromLiveKit('connected_with_agent');
    }
  }
  
  bool get isMuted => _isMuted;
  bool get isConnected => _room?.connectionState == ConnectionState.connected;
  bool get hasAgent => _agent != null;
}
```

## Key Changes from Current Implementation

### 1. Removed Manual State Management
- ❌ `_isConnecting`, `_isConnected` - LiveKit tracks this internally
- ❌ `_connectionLock` - Causes race conditions, remove completely
- ❌ `_reconnectAttempts`, `_reconnectTimer`, `_shouldReconnect` - LiveKit handles reconnection
- ❌ Manual exponential backoff - LiveKit has built-in backoff

### 2. Simplified Connection Flow
- ✅ Single `Room` creation per connection
- ✅ Direct `connect()` call - let LiveKit handle ICE gathering
- ✅ No manual cleanup - LiveKit's `disconnect()` and `dispose()` are sufficient
- ✅ No connection validation - LiveKit handles participant identity

### 3. Event-Driven UI Updates Only
- ✅ Listeners only update orb controller state
- ✅ No manual state transitions or reconnection logic
- ✅ Let LiveKit's automatic reconnection work

### 4. Preserved Essential Features
- ✅ Message sending via data channels
- ✅ Microphone mute/unmute
- ✅ Audio level visualization for orb
- ✅ Agent detection and state mapping

## Benefits of This Simplification

### 1. Fixes WebRTC Timeout Issue
- No conflicting manual ICE handling
- LiveKit's built-in WebRTC connection management
- Proper event flow for connection establishment

### 2. Eliminates Race Conditions
- No manual `_connectionLock` causing deadlocks
- No duplicate connection attempts
- LiveKit's thread-safe connection management

### 3. Resolves DUPLICATE_IDENTITY Errors
- No manual identity validation interfering with LiveKit
- Let LiveKit handle participant lifecycle properly
- Clean room disposal prevents identity conflicts

### 4. Cleaner, More Maintainable Code
- Follows LiveKit's recommended patterns
- Less custom code = fewer bugs
- Easier to debug and extend

## Implementation Steps

### Phase 1: Strip Problematic Code
1. Remove all manual state variables (lines 24-35)
2. Delete `_cleanupExistingConnection()` method
3. Remove manual reconnection logic (`_scheduleReconnect()`)
4. Eliminate exponential backoff configuration

### Phase 2: Simplify Connection Logic
1. Replace `_attemptConnection()` with simple `connect()` method
2. Remove manual connection state tracking
3. Simplify error handling to let LiveKit manage reconnection

### Phase 3: Clean Up Event Listeners
1. Remove manual reconnection triggers from disconnect events
2. Simplify event handling to only update UI state
3. Preserve audio tracking and message handling

### Phase 4: Test and Validate
1. Verify WebRTC connection establishes without timeout
2. Confirm no race conditions or DUPLICATE_IDENTITY errors
3. Test automatic reconnection works properly
4. Ensure orb state updates correctly

## Testing Checklist

### Connection Issues Fixed ✅
- [ ] WebRTC peer connection timeout resolved
- [ ] No more "Connection already in progress" errors
- [ ] DUPLICATE_IDENTITY errors eliminated
- [ ] ICE candidate gathering works automatically

### State Management Simplified ✅
- [ ] No manual `_isConnecting`/`_isConnected` flags
- [ ] No `_connectionLock` Completer causing race conditions
- [ ] No manual reconnection logic interfering
- [ ] UI only reflects state, doesn't manage it

### Essential Features Preserved ✅
- [ ] Text messaging to agent works
- [ ] Microphone mute/unmute functional
- [ ] Orb audio visualization working
- [ ] Agent detection and state mapping correct

This simplified approach should resolve all the current issues while making the code much cleaner and easier to maintain.