import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

/// Unified service for persisting and loading all app settings
class AppSettingsService {
  static const String _settingsKey = 'app_settings';

  /// Load all app settings from persistent storage
  Future<AppSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsKey);
      
      print('[AppSettingsService] Loading settings...');
      print('[AppSettingsService] JSON string from storage: $jsonString');
      
      if (jsonString == null) {
        print('[AppSettingsService] No settings found, returning defaults');
        return AppSettings.defaults();
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final settings = AppSettings.fromJson(json);
      print('[AppSettingsService] Loaded settings: ${settings.toJson()}');
      return settings;
    } catch (e) {
      // If there's any error loading, return defaults
      print('[AppSettingsService] ERROR loading settings: $e');
      return AppSettings.defaults();
    }
  }

  /// Save all app settings to persistent storage
  Future<bool> saveSettings(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      print('[AppSettingsService] Saving settings...');
      print('[AppSettingsService] Settings to save: ${settings.toJson()}');
      print('[AppSettingsService] JSON string: $jsonString');
      final result = await prefs.setString(_settingsKey, jsonString);
      print('[AppSettingsService] Save result: $result');
      
      // Verify it was saved
      final saved = prefs.getString(_settingsKey);
      print('[AppSettingsService] Verification - stored value: $saved');
      
      return result;
    } catch (e) {
      print('[AppSettingsService] ERROR saving settings: $e');
      return false;
    }
  }

  /// Clear all settings
  Future<bool> clearAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_settingsKey);
    } catch (e) {
      return false;
    }
  }
}