import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/services/livekit_service.dart';
import '../models/constants.dart';

/// Controller for managing AI voice agent state and interactions
class AIController extends ChangeNotifier {
  final LiveKitService _livekitService;

  // Subscriptions
  StreamSubscription<AIConnectionState>? _connectionStateSubscription;
  StreamSubscription<AIAgentState>? _agentStateSubscription;
  StreamSubscription<String>? _transcriptSubscription;
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

  // Connection availability
  bool _isTcpConnected = false;
  bool _isTablet = false;

  AIController({
    LiveKitService? livekitService,
  })  : _livekitService = livekitService ?? LiveKitService() {
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
  double get currentAudioLevel => _currentAudioLevel;

  /// Check if AI is available based on connection type and device
  bool get isAIAvailable {
    // In debug mode, always available
    if (kDebugMode && AppConstants.isDemoMode) {
      return true;
    }

    // Check if device is tablet or larger
    if (!_isTablet) {
      return false;
    }

    // AI voice connection is independent of the RV backend TCP connection —
    // it connects directly to LiveKit on the Jetson via the local network.
    return true;
  }

  /// Check if AI is enabled (connected and ready to use)
  bool get isAIEnabled {
    return isAIAvailable && _connectionState == AIConnectionState.connected;
  }

  /// Get status message for UI
  String get statusMessage {
    if (!isAIAvailable) {
      if (!_isTablet) {
        return 'AI is only available on tablets';
      }
    }

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

  /// Initialize the controller
  void _initialize() {
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🤖 AIController: Initializing...');
    }

    // Listen to connection state changes
    _connectionStateSubscription =
        _livekitService.connectionState.listen((state) {
      _connectionState = state;
      if (state == AIConnectionState.error) {
        _errorMessage = 'Failed to connect to AI service';
      } else {
        _errorMessage = null;
      }
      // Auto-reconnect on unexpected disconnect (not from explicit user action)
      if (state == AIConnectionState.disconnected && isAIAvailable) {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 3), () {
          if (_connectionState == AIConnectionState.disconnected) {
            if (AppConstants.aiEnableDebugLogs) {
              debugPrint('🤖 AIController: Auto-reconnecting after unexpected disconnect...');
            }
            connect();
          }
        });
      } else {
        // Connected or connecting — cancel any pending reconnect
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }
      notifyListeners();
    });

    // Listen to agent state changes
    _agentStateSubscription = _livekitService.agentState.listen((state) {
      _agentState = state;
      notifyListeners();
    });

