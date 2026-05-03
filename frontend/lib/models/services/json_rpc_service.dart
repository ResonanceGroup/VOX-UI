import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../communications/connection_manager.dart';

/// JSON-RPC Service for handling communication with RV dashboard
/// Processes JSON-RPC messages from ConnectionManager and provides typed methods
///
/// Expected JSON-RPC Notification Structure for Solar Data:
/// {
///   "jsonrpc": "2.0",
///   "method": "solar.update",
///   "params": {
///     "voltage": 12.5,    // double: Solar panel voltage in volts
///     "current": 2.3,     // double: Solar panel current in amperes
///     "power": 28.75      // double: Solar panel power in watts
///   }
/// }
class JsonRpcService {
  static final JsonRpcService _instance = JsonRpcService._internal();
  factory JsonRpcService() => _instance;
  JsonRpcService._internal();

  ConnectionManager? _connectionManager;
  bool _isInitialized = false;

  // Stream controllers for processed data
  final StreamController<Map<String, dynamic>> _responseController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Data handling
  final StringBuffer _dataBuffer = StringBuffer();
  StreamSubscription<Uint8List>? _dataSubscription;

  // Pending requests tracking
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _nextRequestId = 1;

  // Stream subscriptions
  StreamSubscription<ConnectionManagerState>? _connectionStateSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<String>? _connectionErrorSubscription;

  /// Initialize the JSON-RPC service
  /// Creates ConnectionManager which handles its own connection lifecycle
  /// JsonRpcService only handles JSON-RPC protocol, not connection management
  void initialize() {
    if (_isInitialized) {
      if (kDebugMode) {
        print('JsonRpcService already initialized');
      }
      return;
    }

    // Create ConnectionManager - it handles its own lifecycle and BLE/TCP initialization
    _connectionManager = ConnectionManager();
    _isInitialized = true;

    // Set up stream listeners to observe connection state
    _setupStreamListeners();

    if (kDebugMode) {
      print(
        'JsonRpcService initialized - ConnectionManager handles all connection logic',
      );
    }
  }

  /// Set up listeners for ConnectionManager streams
  void _setupStreamListeners() {
    if (_connectionManager == null) return;

    // Listen to connection state changes
    _connectionStateSubscription = _connectionManager!.connectionStateStream
        .listen((state) {
          if (state == ConnectionManagerState.connected) {
            _setupDataListener();
          } else if (state == ConnectionManagerState.disconnected) {
            _onDisconnected();
          } else if (state == ConnectionManagerState.reconnecting) {
            // TODO: We might to consider the logic here a little more here. Instead of canceling everything, we should "pause" data transmission until a valid connection is formed
            // Cancel data subscription when reconnecting
            _dataSubscription?.cancel();
            _dataSubscription = null;

            // Complete all pending requests with error
            for (final completer in _pendingRequests.values) {
              if (!completer.isCompleted) {
                completer.completeError(
                  'Connection lost, attempting to reconnect',
                );
              }
            }
            _pendingRequests.clear();
          }
        });

    // Listen to connection errors
    _connectionErrorSubscription = _connectionManager!.errorStream.listen((
      error,
    ) {
      _errorController.add('Connection error: $error');
    });
  }

  /// Set up data listener from ConnectionManager's messageStream
  void _setupDataListener() {
    if (_connectionManager == null || !_connectionManager!.isConnected) return;

    // Cancel any existing subscription
    _dataSubscription?.cancel();

    // Listen to ConnectionManager's messageStream (NOT socket directly)
    _dataSubscription = _connectionManager!.messageStream.listen(
      _onDataReceived,
      onError: (error) => _errorController.add('Data reception error: $error'),
      onDone: _onDisconnected,
    );
  }

  /// Handle incoming data from socket
  void _onDataReceived(Uint8List data) {
    if (kDebugMode) {
      print('📨 JsonRpcService: Received ${data.length} bytes from socket');
    }
    try {
      final jsonString = utf8.decode(data);
      _dataBuffer.write(jsonString);

      // Process complete messages (newline-delimited or complete JSON objects)
      final buffer = _dataBuffer.toString();
      final lines = buffer.split('\n');

      // Keep the last incomplete line in the buffer
      _dataBuffer.clear();
      String? lastLine;
      if (lines.isNotEmpty && lines.last.isNotEmpty) {
        lastLine = lines.last;
      }

      // Process complete lines (all except the last)
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          _tryProcessJsonMessage(line);
        }
      }

