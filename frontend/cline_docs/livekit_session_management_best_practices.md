# LiveKit Agents Session Management Best Practices Research Report

## Executive Summary

The research reveals that the VOX-UI Flutter app's "DUPLICATE_IDENTITY" and "SIGNAL_SOURCE_CLOSE" errors are caused by improper connection management patterns. The key solutions involve implementing proper singleton connection management, following correct disconnection sequences, and using LiveKit's built-in state management patterns.

## Key Findings

### 1. **Root Cause Analysis**

**DUPLICATE_IDENTITY Error**: Occurs when multiple participants with the same identity join the room simultaneously, typically caused by:
- Multiple Room instances being created without proper cleanup
- Rapid reconnection attempts without waiting for previous connections to close
- Missing disconnect() calls before creating new connections

**SIGNAL_SOURCE_CLOSE Error**: Related to WebSocket cleanup and connection lifecycle issues:
- Incomplete disconnection sequences leaving orphaned WebSocket connections
- Race conditions in connection/disconnection logic
- Missing dispose() calls after disconnect()

### 2. **Proper Architectural Patterns**

#### Singleton Connection Management Pattern
```dart
class LiveKitConnectionManager {
  static final LiveKitConnectionManager _instance = LiveKitConnectionManager._internal();
  factory LiveKitConnectionManager() => _instance;
  LiveKitConnectionManager._internal();
  
  Room? _currentRoom;
  String? _currentIdentity;
  bool _isConnecting = false;
  
  Future<void> connect(String url, String token, String identity) async {
    // Prevent multiple simultaneous connections
    if (_isConnecting) {
      throw StateError('Connection already in progress');
    }
    
    // Ensure unique identity
    if (_currentIdentity == identity && _currentRoom?.connectionState == ConnectionState.connected) {
      throw StateError('Already connected with this identity');
    }
    
    // Disconnect previous room if exists
    await _cleanupExistingConnection();
    
    _isConnecting = true;
    try {
      final roomOptions = RoomOptions(
        enableVisualizer: true,
        adaptiveStream: true,
        dynacast: true,
      );
      
      _currentRoom = Room(roomOptions: roomOptions);
      await _currentRoom!.connect(url, token);
      await _currentRoom!.localParticipant?.setMicrophoneEnabled(true);
      _currentIdentity = identity;
    } finally {
      _isConnecting = false;
    }
  }
  
  Future<void> _cleanupExistingConnection() async {
    if (_currentRoom != null) {
      try {
        if (_currentRoom!.connectionState != ConnectionState.disconnected) {
          await _currentRoom!.disconnect();
        }
        await _currentRoom!.dispose();
      } catch (e) {
        // Log error but don't throw - cleanup should be idempotent
        print('Error during cleanup: $e');
      } finally {
        _currentRoom = null;
        _currentIdentity = null;
      }
    }
  }
  
  Future<void> disconnect() async {
    await _cleanupExistingConnection();
  }
  
  Room? get currentRoom => _currentRoom;
  bool get isConnected => _currentRoom?.connectionState == ConnectionState.connected;
}
```

#### RoomContext State Management Pattern (Recommended)
```dart
class LiveKitService extends ChangeNotifier {
  RoomContext? _roomContext;
  String? _currentUrl;
  String? _currentToken;
  
  Future<void> initializeConnection(String url, String token) async {
    // Dispose existing context
    await _disposeCurrentContext();
    
    _roomContext = RoomContext(
      url: url,
      token: token,
      connect: true,
    );
    
    _roomContext!.addListener(_onRoomContextChanged);
    notifyListeners();
  }
  
  void _onRoomContextChanged() {
    notifyListeners();
  }
  
  Future<void> _disposeCurrentContext() async {
    if (_roomContext != null) {
      _roomContext!.removeListener(_onRoomContextChanged);
      await _roomContext!.dispose();
      _roomContext = null;
    }
  }
  
  @override
  void dispose() {
    _disposeCurrentContext();
    super.dispose();
  }
}
```

### 3. **Correct Connection/Disconnection Sequences**

