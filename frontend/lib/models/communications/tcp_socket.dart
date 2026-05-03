import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:flutter/foundation.dart';
import 'package:dart_ping/dart_ping.dart';
import 'socket_interface.dart';
import '../constants.dart';

/// TCP Socket implementation with integrated connection management
/// Combines low-level socket operations with lifecycle management
class TcpSocket implements SocketInterface {
  // === Socket Resources ===
  Socket? _socket;
  
  // === Stream Controllers ===
  late StreamController<SocketConnectionState> _connectionStateController;
  late StreamController<Uint8List> _messageController;
  
  // === Configuration ===
  late Map<String, dynamic> _config;
  late SocketConnectionState _connectionState;
  
  // === Retry Logic ===
  int _retryCount = 0;
  Timer? _reconnectTimer;
  
  // === Data Listening ===
  StreamSubscription<List<int>>? _socketDataSubscription;

  TcpSocket() {
    if (kDebugMode) {
      print('🔵 TcpSocket: Initializing TCP Socket...');
    }
    
    _connectionState = SocketConnectionState.disconnected;
    _connectionStateController = StreamController<SocketConnectionState>.broadcast();
    _messageController = StreamController<Uint8List>.broadcast();
    
    // Set default configuration
    _config = {
      'host': AppConstants.dashboardHost,
      'port': AppConstants.dashboardPort,
      'timeout': AppConstants.tcpConnectionTimeout,
      'maxRetries': AppConstants.tcpMaxRetries,
      'retryDelay': const Duration(seconds: 5),
    };

    // Platform-specific initialization
    if (Platform.isAndroid) {
      // Android-specific initialization if needed
    } else if (Platform.isIOS) {
      DartPingIOS.register();
    }
    
    if (kDebugMode) {
      print('✅ TcpSocket: Initialization complete');
    }
  }

  // === SocketInterface Implementation ===
  
