import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'socket_interface.dart';
import '../constants.dart';
import '../../permissions_helper.dart';

/// BLE Socket implementation with integrated connection management
/// Combines low-level BLE operations with lifecycle management
class BleSocket implements SocketInterface {
  // === BLE Resources ===
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;

  // === Device Configuration ===
  String? _targetDeviceName;
  Guid? _serviceUuid;
  Guid? _txCharacteristicUuid;
  Guid? _rxCharacteristicUuid;

  // === Stream Controllers ===
  late StreamController<SocketConnectionState> _connectionStateController;
  late StreamController<Uint8List> _messageController;

  // === Stream Subscriptions ===
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _rxDataSubscription;

  // === Configuration ===
  late Map<String, dynamic> _config;
  late SocketConnectionState _connectionState;

  // === Current BLE connection state ===
  BluetoothConnectionState _currentBleConnectionState = BluetoothConnectionState.disconnected;

  // === Reconnection State ===
  bool _isReconnecting = false;
  bool _shouldReconnect = true;
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;

  BleSocket() {
    if (kDebugMode) {
      print('🔵 BleSocket: Initializing BLE Socket...');
    }

    _connectionState = SocketConnectionState.disconnected;
    _connectionStateController = StreamController<SocketConnectionState>.broadcast();
    _messageController = StreamController<Uint8List>.broadcast();
    _config = {};
    _currentBleConnectionState = BluetoothConnectionState.disconnected;
    
    _setDefaultConfiguration();
    _setupAdapterStateListener();

    if (kDebugMode) {
      print('✅ BleSocket: Initialization complete');
    }
  }

  // === Initialization ===

  /// Set default configuration using constants
  void _setDefaultConfiguration() {
    if (kDebugMode) {
      print('🔧 BleSocket: Setting default configuration...');
    }
    
    setConfig({
      'deviceName': AppConstants.primaryBleDeviceName,
      'serviceUUID': AppConstants.primaryServiceUUID,
      'txCharacteristicUUID': AppConstants.primaryTxCharacteristicUUID,
      'rxCharacteristicUUID': AppConstants.primaryRxCharacteristicUUID,
      'scanTimeout': AppConstants.bleTimeout,
      'connectionTimeout': AppConstants.bleTimeout,
      'autoReconnect': true,
      'maxReconnectAttempts': 5,
      'reconnectDelay': const Duration(seconds: 3),
    });
    
    if (kDebugMode) {
      print('✅ BleSocket: Default configuration set - Device: ${AppConstants.primaryBleDeviceName}');
    }
  }

