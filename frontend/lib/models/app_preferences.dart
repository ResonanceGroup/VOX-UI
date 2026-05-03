/// Units enumeration
enum TemperatureUnit { fahrenheit, celsius }
enum VolumeUnit { gallons, liters }
enum DistanceUnit { miles, kilometers }
enum BatteryCapacityUnit { ah, kwh }

/// Battery system voltages
enum BatterySystemVoltage { v12, v24, v48 }

/// UI size scaling options
enum UISize { small, medium, large }

/// AppPreferences - Pure data model for all app-wide user preferences
/// This is an immutable data class that represents the state of user preferences.
/// Note: Connection status and version info are NOT persisted (managed separately)
class AppPreferences {
  // ========== UI SIZE SCALING ==========
  final UISize uiSize;

  // ========== UNITS OF MEASUREMENT ==========
  final TemperatureUnit temperatureUnit;
  final VolumeUnit volumeUnit;
  final DistanceUnit distanceUnit;
  final BatteryCapacityUnit batteryCapacityUnit;

  // ========== MY RV PROFILE ==========
  final String rvNickname;
  final String rvMakeModel;
  final String rvYear;
  final double freshWaterCapacity; // in gallons
  final double greyWaterCapacity;
  final double blackWaterCapacity;
  final double propaneCapacity;
  final double batteryBankCapacity; // in Ah
  final BatterySystemVoltage batterySystemVoltage;

  // ========== ALERTS & THRESHOLDS ==========
  final double batterySOCLowWarning;
  final double batterySOCLowCritical;
  final double freshWaterLowWarning;
  final double solarCurrentLowWarning;
  final double solarCurrentHighWarning;
  final int solarAlertStartHour; // Hour to start checking solar alerts (0-23)
  final int solarAlertEndHour;   // Hour to stop checking solar alerts (0-23)

  /// Constructor with default values
  const AppPreferences({
    // UI defaults
    this.uiSize = UISize.medium,
    
    // Unit defaults
    this.temperatureUnit = TemperatureUnit.fahrenheit,
    this.volumeUnit = VolumeUnit.gallons,
    this.distanceUnit = DistanceUnit.miles,
    this.batteryCapacityUnit = BatteryCapacityUnit.ah,
    
    // RV profile defaults
    this.rvNickname = 'My RV',
    this.rvMakeModel = '',
    this.rvYear = '',
    this.freshWaterCapacity = 50.0,
    this.greyWaterCapacity = 40.0,
    this.blackWaterCapacity = 30.0,
    this.propaneCapacity = 20.0,
    this.batteryBankCapacity = 200.0,
    this.batterySystemVoltage = BatterySystemVoltage.v12,
    
    // Alert threshold defaults
    this.batterySOCLowWarning = 30.0,
    this.batterySOCLowCritical = 15.0,
    this.freshWaterLowWarning = 20.0,
    this.solarCurrentLowWarning = 2.0,
    this.solarCurrentHighWarning = 15.0,
    this.solarAlertStartHour = 6,
    this.solarAlertEndHour = 18,
  });

  // ========== UI SCALE COMPUTED PROPERTY ==========
  double get uiScale {
    switch (uiSize) {
      case UISize.small:
        return 0.85;
      case UISize.medium:
        return 1.00;
      case UISize.large:
        return 1.15;
    }
  }

  // ========== BATTERY VOLTAGE COMPUTED PROPERTY ==========
  double get batterySystemVoltageValue {
    switch (batterySystemVoltage) {
      case BatterySystemVoltage.v12:
        return 12.0;
      case BatterySystemVoltage.v24:
        return 24.0;
      case BatterySystemVoltage.v48:
        return 48.0;
    }
  }

  // ========== UNIT CONVERSION HELPERS ==========
  
  /// Convert temperature value based on current unit setting
  double convertTemperature(double value, {bool toDisplay = true}) {
    if (toDisplay) {
      // Convert from stored Fahrenheit to display unit
      if (temperatureUnit == TemperatureUnit.celsius) {
        return (value - 32) * 5 / 9;
      }
    } else {
      // Convert from display unit to stored Fahrenheit
      if (temperatureUnit == TemperatureUnit.celsius) {
        return value * 9 / 5 + 32;
      }
    }
    return value;
  }

