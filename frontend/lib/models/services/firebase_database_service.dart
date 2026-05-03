import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:rg_smart_control/models/constants.dart';

/// Service for managing Firebase Realtime Database operations
/// Provides global access throughout the app for user data and real-time updates
class FirebaseDatabaseService {
  static final FirebaseDatabaseService _instance = FirebaseDatabaseService._internal();
  factory FirebaseDatabaseService() => _instance;
  FirebaseDatabaseService._internal();

  late final DatabaseReference _database;
  late final DatabaseReference _usersRef;
  
  // Database rules configured in Firebase Console:
  // {
  //   "rules": {
  //     "users": {
  //       "$uid": {
  //         ".read": "auth != null && auth.uid == $uid",
  //         ".write": "auth != null && auth.uid == $uid",
  //         "email": {
  //           ".validate": "newData.isString() && newData.val().length > 0"
  //         },
  //         "rv_settings": {
  //           "temperature": {
  //             ".validate": "newData.isNumber() && newData.val() >= 0 && newData.val() <= 200"
  //           },
  //           "lighting": {
  //             ".validate": "newData.isString() && newData.val().length > 0"
  //           },
  //           "last_updated": {
  //             ".validate": "newData.isNumber() && newData.val() > 0"
  //           }
  //         }
  //       }
  //     }
  //   }
  // }
  
  /// Initialize the database service
  /// Call this once in main.dart after Firebase initialization
  void initialize() {
    _database = FirebaseDatabase.instance.ref();
    _usersRef = _database.child('users');
    
    // Configure database URL for your specific Firebase project
    FirebaseDatabase.instance.databaseURL = AppConstants.firebaseDatabaseUrl;
    
    if (kDebugMode) {
      print('Firebase Database Service initialized with URL: ${AppConstants.firebaseDatabaseUrl}');
    }
  }

  /// Creates a user profile using Firebase's auto-generated UID
  Future<UserProfile> createUserProfile({
    required String firebaseUid,
    required String email,
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (kDebugMode) {
        print('Creating user profile with Firebase UID: $firebaseUid');
      }

      final userProfile = UserProfile(
        firebaseUid: firebaseUid,
        email: email,
      );

      // Create default RV settings for new user
      final defaultRVSettings = {
        'thermostatControl_setTemperature': AppConstants.defaultTemperatureCelsius, // Default temperature: 22°C
        'lights_all_brightness': AppConstants.defaultBrightness.toString(), // Default lighting: 50% brightness as string
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      // Save user profile and default RV settings to database
      final userRef = _usersRef.child(firebaseUid);
      await userRef.set({
        ...userProfile.toMap(),
        'rv_settings': defaultRVSettings,
      });
      
      if (kDebugMode) {
        print('User profile successfully created for Firebase UID: $firebaseUid');
        print('Default RV settings: $defaultRVSettings');
      }
      
      return userProfile;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating user profile for Firebase UID $firebaseUid: $e');
      }
      rethrow;
    }
  }

