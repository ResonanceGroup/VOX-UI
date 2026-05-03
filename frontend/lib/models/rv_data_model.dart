import 'dart:async';
import 'package:flutter/foundation.dart';
import './services/firebase_database_service.dart';
import './services/json_rpc_service.dart';
import './constants.dart';
import './services/notification_service.dart';

/// RVDataModel - Manages all RV-related data and state
/// Part of the Model layer in MVC architecture
/// 
/// Responsibilities:
/// - Manages RV data (brightness, temperature, solar data, cabin temperature)
/// - Handles JSON notification processing from backend
/// - Syncs data with Firebase Database
/// - Triggers notifications for alerts (e.g., low solar power)
/// - Single source of truth for RV state
class RVDataModel extends ChangeNotifier {
  final FirebaseDatabaseService _databaseService;
  final JsonRpcService _jsonRpcService;

  // RV State
  double _brightness = AppConstants.defaultBrightness;
  double _temperature = AppConstants.defaultTemperatureFahrenheit;
  double? _solarVoltage;
  double? _solarCurrent;
  double? _solarPower;
  int _cabinTemperature = 0;

  // Subscriptions
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  RVDataModel({
    required FirebaseDatabaseService databaseService,
    required JsonRpcService jsonRpcService,
  })  : _databaseService = databaseService,
        _jsonRpcService = jsonRpcService;

  // Getters
  double get brightness => _brightness;
  double get temperature => _temperature;
  double? get solarVoltage => _solarVoltage;
  double? get solarCurrent => _solarCurrent;
  double? get solarPower => _solarPower;
  int get cabinTemperature => _cabinTemperature;

  /// Initialize and start listening to backend notifications
  void initialize() {
    if (kDebugMode) {
      print('RVDataModel: Initializing...');
    }
    
    _subscribeToNotifications();
  }

  /// Subscribe to backend notifications for data updates
  void _subscribeToNotifications() {
    _notificationSubscription = _jsonRpcService.notificationStream.listen((notification) {
      if (kDebugMode) {
        print('RVDataModel: Received notification: ${notification['method']}');
      }

      _handleNotification(notification);
    });
  }

  /// Handle incoming JSON notifications from backend
  void _handleNotification(Map<String, dynamic> notification) {
    final method = notification['method'];
    final params = notification['params'] as Map<String, dynamic>?;

    if (params == null) return;

    switch (method) {
      case 'solar.update':
        _handleSolarUpdate(params);
        break;
      case 'cabinTemperature.update':
        _handleCabinTemperatureUpdate(params);
        break;
      default:
        if (kDebugMode) {
          print('RVDataModel: Unhandled notification method: $method');
        }
    }
  }

  /// Process solar data update from backend
  void _handleSolarUpdate(Map<String, dynamic> params) {
    try {
      final voltage = params['voltage'];
      final current = params['current'];
      final power = params['power'];

      _solarVoltage = voltage is num ? voltage.toDouble() : null;
      _solarCurrent = current is num ? current.toDouble() : null;
      _solarPower = power is num ? power.toDouble() : null;

      notifyListeners();

      if (kDebugMode) {
        print('RVDataModel: Solar data updated - V: $_solarVoltage, A: $_solarCurrent, W: $_solarPower');
      }

      // Check for low solar power alert
      _checkSolarPowerAlert();
    } catch (e) {
      if (kDebugMode) {
        print('RVDataModel: Error parsing solar data: $e');
      }
    }
  }

