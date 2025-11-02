import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_agent_settings.dart';

/// Service for persisting and loading app settings
class SettingsService {
  static const String _voiceAgentKey = 'voice_agent_settings';

  /// Load Voice Agent settings from persistent storage
  Future<VoiceAgentSettings> loadVoiceAgentSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_voiceAgentKey);
      
      if (jsonString == null) {
        return VoiceAgentSettings.defaults();
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return VoiceAgentSettings.fromJson(json);
    } catch (e) {
      // If there's any error loading, return defaults
      return VoiceAgentSettings.defaults();
    }
  }

  /// Save Voice Agent settings to persistent storage
  Future<bool> saveVoiceAgentSettings(VoiceAgentSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      return await prefs.setString(_voiceAgentKey, jsonString);
    } catch (e) {
      return false;
    }
  }

  /// Clear all settings
  Future<bool> clearAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.clear();
    } catch (e) {
      return false;
    }
  }
}