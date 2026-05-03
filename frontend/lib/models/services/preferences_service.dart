import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_preferences.dart';
import '../llm_profile.dart';

/// PreferencesService - Handles persistent storage of app preferences
///
/// Uses SharedPreferences for persistence. Stores the main preferences
/// blob as JSON under a single key, and LLM profiles as a separate key.
class PreferencesService {
  static const String _prefsKey = 'vox_ui_preferences_v1';
  static const String _llmProfilesKey = 'vox_ui_llm_profiles';
  static const String _activeProfileIdKey = 'vox_ui_active_profile_id';
  static const String _livekitUrlKey = 'vox_ui_livekit_url';
  static const String _tokenServiceUrlKey = 'vox_ui_token_service_url';
  static const String _sttBaseUrlKey = 'vox_ui_stt_base_url';
  static const String _ttsBaseUrlKey = 'vox_ui_tts_base_url';
  static const String _ttsVoiceKey = 'vox_ui_tts_voice';
  static const String _ttsSpeedKey = 'vox_ui_tts_speed';
  static const String _themeModeKey = 'vox_ui_theme_mode';

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

  /// Save preferences to persistent storage
  Future<void> save(AppPreferences preferences) async {
    try {
      final jsonString = jsonEncode(preferences.toJson());
      await _p.setString(_prefsKey, jsonString);
      if (kDebugMode) {
        debugPrint('PreferencesService: Saved preferences');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PreferencesService: Error saving preferences: $e');
      }
    }
  }

  /// Load preferences from persistent storage
  Future<AppPreferences?> load() async {
    try {
      final jsonString = _p.getString(_prefsKey);
      if (jsonString == null) return null;
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppPreferences.fromJson(json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PreferencesService: Error loading preferences: $e');
      }
      return null;
    }
  }

  /// Clear all saved preferences (reset to defaults)
  Future<void> clear() async {
    try {
      await _p.remove(_prefsKey);
      if (kDebugMode) {
        debugPrint('PreferencesService: Cleared preferences');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PreferencesService: Error clearing preferences: $e');
      }
    }
  }

  // ========== LLM Profiles ==========

  /// Load LLM profiles
  List<LlmProfile> loadLlmProfiles() {
    try {
      final jsonString = _p.getString(_llmProfilesKey);
      if (jsonString == null) return [];
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((e) => LlmProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PreferencesService: Error loading LLM profiles: $e');
      }
      return [];
    }
  }

  /// Save LLM profiles
  Future<void> saveLlmProfiles(List<LlmProfile> profiles) async {
    try {
      final jsonString =
          jsonEncode(profiles.map((p) => p.toJson()).toList());
      await _p.setString(_llmProfilesKey, jsonString);
      if (kDebugMode) {
        debugPrint('PreferencesService: Saved ${profiles.length} LLM profiles');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PreferencesService: Error saving LLM profiles: $e');
      }
    }
  }

  /// Get active profile ID
  String? getActiveProfileId() {
    return _p.getString(_activeProfileIdKey);
  }

  /// Set active profile ID
  Future<void> setActiveProfileId(String? id) async {
    if (id != null) {
      await _p.setString(_activeProfileIdKey, id);
    } else {
      await _p.remove(_activeProfileIdKey);
    }
  }

  // ========== Connection Settings ==========

  String get livekitUrl => _p.getString(_livekitUrlKey) ?? 'ws://localhost:7880';
  set livekitUrl(String v) => _p.setString(_livekitUrlKey, v);

  String get tokenServiceUrl => _p.getString(_tokenServiceUrlKey) ?? 'https://rg-w00-chat.resonancegroupusa.com/api';
  set tokenServiceUrl(String v) => _p.setString(_tokenServiceUrlKey, v);

  // ========== Voice Endpoints ==========

  String get sttBaseUrl => _p.getString(_sttBaseUrlKey) ?? 'https://jetson-whisper.resonancegroupusa.com';
  set sttBaseUrl(String v) => _p.setString(_sttBaseUrlKey, v);

  String get ttsBaseUrl => _p.getString(_ttsBaseUrlKey) ?? 'https://jetson-kokoro.resonancegroupusa.com';
  set ttsBaseUrl(String v) => _p.setString(_ttsBaseUrlKey, v);

  String get ttsVoice => _p.getString(_ttsVoiceKey) ?? 'af_heart';
  set ttsVoice(String v) => _p.setString(_ttsVoiceKey, v);

  double get ttsSpeed => _p.getDouble(_ttsSpeedKey) ?? 1.0;
  set ttsSpeed(double v) => _p.setDouble(_ttsSpeedKey, v);

  /// 'dark' | 'light' | 'system'
  String get themeModeName => _p.getString(_themeModeKey) ?? 'dark';
  set themeModeName(String v) => _p.setString(_themeModeKey, v);
}
