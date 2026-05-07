import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:audio_streamer/audio_streamer.dart';
import '../constants.dart';

/// Service for managing LiveKit AI voice agent connections
class LiveKitService {
  // Singleton pattern
  static final LiveKitService _instance = LiveKitService._internal();

  factory LiveKitService() => _instance;
  LiveKitService._internal();

  /// Fetch a LiveKit access token from the token service.
  /// [tokenServiceUrl] overrides the default URL from AppConstants.
  /// Returns a map with 'token' and 'url' keys.
  Future<Map<String, dynamic>> fetchToken({
    String identity = 'dashboard-tablet',
    String? tokenServiceUrl,
  }) async {
    final baseUrl = tokenServiceUrl ?? AppConstants.aiTokenServiceUrl;
    final uri = Uri.parse('$baseUrl/token?identity=$identity');

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('LiveKitService: Fetching token from $uri');
    }

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Token service returned ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Token received for ${json['identity']} in room ${json['room']}');
      }

      // Extract ICE servers if provided by token service (Cloudflare TURN)
      final List<RTCIceServer> iceServers = [];
      final rawIce = json['iceServers'] as List<dynamic>?;
      if (rawIce != null) {
        for (final e in rawIce) {
          final m = e as Map<String, dynamic>;
          final urls = (m['urls'] as List<dynamic>?)?.cast<String>() ?? [];
          if (urls.isNotEmpty) {
            iceServers.add(RTCIceServer(
              urls: urls,
              username:   m['username']   as String?,
              credential: m['credential'] as String?,
            ));
          }
        }
        if (AppConstants.aiEnableDebugLogs) {
          debugPrint('LiveKitService: Got ${iceServers.length} ICE server(s) from token service');
        }
      }

      return {
        'token': json['token'] as String,
        'url': json['url'] as String,
        'iceServers': iceServers,
      };
    } catch (e) {
      rethrow;
    }
  }

  // LiveKit room and connection state
  Room? _room;
  LocalAudioTrack? _localAudioTrack;
  RemoteAudioTrack? _remoteAudioTrack;
  bool _isSpeakerMuted = false;


  // Connection state streams
  final StreamController<AIConnectionState> _connectionStateController =
      StreamController<AIConnectionState>.broadcast();
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  // Partial (non-final) user STT updates — for status display only, not history.
  final StreamController<String> _userPartialTranscriptController =
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
  Stream<String> get userPartialTranscript => _userPartialTranscriptController.stream;
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
  bool _isConnecting = false;
  int _reconnectAttempts = 0;

  // Audio monitoring
  AudioStreamer? _audioStreamer;
  StreamSubscription<List<double>>? _audioStreamSubscription;
  Timer? _audioLevelTimer;
  Timer? _disconnectDebounceTimer;

  // Remote audio level polling
  Timer? _remoteAudioLevelTimer;
  // Debounce: hold speaking state for a short window after audio drops.
  // Prevents orb flicker during natural inter-sentence pauses in TTS.
  Timer? _speakingIdleDebounceTimer;
  // Tracks the most recent backend-declared state that was blocked by the
  // speaking guard. When the debounce fires we apply this instead of hardcoded
  // idle so the orb lands in the correct state (e.g. listening after TTS done,
  // or processing if the next sentence is already being generated).
  AIAgentState? _pendingBackendState;

  List<Participant> _activeSpeakers = [];
  EventsListener<RoomEvent>? _eventListener;

  /// Initialize LiveKit service
  Future<void> initialize() async {
    if (_isInitialized) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Already initialized');
      }
      return;
    }

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('LiveKitService: Initializing...');
    }

    try {
      _room = Room();
      _isInitialized = true;
      _setupEventListeners();
      _updateConnectionState(AIConnectionState.disconnected);
      _updateAgentState(AIAgentState.idle);

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Initialized successfully');
      }
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Initialization failed: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }

  /// Connect to LiveKit room
  Future<bool> connect({required String url, required String token, List<RTCIceServer>? iceServers, Function(String)? onError}) async {
    if (!_isInitialized) await initialize();

    if (_currentConnectionState == AIConnectionState.connected ||
        _currentConnectionState == AIConnectionState.connecting ||
        _isConnecting) {
      return true;
    }

    _isConnecting = true;
    try {
      _updateConnectionState(AIConnectionState.connecting);

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Connecting to $url...');
      }

      final connectOpts = (iceServers != null && iceServers.isNotEmpty)
          ? ConnectOptions(
              rtcConfiguration: RTCConfiguration(iceServers: iceServers),
            )
          : null;

      await _room!.connect(
        url,
        token,
        connectOptions: connectOpts,
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

      try {
        await _createLocalAudioTrack();
      } catch (audioErr) {
        debugPrint('LiveKitService: Audio track failed: $audioErr');
        onError?.call('Mic error: $audioErr');
      }

      _reconnectAttempts = 0;
      _isConnecting = false;
      _updateConnectionState(AIConnectionState.connected);
      _startVuMeterTimer(); // Begin continuous 60fps VU polling (local + remote)

      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Connected successfully');
      }

      return true;
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Connection failed: $e');
      }
      _updateConnectionState(AIConnectionState.error);

      if (_reconnectAttempts < AppConstants.aiMaxReconnectAttempts) {
        _reconnectAttempts++;
        _isConnecting = false;  // allow recursive retry call to enter
        if (AppConstants.aiEnableDebugLogs) {
          debugPrint('LiveKitService: Reconnect attempt $_reconnectAttempts/${AppConstants.aiMaxReconnectAttempts}');
        }
        await Future.delayed(AppConstants.aiReconnectDelay);
        return connect(url: url, token: token, iceServers: iceServers, onError: onError);
      }

      // All retries exhausted — reset counter and transition to disconnected
      // so ai_controller's reconnect timer can trigger a fresh attempt.
      _reconnectAttempts = 0;
      _isConnecting = false;
      _updateConnectionState(AIConnectionState.disconnected);
      return false;
    }
  }

  Future<void> _createLocalAudioTrack() async {
    try {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Creating local audio track...');
      }

      _localAudioTrack = await LocalAudioTrack.create(
        const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );

      await _room!.localParticipant?.publishAudioTrack(_localAudioTrack!);
      _startAudioLevelMonitoring();
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Failed to create local audio track: $e');
      }
      rethrow;
    }
  }

  Future<void> _startAudioLevelMonitoring() async {
    // audio_streamer has no web implementation — skip it on web.
    // On web, audio levels come from the LiveKit remote speaker timer
    // (_remoteAudioLevelTimer) which fires whenever active speakers change.
    if (kIsWeb) {
      debugPrint('LiveKitService: Skipping audio_streamer on web (no web plugin)');
      return;
    }
    try {
      _audioStreamer = AudioStreamer();
      _audioStreamSubscription = _audioStreamer!.audioStream.listen(
        (samples) {
          if (_audioLevelController.isClosed) return;
          if (_isMuted) {
            _audioLevelController.add(0.0);
            return;
          }
          if (samples.isEmpty) {
            _audioLevelController.add(0.0);
            return;
          }
          double sum = 0;
          for (final sample in samples) {
            sum += sample * sample;
          }
          final rms = sum > 0 ? (sum / samples.length).abs() : 0.0;
          final normalizedLevel = rms.clamp(0.0, 1.0);
          _audioLevelController.add(normalizedLevel);
        },
        onError: (error) {
          if (!_audioLevelController.isClosed) _audioLevelController.add(0.0);
        },
      );
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Failed to start audio monitoring: $e');
      }
      _audioLevelController.add(0.0);
    }
  }

  void _setupEventListeners() {
    ConnectionState? _lastRoomState;
    _room!.addListener(() {
      if (_room == null) return;  // guard: room disposed between event and callback
      final state = _room!.connectionState;
      if (state == _lastRoomState) return;
      _lastRoomState = state;

      switch (state) {
        case ConnectionState.connected:
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
          _disconnectDebounceTimer?.cancel();
          _disconnectDebounceTimer = Timer(const Duration(milliseconds: 5000), () {
            _updateConnectionState(AIConnectionState.disconnected);
          });
          break;
      }
    });

    _eventListener?.dispose();
    _eventListener = _room!.createListener();
    final listener = _eventListener!;

    listener
      ..on<DataReceivedEvent>((event) {
        try {
          final decoded = utf8.decode(event.data);
          final json = jsonDecode(decoded) as Map<String, dynamic>;
          _handleDataMessage(json);
        } catch (e) {
          if (AppConstants.aiEnableDebugLogs) {
            debugPrint('LiveKitService: Failed to parse data: $e');
          }
        }
      })
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is RemoteAudioTrack) {
          _remoteAudioTrack = event.track as RemoteAudioTrack;
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.track == _remoteAudioTrack) {
          _remoteAudioTrack = null;
        }
      })
      ..on<TranscriptionEvent>((event) {
        for (final segment in event.segments) {
          final text = segment.text.trim();
          if (text.isEmpty) continue;
          final isAgent = event.participant?.identity != _room!.localParticipant?.identity;
          if (isAgent) {
            if (segment.isFinal) {
              _streamingResponseController.add('');  // clear streaming preview
              _responseController.add(text);         // TranscriptionEvent is sole source
            } else {
              // Always stream non-final segments as the LLM generates / TTS speaks.
              // TranscriptionEvent non-final segments are the standard LiveKit streaming
              // mechanism; they arrive word-by-word as text is produced.
              _streamingResponseController.add(text);
            }
          } else {
            if (segment.isFinal) {
              // Final user segment -> adds to conversation history + status
              _transcriptController.add(text);
            } else {
              // Partial user segment -> status display only (no history entry)
              _userPartialTranscriptController.add(text);
            }
          }
        }
      })
      ..on<ParticipantAttributesChanged>((event) {
        final agentState = event.attributes['lk.agent.state'];
        if (agentState != null) {
          if (AppConstants.aiEnableDebugLogs) debugPrint("[STATE] ATTR: " + agentState);
          final state = _parseAgentState(agentState);
          _updateAgentState(state, source: "attr");
        }
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        final _li = _room?.localParticipant?.identity;
        final _ha = event.speakers.any((p) => p.identity != _li);
        if (AppConstants.aiEnableDebugLogs) debugPrint("[STATE] SPKR: " + (_ha ? "audible" : "empty"));
        _updateActiveSpeakers(event.speakers);
      });
  }

  void _handleDataMessage(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'response':
        // The Python agent fires this via `on_conversation_item_added` when the
        // LLM finishes generating — BEFORE TTS finishes playing. This gives
        // "text appears during speech" behavior. We set a flag so the later
        // TranscriptionEvent final doesn't add the same text again.
        final respText = json['text'] as String?;
        if (respText != null && respText.isNotEmpty) {
          // 'response' data channel no longer sent by backend.
          // Kept here as a no-op stub in case old clients send it.
          _streamingResponseController.add('');
          _responseController.add(respText);
        }
        break;
      case 'user_transcript':
        // Backend publishes the user's STT text via data channel when
        // TranscriptionEvent for user speech is unreliable in older clients.
        final userText = json['text'] as String?;
        if (userText != null && userText.isNotEmpty) {
          _transcriptController.add(userText);
        }
        break;
      case 'state':
        final stateName = json['state'] as String?;
        if (stateName != null) { if (AppConstants.aiEnableDebugLogs) debugPrint("[STATE] DC: " + stateName); _updateAgentState(_parseAgentState(stateName), source: "dc"); }
        break;
    }
  }

  AIAgentState _parseAgentState(String state) {
    switch (state.toLowerCase()) {
      case 'idle': return AIAgentState.idle;
      case 'listening': return AIAgentState.listening;
      case 'thinking': case 'processing': return AIAgentState.processing;
      case 'speaking': return AIAgentState.speaking;
      case 'initializing': return AIAgentState.idle;
      case 'error': return AIAgentState.error;
      default: return AIAgentState.idle;
    }
  }

  Future<void> sendTextMessage(String message) async {
    if (_currentConnectionState != AIConnectionState.connected) return;
    try {
      // Canonical LiveKit Agents pattern — text streams on lk.chat topic.
      // The agent framework's on_conversation_item_added handler subscribes
      // to this topic. publishData() with custom JSON is silently ignored
      // by the standard agent framework. Matches RV2 frontend behavior.
      await _room!.localParticipant?.sendText(
        message,
        options: SendTextOptions(topic: 'lk.chat'),
      );
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Failed to send message: $e');
      }
    }
  }

  bool get isSpeakerMuted => _isSpeakerMuted;

  // Speaker mute: toggle flag, then mute/unmute remote audio tracks via
  // MediaStreamTrack.enabled (reliable on iOS Safari; DOM-level audio.muted
  // is not guaranteed for WebRTC streams). orb_widget_web_impl also applies
  // the DOM fallback via _applyAudioMuteState for any audio elements that
  // bypass the LiveKit track API.
  void toggleSpeakerMute() {
    _isSpeakerMuted = !_isSpeakerMuted;
    _applyRemoteAudioMuteState(_isSpeakerMuted);
  }

  void _applyRemoteAudioMuteState(bool muted) {
    _room?.remoteParticipants.forEach((_, participant) {
      for (final pub in participant.audioTrackPublications) {
        final track = pub.track;
        if (track != null) {
          if (muted) {
            track.disable();
          } else {
            track.enable();
          }
        }
      }
    });
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_localAudioTrack != null) {
      try {
        if (_isMuted) {
          await _localAudioTrack!.mute();
        } else {
          await _localAudioTrack!.unmute();
        }
      } catch (e) {
        if (AppConstants.aiEnableDebugLogs) {
          debugPrint('LiveKitService: Error toggling track mute: $e');
        }
      }
    }
  }

  bool get isMuted => _isMuted;

  Future<void> startAudioMonitoring() async {
    if (_audioStreamer != null) return;
    await _startAudioLevelMonitoring();
  }

  Future<void> stopAudioMonitoring() async {
    await _stopAudioMonitoringInternal();
  }

  Future<void> disconnect() async {
    if (_currentConnectionState == AIConnectionState.disconnected) return;

    try {
      await _stopAudioMonitoringInternal();

      if (_localAudioTrack != null) {
        try {
          await _localAudioTrack!.stop();
          await _localAudioTrack!.dispose();
        } catch (_) {}
        _localAudioTrack = null;
      }

      _remoteAudioTrack = null;

      if (_room != null) {
        _eventListener?.dispose();
        _eventListener = null;
        try {
          await _room!.disconnect();
          await _room!.dispose();
        } catch (_) {}
        _room = null;
        _isInitialized = false;
        _reconnectAttempts = 0;
      }

      _disconnectDebounceTimer?.cancel();
      _disconnectDebounceTimer = null;
      _speakingIdleDebounceTimer?.cancel();
      _speakingIdleDebounceTimer = null;
      _remoteAudioLevelTimer?.cancel();
      _remoteAudioLevelTimer = null;
      _activeSpeakers = [];

      _updateConnectionState(AIConnectionState.disconnected);
      _updateAgentState(AIAgentState.idle);
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Disconnect error: $e');
      }
    }
  }

  Future<void> _stopAudioMonitoringInternal() async {
    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      _audioLevelTimer?.cancel();
      _audioLevelTimer = null;
      _audioStreamer = null;
      if (!_audioLevelController.isClosed) _audioLevelController.add(0.0);
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('LiveKitService: Error stopping audio monitoring: $e');
      }
    }
  }

  /// Start (or restart) a continuous 60fps VU-meter timer that reads both the
  /// local participant's mic level and any remote active speakers. This gives
  /// the orb immediate, smooth response to the user's voice without waiting
  /// for LiveKit's speaker-detection event to fire.
  void _startVuMeterTimer() {
    _remoteAudioLevelTimer?.cancel();
    _remoteAudioLevelTimer = Timer.periodic(
      const Duration(milliseconds: 33), // ~30fps (LiveKit audioLevel updates ~100ms; 33ms is sufficient)
      (_) {
        if (_audioLevelController.isClosed) return;
        // Local mic level (user voice) — always non-zero while speaking
        double maxLevel = _room?.localParticipant?.audioLevel ?? 0.0;
        // Remote active speakers (agent audio)
        for (final p in _activeSpeakers) {
          if (p.audioLevel > maxLevel) maxLevel = p.audioLevel;
        }
        _audioLevelController.add(maxLevel);
      },
    );
  }

  void _updateActiveSpeakers(List<Participant> speakers) {
    _activeSpeakers = speakers;
    final localId = _room?.localParticipant?.identity;
    final agentSpeaking = speakers.any((p) => p.identity != localId);

    if (agentSpeaking) {
      // Audio is playing — cancel any pending idle transition and hold speaking.
      _speakingIdleDebounceTimer?.cancel();
      _speakingIdleDebounceTimer = null;
      _updateAgentState(AIAgentState.speaking, source: "audio");
    } else if (_currentAgentState == AIAgentState.speaking) {
      // Audio paused — wait before declaring idle.
      // Covers natural inter-sentence pauses without flickering.
      _speakingIdleDebounceTimer?.cancel();
      _pendingBackendState = null;
      if (AppConstants.aiEnableDebugLogs) debugPrint("[STATE] DBC: start");
      _speakingIdleDebounceTimer = Timer(const Duration(milliseconds: 1200), () {
        _speakingIdleDebounceTimer = null;
        if (AppConstants.aiEnableDebugLogs) debugPrint("[STATE] DBC: fire");
        if (_currentAgentState == AIAgentState.speaking) {
          // Use the most recent blocked backend state (e.g. listening/processing)
          // instead of a hardcoded idle.  This prevents the orb from getting
          // stuck at idle when the backend already declared listening.
          final nextState = _pendingBackendState ?? AIAgentState.listening;
          _pendingBackendState = null;
          if (AppConstants.aiEnableDebugLogs) debugPrint("[STATE] DBC: -> " + nextState.name);
          _updateAgentState(nextState, source: "debounce");
        }
      });
    }

    // VU meter runs continuously via _startVuMeterTimer() — no per-event start/stop.
  }

  void _updateConnectionState(AIConnectionState state) {
    if (_currentConnectionState != state) {
      _currentConnectionState = state;
      if (!_connectionStateController.isClosed) _connectionStateController.add(state);
    }
  }

  void _updateAgentState(AIAgentState state, {String source = "?"}) {
    // While audio is playing or debounce is running, don't let backend
    // attribute events override the audio-confirmed speaking state.
    if (_currentAgentState == AIAgentState.speaking &&
        state != AIAgentState.speaking &&
        state != AIAgentState.error) {
      final localId = _room?.localParticipant?.identity;
      final agentAudible = _activeSpeakers.any((p) => p.identity != localId);
      if (agentAudible || _speakingIdleDebounceTimer != null) {
        _pendingBackendState = state;  // remember last blocked state
        if (AppConstants.aiEnableDebugLogs) debugPrint("[STATE] BLOCK [" + source + "]: " + state.name + " aud=" + agentAudible.toString() + " dbc=" + (_speakingIdleDebounceTimer!=null).toString());
        return;
      }
    }
    if (_currentAgentState != state) {
      if (AppConstants.aiEnableDebugLogs) debugPrint("[STATE] EMIT [" + source + "]: " + _currentAgentState.name + " -> " + state.name);
      _currentAgentState = state;
      if (!_agentStateController.isClosed) _agentStateController.add(state);
    }
  }

  void dispose() {
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
    _remoteAudioLevelTimer?.cancel();
    _remoteAudioLevelTimer = null;
    _speakingIdleDebounceTimer?.cancel();
    _speakingIdleDebounceTimer = null;
    _audioStreamer = null;

    _currentConnectionState = AIConnectionState.disconnected;
    _currentAgentState = AIAgentState.idle;

    if (!_connectionStateController.isClosed) _connectionStateController.close();
    if (!_transcriptController.isClosed) _transcriptController.close();
    if (!_userPartialTranscriptController.isClosed) _userPartialTranscriptController.close();
    if (!_responseController.isClosed) _responseController.close();
    if (!_streamingResponseController.isClosed) _streamingResponseController.close();
    if (!_agentStateController.isClosed) _agentStateController.close();
    if (!_audioLevelController.isClosed) _audioLevelController.close();

    _localAudioTrack?.stop();
    _localAudioTrack?.dispose();
    _localAudioTrack = null;
    _remoteAudioTrack = null;

    _eventListener?.dispose();
    _eventListener = null;
    _room?.disconnect();
    _room?.dispose();
    _room = null;
    _isInitialized = false;
  }
}

/// AI connection states
enum AIConnectionState { disconnected, connecting, connected, error }

/// AI agent states
enum AIAgentState { idle, listening, processing, speaking, error }
