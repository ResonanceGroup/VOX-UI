import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../controllers/livekit_orb_controller.dart';

/// LiveKit service for managing room connection and agent communication
/// 
/// This service handles:
/// - Room connection and lifecycle management
/// - Agent participant detection and tracking  
/// - Event-based state updates to orb controller
/// - Audio level monitoring for visualization
/// - Microphone control and data messaging
/// - Automatic reconnection with exponential backoff
class LiveKitService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  final LiveKitOrbController _orbController;
  RemoteParticipant? _agent;
  bool _isMuted = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  String _serverUrl = '';
  String _authToken = '';
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  
  // Exponential backoff configuration
  static const int _maxReconnectAttempts = 10;
  static const List<int> _backoffDelays = [2, 4, 8, 16, 32, 64]; // seconds
  
  LiveKitService(this._orbController);
  
  /// Connect to the LiveKit server
  Future<void> connect(String url, String token) async {
    // Store connection details for reconnection
    _serverUrl = url;
    _authToken = token;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    
    return _attemptConnection();
  }
  
  /// Attempt to connect with reconnection logic
  Future<void> _attemptConnection() async {
    if (_isConnecting) return;
    _isConnecting = true;
    
    try {
      // Update orb to connecting state
      _orbController.updateFromLiveKit('connecting', 
          status: _reconnectAttempts > 0 
              ? 'Reconnecting... (attempt ${_reconnectAttempts + 1})' 
              : 'Connecting to server...');
      
      // Create room with options
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      
      // Create event listener
      _listener = _room!.createListener();
      
      // Set up event listeners before connecting
      _setupEventListeners();
      
      // Connect to room
      await _room!.connect(_serverUrl, _authToken);
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0; // Reset on successful connection
      
      // Enable microphone
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      // Check if agent is already present
      _checkForAgent();
      
      debugPrint('[LiveKit] Connected to room');
    } catch (e) {
      debugPrint('[LiveKit] Connection error: $e');
      _isConnecting = false;
      
      // Handle reconnection logic
      if (_shouldReconnect && _reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      } else {
        _orbController.updateFromLiveKit('disconnected', status: 'Connection failed');
        _isConnected = false;
      }
    }
  }
  
  /// Set up all event listeners for room state changes
  void _setupEventListeners() {
    if (_listener == null) return;
    
    // Room disconnected
    _listener!.on<RoomDisconnectedEvent>((event) {
      debugPrint('[LiveKit] Room disconnected');
      _isConnected = false;
      
      // Handle automatic reconnection on disconnect
      if (_shouldReconnect && _reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      } else {
        _orbController.updateFromLiveKit('disconnected', 
            status: 'Disconnected from server');
      }
    });
    
    // Participant connected (agent joins)
    _listener!.on<ParticipantConnectedEvent>((event) {
      debugPrint('[LiveKit] Participant connected: ${event.participant.identity}');
      _checkForAgent();
    });
    
    // Participant disconnected
    _listener!.on<ParticipantDisconnectedEvent>((event) {
      debugPrint('[LiveKit] Participant disconnected: ${event.participant.identity}');
      if (event.participant == _agent) {
        _agent = null;
        _orbController.updateFromLiveKit('connected_no_agent', 
            status: 'Agent disconnected');
      }
    });
    
    // Track published (agent starts publishing audio/video)
    _listener!.on<TrackPublishedEvent>((event) {
      debugPrint('[LiveKit] Track published: ${event.publication.kind}');
    });
    
    // Track subscribed (receiving agent audio)
    _listener!.on<TrackSubscribedEvent>((event) {
      debugPrint('[LiveKit] Track subscribed: ${event.track.kind}');
      if (event.track.kind == TrackType.AUDIO) {
        _setupAudioTracking(event.track as AudioTrack);
      }
    });
    
    // Track muted/unmuted
    _listener!.on<TrackMutedEvent>((event) {
      debugPrint('[LiveKit] Track muted');
      if (_isConnected && !_isMuted) {
        _orbController.updateFromLiveKit('silent', status: 'Listening...');
      }
    });
    
    _listener!.on<TrackUnmutedEvent>((event) {
      debugPrint('[LiveKit] Track unmuted');
    });
    
    // Data received (for text messages and commands)
    _listener!.on<DataReceivedEvent>((event) {
      debugPrint('[LiveKit] Data received from ${event.participant?.identity}');
      // Handle incoming data/messages from agent if needed
      // Can decode event.data as UTF-8 string if it's text
    });
  }
  
  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    // Cancel any existing reconnect timer
    _reconnectTimer?.cancel();
    
    // Calculate delay using exponential backoff
    int delaySeconds;
    if (_reconnectAttempts < _backoffDelays.length) {
      delaySeconds = _backoffDelays[_reconnectAttempts];
    } else {
      // Use maximum delay for subsequent attempts
      delaySeconds = _backoffDelays.last;
    }
    
    _reconnectAttempts++;
    
    debugPrint('[LiveKit] Scheduling reconnection in $delaySeconds seconds (attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldReconnect) {
        debugPrint('[LiveKit] Attempting reconnection...');
        _attemptConnection();
      }
    });
  }
  
  /// Track audio activity from an audio track
  void _setupAudioTracking(AudioTrack track) {
    // Listen for audio activity (speaking detection)
    // Note: LiveKit uses voice activity detection automatically
    // We'll monitor the track's stream state for activity
    track.addListener(() {
      // Track is now active/inactive based on voice activity
      // This is a placeholder - actual implementation depends on
      // how LiveKit exposes audio levels in the Flutter SDK
      debugPrint('[LiveKit] Audio track state changed');
    });
  }
  
  /// Check for agent in the room and update state accordingly
  void _checkForAgent() {
    if (_room == null) return;
    
    // Look for non-local participants (agents)
    final participants = _room!.remoteParticipants.values.toList();
    
    if (participants.isNotEmpty) {
      _agent = participants.first;
      debugPrint('[LiveKit] Agent found: ${_agent!.identity}');
      
      if (_isMuted) {
        _orbController.updateFromLiveKit('muted', 
            status: 'Microphone muted');
      } else {
        _orbController.updateFromLiveKit('connected_with_agent', 
            status: 'Agent connected - Ready');
      }
    } else {
      _agent = null;
      _orbController.updateFromLiveKit('connected_no_agent', 
          status: 'No agent available');
    }
  }
  
  /// Send a text message to the agent via data channel
  Future<void> sendMessage(String text) async {
    if (_room == null || !_isConnected) {
      debugPrint('[LiveKit] Cannot send message: Not connected');
      return;
    }
    
    try {
      // Encode message as UTF-8
      final data = Uint8List.fromList(text.codeUnits);
      
      // Send to all participants (agent) with reliable delivery
      await _room!.localParticipant?.publishData(
        data,
        reliable: true,
      );
      
      debugPrint('[LiveKit] Message sent: $text');
    } catch (e) {
      debugPrint('[LiveKit] Error sending message: $e');
    }
  }
  
  /// Toggle microphone mute state
  Future<void> toggleMute() async {
    if (_room == null) return;
    
    _isMuted = !_isMuted;
    await _room!.localParticipant?.setMicrophoneEnabled(!_isMuted);
    
    if (_isMuted) {
      _orbController.updateFromLiveKit('muted', 
          status: 'Microphone muted');
    } else if (_agent != null) {
      _orbController.updateFromLiveKit('connected_with_agent', 
          status: 'Agent connected - Ready');
    } else {
      _orbController.updateFromLiveKit('connected_no_agent', 
          status: 'No agent available');
    }
    
    debugPrint('[LiveKit] Microphone ${_isMuted ? "muted" : "unmuted"}');
  }
  
  /// Get current mute state
  bool get isMuted => _isMuted;
  
  /// Get connection state
  bool get isConnected => _isConnected;
  
  /// Get agent presence
  bool get hasAgent => _agent != null;
  
  /// Disconnect from the room and clean up
  Future<void> disconnect() async {
    if (_room == null) return;
    
    try {
      // Stop reconnection attempts
      _shouldReconnect = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      
      // Dispose listener first
      _listener?.dispose();
      _listener = null;
      
      // Disconnect and dispose room
      await _room!.disconnect();
      await _room!.dispose();
      _room = null;
      _agent = null;
      _isConnected = false;
      _isMuted = false;
      _isConnecting = false;
      _reconnectAttempts = 0;
      
      _orbController.updateFromLiveKit('disconnected', 
          status: 'Disconnected');
      
      debugPrint('[LiveKit] Disconnected from room');
    } catch (e) {
      debugPrint('[LiveKit] Error disconnecting: $e');
    }
  }
  
  /// Clean up resources
  void dispose() {
    disconnect();
  }
}