  /// Gets user profile by Firebase UID
  Future<UserProfile?> getUserProfile(String firebaseUid) async {
    try {
      final snapshot = await _usersRef.child(firebaseUid).get();
      if (snapshot.exists) {
        if (kDebugMode) {
          print('Retrieved user profile for Firebase UID: $firebaseUid');
        }
        return UserProfile.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map),
          firebaseUid,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user profile for Firebase UID $firebaseUid: $e');
      }
      return null;
    }
  }

  /// Checks if user profile exists
  Future<bool> userProfileExists(String firebaseUid) async {
    try {
      final snapshot = await _usersRef.child(firebaseUid).get();
      final exists = snapshot.exists;
      if (kDebugMode) {
        print('User profile exists check for Firebase UID $firebaseUid: $exists');
      }
      return exists;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking user profile existence for Firebase UID $firebaseUid: $e');
      }
      return false;
    }
  }

  /// Listen to user profile changes in real-time
  Stream<UserProfile?> watchUserProfile(String firebaseUid) {
    return _usersRef.child(firebaseUid).onValue.map((event) {
      if (event.snapshot.exists) {
        return UserProfile.fromMap(
          Map<String, dynamic>.from(event.snapshot.value as Map),
          firebaseUid,
        );
      }
      return null;
    });
  }

  /// Update user profile data
  Future<void> updateUserProfile(String firebaseUid, Map<String, dynamic> updates) async {
    try {
      await _usersRef.child(firebaseUid).update(updates);
      if (kDebugMode) {
        print('Updated user profile for Firebase UID: $firebaseUid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user profile for Firebase UID $firebaseUid: $e');
      }
      rethrow;
    }
  }

  /// Update RV settings in the database
  Future<void> updateRVData(String firebaseUid, Map<String, dynamic> rvData) async {
    try {
      // Update RV settings under the user's profile
      final rvRef = _usersRef.child(firebaseUid).child('rvSettings');
      await rvRef.update({
        ...rvData,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });
      
      if (kDebugMode) {
        print('RV settings updated for Firebase UID: $firebaseUid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating RV settings for Firebase UID $firebaseUid: $e');
      }
      rethrow;
    }
  }

  /// Listen to RV settings changes in real-time
  Stream<Map<String, dynamic>?> watchRVData(String firebaseUid) {
    return _usersRef.child(firebaseUid).child('rv_settings').onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  /// Get RV settings once
  Future<Map<String, dynamic>?> getRVData(String firebaseUid) async {
    try {
      final snapshot = await _usersRef.child(firebaseUid).child('rvSettings').get();
      if (snapshot.exists) {
        if (kDebugMode) {
          print('Retrieved RV settings for Firebase UID: $firebaseUid');
        }
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting RV settings for Firebase UID $firebaseUid: $e');
      }
      return null;
    }
  }

  /// Get user preferences (for NFC and profile settings)
  Future<Map<String, dynamic>?> getUserPreferences(String firebaseUid) async {
    try {
      final snapshot = await _usersRef.child(firebaseUid).child('preferences').get();
      if (snapshot.exists) {
        if (kDebugMode) {
          print('Retrieved user preferences for Firebase UID: $firebaseUid');
        }
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user preferences for Firebase UID $firebaseUid: $e');
      }
      return null;
    }
  }

  /// Save user preferences (for NFC and profile settings)
  Future<void> saveUserPreferences(String firebaseUid, Map<String, dynamic> preferences) async {
    try {
      final prefsRef = _usersRef.child(firebaseUid).child('preferences');
      await prefsRef.update({
        ...preferences,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });
      
      if (kDebugMode) {
        print('User preferences updated for Firebase UID: $firebaseUid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user preferences for Firebase UID $firebaseUid: $e');
      }
      rethrow;
    }
  }

  /// Delete user data (for account deletion)
  Future<void> deleteUserData(String firebaseUid) async {
    try {
      await _usersRef.child(firebaseUid).remove();
      if (kDebugMode) {
        print('Deleted all user data for Firebase UID: $firebaseUid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting user data for Firebase UID $firebaseUid: $e');
      }
      rethrow;
    }
  }
}

/// User profile model - Updated to match database structure
class UserProfile {
  final String firebaseUid; // Using Firebase's auto-generated UID
  final String email;

  UserProfile({
    required this.firebaseUid,
    required this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      // Note: firebaseUid is used as the key, not stored as a field
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String firebaseUid) {
    return UserProfile(
      firebaseUid: firebaseUid,
      email: map['email'] ?? '',
    );
  }

  UserProfile copyWith({
    String? firebaseUid,
    String? email,
  }) {
    return UserProfile(
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
    );
  }

  @override
  String toString() {
    return 'UserProfile(firebaseUid: $firebaseUid, email: $email)';
  }
}
