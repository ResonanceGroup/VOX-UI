import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import './constants.dart';
import './services/json_rpc_service.dart';

/// NFCModel - Manages NFC tag scanning functionality
/// Part of the Model layer in MVC architecture
/// 
/// Responsibilities:
/// - Handle NFC availability checking
/// - Manage NFC scanning sessions (single and continuous)
/// - Extract tag IDs from discovered tags
/// - Send tag scan notifications to backend
/// - Manage NFC session lifecycle
class NFCModel extends ChangeNotifier {
  final JsonRpcService _jsonRpcService;
  
  String? _tagId = AppConstants.noTagScanned;
  bool _nfcSessionActive = false;
  bool _isScanningLoopRunning = false;
  String? _currentUserId;
  DateTime? _lastScanTime;
  Map<String, dynamic>? _pendingPreferences;

  NFCModel({required JsonRpcService jsonRpcService})
      : _jsonRpcService = jsonRpcService;

  // Getters
  String? get tagId => _tagId;
  bool get isScanning => _nfcSessionActive;

  /// Set the current user ID for sending notifications
  void setUserId(String? userId) {
    _currentUserId = userId;
  }

  /// Start a single NFC scan (for button-triggered scanning)
  /// Pass user preferences to be sent with the tag notification
  /// Returns true if scan was started successfully, false otherwise
  Future<bool> startSingleScan({Map<String, dynamic>? userPreferences}) async {
    _pendingPreferences = userPreferences;
    if (kIsWeb) {
      return false;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    try {
      bool isAvailable = await NfcManager.instance.isAvailable().timeout(
        AppConstants.nfcTimeout,
        onTimeout: () => false,
      );

      if (!isAvailable) {
        return false;
      }

      // Start single scan session
      await _startSingleScanSession();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('NFCModel: Error starting single NFC scan: $e');
      }
      return false;
    }
  }

  /// Check NFC availability and start scanning if available
  Future<void> startScanning() async {
    if (kIsWeb) {
      _tagId = AppConstants.noTagScanned;
      notifyListeners();
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      _tagId = AppConstants.nfcNotSupportedPlatform;
      notifyListeners();
      return;
    }

    try {
      bool isAvailable = await NfcManager.instance.isAvailable().timeout(
        AppConstants.nfcTimeout,
        onTimeout: () => false,
      );

      if (isAvailable) {
        _tagId = AppConstants.nfcAvailable;
        notifyListeners();

        // Start continuous scanning for iOS and Android
        if (Platform.isIOS || Platform.isAndroid) {
          _startContinuousScanning();
        } else {
          _startSingleScanSession();
        }
      } else {
        _tagId = 'NFC is not available';
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('NFCModel: Error checking NFC availability: $e');
      }
      _tagId = 'Error checking NFC: $e';
      notifyListeners();
    }
  }

  /// Check NFC status for debugging
  Future<Map<String, dynamic>> checkNFCStatus() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      
      if (kDebugMode) {
        print('=== NFC Debug Info ===');
        print('Platform: ${Platform.operatingSystem}');
        print('NFC Available: $isAvailable');
        print('Web: $kIsWeb');
        print('======================');
      }