  /// Convert volume value based on current unit setting
  double convertVolume(double value, {bool toDisplay = true}) {
    if (toDisplay) {
      // Convert from stored gallons to display unit
      if (volumeUnit == VolumeUnit.liters) {
        return value * 3.78541;
      }
    } else {
      // Convert from display unit to stored gallons
      if (volumeUnit == VolumeUnit.liters) {
        return value / 3.78541;
      }
    }
    return value;
  }

  /// Convert distance value based on current unit setting
  double convertDistance(double value, {bool toDisplay = true}) {
    if (toDisplay) {
      // Convert from stored miles to display unit
      if (distanceUnit == DistanceUnit.kilometers) {
        return value * 1.60934;
      }
    } else {
      // Convert from display unit to stored miles
      if (distanceUnit == DistanceUnit.kilometers) {
        return value / 1.60934;
      }
    }
    return value;
  }

  /// Convert battery capacity based on current unit setting
  double convertBatteryCapacity(double value, double systemVoltage, {bool toDisplay = true}) {
    if (toDisplay) {
      // Convert from stored Ah to display unit
      if (batteryCapacityUnit == BatteryCapacityUnit.kwh) {
        return (value * systemVoltage) / 1000;
      }
    } else {
      // Convert from display unit to stored Ah
      if (batteryCapacityUnit == BatteryCapacityUnit.kwh) {
        return (value * 1000) / systemVoltage;
      }
    }
    return value;
  }

  // ========== UNIT LABEL GETTERS ==========
  String get temperatureUnitLabel => temperatureUnit == TemperatureUnit.fahrenheit ? '°F' : '°C';
  String get volumeUnitLabel => volumeUnit == VolumeUnit.gallons ? 'gal' : 'L';
  String get distanceUnitLabel => distanceUnit == DistanceUnit.miles ? 'mi' : 'km';
  String get speedUnitLabel => distanceUnit == DistanceUnit.miles ? 'mph' : 'kph';
  String get batteryCapacityUnitLabel => batteryCapacityUnit == BatteryCapacityUnit.ah ? 'Ah' : 'kWh';

  // ========== IMMUTABLE COPY METHOD ==========
  
  /// Create a copy of this preferences with updated values
  AppPreferences copyWith({
    UISize? uiSize,
    TemperatureUnit? temperatureUnit,
    VolumeUnit? volumeUnit,
    DistanceUnit? distanceUnit,
    BatteryCapacityUnit? batteryCapacityUnit,
    String? rvNickname,
    String? rvMakeModel,
    String? rvYear,
    double? freshWaterCapacity,
    double? greyWaterCapacity,
    double? blackWaterCapacity,
    double? propaneCapacity,
    double? batteryBankCapacity,
    BatterySystemVoltage? batterySystemVoltage,
    double? batterySOCLowWarning,
    double? batterySOCLowCritical,
    double? freshWaterLowWarning,
    double? solarCurrentLowWarning,
    double? solarCurrentHighWarning,
    int? solarAlertStartHour,
    int? solarAlertEndHour,
  }) {
    return AppPreferences(
      uiSize: uiSize ?? this.uiSize,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      batteryCapacityUnit: batteryCapacityUnit ?? this.batteryCapacityUnit,
      rvNickname: rvNickname ?? this.rvNickname,
      rvMakeModel: rvMakeModel ?? this.rvMakeModel,
      rvYear: rvYear ?? this.rvYear,
      freshWaterCapacity: freshWaterCapacity ?? this.freshWaterCapacity,
      greyWaterCapacity: greyWaterCapacity ?? this.greyWaterCapacity,
      blackWaterCapacity: blackWaterCapacity ?? this.blackWaterCapacity,
      propaneCapacity: propaneCapacity ?? this.propaneCapacity,
      batteryBankCapacity: batteryBankCapacity ?? this.batteryBankCapacity,
      batterySystemVoltage: batterySystemVoltage ?? this.batterySystemVoltage,
      batterySOCLowWarning: batterySOCLowWarning ?? this.batterySOCLowWarning,
      batterySOCLowCritical: batterySOCLowCritical ?? this.batterySOCLowCritical,
      freshWaterLowWarning: freshWaterLowWarning ?? this.freshWaterLowWarning,
      solarCurrentLowWarning: solarCurrentLowWarning ?? this.solarCurrentLowWarning,
      solarCurrentHighWarning: solarCurrentHighWarning ?? this.solarCurrentHighWarning,
      solarAlertStartHour: solarAlertStartHour ?? this.solarAlertStartHour,
      solarAlertEndHour: solarAlertEndHour ?? this.solarAlertEndHour,
    );
  }

