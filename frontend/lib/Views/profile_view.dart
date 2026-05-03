import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../Controllers/profile_controller.dart';
import '../models/services/json_rpc_service.dart';
import '../models/services/firebase_database_service.dart';
import '../models/app_preferences_notifier.dart';
import '../Views/theme_manager.dart';
import '../models/constants.dart';

/// Profile subview with user info, preferences, and logout
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfileController(
        jsonRpcService: context.read<JsonRpcService>(),
        databaseService: context.read<FirebaseDatabaseService>(),
      ),
      child: const _ProfileViewContent(),
    );
  }
}

class _ProfileViewContent extends StatelessWidget {
  const _ProfileViewContent();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final settings = context.watch<AppPreferencesNotifier>();
    final scale = settings.uiScale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 900;
          final horizontalPadding = constraints.maxWidth < 400 
              ? 16.0 * scale 
              : (isLargeScreen ? 24.0 : 24.0) * scale;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 32 * scale,
            ),
            child: isLargeScreen
                ? _buildLargeScreenLayout(controller, isDark, scale, context)
                : _buildSmallScreenLayout(controller, isDark, scale, context),
          );
        },
      ),
    );
  }

  /// Large screen layout (grid with header + 2-column cards)
  Widget _buildLargeScreenLayout(
      ProfileController controller, bool isDark, double scale, BuildContext context) {
    return Column(
      children: [
        // User Profile Header (full width)
        _UserProfileHeader(controller: controller, scale: scale),
        SizedBox(height: 32 * scale),

        // Row: Light Preferences + Temperature Preference
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LightPreferencesCard(controller: controller, scale: scale),
            ),
            SizedBox(width: 24 * scale),
            Expanded(
              child: _TemperaturePreferenceCard(controller: controller, scale: scale),
            ),
          ],
        ),
        SizedBox(height: 24 * scale),

        // Logout/Guest Mode (full width)
        if (controller.isSignedIn) ...[
          _LogoutButton(controller: controller, scale: scale),
          SizedBox(height: 32 * scale),
        ] else ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12 * scale),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 24 * scale,
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Text(
                    'Guest Mode - Preferences stored locally',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14 * scale,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32 * scale),
        ],
      ],
    );
  }

  /// Small screen layout (single column)
  Widget _buildSmallScreenLayout(
      ProfileController controller, bool isDark, double scale, BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _UserProfileHeader(controller: controller, scale: scale),
        SizedBox(height: 32 * scale),

        _LightPreferencesCard(controller: controller, scale: scale),
        SizedBox(height: 24 * scale),

        _TemperaturePreferenceCard(controller: controller, scale: scale),
        SizedBox(height: 24 * scale),

        if (controller.isSignedIn) ...[
          _LogoutButton(controller: controller, scale: scale),
          SizedBox(height: 32 * scale),
        ] else ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12 * scale),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 24 * scale,
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Text(
                    'Guest Mode - Preferences stored locally',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14 * scale,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32 * scale),
        ],
      ],
    );
  }
}

/// User profile header with greeting and avatar
class _UserProfileHeader extends StatelessWidget {
  final ProfileController controller;
  final double scale;

  const _UserProfileHeader({required this.controller, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((isTablet ? 32 : 24) * scale),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20 * scale),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 8 * scale,
            spreadRadius: 2 * scale,
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: (isTablet ? 60 : 50) * scale,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
            child: controller.userPhotoUrl != null
                ? ClipOval(
                    child: Image.network(
                      controller.userPhotoUrl!,
                      width: (isTablet ? 120 : 100) * scale,
                      height: (isTablet ? 120 : 100) * scale,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          size: (isTablet ? 60 : 50) * scale,
                          color: AppColors.primaryBlue,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: (isTablet ? 60 : 50) * scale,
                    color: AppColors.primaryBlue,
                  ),
          ),
          SizedBox(height: 16 * scale),

          // Greeting
          Text(
            '${controller.getGreeting()},',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: (isTablet ? 20 : 18) * scale,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 4 * scale),

          // User Name
          Text(
            controller.userName,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: (isTablet ? 32 : 28) * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8 * scale),

          // Email
          if (controller.userEmail.isNotEmpty)
            Text(
              controller.userEmail,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black45,
                fontSize: (isTablet ? 16 : 14) * scale,
              ),
            ),
        ],
      ),
    );
  }
}

/// Light preferences card
class _LightPreferencesCard extends StatelessWidget {
  final ProfileController controller;
  final double scale;

  const _LightPreferencesCard({required this.controller, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((isTablet ? 24 : 20) * scale),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20 * scale),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 8 * scale,
            spreadRadius: 2 * scale,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: AppColors.primaryBlue,
                size: (isTablet ? 28 : 24) * scale,
              ),
              SizedBox(width: 12 * scale),
              Text(
                'Light Preferences',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: (isTablet ? 24 : 20) * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 24 * scale),

