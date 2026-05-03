import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_preferences.dart';
import 'services/preferences_service.dart';

/// AppPreferencesNotifier - State management for app-wide user preferences
/// 
/// This notifier manages the current state of user preferences and coordinates
/// with PreferencesService for persistence. It extends ChangeNotifier to enable
/// reactive UI updates when preferences change.
/// 
/// Layer responsibilities:
/// - AppPreferences: Pure data (what)
/// - PreferencesService: Storage operations (how)
/// - AppPreferencesNotifier: State coordination (when)
class AppPreferencesNotifier extends ChangeNotifier {
  final PreferencesService _preferencesService;
  AppPreferences _preferences = const AppPreferences();

  // ========== CONNECTION STATUS (NOT PERSISTED) ==========
  // These are managed separately and set by external services
  bool _isConnected = false;
  String _connectionType = 'None';
  String _overallStatus = 'Disconnected';

  // ========== VERSION INFORMATION (NOT PERSISTED) ==========
  String _frontendVersion = '—';
  String _backendVersion = '1.0.0';

  /// Constructor - initializes with service dependency
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
      if (kDebugMode) print('AppPreferencesNotifier: Could not read package info: $e');
    }
  }

  /// Get current preferences data model
  AppPreferences get preferences => _preferences;

  // ========== CONVENIENCE GETTERS ==========
  // Expose commonly used properties for easier access

  // UI Scaling
  UISize get uiSize => _preferences.uiSize;
  double get uiScale => _preferences.uiScale;

  // Units
  TemperatureUnit get temperatureUnit => _preferences.temperatureUnit;
  VolumeUnit get volumeUnit => _preferences.volumeUnit;
  DistanceUnit get distanceUnit => _preferences.distanceUnit;
  BatteryCapacityUnit get batteryCapacityUnit => _preferences.batteryCapacityUnit;

  // Unit labels
  String get temperatureUnitLabel => _preferences.temperatureUnitLabel;
  String get volumeUnitLabel => _preferences.volumeUnitLabel;
  String get distanceUnitLabel => _preferences.distanceUnitLabel;
  String get speedUnitLabel => _preferences.speedUnitLabel;
  String get batteryCapacityUnitLabel => _preferences.batteryCapacityUnitLabel;

  // RV Profile
  String get rvNickname => _preferences.rvNickname;
  String get rvMakeModel => _preferences.rvMakeModel;
  String get rvYear => _preferences.rvYear;
  double get freshWaterCapacity => _preferences.freshWaterCapacity;
  double get greyWaterCapacity => _preferences.greyWaterCapacity;
  double get blackWaterCapacity => _preferences.blackWaterCapacity;
  double get propaneCapacity => _preferences.propaneCapacity;
  double get batteryBankCapacity => _preferences.batteryBankCapacity;
  BatterySystemVoltage get batterySystemVoltage => _preferences.batterySystemVoltage;
  double get batterySystemVoltageValue => _preferences.batterySystemVoltageValue;

  // Alert Thresholds
  double get batterySOCLowWarning => _preferences.batterySOCLowWarning;
  double get batterySOCLowCritical => _preferences.batterySOCLowCritical;
  double get freshWaterLowWarning => _preferences.freshWaterLowWarning;
  double get solarCurrentLowWarning => _preferences.solarCurrentLowWarning;
  double get solarCurrentHighWarning => _preferences.solarCurrentHighWarning;
  int get solarAlertStartHour => _preferences.solarAlertStartHour;
  int get solarAlertEndHour => _preferences.solarAlertEndHour;

  // Connection Status (not persisted)
  bool get isConnected => _isConnected;
  String get connectionType => _connectionType;
  String get overallStatus => _overallStatus;

  // Version Information (not persisted)
  String get frontendVersion => _frontendVersion;
  String get backendVersion => _backendVersion;

  // ========== UNIT CONVERSION HELPERS ==========
  // Delegate to AppPreferences model
  double convertTemperature(double value, {bool toDisplay = true}) =>
      _preferences.convertTemperature(value, toDisplay: toDisplay);

  double convertVolume(double value, {bool toDisplay = true}) =>
      _preferences.convertVolume(value, toDisplay: toDisplay);

  double convertDistance(double value, {bool toDisplay = true}) =>
      _preferences.convertDistance(value, toDisplay: toDisplay);

  double convertBatteryCapacity(double value, double systemVoltage, {bool toDisplay = true}) =>
      _preferences.convertBatteryCapacity(value, systemVoltage, toDisplay: toDisplay);

  // ========== STATE UPDATE METHODS ==========

  /// Set UI size and persist
  void setUISize(UISize size) {
    if (_preferences.uiSize != size) {
      _preferences = _preferences.copyWith(uiSize: size);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set temperature unit and persist
  void setTemperatureUnit(TemperatureUnit unit) {
    if (_preferences.temperatureUnit != unit) {
      _preferences = _preferences.copyWith(temperatureUnit: unit);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set volume unit and persist
  void setVolumeUnit(VolumeUnit unit) {
    if (_preferences.volumeUnit != unit) {
      _preferences = _preferences.copyWith(volumeUnit: unit);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set distance unit and persist
  void setDistanceUnit(DistanceUnit unit) {
    if (_preferences.distanceUnit != unit) {
      _preferences = _preferences.copyWith(distanceUnit: unit);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set battery capacity unit and persist
  void setBatteryCapacityUnit(BatteryCapacityUnit unit) {
    if (_preferences.batteryCapacityUnit != unit) {
      _preferences = _preferences.copyWith(batteryCapacityUnit: unit);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set RV nickname and persist
  void setRVNickname(String value) {
    if (_preferences.rvNickname != value) {
      _preferences = _preferences.copyWith(rvNickname: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set RV make/model and persist
  void setRVMakeModel(String value) {
    if (_preferences.rvMakeModel != value) {
      _preferences = _preferences.copyWith(rvMakeModel: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set RV year and persist
  void setRVYear(String value) {
    if (_preferences.rvYear != value) {
      _preferences = _preferences.copyWith(rvYear: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set fresh water capacity and persist
  void setFreshWaterCapacity(double value) {
    if (_preferences.freshWaterCapacity != value) {
      _preferences = _preferences.copyWith(freshWaterCapacity: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set grey water capacity and persist
  void setGreyWaterCapacity(double value) {
    if (_preferences.greyWaterCapacity != value) {
      _preferences = _preferences.copyWith(greyWaterCapacity: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set black water capacity and persist
  void setBlackWaterCapacity(double value) {
    if (_preferences.blackWaterCapacity != value) {
      _preferences = _preferences.copyWith(blackWaterCapacity: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set propane capacity and persist
  void setPropaneCapacity(double value) {
    if (_preferences.propaneCapacity != value) {
      _preferences = _preferences.copyWith(propaneCapacity: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set battery bank capacity and persist
  void setBatteryBankCapacity(double value) {
    if (_preferences.batteryBankCapacity != value) {
      _preferences = _preferences.copyWith(batteryBankCapacity: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set battery system voltage and persist
  void setBatterySystemVoltage(BatterySystemVoltage value) {
    if (_preferences.batterySystemVoltage != value) {
      _preferences = _preferences.copyWith(batterySystemVoltage: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set battery SOC low warning threshold and persist
  void setBatterySOCLowWarning(double value) {
    if (_preferences.batterySOCLowWarning != value) {
      _preferences = _preferences.copyWith(batterySOCLowWarning: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set battery SOC low critical threshold and persist
  void setBatterySOCLowCritical(double value) {
    if (_preferences.batterySOCLowCritical != value) {
      _preferences = _preferences.copyWith(batterySOCLowCritical: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set fresh water low warning threshold and persist
  void setFreshWaterLowWarning(double value) {
    if (_preferences.freshWaterLowWarning != value) {
      _preferences = _preferences.copyWith(freshWaterLowWarning: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set solar current low warning threshold and persist
  void setSolarCurrentLowWarning(double value) {
    if (_preferences.solarCurrentLowWarning != value) {
      _preferences = _preferences.copyWith(solarCurrentLowWarning: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set solar current high warning threshold and persist
  void setSolarCurrentHighWarning(double value) {
    if (_preferences.solarCurrentHighWarning != value) {
      _preferences = _preferences.copyWith(solarCurrentHighWarning: value);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set solar alert start hour and persist
  void setSolarAlertStartHour(int value) {
    // Clamp value between 0 and 23
    final clampedValue = value.clamp(0, 23);
    if (_preferences.solarAlertStartHour != clampedValue) {
      _preferences = _preferences.copyWith(solarAlertStartHour: clampedValue);
      notifyListeners();
      _savePreferences();
    }
  }

  /// Set solar alert end hour and persist
  void setSolarAlertEndHour(int value) {
    // Clamp value between 0 and 23
    final clampedValue = value.clamp(0, 23);
    if (_preferences.solarAlertEndHour != clampedValue) {
      _preferences = _preferences.copyWith(solarAlertEndHour: clampedValue);
      notifyListeners();
      _savePreferences();
    }
  }

  // ========== CONNECTION STATUS (NOT PERSISTED) ==========
  
  /// Set connection status (managed by external services)
  /// This is NOT persisted as it's runtime state
  void setConnectionStatus(bool connected, String type, {String? overallStatus}) {
    bool changed = false;
    if (_isConnected != connected) {
      _isConnected = connected;
      changed = true;
    }
    if (_connectionType != type) {
      _connectionType = type;
      changed = true;
    }
    final status = overallStatus ?? (connected ? 'Connected' : 'Disconnected');
    if (_overallStatus != status) {
      _overallStatus = status;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  // ========== VERSION INFORMATION (NOT PERSISTED) ==========
  
  /// Set frontend version (not persisted)
  void setFrontendVersion(String value) {
    if (_frontendVersion != value) {
      _frontendVersion = value;
      notifyListeners();
    }
  }

  /// Set backend version (not persisted)
  void setBackendVersion(String value) {
    if (_backendVersion != value) {
      _backendVersion = value;
      notifyListeners();
    }
  }

  // ========== RESET TO DEFAULTS ==========
  
  /// Reset all preferences to default values and persist
  Future<void> resetToDefaults() async {
    _preferences = const AppPreferences(); // Use default constructor
    notifyListeners();
    
    // Clear persisted preferences
    await _preferencesService.clear();
    
    if (kDebugMode) {
      print('✅ Preferences reset to defaults');
    }
  }

  // ========== PERSISTENCE OPERATIONS ==========

  /// Load preferences from storage
  /// Called automatically during initialization
  Future<void> _loadPreferences() async {
    try {
      final loaded = await _preferencesService.load();
      if (loaded != null) {
        _preferences = loaded;
        notifyListeners();
        if (kDebugMode) {
          print('✅ Preferences loaded from storage');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ No saved preferences, using defaults');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading preferences: $e');
        print('   Using defaults');
      }
      // Keep default preferences on error
    }
  }

  /// Save current preferences to storage
  /// Called automatically when any preference changes
  Future<void> _savePreferences() async {
    try {
      await _preferencesService.save(_preferences);
      // Note: Service logs success/failure internally
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving preferences: $e');
      }
      // Don't rethrow - allow app to continue even if save fails
    }
  }

  /// Manually trigger a save (if needed for batch updates)
  Future<void> saveNow() async {
    await _savePreferences();
  }
}