  // ========== SERIALIZATION ==========
  
  /// Convert preferences to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'uiSize': uiSize.name,
      'temperatureUnit': temperatureUnit.name,
      'volumeUnit': volumeUnit.name,
      'distanceUnit': distanceUnit.name,
      'batteryCapacityUnit': batteryCapacityUnit.name,
      'rvNickname': rvNickname,
      'rvMakeModel': rvMakeModel,
      'rvYear': rvYear,
      'freshWaterCapacity': freshWaterCapacity,
      'greyWaterCapacity': greyWaterCapacity,
      'blackWaterCapacity': blackWaterCapacity,
      'propaneCapacity': propaneCapacity,
      'batteryBankCapacity': batteryBankCapacity,
      'batterySystemVoltage': batterySystemVoltage.name,
      'batterySOCLowWarning': batterySOCLowWarning,
      'batterySOCLowCritical': batterySOCLowCritical,
      'freshWaterLowWarning': freshWaterLowWarning,
      'solarCurrentLowWarning': solarCurrentLowWarning,
      'solarCurrentHighWarning': solarCurrentHighWarning,
      'solarAlertStartHour': solarAlertStartHour,
      'solarAlertEndHour': solarAlertEndHour,
    };
  }

  /// Create preferences from JSON (used when loading from persistence)
  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    return AppPreferences(
      uiSize: UISize.values.byName(json['uiSize'] ?? 'medium'),
      temperatureUnit: TemperatureUnit.values.byName(json['temperatureUnit'] ?? 'fahrenheit'),
      volumeUnit: VolumeUnit.values.byName(json['volumeUnit'] ?? 'gallons'),
      distanceUnit: DistanceUnit.values.byName(json['distanceUnit'] ?? 'miles'),
      batteryCapacityUnit: BatteryCapacityUnit.values.byName(json['batteryCapacityUnit'] ?? 'ah'),
      rvNickname: json['rvNickname'] ?? 'My RV',
      rvMakeModel: json['rvMakeModel'] ?? '',
      rvYear: json['rvYear'] ?? '',
      freshWaterCapacity: (json['freshWaterCapacity'] ?? 50.0).toDouble(),
      greyWaterCapacity: (json['greyWaterCapacity'] ?? 40.0).toDouble(),
      blackWaterCapacity: (json['blackWaterCapacity'] ?? 30.0).toDouble(),
      propaneCapacity: (json['propaneCapacity'] ?? 20.0).toDouble(),
      batteryBankCapacity: (json['batteryBankCapacity'] ?? 200.0).toDouble(),
      batterySystemVoltage: BatterySystemVoltage.values.byName(json['batterySystemVoltage'] ?? 'v12'),
      batterySOCLowWarning: (json['batterySOCLowWarning'] ?? 30.0).toDouble(),
      batterySOCLowCritical: (json['batterySOCLowCritical'] ?? 15.0).toDouble(),
      freshWaterLowWarning: (json['freshWaterLowWarning'] ?? 20.0).toDouble(),
      solarCurrentLowWarning: (json['solarCurrentLowWarning'] ?? 2.0).toDouble(),
      solarCurrentHighWarning: (json['solarCurrentHighWarning'] ?? 15.0).toDouble(),
      solarAlertStartHour: json['solarAlertStartHour'] ?? 6,
      solarAlertEndHour: json['solarAlertEndHour'] ?? 18,
    );
  }
}
