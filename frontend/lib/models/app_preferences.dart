/// UI size scaling options
enum UISize { small, medium, large }

/// AppPreferences - Pure data model for VoxUI preferences
/// Stripped of all RV-specific fields; only UI and general settings remain.
class AppPreferences {
  // ========== UI SIZE SCALING ==========
  final UISize uiSize;

  /// Constructor with default values
  const AppPreferences({
    this.uiSize = UISize.medium,
  });

  // ========== UI SCALE COMPUTED PROPERTY ==========
  double get uiScale {
    switch (uiSize) {
      case UISize.small:
        return 0.85;
      case UISize.medium:
        return 1.00;
      case UISize.large:
        return 1.15;
    }
  }

  // ========== IMMUTABLE COPY METHOD ==========
  AppPreferences copyWith({
    UISize? uiSize,
  }) {
    return AppPreferences(
      uiSize: uiSize ?? this.uiSize,
    );
  }

  // ========== SERIALIZATION ==========
  Map<String, dynamic> toJson() {
    return {
      'uiSize': uiSize.name,
    };
  }

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    return AppPreferences(
      uiSize: UISize.values.byName(json['uiSize'] ?? 'medium'),
    );
  }
}
