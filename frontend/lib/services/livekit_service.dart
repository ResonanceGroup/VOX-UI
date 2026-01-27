import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../controllers/livekit_orb_controller.dart';

/// Simplified LiveKit service for managing room connection and agent communication
class LiveKitService {
  static final LiveKitService _instance = LiveKitService._internal();
  factory LiveKitService(LiveKitOrbController orbController) => _instance;
  
  // Audio level scaling factors
  static const double _agentAudioLevelScaleFactor = 2.0;
  
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  final LiveKitOrbController _orbController;
  RemoteParticipant? _agent;
  bool _isMuted = false;
  bool _agentIsSpeaking = false;
  String? _agentVoxState;
  String? _agentVoxStatusText;
  
  LiveKitService._internal() : _orbController = LiveKitOrbController();
  
  /// Simple connect
  Future<void> connect(String url, String token) async {
    debugPrint('[LiveKit] 🔌 Connecting to: $url');
    
    try {
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      
      _setupEventListeners();
      _orbController.updateFromLiveKit('connecting', status: 'Connecting...');
      
      await _room!.connect(url, token);
      debugPrint('[LiveKit] ✅ Connected to room');
      
      // Enable microphone with AGC, echo cancellation, and noise suppression
      await _room!.localParticipant?.setMicrophoneEnabled(true,
        audioCaptureOptions: const AudioCaptureOptions(
          autoGainControl: true,
          echoCancellation: true,
          noiseSuppression: true,
        ));
      
      debugPrint('[LiveKit] ✅ Microphone enabled with AGC');
      _checkForAgent();
      _updateOrbState();
          
    } catch (e) {
      debugPrint('[LiveKit] ❌ Error: $e');
      _orbController.updateFromLiveKit('disconnected', status: 'Connection failed');
    }
  }
  
  /// Simple disconnect
  Future<void> disconnect() async {
    if (_room == null) return;
    
    try {
      await _room!.disconnect();
      await _room!.dispose();
      _room = null;
      _listener?.dispose();
      _listener = null;
      _agent = null;
      _orbController.updateFromLiveKit('disconnected');
      debugPrint('[LiveKit] Disconnected');
    } catch (e) {
      _room = null;
      _listener = null;
      _agent = null;
    }
  }
  


  void _updateOrbState({double? agentLevelOverride}) {
    if (_room == null) return;

    if (_room!.connectionState != ConnectionState.connected) {
      _orbController.updateFromLiveKit('disconnected');
      return;
    }

    if (_isMuted) {
      _orbController.updateFromLiveKit('muted', status: 'Microphone muted');
      return;
    }

    if (_agent == null) {
      _orbController.updateFromLiveKit('connected_no_agent', status: 'No agent');
      return;
    }

    if (_agentIsSpeaking) {
      final level = agentLevelOverride ??
          (_agent!.audioLevel * _agentAudioLevelScaleFactor).clamp(0.0, 1.0);
      _orbController.updateFromLiveKit(
        'talking',
        status: _agentVoxStatusText ?? 'Agent speaking...',
        level: level,
      );
      return;
    }

    if (_agentVoxState != null || _agentVoxStatusText != null) {
      _orbController.updateFromLiveKit(
        _agentVoxState ?? 'silent',
        status: _agentVoxStatusText,
      );
      return;
    }

    _orbController.updateFromLiveKit('connected_with_agent', status: 'Ready');
  }

