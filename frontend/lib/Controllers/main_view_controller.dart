import 'package:flutter/foundation.dart';
import '../models/services/json_rpc_service.dart';
import '../models/communications/connection_manager.dart';
import 'dart:async';

/// Controller for MainView - manages app-level state
/// Handles connection status, notifications, and system-level updates
class MainViewController extends ChangeNotifier {
  final JsonRpcService _jsonRpcService;

  // Connection state
  ConnectionManagerState _connectionState = ConnectionManagerState.disconnected;
  ConnectionManagerState get connectionState => _connectionState;

  bool get isConnected => _connectionState == ConnectionManagerState.connected;
  bool get isConnecting => _connectionState == ConnectionManagerState.connecting;
  bool get isDisconnected =>
      _connectionState == ConnectionManagerState.disconnected ||
      _connectionState == ConnectionManagerState.error;

  // Connection type (for displaying appropriate icon)
  String _connectionType = 'none'; // 'ble', 'wifi', or 'none'
  String get connectionType => _connectionType;

  // Notification badge count (for future notifications feature)
  int _notificationCount = 0;
  int get notificationCount => _notificationCount;

  // System status message
  String _statusMessage = 'Not connected';
  String get statusMessage => _statusMessage;

  // Stream subscriptions
  StreamSubscription<ConnectionManagerState>? _connectionStateSubscription;
  StreamSubscription<String>? _errorSubscription;

  MainViewController({
    required JsonRpcService jsonRpcService,
  }) : _jsonRpcService = jsonRpcService {
    _initialize();
  }

  /// Initialize controller and set up listeners
  void _initialize() {
    if (kDebugMode) {
      print('🎮 MainViewController: Initializing');
    }

    // Ensure JsonRpcService is initialized
    _jsonRpcService.initialize();

    // Listen to connection state changes
    _connectionStateSubscription = _jsonRpcService.connectionStateStream.listen(
      _onConnectionStateChanged,
    );

    // Listen to errors
    _errorSubscription = _jsonRpcService.errorStream.listen(
      _onError,
    );

    // Get initial connection state
    _updateConnectionState(_jsonRpcService.connectionState);
  }

  /// Handle connection state changes
  void _onConnectionStateChanged(ConnectionManagerState state) {
    if (kDebugMode) {
      print('🎮 MainViewController: Connection state changed to $state');
    }
    _updateConnectionState(state);
  }

  /// Update connection state and related properties
  void _updateConnectionState(ConnectionManagerState state) {
    _connectionState = state;

    // Determine connection type based on state
    // TODO: Get actual connection type from ConnectionManager (BLE vs TCP)
    final currentTransport = _jsonRpcService.currentTransport;
    
    switch (state) {
      case ConnectionManagerState.connected:
        // Determine if BLE or WiFi based on transport
        if (currentTransport != null) {
          _connectionType = currentTransport.toLowerCase().contains('ble') ? 'ble' : 'wifi';
          _statusMessage = 'Connected via ${_connectionType.toUpperCase()}';
        } else {
          _connectionType = 'ble'; // Default assumption
          _statusMessage = 'Connected';
        }
        break;
      case ConnectionManagerState.connecting:
      case ConnectionManagerState.reconnecting:
        _connectionType = 'connecting';
        _statusMessage = 'Connecting...';
        break;
      case ConnectionManagerState.disconnected:
        _connectionType = 'none';
        _statusMessage = 'Not connected';
        break;
      default:
        _connectionType = 'none';
        _statusMessage = 'Unknown state';
        break;
    }

    notifyListeners();
  }

  /// Handle errors
  void _onError(String error) {
    if (kDebugMode) {
      print('❌ MainViewController: Error - $error');
    }
    _statusMessage = 'Error: $error';
    notifyListeners();
  }

  /// Manually trigger reconnection to the backend.
  /// No-op if already connected or actively connecting.
  Future<void> reconnect() async {
    if (kDebugMode) {
      print('🎮 MainViewController: Manual reconnect triggered by user');
    }
    await _jsonRpcService.reconnect();
  }

  /// Update notification count (for future use)
  void setNotificationCount(int count) {
    if (_notificationCount != count) {
      _notificationCount = count;
      notifyListeners();
    }
  }

  /// Increment notification count
  void incrementNotificationCount() {
    _notificationCount++;
    notifyListeners();
  }

  /// Clear all notifications
  void clearNotifications() {
    if (_notificationCount > 0) {
      _notificationCount = 0;
      notifyListeners();
    }
  }

  // Navigation request — index into the full _allDestinations list
  int? _requestedNavIndex;
  int? get requestedNavIndex => _requestedNavIndex;

  /// Request navigation to a destination by its index in _allDestinations.
  void navigateTo(int destinationIndex) {
    _requestedNavIndex = destinationIndex;
    notifyListeners();
  }

  /// Clear the pending navigation request after it has been consumed.
  void clearNavRequest() {
    _requestedNavIndex = null;
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('🎮 MainViewController: Disposing');
    }
    _connectionStateSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }
}
