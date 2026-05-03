import 'package:flutter/foundation.dart';
import '../models/app_preferences_notifier.dart';
import '../models/services/preferences_service.dart';

/// Settings Controller - Manages business logic for Settings View
class SettingsController extends ChangeNotifier {
  final AppPreferencesNotifier _preferencesNotifier;
  final PreferencesService _preferencesService;

  SettingsController({
    required AppPreferencesNotifier preferencesNotifier,
    required PreferencesService preferencesService,
  })  : _preferencesNotifier = preferencesNotifier,
        _preferencesService = preferencesService;

  /// Get current preferences notifier
  AppPreferencesNotifier get preferencesNotifier => _preferencesNotifier;

  @override
  void dispose() {
    super.dispose();
  }
}