#### Proper Disconnection Pattern
```dart
Future<void> _reconnect() async {
  // Step 1: Disconnect current room
  await _room?.disconnect();
  
  // Step 2: Dispose room resources (Critical for cleanup)
  await _room?.dispose();
  
  // Step 3: Create new room instance
  final roomOptions = RoomOptions(enableVisualizer: true);
  _room = Room(roomOptions: roomOptions);
  
  // Step 4: Connect with new token
  await _room!.connect(newUrl, newToken);
  await _room!.localParticipant?.setMicrophoneEnabled(true);
}
```

#### Connection State Management
```dart
void _setupRoomEventHandlers(Room room) {
  room.on<RoomStateChangedEvent>((event) {
    switch (event.newState) {
      case RoomState.connecting:
        _updateOrbState('connecting');
        break;
      case RoomState.connected:
        _updateOrbState('connected');
        break;
      case RoomState.disconnected:
        _handleDisconnection(event.disconnectedReason);
        break;
      case RoomState.reconnecting:
        _updateOrbState('reconnecting');
        break;
    }
  });
  
  room.on<ParticipantConnectedEvent>((event) {
    if (event.participant.isAgent) {
      _updateOrbState('agent_connected');
    }
  });
  
  room.on<DisconnectedEvent>((event) {
    _handleDisconnection(event.reason);
  });
}

void _handleDisconnection(DisconnectReason reason) {
  switch (reason) {
    case DisconnectReason.duplicate_identity:
      _showError('Another connection with this identity is active');
      break;
    case DisconnectReason.room_deleted:
      _showError('Room was deleted');
      break;
    case DisconnectReason.participant_removed:
      _showError('You were removed from the room');
      break;
    default:
      _updateOrbState('disconnected');
  }
}
```

### 4. **State Synchronization Patterns**

#### LiveKitOrbController Integration
```dart
class LiveKitOrbController {
  String _currentOrbState = 'off';
  String _currentLiveKitState = 'disconnected';
  
  void updateFromLiveKit(String liveKitState) {
    _currentLiveKitState = liveKitState;
    final orbState = _mapLiveKitToOrbState(liveKitState);
    if (_currentOrbState != orbState) {
      _currentOrbState = orbState;
      updateState(orbState);
    }
  }
  
  String _mapLiveKitToOrbState(String liveKitState) {
    switch (liveKitState) {
      case 'disconnected':
        return 'off';
      case 'connecting':
      case 'reconnecting':
        return 'muted';
      case 'connected':
        return 'idle';
      case 'agent_connected':
        return 'idle';
      case 'talking':
        return 'active';
      case 'silent':
        return 'idle';
      default:
        return 'off';
    }
  }
}
```

### 5. **Common Pitfalls and Solutions**

#### Issue 1: Visualizer UI Freeze (Fixed in v2.3.4)
- **Problem**: UI freezing during reconnection with enableVisualizer: true
- **Solution**: Update to livekit_client >= 2.3.4, which includes fixes for Visualizer thread safety
- **Workaround**: Disable visualizer on problematic platforms if upgrade not possible

#### Issue 2: Identity Collision
- **Problem**: Rapid reconnection attempts causing identity conflicts
- **Solution**: Implement connection locking and identity validation
- **Code Pattern**:
```dart
Future<void> safeReconnect() async {
  final lock = _connectionLock;
  if (!lock.isCompleted) {
    await lock;
  }
  
  final completer = Completer<void>();
  _connectionLock = completer.future;
  
  try {
    await disconnect();
    await Future.delayed(Duration(milliseconds: 100)); // Brief delay for cleanup
    await connect(newUrl, newToken);
    completer.complete();
  } catch (e) {
    completer.completeError(e);
    rethrow;
  }
}
```

#### Issue 3: Resource Leaks
- **Problem**: Memory leaks from improper cleanup
- **Solution**: Always follow disconnect() → dispose() pattern
- **Best Practice**: Use try-finally blocks for cleanup

### 6. **Recommended Implementation for VOX-UI**

