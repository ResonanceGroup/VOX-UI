import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:audio_streamer/audio_streamer.dart';
import '../constants.dart';

/// Service for managing LiveKit AI voice agent connections
/// This is separate from JSON-RPC communication and only used for AI features
class LiveKitService {
  // Singleton pattern
  static final LiveKitService _instance = LiveKitService._internal();

  /// Fetch a LiveKit access token from the Jetson token service.
  /// Returns a map with 'token' and 'url' keys.
  /// Throws an exception if the request fails.
  Future<Map<String, String>> fetchToken({
    String identity = 'dashboard-tablet',
  }) async {
    final uri = Uri.parse(
      '${AppConstants.aiTokenServiceUrl}/token?identity=$identity',
    );

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ LiveKitService: Fetching token from $uri');
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception(
          'Token service returned ${response.statusCode}',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('✅ LiveKitService: Token received for ${json['identity']} in room ${json['room']}');
      }

      return {
        'token': json['token'] as String,
        'url': json['url'] as String,
      };
    } finally {
      client.close();
    }
  }

  factory LiveKitService() => _instance;
  LiveKitService._internal();

  // LiveKit room and connection state
  Room? _room;
  LocalAudioTrack? _localAudioTrack;
  RemoteAudioTrack? _remoteAudioTrack;

  // Connection state streams
  final StreamController<AIConnectionState> _connectionStateController =
      StreamController<AIConnectionState>.broadcast();
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();
  final StreamController<String> _streamingResponseController =
      StreamController<String>.broadcast();
  final StreamController<AIAgentState> _agentStateController =
      StreamController<AIAgentState>.broadcast();
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();

  Stream<AIConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<String> get transcript => _transcriptController.stream;
  Stream<String> get response => _responseController.stream;
  Stream<String> get streamingResponse => _streamingResponseController.stream;
  Stream<AIAgentState> get agentState => _agentStateController.stream;
  Stream<double> get audioLevel => _audioLevelController.stream;

  AIConnectionState _currentConnectionState = AIConnectionState.disconnected;
  AIAgentState _currentAgentState = AIAgentState.idle;

  AIConnectionState get currentConnectionState => _currentConnectionState;
  AIAgentState get currentAgentState => _currentAgentState;

  bool _isInitialized = false;
  bool _isMuted = false;
  int _reconnectAttempts = 0;
  
  // Audio monitoring
  AudioStreamer? _audioStreamer;
  StreamSubscription<List<double>>? _audioStreamSubscription;
  Timer? _audioLevelTimer;
  Timer? _disconnectDebounceTimer;

  // Remote audio level polling (VU meter for orb)
  Timer? _remoteAudioLevelTimer;
  List<Participant> _activeSpeakers = [];

  /// Initialize LiveKit service
  Future<void> initialize() async {
    if (_isInitialized) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('🎙️ LiveKitService: Already initialized');
      }
      return;
    }

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ LiveKitService: Initializing...');
    }

    try {
      _room = Room();
      _isInitialized = true;
      _updateConnectionState(AIConnectionState.disconnected);
      _updateAgentState(AIAgentState.idle);

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('✅ LiveKitService: Initialized successfully');
      }
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('❌ LiveKitService: Initialization failed: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }

  /// Connect to LiveKit room
  Future<bool> connect({required String url, required String token}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_currentConnectionState == AIConnectionState.connected) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('🎙️ LiveKitService: Already connected');
      }
      return true;
    }

    if (_currentConnectionState == AIConnectionState.connecting) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('🎙️ LiveKitService: Already connecting');
      }
      return true;
    }

    try {
      _updateConnectionState(AIConnectionState.connecting);

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('🎙️ LiveKitService: Connecting to $url...');
      }

      // Connect to room
      await _room!.connect(
        url,
        token,
        roomOptions: const RoomOptions(
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
          defaultAudioPublishOptions: AudioPublishOptions(),
          adaptiveStream: true,
        ),
      );

      // Set up event listeners
      _setupEventListeners();

      // Create and publish local audio track
      await _createLocalAudioTrack();

      _reconnectAttempts = 0;
      _updateConnectionState(AIConnectionState.connected);

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('✅ LiveKitService: Connected successfully');
      }

      return true;
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('❌ LiveKitService: Connection failed: $e');
      }
      _updateConnectionState(AIConnectionState.error);
      
      // Attempt reconnection
      if (_reconnectAttempts < AppConstants.aiMaxReconnectAttempts) {
        _reconnectAttempts++;
        if (AppConstants.aiEnableDebugLogs) {
          debugPrint(
            '🔄 LiveKitService: Reconnect attempt $_reconnectAttempts/${AppConstants.aiMaxReconnectAttempts}',
          );
        }
        await Future.delayed(AppConstants.aiReconnectDelay);
        return connect(url: url, token: token);
      }

      return false;
    }
  }

  /// Create local audio track for microphone input
  Future<void> _createLocalAudioTrack() async {
    try {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('🎙️ LiveKitService: Creating local audio track...');
      }

      _localAudioTrack = await LocalAudioTrack.create(
        const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('✅ LiveKitService: Local audio track created successfully');
        debugPrint('🎙️ LiveKitService: Track muted state: ${_localAudioTrack!.muted}');
      }

      await _room!.localParticipant?.publishAudioTrack(_localAudioTrack!);

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('✅ LiveKitService: Local audio track published to room');
      }

      // Start monitoring audio levels
      _startAudioLevelMonitoring();

    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('❌ LiveKitService: Failed to create local audio track: $e');
      }
      rethrow;
    }
  }

  /// Start monitoring audio levels from microphone
  Future<void> _startAudioLevelMonitoring() async {
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ LiveKitService: Starting audio level monitoring...');
      debugPrint('🎙️ LiveKitService: Local track exists: ${_localAudioTrack != null}');
      if (_localAudioTrack != null) {
        debugPrint('🎙️ LiveKitService: Local track muted: ${_localAudioTrack!.muted}');
      }
    }

    try {
      // Initialize audio streamer with error handling
      try {
        _audioStreamer = AudioStreamer();
      } catch (e) {
        if (AppConstants.aiEnableDebugLogs) {
          debugPrint('❌ LiveKitService: Failed to initialize AudioStreamer: $e');
        }
        // Rethrow to be caught by outer try-catch
        rethrow;
      }
      
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('✅ LiveKitService: AudioStreamer initialized');
      }

      // Listen to audio stream with error handling
      _audioStreamSubscription = _audioStreamer!.audioStream.listen(
        (samples) {
          // Check if controller is closed before adding events
          if (_audioLevelController.isClosed) {
            return;
          }
          
          // If muted, always emit 0
          if (_isMuted) {
            _audioLevelController.add(0.0);
            return;
          }
          
          if (samples.isEmpty) {
            _audioLevelController.add(0.0);
            return;
          }
          
          // Calculate RMS (Root Mean Square) audio level
          double sum = 0;
          for (final sample in samples) {
            sum += sample * sample;
          }
          
          final rms = sum > 0 ? (sum / samples.length).abs() : 0.0;
          final normalizedLevel = rms.clamp(0.0, 1.0);
          
          // Emit audio level
          _audioLevelController.add(normalizedLevel);
          
          // Log when audio is detected
          if (AppConstants.aiEnableDebugLogs && normalizedLevel > 0.01) {
            debugPrint('🎤 LiveKitService: Audio detected - Level: ${(normalizedLevel * 100).toStringAsFixed(1)}%');
          }
        },
        onError: (error) {
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('❌ LiveKitService: Audio stream error: $error');
          }
          // Don't let stream errors crash the app
          if (!_audioLevelController.isClosed) {
            _audioLevelController.add(0.0);
          }
        },
      );

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('✅ LiveKitService: Audio monitoring active - speak to test!');
      }

    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('❌ LiveKitService: Failed to start audio monitoring: $e');
      }
      // Fallback to baseline
      _audioLevelController.add(0.0);
    }
  }

  /// Set up event listeners for LiveKit room events
  void _setupEventListeners() {
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ LiveKitService: Setting up event listeners...');
    }

    // Listen to connection state changes (only log on actual transitions)
    ConnectionState? _lastRoomState;
    _room!.addListener(() {
      final state = _room!.connectionState;
      if (state == _lastRoomState) return; // skip duplicate fires
      _lastRoomState = state;

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('🎙️ LiveKitService: Room state changed to: $state');
      }

      switch (state) {
        case ConnectionState.connected:
          // Cancel any pending disconnect — this was just an ICE restart
          _disconnectDebounceTimer?.cancel();
          _disconnectDebounceTimer = null;
          _updateConnectionState(AIConnectionState.connected);
          break;
        case ConnectionState.connecting:
        case ConnectionState.reconnecting:
          _disconnectDebounceTimer?.cancel();
          _disconnectDebounceTimer = null;
          _updateConnectionState(AIConnectionState.connecting);
          break;
        case ConnectionState.disconnected:
          // Debounce: ICE restarts fire disconnected briefly before reconnecting.
          // Wait 1.5s — if connected fires first, this gets cancelled above.
          _disconnectDebounceTimer?.cancel();
          _disconnectDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
            _updateConnectionState(AIConnectionState.disconnected);
          });
          break;
      }
    });

    // Set up event listener for data and track events
    final listener = _room!.createListener();
    
    listener
      ..on<DataReceivedEvent>((event) {
        try {
          final decoded = utf8.decode(event.data);
          final json = jsonDecode(decoded) as Map<String, dynamic>;

          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('📨 LiveKitService: Received data: ${json['type']}');
          }

          _handleDataMessage(json);
        } catch (e) {
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('❌ LiveKitService: Failed to parse data: $e');
          }
        }
      })
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is RemoteAudioTrack) {
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('🔊 LiveKitService: Remote audio track subscribed');
          }
          _remoteAudioTrack = event.track as RemoteAudioTrack;
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.track == _remoteAudioTrack) {
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('🔇 LiveKitService: Remote audio track unsubscribed');
          }
          _remoteAudioTrack = null;
        }
      })
      ..on<TranscriptionEvent>((event) {
        // Standard LiveKit transcription — covers both STT (user speech)
        // and agent responses (published by TranscriptSynchronizer on backend)
        for (final segment in event.segments) {
          final text = segment.text.trim();
          if (text.isEmpty) continue;
          final isAgent = event.participant?.identity != _room!.localParticipant?.identity;
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('📝 LiveKitService: Transcription [${isAgent ? "agent" : "user"}]: $text');
          }
          if (isAgent) {
            if (segment.isFinal) {
              // Final: commit to history and clear the streaming preview
              _streamingResponseController.add('');
              _responseController.add(text);
            } else {
              // Non-final: update the live streaming preview
              _streamingResponseController.add(text);
            }
          } else {
            if (!segment.isFinal) continue;
            _transcriptController.add(text);
          }
        }
      })
      ..on<ParticipantAttributesChanged>((event) {
        // LiveKit agents publish state via participant attribute "lk.agent.state"
        // Valid states: initializing, idle, listening, thinking, speaking
        final agentState = event.attributes['lk.agent.state'];
        if (agentState != null) {
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('🤖 LiveKitService: Agent state attribute changed → $agentState');
          }
          final state = _parseAgentState(agentState);
          _updateAgentState(state);
        }
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        // Start/stop audio level polling based on who's speaking
        _updateActiveSpeakers(event.speakers);
      });
  }

  /// Handle data messages from the agent
  void _handleDataMessage(Map<String, dynamic> json) {
    final type = json['type'] as String?;

    switch (type) {
      case 'transcript':
        final text = json['text'] as String?;
        if (text != null) {
          _transcriptController.add(text);
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('📝 LiveKitService: Transcript: $text');
          }
        }
        break;

      case 'response':
        final text = json['text'] as String?;
        if (text != null) {
          _responseController.add(text);
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('💬 LiveKitService: Response: $text');
          }
        }
        break;

      case 'state':
        final stateName = json['state'] as String?;
        if (stateName != null) {
          final state = _parseAgentState(stateName);
          _updateAgentState(state);
        }
        break;

      default:
        if (AppConstants.aiEnableDebugLogs) {
          debugPrint('❓ LiveKitService: Unknown message type: $type');
        }
    }
  }

  /// Parse agent state from string
  /// Backend sends: initializing, idle, listening, thinking, speaking
  AIAgentState _parseAgentState(String state) {
    switch (state.toLowerCase()) {
      case 'idle':
        return AIAgentState.idle;
      case 'listening':
        return AIAgentState.listening;
      case 'thinking':
      case 'processing':
        return AIAgentState.processing;
      case 'speaking':
        return AIAgentState.speaking;
      case 'initializing':
        return AIAgentState.idle;
      case 'error':
        return AIAgentState.error;
      default:
        return AIAgentState.idle;
    }
  }

  /// Send a text message to the agent
  Future<void> sendTextMessage(String message) async {
    if (_currentConnectionState != AIConnectionState.connected) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('⚠️ LiveKitService: Not connected, cannot send message');
      }
      return;
    }

    try {
      // topic must be 'lk.chat' — the backend registers its text stream
      // handler on that topic; default empty topic "" never matches.
      await _room!.localParticipant?.sendText(
        message,
        options: SendTextOptions(topic: 'lk.chat'),
      );

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('📤 LiveKitService: Sent text message: $message');
      }
    } catch (e) {  
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('❌ LiveKitService: Failed to send message: $e');
      }
    }
  }

  /// Toggle microphone mute
  Future<void> toggleMute() async {
    // Toggle the internal state first
    _isMuted = !_isMuted;
    
    // Apply to LiveKit track if available
    if (_localAudioTrack != null) {
      try {
        if (_isMuted) {
          await _localAudioTrack!.mute();
        } else {
          await _localAudioTrack!.unmute();
        }
      } catch (e) {
        if (AppConstants.aiEnableDebugLogs) {
          debugPrint('⚠️ LiveKitService: Error toggling track mute: $e');
        }
      }
    }

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ LiveKitService: Microphone ${_isMuted ? "muted" : "unmuted"}');
    }
  }

  /// Get muted state
  bool get isMuted => _isMuted;

  /// Start audio monitoring (can be used independently of LiveKit connection)
  Future<void> startAudioMonitoring() async {
    if (_audioStreamer != null) {
      // Already monitoring
      return;
    }
    await _startAudioLevelMonitoring();
  }

  /// Stop audio monitoring
  Future<void> stopAudioMonitoring() async {
    await _stopAudioMonitoringInternal();
  }

  /// Disconnect from LiveKit room
  Future<void> disconnect() async {
    if (_currentConnectionState == AIConnectionState.disconnected) {
      return;
    }

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ LiveKitService: Disconnecting...');
    }

    try {
      // Stop audio monitoring first
      await _stopAudioMonitoringInternal();
      
      // Stop and dispose local audio track
      if (_localAudioTrack != null) {
        try {
          await _localAudioTrack!.stop();
          await _localAudioTrack!.dispose();
        } catch (e) {
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('⚠️ LiveKitService: Error stopping local track: $e');
          }
        }
        _localAudioTrack = null;
      }
      
      _remoteAudioTrack = null;

      // Disconnect from room
      if (_room != null) {
        try {
          await _room!.disconnect();
          await _room!.dispose();
        } catch (e) {
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('⚠️ LiveKitService: Error disconnecting room: $e');
          }
        }
        _room = null;
        _isInitialized = false;
        _reconnectAttempts = 0;
      }

      _disconnectDebounceTimer?.cancel();
      _disconnectDebounceTimer = null;
      
      _updateConnectionState(AIConnectionState.disconnected);
      _updateAgentState(AIAgentState.idle);

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('✅ LiveKitService: Disconnected successfully');
      }
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('❌ LiveKitService: Disconnect error: $e');
      }
    }
  }

  /// Internal method to stop audio monitoring
  Future<void> _stopAudioMonitoringInternal() async {
    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      
      _audioLevelTimer?.cancel();
      _audioLevelTimer = null;
      
      _audioStreamer = null;
      
      // Emit zero level after stopping
      if (!_audioLevelController.isClosed) {
        _audioLevelController.add(0.0);
      }
      
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('🎙️ LiveKitService: Audio monitoring stopped');
      }
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('⚠️ LiveKitService: Error stopping audio monitoring: $e');
      }
    }
  }

  /// Handle active speakers change — start/stop audio level polling
  void _updateActiveSpeakers(List<Participant> speakers) {
    _activeSpeakers = speakers;

    if (speakers.isNotEmpty && _remoteAudioLevelTimer == null) {
      // Poll audio levels at ~30fps for smooth orb VU animation
      _remoteAudioLevelTimer = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) {
          double maxLevel = 0.0;
          for (final p in _activeSpeakers) {
            if (p.audioLevel > maxLevel) {
              maxLevel = p.audioLevel;
            }
          }
          if (!_audioLevelController.isClosed) {
            _audioLevelController.add(maxLevel);
          }
        },
      );
    } else if (speakers.isEmpty && _remoteAudioLevelTimer != null) {
      _remoteAudioLevelTimer?.cancel();
      _remoteAudioLevelTimer = null;
      if (!_audioLevelController.isClosed) {
        _audioLevelController.add(0.0);
      }
    }
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(AIConnectionState state) {
    if (_currentConnectionState != state) {
      _currentConnectionState = state;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(state);
      }
    }
  }

  /// Update agent state and notify listeners
  void _updateAgentState(AIAgentState state) {
    if (_currentAgentState != state) {
      _currentAgentState = state;
      if (!_agentStateController.isClosed) {
        _agentStateController.add(state);
      }
    }
  }

  /// Dispose resources
  void dispose() {
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ LiveKitService: Disposing...');
    }

    // Stop audio monitoring FIRST to cancel active subscriptions
    // This must be done synchronously to prevent race conditions
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
    _remoteAudioLevelTimer?.cancel();
    _remoteAudioLevelTimer = null;
    _audioStreamer = null;
    
    // Update states before closing controllers
    _currentConnectionState = AIConnectionState.disconnected;
    _currentAgentState = AIAgentState.idle;
    
    // Close all stream controllers
    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
    if (!_transcriptController.isClosed) {
      _transcriptController.close();
    }
    if (!_responseController.isClosed) {
      _responseController.close();
    }
    if (!_streamingResponseController.isClosed) {
      _streamingResponseController.close();
    }
    if (!_agentStateController.isClosed) {
      _agentStateController.close();
    }
    if (!_audioLevelController.isClosed) {
      _audioLevelController.close();
    }
    
    // Dispose tracks and room synchronously
    _localAudioTrack?.stop();
    _localAudioTrack?.dispose();
    _localAudioTrack = null;
    _remoteAudioTrack = null;
    
    _room?.disconnect();
    _room?.dispose();
    _room = null;
    
    _isInitialized = false;
    
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('✅ LiveKitService: Disposed successfully');
    }
  }
}

/// AI connection states
enum AIConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// AI agent states (matches the backend states)
enum AIAgentState {
  idle,
  listening,
  processing,
  speaking,
  error,
}
