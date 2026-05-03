class LlmProfile {
  final String id;
  final String name;
  final String baseUrl;
  final String modelName;

  const LlmProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.modelName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'modelName': modelName,
      };

  factory LlmProfile.fromJson(Map<String, dynamic> j) => LlmProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        baseUrl: j['baseUrl'] as String,
        modelName: j['modelName'] as String,
      );

  LlmProfile copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? modelName,
  }) =>
      LlmProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        modelName: modelName ?? this.modelName,
      );
}
