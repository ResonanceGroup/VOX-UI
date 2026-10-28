/// AgentProfile — per-profile connection settings for LLM, STT, and TTS.
class AgentProfile {
  final String id;
  final String name;

  // LLM
  final String llmBaseUrl;
  final String llmModelName;
  final String llmApiKey;

  // STT
  final String sttUrl;
  final String sttModel;

  // TTS
  final String ttsUrl;
  final String ttsVoice;
  final String ttsModel;
  final double ttsSpeed;

  // Agent behavior
  final int llmReadTimeout;      // seconds
  final int llmMaxRetries;
  final int maxContextItems;     // 1 = slim mode (system + latest user only)
  final bool preemptiveGeneration;
  final bool discardWhileGenerating;

  const AgentProfile({
    required this.id,
    required this.name,
    this.llmBaseUrl = '',
    this.llmModelName = '',
    this.llmApiKey = '',
    this.sttUrl = '',
    this.sttModel = '',
    this.ttsUrl = '',
    this.ttsVoice = 'af_heart',
    this.ttsModel = 'tts-1',
    this.ttsSpeed = 1.0,
    this.llmReadTimeout = 120,
    this.llmMaxRetries = 3,
    this.maxContextItems = 10,
    this.preemptiveGeneration = false,
    this.discardWhileGenerating = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'llmBaseUrl': llmBaseUrl,
    'llmModelName': llmModelName,
    'llmApiKey': llmApiKey,
    'sttUrl': sttUrl,
    'sttModel': sttModel,
    'ttsUrl': ttsUrl,
    'ttsVoice': ttsVoice,
    'ttsModel': ttsModel,
    'ttsSpeed': ttsSpeed,
    'llmReadTimeout': llmReadTimeout,
    'llmMaxRetries': llmMaxRetries,
    'maxContextItems': maxContextItems,
    'preemptiveGeneration': preemptiveGeneration,
    'discardWhileGenerating': discardWhileGenerating,
  };

  factory AgentProfile.fromJson(Map<String, dynamic> j) => AgentProfile(
    id: j['id'] as String,
    name: j['name'] as String,
    llmBaseUrl: (j['llmBaseUrl'] as String?) ?? '',
    llmModelName: (j['llmModelName'] as String?) ?? '',
    llmApiKey: (j['llmApiKey'] as String?) ?? '',
    sttUrl: (j['sttUrl'] as String?) ?? '',
    sttModel: (j['sttModel'] as String?) ?? '',
    ttsUrl: (j['ttsUrl'] as String?) ?? '',
    ttsVoice: (j['ttsVoice'] as String?) ?? 'af_heart',
    ttsModel: (j['ttsModel'] as String?) ?? 'tts-1',
    ttsSpeed: (j['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
    llmReadTimeout: (j['llmReadTimeout'] as num?)?.toInt() ?? 120,
    llmMaxRetries: (j['llmMaxRetries'] as num?)?.toInt() ?? 3,
    maxContextItems: (j['maxContextItems'] as num?)?.toInt() ?? 10,
    preemptiveGeneration: (j['preemptiveGeneration'] as bool?) ?? false,
    discardWhileGenerating: (j['discardWhileGenerating'] as bool?) ?? true,
  );

  AgentProfile copyWith({
    String? id,
    String? name,
    String? llmBaseUrl,
    String? llmModelName,
    String? llmApiKey,
    String? sttUrl,
    String? sttModel,
    String? ttsUrl,
    String? ttsVoice,
    String? ttsModel,
    double? ttsSpeed,
    int? llmReadTimeout,
    int? llmMaxRetries,
    int? maxContextItems,
    bool? preemptiveGeneration,
    bool? discardWhileGenerating,
  }) {
    return AgentProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
      llmModelName: llmModelName ?? this.llmModelName,
      llmApiKey: llmApiKey ?? this.llmApiKey,
      sttUrl: sttUrl ?? this.sttUrl,
      sttModel: sttModel ?? this.sttModel,
      ttsUrl: ttsUrl ?? this.ttsUrl,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsModel: ttsModel ?? this.ttsModel,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      llmReadTimeout: llmReadTimeout ?? this.llmReadTimeout,
      llmMaxRetries: llmMaxRetries ?? this.llmMaxRetries,
      maxContextItems: maxContextItems ?? this.maxContextItems,
      preemptiveGeneration: preemptiveGeneration ?? this.preemptiveGeneration,
      discardWhileGenerating: discardWhileGenerating ?? this.discardWhileGenerating,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