  /// Process cabin temperature update from backend
  void _handleCabinTemperatureUpdate(Map<String, dynamic> params) {
    try {
      final temperature = params['temperature'];
      
      if (temperature is int) {
        _cabinTemperature = temperature;
        notifyListeners();

        if (kDebugMode) {
          print('RVDataModel: Cabin temperature updated: $_cabinTemperature °F');
        }
      } else {
        if (kDebugMode) {
          print('RVDataModel: Invalid cabin temperature data type: ${temperature.runtimeType}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('RVDataModel: Error parsing cabin temperature: $e');
      }
    }
  }

  /// Check solar power and send alert if below threshold
  Future<void> _checkSolarPowerAlert() async {
    if (_solarPower == null) return;

    // Get currently active notifications
    final activeNotifications = await NotificationService().getActiveNotifications();
    final hasActiveSolarAlert = activeNotifications.any(
      (notification) => notification.id == AppConstants.solarPanelNotificationID,
    );

    if (_solarPower! < AppConstants.solarPanelAlertThreshold && !hasActiveSolarAlert) {
      try {
        await NotificationService().showNotification(
          id: AppConstants.solarPanelNotificationID,
          title: AppConstants.solarPowerLow,
          body: 'Solar panel power has dropped below ${AppConstants.solarPanelAlertThreshold}W (${_solarPower!.toStringAsFixed(1)}W). Check your solar system.',
          payload: 'solar_power_alert',
        );

        if (kDebugMode) {
          print('RVDataModel: Solar power alert sent: ${_solarPower}W');
        }
      } catch (e) {
        if (kDebugMode) {
          print('RVDataModel: Failed to send solar alert: $e');
        }
      }
    }
  }

  /// Update brightness and send command to backend
  Future<void> updateBrightness(double value) async {
    _brightness = value;
    notifyListeners();

    if (kDebugMode) {
      print('RVDataModel: Brightness updated to $value');
    }

    // Send command to backend
    try {
      await _jsonRpcService.sendNotification('brightness.set', {
        'brightness': value,
      });
    } catch (e) {
      if (kDebugMode) {
        print('RVDataModel: Error sending brightness command: $e');
      }
    }
  }

  /// Update temperature setpoint and send command to backend
  Future<void> updateTemperature(double value) async {
    _temperature = value;
    notifyListeners();

    if (kDebugMode) {
      print('RVDataModel: Temperature updated to $value');
    }

    // Send command to backend
    try {
      await _jsonRpcService.sendNotification('temperature.set', {
        'temperature': value,
      });
    } catch (e) {
      if (kDebugMode) {
        print('RVDataModel: Error sending temperature command: $e');
      }
    }
  }

  /// Toggle temperature control on/off
  Future<void> toggleTemperatureControl(bool enabled) async {
    if (kDebugMode) {
      print('RVDataModel: Temperature control ${enabled ? "enabled" : "disabled"}');
    }

    try {
      await _jsonRpcService.sendNotification('temperature.enable', {
        'enabled': enabled,
      });
    } catch (e) {
      if (kDebugMode) {
        print('RVDataModel: Error toggling temperature control: $e');
      }
    }
  }

  /// Load user's saved RV settings from Firebase
  Future<void> loadFromCloud(String userId) async {
    try {
      if (kDebugMode) {
        print('RVDataModel: Loading settings from cloud for user: $userId');
      }

      final rvData = await _databaseService.getRVData(userId);
      
      if (rvData != null) {
        // Load saved lighting value (convert string to double)
        if (rvData['lights_all_brightness'] != null) {
          _brightness = double.tryParse(rvData['lights_all_brightness'].toString()) ?? 
                       AppConstants.defaultBrightness;
        }
        
        // Load saved temperature value (handle both key formats)
        if (rvData.containsKey('thermostatControl_setTemperature')) {
          _temperature = (rvData['thermostatControl_setTemperature'] as num).toDouble();
        } else if (rvData.containsKey('thermostatControl_setTemperature ')) {
          _temperature = (rvData['thermostatControl_setTemperature '] as num).toDouble();
        }

        notifyListeners();

        if (kDebugMode) {
          print('RVDataModel: Loaded settings - Brightness: $_brightness, Temp: $_temperature');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('RVDataModel: Error loading settings from cloud: $e');
      }
      rethrow;
    }
  }

  /// Save current RV settings to Firebase
  Future<void> saveToCloud(String userId) async {
    try {
      if (kDebugMode) {
        print('RVDataModel: Saving settings to cloud for user: $userId');
      }

      final rvData = {
        'lights_all_brightness': _brightness.toString(),
        'thermostatControl_setTemperature ': _temperature,
      };

      await _databaseService.updateRVData(userId, rvData);

      if (kDebugMode) {
        print('RVDataModel: Settings saved successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('RVDataModel: Error saving settings to cloud: $e');
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('RVDataModel: Disposing...');
    }
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
