import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'socket_interface.dart';
import 'tcp_socket.dart';
import 'ble_socket.dart';
import '../constants.dart';
import '../services/notification_service.dart';

/// Connection manager that intelligently chooses between TCP and BLE connections
/// based on connectivity testing and provides a unified interface for communication
/// Enumeration of possible connection manager states
enum ConnectionManagerState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class ConnectionManager {
  /// Available transport types
  static const String transportTcp = 'tcp';
  static const String transportBle = 'ble';

  /// Current active transport
  String? _currentTransport;

  /// Current active socket interface
  SocketInterface? _currentSocket;

  /// Socket instances
  TcpSocket? _tcpSocket;
  BleSocket? _bleSocket;

  /// Request ID counter
  int _requestId = 0;

  /// Reserved heartbeat request ID (hardcoded to avoid conflicts)
  static const int heartbeatRequestId = -9999;

  /// Reserved diagnostics request ID (hardcoded to avoid conflicts)
  static const int diagnosticsRequestId = -9998;

  /// Connection state controller
  final StreamController<ConnectionManagerState> _connectionStateController =
      StreamController<ConnectionManagerState>.broadcast();

  /// Transport availability controller
  final StreamController<Map<String, bool>> _transportAvailabilityController =
      StreamController<Map<String, bool>>.broadcast();

  /// Network transport label stream controller ('WiFi', 'Ethernet', 'Bluetooth', 'None')
  final StreamController<String> _networkTransportLabelController =
      StreamController<String>.broadcast();
  String _lastEmittedTransportLabel = '';

  /// Error state controller
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  /// Message stream controller to forward data from active socket
  final StreamController<Uint8List> _messageStreamController =
      StreamController<Uint8List>.broadcast();

  /// Subscription to the active socket's message stream
  StreamSubscription<Uint8List>? _messageStreamSubscription;

  /// Retry timer
  Timer? _retryTimer;
  static const Duration _retryInterval = Duration(minutes: 1);

  /// Connectivity status
  bool _isTcpEnabled = false;
  bool _isBluetoothEnabled = false;
  bool _isTcpReachable = false;
  bool _isBleDeviceFound = false;

  /// Transport priority order (highest to lowest)
  final List<String> _transportPriority = [
    transportTcp, // Prefer TCP when available
    transportBle, // Fallback to BLE
  ];

  // final List<String> _transportPriority = [
  //   transportBle,
  //   transportTcp, // Prefer TCP when available
  // ];

  /// Track if initial scan is complete
  bool _initialScanComplete = false;

  /// Track scan completion by transport
  bool _tcpStatusComplete = false;
  bool _bluetoothScanComplete = false;

  /// ConnectionManager's own state tracking
  ConnectionManagerState _currentState = ConnectionManagerState.disconnected;

  /// Subscription to the active socket's connection state stream
  StreamSubscription<SocketConnectionState>? _socketStateSubscription;

  /// Flag to prevent multiple concurrent reconnection loops
  bool _isReconnecting = false;

  /// Flag to prevent concurrent connection attempts (e.g. duplicate
  /// connectivity-changed events firing at the same time)
  bool _isAttemptingConnection = false;

  /// Defer BLE initialization until Bluetooth is detected
  bool _bleInitialized = false;

  /// Connectivity subscription
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Last known connectivity result
  List<ConnectivityResult> _lastConnectivityResult = [];

  /// Heartbeat mechanism to detect unresponsive backends
  Timer? _heartbeatTimer;
  int _heartbeatFailedAttempts = 0;
  bool _pendingHeartbeatResponse = false;
  static const int _maxHeartbeatFailures = 3;
  static const Duration _heartbeatInterval = Duration(seconds: 15);

  ConnectionManager() {
    if (kDebugMode) {
      print('⚙️ ConnectionManager: Constructing and initializing...');
    }

    // Initialize sockets
    _tcpSocket = TcpSocket();
    _bleSocket = BleSocket();

    if (kDebugMode) {
      print('📡 ConnectionManager: Starting connectivity monitoring...');
    }

    // Start listening to connectivity changes immediately
    _startConnectivityListener();
  }

