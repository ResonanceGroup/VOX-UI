import 'package:flutter/material.dart';
import 'voice_agent_settings.dart';

/// Unified App Settings Model
///
/// Stores all application configuration including Voice Agent settings and theme preferences
class AppSettings {
  final VoiceAgentSettings voiceAgent;
  final ThemeMode themeMode;

  AppSettings({
    required this.voiceAgent,
    required this.themeMode,
  });

  /// Default settings for initial setup
  factory AppSettings.defaults() {
    return AppSettings(
      voiceAgent: VoiceAgentSettings.defaults(),
      themeMode: ThemeMode.system,
    );
  }

  /// Create from JSON map
  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AppSettings.defaults();
    }

    return AppSettings(
      voiceAgent: VoiceAgentSettings.fromJson(
        json['voiceAgent'] as Map<String, dynamic>? ?? {},
      ),
      themeMode: _themeModeFromJson(json['themeMode'] as String?),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'voiceAgent': voiceAgent.toJson(),
      'themeMode': _themeModeToJson(themeMode),
    };
  }

  /// Create a copy with updated fields
  AppSettings copyWith({
    VoiceAgentSettings? voiceAgent,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      voiceAgent: voiceAgent ?? this.voiceAgent,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.voiceAgent == voiceAgent &&
        other.themeMode == themeMode;
  }

  @override
  int get hashCode => Object.hash(voiceAgent, themeMode);

  /// Helper methods for theme mode conversion
  static ThemeMode _themeModeFromJson(String? themeString) {
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToJson(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }
}