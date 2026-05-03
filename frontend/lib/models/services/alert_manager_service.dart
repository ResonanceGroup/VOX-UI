import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../alert_model.dart';
import '../app_preferences_notifier.dart';
import 'json_rpc_service.dart';
import 'notification_service.dart';
import '../../Controllers/dashboard_controller.dart';

/// AlertManagerService - Centralized alert monitoring and management
/// 
/// Responsibilities:
/// - Subscribe to JSON-RPC notifications
/// - Monitor RV system values against AppPreferences thresholds
/// - Trigger push notifications for critical alerts
/// - Send alerts to DashboardController for UI display
/// - Prevent duplicate alerts with cooldown periods
/// - Handle backend-generated alerts
/// - Provide test alert injection for debugging
/// 
/// V1 Features:
/// - In-memory alert storage only (no persistence)
/// - Dismissal deletes alerts
/// - All notifications navigate to dashboard
/// 
/// Singleton pattern ensures single monitoring instance across app
class AlertManagerService {
  static final AlertManagerService _instance = AlertManagerService._internal();
  factory AlertManagerService() => _instance;
  AlertManagerService._internal();

  // Services
  final JsonRpcService _jsonRpcService = JsonRpcService();
  final NotificationService _notificationService = NotificationService();
  final Uuid _uuid = const Uuid();

  // Dependencies (set during initialization)
  AppPreferencesNotifier? _preferencesNotifier;
  DashboardController? _dashboardController;

  // State
  bool _isInitialized = false;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  // Cooldown tracking to prevent duplicate alerts
  final Map<String, DateTime> _lastAlertTime = {};

  // Cooldown durations per alert category
  static const Duration _batteryAlertCooldown = Duration(minutes: 15);
  static const Duration _waterAlertCooldown = Duration(minutes: 30);
  static const Duration _solarAlertCooldown = Duration(minutes: 10);
  static const Duration _climateAlertCooldown = Duration(minutes: 20);
  static const Duration _systemAlertCooldown = Duration(minutes: 5);

  /// Check if it's currently daytime (when solar panels should produce power)
  /// Uses user-configurable hours from preferences (default 6 AM to 6 PM)
  bool _isDaytime() {
    if (_preferencesNotifier == null) {
      // Fallback to default 6 AM - 6 PM if preferences not available
      final now = DateTime.now();
      final hour = now.hour;
      return hour >= 6 && hour < 18;
    }
    
    final now = DateTime.now();
    final hour = now.hour;
    final startHour = _preferencesNotifier!.solarAlertStartHour;
    final endHour = _preferencesNotifier!.solarAlertEndHour;
    
    return hour >= startHour && hour < endHour;
  }

