import 'dart:async';
import 'dart:typed_data';

/// Abstract interface for unified communications across different transport protocols
/// This allows TCP, BLE, and future mobile data connections to implement a common API
abstract class SocketInterface {
  /// Stream controller for connection state changes
  StreamController<SocketConnectionState>? _connectionStateController;

  /// Stream of connection state changes
  Stream<SocketConnectionState> get connectionStateStream {
    _connectionStateController ??=
        StreamController<SocketConnectionState>.broadcast();
    return _connectionStateController!.stream;
  }

  /// Current connection state
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;

  SocketConnectionState get connectionState => _connectionState;

  /// Configuration map for transport-specific parameters
  Map<String, dynamic> _config = {};

  /// Set configuration parameters for the transport
  void setConfig(Map<String, dynamic> config) {
    _config = Map.from(config);
  }

  /// Get current configuration
  Map<String, dynamic> getConfig() => Map.from(_config);

  /// Abstract method: Establish connection to the transport
  /// Implementations should handle transport-specific connection logic
  /// and update connectionState accordingly
  Future<void> connect();

  /// Abstract method: Close connection and clean up resources
  /// Should update connectionState to disconnected
  Future<void> disconnect();

  /// Abstract method: Send data through the transport
  /// @param data The data to send as bytes
  Future<void> sendData(Uint8List data);

  /// Stream of incoming messages from the transport
  /// Emits raw binary data (Uint8List) received from the connection
  Stream<Uint8List> get messageStream;

  /// Optional method: Listen to incoming data
  /// Returns a subscription that can be cancelled
  StreamSubscription<Uint8List>? listen(
    void Function(Uint8List) onData, {
    Function? onError,
    void Function()? onDone,
  });

  /// Update connection state and notify listeners
  void _updateConnectionState(SocketConnectionState state) {
    _connectionState = state;
    if (_connectionStateController != null &&
        !_connectionStateController!.isClosed) {
      _connectionStateController!.add(state);
    }
  }

  /// Helper method for implementations to update state
  void updateConnectionState(SocketConnectionState state) {
    _updateConnectionState(state);
  }

  /// Check if currently connected
  bool get isConnected => _connectionState == SocketConnectionState.connected;

  /// Check if currently connecting
  bool get isConnecting => _connectionState == SocketConnectionState.connecting;

  /// Check if currently disconnected
  bool get isDisconnected =>
      _connectionState == SocketConnectionState.disconnected;

  /// Dispose of resources
  void dispose() {
    _connectionStateController?.close();
  }
}

/// Enumeration of possible connection states
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}