      // Try to process the last line if it looks like complete JSON
      if (lastLine != null && lastLine.trim().isNotEmpty) {
        final trimmedLast = lastLine.trim();
        if (_looksLikeCompleteJson(trimmedLast)) {
          _tryProcessJsonMessage(trimmedLast);
          // Successfully processed, don't put it back in buffer
        } else {
          // Put incomplete data back in buffer
          _dataBuffer.write(lastLine);
        }
      }
    } catch (e) {
      _errorController.add('Failed to parse incoming data: $e');
    }
  }

  /// Check if a string looks like complete JSON
  bool _looksLikeCompleteJson(String text) {
    if (text.isEmpty) return false;
    text = text.trim();
    return (text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'));
  }

  /// Try to process a JSON message string
  void _tryProcessJsonMessage(String jsonText) {
    try {
      final message = json.decode(jsonText) as Map<String, dynamic>;
      _handleJsonRpcMessage(message);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to parse JSON: $e');
        print('JSON text: $jsonText');
      }
      _errorController.add('Failed to parse JSON message: $e');
    }
  }

  /// Handle incoming JSON-RPC message
  void _handleJsonRpcMessage(Map<String, dynamic> message) {
    // Check if it's a response (has id and result/error)
    if (message.containsKey('id') &&
        (message.containsKey('result') || message.containsKey('error'))) {
      _handleIncomingMessage(message);
    }
    // Check if it's a notification (has method but no id)
    else if (message.containsKey('method') && !message.containsKey('id')) {
      _handleIncomingNotification(message);
    }
  }

  /// Called when socket disconnects
  void _onDisconnected() {
    _dataSubscription?.cancel();

    // Complete all pending requests with error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Connection lost');
      }
    }
    _pendingRequests.clear();
  }

  /// Handle incoming JSON-RPC messages (responses)
  void _handleIncomingMessage(Map<String, dynamic> message) {
    try {
      final id = message['id'];
      final error = message['error'];
      final result = message['result'];

      // Check if this is a heartbeat response
      if (id != null && _connectionManager != null) {
        _connectionManager!.handleHeartbeatResponse(id);
      }

      if (id != null && _pendingRequests.containsKey(id)) {
        final completer = _pendingRequests.remove(id)!;

        if (error != null) {
          completer.completeError(JsonRpcError.fromJson(error));
        } else {
          completer.complete(result ?? {});
        }
      }

      // Also emit to response stream for external listeners
      _responseController.add(message);
    } catch (e) {
      _errorController.add('Error processing incoming message: $e');
    }
  }

  /// Handle incoming JSON-RPC notifications
  void _handleIncomingNotification(Map<String, dynamic> notification) {
    try {
      if (kDebugMode) {
        final method = notification['method'];
        final params = notification['params'];
        print('📢 JsonRpcService: Processing notification: $method');
        print('📢 JsonRpcService: Adding to notification stream');
      }

      _notificationController.add(notification);

      if (kDebugMode) {
        final method = notification['method'];
        final params = notification['params'];
        print(
          '✅ JsonRpcService: Notification propagated: $method with params: $params',
        );
      }
    } catch (e) {
      _errorController.add('Error processing notification: $e');
    }
  }

  /// Send a JSON-RPC request and wait for response
  Future<Map<String, dynamic>> sendRequest(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    if (!_isInitialized || _connectionManager == null) {
      if (kDebugMode) {
        print('⚠️ JsonRpcService: Not initialized, skipping request in debug mode');
        return {};
      }
      throw StateError('JsonRpcService not initialized');
    }

    if (!_connectionManager!.isConnected) {
      if (kDebugMode) {
        print('⚠️ JsonRpcService: No connection, skipping request "$method" in debug mode');
        return {};
      }
      throw StateError('No active connection');
    }

    final requestId = _nextRequestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    // Set timeout for request
    final timeout = Timer(const Duration(seconds: 30), () {
      if (_pendingRequests.containsKey(requestId)) {
        _pendingRequests.remove(requestId);
        completer.completeError('Request timeout');
      }
    });

    try {
      await _connectionManager!.sendRequest(method, params);

      final result = await completer.future;
      timeout.cancel();
      return result;
    } catch (e) {
      timeout.cancel();
      if (_pendingRequests.containsKey(requestId)) {
        _pendingRequests.remove(requestId);
      }
      rethrow;
    }
  }

  /// Send a JSON-RPC notification (no response expected)
  Future<void> sendNotification(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    if (!_isInitialized || _connectionManager == null) {
      if (kDebugMode) {
        print('⚠️ JsonRpcService: Not initialized, skipping notification in debug mode');
        return;
      }
      throw StateError('JsonRpcService not initialized');
    }

    if (!_connectionManager!.isConnected) {
      if (kDebugMode) {
        print('⚠️ JsonRpcService: No connection, skipping notification "$method" with params: $params in debug mode');
        return;
      }
      throw StateError('No active connection');
    }

    await _connectionManager!.sendNotification(method, params);
  }

  /// Send print diagnostics request to backend
  Future<bool> sendPrintDiagnostics() async {
    if (!_isInitialized || _connectionManager == null) {
      if (kDebugMode) {
        print('⚠️ JsonRpcService: Not initialized, cannot send diagnostics');
      }
      return false;
    }

    return await _connectionManager!.sendPrintDiagnostics();
  }

  /// Manually trigger reconnection. No-op if already connected or connecting.
  Future<void> reconnect() async {
    await _connectionManager?.reconnect();
  }

  /// Get current transport type
  String? get currentTransport => _connectionManager?.currentTransport;

  /// Human-readable connection type label ('WiFi', 'Ethernet', 'Bluetooth', or 'None')
  String get networkTransportLabel =>
      _connectionManager?.networkTransportLabel ?? 'None';

  /// Check if connected (not reconnecting)
  bool get isConnected =>
      _connectionManager != null && _connectionManager!.isConnected;

  /// Get connection state
  ConnectionManagerState get connectionState =>
      _connectionManager?.currentState ?? ConnectionManagerState.disconnected;

  /// Stream of JSON-RPC responses
  Stream<Map<String, dynamic>> get responseStream => _responseController.stream;

  /// Stream of JSON-RPC notifications
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  /// Stream of errors
  Stream<String> get errorStream => _errorController.stream;

  /// Stream of connection state changes
  Stream<ConnectionManagerState> get connectionStateStream {
    if (_connectionManager == null) {
      return const Stream.empty();
    }
    return _connectionManager!.connectionStateStream;
  }

  /// Stream of network transport label changes ('WiFi', 'Ethernet', 'Bluetooth', 'None')
  Stream<String> get networkTransportStream {
    if (_connectionManager == null) {
      return const Stream.empty();
    }
    return _connectionManager!.networkTransportStream;
  }

  /// Dispose of resources
  void dispose() {
    _connectionStateSubscription?.cancel();
    _messageSubscription?.cancel();
    _notificationSubscription?.cancel();
    _connectionErrorSubscription?.cancel();
    _dataSubscription?.cancel();

    _pendingRequests.clear();

    _responseController.close();
    _notificationController.close();
    _errorController.close();
    _dataBuffer.clear();

    // Dispose of the connection manager
    _connectionManager?.dispose();
    _connectionManager = null;

    _isInitialized = false;

    if (kDebugMode) {
      print('JsonRpcService disposed');
    }
  }
}

/// JSON-RPC Error class
class JsonRpcError implements Exception {
  final int code;
  final String message;
  final dynamic data;

  JsonRpcError({required this.code, required this.message, this.data});

  factory JsonRpcError.fromJson(Map<String, dynamic> json) {
    return JsonRpcError(
      code: json['code'] as int? ?? -32603,
      message: json['message'] as String? ?? 'Unknown error',
      data: json['data'],
    );
  }

  @override
  String toString() => 'JsonRpcError $code: $message';
}
