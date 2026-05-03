import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Controllers/settings_controller.dart';
import '../models/app_preferences.dart';
import '../models/app_preferences_notifier.dart';
import '../models/services/preferences_service.dart';
import 'theme_manager.dart';

/// Settings View - Connection, LLM Profiles, Voice Endpoints
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      lazy: false,
      create: (context) => SettingsController(
        preferencesNotifier: context.read<AppPreferencesNotifier>(),
        preferencesService: context.read<PreferencesService>(),
      ),
      child: const _SettingsViewContent(),
    );
  }
}

class _SettingsViewContent extends StatelessWidget {
  const _SettingsViewContent();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferencesNotifier>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = settings.uiScale;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [const Color(0xFFF0F4F8), const Color(0xFFE1E8ED)],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: 24 * scale,
          vertical: 32 * scale,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(isDark, scale),
            SizedBox(height: 32 * scale),

            // Section A: Connection
            _buildConnectionSection(context, settings, isDark, scale),
            SizedBox(height: 24 * scale),

            // Section B: LLM Profiles
            _buildLlmProfilesSection(context, settings, isDark, scale),
            SizedBox(height: 24 * scale),

            // Section C: Voice Endpoints
            _buildVoiceEndpointsSection(context, settings, isDark, scale),
            SizedBox(height: 24 * scale),

            // UI Scaling
            _buildUIScalingSection(settings, isDark, scale),
            SizedBox(height: 24 * scale),

