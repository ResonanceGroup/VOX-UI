/// Voice Agent Settings Model
///
/// Stores configuration for LiveKit voice agent connection.
class VoiceAgentSettings {
  final String serverUrl;
  final String token;
  final String voice;

  /// Optional: URL to a local token service.
  /// Example: http://192.168.1.10:8787
  final String tokenServiceUrl;

  /// Room/identity used when fetching a token.
  final String room;
  final String identity;

  const VoiceAgentSettings({
    required this.serverUrl,
    required this.token,
    required this.voice,
    required this.tokenServiceUrl,
    required this.room,
    required this.identity,
  });

  factory VoiceAgentSettings.defaults() {
    return const VoiceAgentSettings(
      serverUrl: 'ws://localhost:7880',
      token: '',
      voice: 'af_heart',
      tokenServiceUrl: 'http://localhost:8787',
      room: 'vox',
      identity: 'phone',
    );
  }

  /// Backward compatible: ignores legacy fields.
  factory VoiceAgentSettings.fromJson(Map<String, dynamic> json) {
    return VoiceAgentSettings(
      serverUrl: json['serverUrl'] as String? ?? 'ws://localhost:7880',
      token: json['token'] as String? ?? '',
      voice: json['voice'] as String? ?? 'af_heart',
      tokenServiceUrl: json['tokenServiceUrl'] as String? ?? 'http://localhost:8787',
      room: json['room'] as String? ?? 'vox',
      identity: json['identity'] as String? ?? 'phone',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'token': token,
      'voice': voice,
      'tokenServiceUrl': tokenServiceUrl,
      'room': room,
      'identity': identity,
    };
  }

  VoiceAgentSettings copyWith({
    String? serverUrl,
    String? token,
    String? voice,
    String? tokenServiceUrl,
    String? room,
    String? identity,
  }) {
    return VoiceAgentSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      token: token ?? this.token,
      voice: voice ?? this.voice,
      tokenServiceUrl: tokenServiceUrl ?? this.tokenServiceUrl,
      room: room ?? this.room,
      identity: identity ?? this.identity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoiceAgentSettings &&
        other.serverUrl == serverUrl &&
        other.token == token &&
        other.voice == voice &&
        other.tokenServiceUrl == tokenServiceUrl &&
        other.room == room &&
        other.identity == identity;
  }

  @override
  int get hashCode => Object.hash(serverUrl, token, voice, tokenServiceUrl, room, identity);
}
