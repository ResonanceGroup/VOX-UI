import 'package:flutter/foundation.dart';

class LiveKitOrbData {
  final String state;
  final double level;
  final String theme;
  final String status;
  
  LiveKitOrbData({
    required this.state,
    required this.level,
    required this.theme,
    required this.status,
  });
  
  Map<String, dynamic> toJson() => {
    'state': state,
    'level': level,
    'theme': theme,
    'status': status,
  };
}

class LiveKitOrbController extends ChangeNotifier {
  static final LiveKitOrbController _instance = LiveKitOrbController._internal();
  factory LiveKitOrbController() => _instance;
  LiveKitOrbController._internal();
  
  LiveKitOrbData? _currentData;
  LiveKitOrbData get currentData {
    if (_currentData != null) {
      return _currentData!;
    }
    // Return a default only if truly no data exists
    return LiveKitOrbData(
      state: 'idle',
      level: 0.0,
      theme: 'light',
      status: 'Ready to assist...',
    );
  }
  
  void updateFromLiveKit(String liveKitState, {double? level, String? status}) {
    final orbState = _mapLiveKitToOrbState(liveKitState);
    final finalStatus = status ?? _getDefaultStatus(orbState);
    
    final data = LiveKitOrbData(
      state: orbState,
      level: level ?? currentData.level,
      theme: currentData.theme,
      status: finalStatus,
    );
    
    _currentData = data;
    notifyListeners();
  }
  
  // Manual tool execution trigger
  void triggerToolExecution() {
    final data = LiveKitOrbData(
      state: 'executing',
      level: currentData.level,
      theme: currentData.theme,
      status: 'Executing tool...',
    );
    
    _currentData = data;
    notifyListeners();
  }
  
  void updateAudioLevel(double level) {
    if (_currentData == null) {
      // If no data exists yet, create initial data with current slider level
      _currentData = LiveKitOrbData(
        state: 'idle',
        level: level,
        theme: 'light',
        status: 'Ready to assist...',
      );
    } else {
      // Only update the level field while preserving everything else
      _currentData = _currentData!.copyWith(level: level);
    }
    notifyListeners();
  }
  
  void updateTheme(String theme) {
    final data = currentData.copyWith(theme: theme);
    _currentData = data;
    notifyListeners();
  }
  
  // Manual state trigger for testing
  void triggerManualState(String state) {
    final data = LiveKitOrbData(
      state: state,
      level: currentData.level,
      theme: currentData.theme,
      status: _getDefaultStatus(state),
    );
    
    _currentData = data;
    notifyListeners();
  }
  
  // Get the current audio level independently
  double get currentAudioLevel => _currentData?.level ?? 0.0;
  
  // State mapping based on LiveKit integration requirements
  String _mapLiveKitToOrbState(String liveKitState) {
    switch (liveKitState) {
      // Already-orb states
      case 'idle':
      case 'processing':
      case 'executing':
      case 'notifying':
      case 'muted':
      case 'disconnected':
        return liveKitState;

      // Connection states
      case 'connecting':
        return 'muted';
      case 'connected_with_agent':
        return 'idle';
      case 'connected_no_agent':
        return 'disconnected';

      // Activity
      case 'talking':
        return 'processing';
      case 'silent':
        return 'idle';

      // Agent-provided pipeline states
      case 'listening':
        return 'idle';
      case 'transcribing':
      case 'thinking':
      case 'speaking':
        return 'processing';
      case 'error':
        return 'disconnected';

      default:
        return 'disconnected';
    }
  }
  
  String _getDefaultStatus(String orbState) {
    switch (orbState) {
      case 'idle':
        return 'Ready to assist...';
      case 'executing':
        return 'Executing tool...';  // Different from speaking
      case 'processing':
        return 'Processing…';
      case 'speaking':
        return 'Responding...';  // Different from executing
      case 'muted':
        return 'Microphone muted';
      case 'notifying':
        return 'Notification received';
      case 'disconnected':
        return 'Disconnected';
      default:
        return 'Ready to assist...';
    }
  }
}

// Extension for copying LiveKitOrbData
extension LiveKitOrbDataCopy on LiveKitOrbData {
  LiveKitOrbData copyWith({
    String? state,
    double? level,
    String? theme,
    String? status,
  }) {
    return LiveKitOrbData(
      state: state ?? this.state,
      level: level ?? this.level,
      theme: theme ?? this.theme,
      status: status ?? this.status,
    );
  }
}