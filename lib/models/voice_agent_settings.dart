/// Voice Agent Settings Model
///
/// Stores configuration for LiveKit voice agent connection
class VoiceAgentSettings {
  final String serverUrl;
  final String token;
  final String systemPrompt;
  final String model;
  final String voice;

  const VoiceAgentSettings({
    required this.serverUrl,
    required this.token,
    required this.systemPrompt,
    required this.model,
    required this.voice,
  });

  /// Default settings for initial setup
  factory VoiceAgentSettings.defaults() {
    return const VoiceAgentSettings(
      serverUrl: 'http://localhost:7880',
      token: '',
      systemPrompt: 'You are a helpful offline voice assistant. '
          'Be concise and friendly. You run completely locally.',
      model: 'qwen2:1.5b',
      voice: 'af_heart',
    );
  }

  /// Create from JSON map
  factory VoiceAgentSettings.fromJson(Map<String, dynamic> json) {
    return VoiceAgentSettings(
      serverUrl: json['serverUrl'] as String? ?? 'http://localhost:7880',
      token: json['token'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ??
          'You are a helpful offline voice assistant. '
          'Be concise and friendly. You run completely locally.',
      model: json['model'] as String? ?? 'qwen2:1.5b',
      voice: json['voice'] as String? ?? 'af_heart',
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'token': token,
      'systemPrompt': systemPrompt,
      'model': model,
      'voice': voice,
    };
  }

  /// Create a copy with updated fields
  VoiceAgentSettings copyWith({
    String? serverUrl,
    String? token,
    String? systemPrompt,
    String? model,
    String? voice,
  }) {
    return VoiceAgentSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      token: token ?? this.token,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      model: model ?? this.model,
      voice: voice ?? this.voice,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoiceAgentSettings &&
        other.serverUrl == serverUrl &&
        other.token == token &&
        other.systemPrompt == systemPrompt &&
        other.model == model &&
        other.voice == voice;
  }

  @override
  int get hashCode {
    return Object.hash(
      serverUrl,
      token,
      systemPrompt,
      model,
      voice,
    );
  }
}