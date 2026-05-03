import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/services/json_rpc_service.dart';
import '../models/services/firebase_database_service.dart';

/// Controller for managing user profile and preferences
class ProfileController extends ChangeNotifier {
  final JsonRpcService _jsonRpcService;
  final FirebaseDatabaseService _databaseService;

  ProfileController({
    JsonRpcService? jsonRpcService,
    FirebaseDatabaseService? databaseService,
  })  : _jsonRpcService = jsonRpcService ?? JsonRpcService(),
        _databaseService = databaseService ?? FirebaseDatabaseService() {
    _loadUserPreferences();
  }

  // User info
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // User preferences for NFC
  double _mainLightBrightness = 75.0;
  double _galleryLightBrightness = 60.0;
  bool _mainLightsOn = true;
  bool _galleryLightsOn = true;
  double _preferredCabinTemp = 72.0;

  // Loading state
  bool _isLoading = false;
  String? _errorMessage;

  // Getters for preferences
  double get mainLightBrightness => _mainLightBrightness;
  double get galleryLightBrightness => _galleryLightBrightness;
  bool get mainLightsOn => _mainLightsOn;
  bool get galleryLightsOn => _galleryLightsOn;
  double get preferredCabinTemp => _preferredCabinTemp;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Get greeting based on time of day
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  /// Get user display name
  String get userName => currentUser?.displayName ?? 'Guest User';

  /// Get user email
  String get userEmail => currentUser?.email ?? '';

  /// Get user photo URL
  String? get userPhotoUrl => currentUser?.photoURL;
  
  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Set main light brightness
  void setMainLightBrightness(double brightness) {
    _mainLightBrightness = brightness.clamp(0.0, 100.0);
    notifyListeners();
    _savePreferences();
  }

  /// Set gallery light brightness
  void setGalleryLightBrightness(double brightness) {
    _galleryLightBrightness = brightness.clamp(0.0, 100.0);
    notifyListeners();
    _savePreferences();
  }

  /// Toggle main lights
  void toggleMainLights() {
    _mainLightsOn = !_mainLightsOn;
    notifyListeners();
    _savePreferences();
  }

  /// Toggle gallery lights
  void toggleGalleryLights() {
    _galleryLightsOn = !_galleryLightsOn;
    notifyListeners();
    _savePreferences();
  }

  /// Set preferred cabin temperature
  void setPreferredCabinTemp(double temp) {
    _preferredCabinTemp = temp.clamp(50.0, 90.0);
    notifyListeners();
    _savePreferences();
  }

  /// Load user preferences from Firebase
  Future<void> _loadUserPreferences() async {
    final user = currentUser;
    if (user == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await _databaseService.getUserPreferences(user.uid);
      
      if (prefs != null) {
        _mainLightBrightness = (prefs['mainLightBrightness'] as num?)?.toDouble() ?? 75.0;
        _galleryLightBrightness = (prefs['galleryLightBrightness'] as num?)?.toDouble() ?? 60.0;
        _mainLightsOn = (prefs['mainLightsOn'] as bool?) ?? true;
        _galleryLightsOn = (prefs['galleryLightsOn'] as bool?) ?? true;
        _preferredCabinTemp = (prefs['preferredCabinTemp'] as num?)?.toDouble() ?? 72.0;
        
        if (kDebugMode) {
          print('ProfileController: Loaded user preferences successfully');
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load preferences: $e';
      if (kDebugMode) {
        print('ProfileController: Error loading preferences: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save user preferences to Firebase
  Future<void> _savePreferences() async {
    final user = currentUser;
    if (user == null) return;

    try {
      await _databaseService.saveUserPreferences(user.uid, {
        'mainLightBrightness': _mainLightBrightness,
        'galleryLightBrightness': _galleryLightBrightness,
        'mainLightsOn': _mainLightsOn,
        'galleryLightsOn': _galleryLightsOn,
        'preferredCabinTemp': _preferredCabinTemp,
      });
      
      if (kDebugMode) {
        print('ProfileController: Saved user preferences successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ProfileController: Error saving preferences: $e');
      }
    }
  }

  /// Apply NFC preferences to the system
  Future<void> applyNFCPreferences() async {
    if (!_jsonRpcService.isConnected) {
      if (kDebugMode) {
        print('ProfileController: Cannot apply NFC preferences - not connected to backend');
      }
      return;
    }

    try {
      // Send lighting preferences
      _jsonRpcService.sendNotification('lighting.set', {
        'zone': 'main',
        'on': _mainLightsOn,
        'brightness': _mainLightBrightness,
      });

      _jsonRpcService.sendNotification('lighting.set', {
        'zone': 'gallery',
        'on': _galleryLightsOn,
        'brightness': _galleryLightBrightness,
      });

      // Send climate preference
      _jsonRpcService.sendNotification('climate.set', {
        'mode': 'auto',
        'setpoint': _preferredCabinTemp,
      });

      if (kDebugMode) {
        print('ProfileController: Applied NFC preferences to backend');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ProfileController: Error applying NFC preferences: $e');
      }
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    if (currentUser == null) {
      if (kDebugMode) {
        print('ProfileController: No user to sign out');
      }
      return;
    }
    
    try {
      await FirebaseAuth.instance.signOut();
      if (kDebugMode) {
        print('ProfileController: User signed out successfully');
      }
    } catch (e) {
      _errorMessage = 'Failed to sign out: $e';
      if (kDebugMode) {
        print('ProfileController: Error signing out: $e');
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
