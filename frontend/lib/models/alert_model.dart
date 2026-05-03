/// Alert severity levels
/// Maps to backend values: "info", "warning", "error"
enum AlertSeverity {
  info,     // Informational (blue)
  warning,  // Needs attention (yellow/orange)
  error,    // Error - urgent action required (red)
  critical, // Legacy mapping to "error" for backend compatibility
}

/// Alert categories for filtering and icon display
enum AlertCategory {
  battery,  // Battery-related alerts
  water,    // Water system alerts
  solar,    // Solar system alerts
  climate,  // Climate/HVAC alerts
  system,   // General system alerts
  backend,  // Backend-generated alerts (catch-all)
}

/// AlertItem - Comprehensive alert data model
/// 
/// V1 Notes:
/// - No persistence (alerts cleared on app restart)
/// - No actionUrl (all notifications → dashboard)
/// - Dismissing = deleting (no acknowledgment tracking)
/// 
/// Future enhancements:
/// - Add actionUrl for deep linking
/// - Add persistence via AlertStorageService
/// - Add backend acknowledgment sync
class AlertItem {
  final String id;                    // Unique identifier (UUID or backend-provided)
  final String title;                 // Alert title
  final String message;               // Detailed message
  final AlertSeverity severity;       // Severity level
  final AlertCategory category;       // Alert category
  final DateTime timestamp;           // When alert was created

  const AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.category,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _DefaultTimestamp();

  /// Convert to JSON for future persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'severity': severity.name,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from JSON (for future persistence and backend alerts)
  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      severity: _parseSeverity(json['severity']),
      category: _parseCategory(json['category']),
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now(),
    );
  }

  /// Parse severity from string (backend compatibility)
  static AlertSeverity _parseSeverity(dynamic value) {
    if (value is AlertSeverity) return value;
    
    final severityStr = (value as String?)?.toLowerCase() ?? 'info';
    switch (severityStr) {
      case 'warning':
        return AlertSeverity.warning;
      case 'error':
      case 'critical': // Support legacy "critical" mapping
        return AlertSeverity.error;
      case 'info':
      default:
        return AlertSeverity.info;
    }
  }

  /// Parse category from string
  static AlertCategory _parseCategory(dynamic value) {
    if (value is AlertCategory) return value;
    
    final categoryStr = (value as String?)?.toLowerCase() ?? 'system';
    switch (categoryStr) {
      case 'battery':
        return AlertCategory.battery;
      case 'water':
        return AlertCategory.water;
      case 'solar':
        return AlertCategory.solar;
      case 'climate':
        return AlertCategory.climate;
      case 'backend':
        return AlertCategory.backend;
      case 'system':
      default:
        return AlertCategory.system;
    }
  }

  /// Create a copy with updated fields
  AlertItem copyWith({
    String? id,
    String? title,
    String? message,
    AlertSeverity? severity,
    AlertCategory? category,
    DateTime? timestamp,
  }) {
    return AlertItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'AlertItem(id: $id, title: $title, severity: ${severity.name}, category: ${category.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AlertItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Helper class for default timestamp in const constructor
class _DefaultTimestamp implements DateTime {
  const _DefaultTimestamp();
  
  @override
  DateTime add(Duration duration) => DateTime.now().add(duration);
  
  @override
  int compareTo(DateTime other) => DateTime.now().compareTo(other);
  
  @override
  DateTime subtract(Duration duration) => DateTime.now().subtract(duration);
  
  @override
  Duration difference(DateTime other) => DateTime.now().difference(other);
  
  @override
  bool isAfter(DateTime other) => DateTime.now().isAfter(other);
  
  @override
  bool isBefore(DateTime other) => DateTime.now().isBefore(other);
  
  @override
  bool isAtSameMomentAs(DateTime other) => DateTime.now().isAtSameMomentAs(other);
  
  @override
  int get day => DateTime.now().day;
  
  @override
  int get hour => DateTime.now().hour;
  
  @override
  bool get isUtc => false;
  
  @override
  int get microsecond => DateTime.now().microsecond;
  
  @override
  int get millisecond => DateTime.now().millisecond;
  
  @override
  int get millisecondsSinceEpoch => DateTime.now().millisecondsSinceEpoch;
  
  @override
  int get minute => DateTime.now().minute;
  
  @override
  int get month => DateTime.now().month;
  
  @override
  int get second => DateTime.now().second;
  
  @override
  String get timeZoneName => DateTime.now().timeZoneName;
  
  @override
  Duration get timeZoneOffset => DateTime.now().timeZoneOffset;
  
  @override
  int get weekday => DateTime.now().weekday;
  
  @override
  int get year => DateTime.now().year;
  
  @override
  DateTime toLocal() => DateTime.now().toLocal();
  
  @override
  DateTime toUtc() => DateTime.now().toUtc();
  
  @override
  String toIso8601String() => DateTime.now().toIso8601String();
  
  @override
  int get microsecondsSinceEpoch => DateTime.now().microsecondsSinceEpoch;
}
