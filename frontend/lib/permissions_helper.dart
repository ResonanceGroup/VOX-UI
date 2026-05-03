import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class to handle permissions for VoxUI
class PermissionsHelper {
  /// Request microphone permission for AI voice assistant
  static Future<bool> requestMicrophonePermission() async {
    if (kDebugMode) {
      print('PermissionsHelper: Requesting microphone permission...');
    }

    final status = await Permission.microphone.request();

    if (kDebugMode) {
      print('PermissionsHelper: Microphone permission: $status');
    }

    return status.isGranted;
  }

  /// Check microphone permission status
  static Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Check if platform supports microphone
  static bool isPlatformSupported() {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }
}
