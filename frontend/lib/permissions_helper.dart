import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class to handle BLE permissions
class PermissionsHelper {
  /// Request all necessary BLE permissions on app startup
  static Future<bool> requestBLEPermissions() async {
    if (kDebugMode) {
      print('🔐 PermissionsHelper: Requesting BLE permissions...');
    }

    // Check if we're on Android and what version
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      if (kDebugMode) {
        print('📱 PermissionsHelper: Android SDK version: $androidInfo');
      }

      // Request permissions based on Android version
      if (androidInfo >= 31) { // Android 12+
        return await _requestAndroid12Permissions();
      } else {
        return await _requestLegacyAndroidPermissions();
      }
    } else if (Platform.isIOS) {
      return await _requestIOSPermissions();
    }

    if (kDebugMode) {
      print('⚠️ PermissionsHelper: Unsupported platform for BLE permissions');
    }
    return false;
  }

  /// Get Android SDK version
  static Future<int> _getAndroidVersion() async {
    try {
      // For now, assume modern Android (12+) - you can use device_info_plus for actual detection
      return 31; // This should be replaced with actual device info detection
    } catch (e) {
      if (kDebugMode) {
        print('❌ PermissionsHelper: Failed to get Android version: $e');
      }
      return 30; // Default to pre-Android 12
    }
  }

  /// Request Android 12+ BLE permissions
  static Future<bool> _requestAndroid12Permissions() async {
    if (kDebugMode) {
      print('🔐 PermissionsHelper: Requesting Android 12+ BLE permissions...');
    }

    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse, // Still needed for BLE scanning
    ];

    final statuses = await permissions.request();

    bool allGranted = true;
    for (final permission in permissions) {
      final status = statuses[permission];
      if (kDebugMode) {
        print('📋 PermissionsHelper: ${permission.toString()}: $status');
      }
      if (status != PermissionStatus.granted) {
        allGranted = false;
      }
    }

    if (kDebugMode) {
      print(allGranted 
        ? '✅ PermissionsHelper: All Android 12+ BLE permissions granted' 
        : '❌ PermissionsHelper: Some Android 12+ BLE permissions denied');
    }

    return allGranted;
  }

  /// Request legacy Android BLE permissions
  static Future<bool> _requestLegacyAndroidPermissions() async {
    if (kDebugMode) {
      print('🔐 PermissionsHelper: Requesting legacy Android BLE permissions...');
    }

    final permissions = [
      Permission.bluetooth,
      Permission.locationWhenInUse,
      Permission.location,
    ];

    final statuses = await permissions.request();

    bool allGranted = true;
    for (final permission in permissions) {
      final status = statuses[permission];
      if (kDebugMode) {
        print('📋 PermissionsHelper: ${permission.toString()}: $status');
      }
      if (status != PermissionStatus.granted) {
        allGranted = false;
      }
    }

    if (kDebugMode) {
      print(allGranted 
        ? '✅ PermissionsHelper: All legacy Android BLE permissions granted' 
        : '❌ PermissionsHelper: Some legacy Android BLE permissions denied');
    }

    return allGranted;
  }

  /// Request iOS BLE permissions
  static Future<bool> _requestIOSPermissions() async {
    if (kDebugMode) {
      print('🔐 PermissionsHelper: Requesting iOS BLE permissions...');
    }

    // iOS handles the Bluetooth permission prompt automatically on first BLE access.
    // We must check both hardware support and user authorization state:
    // - isSupported: true even when user has denied access
    // - adapterState: .unauthorized when the user has denied Bluetooth
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        if (kDebugMode) {
          print('❌ PermissionsHelper: iOS Bluetooth hardware not supported');
        }
        return false;
      }

      // Wait briefly for the adapter state to settle, then check authorization
      final adapterState = await FlutterBluePlus.adapterState
          .firstWhere(
            (s) => s != BluetoothAdapterState.unknown,
            orElse: () => BluetoothAdapterState.unknown,
          )
          .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.unknown);

      if (kDebugMode) {
        print('📡 PermissionsHelper: iOS adapter state: $adapterState');
      }

      if (adapterState == BluetoothAdapterState.unauthorized) {
        if (kDebugMode) {
          print('❌ PermissionsHelper: iOS Bluetooth permission denied by user');
        }
        return false;
      }

      if (adapterState == BluetoothAdapterState.unavailable) {
        if (kDebugMode) {
          print('❌ PermissionsHelper: iOS Bluetooth unavailable');
        }
        return false;
      }

      if (kDebugMode) {
        print('✅ PermissionsHelper: iOS Bluetooth authorized (state: $adapterState)');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ PermissionsHelper: iOS Bluetooth check failed: $e');
      }
      return false;
    }
  }

  /// Check if BLE is available and permissions are granted
  static Future<bool> checkBLEPermissions() async {
    if (kDebugMode) {
      print('🔍 PermissionsHelper: Checking BLE permissions...');
    }

    try {
      // Check if Bluetooth is supported
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        if (kDebugMode) {
          print('❌ PermissionsHelper: Bluetooth not supported on this device');
        }
        return false;
      }

      // Check Bluetooth adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (kDebugMode) {
        print('📡 PermissionsHelper: Bluetooth adapter state: $adapterState');
      }

      if (adapterState == BluetoothAdapterState.on) {
        if (kDebugMode) {
          print('✅ PermissionsHelper: Bluetooth is available and ready');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ PermissionsHelper: Bluetooth adapter not ready: $adapterState');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ PermissionsHelper: Error checking BLE permissions: $e');
      }
      return false;
    }
  }

  /// Check specific permission status without requesting
  static Future<bool> isPermissionGranted(Permission permission) async {
    try {
      final status = await permission.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      if (kDebugMode) {
        print('❌ PermissionsHelper: Error checking permission $permission: $e');
      }
      return false;
    }
  }

  /// Get a human-readable status message for BLE state
  static String getBLEStatusMessage(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.unknown:
        return 'Bluetooth state unknown';
      case BluetoothAdapterState.unavailable:
        return 'Bluetooth unavailable on this device';
      case BluetoothAdapterState.unauthorized:
        return 'Bluetooth permissions not granted';
      case BluetoothAdapterState.turningOn:
        return 'Bluetooth is turning on...';
      case BluetoothAdapterState.on:
        return 'Bluetooth is ready';
      case BluetoothAdapterState.turningOff:
        return 'Bluetooth is turning off...';
      case BluetoothAdapterState.off:
        return 'Bluetooth is turned off';
    }
  }

  /// Show permissions dialog if needed
  static Future<void> showPermissionDialog() async {
    if (kDebugMode) {
      print('💬 PermissionsHelper: Showing permission dialog guidance');
    }
    
    // This could show a dialog explaining why permissions are needed
    // For now, just log the guidance
    if (kDebugMode) {
      print('''
📝 Permission Guide:
- Bluetooth permissions are required for device communication
- Location permissions are needed for Bluetooth scanning on Android
- Please grant all requested permissions for full functionality
      ''');
    }
  }

  /// Check if platform supports BLE
  static bool isPlatformSupported() {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Request microphone permissions for AI voice assistant
  static Future<bool> requestMicrophonePermission() async {
    if (kDebugMode) {
      print('🎙️ PermissionsHelper: Requesting microphone permission...');
    }

    final status = await Permission.microphone.request();

    if (kDebugMode) {
      print('📋 PermissionsHelper: Microphone permission: $status');
    }

    if (status.isGranted) {
      if (kDebugMode) {
        print('✅ PermissionsHelper: Microphone permission granted');
      }
      return true;
    } else {
      if (kDebugMode) {
        print('❌ PermissionsHelper: Microphone permission denied');
      }
      return false;
    }
  }

  /// Check microphone permission status
  static Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }
}
