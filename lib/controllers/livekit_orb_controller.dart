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
    final data = LiveKitOrbData(
      state: orbState,
      level: level ?? currentData.level,
      theme: currentData.theme,
      status: status ?? _getDefaultStatus(orbState),
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
      // Connection states
      case 'disconnected':
        return 'disconnected';
      case 'connecting':
        return 'muted';  // Show muted state while connecting
      case 'connected_with_agent':
        return 'idle';  // Agent present and ready
      case 'connected_no_agent':
        return 'disconnected';  // No agent = off state
      
      // Activity states
      case 'talking':
        return 'processing';  // Agent is speaking/active
      case 'silent':
        return 'idle';  // Connected but silent
      case 'muted':
        return 'muted';  // Microphone muted
        
      // Legacy states for backward compatibility
      case 'initializing':
      case 'listening':
        return 'idle';
      case 'thinking':
        return 'processing';
      case 'speaking':
        return 'processing';
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
        return 'Processing request';
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