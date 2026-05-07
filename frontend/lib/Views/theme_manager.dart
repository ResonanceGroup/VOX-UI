import 'package:flutter/material.dart';

/// Theme Manager for RV Dashboard App
/// Handles dark and light mode themes with runtime switching capability
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Toggle between dark and light mode
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  /// Set specific theme mode
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  /// Dark Theme Definition
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      
      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentGreen,
        surface: AppColors.cardDark,
        background: AppColors.backgroundDark,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 4,
        shadowColor: Colors.black38,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),

      // Navigation Rail theme
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.backgroundDark,
        selectedIconTheme: IconThemeData(
          color: AppColors.primaryBlue,
          size: 28,
        ),
        unselectedIconTheme: const IconThemeData(
          color: Colors.white70,
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
        ),
        indicatorColor: AppColors.selectedNavBackground,
      ),

      // Drawer theme
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.backgroundDark,
        elevation: 16,
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: Colors.white60,
          fontSize: 12,
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: Colors.white,
        size: 24,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // Progress indicator theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primaryBlue,
        linearTrackColor: AppColors.divider,
      ),

      // Input decoration theme (all TextFields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3A3A3A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF555555)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF555555)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        hintStyle: const TextStyle(color: Color(0xFF666666)),
      ),
    );
  }

  /// Light Theme Definition
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      
      // Color scheme
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentGreen,
        surface: AppColors.cardLight,
        background: AppColors.backgroundLight,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
        onBackground: Colors.black87,
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(
          color: Colors.black87,
          size: 24,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),

      // Navigation Rail theme
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: IconThemeData(
          color: AppColors.primaryBlue,
          size: 28,
        ),
        unselectedIconTheme: const IconThemeData(
          color: Colors.black54,
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Colors.black54,
          fontSize: 16,
        ),
        indicatorColor: AppColors.primaryBlue.withOpacity(0.1),
      ),

      // Drawer theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        elevation: 16,
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: Colors.black87,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: Colors.black87,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: Colors.black87,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: Colors.black54,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: Colors.black45,
          fontSize: 12,
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: Colors.black87,
        size: 24,
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: Colors.black12,
        thickness: 1,
        space: 1,
      ),

      // Progress indicator theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primaryBlue,
        linearTrackColor: Colors.black12,
      ),

      // Input decoration theme (all TextFields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF666666)),
        hintStyle: const TextStyle(color: Color(0xFF999999)),
      ),
    );
  }
}

/// App Color Palette
class AppColors {
  // Dark mode colors
  static const Color backgroundDark = Color(0xFF000000);
  static const Color cardDark = Color(0xFF1A1A1A);
  static const Color cardAccentDark = Color(0xFF1F1F1F);
  static const Color divider = Color(0xFF333333);
  static const Color selectedNavBackground = Color(0xFF2A2A2A);

  // Light mode colors
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Accent colors (used in both themes)
  static const Color primaryBlue = Color(0xFF347AB8); // original VoxUI primary
  static const Color accentGreen = Color(0xFF00FF00);
  static const Color batteryGreen = Color(0xFF4CAF50);
  static const Color solarBlue = Color(0xFF2196F3);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFF9800);
  static const Color success = Color(0xFF4CAF50);

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textTertiary = Color(0xFF888888);
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF666666);

  // Progress bar gradient colors
  static const Color batteryStart = Color(0xFF1565C0);
  static const Color batteryEnd = Color(0xFF4CAF50);
  
  // Power-specific colors
  static const Color batteryIconGreen = Color(0xFF00FF66);
  static const Color solarYellow = Color(0xFFFFCC00);
  static const Color acYellow = Color(0xFFFFFF00);
  static const Color toggleInactive = Color(0xFF444444);
  static const Color toggleInactiveLight = Color(0xFFCCCCCC);
  static const Color greyedOutDark = Color(0xFF666666);
  static const Color greyedOutLight = Color(0xFFAAAAAA);
  static const Color dividerDark = Color(0xFF444444);
  static const Color dividerLight = Color(0xFFDDDDDD);
  static const Color socTrackDark = Color(0xFF333333);
  static const Color socTrackLight = Color(0xFFE0E0E0);
  static const Color gradientStartDark = Color(0xFF000000);
  static const Color gradientEndDark = Color(0xFF0A0A0A);
  static const Color gradientStartLight = Color(0xFFF5F5F5);
  static const Color gradientEndLight = Color(0xFFEEEEEE);
}