            // Reset
            _buildResetButton(context, settings, scale),
            SizedBox(height: 32 * scale),
          ],
        ),
      ),
    );
  }

  /// Header
  Widget _buildHeader(bool isDark, double scale) {
    return Row(
      children: [
        Icon(
          Icons.admin_panel_settings,
          size: 36,
          color: isDark ? AppColors.primaryBlue : const Color(0xFF0066CC),
        ),
        SizedBox(width: 16 * scale),
        Text(
          'Settings',
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            fontSize: 28 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ==================== Section A: Connection ====================

  Widget _buildConnectionSection(
      BuildContext context, AppPreferencesNotifier settings, bool isDark, double scale) {
    return _SettingsSection(
      title: 'Connection',
      icon: Icons.cloud_outlined,
      scale: scale,
      isDark: isDark,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          children: [
            _buildTextField(
              label: 'LiveKit Server URL',
              value: settings.livekitUrl,
              onChanged: (v) => settings.livekitUrl = v,
              scale: scale,
              isDark: isDark,
            ),
            SizedBox(height: 16 * scale),
            _buildTextField(
              label: 'Token Service URL',
              value: settings.tokenServiceUrl,
              onChanged: (v) => settings.tokenServiceUrl = v,
              scale: scale,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Section B: LLM Profiles ====================

  Widget _buildLlmProfilesSection(
      BuildContext context, AppPreferencesNotifier settings, bool isDark, double scale) {
    final profiles = settings.llmProfiles;
    final activeId = settings.activeProfileId;

    return _SettingsSection(
      title: 'LLM Profiles',
      icon: Icons.psychology_outlined,
      scale: scale,
      isDark: isDark,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profiles.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16 * scale),
                child: Text(
                  'No profiles configured. Add one in the Profiles tab.',
                  style: TextStyle(
                    fontSize: 14 * scale,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              )
            else
              ...profiles.map((profile) {
                final isActive = profile.id == activeId;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8 * scale),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12 * scale),
                      side: BorderSide(
                        color: isActive
                            ? AppColors.primaryBlue
                            : (isDark ? Colors.white24 : Colors.black12),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    leading: Radio<String>(
                      value: profile.id,
                      groupValue: activeId,
                      onChanged: (_) => settings.setActiveProfileId(profile.id),
                      activeColor: AppColors.primaryBlue,
                    ),
                    title: Text(
                      profile.name,
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppColors.primaryBlue
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    subtitle: Text(
                      '${profile.modelName}\n${profile.baseUrl}',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    isThreeLine: true,
                    onTap: () => settings.setActiveProfileId(profile.id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ==================== Section C: Voice Endpoints ====================

  Widget _buildVoiceEndpointsSection(
      BuildContext context, AppPreferencesNotifier settings, bool isDark, double scale) {
    return _SettingsSection(
      title: 'Voice Endpoints',
      icon: Icons.record_voice_over_outlined,
      scale: scale,
      isDark: isDark,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          children: [
            _buildTextField(
              label: 'STT Base URL',
              value: settings.sttBaseUrl,
              onChanged: (v) => settings.sttBaseUrl = v,
              scale: scale,
              isDark: isDark,
            ),
            SizedBox(height: 16 * scale),
            _buildTextField(
              label: 'TTS Base URL',
              value: settings.ttsBaseUrl,
              onChanged: (v) => settings.ttsBaseUrl = v,
              scale: scale,
              isDark: isDark,
            ),
            SizedBox(height: 16 * scale),
            _buildTextField(
              label: 'TTS Voice',
              value: settings.ttsVoice,
              onChanged: (v) => settings.ttsVoice = v,
              scale: scale,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== UI Scaling ====================

  Widget _buildUIScalingSection(AppPreferencesNotifier settings, bool isDark, double scale) {
    return _SettingsSection(
      title: 'UI Size Scaling',
      icon: Icons.zoom_in,
      scale: scale,
      isDark: isDark,
      child: Column(
        children: [
          _SettingsRadioTile<UISize>(
            title: 'Small',
            subtitle: '85% scale',
            value: UISize.small,
            groupValue: settings.uiSize,
            onChanged: (value) => settings.setUISize(value),
            scale: scale,
          ),
          Divider(height: 1 * scale),
          _SettingsRadioTile<UISize>(
            title: 'Medium',
            subtitle: '100% scale',
            value: UISize.medium,
            groupValue: settings.uiSize,
            onChanged: (value) => settings.setUISize(value),
            scale: scale,
          ),
          Divider(height: 1 * scale),
          _SettingsRadioTile<UISize>(
            title: 'Large',
            subtitle: '115% scale',
            value: UISize.large,
            groupValue: settings.uiSize,
            onChanged: (value) => settings.setUISize(value),
            scale: scale,
          ),
        ],
      ),
    );
  }

  // ==================== Reset ====================

  Widget _buildResetButton(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: ElevatedButton.icon(
        onPressed: () => _showResetConfirmation(context, settings),
        icon: Icon(Icons.restore, size: 20 * scale),
        label: Text(
          'Reset All Settings to Defaults',
          style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, AppPreferencesNotifier settings) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset Settings?'),
          content: const Text(
            'This will reset all settings to their default values. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                settings.resetToDefaults();
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to defaults'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  // ==================== Shared Widgets ====================

  Widget _buildTextField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required double scale,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        SizedBox(height: 8 * scale),
        TextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          onChanged: onChanged,
          style: TextStyle(fontSize: 16 * scale),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
          ),
        ),
      ],
    );
  }
}

// ==================== Section Container ====================

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final double scale;
  final bool isDark;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.child,
    required this.scale,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8 * scale,
            offset: Offset(0, 4 * scale),
          ),
        ],
        border: Border.all(
          color: isDark
              ? AppColors.primaryBlue.withOpacity(0.3)
              : const Color(0xFF0066CC).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primaryBlue.withOpacity(0.15)
                  : const Color(0xFF0066CC).withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16 * scale),
                topRight: Radius.circular(16 * scale),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24 * scale,
                  color: isDark ? AppColors.primaryBlue : const Color(0xFF0066CC),
                ),
                SizedBox(width: 12 * scale),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.primaryBlue : const Color(0xFF0066CC),
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ==================== Radio Tile ====================

class _SettingsRadioTile<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;
  final double scale;

  const _SettingsRadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      title: Text(
        title,
        style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 14 * scale),
      ),
      value: value,
      groupValue: groupValue,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      activeColor: AppColors.primaryBlue,
    );
  }
}