  void _applyAgentVox({String? metadata, Map<String, String>? attributes}) {
    String? state = attributes?['vox.state'];
    String? statusText = attributes?['vox.statusText'];

    state = state?.trim();
    if (state != null && state.isEmpty) state = null;
    statusText = statusText?.trim();
    if (statusText != null && statusText.isEmpty) statusText = null;

    if ((state == null || statusText == null) && metadata != null && metadata.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map && decoded['vox'] is Map) {
          final vox = decoded['vox'] as Map;
          state ??= vox['state'] is String ? vox['state'] as String : null;
          statusText ??= vox['statusText'] is String ? vox['statusText'] as String : null;
        }
      } catch (_) {
        // Ignore non-JSON metadata
      }
    }

    state = state?.trim();
    if (state != null && state.isEmpty) state = null;
    statusText = statusText?.trim();
    if (statusText != null && statusText.isEmpty) statusText = null;

    final didChange = state != _agentVoxState || statusText != _agentVoxStatusText;
    _agentVoxState = state;
    _agentVoxStatusText = statusText;

    if (didChange) {
      _updateOrbState();
    }
  }

  /// Event listeners
  void _setupEventListeners() {
    if (_room == null) return;
    
    _listener = _room!.createListener();
    
    _listener!.on<RoomDisconnectedEvent>((event) {
      debugPrint('[LiveKit] Room disconnected');
      _orbController.updateFromLiveKit('disconnected');
    });
    
    _listener!.on<ParticipantConnectedEvent>((event) {
      _checkForAgent();
    });
    
    _listener!.on<ParticipantDisconnectedEvent>((event) {
      if (event.participant == _agent) {
        _agent = null;
        _orbController.updateFromLiveKit('connected_no_agent');
      }
    });
    
    _listener!.on<TrackSubscribedEvent>((event) {
      if (event.track.kind == TrackType.AUDIO) {
        _setupAudioTracking(event.track as AudioTrack);
      }
    });
    


    _listener!.on<ParticipantMetadataUpdatedEvent>((event) {
      if (_agent != null && event.participant.identity == _agent!.identity) {
        _applyAgentVox(metadata: event.metadata, attributes: event.participant.attributes);
      }
    });

    _listener!.on<ParticipantAttributesUpdatedEvent>((event) {
      if (_agent != null && event.participant.identity == _agent!.identity) {
        _applyAgentVox(metadata: event.participant.metadata, attributes: event.attributes);
      }
    });
    _listener!.on<TrackMutedEvent>((event) {
      if (_agent != null && !_isMuted) {
        _agentIsSpeaking = false;
        _updateOrbState();
      }
    });
    
    _listener!.on<ActiveSpeakersChangedEvent>((event) {
      if (_agent != null && !_isMuted) {
        _agentIsSpeaking = event.speakers.contains(_agent);
        _updateOrbState(
          agentLevelOverride: (_agent!.audioLevel * _agentAudioLevelScaleFactor).clamp(0.0, 1.0),
        );
      }
    });
  }
  
  /// Check for agent
  void _checkForAgent() {
    if (_room == null) return;
    
    final participants = _room!.remoteParticipants.values.toList();
    if (participants.isNotEmpty) {
      _agent = participants.firstWhere(
        (p) {
          final id = p.identity.toLowerCase();
          final name = p.name.toLowerCase();
          return id.contains('agent') || name.contains('agent');
        },
        orElse: () => participants.first,
      );
      debugPrint('[LiveKit] Agent connected: ${_agent!.identity}');
      _applyAgentVox(metadata: _agent!.metadata, attributes: _agent!.attributes);

      if (_isMuted) {
        _orbController.updateFromLiveKit('muted', status: 'Microphone muted');
      } else {
        _updateOrbState();
      }
    } else {
      _agent = null;
      _agentIsSpeaking = false;
      _agentVoxState = null;
      _agentVoxStatusText = null;
      _orbController.updateFromLiveKit('connected_no_agent', status: 'No agent');
    }
  }
  
  /// Track audio activity
  void _setupAudioTracking(AudioTrack track) {
    track.addListener(() {
      if (_agent != null && !_isMuted) {
        _agentIsSpeaking = _agent!.isSpeaking;
        _updateOrbState(
          agentLevelOverride: (_agent!.audioLevel * _agentAudioLevelScaleFactor).clamp(0.0, 1.0),
        );
      }
    });
  }
    });
  }
  
  /// Send message
  Future<void> sendMessage(String text) async {
    if (_room?.localParticipant != null) {
      try {
        final data = Uint8List.fromList(text.codeUnits);
        await _room!.localParticipant?.publishData(data, reliable: true);
      } catch (e) {
        // Silent error
      }
    }
  }
  
  /// Toggle mute
  Future<void> toggleMute() async {
    if (_room?.localParticipant == null) return;
    
    _isMuted = !_isMuted;
    debugPrint('[LiveKit] Microphone ${_isMuted ? "muted" : "unmuted"}');
    
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(!_isMuted,
        audioCaptureOptions: const AudioCaptureOptions(
          autoGainControl: true,
          echoCancellation: true,
          noiseSuppression: true,
        ));
      
      if (_isMuted) {
        _orbController.updateFromLiveKit('muted', status: 'Microphone muted');
      } else if (_agent != null) {
        _orbController.updateFromLiveKit('connected_with_agent', status: 'Ready');
      } else {
        _orbController.updateFromLiveKit('connected_no_agent', status: 'No agent');
      }
    } catch (e) {
      _isMuted = !_isMuted;
      debugPrint('[LiveKit] ❌ Toggle mute failed: $e');
    }
  }
  
  bool get isMuted => _isMuted;
  bool get isConnected => _room?.connectionState == ConnectionState.connected;
  bool get hasAgent => _agent != null;
  
  Future<void> dispose() async {
    await disconnect();
  }
}