import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../controllers/livekit_orb_controller.dart';

/// Simplified LiveKit service for managing room connection and agent communication
/// 
/// This service follows LiveKit's recommended patterns:
/// - Let LiveKit handle connection state management internally
/// - Use built-in automatic reconnection
/// - UI only reflects state, doesn't manage it
/// - Simple connect/disconnect lifecycle
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
  Timer? _localAudioTimer;
  
  LiveKitService._internal() : _orbController = LiveKitOrbController();
  
  /// Simple connect - let LiveKit handle everything
  Future<void> connect(String url, String token) async {
    final urlPreview = url.length > 50 ? '${url.substring(0, 50)}...' : url;
    debugPrint('[LiveKit] 🔌 Connecting to: $urlPreview');
    
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
      
      _orbController.updateFromLiveKit('connecting', status: 'Connecting to server...');
      
      // Single connect call - LiveKit handles ICE, reconnection, etc.
      await _room!.connect(url, token);
      debugPrint('[LiveKit] Room connected successfully');
      
      // Enable microphone
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      // Check if agent is already present
      _checkForAgent();
      
      // Update with successful connection status
      debugPrint('[LiveKit] 🟢 Connected successfully');
      _orbController.updateFromLiveKit('connected_with_agent',
          status: 'Connection established');
          
    } catch (e, stackTrace) {
      debugPrint('[LiveKit] ❌ Connection error: $e');
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
      
      // Cancel any active timers
      _localAudioTimer?.cancel();
      _localAudioTimer = null;
      
      _orbController.updateFromLiveKit('disconnected');
      debugPrint('[LiveKit] Disconnected from room');
      
    } catch (e) {
      debugPrint('[LiveKit] Error disconnecting: $e');
      // Ensure cleanup even if disconnect fails
      _room = null;
      _listener = null;
      _agent = null;
      _localAudioTimer?.cancel();
      _localAudioTimer = null;
    }
  }
  
  /// Event listeners - only for UI updates, no state management
  void _setupEventListeners() {
    if (_room == null) return;
    
    _listener = _room!.createListener();
    
    // Connection state changes - just update UI
    _listener!.on<RoomDisconnectedEvent>((event) {
      debugPrint('[LiveKit] Room disconnected');
      // Don't trigger manual reconnection - LiveKit does this automatically
      _orbController.updateFromLiveKit('disconnected');
    });
    
    // Participant events
    _listener!.on<ParticipantConnectedEvent>((event) {
      debugPrint('[LiveKit] Participant connected: ${event.participant.identity}');
      _checkForAgent();
    });
    
    _listener!.on<ParticipantDisconnectedEvent>((event) {
      debugPrint('[LiveKit] Participant disconnected: ${event.participant.identity}');
      if (event.participant == _agent) {
        _agent = null;
        _orbController.updateFromLiveKit('connected_no_agent');
      }
    });
    
    // Track published (agent starts publishing audio/video)
    _listener!.on<TrackPublishedEvent>((event) {
      // debugPrint('[LiveKit] Track published: ${event.publication.kind}');
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
      // debugPrint('[LiveKit] Track muted');
      if (_agent != null && !_isMuted) {
        _orbController.updateFromLiveKit('silent', status: 'Listening...');
      }
    });
    
    _listener!.on<TrackUnmutedEvent>((event) {
      // debugPrint('[LiveKit] Track unmuted');
    });
    
    // Active speakers changed - for real-time speaking detection
    _listener!.on<ActiveSpeakersChangedEvent>((event) {
      if (_agent != null && !_isMuted) {
        // Check if our agent is in the active speakers list
        final agentIsSpeaking = event.speakers.contains(_agent);
        
        if (agentIsSpeaking) {
          _orbController.updateFromLiveKit('talking',
              status: 'Agent speaking...',
              level: _agent!.audioLevel);
        } else {
          _orbController.updateFromLiveKit('silent',
              status: 'Listening...',
              level: 0.0);
        }
      }
    });
    
    // Data received (for text messages and commands)
    _listener!.on<DataReceivedEvent>((event) {
      // debugPrint('[LiveKit] Data received from ${event.participant?.identity}');
      // Handle incoming data/messages from agent if needed
    });
  }
  
  /// Simple agent detection - no manual state validation
  void _checkForAgent() {
    if (_room == null) return;
    
    // Look for non-local participants (agents)
    final participants = _room!.remoteParticipants.values.toList();
    if (participants.isNotEmpty) {
      _agent = participants.first;
      debugPrint('[LiveKit] Agent connected: ${_agent!.identity}');
      
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
  
  /// Track audio activity from an audio track
  void _setupAudioTracking(AudioTrack track) {
    // Listen for audio activity (speaking detection) using actual audio levels
    track.addListener(() {
      // Track state changed - monitor for actual audio activity
      // debugPrint('[LiveKit] Audio track state changed');
      
      // Check if participant is speaking based on actual audio levels
      if (_agent != null && !_isMuted) {
        // Use participant's isSpeaking property for accurate detection
        final isSpeaking = _agent!.isSpeaking;
        // debugPrint('[LiveKit] Agent speaking status: $isSpeaking, audioLevel: ${_agent!.audioLevel}');
        
        if (isSpeaking) {
          _orbController.updateFromLiveKit('talking',
              status: 'Agent speaking...',
              level: _agent!.audioLevel);
        } else {
          // Only update to silent if we were previously talking
          _orbController.updateFromLiveKit('silent',
              status: 'Listening...',
              level: 0.0);
        }
      }
    });
    
    // Start monitoring actual audio levels for visualization
    _monitorAudioLevel(track);
  }
  
  /// Monitor audio levels for visualization using actual audio data
  void _monitorAudioLevel(AudioTrack track) {
    // Create a timer to periodically check actual audio levels
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_agent == null || track.isDisposed) {
        timer.cancel();
        return;
      }
      
      // Get actual audio level from participant
      double audioLevel = _agent!.audioLevel;
      
      // Update orb with actual audio level for visualization
      if (audioLevel > 0.01) { // Only update if there's actual audio
        _orbController.updateAudioLevel(audioLevel);
      }
    });
  }
  
  /// Send a text message to the agent via data channel
  Future<void> sendMessage(String text) async {
    if (_room?.localParticipant != null) {
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
  }
  
  /// Toggle microphone mute state
  Future<void> toggleMute() async {
    if (_room == null) {
      debugPrint('[LiveKit] Cannot toggle mute: No room');
      return;
    }
    
    if (_room!.localParticipant == null) {
      debugPrint('[LiveKit] Cannot toggle mute: No local participant');
      return;
    }
    
    _isMuted = !_isMuted;
    debugPrint('[LiveKit] Microphone ${_isMuted ? "muted" : "unmuted"}');
    
    try {
      // Use setMicrophoneEnabled to properly handle track publishing
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
      
      // Start monitoring local audio levels for user feedback
      if (!_isMuted && _room!.localParticipant != null) {
        _monitorLocalAudioLevel();
      }
    } catch (e) {
      debugPrint('[LiveKit] Error toggling mute: $e');
      // Revert mute state if operation failed
      _isMuted = !_isMuted;
    }
  }
  
  /// Monitor local audio levels for user microphone feedback
  void _monitorLocalAudioLevel() {
    // Clear any existing local audio monitoring
    if (_localAudioTimer != null) {
      _localAudioTimer!.cancel();
      _localAudioTimer = null;
    }
    
    // Only monitor when not muted
    if (_isMuted) return;
    
    // Create a timer to periodically check local audio levels
    _localAudioTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_room?.localParticipant == null || _isMuted) {
        timer.cancel();
        _localAudioTimer = null;
        return;
      }
      
      // Get actual local audio level from local participant
      double audioLevel = _room!.localParticipant!.audioLevel;
      
      // Update orb with local audio level for user feedback
      if (audioLevel > 0.01) { // Only update if there's actual audio
        _orbController.updateAudioLevel(audioLevel);
      }
    });
  }
  
  /// Get current mute state
  bool get isMuted => _isMuted;
  
  /// Get connection state from LiveKit (not manual tracking)
  bool get isConnected => _room?.connectionState == ConnectionState.connected;
  
  /// Get agent presence
  bool get hasAgent => _agent != null;
  
  /// Clean up resources with proper async handling
  Future<void> dispose() async {
    await disconnect();
  }
}