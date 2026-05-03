import 'package:flutter/foundation.dart';
import '../models/app_preferences_notifier.dart';
import '../models/llm_profile.dart';

/// Controller for managing LLM profiles
/// Bridges the UI with AppPreferencesNotifier for profile CRUD operations
class ProfileController extends ChangeNotifier {
  final AppPreferencesNotifier _preferencesNotifier;

  ProfileController({
    required AppPreferencesNotifier preferencesNotifier,
  }) : _preferencesNotifier = preferencesNotifier;

  /// Get all profiles
  List<LlmProfile> get profiles => _preferencesNotifier.llmProfiles;

  /// Get active profile
  LlmProfile? get activeProfile => _preferencesNotifier.activeProfile;

  /// Get active profile ID
  String? get activeProfileId => _preferencesNotifier.activeProfileId;

  /// Add a new profile
  Future<void> addProfile(LlmProfile profile) async {
    await _preferencesNotifier.addLlmProfile(profile);
  }

  /// Update an existing profile
  Future<void> updateProfile(LlmProfile profile) async {
    await _preferencesNotifier.updateLlmProfile(profile);
  }

  /// Delete a profile by ID
  Future<void> deleteProfile(String id) async {
    await _preferencesNotifier.deleteLlmProfile(id);
  }

  /// Set the active profile
  Future<void> setActiveProfile(String id) async {
    await _preferencesNotifier.setActiveProfileId(id);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
