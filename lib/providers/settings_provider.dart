import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/voice_agent_settings.dart';
import '../services/settings_service.dart';

/// Provider for the settings service
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

/// Provider for Voice Agent settings
/// 
/// This is an AsyncNotifier that loads settings on startup and provides
/// methods for updating individual fields
class VoiceAgentSettingsNotifier extends AsyncNotifier<VoiceAgentSettings> {
  @override
  Future<VoiceAgentSettings> build() async {
    // Load settings when provider is first accessed
    final service = ref.read(settingsServiceProvider);
    return await service.loadVoiceAgentSettings();
  }

  /// Update server URL
  Future<void> updateServerUrl(String url) async {
    state = await AsyncValue.guard(() async {
      final current = state.value ?? VoiceAgentSettings.defaults();
      final updated = current.copyWith(serverUrl: url);
      final service = ref.read(settingsServiceProvider);
      await service.saveVoiceAgentSettings(updated);
      return updated;
    });
  }

  /// Update LiveKit token
  Future<void> updateToken(String token) async {
    state = await AsyncValue.guard(() async {
      final current = state.value ?? VoiceAgentSettings.defaults();
      final updated = current.copyWith(token: token);
      final service = ref.read(settingsServiceProvider);
      await service.saveVoiceAgentSettings(updated);
      return updated;
    });
  }

  /// Update system prompt
  Future<void> updateSystemPrompt(String prompt) async {
    state = await AsyncValue.guard(() async {
      final current = state.value ?? VoiceAgentSettings.defaults();
      final updated = current.copyWith(systemPrompt: prompt);
      final service = ref.read(settingsServiceProvider);
      await service.saveVoiceAgentSettings(updated);
      return updated;
    });
  }

  /// Update model
  Future<void> updateModel(String model) async {
    state = await AsyncValue.guard(() async {
      final current = state.value ?? VoiceAgentSettings.defaults();
      final updated = current.copyWith(model: model);
      final service = ref.read(settingsServiceProvider);
      await service.saveVoiceAgentSettings(updated);
      return updated;
    });
  }

  /// Update voice
  Future<void> updateVoice(String voice) async {
    state = await AsyncValue.guard(() async {
      final current = state.value ?? VoiceAgentSettings.defaults();
      final updated = current.copyWith(voice: voice);
      final service = ref.read(settingsServiceProvider);
      await service.saveVoiceAgentSettings(updated);
      return updated;
    });
  }

  /// Update all settings at once
  Future<void> updateAll(VoiceAgentSettings settings) async {
    state = await AsyncValue.guard(() async {
      final service = ref.read(settingsServiceProvider);
      await service.saveVoiceAgentSettings(settings);
      return settings;
    });
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    state = await AsyncValue.guard(() async {
      final defaults = VoiceAgentSettings.defaults();
      final service = ref.read(settingsServiceProvider);
      await service.saveVoiceAgentSettings(defaults);
      return defaults;
    });
  }
}

/// Provider for Voice Agent settings state
final voiceAgentSettingsProvider = 
    AsyncNotifierProvider<VoiceAgentSettingsNotifier, VoiceAgentSettings>(() {
  return VoiceAgentSettingsNotifier();
});