    // Listen to transcript updates
    _transcriptSubscription = _livekitService.transcript.listen((text) {
      _currentTranscript = text;
      _addToHistory(ConversationMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    });

    // Listen to response updates
    _responseSubscription = _livekitService.response.listen((text) {
      _currentResponse = text;
      _streamingAgentMessage = null; // final arrived — clear the preview
      _addToHistory(ConversationMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    });

    // Listen to streaming (non-final) agent response for live preview
    _streamingResponseSubscription = _livekitService.streamingResponse.listen((text) {
      // Empty string = clear signal (final segment incoming)
      _streamingAgentMessage = text.isEmpty ? null : text;
      notifyListeners();
    });

    // Listen to audio level updates
    _audioLevelSubscription = _livekitService.audioLevel.listen((level) {
      _currentAudioLevel = level;
      notifyListeners();
    });    
    // Log audio levels periodically for debugging
    if (AppConstants.aiEnableDebugLogs) {
      _audioLevelLogTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_currentAudioLevel > 0.0) {
          debugPrint('🎤 AIController: Audio level: ${(_currentAudioLevel * 100).toStringAsFixed(1)}%');
        }
      });
    }
    
    // In debug mode, start audio monitoring with a delay to avoid native crashes
    if (kDebugMode && AppConstants.isDemoMode) {
      // Delay audio initialization to ensure UI is fully rendered and
      // native audio subsystem is ready (prevents thread attachment crashes)
      Future.delayed(const Duration(milliseconds: 1500), () {
        _startDebugAudioMonitoring();
      });
    }
  }

  /// Start audio monitoring in debug mode
  Future<void> _startDebugAudioMonitoring() async {
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎤 AIController: Starting debug audio monitoring...');
    }
    
    try {
      await _livekitService.startAudioMonitoring();
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('❌ AIController: Failed to start audio monitoring: $e');
      }
      // Don't let audio monitoring failures crash the app
      _errorMessage = 'Audio monitoring unavailable';
    }
  }

  /// Update device type (tablet or not)
  void updateDeviceType(bool isTablet) {
    _isTablet = isTablet;
    notifyListeners();
  }

  /// Update TCP connection status
  void updateTcpConnectionStatus(bool isConnected) {
    _isTcpConnected = isConnected;
    notifyListeners();
  }

  /// Connect to AI service
  Future<bool> connect() async {
    // Skip connection in demo mode to avoid sending data
    if (kDebugMode && AppConstants.isDemoMode) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('🎭 AIController: Demo mode - simulating connection');
      }
      _connectionState = AIConnectionState.connected;
      _agentState = AIAgentState.idle;
      notifyListeners();
      return true;
    }

    if (!isAIAvailable) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('⚠️ AIController: AI not available');
      }
      _errorMessage = 'AI is not available on this device or connection';
      notifyListeners();
      return false;
    }

    try {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('🤖 AIController: Connecting to AI service...');
      }

      // Initialize LiveKit service
      await _livekitService.initialize();

      // Fetch token from Jetson token service (no secrets in the app)
      final tokenData = await _livekitService.fetchToken(
        identity: AppConstants.aiParticipantIdentity,
      );

      final success = await _livekitService.connect(
        url: tokenData['url']!,
        token: tokenData['token']!,
      );

      if (success) {
        if (AppConstants.aiEnableDebugLogs) {
          debugPrint('✅ AIController: Connected to AI service');
        }
        _errorMessage = null;
      } else {
        if (AppConstants.aiEnableDebugLogs) {
          debugPrint('❌ AIController: Failed to connect to AI service');
        }
        _errorMessage = 'Failed to connect to AI service';
      }

      notifyListeners();
      return success;
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('❌ AIController: Connection error: $e');
      }
      _errorMessage = 'Connection error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from AI service
  Future<void> disconnect() async {
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🤖 AIController: Disconnecting from AI service...');
    }

    // In demo mode, just update state
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
    if (!isAIEnabled) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('⚠️ AIController: AI not enabled, cannot send message');
      }
      return;
    }

    // In demo mode, simulate response
    if (kDebugMode && AppConstants.isDemoMode) {
      _addToHistory(ConversationMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      
      // Simulate AI thinking
      _agentState = AIAgentState.processing;
      notifyListeners();
      
      await Future.delayed(const Duration(seconds: 1));
      
      // Simulate response
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

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('💬 AIController: Sending message: $message');
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

  /// Start voice recording
  void startRecording() {
    _isRecording = true;
    notifyListeners();

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ AIController: Started recording');
    }
  }

  /// Stop voice recording
  void stopRecording() {
    _isRecording = false;
    notifyListeners();

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🛑 AIController: Stopped recording');
    }
  }

  /// Toggle microphone mute
  Future<void> toggleMute() async {
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ AIController: Toggling mute (current: ${_livekitService.isMuted})');
    }
    
    await _livekitService.toggleMute();
    // Notify listeners to update UI immediately
    notifyListeners();
    
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🎙️ AIController: Mute state changed to ${_livekitService.isMuted}');
      debugPrint('🎙️ AIController: Current agent state: $_agentState');
      debugPrint('🎙️ AIController: Is AI enabled: $isAIEnabled');
      debugPrint('🎙️ AIController: Is AI available: $isAIAvailable');
    }
  }

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
    _currentTranscript = '';
    _currentResponse = '';
    notifyListeners();

    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🗑️ AIController: Cleared conversation history');
    }
  }

  /// Add message to conversation history
  void _addToHistory(ConversationMessage message) {
    _conversationHistory.add(message);
    
    // Keep only last 50 messages to prevent memory issues
    if (_conversationHistory.length > 50) {
      _conversationHistory.removeAt(0);
    }
  }

  @override
  void dispose() {
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('🤖 AIController: Disposing...');
    }

    // Cancel audio level logging timer first
    _audioLevelLogTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _audioLevelLogTimer = null;
    
    // Stop audio monitoring before disposing service
    // This ensures the AudioStreamer stops before stream controllers close
    try {
      _livekitService.stopAudioMonitoring();
    } catch (e) {
      if (AppConstants.aiEnableDebugLogs) {
        debugPrint('⚠️ AIController: Error stopping audio monitoring: $e');
      }
    }
    
    // Cancel all subscriptions
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    
    _agentStateSubscription?.cancel();
    _agentStateSubscription = null;
    
    _transcriptSubscription?.cancel();
    _transcriptSubscription = null;
    
    _responseSubscription?.cancel();
    _responseSubscription = null;
    
    _streamingResponseSubscription?.cancel();
    _streamingResponseSubscription = null;

    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;
    
    // Dispose LiveKit service (will clean up remaining resources)
    _livekitService.dispose();
    
    if (AppConstants.aiEnableDebugLogs) {
      debugPrint('✅ AIController: Disposed successfully');
    }
    
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
