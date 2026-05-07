import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/services/livekit_service.dart';
import 'package:livekit_client/livekit_client.dart' show RTCIceServer;
import '../models/services/preferences_service.dart';
import '../models/constants.dart';

/// Controller for managing AI voice agent state and interactions
class AIController extends ChangeNotifier {
  final LiveKitService _livekitService;
  final PreferencesService? _preferencesService;

  // Subscriptions
  StreamSubscription<AIConnectionState>? _connectionStateSubscription;
  StreamSubscription<AIAgentState>? _agentStateSubscription;
  StreamSubscription<String>? _transcriptSubscription;
  StreamSubscription<String>? _partialTranscriptSubscription;
  StreamSubscription<String>? _responseSubscription;
  StreamSubscription<String>? _streamingResponseSubscription;
  StreamSubscription<double>? _audioLevelSubscription;
  Timer? _audioLevelLogTimer;
  Timer? _reconnectTimer;

  // State
  AIConnectionState _connectionState = AIConnectionState.disconnected;
  AIAgentState _agentState = AIAgentState.idle;
  String _currentTranscript = '';
  String _currentResponse = '';
  String? _streamingAgentMessage;
  List<ConversationMessage> _conversationHistory = [];
  bool _isRecording = false;
  String? _errorMessage;
  double _currentAudioLevel = 0.0;

  // Device info
  bool _isTablet = false;

  AIController({
    LiveKitService? livekitService,
    PreferencesService? preferencesService,
  })  : _livekitService = livekitService ?? LiveKitService(),
        _preferencesService = preferencesService {
    _initialize();
  }

  // Getters
  AIConnectionState get connectionState => _connectionState;
  AIAgentState get agentState => _agentState;
  LiveKitService get livekitService => _livekitService;
  String get currentTranscript => _currentTranscript;
  String get currentResponse => _currentResponse;
  String? get streamingAgentMessage => _streamingAgentMessage;
  List<ConversationMessage> get conversationHistory => _conversationHistory;
  bool get isRecording => _isRecording;
  String? get errorMessage => _errorMessage;
  bool get isMuted => _livekitService.isMuted;
  bool get isSpeakerMuted => _livekitService.isSpeakerMuted;
  double get currentAudioLevel => _currentAudioLevel;

  /// Check if AI is available
  bool get isAIAvailable {
    if (kDebugMode && AppConstants.isDemoMode) return true;
    return true;
  }

  /// Check if AI is enabled (connected and ready to use)
  bool get isAIEnabled {
    return isAIAvailable && _connectionState == AIConnectionState.connected;
  }

  /// Get status message for UI
  String get statusMessage {
    switch (_connectionState) {
      case AIConnectionState.disconnected:
        return 'AI Disconnected';
      case AIConnectionState.connecting:
        return 'Connecting to AI...';
      case AIConnectionState.connected:
        switch (_agentState) {
          case AIAgentState.idle:
            return 'AI Ready';
          case AIAgentState.listening:
            return 'Listening...';
          case AIAgentState.processing:
            return 'Thinking...';
          case AIAgentState.speaking:
            return 'Speaking...';
          case AIAgentState.error:
            return _errorMessage ?? 'AI Error';
        }
      case AIConnectionState.error:
        return _errorMessage ?? 'Connection Error';
    }
  }

  /// Get the token service URL from preferences or defaults
  String get _tokenServiceUrl {
    return _preferencesService?.tokenServiceUrl ?? AppConstants.aiTokenServiceUrl;
  }

  /// Initialize the controller
  void _initialize() {
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('AIController: Initializing...');
    }