  /// Set up listener for Bluetooth adapter state changes
  void _setupAdapterStateListener() {
    if (kDebugMode) {
      print('👂 BleSocket: Setting up Bluetooth adapter state listener...');
    }
    
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (kDebugMode) {
        print('📡 BleSocket: Bluetooth adapter state changed to: $state');
      }
      
      switch (state) {
        case BluetoothAdapterState.on:
          if (kDebugMode) {
            print('✅ BleSocket: Bluetooth is ON');
          }
          updateConnectionState(SocketConnectionState.disconnected);
          break;
        case BluetoothAdapterState.off:
          if (kDebugMode) {
            print('❌ BleSocket: Bluetooth is OFF');
          }
          _handleBluetoothDisabled();
          break;
        case BluetoothAdapterState.unavailable:
          if (kDebugMode) {
            print('⚠️ BleSocket: Bluetooth is UNAVAILABLE');
          }
          updateConnectionState(SocketConnectionState.disconnected);
          break;
        default:
          if (kDebugMode) {
            print('⚠️ BleSocket: Unknown Bluetooth state: $state');
          }
          break;
      }
    });
  }

  // === SocketInterface Implementation ===

  @override
  void setConfig(Map<String, dynamic> config) {
    if (kDebugMode) {
      print('🔧 BleSocket: Updating configuration...');
      print('📝 BleSocket: New config: $config');
    }
    
    _config = Map.from(config);

    // Update local configuration
    _targetDeviceName = config['deviceName'] as String?;
    _serviceUuid = config['serviceUUID'] != null ? Guid(config['serviceUUID']) : null;
    _txCharacteristicUuid = config['txCharacteristicUUID'] != null ? Guid(config['txCharacteristicUUID']) : null;
    _rxCharacteristicUuid = config['rxCharacteristicUUID'] != null ? Guid(config['rxCharacteristicUUID']) : null;
    
    if (kDebugMode) {
      print('✅ BleSocket: Configuration updated - Target device: $_targetDeviceName');
    }
  }

  @override
  Map<String, dynamic> getConfig() => Map.from(_config);

  @override
  SocketConnectionState get connectionState => _connectionState;

  @override
  Stream<SocketConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  void updateConnectionState(SocketConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(state);
      }
      if (kDebugMode) {
        print('🔄 BleSocket: Connection state changed to: $state');
      }
    }
  }

  @override
  Future<void> connect() async {
    if (isConnected) {
      if (kDebugMode) {
        print('ℹ️ BleSocket: Already connected');
      }
      return;
    }

    if (kDebugMode) {
      print('🚀 BleSocket: Starting connection...');
    }

    await _scanAndConnectToDevice();
  }

  /// Scan for and connect to the target BLE device
  Future<void> _scanAndConnectToDevice() async {
    if (kDebugMode) {
      print('🔍 BleSocket: Starting streamlined scan and connect process...');
    }
    
    // Request BLE permissions before scanning (critical for Android 12+)
    final permissionsGranted = await PermissionsHelper.requestBLEPermissions();
    if (!permissionsGranted) {
      if (kDebugMode) {
        print('❌ BleSocket: BLE permissions not granted, cannot scan');
      }
      updateConnectionState(SocketConnectionState.error);
      throw Exception('BLE permissions not granted');
    }
    
    if (_targetDeviceName == null) {
      if (kDebugMode) {
        print('❌ BleSocket: No target device name configured!');
      }
      throw Exception('Target device name not configured');
    }

    if (kDebugMode) {
      print('🎯 BleSocket: Target device: $_targetDeviceName');
    }

    updateConnectionState(SocketConnectionState.connecting);

    const connectionScanTimeout = Duration(seconds: 30);
    final completer = Completer<BluetoothDevice>();
    StreamSubscription<List<ScanResult>>? subscription;
    BluetoothDevice? targetDevice;

    if (kDebugMode) {
      print('📡 BleSocket: Initiating connection scan with low latency mode...');
    }

    try {
      // Start connection scan with platform-optimized parameters
      // Note: On Android 12+, service filtering can prevent device discovery
      // if the device doesn't advertise the service UUID in its advertisement packet.
      // We scan without service filter and filter manually in results.
      // iOS ignores androidScanMode but it's fine to include it
      await FlutterBluePlus.startScan(
        timeout: connectionScanTimeout,
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: false,
        // Removed withServices filter for better Android 12+ and iOS compatibility
      );

      // Listen for scan results and connect immediately when found
      subscription = FlutterBluePlus.scanResults.listen((results) {
        if (kDebugMode && results.isNotEmpty) {
          print('📱 BleSocket: Connection scan received ${results.length} results');
        }

        if (targetDevice == null && !completer.isCompleted) {
          for (final result in results) {
            final hasCorrectName = result.device.platformName == _targetDeviceName ||
                                  result.advertisementData.advName == _targetDeviceName;
            
            final hasCorrectService = _serviceUuid == null || 
                                    result.advertisementData.serviceUuids.contains(_serviceUuid);
            
            if (kDebugMode) {
              final deviceName = result.device.platformName.isNotEmpty ? result.device.platformName : 'Unknown';
              print('🔍 BleSocket: Validating device: $deviceName');
              print('  ✓ Name match: $hasCorrectName (looking for: $_targetDeviceName)');
              print('  ✓ Service match: $hasCorrectService (looking for: $_serviceUuid)');
            }
            
            if (hasCorrectName && hasCorrectService) {
              targetDevice = result.device;
              if (kDebugMode) {
                print('🎯 BleSocket: TARGET DEVICE FOUND! $_targetDeviceName with service $_serviceUuid');
              }
              completer.complete(targetDevice!);
              return;
            }
          }
        }
      });

      // Wait for device to be found or timeout
      // iOS and Android have different scan behaviors, but timeout handles both
      final device = await completer.future.timeout(
        connectionScanTimeout,
        onTimeout: () {
          if (kDebugMode) {
            print('⏰ BleSocket: Scan timeout - device $_targetDeviceName not found');
          }
          throw TimeoutException('Device not found within ${connectionScanTimeout.inSeconds}s');
        },
      );
      
      // Clean up scan immediately
      await subscription.cancel();
      await FlutterBluePlus.stopScan();
      
      // Connect to the found device
      await _connectToDevice(device);
      
    } catch (e) {
      // Clean up scan
      await subscription?.cancel();
      await FlutterBluePlus.stopScan();
      
      if (kDebugMode) {
        print('❌ BleSocket: Connection scan failed: $e');
      }
      
      updateConnectionState(SocketConnectionState.error);
      throw Exception('Target device $_targetDeviceName not found: $e');
    }
  }

  /// Connect to a specific Bluetooth device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (kDebugMode) {
      print('🔗 BleSocket: Attempting to connect to device: ${device.platformName} (${device.remoteId})');
    }
    
    try {
      // Optimized connection with MTU configuration
      if (Platform.isAndroid) {
        if (kDebugMode) {
          print('🤖 BleSocket: Android detected - using MTU optimization (512)');
        }
        await device.connect(
          timeout: _config['connectionTimeout'] as Duration? ?? AppConstants.bleTimeout,
          mtu: 512,
        );
      } else {
        if (kDebugMode) {
          print('🍎 BleSocket: iOS/macOS detected - using automatic MTU');
        }
        await device.connect(
          timeout: _config['connectionTimeout'] as Duration? ?? AppConstants.bleTimeout,
        );
      }

      _connectedDevice = device;

      // Request high priority connection for faster data transfer (Android only)
      if (Platform.isAndroid) {
        try {
          await device.requestConnectionPriority(
            connectionPriorityRequest: ConnectionPriority.high,
          );
          if (kDebugMode) {
            print('✅ BleSocket: High priority connection requested');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ BleSocket: Failed to request high priority: $e');
          }
        }
      }

      // Set up connection state listener
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (kDebugMode) {
          print('🔄 BleSocket: BLE connection state changed to: $state');
        }
        
        _currentBleConnectionState = state;

        switch (state) {
          case BluetoothConnectionState.connected:
            _onDeviceConnected();
            break;
          case BluetoothConnectionState.disconnected:
            _onDeviceDisconnected();
            break;
          default:
            break;
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('❌ BleSocket: Failed to connect to device: $e');
      }
      await device.disconnect();
      updateConnectionState(SocketConnectionState.error);
      throw Exception('Failed to connect to device: $e');
    }
  }

  /// Called when device is successfully connected
  Future<void> _onDeviceConnected() async {
    if (kDebugMode) {
      print('🎯 BleSocket: Device connected - initializing services...');
    }
    
    // Reset reconnection state on successful connection
    _shouldReconnect = true;
    _reconnectionAttempts = 0;
    _isReconnecting = false;
    
    // Small delay to ensure connection is fully established
    // iOS typically needs less delay than Android, but 500ms works for both
    
    try {
      await _discoverServices();
      updateConnectionState(SocketConnectionState.connected);
    } catch (e) {
      if (kDebugMode) {
        print('❌ BleSocket: Service discovery failed: $e');
      }
      await disconnect();
      rethrow;
    }
  }

  /// Discover services and characteristics
  Future<void> _discoverServices() async {
    if (kDebugMode) {
      print('🔍 BleSocket: Starting service discovery...');
    }
    
    if (_connectedDevice == null) {
      throw Exception('No connected device');
    }

    if (_serviceUuid == null) {
      throw Exception('Service UUID not configured');
    }

    // Discover services with timeout
    // iOS typically completes service discovery faster than Android
    final services = await _connectedDevice!.discoverServices(
      subscribeToServicesChanged: true,
      timeout: AppConstants.BLEServiceTimeout,
    );

    if (kDebugMode) {
      print('📋 BleSocket: Discovered ${services.length} services');
    }

    if (services.isEmpty) {
      throw Exception('No services discovered');
    }

    bool targetServiceFound = false;
    
    for (final service in services) {
      if (service.uuid == _serviceUuid) {
        targetServiceFound = true;
        if (kDebugMode) {
          print('✅ BleSocket: Found target service: ${service.uuid}');
        }
        
        // Find TX and RX characteristics
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid == _txCharacteristicUuid) {
            _txCharacteristic = characteristic;
            if (kDebugMode) {
              print('✅ BleSocket: Found TX characteristic');
            }
          } else if (characteristic.uuid == _rxCharacteristicUuid) {
            _rxCharacteristic = characteristic;
            if (kDebugMode) {
              print('✅ BleSocket: Found RX characteristic');
            }
            await _setupRxNotifications();
          }
        }
        break;
      }
    }

    if (!targetServiceFound) {
      throw Exception('Target service $_serviceUuid not found');
    }

    if (_txCharacteristic == null) {
      throw Exception('TX characteristic not found');
    }

    if (_rxCharacteristic == null) {
      throw Exception('RX characteristic not found');
    }
  }

  /// Set up notifications for RX characteristic
  Future<void> _setupRxNotifications() async {
    if (_rxCharacteristic == null) {
      if (kDebugMode) {
        print('❌ BleSocket: RX characteristic is null');
      }
      return;
    }

    if (!_rxCharacteristic!.properties.notify && !_rxCharacteristic!.properties.indicate) {
      if (kDebugMode) {
        print('❌ BleSocket: RX characteristic does not support notifications');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('📡 BleSocket: Enabling RX notifications...');
      }

      await _rxCharacteristic!.setNotifyValue(true);

      _rxDataSubscription = _rxCharacteristic!.onValueReceived.listen(
        (data) {
          if (kDebugMode) {
            print('📥 BleSocket: Received ${data.length} bytes');
          }
          
          // Convert List<int> to Uint8List and forward
          final uint8Data = Uint8List.fromList(data);
          if (!_messageController.isClosed) {
            _messageController.add(uint8Data);
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('❌ BleSocket: RX error: $error');
          }
        },
        onDone: () {
          if (kDebugMode) {
            print('🛑 BleSocket: RX stream closed');
          }
        },
      );

      if (kDebugMode) {
        print('✅ BleSocket: RX notifications enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ BleSocket: Failed to setup RX notifications: $e');
      }
      rethrow;
    }
  }

  /// Called when device is disconnected
  void _onDeviceDisconnected() {
    if (kDebugMode) {
      print('💔 BleSocket: Device disconnected');
    }
    
    _currentBleConnectionState = BluetoothConnectionState.disconnected;
    updateConnectionState(SocketConnectionState.disconnected);
    
    final shouldReconnect = _config['autoReconnect'] as bool? ?? true;
    final maxAttempts = _config['maxReconnectAttempts'] as int? ?? 5;
    
    if (shouldReconnect && _shouldReconnect && !_isReconnecting && _reconnectionAttempts < maxAttempts) {
      _attemptReconnection();
    } else {
      _cleanupConnection();
    }
  }

  /// Attempt to reconnect to the last connected device
  void _attemptReconnection() async {
    if (_isReconnecting || _targetDeviceName == null) return;
    
    _isReconnecting = true;
    _reconnectionAttempts++;
    
    final reconnectDelay = _config['reconnectDelay'] as Duration? ?? const Duration(seconds: 3);
    final maxAttempts = _config['maxReconnectAttempts'] as int? ?? 5;
    
    if (kDebugMode) {
      print('🔄 BleSocket: Attempting reconnection $_reconnectionAttempts/$maxAttempts in ${reconnectDelay.inSeconds}s...');
    }
    
    updateConnectionState(SocketConnectionState.reconnecting);
    
    _reconnectionTimer = Timer(reconnectDelay, () async {
      try {
        await _scanAndConnectToDevice();
        _reconnectionAttempts = 0;
        _isReconnecting = false;
        
        if (kDebugMode) {
          print('✅ BleSocket: Reconnection successful');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ BleSocket: Reconnection attempt $_reconnectionAttempts failed: $e');
        }
        
        _isReconnecting = false;
        
        if (_reconnectionAttempts >= maxAttempts) {
          if (kDebugMode) {
            print('❌ BleSocket: Max reconnection attempts reached');
          }
          _cleanupConnection();
          updateConnectionState(SocketConnectionState.error);
        }
      }
    });
  }

  /// Handle Bluetooth being disabled
  void _handleBluetoothDisabled() {
    _cleanupConnection();
    updateConnectionState(SocketConnectionState.disconnected);
  }

  /// Clean up connection resources
  void _cleanupConnection() {
    _currentBleConnectionState = BluetoothConnectionState.disconnected;
    
    _disableNotifications();
    
    _rxDataSubscription?.cancel();
    _rxDataSubscription = null;
    
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    
    _scanSubscription?.cancel();
    _scanSubscription = null;
    
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;

    _connectedDevice = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _isReconnecting = false;
  }

  /// Disable notifications on characteristics
  /// Captures a local reference to avoid a race with _cleanupConnection nulling the field.
  Future<void> _disableNotifications() async {
    final rxChar = _rxCharacteristic; // capture before possible null-out
    if (rxChar == null) return;
    try {
      if (rxChar.properties.notify || rxChar.properties.indicate) {
        await rxChar.setNotifyValue(false);
        if (kDebugMode) {
          print('🛑 BleSocket: RX notifications disabled');
        }
      }
    } catch (e) {
      // Expected to fail if the device is already physically disconnected
      if (kDebugMode) {
        print('⚠️ BleSocket: Error disabling notifications (device may already be disconnected): $e');
      }
    }
  }

  @override
  Future<void> disconnect() async {
    if (kDebugMode) {
      print('🔌 BleSocket: Manual disconnect requested');
    }
    
    _shouldReconnect = false;
    
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect(
          timeout: 10,
          queue: true,
          androidDelay: 2000,
        );
        
        if (kDebugMode) {
          print('✅ BleSocket: Device disconnected successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ BleSocket: Error during disconnect: $e');
        }
      }
    }
    
    _cleanupConnection();
    updateConnectionState(SocketConnectionState.disconnected);
  }

  @override
  Future<void> sendData(Uint8List data) async {
    if (kDebugMode) {
      print('📤 BleSocket: Attempting to send ${data.length} bytes...');
    }
    
    if (!isConnected || _txCharacteristic == null) {
      if (kDebugMode) {
        print('❌ BleSocket: Cannot send data - not connected');
      }
      throw StateError('Not connected or TX characteristic not available');
    }

    try {
      await _txCharacteristic!.write(data, withoutResponse: false);
      
      if (kDebugMode) {
        print('✅ BleSocket: Data sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ BleSocket: Failed to send data: $e');
      }
      rethrow;
    }
  }

  @override
  Stream<Uint8List> get messageStream => _messageController.stream;

  @override
  StreamSubscription<Uint8List>? listen(
    void Function(Uint8List) onData, {
    Function? onError,
    void Function()? onDone,
  }) {
    return messageStream.listen(
      onData,
      onError: onError,
      onDone: onDone,
    );
  }

  // === BLE-Specific Methods ===

  /// Check if a specific BLE device is available
  Future<bool> checkDeviceAvailability(
    String deviceName,
    String? serviceUuid, {
    Duration scanTimeout = const Duration(seconds: 10),
  }) async {
    if (kDebugMode) {
      print('🔍 BleSocket: Checking availability of device: $deviceName');
    }

    // Request BLE permissions before scanning (critical for Android 12+)
    final permissionsGranted = await PermissionsHelper.requestBLEPermissions();
    if (!permissionsGranted) {
      if (kDebugMode) {
        print('❌ BleSocket: BLE permissions not granted, cannot scan');
      }
      return false;
    }

    final completer = Completer<bool>();
    StreamSubscription<List<ScanResult>>? subscription;
    final targetServiceUuid = serviceUuid != null ? Guid(serviceUuid) : null;

    try {
      // Start scan with optimized parameters
      // Note: On Android 12+, service filtering can prevent device discovery
      // iOS handles scan parameters differently but this works for both
      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: false,
        // Removed withServices filter for better Android 12+ and iOS compatibility
      );

      subscription = FlutterBluePlus.scanResults.listen((results) {
        if (!completer.isCompleted) {
          for (final result in results) {
            final hasCorrectName = result.device.platformName == deviceName ||
                                  result.advertisementData.advName == deviceName;
            final hasCorrectService = targetServiceUuid == null ||
                                    result.advertisementData.serviceUuids.contains(targetServiceUuid);

            if (hasCorrectName && hasCorrectService) {
              if (kDebugMode) {
                print('🎯 BleSocket: Device $deviceName found');
              }
              completer.complete(true);
              return;
            }
          }
        }
      });

      final result = await completer.future.timeout(scanTimeout, onTimeout: () {
        if (kDebugMode) {
          print('⏰ BleSocket: Availability check timed out');
        }
        return false;
      });

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ BleSocket: Error during availability check: $e');
      }
      return false;
    } finally {
      await subscription?.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  /// Scan for BLE devices
  /// Accumulates unique devices (by remoteId) across the full scan duration.
  Future<List<ScanResult>> scanForDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (kDebugMode) {
      print('🔍 BleSocket: Starting device scan (${timeout.inSeconds}s)...');
    }

    final resultMap = <String, ScanResult>{};

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidScanMode: AndroidScanMode.lowLatency,
      continuousUpdates: true,
    );

    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        resultMap[r.device.remoteId.str] = r;
      }
    });

    // Wait for the scan to complete
    await Future.delayed(timeout);
    await subscription.cancel();
    await FlutterBluePlus.stopScan();

    final results = resultMap.values.toList();
    if (kDebugMode) {
      print('📱 BleSocket: Scan complete — found ${results.length} unique devices');
    }

    return results;
  }

  /// Connect to a specific device by name
  Future<void> connectToDevice(String deviceName) async {
    // Re-enable reconnection in case a previous disconnect() turned it off
    _shouldReconnect = true;
    _reconnectionAttempts = 0;
    setConfig({..._config, 'deviceName': deviceName});
    await _scanAndConnectToDevice();
  }

  /// Connect to a specific Bluetooth device directly
  Future<void> connectToDeviceDirect(BluetoothDevice device) async {
    await _connectToDevice(device);
  }

  /// Switch to primary device configuration
  void usePrimaryDevice() {
    setConfig({
      ..._config,
      'deviceName': AppConstants.primaryBleDeviceName,
      'serviceUUID': AppConstants.primaryServiceUUID,
      'txCharacteristicUUID': AppConstants.primaryTxCharacteristicUUID,
      'rxCharacteristicUUID': AppConstants.primaryRxCharacteristicUUID,
    });
  }

  /// Monitor connection health
  Future<Map<String, dynamic>> getConnectionHealth() async {
    if (_connectedDevice == null || !isConnected) {
      return {
        'connected': false,
        'rssi': null,
        'mtu': null,
        'status': 'disconnected'
      };
    }

    try {
      final rssi = await _connectedDevice!.readRssi();
      final mtu = _connectedDevice!.mtuNow;
      
      String quality = 'poor';
      if (rssi > -60) {
        quality = 'excellent';
      } else if (rssi > -70) {
        quality = 'good';
      } else if (rssi > -80) {
        quality = 'fair';
      }

      return {
        'connected': true,
        'rssi': rssi,
        'mtu': mtu,
        'quality': quality,
        'status': 'healthy',
        'deviceName': _connectedDevice!.platformName,
      };
    } catch (e) {
      return {
        'connected': true,
        'rssi': null,
        'mtu': null,
        'status': 'error',
        'error': e.toString()
      };
    }
  }

  /// Enable automatic reconnection
  void enableAutoReconnect() {
    _shouldReconnect = true;
    _reconnectionAttempts = 0;
  }

  /// Disable automatic reconnection
  void disableAutoReconnect() {
    _shouldReconnect = false;
    _reconnectionTimer?.cancel();
    _isReconnecting = false;
  }

  /// Manually trigger reconnection
  Future<void> reconnect() async {
    if (_targetDeviceName == null) {
      throw Exception('No target device name configured');
    }
    
    _shouldReconnect = true;
    _reconnectionAttempts = 0;
    _isReconnecting = false;
    
    if (isConnected) {
      await disconnect();
    }
    
    await _scanAndConnectToDevice();
  }

  // === Property Accessors ===

  @override
  bool get isConnected => _connectionState == SocketConnectionState.connected && _connectedDevice != null;

  @override
  bool get isConnecting => _connectionState == SocketConnectionState.connecting;

  @override
  bool get isDisconnected => _connectionState == SocketConnectionState.disconnected;

  /// Get the current connected device
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Check if a specific device is connected
  bool isDeviceConnected(String deviceName) {
    return isConnected && _connectedDevice?.platformName == deviceName;
  }

  /// Check if auto-reconnect is enabled
  bool get isAutoReconnectEnabled => _shouldReconnect;

  /// Get current reconnection attempt count
  int get reconnectionAttempts => _reconnectionAttempts;

  // === Disposal ===

  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 BleSocket: Disposing...');
    }

    _shouldReconnect = false;
    _cleanupConnection();
    _adapterStateSubscription?.cancel();
    
    _connectionStateController.close();
    _messageController.close();

    if (kDebugMode) {
      print('✅ BleSocket: Disposal complete');
    }
  }
}
