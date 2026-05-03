/// Consolidated constants for VoxUI
class AppConstants {
  // Debug Mode - set to true to skip backend connection attempts
  static const bool isDebugMode = false;

  // Demo Mode - set to true to skip hardware connections for UI testing
  static const bool isDemoMode = false;

  // Navigation Routes
  static const String homeRoute = '/';
  static const String aiRoute = '/ai';
  static const String settingsRoute = '/settings';
  static const String profilesRoute = '/profiles';

  // AI Voice Agent Settings
  static const String aiTokenServiceUrl = 'http://10.0.0.200:7882';
  static const String aiDefaultRoom = 'ai-assistant-room';
  static const String aiParticipantIdentity = 'dashboard-tablet';

  // Legacy defaults (used when PreferencesService has no saved value)
  static const String aiVoiceServerUrl = 'wss://jetson-livekit.resonancegroupusa.com';
  static const String aiVoiceAgentModel = 'llama3.2:3b';
  static const String aiVoiceTtsVoice = 'af_heart';
  static const String aiVoiceSystemPrompt =
      'You are an AI voice assistant. Keep responses concise and helpful.';
  static const Duration aiConnectionTimeout = Duration(seconds: 15);
  static const Duration aiReconnectDelay = Duration(seconds: 5);
  static const int aiMaxReconnectAttempts = 3;
  static const bool aiEnableDebugLogs = true;

  // Timeouts
  static const Duration snackbarDuration = Duration(seconds: 2);
  static const Duration animationDuration = Duration(milliseconds: 300);
}
