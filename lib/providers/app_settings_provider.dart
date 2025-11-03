import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/voice_agent_settings.dart';
import '../services/app_settings_service.dart';

/// Provider for the app settings service
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

/// Provider for all app settings
/// 
/// This is an AsyncNotifier that loads all settings on startup and provides
/// methods for updating settings
class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    // Load settings when provider is first accessed (at app startup)
    final service = ref.read(appSettingsServiceProvider);
    return await service.loadSettings();
  }

  /// Update voice agent settings
  Future<void> updateVoiceAgent(VoiceAgentSettings voiceAgent) async {
    state = await AsyncValue.guard(() async {
      final current = state.value ?? AppSettings.defaults();
      final updated = current.copyWith(voiceAgent: voiceAgent);
      final service = ref.read(appSettingsServiceProvider);
      await service.saveSettings(updated);
      return updated;
    });
  }

  /// Update theme mode
  Future<void> updateThemeMode(ThemeMode themeMode) async {
    state = await AsyncValue.guard(() async {
      final current = state.value ?? AppSettings.defaults();
      final updated = current.copyWith(themeMode: themeMode);
      final service = ref.read(appSettingsServiceProvider);
      await service.saveSettings(updated);
      return updated;
    });
  }

  /// Update all settings at once
  Future<void> updateAll(AppSettings settings) async {
    state = await AsyncValue.guard(() async {
      final service = ref.read(appSettingsServiceProvider);
      await service.saveSettings(settings);
      return settings;
    });
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    state = await AsyncValue.guard(() async {
      final defaults = AppSettings.defaults();
      final service = ref.read(appSettingsServiceProvider);
      await service.saveSettings(defaults);
      return defaults;
    });
  }
}

/// Provider for app settings state
final appSettingsProvider = 
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(() {
  return AppSettingsNotifier();
});