#### Enhanced LiveKitOrbController with Singleton Pattern
```dart
class LiveKitOrbController {
  static final LiveKitOrbController _instance = LiveKitOrbController._internal();
  factory LiveKitOrbController() => _instance;
  LiveKitOrbController._internal();
  
  Room? _room;
  String? _currentIdentity;
  bool _isConnecting = false;
  
  Future<void> initializeAndConnect(String url, String token, String identity) async {
    if (_isConnecting) {
      throw StateError('Connection already in progress');
    }
    
    await _cleanupExistingConnection();
    
    _isConnecting = true;
    try {
      _currentIdentity = identity;
      _room = Room(
        roomOptions: RoomOptions(
          enableVisualizer: true,
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      
      _setupEventHandlers();
      
      await _room!.connect(url, token);
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      updateFromLiveKit('connected');
    } finally {
      _isConnecting = false;
    }
  }
  
  void _setupEventHandlers() {
    _room!.on<RoomStateChangedEvent>((event) {
      updateFromLiveKit(event.newState.toString().toLowerCase());
    });
    
    _room!.on<DisconnectedEvent>((event) {
      handleDisconnection(event.reason);
    });
    
    _room!.on<ParticipantConnectedEvent>((event) {
      if (event.participant.isAgent) {
        updateFromLiveKit('agent_connected');
      }
    });
  }
  
  Future<void> _cleanupExistingConnection() async {
    if (_room != null) {
      try {
        if (_room!.connectionState != ConnectionState.disconnected) {
          await _room!.disconnect();
        }
        await _room!.dispose();
      } catch (e) {
        print('Error during connection cleanup: $e');
      } finally {
        _room = null;
        _currentIdentity = null;
      }
    }
  }
  
  Future<void> disconnect() async {
    await _cleanupExistingConnection();
    updateFromLiveKit('disconnected');
  }
  
  Future<void> sendMessage(String message) async {
    if (_room?.connectionState == ConnectionState.connected) {
      // Send message via data channel
      final data = Uint8List.fromList(utf8.encode(message));
      await _room!.localParticipant?.publishData(data, reliability: Reliability.reliable);
    }
  }
  
  Future<void> toggleMute() async {
    if (_room?.localParticipant != null) {
      final isEnabled = _room!.localParticipant!.isMicrophoneEnabled;
      await _room!.localParticipant!.setMicrophoneEnabled(!isEnabled);
    }
  }
}
```

## Recommendations for VOX-UI Implementation

### 1. **Immediate Actions**
1. Implement the singleton pattern in LiveKitOrbController
2. Ensure disconnect() → dispose() sequence is always followed
3. Add connection locking to prevent race conditions
4. Update to livekit_client >= 2.3.4

### 2. **Architecture Improvements**
1. Use RoomContext pattern for better state management
2. Implement proper event handling for all connection states
3. Add connection retry logic with exponential backoff
4. Implement proper error handling and user feedback

### 3. **Testing Strategy**
1. Test rapid connect/disconnect cycles
2. Test network interruption scenarios
3. Test identity collision scenarios
4. Verify proper cleanup on app termination

### 4. **Future Enhancements**
1. Implement connection quality monitoring
2. Add automatic reconnection with configurable attempts
3. Implement connection state persistence
4. Add analytics for connection reliability metrics

## Conclusion

The VOX-UI app's connection issues stem from improper session management patterns. By implementing the singleton connection manager, following proper disconnect sequences, and using LiveKit's built-in state management, these issues can be resolved. The key is ensuring that each connection attempt is properly managed, with complete cleanup before new connections are established.

## Sources

1. [LiveKit Connection Documentation](https://docs.livekit.io/home/client/connect/)
2. [LiveKit Flutter Client SDK API](https://docs.livekit.io/reference/client-sdk-flutter/)
3. [LiveKit Components Flutter GitHub](https://github.com/livekit/components-flutter)
4. [LiveKit Flutter UI Freeze Issue #659](https://github.com/livekit/client-sdk-flutter/issues/659)
5. [LiveKit Room Class Documentation](https://docs.livekit.io/reference/client-sdk-flutter/livekit_client/Room-class.html)
6. [LiveKit Agents Session Management](https://docs.livekit.io/agents/build/session/)