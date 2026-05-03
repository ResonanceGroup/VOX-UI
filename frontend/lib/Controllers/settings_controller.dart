import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_preferences_notifier.dart';
import '../models/services/json_rpc_service.dart';
import '../models/communications/connection_manager.dart';

/// Settings Controller - Manages business logic for Settings View
/// Bridges AppPreferencesNotifier with external services (JsonRpc, ConnectionManager)
class SettingsController extends ChangeNotifier {
  final AppPreferencesNotifier _preferencesNotifier;
  final JsonRpcService _jsonRpcService;

  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _networkTransportSubscription;

  SettingsController({
    required AppPreferencesNotifier preferencesNotifier,
    required JsonRpcService jsonRpcService,
  })  : _preferencesNotifier = preferencesNotifier,
        _jsonRpcService = jsonRpcService {
    _initialize();
  }

  /// Initialize controller and set up listeners
  void _initialize() {
    _setupConnectionStatusListener();
    // Defer the initial read until after the first frame so that
    // notifyListeners() on AppPreferencesNotifier isn't called during build.
    Future.microtask(_updateConnectionStatus);
  }

  /// Set up listener for connection status changes
  void _setupConnectionStatusListener() {
    _connectionStateSubscription = _jsonRpcService.connectionStateStream.listen((_) {
      _updateConnectionStatus();
    });
    // Also react to transport label changes (e.g. WiFi ↔ Ethernet while connected).
    _networkTransportSubscription = _jsonRpcService.networkTransportStream.listen((_) {
      _updateConnectionStatus();
    });
  }

  /// Update connection status in settings notifier
  void _updateConnectionStatus() {
    final state = _jsonRpcService.connectionState;
    final isConnected = state == ConnectionManagerState.connected;
    final connectionType = _jsonRpcService.networkTransportLabel;

    final String overallStatus;
    switch (state) {
      case ConnectionManagerState.connected:
        overallStatus = 'Connected';
        break;
      case ConnectionManagerState.reconnecting:
        overallStatus = 'Reconnecting';
        break;
      default:
        overallStatus = 'Disconnected';
    }

    _preferencesNotifier.setConnectionStatus(
      isConnected,
      connectionType,
      overallStatus: overallStatus,
    );
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _networkTransportSubscription?.cancel();
    super.dispose();
  }

  /// Send vehicle diagnostics print command to backend
  /// Returns true if command was sent successfully, false otherwise
  Future<bool> printVehicleDiagnostics() async {
    try {
      // Send the system.print request with hardcoded ID -9998
      final success = await _jsonRpcService.sendPrintDiagnostics();

      if (kDebugMode) {
        if (success) {
          print('SettingsController: Diagnostics print request sent successfully');
        } else {
          print('SettingsController: Failed to send diagnostics print request');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('SettingsController: Error sending diagnostics command: $e');
      }
      return false;
    }
  }
}