  /// Start listening to connectivity changes
  void _startConnectivityListener() {
    if (kDebugMode) {
      print('📡 ConnectionManager: Setting up connectivity listener...');
    }

    // Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        if (kDebugMode) {
          print('❌ ConnectionManager: Connectivity listener error: $error');
        }
      },
    );

    // Check initial connectivity state
    _checkInitialConnectivity();
  }

  /// Check initial connectivity state on startup
  Future<void> _checkInitialConnectivity() async {
    if (kDebugMode) {
      print('🔍 ConnectionManager: Checking initial connectivity state...');
    }

    // Debug mode: Skip all connection attempts and set to connected state
    if (AppConstants.isDebugMode) {
      if (kDebugMode) {
        print('🐛 ConnectionManager: Debug mode enabled - skipping connection attempts');
      }
      _currentState = ConnectionManagerState.connected;
      _connectionStateController.add(ConnectionManagerState.connected);
      return;
    }

    try {
      final result = await Connectivity().checkConnectivity();
      await _onConnectivityChanged(result);
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectionManager: Failed to check initial connectivity: $e');
      }
    }
  }

  /// Handle connectivity changes
  Future<void> _onConnectivityChanged(List<ConnectivityResult> result) async {
    // Skip connectivity handling in debug mode
    if (AppConstants.isDebugMode) {
      return;
    }

    if (kDebugMode) {
      print('🌐 ConnectionManager: Connectivity changed: $result');
      print(
        '🔍 ConnectionManager: Previous connectivity: $_lastConnectivityResult',
      );
    }

    // Check if this is a meaningful change
    final hadTcp =
        _lastConnectivityResult.contains(ConnectivityResult.wifi) ||
        _lastConnectivityResult.contains(ConnectivityResult.ethernet);
    final hasTcp =
        result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);

    _lastConnectivityResult = result;
    _isTcpEnabled = hasTcp;

    // Re-emit transport label in case WiFi ↔ Ethernet changed while still connected.
    _emitTransportLabelIfChanged();

    if (kDebugMode) {
      print(
        '📶 ConnectionManager: TCP connectivity: ${hasTcp ? "AVAILABLE" : "UNAVAILABLE"}',
      );
    }

    // Ensure BLE is ready if Bluetooth hardware is detected
    await _ensureBleReady();

    // Handle TCP state changes
    if (!hadTcp && hasTcp) {
      // TCP became available
      if (kDebugMode) {
        print(
          '✅ ConnectionManager: TCP connectivity gained, attempting connection...',
        );
      }
      await _handleTcpAvailable();
    } else if (hadTcp && !hasTcp) {
      // TCP lost
      if (kDebugMode) {
        print('❌ ConnectionManager: TCP connectivity lost');
      }
      await _handleTcpLost();
    } else if (hasTcp && _currentTransport == null) {
      // TCP available and not connected - attempt connection
      if (kDebugMode) {
        print('🔄 ConnectionManager: TCP available, attempting connection...');
      }
      await _handleTcpAvailable();
    } else if (!hasTcp && _currentTransport == null && _bleInitialized) {
      // No TCP, not connected, but BLE is ready - try BLE
      if (kDebugMode) {
        print('🔄 ConnectionManager: No TCP, attempting BLE connection...');
      }
      await _attemptBleConnection();
    }

    // Update transport availability
    _updateTransportAvailability();
  }

  /// Ensure BLE is ready for use - check support and initialize if needed
  Future<bool> _ensureBleReady() async {
    // Skip if already initialized
    if (_bleInitialized) {
      return true;
    }

    if (kDebugMode) {
      print('🔍 ConnectionManager: Checking BLE readiness...');
    }

    // Check Bluetooth support
    await _checkBluetoothSupport();

    if (_isBluetoothEnabled) {
      _bleInitialized = true;
      if (kDebugMode) {
        print('✅ ConnectionManager: BLE initialized and ready');
      }
      return true;
    } else {
      if (kDebugMode) {
        print('⏭️ ConnectionManager: Bluetooth not supported, BLE unavailable');
      }
      return false;
    }
  }

  /// Handle when TCP becomes available
  Future<void> _handleTcpAvailable() async {
    // Test if we can actually reach the dashboard via TCP
    await _testTcpConnectivity();

    // Also scan for BLE so _attemptConnection() has full information
    // before making a priority-based decision
    if (_bleInitialized) {
      await _scanForBleDevices();
    }

    if (!_isTcpReachable && !_isBleDeviceFound) {
      if (kDebugMode) {
        print(
          '⚠️ ConnectionManager: Neither TCP nor BLE is currently reachable',
        );
      }
      return;
    }

    // If already connected, check whether a higher-priority transport has
    // now become available, and switch to it if so
    if (_currentTransport != null) {
      final currentIndex = _transportPriority.indexOf(_currentTransport!);
      bool higherPriorityAvailable = false;
      for (int i = 0; i < currentIndex; i++) {
        if (await _isTransportAvailable(_transportPriority[i])) {
          higherPriorityAvailable = true;
          if (kDebugMode) {
            print(
              '🔄 ConnectionManager: Higher-priority transport (${_transportPriority[i]}) is now available — switching...',
            );
          }
          break;
        }
      }
      if (higherPriorityAvailable) {
        await disconnect();
      } else {
        // Current transport is still the best available — stay on it
        if (kDebugMode) {
          print(
            'ℹ️ ConnectionManager: Already on best available transport ($_currentTransport), no switch needed',
          );
        }
        return;
      }
    }

    // Attempt connection using the configured priority order
    // (e.g. BLE first, then TCP as fallback)
    if (_currentTransport == null) {
      await _attemptConnection();
    }
  }

  /// Handle when TCP is lost
  Future<void> _handleTcpLost() async {
    _isTcpReachable = false;
    _updateTransportAvailability();

    if (_currentTransport == transportTcp) {
      if (kDebugMode) {
        print('⚠️ ConnectionManager: TCP lost while connected — disconnecting and attempting fallback...');
      }
      // Clean disconnect first (clears transport refs)
      await disconnect();
      // Attempt fallback; if all transports fail the user is notified
      await _handleReconnection();
    } else {
      if (kDebugMode) {
        print(
          'ℹ️ ConnectionManager: TCP lost but not currently using TCP (current: $_currentTransport)',
        );
      }
    }
  }

  /// Attempt BLE connection if available
  Future<void> _attemptBleConnection() async {
    if (_isAttemptingConnection) {
      if (kDebugMode) {
        print('⏭️ ConnectionManager: Connection attempt already in progress, skipping duplicate BLE attempt');
      }
      return;
    }
    _isAttemptingConnection = true;
    try {
      // Ensure BLE is ready before attempting connection
      final bleReady = await _ensureBleReady();
      if (!bleReady) {
        if (kDebugMode) {
          print('⏭️ ConnectionManager: BLE not ready, skipping BLE connection');
        }
        return;
      }

      // Scan for BLE devices
      await _scanForBleDevices();

      if (_isBleDeviceFound && _currentTransport == null) {
        try {
          if (kDebugMode) {
            print(
              '🔄 ConnectionManager: BLE device found, attempting connection...',
            );
          }
          await _connectToTransport(transportBle);
        } catch (e) {
          if (kDebugMode) {
            print('❌ ConnectionManager: BLE connection failed: $e');
          }
        }
      }
    } finally {
      _isAttemptingConnection = false;
    }
  }

  /// Check TCP connectivity status (WiFi or Ethernet)
  Future<void> _checkTCPStatus() async {
    if (kDebugMode) {
      print('🌐 ConnectionManager: Checking TCP status...');
    }

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      _isTcpEnabled =
          connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.ethernet);

      // Optional: Check for any connectivity
      bool hasConnectivity = !connectivityResult.contains(
        ConnectivityResult.none,
      );

      if (kDebugMode) {
        print(
          '✅ ConnectionManager: Connectivity check completed - Types: $connectivityResult',
        );
        print(
          '📶 ConnectionManager: TCP status - ${_isTcpEnabled ? "ENABLED" : "DISABLED"}',
        );
        print('🌍 ConnectionManager: Has connectivity - $hasConnectivity');
      }
    } catch (e) {
      _isTcpEnabled = false;
      if (kDebugMode) {
        print('❌ ConnectionManager: Connectivity check failed: $e');
      }
    }

    // Note: Transport availability will be updated after all scans complete
  }

  /// Check Bluetooth status
  Future<void> _checkBluetoothSupport() async {
    if (kDebugMode) {
      print('📱 ConnectionManager: Checking Bluetooth support...');
    }

    try {
      // First we are going to check if bluetooth is supported by the device:
      final isSupported = await FlutterBluePlus.isSupported;

      if (kDebugMode) {
        print(
          '🔍 ConnectionManager: FlutterBluePlus.isSupported = $isSupported',
        );
      }

      if (isSupported == true) {
        _isBluetoothEnabled = true; // Bluetooth is supported
        if (kDebugMode) {
          print('✅ ConnectionManager: Bluetooth is supported by device');
        }
      } else {
        _isBluetoothEnabled = false;
        if (kDebugMode) {
          print('❌ ConnectionManager: Bluetooth is NOT supported by device');
        }
      }
    } catch (e) {
      _isBluetoothEnabled = false;
      if (kDebugMode) {
        print('❌ ConnectionManager: Error checking Bluetooth support: $e');
      }
    }

    if (kDebugMode) {
      print(
        '📡 ConnectionManager: Bluetooth support - ${_isBluetoothEnabled ? "ENABLED" : "DISABLED"}',
      );
    }
    // Note: Transport availability will be updated after all scans complete
  }

  /// Test TCP connectivity by checking device availability
  Future<void> _testTcpConnectivity() async {
    if (kDebugMode) {
      print('🌐 ConnectionManager: Testing TCP connectivity...');
    }

    if (!_isTcpEnabled) {
      _isTcpReachable = false;
      if (kDebugMode) {
        print('❌ ConnectionManager: TCP not enabled, skipping TCP test');
      }
      // Note: Transport availability will be updated after all scans complete
      return;
    }

    try {
      if (kDebugMode) {
        print(
          '🔍 ConnectionManager: Checking availability of TCP device: ${AppConstants.dashboardHost}',
        );
      }

      // Use TcpSocket's checkDeviceAvailability method
      _isTcpReachable = await _tcpSocket!.checkDeviceAvailability(
        AppConstants.dashboardHost,
      );

      if (kDebugMode) {
        print(
          '✅ ConnectionManager: TCP device availability check completed - ${_isTcpReachable ? "AVAILABLE" : "NOT AVAILABLE"}',
        );
      }
    } catch (e) {
      _isTcpReachable = false;
      if (kDebugMode) {
        print('❌ ConnectionManager: TCP device availability check error: $e');
      }
    }

    if (kDebugMode) {
      print(
        '🔗 ConnectionManager: TCP connectivity to ${AppConstants.dashboardHost} - ${_isTcpReachable ? "REACHABLE" : "UNREACHABLE"}',
      );
    }
    // Note: Transport availability will be updated after all scans complete
  }

  /// Scan for BLE devices
  Future<void> _scanForBleDevices() async {
    if (kDebugMode) {
      print('📡 ConnectionManager: Starting BLE device scan...');
      print('🔍 ConnectionManager: _bleSocket is null: ${_bleSocket == null}');
      print('🔍 ConnectionManager: _isBluetoothEnabled: $_isBluetoothEnabled');
    }

    if (!_isBluetoothEnabled) {
      _isBleDeviceFound = false;
      if (kDebugMode) {
        print('❌ ConnectionManager: Bluetooth not enabled, skipping BLE scan');
      }
      // Note: Transport availability will be updated after all scans complete
      return;
    }

    // Check if BLE socket is initialized
    if (_bleSocket == null) {
      if (kDebugMode) {
        print('❌ ConnectionManager: BLE socket not initialized, cannot scan');
      }
      _isBleDeviceFound = false;
      _isBluetoothEnabled = false;
      _updateTransportAvailability();
      return;
    }

    try {
      if (kDebugMode) {
        print(
          '🎧 ConnectionManager: Setting up Bluetooth adapter state listener...',
        );
      }
      // TODO: In this function, we should call the socket to do the checking
      bool deviceFound = await _bleSocket!.checkDeviceAvailability(
        AppConstants.primaryBleDeviceName,
        AppConstants.deviceUUID,
      );

      if (deviceFound) {
        _isBleDeviceFound = true;
        if (kDebugMode) {
          print('✅ ConnectionManager: BLE device found');
        }
      } else {
        _isBleDeviceFound = false;
        if (kDebugMode) {
          print('❌ ConnectionManager: BLE device NOT found');
        }
      }
    } catch (e) {
      // If there are any errors we should assume that the bluetooth is not available
      _isBleDeviceFound = false;
      _isBluetoothEnabled = false;
      if (kDebugMode) {
        print('❌ ConnectionManager: BLE scan failed with error: $e');
      }
    }

    // Update transport availability now that BLE scan is complete
    _updateTransportAvailability();
  }

  /// Update transport availability based on current conditions
  void _updateTransportAvailability() {
    final availability = {
      transportTcp: _isTcpEnabled && _isTcpReachable,
      transportBle: _isBluetoothEnabled && _isBleDeviceFound,
    };

    if (kDebugMode) {
      print('📊 ConnectionManager: Transport availability update:');
      print('   • TCP enabled: $_isTcpEnabled');
      print('   • TCP reachable: $_isTcpReachable');
      print('   • Bluetooth enabled: $_isBluetoothEnabled');
      print('   • BLE device found: $_isBleDeviceFound');
      print('   • TCP available: ${availability[transportTcp]}');
      print('   • BLE available: ${availability[transportBle]}');
    }

    _transportAvailabilityController.add(availability);

    // Note: Auto-connection is now handled by _attemptInitialConnection()
    // after all transport scanning is complete, not here during scanning
  }

  /// Start the retry timer
  void _startRetryTimer() {
    _retryTimer = Timer.periodic(_retryInterval, (_) {
      if (_currentTransport == null) {
        _attemptConnection();
      }
    });
  }

  /// Attempt to connect using the best available transport
  Future<void> _attemptConnection() async {
    if (_isAttemptingConnection) {
      if (kDebugMode) {
        print('⏭️ ConnectionManager: Connection attempt already in progress, skipping duplicate attempt');
      }
      return;
    }
    _isAttemptingConnection = true;
    try {
    if (kDebugMode) {
      print('🔄 ConnectionManager: Attempting connection...');
      print(
        '📋 ConnectionManager: Transport priority order: $_transportPriority',
      );
    }

    for (final transport in _transportPriority) {
      if (kDebugMode) {
        print('🔍 ConnectionManager: Checking transport: $transport');
      }

      if (await _isTransportAvailable(transport)) {
        try {
          if (kDebugMode) {
            print('🚀 ConnectionManager: Trying to connect via $transport...');
          }
          await _connectToTransport(transport);
          if (kDebugMode) {
            print('✅ ConnectionManager: Successfully connected via $transport');
          }
          break;
        } catch (e) {
          // Try next transport if this one fails
          if (kDebugMode) {
            print('❌ ConnectionManager: Failed to connect to $transport: $e');
          }
          _errorController.add('Failed to connect to $transport: $e');
          continue;
        }
      } else {
        if (kDebugMode) {
          print('❌ ConnectionManager: Transport $transport is not available');
        }
      }
    }

    // If no transport succeeded, update state to error
    if (_currentTransport == null) {
      if (kDebugMode) {
        print(
          '💥 ConnectionManager: No transport available for connection - all attempts failed',
        );
      }
      _connectionStateController.add(ConnectionManagerState.reconnecting);
      _errorController.add('No available transport could establish connection');
    }
    } finally {
      _isAttemptingConnection = false;
    }
  }

  /// Check if a transport is available
  Future<bool> _isTransportAvailable(String transport) async {
    switch (transport) {
      case transportTcp:
        return _isTcpEnabled && _isTcpReachable;
      case transportBle:
        return _isBluetoothEnabled && _isBleDeviceFound;
      default:
        return false;
    }
  }

  /// Connect to a specific transport
  Future<void> _connectToTransport(String transport) async {
    if (kDebugMode) {
      print('🔌 ConnectionManager: Connecting to transport: $transport');
    }
    SocketInterface? socket;

    switch (transport) {
      case transportTcp:
        socket = _tcpSocket;
        if (kDebugMode) {
          print('🌐 ConnectionManager: Using TCP socket');
        }
        break;
      case transportBle:
        socket = _bleSocket;
        if (kDebugMode) {
          print('📱 ConnectionManager: Using BLE socket');
        }
        break;
      default:
        if (kDebugMode) {
          print('❌ ConnectionManager: Unsupported transport: $transport');
        }
        throw UnsupportedError('Unsupported transport: $transport');
    }

    if (socket == null) {
      if (kDebugMode) {
        print(
          '❌ ConnectionManager: Socket not initialized for transport: $transport',
        );
      }
      throw StateError('Socket not initialized for transport: $transport');
    }

    try {
      if (kDebugMode) {
        print('⚙️ ConnectionManager: Configuring socket for $transport...');
      }

      // Configure the socket
      final config = _getTransportConfig(transport);
      socket.setConfig(config);

      if (kDebugMode) {
        print('🔗 ConnectionManager: Attempting socket connection...');
      }

      // Connect
      await socket.connect();

      // Update current transport
      _currentTransport = transport;
      _currentSocket = socket;

      // Set up listener for socket state changes
      _listenToSocketState(socket);

      // Update state and notify listeners
      _currentState = ConnectionManagerState.connected;
      _connectionStateController.add(ConnectionManagerState.connected);

      // Emit updated transport label (TCP vs BLE may have changed).
      _emitTransportLabelIfChanged();

      // Update transport availability to reflect current connection
      _updateTransportAvailability();

      // Start heartbeat to monitor backend responsiveness
      _startHeartbeat();

      if (kDebugMode) {
        print('🎉 ConnectionManager: Successfully connected to $transport');
        print('📡 ConnectionManager: Current transport: $_currentTransport');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectionManager: Connection to $transport failed: $e');
      }
      rethrow;
    }
  }

  /// Get configuration for a specific transport
  Map<String, dynamic> _getTransportConfig(String transport) {
    switch (transport) {
      case transportTcp:
        return {
          'host': AppConstants.dashboardHost,
          'port': AppConstants.dashboardPort,
          'timeout': AppConstants.tcpConnectionTimeout,
          'maxRetries': AppConstants.tcpMaxRetries,
          'retryDelay': AppConstants.tcpRetryDelay,
        };
      case transportBle:
        return {
          'deviceName': AppConstants.primaryBleDeviceName,
          'serviceUUID': AppConstants.primaryServiceUUID,
          'txCharacteristicUUID': AppConstants.primaryTxCharacteristicUUID,
          'rxCharacteristicUUID': AppConstants.primaryRxCharacteristicUUID,
          'scanTimeout': AppConstants.bleTimeout,
        };
      default:
        return {};
    }
  }

  /// Subscribe to the socket's connection state stream and handle state transitions
  void _listenToSocketState(SocketInterface socket) {
    // Cancel any existing subscription
    _socketStateSubscription?.cancel();

    // Reset the reconnection flag when we start listening to a new socket
    _isReconnecting = false;

    // Subscribe to the socket's connection state stream
    _socketStateSubscription = socket.connectionStateStream.listen((newState) {
      if (kDebugMode) {
        print('🔄 ConnectionManager: Socket state changed to: $newState');
      }

      // Map SocketConnectionState to ConnectionManagerState
      ConnectionManagerState managerState;
      switch (newState) {
        case SocketConnectionState.disconnected:
          managerState = ConnectionManagerState.disconnected;
          break;
        case SocketConnectionState.connecting:
          managerState = ConnectionManagerState.connecting;
          break;
        case SocketConnectionState.connected:
          managerState = ConnectionManagerState.connected;
          break;
        case SocketConnectionState.reconnecting:
          managerState = ConnectionManagerState.reconnecting;
          break;
        case SocketConnectionState.error:
          managerState = ConnectionManagerState.error;
          break;
      }

      // Any loss-of-connection while we believe we are connected should
      // trigger a fallback attempt (and ultimately a push notification if
      // all transports fail).  We treat both graceful disconnection AND
      // socket errors the same way.
      final wasConnected =
          _currentState == ConnectionManagerState.connected;
      final isLoss =
          managerState == ConnectionManagerState.disconnected ||
          managerState == ConnectionManagerState.error;

      if (wasConnected && isLoss) {
        if (kDebugMode) {
          print(
            '💔 ConnectionManager: Connection lost ($managerState) — initiating fallback...',
          );
        }
        // Cancel the subscription synchronously before the async handoff so
        // that further socket events don't trigger a second reconnection.
        _socketStateSubscription?.cancel();
        _socketStateSubscription = null;
        _messageStreamSubscription?.cancel();
        _messageStreamSubscription = null;
        _currentTransport = null;
        _currentSocket = null;
        _isAttemptingConnection = false;
        _handleReconnection();
      } else {
        // For all other state changes, update our internal state and notify listeners
        _currentState = managerState;
        _connectionStateController.add(managerState);

        // If the socket errored outside of a "was connected" transition
        // (e.g. during an in-progress reconnect attempt), clear stale refs
        // so the reconnect button is never blocked.
        if (managerState == ConnectionManagerState.error) {
          _socketStateSubscription?.cancel();
          _socketStateSubscription = null;
          _messageStreamSubscription?.cancel();
          _messageStreamSubscription = null;
          _currentTransport = null;
          _currentSocket = null;
          _isAttemptingConnection = false;
        }
      }
    });

    // Start listening to messages from the socket
    _startListeningToMessages(socket);
  }

  /// Start forwarding messages from the active socket to our broadcast stream
  void _startListeningToMessages(SocketInterface socket) {
    // Cancel any existing message subscription
    _messageStreamSubscription?.cancel();

    if (kDebugMode) {
      print('📨 ConnectionManager: Starting to listen to socket messages...');
    }

    // Subscribe to the socket's message stream
    _messageStreamSubscription = socket.messageStream.listen(
      (data) {
        if (kDebugMode) {
          print(
            '📥 ConnectionManager: Received ${data.length} bytes from $_currentTransport',
          );
        }
        // Forward the data to our broadcast stream
        _messageStreamController.add(data);
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ ConnectionManager: Message stream error: $error');
        }
        _errorController.add('Message stream error: $error');
      },
      onDone: () {
        if (kDebugMode) {
          print('🔚 ConnectionManager: Message stream closed');
        }
      },
    );
  }

  /// Handle reconnection when a disconnection is detected.
  ///
  /// Strategy:
  ///   1. Re-scan all transports to see what is currently reachable.
  ///   2. Attempt connection via priority order (TCP → BLE).
  ///   3. If a transport succeeds → done.
  ///   4. If all transports fail → set state to disconnected, send a push
  ///      notification telling the user to tap the reconnect button.
  ///
  /// No automatic retry loop — the user must press the reconnect button.
  Future<void> _handleReconnection() async {
    if (AppConstants.isDebugMode) return;

    if (_isReconnecting) {
      if (kDebugMode) {
        print('⏭️ ConnectionManager: Reconnection already in progress, skipping...');
      }
      return;
    }

    _isReconnecting = true;

    // Clear any stale transport/subscription refs
    _currentTransport = null;
    _currentSocket = null;
    _isAttemptingConnection = false; // allow _attemptConnection() to run
    _socketStateSubscription?.cancel();
    _socketStateSubscription = null;
    _messageStreamSubscription?.cancel();
    _messageStreamSubscription = null;

    // Signal UI that a reconnect is in progress
    _currentState = ConnectionManagerState.reconnecting;
    _connectionStateController.add(ConnectionManagerState.reconnecting);

    if (kDebugMode) {
      print('🔄 ConnectionManager: Scanning transports and attempting fallback...');
    }

    try {
      // Re-probe both transports so _attemptConnection() has fresh data
      await _testTcpConnectivity();            // updates _isTcpReachable
      if (_bleInitialized) await _scanForBleDevices(); // updates _isBleDeviceFound

      // Try TCP first, then BLE (priority order)
      await _attemptConnection();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ ConnectionManager: Exception during fallback attempt: $e');
      }
    }

    if (_currentTransport != null) {
      // _attemptConnection already emitted connected state
      if (kDebugMode) {
        print('🎉 ConnectionManager: Fallback succeeded via $_currentTransport');
      }
      _isReconnecting = false;
      return;
    }

    // All transports failed — go to disconnected and alert the user
    if (kDebugMode) {
      print('💥 ConnectionManager: All transports failed — notifying user');
    }
    _currentState = ConnectionManagerState.disconnected;
    _connectionStateController.add(ConnectionManagerState.disconnected);
    _isReconnecting = false;

    try {
      await NotificationService().showNotification(
        id: 9001, // fixed ID so repeated failures replace rather than stack
        title: 'RV Connection Lost',
        body: 'Unable to reach the RV system. Open the app and tap the reconnect button to try again.',
        payload: 'connection_lost',
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ ConnectionManager: Failed to send connection-lost notification: $e');
      }
    }
  }

  /// Manually request a reconnection attempt (triggered by the user tapping
  /// the reconnect button in the UI).
  ///
  /// No-op if already connected or actively connecting.
  /// Runs the same single-attempt fallback as an automatic reconnection, and
  /// sends a push notification if all transports fail again.
  Future<void> reconnect() async {
    if (_currentState == ConnectionManagerState.connected ||
        _currentState == ConnectionManagerState.connecting ||
        _currentState == ConnectionManagerState.reconnecting) {
      if (kDebugMode) {
        print('⏭️ ConnectionManager: reconnect() ignored – already connected/connecting/reconnecting');
      }
      return;
    }

    if (kDebugMode) {
      print('🔄 ConnectionManager: Manual reconnect triggered by user');
    }

    if (AppConstants.isDebugMode) {
      _currentState = ConnectionManagerState.connected;
      _connectionStateController.add(ConnectionManagerState.connected);
      return;
    }

    // Reset flag so _handleReconnection() isn't blocked by a stale guard
    _isReconnecting = false;
    await _handleReconnection();
  }

  /// Disconnect from current transport
  Future<void> disconnect() async {
    if (kDebugMode) {
      print('🔌 ConnectionManager: Disconnecting from $_currentTransport');
    }

    // Stop heartbeat monitoring
    _stopHeartbeat();

    // Handle debug mode disconnect
    if (AppConstants.isDebugMode) {
      _currentState = ConnectionManagerState.disconnected;
      _connectionStateController.add(ConnectionManagerState.disconnected);
      if (kDebugMode) {
        print('🐛 ConnectionManager: Debug mode disconnect completed');
      }
      return;
    }

    // Cancel the socket state subscription
    _socketStateSubscription?.cancel();
    _socketStateSubscription = null;

    // Cancel the message stream subscription
    _messageStreamSubscription?.cancel();
    _messageStreamSubscription = null;

    if (_currentSocket != null) {
      if (kDebugMode) {
        print('🔗 ConnectionManager: Closing socket connection...');
      }
      await _currentSocket!.disconnect();
      _currentSocket = null;
    }

    _currentTransport = null;
    _isAttemptingConnection = false; // clear so next attempt isn't blocked
    _currentState = ConnectionManagerState.disconnected;
    _connectionStateController.add(ConnectionManagerState.disconnected);

    // Update transport availability to reflect disconnection
    _updateTransportAvailability();

    if (kDebugMode) {
      print('✅ ConnectionManager: Disconnection completed');
    }
  }


  /// Send raw JSON-RPC request
  Future<Map<String, dynamic>> sendRequest(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    // In debug mode, pretend request was sent successfully
    if (AppConstants.isDebugMode) {
      if (kDebugMode) {
        print('🐛 ConnectionManager: Debug mode - simulating request: $method');
      }
      return {};
    }

    if (_currentSocket == null) {
      if (kDebugMode) {
        print(
          '❌ ConnectionManager: Cannot send request - no active connection',
        );
      }
      throw StateError('No active connection');
    }

    if (kDebugMode) {
      print(
        '📤 ConnectionManager: Sending JSON-RPC request via $_currentTransport',
      );
      print('   • Method: $method');
      print('   • Params: $params');
    }

    try {
      final requestId = ++_requestId;

      // Format JSON-RPC message in ConnectionManager
      final Map<String, dynamic> jsonRpcRequest = {
        'jsonrpc': '2.0',
        'method': method,
        'id': requestId,
      };
      
      if (params != null) {
        jsonRpcRequest['params'] = params;
      }
      
      // Encode to JSON and convert to bytes
      final jsonString = jsonEncode(jsonRpcRequest);
      final data = Uint8List.fromList(utf8.encode('$jsonString\n'));
      
      // Send raw bytes through socket
      await _currentSocket!.sendData(data);

      if (kDebugMode) {
        print('✅ ConnectionManager: Request sent successfully');
      }

      // Note: For now, we'll return an empty response since we don't have response handling
      // In a full implementation, you'd track pending requests and match responses
      return {};
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectionManager: Request failed: $e');
      }
      rethrow;
    }
  }

  /// Send print diagnostics request to backend
  Future<bool> sendPrintDiagnostics() async {
    // In debug mode, pretend request was sent successfully
    if (AppConstants.isDebugMode) {
      if (kDebugMode) {
        print('🐛 ConnectionManager: Debug mode - simulating diagnostics print request');
      }
      return true;
    }

    if (_currentSocket == null || !isConnected) {
      if (kDebugMode) {
        print('❌ ConnectionManager: Cannot send diagnostics - not connected');
      }
      return false;
    }

    try {
      final Map<String, dynamic> diagnosticsRequest = {
        'jsonrpc': '2.0',
        'method': 'system.print',
        'id': diagnosticsRequestId,
      };

      final jsonString = jsonEncode(diagnosticsRequest);
      final data = Uint8List.fromList(utf8.encode('$jsonString\n'));
      
      await _currentSocket!.sendData(data);

      if (kDebugMode) {
        print('📄 ConnectionManager: Print diagnostics request sent (id: $diagnosticsRequestId)');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectionManager: Failed to send diagnostics request: $e');
      }
      return false;
    }
  }

  /// Send raw JSON-RPC notification
  Future<void> sendNotification(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    // In debug mode, pretend notification was sent successfully
    if (AppConstants.isDebugMode) {
      if (kDebugMode) {
        print('🐛 ConnectionManager: Debug mode - simulating notification: $method');
      }
      return;
    }

    if (_currentSocket == null) {
      if (kDebugMode) {
        print(
          '❌ ConnectionManager: Cannot send notification - no active connection',
        );
      }
      throw StateError('No active connection');
    }

    if (kDebugMode) {
      print(
        '📣 ConnectionManager: Sending JSON-RPC notification via $_currentTransport',
      );
      print('   • Method: $method');
      print('   • Params: $params');
    }

    try {
      // Format JSON-RPC message in ConnectionManager (no ID for notifications)
      final Map<String, dynamic> jsonRpcRequest = {
        'jsonrpc': '2.0',
        'method': method,
      };
      
      if (params != null) {
        jsonRpcRequest['params'] = params;
      }
      
      // Encode to JSON and convert to bytes
      final jsonString = jsonEncode(jsonRpcRequest);
      final data = Uint8List.fromList(utf8.encode('$jsonString\n'));
      
      // Send raw bytes through socket
      await _currentSocket!.sendData(data);
      
      if (kDebugMode) {
        print('✅ ConnectionManager: Notification sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectionManager: Notification failed: $e');
      }
      rethrow;
    }
  }

  /// Get current connection state (for backward compatibility with SocketConnectionState)
  SocketConnectionState get connectionState {
    // Map ConnectionManagerState to SocketConnectionState for backward compatibility
    switch (_currentState) {
      case ConnectionManagerState.disconnected:
        return SocketConnectionState.disconnected;
      case ConnectionManagerState.connecting:
        return SocketConnectionState.connecting;
      case ConnectionManagerState.connected:
        return SocketConnectionState.connected;
      case ConnectionManagerState.reconnecting:
        return SocketConnectionState.reconnecting;
      case ConnectionManagerState.error:
        return SocketConnectionState.error;
    }
  }

  /// Get current connection manager state
  ConnectionManagerState get currentState => _currentState;

  /// Get current transport type
  String? get currentTransport => _currentTransport;

  /// Stream of incoming messages from the active transport
  /// Emits raw binary data (Uint8List) that should be decoded by JSON-RPC layer
  Stream<Uint8List> get messageStream => _messageStreamController.stream;

  /// Check if connected
  bool get isConnected => _currentSocket?.isConnected ?? false;

  /// Check if TCP is enabled
  bool get isTcpEnabled => _isTcpEnabled;

  /// Human-readable connection type label for display in the Settings view.
  ///
  /// Returns 'WiFi', 'Ethernet', 'Bluetooth', or 'None'.
  String get networkTransportLabel {
    if (_currentTransport == transportBle) return 'Bluetooth';
    if (_currentTransport == transportTcp) {
      if (_lastConnectivityResult.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      }
      return 'WiFi';
    }
    // Debug mode: report "WiFi" so the UI shows something useful.
    if (AppConstants.isDebugMode && kDebugMode) return 'WiFi';
    return 'None';
  }

  /// Check if Bluetooth is enabled
  bool get isBluetoothEnabled => _isBluetoothEnabled;

  /// Check if TCP is reachable
  bool get isTcpReachable => _isTcpReachable;

  /// Check if BLE device is found
  bool get isBleDeviceFound => _isBleDeviceFound;

  /// Stream of connection state changes
  Stream<ConnectionManagerState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Stream of transport availability changes
  Stream<Map<String, bool>> get transportAvailabilityStream =>
      _transportAvailabilityController.stream;

  /// Stream of errors
  Stream<String> get errorStream => _errorController.stream;

  /// Stream of network transport label changes ('WiFi', 'Ethernet', 'Bluetooth', 'None')
  Stream<String> get networkTransportStream =>
      _networkTransportLabelController.stream;

  /// Emit networkTransportLabel on the stream only when the label has actually changed.
  void _emitTransportLabelIfChanged() {
    final label = networkTransportLabel;
    if (label != _lastEmittedTransportLabel) {
      _lastEmittedTransportLabel = label;
      if (!_networkTransportLabelController.isClosed) {
        _networkTransportLabelController.add(label);
      }
    }
  }

  // === Heartbeat Mechanism ===

  /// Start heartbeat timer to detect unresponsive backends
  void _startHeartbeat() {
    // Don't start heartbeat in debug mode
    if (AppConstants.isDebugMode) {
      return;
    }

    // Cancel any existing heartbeat timer
    _stopHeartbeat();

    if (kDebugMode) {
      print('💓 ConnectionManager: Starting heartbeat (${_heartbeatInterval.inSeconds}s interval)');
    }

    // Reset failure counter
    _heartbeatFailedAttempts = 0;

    // Send first heartbeat immediately
    _sendHeartbeat();

    // Start periodic heartbeat
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    if (_heartbeatTimer != null) {
      if (kDebugMode) {
        print('💓 ConnectionManager: Stopping heartbeat');
      }
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _pendingHeartbeatResponse = false;
      _heartbeatFailedAttempts = 0;
    }
  }

  /// Send heartbeat ping to backend
  void _sendHeartbeat() async {
    if (_currentSocket == null || !isConnected) {
      if (kDebugMode) {
        print('💓 ConnectionManager: Skipping heartbeat - not connected');
      }
      return;
    }

    // If there's a pending heartbeat that hasn't been responded to
    if (_pendingHeartbeatResponse) {
      _heartbeatFailedAttempts++;
      
      if (kDebugMode) {
        print('💔 ConnectionManager: Heartbeat timeout (attempt $_heartbeatFailedAttempts/$_maxHeartbeatFailures)');
      }

      // Check if we've exceeded max failures
      if (_heartbeatFailedAttempts >= _maxHeartbeatFailures) {
        if (kDebugMode) {
          print('❌ ConnectionManager: Backend unresponsive - max heartbeat failures reached');
        }
        
        // Stop heartbeat and trigger reconnection
        _stopHeartbeat();
        _handleUnresponsiveBackend();
        return;
      }
    }

    try {
      _pendingHeartbeatResponse = true;

      final Map<String, dynamic> heartbeatRequest = {
        'jsonrpc': '2.0',
        'method': 'system.ping',
        'id': heartbeatRequestId,
      };

      final jsonString = jsonEncode(heartbeatRequest);
      final data = Uint8List.fromList(utf8.encode('$jsonString\n'));
      
      await _currentSocket!.sendData(data);

      if (kDebugMode) {
        print('💓 ConnectionManager: Heartbeat sent (id: $heartbeatRequestId)');
      }

      // Set a timeout to mark as failed if no response comes
      Timer(const Duration(seconds: 10), () {
        if (_pendingHeartbeatResponse) {
          if (kDebugMode) {
            print('⏱️ ConnectionManager: Heartbeat timeout for id: $heartbeatRequestId');
          }
          // Will be handled on next heartbeat interval
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectionManager: Failed to send heartbeat: $e');
      }
      _heartbeatFailedAttempts++;
    }
  }

  /// Handle heartbeat response (call this from message processing layer)
  void handleHeartbeatResponse(int responseId) {
    if (responseId == heartbeatRequestId) {
      if (kDebugMode) {
        print('💚 ConnectionManager: Heartbeat acknowledged (id: $responseId)');
      }
      
      _pendingHeartbeatResponse = false;
      _heartbeatFailedAttempts = 0;
    }
  }

  /// Handle unresponsive backend
  void _handleUnresponsiveBackend() {
    if (kDebugMode) {
      print('🔄 ConnectionManager: Backend unresponsive - forcing disconnect and reconnect');
    }

    // Disconnect and attempt reconnection
    disconnect();
    
    // Notify that backend became unresponsive
    if (!_errorController.isClosed) {
      _errorController.add('Backend unresponsive - reconnecting');
    }

    // Trigger reconnection after a short delay
    Timer(const Duration(seconds: 2), () {
      if (kDebugMode) {
        print('🔄 ConnectionManager: Attempting reconnection after backend timeout');
      }
      reconnect();
    });
  }

  /// Dispose of resources
  void dispose() {
    if (kDebugMode) {
      print('ConnectionManager: Disposing resources...');
    }
    _stopHeartbeat();
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _socketStateSubscription?.cancel();
    _messageStreamSubscription?.cancel();
    disconnect();
    _connectionStateController.close();
    _transportAvailabilityController.close();
    _networkTransportLabelController.close();
    _errorController.close();
    _messageStreamController.close();
  }
}
