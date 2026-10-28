import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_preferences.dart';
import '../agent_profile.dart';

/// PreferencesService - Handles persistent storage of app preferences
///
/// Uses SharedPreferences for persistence. Stores the main preferences
/// blob as JSON under a single key, and agent profiles as a separate key.
class PreferencesService {
  static const String _prefsKey = 'vox_ui_preferences_v1';
  static const String _agentProfilesKey = 'vox_ui_agent_profiles';
  static const String _activeProfileIdKey = 'vox_ui_active_profile_id';
  static const String _livekitUrlKey = 'vox_ui_livekit_url';
  static const String _tokenServiceUrlKey = 'vox_ui_token_service_url';
  static const String _sttBaseUrlKey = 'vox_ui_stt_base_url';
  static const String _ttsBaseUrlKey = 'vox_ui_tts_base_url';
  static const String _ttsVoiceKey = 'vox_ui_tts_voice';
  static const String _ttsSpeedKey = 'vox_ui_tts_speed';
  static const String _themeModeKey = 'vox_ui_theme_mode';
  static const String _backendBaseUrlKey = 'vox_ui_backend_base_url';

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences (call once at startup)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (kDebugMode) {
      debugPrint('PreferencesService: Initialized');
    }
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'PreferencesService not initialized. Call init() first.');
    return _prefs!;
  }

  // ========== General Preferences ==========

  Future<void> save(AppPreferences preferences) async {
    try {
      final jsonString = jsonEncode(preferences.toJson());
      await _p.setString(_prefsKey, jsonString);
    } catch (e) {
      if (kDebugMode) debugPrint('PreferencesService: Error saving preferences: $e');
    }
  }

  Future<AppPreferences?> load() async {
    try {
      final jsonString = _p.getString(_prefsKey);
      if (jsonString == null) return null;
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppPreferences.fromJson(json);
    } catch (e) {
      if (kDebugMode) debugPrint('PreferencesService: Error loading preferences: $e');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _p.remove(_prefsKey);
    } catch (e) {
      if (kDebugMode) debugPrint('PreferencesService: Error clearing preferences: $e');
    }
  }

  // ========== Agent Profiles ==========

  /// Load agent profiles (renamed from LLM profiles — now includes STT/TTS)
  List<AgentProfile> loadAgentProfiles() {
    try {
      final jsonString = _p.getString(_agentProfilesKey);
      if (jsonString == null) return [];
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((e) => AgentProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('PreferencesService: Error loading agent profiles: $e');
      return [];
    }
  }

  Future<void> saveAgentProfiles(List<AgentProfile> profiles) async {
    try {
      final jsonString =
          jsonEncode(profiles.map((p) => p.toJson()).toList());
      await _p.setString(_agentProfilesKey, jsonString);
      if (kDebugMode) debugPrint('PreferencesService: Saved ${profiles.length} agent profiles');
    } catch (e) {
      if (kDebugMode) debugPrint('PreferencesService: Error saving agent profiles: $e');
    }
  }

  // Legacy compat — migrates old LlmProfile key to new AgentProfile key
  List<AgentProfile> loadAndMigrateProfiles() {
    // Try new key first
    var profiles = loadAgentProfiles();
    if (profiles.isNotEmpty) return profiles;

    // Try old key
    const oldKey = 'vox_ui_llm_profiles';
    try {
      final jsonString = _p.getString(oldKey);
      if (jsonString != null) {
        final list = jsonDecode(jsonString) as List<dynamic>;
        // Old format: {id, name, baseUrl, modelName, apiKey}
        profiles = list.map((e) {
          final m = e as Map<String, dynamic>;
          return AgentProfile(
            id: m['id'] as String,
            name: m['name'] as String,
            llmBaseUrl: (m['baseUrl'] as String?) ?? '',
            llmModelName: (m['modelName'] as String?) ?? '',
            llmApiKey: (m['apiKey'] as String?) ?? '',
          );
        }).toList();
        if (profiles.isNotEmpty) {
          saveAgentProfiles(profiles);
          _p.remove(oldKey);
          if (kDebugMode) debugPrint('PreferencesService: Migrated ${profiles.length} LLM profiles to AgentProfile format');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PreferencesService: Error migrating old profiles: $e');
    }
    return profiles;
  }

  String? getActiveProfileId() => _p.getString(_activeProfileIdKey);

  Future<void> setActiveProfileId(String? id) async {
    if (id != null) {
      await _p.setString(_activeProfileIdKey, id);
    } else {
      await _p.remove(_activeProfileIdKey);
    }
  }

  // ========== Connection Settings (Global) ==========

  String get livekitUrl => _p.getString(_livekitUrlKey) ?? 'ws://localhost:7880';
  set livekitUrl(String v) => _p.setString(_livekitUrlKey, v);

  String get backendBaseUrl => _p.getString(_backendBaseUrlKey) ?? 'https://rg-w00-chat.resonancegroupusa.com';
  set backendBaseUrl(String v) => _p.setString(_backendBaseUrlKey, v);

  String get tokenServiceUrl => _p.getString(_tokenServiceUrlKey) ?? '${backendBaseUrl}/api';
  set tokenServiceUrl(String v) => _p.setString(_tokenServiceUrlKey, v);

  // ========== Voice Endpoints (Global defaults — overridden by active profile) ==========

  String get sttBaseUrl => _p.getString(_sttBaseUrlKey) ?? 'https://jetson-whisper.resonancegroupusa.com';
  set sttBaseUrl(String v) => _p.setString(_sttBaseUrlKey, v);

  String get ttsBaseUrl => _p.getString(_ttsBaseUrlKey) ?? 'https://jetson-kokoro.resonancegroupusa.com';
  set ttsBaseUrl(String v) => _p.setString(_ttsBaseUrlKey, v);

  String get ttsVoice => _p.getString(_ttsVoiceKey) ?? 'af_heart';
  set ttsVoice(String v) => _p.setString(_ttsVoiceKey, v);

  double get ttsSpeed => _p.getDouble(_ttsSpeedKey) ?? 1.0;
  set ttsSpeed(double v) => _p.setDouble(_ttsSpeedKey, v);

  String get themeModeName => _p.getString(_themeModeKey) ?? 'dark';
  set themeModeName(String v) => _p.setString(_themeModeKey, v);
}