    _connectionStateSubscription =
        _livekitService.connectionState.listen((state) {
      _connectionState = state;
      if (state == AIConnectionState.error) {
        _errorMessage = 'Failed to connect to AI service';
      } else {
        _errorMessage = null;
      }
      if (state == AIConnectionState.disconnected && isAIAvailable) {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 3), () {
          if (_connectionState == AIConnectionState.disconnected) {
            if (AppConstants.aiEnableDebugLogs) {
              debugPrint('AIController: Auto-reconnecting...');
            }
            connect();
          }
        });
      } else {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }
      notifyListeners();
    });

    _agentStateSubscription = _livekitService.agentState.listen((state) {
      _agentState = state;
      notifyListeners();
    });

    _partialTranscriptSubscription = _livekitService.userPartialTranscript.listen((text) {
      // Partial user STT -- show in status bar as user speaks, no history entry
      _currentTranscript = text;
      notifyListeners();
    });

    _transcriptSubscription = _livekitService.transcript.listen((text) {
      _currentTranscript = text;
      _addToHistory(ConversationMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    });

    _responseSubscription = _livekitService.response.listen((text) {
      _currentResponse = text;
      _streamingAgentMessage = null;
      _addToHistory(ConversationMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    });

    _streamingResponseSubscription = _livekitService.streamingResponse.listen((text) {
      _streamingAgentMessage = text.isEmpty ? null : text;
      notifyListeners();
    });

    _audioLevelSubscription = _livekitService.audioLevel.listen((level) {
      _currentAudioLevel = level;
      notifyListeners();
    });

    if (AppConstants.aiEnableDebugLogs) {
      _audioLevelLogTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_currentAudioLevel > 0.0) {
          debugPrint('AIController: Audio level: ${(_currentAudioLevel * 100).toStringAsFixed(1)}%');
        }
      });
    }

    if (kDebugMode && AppConstants.isDemoMode) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _startDebugAudioMonitoring();
      });
    }
  }

  Future<void> _startDebugAudioMonitoring() async {
    try {
      await _livekitService.startAudioMonitoring();
    } catch (e) {
      _errorMessage = 'Audio monitoring unavailable';
    }
  }

  void updateDeviceType(bool isTablet) {
    _isTablet = isTablet;
    notifyListeners();
  }

  void updateTcpConnectionStatus(bool isConnected) {
    notifyListeners();
  }

  /// Connect to AI service
  Future<bool> connect() async {
    if (kDebugMode && AppConstants.isDemoMode) {
      _connectionState = AIConnectionState.connected;
      _agentState = AIAgentState.idle;
      notifyListeners();
      return true;
    }

    if (!isAIAvailable) {
      _errorMessage = 'AI is not available';
      notifyListeners();
      return false;
    }

    try {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('AIController: Connecting to AI service...');
      }

      await _livekitService.initialize();

      final tokenData = await _livekitService.fetchToken(
        identity: AppConstants.aiParticipantIdentity,
        tokenServiceUrl: _tokenServiceUrl,
      );

      // Extract ICE servers from token response (Cloudflare TURN credentials)
      final iceServers = tokenData['iceServers'] as List<RTCIceServer>?;

      final success = await _livekitService.connect(
        url: tokenData['url']! as String,
        token: tokenData['token']! as String,
        iceServers: (iceServers != null && iceServers.isNotEmpty) ? iceServers : null,
        onError: (msg) {
          _errorMessage = msg;
          notifyListeners();
        },
      );

      if (success) {
        _errorMessage = null;
      } else {
        _errorMessage = 'Failed to connect to AI service';
      }

      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from AI service
  Future<void> disconnect() async {
    if (kDebugMode && AppConstants.isDemoMode) {
      _connectionState = AIConnectionState.disconnected;
      _agentState = AIAgentState.idle;
      notifyListeners();
      return;
    }

    await _livekitService.disconnect();
    _currentTranscript = '';
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _currentResponse = '';
    notifyListeners();
  }

  /// Send a text message to the AI
  Future<void> sendMessage(String message) async {
    if (!isAIEnabled) return;

    if (kDebugMode && AppConstants.isDemoMode) {
      _addToHistory(ConversationMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _agentState = AIAgentState.processing;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      final demoResponse = 'This is a demo response. In production, the AI would respond based on your input: "$message"';
      _addToHistory(ConversationMessage(
        text: demoResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _agentState = AIAgentState.idle;
      notifyListeners();
      return;
    }

    await _livekitService.sendTextMessage(message);
    _currentTranscript = message;
    _addToHistory(ConversationMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  void startRecording() {
    _isRecording = true;
    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    notifyListeners();
  }

  Future<void> toggleMute() async {
    await _livekitService.toggleMute();
    notifyListeners();
  }

  void toggleSpeakerMute() {
    _livekitService.toggleSpeakerMute();
    notifyListeners();
  }

  void clearHistory() {
    _conversationHistory.clear();
    _currentTranscript = '';
    _currentResponse = '';
    notifyListeners();
  }

  void _addToHistory(ConversationMessage message) {
    // Dedup: the LiveKit agent framework echoes user text input back as a
    // TranscriptionEvent (UserInputTranscribed → _forward_user_transcript →
    // capture_text), so text messages sent via sendMessage() would appear twice
    // — once from sendMessage()'s optimistic add and once from the transcript
    // subscription. If the incoming message has the same text, same sender, and
    // arrived within 3 seconds of the last entry, skip it.
    if (_conversationHistory.isNotEmpty) {
      final last = _conversationHistory.last;
      final gap = message.timestamp.difference(last.timestamp).abs();
      if (last.text == message.text &&
          last.isUser == message.isUser &&
          gap < const Duration(seconds: 3)) {
        return;
      }
    }
    _conversationHistory.add(message);
    if (_conversationHistory.length > 50) {
      _conversationHistory.removeAt(0);
    }
  }

  @override
  void dispose() {
    _audioLevelLogTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _audioLevelLogTimer = null;

    try {
      _livekitService.stopAudioMonitoring();
    } catch (_) {}

    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _agentStateSubscription?.cancel();
    _agentStateSubscription = null;
    _partialTranscriptSubscription?.cancel();
    _partialTranscriptSubscription = null;
    _transcriptSubscription?.cancel();
    _transcriptSubscription = null;
    _responseSubscription?.cancel();
    _responseSubscription = null;
    _streamingResponseSubscription?.cancel();
    _streamingResponseSubscription = null;
    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;

    _livekitService.dispose();
    super.dispose();
  }
}

/// Conversation message model
class ConversationMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ConversationMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