  @override
  void setConfig(Map<String, dynamic> config) {
    if (kDebugMode) {
      print('🔧 TcpSocket: Updating configuration: $config');
    }
    _config = Map.from(config);
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
        print('🔄 TcpSocket: Connection state changed to: $state');
      }
    }
  }

  @override
  Future<void> connect() async {
    if (isConnected) {
      if (kDebugMode) {
        print('ℹ️ TcpSocket: Already connected');
      }
      return;
    }

    if (kDebugMode) {
      print('🚀 TcpSocket: Starting connection...');
    }

    _retryCount = 0;
    await _attemptConnection();
  }

  /// Attempt to establish TCP connection with retry logic
  Future<void> _attemptConnection() async {
    updateConnectionState(SocketConnectionState.connecting);

    // Read target host/port before the try so they are available in catch
    final host = _config['host'] as String;
    final port = _config['port'] as int;
    final timeout = _config['timeout'] as Duration;

    try {
      if (kDebugMode) {
        print('🔌 TcpSocket: Connecting to $host:$port (attempt ${_retryCount + 1})');
      }

      _socket = await Socket.connect(
        host,
        port,
        timeout: timeout,
      );

      if (kDebugMode) {
        print('✅ TcpSocket: Socket connection established to $host:$port');
      }

      _setupSocketListeners();
      updateConnectionState(SocketConnectionState.connected);

      // Reset retry count on successful connection
      _retryCount = 0;

    } catch (e) {
      // Note: Dart's SocketException on Android reports the *local* ephemeral port
      // assigned by the OS, not the remote port. Always log the intended target
      // explicitly so error messages are not misleading.
      if (kDebugMode) {
        print('❌ TcpSocket: Connection to $host:$port failed: $e');
      }

      _cleanupSocket();

      final maxRetries = _config['maxRetries'] as int? ?? AppConstants.tcpMaxRetries;

      if (_retryCount < maxRetries) {
        _retryCount++;
        final retryDelay =
            _config['retryDelay'] as Duration? ?? const Duration(seconds: 5);

        if (kDebugMode) {
          print(
            '🔄 TcpSocket: Retrying in ${retryDelay.inSeconds}s… '
            '(attempt $_retryCount/$maxRetries)',
          );
        }

        _reconnectTimer = Timer(retryDelay, () => _attemptConnection());
      } else {
        if (kDebugMode) {
          print('❌ TcpSocket: Max retries reached, giving up on $host:$port');
        }
        updateConnectionState(SocketConnectionState.error);
        // Include the intended target in the message – the OS-level port in the
        // raw SocketException is the local ephemeral port, NOT the remote port.
        throw Exception(
          'Failed to connect to $host:$port after $maxRetries attempts. '
          'OS error: $e',
        );
      }
    }
  }

  /// Set up socket event listeners
  void _setupSocketListeners() {
    if (_socket == null) return;

    if (kDebugMode) {
      print('👂 TcpSocket: Setting up socket listeners...');
    }

    _socketDataSubscription = _socket!.listen(
      (List<int> data) {
        // Convert List<int> to Uint8List and forward to message stream
        final uint8Data = Uint8List.fromList(data);
        if (!_messageController.isClosed) {
          _messageController.add(uint8Data);
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ TcpSocket: Socket error: $error');
        }
        _handleDisconnection();
      },
      onDone: () {
        if (kDebugMode) {
          print('🛑 TcpSocket: Socket closed');
        }
        _handleDisconnection();
      },
    );

    // Set socket options
    _socket!.setOption(SocketOption.tcpNoDelay, true);
  }

  /// Handle socket disconnection
  void _handleDisconnection() {
    if (kDebugMode) {
      print('💔 TcpSocket: Handling disconnection...');
    }

    _cleanupSocket();
    updateConnectionState(SocketConnectionState.disconnected);

    // Note: Reconnection logic should be handled by ConnectionManager
    // not by the socket itself
  }

  /// Clean up socket resources
  void _cleanupSocket() {
    _socketDataSubscription?.cancel();
    _socketDataSubscription = null;

    _socket?.destroy();
    _socket = null;
  }

  @override
  Future<void> disconnect() async {
    if (kDebugMode) {
      print('🔌 TcpSocket: Disconnecting...');
    }

    // Cancel any pending reconnect timers
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _cleanupSocket();
    updateConnectionState(SocketConnectionState.disconnected);

    if (kDebugMode) {
      print('✅ TcpSocket: Disconnection complete');
    }
  }

  @override
  Future<void> sendData(Uint8List data) async {
    if (!isConnected || _socket == null) {
      if (kDebugMode) {
        print('❌ TcpSocket: Cannot send data - not connected');
      }
      throw StateError('Not connected to TCP socket');
    }

    try {
      _socket!.add(data);
      await _socket!.flush();
      
      if (kDebugMode) {
        print('📤 TcpSocket: Sent ${data.length} bytes');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TcpSocket: Failed to send data: $e');
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

  // === TCP-Specific Methods ===

  /// Check if a specific TCP device is available using ping
  Future<bool> checkDeviceAvailability(
    String? hostName, {
    Duration scanTimeout = const Duration(seconds: 10),
  }) async {
    final host = hostName ?? _config['host'] as String;

    if (kDebugMode) {
      print('🔍 TcpSocket: Checking availability of $host...');
    }

    try {
      final ping = Ping(host, count: 3, timeout: 3);
      
      await for (final event in ping.stream) {
        if (event.response != null) {
          if (kDebugMode) {
            print('✅ TcpSocket: Device $host is available (${event.response!.time?.inMilliseconds}ms)');
          }
          return true;
        }
      }

      if (kDebugMode) {
        print('❌ TcpSocket: Device $host did not respond to ping');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ TcpSocket: Error checking device availability: $e');
      }
      return false;
    }
  }

  // === Property Accessors ===

  @override
  bool get isConnected => _connectionState == SocketConnectionState.connected && _socket != null;

  @override
  bool get isConnecting => _connectionState == SocketConnectionState.connecting;

  @override
  bool get isDisconnected => _connectionState == SocketConnectionState.disconnected;

  /// Get the current socket
  Socket? get socket => _socket;

  /// Get current retry count
  int get retryCount => _retryCount;

  // === Disposal ===

  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 TcpSocket: Disposing...');
    }

    _reconnectTimer?.cancel();
    _cleanupSocket();
    
    _connectionStateController.close();
    _messageController.close();

    if (kDebugMode) {
      print('✅ TcpSocket: Disposal complete');
    }
  }
}
