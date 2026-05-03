import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_preferences.dart';
import 'services/preferences_service.dart';
import 'llm_profile.dart';

/// AppPreferencesNotifier - State management for VoxUI preferences
class AppPreferencesNotifier extends ChangeNotifier {
  final PreferencesService _preferencesService;
  AppPreferences _preferences = const AppPreferences();

  // ========== VERSION INFORMATION (NOT PERSISTED) ==========
  String _frontendVersion = '—';

  AppPreferencesNotifier(this._preferencesService) {
    _loadPreferences();
    _loadVersionInfo();
  }

  /// Load app version from platform package info
  Future<void> _loadVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;
      if (_frontendVersion != version) {
        _frontendVersion = version;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppPreferencesNotifier: Could not read package info: $e');
      }
    }
  }

  AppPreferences get preferences => _preferences;

  // Convenience getters
  UISize get uiSize => _preferences.uiSize;
  double get uiScale => _preferences.uiScale;
  String get frontendVersion => _frontendVersion;

  // ========== LLM PROFILES (delegated to PreferencesService) ==========

  List<LlmProfile> _llmProfiles = [];
  String? _activeProfileId;

  List<LlmProfile> get llmProfiles => _llmProfiles;
  String? get activeProfileId => _activeProfileId;

  /// Get the currently active profile (or null)
  LlmProfile? get activeProfile {
    if (_activeProfileId == null) return null;
    try {
      return _llmProfiles.firstWhere((p) => p.id == _activeProfileId);
    } catch (_) {
      return null;
    }
  }

  /// Load LLM profiles from persistence
  void _loadLlmProfiles() {
    _llmProfiles = _preferencesService.loadLlmProfiles();
    _activeProfileId = _preferencesService.getActiveProfileId();
  }

  /// Add a new LLM profile
  Future<void> addLlmProfile(LlmProfile profile) async {
    _llmProfiles = [..._llmProfiles, profile];
    await _preferencesService.saveLlmProfiles(_llmProfiles);
    notifyListeners();
  }

  /// Update an existing LLM profile
  Future<void> updateLlmProfile(LlmProfile profile) async {
    _llmProfiles = [
      for (final p in _llmProfiles)
        if (p.id == profile.id) profile else p,
    ];
    await _preferencesService.saveLlmProfiles(_llmProfiles);
    notifyListeners();
  }

  /// Delete an LLM profile by ID
  Future<void> deleteLlmProfile(String id) async {
    _llmProfiles = _llmProfiles.where((p) => p.id != id).toList();
    if (_activeProfileId == id) {
      _activeProfileId = _llmProfiles.isNotEmpty ? _llmProfiles.first.id : null;
      await _preferencesService.setActiveProfileId(_activeProfileId);
    }
    await _preferencesService.saveLlmProfiles(_llmProfiles);
    notifyListeners();
  }

  /// Set the active profile
  Future<void> setActiveProfileId(String? id) async {
    if (_activeProfileId != id) {
      _activeProfileId = id;
      await _preferencesService.setActiveProfileId(id);
      notifyListeners();
    }
  }

  // ========== CONNECTION SETTINGS (delegated to PreferencesService) ==========

  String get livekitUrl => _preferencesService.livekitUrl;
  set livekitUrl(String v) => _preferencesService.livekitUrl = v;

  String get tokenServiceUrl => _preferencesService.tokenServiceUrl;
  set tokenServiceUrl(String v) => _preferencesService.tokenServiceUrl = v;

  // ========== VOICE ENDPOINTS (delegated to PreferencesService) ==========

  String get sttBaseUrl => _preferencesService.sttBaseUrl;
  set sttBaseUrl(String v) => _preferencesService.sttBaseUrl = v;

  String get ttsBaseUrl => _preferencesService.ttsBaseUrl;
  set ttsBaseUrl(String v) => _preferencesService.ttsBaseUrl = v;

  String get ttsVoice => _preferencesService.ttsVoice;
  set ttsVoice(String v) => _preferencesService.ttsVoice = v;

  double get ttsSpeed => _preferencesService.ttsSpeed;
  set ttsSpeed(double v) => _preferencesService.ttsSpeed = v;

  // ========== STATE UPDATE METHODS ==========

  void setUISize(UISize size) {
    if (_preferences.uiSize != size) {
      _preferences = _preferences.copyWith(uiSize: size);
      notifyListeners();
      _savePreferences();
    }
  }

  // ========== RESET TO DEFAULTS ==========

  Future<void> resetToDefaults() async {
    _preferences = const AppPreferences();
    _llmProfiles = [];
    _activeProfileId = null;
    await _preferencesService.clear();
    await _preferencesService.saveLlmProfiles([]);
    await _preferencesService.setActiveProfileId(null);
    notifyListeners();
    if (kDebugMode) {
      debugPrint('Preferences reset to defaults');
    }
  }

  // ========== PERSISTENCE ==========

  Future<void> _loadPreferences() async {
    try {
      final loaded = await _preferencesService.load();
      if (loaded != null) {
        _preferences = loaded;
      }
      _loadLlmProfiles();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading preferences: $e');
      }
    }
  }

  Future<void> _savePreferences() async {
    try {
      await _preferencesService.save(_preferences);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving preferences: $e');
      }
    }
  }
}