      return {
        'available': isAvailable,
        'platform': Platform.operatingSystem,
        'isWeb': kIsWeb,
      };
    } catch (e) {
      if (kDebugMode) {
        print('NFCModel: Error checking NFC status: $e');
      }
      return {
        'available': false,
        'error': e.toString(),
      };
    }
  }

  /// Start continuous NFC scanning (iOS optimized)
  Future<void> _startContinuousScanning() async {
    if (_isScanningLoopRunning) return;

    _isScanningLoopRunning = true;
    _nfcSessionActive = true;
    notifyListeners();

    while (_nfcSessionActive) {
      try {
        await _startSingleScanSession(continuous: true);
        // Small delay before restarting session
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        if (kDebugMode) {
          print('NFCModel: Error in continuous scanning loop: $e');
        }
        // Wait longer on error
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    _isScanningLoopRunning = false;
  }

  /// Stop any active NFC session safely
  Future<void> _stopNfcSessionSafely() async {
    try {
      await NfcManager.instance.stopSession();
      if (kDebugMode) {
        print('NFCModel: NFC session stopped successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NFCModel: No active NFC session to stop: $e');
      }
    }
  }

  /// Start a single NFC scan session
  Future<void> _startSingleScanSession({bool continuous = false}) async {
    try {
      // For single-shot scans, stop any existing session first
      if (!continuous) await _stopNfcSessionSafely();

      // Small delay to ensure session cleanup
      await Future.delayed(const Duration(milliseconds: 300));

      // Check if NFC is available before starting
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        if (kDebugMode) {
          print('NFCModel: NFC is not available on this device');
        }
        return;
      }

      if (kDebugMode) {
        print('NFCModel: Starting new NFC session...');
      }

      _nfcSessionActive = true;
      notifyListeners();

      // Start NFC session
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Hold your iPhone near the NFC tag',
        invalidateAfterFirstReadIos: true,
        onDiscovered: (NfcTag tag) async {
          if (kDebugMode) {
            print('NFCModel: NFC tag discovered!');
            print('NFCModel: Raw tag data: ${tag.data}');
          }

          String tagID = await _extractTagId(tag);

          // Always update and send notification, even for empty tags
          // (empty tags are by design and still valid)
          _tagId = tagID.isNotEmpty ? tagID : 'EMPTY_TAG';
          notifyListeners();

          // Send the NFC tag ID to backend via JSON-RPC
          await _sendTagNotification(_tagId!);

          if (kDebugMode) {
            print('NFCModel: Tag scanned: ${_tagId}');
          }

          // Stop the session after successful read (only for non-continuous mode)
          if (!continuous) {
            await NfcManager.instance.stopSession(alertMessageIos: 'Tag scanned successfully!');
          }
        },
        onSessionErrorIos: (error) {
          if (kDebugMode) {
            print('NFCModel: NFC session error: ${error.message}');
          }
          
          _tagId = 'Session error: ${error.message}';
          notifyListeners();
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('NFCModel: Error starting NFC session: $e');
      }

      if (!continuous) {
        _nfcSessionActive = false;
        notifyListeners();
      }

      // Handle session already exists error
      if (e.toString().contains('session_already_exists')) {
        if (kDebugMode) {
          print('NFCModel: NFC session already exists - stopping and restarting');
        }

        try {
          await NfcManager.instance.stopSession();
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // Try again after stopping existing session
          _startSingleScanSession();
        } catch (stopError) {
          if (kDebugMode) {
            print('NFCModel: Error stopping existing NFC session: $stopError');
          }
          _tagId = 'NFC scanner conflict - please try again';
          notifyListeners();
        }
      } else {
        _tagId = 'Error starting NFC session: $e';
        notifyListeners();
      }
    } finally {
      if (!continuous) {
        _nfcSessionActive = false;
        notifyListeners();
      }
    }
  }

  /// Extract tag ID from discovered NFC tag
  Future<String> _extractTagId(NfcTag tag) async {
    String tagID = "";

    if (Platform.isAndroid) {
      if (kDebugMode) {
        print('NFCModel: Processing Android NFC tag...');
      }
      
      var nfcAndroidTag = NfcAAndroid.from(tag);
      if (nfcAndroidTag != null) {
        var androidTag = nfcAndroidTag.tag;
        tagID = androidTag.id
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join('')
            .toUpperCase();
        
        if (kDebugMode) {
          print('NFCModel: Android NFC-A tag detected');
          print('NFCModel: Tag ID bytes: ${androidTag.id}');
          print('NFCModel: Tag ID (hex): $tagID');
          print('NFCModel: Tag tech list: ${androidTag.techList}');
        }
      } else {
        if (kDebugMode) {
          print('NFCModel: No NFC-A tag found on Android');
          print('NFCModel: Available tag data: ${tag.data}');
        }
      }
    } else if (Platform.isIOS) {
      if (kDebugMode) {
        print('NFCModel: Processing iOS NFC tag...');
        print('NFCModel: Available tag data: ${tag.data}');
      }

      // Try MiFare tags first (most common)
      var miFareTag = MiFareIos.from(tag);
      if (miFareTag != null) {
        tagID = miFareTag.identifier
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join('')
            .toUpperCase();
        
        if (kDebugMode) {
          print('NFCModel: Found MiFare tag on iOS');
          print('NFCModel: MiFare identifier bytes: ${miFareTag.identifier}');
          print('NFCModel: MiFare tag ID (hex): $tagID');
          print('NFCModel: MiFare family identifier: ${miFareTag.mifareFamily}');
          print('NFCModel: MiFare historical bytes: ${miFareTag.historicalBytes}');
        }
      } else {
        // Try ISO15693 tags
        var iso15693Tag = Iso15693Ios.from(tag);
        if (iso15693Tag != null) {
          tagID = iso15693Tag.identifier
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join('')
              .toUpperCase();
          
          if (kDebugMode) {
            print('NFCModel: Found ISO15693 tag on iOS');
            print('NFCModel: ISO15693 identifier bytes: ${iso15693Tag.identifier}');
            print('NFCModel: ISO15693 tag ID (hex): $tagID');
            print('NFCModel: ISO15693 IC manufacturer code: ${iso15693Tag.icManufacturerCode}');
            print('NFCModel: ISO15693 IC serial number: ${iso15693Tag.icSerialNumber}');
          }
        } else {
          // Try FeliCa tags
          var feliCaTag = FeliCaIos.from(tag);
          if (feliCaTag != null) {
            tagID = feliCaTag.currentIDm
                .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join('')
                .toUpperCase();
            
            if (kDebugMode) {
              print('NFCModel: Found FeliCa tag on iOS');
              print('NFCModel: FeliCa currentIDm bytes: ${feliCaTag.currentIDm}');
              print('NFCModel: FeliCa tag ID (hex): $tagID');
              print('NFCModel: FeliCa currentSystemCode: ${feliCaTag.currentSystemCode}');
            }
          } else {
            // Try NDEF tags as last resort
            var ndefTag = NdefIos.from(tag);
            if (ndefTag != null) {
              // Generate ID from tag hash
              var tagHashCode = tag.hashCode.abs();
              tagID = tagHashCode.toRadixString(16).toUpperCase().padLeft(8, '0');

              if (kDebugMode) {
                print('NFCModel: Found NDEF tag on iOS');
                print('NFCModel: NDEF tag hash code: $tagHashCode');
                print('NFCModel: Generated NDEF tag ID from hash: $tagID');
              }

              // Try to read NDEF message for more specific ID
              try {
                var ndefMessage = await ndefTag.readNdef();
                if (ndefMessage != null && ndefMessage.records.isNotEmpty) {
                  if (kDebugMode) {
                    print('NFCModel: NDEF message records count: ${ndefMessage.records.length}');
                  }
                  
                  var record = ndefMessage.records.first;
                  if (kDebugMode) {
                    print('NFCModel: NDEF record TNF: ${record.typeNameFormat}');
                    print('NFCModel: NDEF record type: ${record.type}');
                    print('NFCModel: NDEF record identifier bytes: ${record.identifier}');
                    print('NFCModel: NDEF record payload: ${record.payload}');
                  }
                  
                  if (record.identifier.isNotEmpty) {
                    tagID = record.identifier
                        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                        .join('')
                        .toUpperCase();
                    if (kDebugMode) {
                      print('NFCModel: Updated NDEF tag ID from record: $tagID');
                    }
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print('NFCModel: NDEF read failed (using hash-based ID): $e');
                }
              }
            }
          }
        }
      }

      if (tagID.isEmpty && kDebugMode) {
        print('NFCModel: No compatible iOS tag type found - using fallback ID');
        tagID = tag.hashCode.abs().toRadixString(16).toUpperCase().padLeft(8, '0');
        print('NFCModel: Fallback tag ID: $tagID');
      }
    }

    if (kDebugMode) {
      print('NFCModel: ========================================');
      if (tagID.isEmpty) {
        print('NFCModel: Empty tag detected (this is normal and by design)');
        print('NFCModel: Final extracted tag ID: EMPTY_TAG');
      } else {
        print('NFCModel: Final extracted tag ID: $tagID');
      }
      print('NFCModel: ========================================');
    }

    return tagID;
  }

  /// Send NFC tag notification to backend
  Future<void> _sendTagNotification(String tagID) async {
    // Prevent duplicate scans within 3 seconds
    final now = DateTime.now();
    if (_lastScanTime != null && 
        now.difference(_lastScanTime!).inSeconds < 3) {
      if (kDebugMode) {
        print('NFCModel: Ignoring duplicate scan within 3 seconds');
      }
      return;
    }
    _lastScanTime = now;

    if (_currentUserId == null) {
      if (kDebugMode) {
        print('NFCModel: No authenticated user - cannot send NFC tag notification');
      }
      return;
    }

    try {
      // Build notification params with tag ID and user ID
      final params = <String, dynamic>{
        'tagId': tagID,
        'userId': _currentUserId,
      };

      // Add user preferences if they were provided for this scan
      if (_pendingPreferences != null) {
        params['preferences'] = _pendingPreferences;
        
        if (kDebugMode) {
          print('NFCModel: Sending NFC tag with preferences: $params');
        }
      }

      await _jsonRpcService.sendNotification('nfc.tagScanned', params);

      if (kDebugMode) {
        print('NFCModel: NFC tag notification sent: $tagID');
      }
      
      // Clear pending preferences after successful send
      _pendingPreferences = null;
    } catch (e) {
      if (kDebugMode) {
        print('NFCModel: Failed to send NFC tag notification: $e');
      }
      // Clear pending preferences even on error
      _pendingPreferences = null;
    }
  }

  /// Stop continuous NFC scanning
  void stopContinuousScanning() {
    _nfcSessionActive = false;
    _isScanningLoopRunning = false;
    notifyListeners();
    
    try {
      NfcManager.instance.stopSession(alertMessageIos: 'NFC scanning stopped');
    } catch (e) {
      if (kDebugMode) {
        print('NFCModel: Error stopping NFC session: $e');
      }
    }
  }

  /// Toggle continuous NFC scanning on/off
  void toggleContinuousScanning(bool enabled) {
    if (enabled) {
      _startContinuousScanning();
    } else {
      stopContinuousScanning();
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('NFCModel: Disposing...');
    }
    stopContinuousScanning();
    super.dispose();
  }
}
