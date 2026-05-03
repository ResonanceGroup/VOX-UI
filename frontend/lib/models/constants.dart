/// Consolidated constants for the RV Flutter Demo app
/// Centralizes all important hardcoded values for easy modification and maintenance
class AppConstants {
  // Debug Mode - set to true to skip all backend connection attempts (BLE/TCP).
  // When true, the app uses its initial/mock values and never searches for the backend.
  // Set to false for normal production behaviour where the app searches for a connection.
  static const bool isDebugMode = false;

  // Demo Mode - set to true to skip hardware connections for UI testing
  // Controllers will use their initial values as mock data
  static const bool isDemoMode = false; // Change to false for production

  // Firebase Database
  static const String firebaseDatabaseUrl = 'https://rg-smart-control-system-default-rtdb.firebaseio.com/';
  static const String usersPath = 'users';
  static const String rvSettingsPath = 'rv_settings';
  static const String lastUpdatedKey = 'last_updated';

  // RV Settings Keys
  static const String thermostatControlSetTemperatureKey = 'thermostatControl_setTemperature';
  static const String lightsAllBrightnessKey = 'lights_all_brightness';

  // Default RV Settings Values
  static const double defaultTemperatureCelsius = 22.0; // Default temperature in °C
  static const double defaultTemperatureFahrenheit = 72.0; // Default temperature in °F
  static const double defaultBrightness = 50.0; // Default brightness percentage

  // BLE Device Names
  static const String primaryBleDeviceName = 'rgcommandcenter2';

  // BLE UUIDs - Primary Device (dashboard)
  static const String deviceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String primaryServiceUUID = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String primaryTxCharacteristicUUID = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String primaryRxCharacteristicUUID = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
  static const int BLEServiceTimeout = 15; // seconds

  // Google OAuth - Platform-specific Client IDs
  static const String googleClientIdAndroid = '462600381570-htci1n2k563s5si2gemaa1fgrph7tqoj.apps.googleusercontent.com';
  static const String googleClientIdIOS = '462600381570-ca3e5cptic7t00eg22htfs9sc5j0rurn.apps.googleusercontent.com';

  // Navigation Routes
  static const String homeRoute = '/';
  static const String demoRoute = '/demo';
  static const String profileRoute = '/profile';

  // Temperature Limits
  static const double minTemperatureFahrenheit = 32.0; // 32°F (0°C)
  static const double maxTemperatureFahrenheit = 104.0; // 104°F (40°C)
  static const double minTemperatureCelsius = 0.0;
  static const double maxTemperatureCelsius = 200.0;

  // Validation Limits (matching Firebase rules)
  static const double minValidTemperature = 0.0;
  static const double maxValidTemperature = 200.0;

  // Timeouts
  static const Duration bleTimeout = Duration(seconds: 10); // Reduced from 60s for faster connections
  static const Duration nfcTimeout = Duration(seconds: 5);

  // TCP Connection Constants
  static const String dashboardHost = '10.0.0.2'; // Dashboard IP address
  static const int dashboardPort = 9000; // Default TCP port for dashboard
  static const Duration tcpConnectionTimeout = Duration(seconds: 10);
  static const Duration tcpReadTimeout = Duration(seconds: 30);
  static const int tcpMaxRetries = 3;
  static const Duration tcpRetryDelay = Duration(seconds: 2);

  // UI Constants
  static const Duration snackbarDuration = Duration(seconds: 2);
  static const Duration animationDuration = Duration(milliseconds: 300);

  // NFC Polling Options
  static const int nfcIso14443 = 1; // NfcPollingOption.iso14443
  static const int nfcIso15693 = 2; // NfcPollingOption.iso15693

  // Firebase Database Rules Validation (for reference)
  static const String emailValidation = 'newData.isString() && newData.val().length > 0';
  static const String temperatureValidation = 'newData.isNumber() && newData.val() >= 0 && newData.val() <= 200';
  static const String lightingValidation = 'newData.isString() && newData.val().length > 0';
  static const String lastUpdatedValidation = 'newData.isNumber() && newData.val() > 0';

  // Error Messages
  static const String nfcNotSupportedWeb = 'NFC is not supported on the web';
  static const String nfcNotSupportedPlatform = 'NFC is not supported on this platform';
  static const String nfcAvailable = 'NFC is available';
  static const String noTagScanned = 'No tag scanned';
  static const String bleInitializing = 'Initializing BLE...';
  static const String rvSettingsSynced = 'RV settings synced to cloud';
  static const String syncFailed = 'Sync failed';

  // Solar panel notification settings
  static const String solarPowerLow = '⚠️ Low Solar Power Alert';
  static const String solarPowerNormal = 'Solar power is back to normal';
  static const int solarPanelAlertThreshold = 5; // Watts
  static const int solarPanelNotificationID = 1001;

  // AI Voice Agent Settings
  // Token service runs on Jetson — handles signing, no secrets in the app
  static const String aiTokenServiceUrl = 'http://10.0.0.200:7882';
  static const String aiDefaultRoom = 'ai-assistant-room';
  static const String aiParticipantIdentity = 'dashboard-tablet';

  // Legacy
  static const String aiVoiceServerUrl = 'wss://jetson-livekit.resonancegroupusa.com'; // LiveKit WebSocket URL
  static const String aiVoiceAgentModel = 'llama3.2:3b'; // Default LLM model
  static const String aiVoiceTtsVoice = 'alloy'; // Default TTS voice
  static const String aiVoiceSystemPrompt = '''You are an AI assistant embedded in an RV. You can read data from the power system (inverter, battery, solar) and control or read the state of the lighting system. Keep responses concise and helpful.''';
  static const Duration aiConnectionTimeout = Duration(seconds: 15);
  static const Duration aiReconnectDelay = Duration(seconds: 5);
  static const int aiMaxReconnectAttempts = 3;
  static const bool aiEnableDebugLogs = true;
}