          // Main Lights Section
          _LightSection(
            label: 'Main Lights',
            isOn: controller.mainLightsOn,
            brightness: controller.mainLightBrightness,
            onToggle: controller.toggleMainLights,
            onBrightnessChanged: controller.setMainLightBrightness,
            scale: scale,
          ),
          SizedBox(height: 20 * scale),

          // Divider
          Container(
            height: 1 * scale,
            color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
          ),
          SizedBox(height: 20 * scale),

          // Gallery Lights Section
          _LightSection(
            label: 'Gallery Lights',
            isOn: controller.galleryLightsOn,
            brightness: controller.galleryLightBrightness,
            onToggle: controller.toggleGalleryLights,
            onBrightnessChanged: controller.setGalleryLightBrightness,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

/// Individual light section with toggle and brightness
class _LightSection extends StatelessWidget {
  final String label;
  final bool isOn;
  final double brightness;
  final VoidCallback onToggle;
  final ValueChanged<double> onBrightnessChanged;
  final double scale;

  const _LightSection({
    required this.label,
    required this.isOn,
    required this.brightness,
    required this.onToggle,
    required this.onBrightnessChanged,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label and Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            _CustomToggleSwitch(
              isOn: isOn,
              onToggle: onToggle,
              scale: scale,
            ),
          ],
        ),
        SizedBox(height: 16 * scale),

        // Brightness Slider
        Row(
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              color: isDark ? Colors.white60 : Colors.black45,
              size: 20 * scale,
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primaryBlue,
                  inactiveTrackColor: isDark
                      ? const Color(0xFF333333)
                      : const Color(0xFFE0E0E0),
                  thumbColor: AppColors.primaryBlue,
                  overlayColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10 * scale),
                  trackHeight: 6 * scale,
                ),
                child: Slider(
                  value: brightness,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: onBrightnessChanged,
                ),
              ),
            ),
            SizedBox(width: 12 * scale),
            SizedBox(
              width: 45 * scale,
              child: Text(
                '${brightness.round()}%',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Temperature preference card
class _TemperaturePreferenceCard extends StatelessWidget {
  final ProfileController controller;
  final double scale;

  const _TemperaturePreferenceCard({required this.controller, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((isTablet ? 24 : 20) * scale),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20 * scale),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 8 * scale,
            spreadRadius: 2 * scale,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.thermostat,
                color: AppColors.primaryBlue,
                size: (isTablet ? 28 : 24) * scale,
              ),
              SizedBox(width: 12 * scale),
              Text(
                'Cabin Temperature',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: (isTablet ? 24 : 20) * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 24 * scale),

          // Temperature Display and Slider
          Column(
            children: [
              // Large temperature display
              Text(
                '${controller.preferredCabinTemp.round()}°F',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: (isTablet ? 48 : 40) * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20 * scale),

              // Temperature Slider
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primaryBlue,
                  inactiveTrackColor: isDark
                      ? const Color(0xFF333333)
                      : const Color(0xFFE0E0E0),
                  thumbColor: AppColors.primaryBlue,
                  overlayColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12 * scale),
                  trackHeight: 8 * scale,
                ),
                child: Slider(
                  value: controller.preferredCabinTemp,
                  min: 50,
                  max: 90,
                  divisions: 40,
                  onChanged: controller.setPreferredCabinTemp,
                ),
              ),
              SizedBox(height: 8 * scale),

              // Min/Max labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '50°F',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black45,
                      fontSize: 14 * scale,
                    ),
                  ),
                  Text(
                    '90°F',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black45,
                      fontSize: 14 * scale,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Logout button
class _LogoutButton extends StatelessWidget {
  final ProfileController controller;
  final double scale;

  const _LogoutButton({required this.controller, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );

          if (confirmed == true && context.mounted) {
            try {
              await controller.signOut();
              if (context.mounted) {
                context.go(AppConstants.homeRoute);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to sign out: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
        icon: Icon(Icons.logout, size: 24 * scale),
        label: Text(
          'Log Out',
          style: TextStyle(
            fontSize: (isTablet ? 18 : 16) * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: (isTablet ? 20 : 16) * scale,
            horizontal: 24 * scale,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * scale),
          ),
        ),
      ),
    );
  }
}

/// Custom toggle switch matching the app style
class _CustomToggleSwitch extends StatelessWidget {
  final bool isOn;
  final VoidCallback onToggle;
  final double scale;

  const _CustomToggleSwitch({
    required this.isOn,
    required this.onToggle,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 52 * scale,
        height: 28 * scale,
        decoration: BoxDecoration(
          color: isOn
              ? AppColors.primaryBlue
              : (Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.cardAccentDark 
                  : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(14 * scale),
        ),
        child: Padding(
          padding: EdgeInsets.all(3 * scale),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22 * scale,
              height: 22 * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 3 * scale,
                    spreadRadius: 1 * scale,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