  /// Initialize the alert manager with required dependencies
  Future<void> initialize({
    required AppPreferencesNotifier preferencesNotifier,
    DashboardController? dashboardController,
  }) async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('AlertManagerService: Already initialized');
      }
      return;
    }

    _preferencesNotifier = preferencesNotifier;
    _dashboardController = dashboardController;

    // Subscribe to JSON-RPC notifications
    _subscribeToNotifications();

    _isInitialized = true;

    if (kDebugMode) {
      print('✅ AlertManagerService: Initialized successfully');
    }
  }

  /// Register dashboard controller (may be set after initialization)
  void registerDashboardController(DashboardController controller) {
    _dashboardController = controller;
    if (kDebugMode) {
      print('AlertManagerService: Dashboard controller registered');
    }
  }

  /// Subscribe to JSON-RPC notification stream
  void _subscribeToNotifications() {
    _notificationSubscription = _jsonRpcService.notificationStream.listen(
      _handleNotification,
      onError: (error) {
        if (kDebugMode) {
          print('AlertManagerService: Error in notification stream: $error');
        }
      },
    );
  }

  /// Handle incoming JSON-RPC notifications
  void _handleNotification(Map<String, dynamic> notification) {
    final method = notification['method'] as String?;
    final params = notification['params'] as Map<String, dynamic>?;

    if (method == null || params == null) return;

    try {
      switch (method) {
        // Battery updates (bank1 = primary, bank2 = secondary)
        case 'bank1.update':
          _handleBatteryUpdate(params, 1);
          break;
        case 'bank2.update':
          _handleBatteryUpdate(params, 2);
          break;

        // Water updates
        case 'water.update':
          _handleWaterUpdate(params);
          break;

        // Solar updates
        case 'solar.update':
          _handleSolarUpdate(params);
          break;

        // Climate updates
        case 'climate.update':
          _handleClimateUpdate(params);
          break;

        // Backend-generated alerts
        case 'alert.new':
          _handleBackendAlert(params);
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlertManagerService: Error handling notification ($method): $e');
      }
    }
  }

  /// Handle battery SOC updates and check thresholds
  void _handleBatteryUpdate(Map<String, dynamic> params, int bank) {
    final soc = params['soc'];
    if (soc == null) return;

    final socValue = (soc as num).toDouble();
    _checkBatterySOC(socValue, bank);
  }

  /// Check battery state of charge against thresholds
  void _checkBatterySOC(double soc, int bank) {
    if (_preferencesNotifier == null) return;

    final prefs = _preferencesNotifier!;
    final bankLabel = bank == 1 ? 'Primary Battery Bank' : 'Secondary Battery Bank';
    final criticalKey = 'battery_critical_bank$bank';
    final lowKey = 'battery_low_bank$bank';
    final fullKey = 'battery_full_bank$bank';

    // Critical battery level
    if (soc <= prefs.batterySOCLowCritical) {
      if (_canTriggerAlert(criticalKey)) {
        _triggerAlert(
          id: _uuid.v4(),
          title: '$bankLabel Critical',
          message: '$bankLabel at ${soc.toStringAsFixed(0)}% - Connect to power immediately',
          severity: AlertSeverity.error,
          category: AlertCategory.battery,
        );
        _lastAlertTime[criticalKey] = DateTime.now();
      }
    }
    // Low battery warning
    else if (soc <= prefs.batterySOCLowWarning) {
      if (_canTriggerAlert(lowKey)) {
        _triggerAlert(
          id: _uuid.v4(),
          title: '$bankLabel Low',
          message: '$bankLabel at ${soc.toStringAsFixed(0)}% - Consider charging',
          severity: AlertSeverity.warning,
          category: AlertCategory.battery,
        );
        _lastAlertTime[lowKey] = DateTime.now();
      }
    }
    // Battery full (informational)
    else if (soc >= 95.0) {
      if (_canTriggerAlert(fullKey)) {
        _triggerAlert(
          id: _uuid.v4(),
          title: '$bankLabel Fully Charged',
          message: '$bankLabel at ${soc.toStringAsFixed(0)}%',
          severity: AlertSeverity.info,
          category: AlertCategory.battery,
        );
        _lastAlertTime[fullKey] = DateTime.now();
      }
    }
  }

  /// Handle water system updates and check thresholds
  void _handleWaterUpdate(Map<String, dynamic> params) {
    // Updated field names (Mar 3, 2026): fresh_level, grey_level, black_level
    final freshWater = params['fresh_level'];
    final greyWater = params['grey_level'];

    if (freshWater != null) {
      _checkFreshWaterLevel((freshWater as num).toDouble());
    }

    if (greyWater != null) {
      _checkGreyWaterLevel((greyWater as num).toDouble());
    }
  }

  /// Check fresh water level against thresholds
  void _checkFreshWaterLevel(double level) {
    if (_preferencesNotifier == null) return;

    final prefs = _preferencesNotifier!;

    // Fresh water nearly empty
    if (level < 5.0) {
      if (_canTriggerAlert('water_fresh_empty')) {
        _triggerAlert(
          id: _uuid.v4(),
          title: 'Fresh Water Empty',
          message: 'Fresh water tank at ${level.toStringAsFixed(0)}% - Refill immediately',
          severity: AlertSeverity.error,
          category: AlertCategory.water,
        );
        _lastAlertTime['water_fresh_empty'] = DateTime.now();
      }
    }
    // Fresh water low warning
    else if (level <= prefs.freshWaterLowWarning) {
      if (_canTriggerAlert('water_fresh_low')) {
        _triggerAlert(
          id: _uuid.v4(),
          title: 'Fresh Water Low',
          message: 'Fresh water tank at ${level.toStringAsFixed(0)}% - Refill soon',
          severity: AlertSeverity.warning,
          category: AlertCategory.water,
        );
        _lastAlertTime['water_fresh_low'] = DateTime.now();
      }
    }
  }

  /// Check grey water level against thresholds
  void _checkGreyWaterLevel(double level) {
    // Grey water nearly full (critical)
    if (level > 95.0) {
      if (_canTriggerAlert('water_grey_critical')) {
        _triggerAlert(
          id: _uuid.v4(),
          title: 'Grey Water Critical',
          message: 'Grey water tank at ${level.toStringAsFixed(0)}% - Dump immediately',
          severity: AlertSeverity.error,
          category: AlertCategory.water,
        );
        _lastAlertTime['water_grey_critical'] = DateTime.now();
      }
    }
    // Grey water getting full (warning)
    else if (level > 80.0) {
      if (_canTriggerAlert('water_grey_full')) {
        _triggerAlert(
          id: _uuid.v4(),
          title: 'Grey Water Full',
          message: 'Grey water tank at ${level.toStringAsFixed(0)}% - Dump soon',
          severity: AlertSeverity.warning,
          category: AlertCategory.water,
        );
        _lastAlertTime['water_grey_full'] = DateTime.now();
      }
    }
  }

  /// Handle solar system updates and check thresholds
  void _handleSolarUpdate(Map<String, dynamic> params) {
    if (kDebugMode) {
      print('AlertManagerService: Solar update received: $params');
    }

    // Use output_current (charge current to battery) for alerts
    // Backend spec: output_current, output_voltage, output_power (charge side)
    //               input_current, input_voltage, input_power (PV panel side)
    final current = params['output_current'];
    final voltage = params['output_voltage'];

    if (current != null) {
      final currentValue = (current as num).toDouble();
      if (kDebugMode) {
        print('AlertManagerService: Checking solar current: ${currentValue}A');
        print('   isDaytime: ${_isDaytime()}');
        print('   threshold: ${_preferencesNotifier?.solarCurrentLowWarning}A');
      }
      _checkSolarCurrent(currentValue);
    }

    if (voltage != null) {
      final voltageValue = (voltage as num).toDouble();
      if (kDebugMode) {
        print('AlertManagerService: Checking solar voltage: ${voltageValue}V');
      }
      _checkSolarVoltage(voltageValue);
    }
  }

  /// Check solar current against thresholds
  void _checkSolarCurrent(double current) {
    if (_preferencesNotifier == null) {
      if (kDebugMode) {
        print('AlertManagerService: Cannot check solar current - preferences not initialized');
      }
      return;
    }

    final prefs = _preferencesNotifier!;

    if (kDebugMode) {
      print('AlertManagerService: Solar current check - current: ${current}A, threshold: ${prefs.solarCurrentLowWarning}A');
    }

    // Solar current too high (potential issue)
    if (current > prefs.solarCurrentHighWarning) {
      if (_canTriggerAlert('solar_current_high')) {
        if (kDebugMode) {
          print('AlertManagerService: Triggering solar current HIGH alert');
        }
        _triggerAlert(
          id: _uuid.v4(),
          title: 'Solar Current High',
          message: 'Solar current at ${current.toStringAsFixed(1)}A - Check controller',
          severity: AlertSeverity.warning,
          category: AlertCategory.solar,
        );
        _lastAlertTime['solar_current_high'] = DateTime.now();
      } else {
        if (kDebugMode) {
          print('AlertManagerService: Solar current high alert in cooldown period');
        }
      }
    }
    // Solar current too low (only alert during daytime)
    else if (current < prefs.solarCurrentLowWarning && _isDaytime()) {
      if (_canTriggerAlert('solar_current_low')) {
        if (kDebugMode) {
          print('AlertManagerService: Triggering solar current LOW alert');
        }
        _triggerAlert(
          id: _uuid.v4(),
          title: 'Solar Output Low',
          message: 'Solar current at ${current.toStringAsFixed(1)}A - Check panel position',
          severity: AlertSeverity.warning,
          category: AlertCategory.solar,
        );
        _lastAlertTime['solar_current_low'] = DateTime.now();
      } else {
        if (kDebugMode) {
          print('AlertManagerService: Solar current low alert in cooldown period');
        }
      }
    } else {
      if (kDebugMode) {
        if (!_isDaytime()) {
          print('AlertManagerService: Not daytime - skipping solar alert');
        } else {
          print('AlertManagerService: Solar current within normal range');
        }
      }
    }
  }

  /// Check solar voltage (detect disconnection)
  void _checkSolarVoltage(double voltage) {
    if (kDebugMode) {
      print('AlertManagerService: Checking solar voltage: ${voltage}V, isDaytime: ${_isDaytime()}');
    }
    
    // Solar system disconnected (only alert during daytime to avoid false alarms at night)
    if (voltage == 0 && _isDaytime()) {
      if (_canTriggerAlert('solar_disconnected')) {
        if (kDebugMode) {
          print('AlertManagerService: Triggering solar DISCONNECTED alert');
        }
        _triggerAlert(
          id: _uuid.v4(),
          title: 'Solar Disconnected',
          message: 'Solar system shows no voltage - Check connections',
          severity: AlertSeverity.error,
          category: AlertCategory.solar,
        );
        _lastAlertTime['solar_disconnected'] = DateTime.now();
      } else {
        if (kDebugMode) {
          print('AlertManagerService: Solar disconnected alert in cooldown period');
        }
      }
    }
  }

  /// Handle climate/temperature updates and check thresholds
  void _handleClimateUpdate(Map<String, dynamic> params) {
    final cabinTemp = params['cabin'];
    
    if (cabinTemp != null) {
      _checkCabinTemperature((cabinTemp as num).toDouble());
    }
  }

  /// Check cabin temperature for extreme conditions
  void _checkCabinTemperature(double tempF) {
    // Extreme cold
    if (tempF < 32.0) {
      if (_canTriggerAlert('climate_extreme_cold')) {
        _triggerAlert(
          id: _uuid.v4(),
          title: 'Extreme Cold',
          message: 'Cabin temperature at ${tempF.toStringAsFixed(0)}°F - Risk of freezing',
          severity: AlertSeverity.error,
          category: AlertCategory.climate,
        );
        _lastAlertTime['climate_extreme_cold'] = DateTime.now();
      }
    }
    // Extreme heat
    else if (tempF > 95.0) {
      if (_canTriggerAlert('climate_extreme_heat')) {
        _triggerAlert(
          id: _uuid.v4(),
          title: 'Extreme Heat',
          message: 'Cabin temperature at ${tempF.toStringAsFixed(0)}°F - Check HVAC',
          severity: AlertSeverity.error,
          category: AlertCategory.climate,
        );
        _lastAlertTime['climate_extreme_heat'] = DateTime.now();
      }
    }
  }

  /// Handle backend-generated alerts (catch-all for system-wide issues)
  void _handleBackendAlert(Map<String, dynamic> params) {
    try {
      final alert = AlertItem.fromJson(params);
      
      if (kDebugMode) {
        print('AlertManagerService: Received backend alert: ${alert.title}');
      }

      // Add to dashboard
      _dashboardController?.addAlert(alert);

      // Show push notification for all severities
      _showPushNotification(alert);
    } catch (e) {
      if (kDebugMode) {
        print('AlertManagerService: Error parsing backend alert: $e');
      }
    }
  }

  /// Check if an alert can be triggered (respects cooldown period)
  bool _canTriggerAlert(String alertKey) {
    final lastTime = _lastAlertTime[alertKey];
    if (lastTime == null) return true;

    final cooldown = _getCooldownDuration(alertKey);
    final elapsed = DateTime.now().difference(lastTime);
    
    return elapsed > cooldown;
  }

  /// Get cooldown duration based on alert key
  Duration _getCooldownDuration(String alertKey) {
    if (alertKey.startsWith('battery_')) {
      return _batteryAlertCooldown;
    } else if (alertKey.startsWith('water_')) {
      return _waterAlertCooldown;
    } else if (alertKey.startsWith('solar_')) {
      return _solarAlertCooldown;
    } else if (alertKey.startsWith('climate_')) {
      return _climateAlertCooldown;
    } else {
      return _systemAlertCooldown;
    }
  }

  /// Trigger an alert (add to dashboard + push notification)
  Future<void> _triggerAlert({
    required String id,
    required String title,
    required String message,
    required AlertSeverity severity,
    required AlertCategory category,
  }) async {
    final alert = AlertItem(
      id: id,
      title: title,
      message: message,
      severity: severity,
      category: category,
      timestamp: DateTime.now(),
    );

    if (kDebugMode) {
      print('🔔 AlertManagerService: Triggering alert - $title (${severity.name})');
    }

    // Add to dashboard
    _dashboardController?.addAlert(alert);

    // Show push notification for all severities
    await _showPushNotification(alert);
  }

  /// Show push notification for alert
  Future<void> _showPushNotification(AlertItem alert) async {
    try {
      await _notificationService.showNotification(
        id: alert.id.hashCode, // Use hash of ID for notification ID
        title: alert.title,
        body: alert.message,
        payload: 'alert:${alert.id}',
      );

      if (kDebugMode) {
        print('AlertManagerService: Push notification sent - ${alert.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlertManagerService: Error showing notification: $e');
      }
    }
  }

  /// Dismiss an alert (called by DashboardController)
  void dismissAlert(String alertId) {
    if (kDebugMode) {
      print('AlertManagerService: Alert dismissed - $alertId');
    }
    // V1: No additional action needed (dashboard handles removal)
    // Future: Sync dismissal with backend if needed
  }

  /// Inject test alert for debugging
  Future<void> injectTestAlert(Map<String, dynamic> alertData) async {
    try {
      final alert = AlertItem.fromJson(alertData);
      
      if (kDebugMode) {
        print('🧪 AlertManagerService: Injecting test alert - ${alert.title}');
        print('   DashboardController available: ${_dashboardController != null}');
      }

      // Add to dashboard
      if (_dashboardController != null) {
        _dashboardController!.addAlert(alert);
        if (kDebugMode) {
          print('   ✅ Alert added to dashboard');
        }
      } else {
        if (kDebugMode) {
          print('   ⚠️ No DashboardController registered!');
        }
      }

      // Show push notification for all severities
      await _showPushNotification(alert);
      if (kDebugMode) {
        print('   📱 Push notification sent');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlertManagerService: Error injecting test alert: $e');
      }
      rethrow;
    }
  }

  /// Dispose of resources
  void dispose() {
    _notificationSubscription?.cancel();
    _isInitialized = false;
    
    if (kDebugMode) {
      print('AlertManagerService: Disposed');
    }
  }
}
