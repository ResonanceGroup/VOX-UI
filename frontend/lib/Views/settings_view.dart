import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../Controllers/settings_controller.dart';
import '../models/app_preferences.dart';
import '../models/app_preferences_notifier.dart';
import '../models/services/json_rpc_service.dart';
import 'theme_manager.dart';

/// Settings View - Admin-style settings screen with live in-memory configuration
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      lazy: false,
      create: (context) => SettingsController(
        preferencesNotifier: context.read<AppPreferencesNotifier>(),
        jsonRpcService: context.read<JsonRpcService>(),
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
    
    // Apply UI scale
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 900;
          final horizontalPadding = constraints.maxWidth < 400 
              ? 16.0 * scale
              : (isLargeScreen ? 24.0 : (constraints.maxWidth > 600 ? 48.0 * scale : 24.0 * scale));
          final titleSize = (constraints.maxWidth > 600 ? 32.0 : 28.0) * scale;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 32 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section with admin icon
                _buildHeader(titleSize, context, isDark, scale),
                SizedBox(height: 32 * scale),
                
                // Layout sections
                if (isLargeScreen)
                  _buildLargeScreenLayout(context, settings, scale)
                else
                  _buildSmallScreenLayout(context, settings, scale),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Large screen layout (2-column grid)
  Widget _buildLargeScreenLayout(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return Column(
      children: [
        // Row 1: UI Scaling + Units
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildUIScalingSection(context, settings, scale),
            ),
            SizedBox(width: 24 * scale),
            Expanded(
              child: _buildUnitsSection(context, settings, scale),
            ),
          ],
        ),
        SizedBox(height: 24 * scale),

        // Row 2: RV Profile + Alerts
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildRVProfileSection(context, settings, scale),
            ),
            SizedBox(width: 24 * scale),
            Expanded(
              child: _buildAlertsSection(context, settings, scale),
            ),
          ],
        ),
        SizedBox(height: 24 * scale),

        // Row 3: Connection Status + Version
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildConnectionStatusSection(context, settings, scale),
            ),
            SizedBox(width: 24 * scale),
            Expanded(
              child: _buildVersionSection(context, settings, scale),
            ),
          ],
        ),
        SizedBox(height: 24 * scale),

        // Row 4: Diagnostics (full width)
        _buildDiagnosticsSection(context, settings, scale),
        SizedBox(height: 24 * scale),

        // Row 5: Reset Button (full width)
        _buildResetButton(context, settings, scale),
        SizedBox(height: 32 * scale),
      ],
    );
  }

  /// Small screen layout (single column)
  Widget _buildSmallScreenLayout(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUIScalingSection(context, settings, scale),
        SizedBox(height: 24 * scale),
        
        _buildUnitsSection(context, settings, scale),
        SizedBox(height: 24 * scale),
        
        _buildRVProfileSection(context, settings, scale),
        SizedBox(height: 24 * scale),
        
        _buildAlertsSection(context, settings, scale),
        SizedBox(height: 24 * scale),
        
        _buildConnectionStatusSection(context, settings, scale),
        SizedBox(height: 24 * scale),
        
        _buildVersionSection(context, settings, scale),
        SizedBox(height: 24 * scale),
        
        _buildDiagnosticsSection(context, settings, scale),
        SizedBox(height: 24 * scale),
        
        _buildResetButton(context, settings, scale),
        SizedBox(height: 32 * scale),
      ],
    );
  }

  /// Header with "Settings" title and admin icon
  Widget _buildHeader(double titleSize, BuildContext context, bool isDark, double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.admin_panel_settings,
          size: titleSize + 8,
          color: isDark ? AppColors.primaryBlue : const Color(0xFF0066CC),
        ),
        SizedBox(width: 16 * scale),
        Text(
          'Settings',
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.settings_applications,
          size: titleSize,
          color: isDark ? AppColors.accentGreen : const Color(0xFF00AA66),
        ),
      ],
    );
  }

  /// UI Size Scaling Section
  Widget _buildUIScalingSection(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return _SettingsSection(
      title: 'UI Size Scaling',
      icon: Icons.zoom_in,
      scale: scale,
      child: Column(
        children: [
          _SettingsRadioTile<UISize>(
            title: 'Small',
            subtitle: '85% scale - Compact interface',
            value: UISize.small,
            groupValue: settings.uiSize,
            onChanged: (value) => settings.setUISize(value),
            scale: scale,
          ),
          Divider(height: 1 * scale),
          _SettingsRadioTile<UISize>(
            title: 'Medium',
            subtitle: '100% scale - Default size',
            value: UISize.medium,
            groupValue: settings.uiSize,
            onChanged: (value) => settings.setUISize(value),
            scale: scale,
          ),
          Divider(height: 1 * scale),
          _SettingsRadioTile<UISize>(
            title: 'Large',
            subtitle: '115% scale - Easier to read',
            value: UISize.large,
            groupValue: settings.uiSize,
            onChanged: (value) => settings.setUISize(value),
            scale: scale,
          ),
        ],
      ),
    );
  }

  /// Units of Measurement Section
  Widget _buildUnitsSection(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return _SettingsSection(
      title: 'Units of Measurement',
      icon: Icons.straighten,
      scale: scale,
      child: Column(
        children: [
          _buildUnitToggle(
            context,
            'Temperature',
            settings.temperatureUnit == TemperatureUnit.fahrenheit ? '°F' : '°C',
            settings.temperatureUnit == TemperatureUnit.fahrenheit,
            (value) => settings.setTemperatureUnit(
              value ? TemperatureUnit.fahrenheit : TemperatureUnit.celsius,
            ),
            scale,
          ),
          Divider(height: 1 * scale),
          _buildUnitToggle(
            context,
            'Tank Volume',
            settings.volumeUnit == VolumeUnit.gallons ? 'Gallons' : 'Liters',
            settings.volumeUnit == VolumeUnit.gallons,
            (value) => settings.setVolumeUnit(
              value ? VolumeUnit.gallons : VolumeUnit.liters,
            ),
            scale,
          ),
          Divider(height: 1 * scale),
          _buildUnitToggle(
            context,
            'Distance / Speed',
            settings.distanceUnit == DistanceUnit.miles ? 'Miles/mph' : 'Km/kph',
            settings.distanceUnit == DistanceUnit.miles,
            (value) => settings.setDistanceUnit(
              value ? DistanceUnit.miles : DistanceUnit.kilometers,
            ),
            scale,
          ),
          Divider(height: 1 * scale),
          _buildUnitToggle(
            context,
            'Battery Capacity',
            settings.batteryCapacityUnit == BatteryCapacityUnit.ah ? 'Ah' : 'kWh',
            settings.batteryCapacityUnit == BatteryCapacityUnit.ah,
            (value) => settings.setBatteryCapacityUnit(
              value ? BatteryCapacityUnit.ah : BatteryCapacityUnit.kwh,
            ),
            scale,
          ),
        ],
      ),
    );
  }

  /// Unit Toggle Widget
  Widget _buildUnitToggle(
    BuildContext context,
    String label,
    String currentUnit,
    bool value,
    ValueChanged<bool> onChanged,
    double scale,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            child: Text(
              currentUnit,
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGreen,
              ),
            ),
          ),
          SizedBox(width: 12 * scale),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }

  /// My RV Profile Section
  Widget _buildRVProfileSection(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return _SettingsSection(
      title: 'My RV Profile',
      icon: Icons.rv_hookup,
      scale: scale,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          children: [
            _buildTextField(
              label: 'RV Nickname',
              value: settings.rvNickname,
              onChanged: settings.setRVNickname,
              scale: scale,
            ),
            SizedBox(height: 16 * scale),
            _buildTextField(
              label: 'Make & Model',
              value: settings.rvMakeModel,
              onChanged: settings.setRVMakeModel,
              scale: scale,
            ),
            SizedBox(height: 16 * scale),
            _buildTextField(
              label: 'Year',
              value: settings.rvYear,
              onChanged: settings.setRVYear,
              keyboardType: TextInputType.number,
              scale: scale,
            ),
            SizedBox(height: 16 * scale),
            _buildNumberField(
              label: 'Fresh Water Capacity (${settings.volumeUnitLabel})',
              value: settings.freshWaterCapacity,
              onChanged: settings.setFreshWaterCapacity,
              scale: scale,
            ),
            SizedBox(height: 16 * scale),
            _buildNumberField(
              label: 'Grey Water Capacity (${settings.volumeUnitLabel})',
              value: settings.greyWaterCapacity,
              onChanged: settings.setGreyWaterCapacity,
              scale: scale,
            ),
            SizedBox(height: 16 * scale),
            _buildNumberField(
              label: 'Black Water Capacity (${settings.volumeUnitLabel})',
              value: settings.blackWaterCapacity,
              onChanged: settings.setBlackWaterCapacity,
              scale: scale,
            ),
            SizedBox(height: 16 * scale),
            _buildNumberField(
              label: 'Propane Capacity (${settings.volumeUnitLabel})',
              value: settings.propaneCapacity,
              onChanged: settings.setPropaneCapacity,
              scale: scale,
            ),
            SizedBox(height: 16 * scale),
            _buildNumberField(
              label: 'Battery Bank Capacity (${settings.batteryCapacityUnitLabel})',
              value: settings.batteryBankCapacity,
              onChanged: settings.setBatteryBankCapacity,
              scale: scale,
            ),
            SizedBox(height: 16 * scale),
            _buildBatteryVoltageDropdown(context, settings, scale),
          ],
        ),
      ),
    );
  }

  /// Battery System Voltage Dropdown
  Widget _buildBatteryVoltageDropdown(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Battery System Voltage',
          style: TextStyle(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black87,
          ),
        ),
        SizedBox(height: 8 * scale),
        DropdownButtonFormField<BatterySystemVoltage>(
          value: settings.batterySystemVoltage,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
          ),
          items: [
            DropdownMenuItem(
              value: BatterySystemVoltage.v12,
              child: Text('12V', style: TextStyle(fontSize: 16 * scale)),
            ),
            DropdownMenuItem(
              value: BatterySystemVoltage.v24,
              child: Text('24V', style: TextStyle(fontSize: 16 * scale)),
            ),
            DropdownMenuItem(
              value: BatterySystemVoltage.v48,
              child: Text('48V', style: TextStyle(fontSize: 16 * scale)),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              settings.setBatterySystemVoltage(value);
            }
          },
        ),
      ],
    );
  }

  /// Alerts & Thresholds Section
  Widget _buildAlertsSection(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return _SettingsSection(
      title: 'Alerts & Thresholds',
      icon: Icons.warning_amber,
      scale: scale,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Battery SOC
            Text(
              'Battery State of Charge',
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGreen,
              ),
            ),
            SizedBox(height: 12 * scale),
            _buildNumberField(
              label: 'Low Warning (%)',
              value: settings.batterySOCLowWarning,
              onChanged: settings.setBatterySOCLowWarning,
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            _buildNumberField(
              label: 'Low Critical (%)',
              value: settings.batterySOCLowCritical,
              onChanged: settings.setBatterySOCLowCritical,
              scale: scale,
            ),
            SizedBox(height: 24 * scale),
            
            // Fresh Water
            Text(
              'Fresh Water Tank Level',
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGreen,
              ),
            ),
            SizedBox(height: 12 * scale),
            _buildNumberField(
              label: 'Low Warning (%)',
              value: settings.freshWaterLowWarning,
              onChanged: settings.setFreshWaterLowWarning,
              scale: scale,
            ),
            SizedBox(height: 24 * scale),
            
            // Solar Panel Current
            Text(
              'Solar Panel Current',
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGreen,
              ),
            ),
            SizedBox(height: 12 * scale),
            _buildNumberField(
              label: 'Low Warning (Amps)',
              value: settings.solarCurrentLowWarning,
              onChanged: settings.setSolarCurrentLowWarning,
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            _buildNumberField(
              label: 'High Warning (Amps)',
              value: settings.solarCurrentHighWarning,
              onChanged: settings.setSolarCurrentHighWarning,
              scale: scale,
            ),
            SizedBox(height: 24 * scale),
            
            // Solar Alert Hours
            Text(
              'Solar Alert Hours',
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGreen,
              ),
            ),
            SizedBox(height: 8 * scale),
            Text(
              'Only receive solar alerts during these hours (24-hour format)',
              style: TextStyle(
                fontSize: 12 * scale,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 12 * scale),
            Row(
              children: [
                Expanded(
                  child: _buildHourField(
                    label: 'Start Hour (0-23)',
                    value: settings.solarAlertStartHour,
                    onChanged: settings.setSolarAlertStartHour,
                    scale: scale,
                  ),
                ),
                SizedBox(width: 16 * scale),
                Expanded(
                  child: _buildHourField(
                    label: 'End Hour (0-23)',
                    value: settings.solarAlertEndHour,
                    onChanged: settings.setSolarAlertEndHour,
                    scale: scale,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Connection Status Section (Read-Only)
  Widget _buildConnectionStatusSection(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return _SettingsSection(
      title: 'Connection Status',
      icon: _getConnectionTypeIcon(settings.connectionType),
      scale: scale,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          children: [
            _buildStatusRow(
              'Overall Status',
              settings.overallStatus,
              _getOverallStatusColor(settings.overallStatus),
              scale,
            ),
            SizedBox(height: 16 * scale),
            _buildStatusRow(
              'Connection Type',
              settings.connectionType,
              _getConnectionTypeColor(settings.connectionType),
              scale,
            ),
          ],
        ),
      ),
    );
  }

  /// Get icon for connection type
  IconData _getConnectionTypeIcon(String type) {
    switch (type) {
      case 'WiFi':
        return Icons.wifi;
      case 'Ethernet':
        return Icons.cable;
      case 'Bluetooth':
        return Icons.bluetooth;
      default:
        return Icons.wifi_off;
    }
  }

  /// Get color for overall connection status label
  Color _getOverallStatusColor(String status) {
    switch (status) {
      case 'Connected':
        return AppColors.accentGreen;
      case 'Reconnecting':
        return const Color(0xFFFFAA00); // amber
      default: // 'Disconnected'
        return Colors.grey;
    }
  }

  /// Get color for connection type
  Color _getConnectionTypeColor(String type) {
    switch (type) {
      case 'WiFi':
        return AppColors.primaryBlue;
      case 'Ethernet':
        return AppColors.accentGreen;
      case 'Bluetooth':
        return const Color(0xFFAA66FF);
      default:
        return Colors.grey;
    }
  }

  /// Status Row Widget
  Widget _buildStatusRow(String label, String value, Color valueColor, double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8 * scale),
            border: Border.all(color: valueColor, width: 1.5),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14 * scale,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Version Information Section (Read-Only)
  Widget _buildVersionSection(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return _SettingsSection(
      title: 'Version Information',
      icon: Icons.info_outline,
      scale: scale,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          children: [
            _buildVersionRow('Frontend', settings.frontendVersion, scale),
            SizedBox(height: 16 * scale),
            _buildVersionRow('Backend', settings.backendVersion, scale),
          ],
        ),
      ),
    );
  }

  /// Version Row Widget
  Widget _buildVersionRow(String label, String version, double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500),
        ),
        Text(
          version,
          style: TextStyle(
            fontSize: 14 * scale,
            fontWeight: FontWeight.bold,
            color: AppColors.accentGreen,
          ),
        ),
      ],
    );
  }

  /// Reset to Defaults Button
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

  /// Vehicle Diagnostics Section
  Widget _buildDiagnosticsSection(BuildContext context, AppPreferencesNotifier settings, double scale) {
    final settingsController = context.watch<SettingsController>();
    
    return _SettingsSection(
      title: 'Vehicle Diagnostics',
      icon: Icons.car_repair,
      scale: scale,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Generate and print a comprehensive diagnostic report of all vehicle systems.',
              style: TextStyle(
                fontSize: 14 * scale,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16 * scale),
            ElevatedButton.icon(
              onPressed: () => _handlePrintDiagnostics(context, settingsController, scale),
              icon: Icon(Icons.print, size: 20 * scale),
              label: Text(
                'Print Vehicle Diagnostics',
                style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle print diagnostics button press
  Future<void> _handlePrintDiagnostics(
    BuildContext context,
    SettingsController controller,
    double scale,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: AppColors.primaryBlue),
              SizedBox(width: 20 * scale),
              const Text('Sending diagnostics request...'),
            ],
          ),
        );
      },
    );

    // Send diagnostics command
    final success = await controller.printVehicleDiagnostics();

    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Show result
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 20 * scale,
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  success
                      ? 'Diagnostics print request sent successfully'
                      : 'Failed to send diagnostics request. Please check connection.',
                  style: TextStyle(fontSize: 14 * scale),
                ),
              ),
            ],
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10 * scale),
          ),
        ),
      );
    }
  }

  /// Show reset confirmation dialog
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

  /// Text Field Widget
  Widget _buildTextField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    required double scale,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8 * scale),
        TextField(
          controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 16 * scale),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
          ),
        ),
      ],
    );
  }

  /// Number Field Widget
  Widget _buildNumberField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required double scale,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8 * scale),
        TextField(
          controller: TextEditingController(text: value.toStringAsFixed(1))
            ..selection = TextSelection.collapsed(offset: value.toStringAsFixed(1).length),
          onChanged: (text) {
            final parsed = double.tryParse(text);
            if (parsed != null) {
              onChanged(parsed);
            }
          },
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          style: TextStyle(fontSize: 16 * scale),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
          ),
        ),
      ],
    );
  }

  /// Build hour field (integer, 0-23)
  Widget _buildHourField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required double scale,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8 * scale),
        TextField(
          controller: TextEditingController(text: value.toString())
            ..selection = TextSelection.collapsed(offset: value.toString().length),
          onChanged: (text) {
            final parsed = int.tryParse(text);
            if (parsed != null && parsed >= 0 && parsed <= 23) {
              onChanged(parsed);
            }
          },
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: TextStyle(fontSize: 16 * scale),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
          ),
        ),
      ],
    );
  }
}

/// Settings Section Container
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final double scale;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.child,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
          // Section Header
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
          // Section Content
          child,
        ],
      ),
    );
  }
}

/// Settings Radio Tile
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
        if (value != null) {
          onChanged(value);
        }
      },
      activeColor: AppColors.primaryBlue,
    );
  }
}
