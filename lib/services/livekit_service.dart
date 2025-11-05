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
  
  // Audio level scaling factors to amplify visualization intensity
  static const double _agentAudioLevelScaleFactor = 2.0;  // For AI voice output
  static const double _micAudioLevelScaleFactor = 1.0;    // For mic input
  
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
      
      // Enable microphone with AGC
      await _room!.localParticipant?.setMicrophoneEnabled(true,
        audioCaptureOptions: const AudioCaptureOptions(
          autoGainControl: true,
          echoCancellation: true,
          noiseSuppression: true,
        ));
      
      // Check if agent is already present
      _checkForAgent();
      
      // Update with successful connection status
      _orbController.updateFromLiveKit('connected_with_agent',
          status: 'Connection established');
          
    } catch (e, stackTrace) {
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
      
    } catch (e) {
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
    
    // Track published (agent starts publishing audio/video)
    _listener!.on<TrackPublishedEvent>((event) {
      // debugPrint('[LiveKit] Track published: ${event.publication.kind}');
    });
    
    // Track subscribed (receiving agent audio)
    _listener!.on<TrackSubscribedEvent>((event) {
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
              level: (_agent!.audioLevel * _agentAudioLevelScaleFactor).clamp(0.0, 1.0));
        } else {
          // Agent has stopped talking completely - go back to idle state
          _orbController.updateFromLiveKit('silent',
              status: 'Ready to assist...');
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
        // Display audio level on single line that overwrites
        
        if (isSpeaking) {
          _orbController.updateFromLiveKit('talking',
              status: 'Agent speaking...',
              level: (_agent!.audioLevel * _agentAudioLevelScaleFactor).clamp(0.0, 1.0));
        } else {
          // Agent has stopped talking - go back to silent state
          _orbController.updateFromLiveKit('silent',
              status: 'Ready to assist...');
        }
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
        
      } catch (e) {
        // Silent error handling
      }
    }
  }
  
  /// Toggle microphone mute state
  Future<void> toggleMute() async {
    if (_room == null) {
      return;
    }
    
    if (_room!.localParticipant == null) {
      return;
    }
    
    _isMuted = !_isMuted;
    
    try {
      // Use setMicrophoneEnabled to properly handle track publishing with AGC
      await _room!.localParticipant?.setMicrophoneEnabled(!_isMuted,
        audioCaptureOptions: const AudioCaptureOptions(
          autoGainControl: true,
          echoCancellation: true,
          noiseSuppression: true,
        ));
      
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
      
    } catch (e) {
      // Revert mute state if operation failed
      _isMuted = !_isMuted;
    }
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