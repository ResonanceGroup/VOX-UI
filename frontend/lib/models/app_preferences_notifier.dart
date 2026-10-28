import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:package_info_plus/package_info_plus.dart';
import 'app_preferences.dart';
import 'services/preferences_service.dart';
import 'agent_profile.dart';

/// AppPreferencesNotifier — state management for VoxUI preferences.
///
/// Profiles are backend-only — SharedPreferences is NOT used for profiles
/// or active profile ID. Backend (profiles.json) is the single source of truth.
/// Only connection settings and theme are stored locally.
class AppPreferencesNotifier extends ChangeNotifier {
  final PreferencesService _preferencesService;

  AppPreferences _preferences = const AppPreferences();
  String _frontendVersion = '—';

  /// ConfigApiService — set by the caller so we can sync with the backend.
  /// If null, profile syncing is skipped.
  dynamic _configApi;

  AppPreferencesNotifier(this._preferencesService);

  void setConfigApi(api) { _configApi = api; }

  // ── App info ─────────────────────────────────────────────────────────────

  Future<void> _loadVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _frontendVersion = info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;
      notifyListeners();
    } catch (_) {}
  }

  AppPreferences get preferences => _preferences;
  UISize get uiSize => _preferences.uiSize;
  double get uiScale => _preferences.uiScale;
  String get frontendVersion => _frontendVersion;

  // ── Agent Profiles (backend-only) ────────────────────────────────────────

  List<AgentProfile> _agentProfiles = [];
  String? _activeProfileId;

  List<AgentProfile> get agentProfiles => _agentProfiles;
  String? get activeProfileId => _activeProfileId;

  AgentProfile? get activeProfile {
    if (_activeProfileId == null) return null;
    try {
      return _agentProfiles.firstWhere((p) => p.id == _activeProfileId);
    } catch (_) { return null; }
  }

  /// Fetch profiles from the backend. Backend is the only truth.
  /// Falls back to built-in defaults only if the backend is unreachable.
  Future<void> syncFromBackend() async {
    if (_configApi == null) return;
    try {
      final result = await _configApi.fetchProfiles();
      if (result != null && result.profiles.isNotEmpty) {
        _agentProfiles = result.profiles.map((m) => _mapToAgentProfile(m)).toList();
        if (result.activeProfileId != null) {
          _activeProfileId = result.activeProfileId;
        }
        _activeProfileId ??= _agentProfiles.first.id;
        if (kDebugMode) debugPrint('AppPreferencesNotifier: Synced ${_agentProfiles.length} profiles from backend, active=\$_activeProfileId');
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AppPreferencesNotifier: Backend profile fetch failed: \$e');
    }
  }

  /// Save current profiles + active profile to backend.
  Future<void> syncToBackend() async {
    if (_configApi == null) return;
    try {
      final maps = _agentProfiles.map((p) => p.toJson()).toList();
      final ok = await _configApi.saveProfiles(maps, activeProfileId: _activeProfileId);
      if (kDebugMode) {
        debugPrint(ok
          ? 'AppPreferencesNotifier: Saved ${_agentProfiles.length} profiles to backend'
          : 'AppPreferencesNotifier: Backend profile save returned false');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AppPreferencesNotifier: Backend profile save failed: \$e');
    }
  }

  AgentProfile _mapToAgentProfile(Map<String, dynamic> m) => AgentProfile(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? 'Unknown',
    llmBaseUrl: m['llmBaseUrl']?.toString() ?? '',
    llmModelName: m['llmModelName']?.toString() ?? '',
    llmApiKey: m['llmApiKey']?.toString() ?? '',
    sttUrl: m['sttUrl']?.toString() ?? '',
    sttModel: m['sttModel']?.toString() ?? '',
    ttsUrl: m['ttsUrl']?.toString() ?? '',
    ttsVoice: m['ttsVoice']?.toString() ?? 'af_heart',
    ttsModel: m['ttsModel']?.toString() ?? 'tts-1',
    ttsSpeed: (m['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
    llmReadTimeout: (m['llmReadTimeout'] as num?)?.toInt() ?? 120,
    llmMaxRetries: (m['llmMaxRetries'] as num?)?.toInt() ?? 3,
    maxContextItems: (m['maxContextItems'] as num?)?.toInt() ?? 10,
    preemptiveGeneration: (m['preemptiveGeneration'] as bool?) ?? false,
    discardWhileGenerating: (m['discardWhileGenerating'] as bool?) ?? true,
  );

  Future<void> addAgentProfile(AgentProfile profile) async {
    _agentProfiles = [..._agentProfiles, profile];
    await syncToBackend();
    notifyListeners();
  }

  Future<void> updateAgentProfile(AgentProfile profile) async {
    _agentProfiles = [
      for (final p in _agentProfiles)
        if (p.id == profile.id) profile else p,
    ];
    await syncToBackend();
    notifyListeners();
  }

  Future<void> deleteAgentProfile(String id) async {
    _agentProfiles = _agentProfiles.where((p) => p.id != id).toList();
    if (_activeProfileId == id) {
      _activeProfileId = _agentProfiles.isNotEmpty ? _agentProfiles.first.id : null;
    }
    await syncToBackend();
    notifyListeners();
  }

  Future<void> setActiveProfileId(String? id) async {
    if (_activeProfileId != id) {
      _activeProfileId = id;
      notifyListeners();
    }
  }

  // ── Connection Settings (local only — needed before backend is reachable) ─

  String get livekitUrl => _preferencesService.livekitUrl;
  set livekitUrl(String v) { _preferencesService.livekitUrl = v; notifyListeners(); }

  String get backendBaseUrl => _preferencesService.backendBaseUrl;
  set backendBaseUrl(String v) { _preferencesService.backendBaseUrl = v; notifyListeners(); }

  String get tokenServiceUrl => _preferencesService.tokenServiceUrl;
  set tokenServiceUrl(String v) { _preferencesService.tokenServiceUrl = v; notifyListeners(); }

  // ── Theme ─────────────────────────────────────────────────────────────────

  ThemeMode get themeMode {
    switch (_preferencesService.themeModeName) {
      case 'light':   return ThemeMode.light;
      case 'system':  return ThemeMode.system;
      default:        return ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final name = mode == ThemeMode.light ? 'light'
               : mode == ThemeMode.system ? 'system' : 'dark';
    _preferencesService.themeModeName = name;
    notifyListeners();
  }

  // ── UI Size ──────────────────────────────────────────────────────────────

  void setUISize(UISize size) {
    if (_preferences.uiSize != size) {
      _preferences = _preferences.copyWith(uiSize: size);
      _savePreferences();
      notifyListeners();
    }
  }

  // ── Reset ────────────────────────────────────────────────────────────────

  Future<void> resetToDefaults() async {
    _preferences = const AppPreferences();
    _agentProfiles = [];
    _activeProfileId = null;
    await _preferencesService.clear();
    notifyListeners();
  }

  // ── Persistence (theme + connection settings only) ────────────────────────

  Future<void> _loadPreferences() async {
    try {
      final loaded = await _preferencesService.load();
      if (loaded != null) _preferences = loaded;
      // Profiles are NOT loaded from local storage — syncFromBackend() handles them.
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('AppPreferencesNotifier: _loadPreferences error: \$e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      await _preferencesService.save(_preferences);
    } catch (e) {
      if (kDebugMode) debugPrint('AppPreferencesNotifier: _savePreferences error: \$e');
    }
  }

  AppPreferencesNotifier._internal(this._preferencesService) {
    _loadPreferences();
    _loadVersionInfo();
  }
}
