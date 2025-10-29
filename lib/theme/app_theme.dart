import 'package:flutter/material.dart';

/// VOX UI Theme System
/// Based on visual analysis of the existing web UI
class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF347AB8);
  static const Color primaryHoverColor = Color(0xFF2A6194);

  // Theme Colors
  static const Color backgroundColor = Colors.white;
  static const Color textColor = Color(0xFF333333);
  static const Color textLightColor = Color(0xFF666666);
  static const Color textDarkColor = Color(0xFFCCCCCC);
  static const Color borderColor = Color(0xFFCCCCCC);  // Light mode border (matching CSS)
  static const Color borderDarkColor = Color(0xFF444444);

  // UI Element Colors
  static const Color headerBackground = Colors.white;
  static const Color headerDarkBackground = Color(0xFF252526);
  static const Color sidebarBackground = Colors.white;
  static const Color sidebarDarkBackground = Color(0xFF252526);
  static const Color sidebarBorder = Color(0xFFCCCCCC);  // Light mode border
  static const Color sidebarDarkBorder = Color(0xFF333333);
  static const Color inputControlsBackground = Colors.white;
  static const Color inputControlsDarkBackground = Color(0xFF1E1E1E);
  static const Color inputControlsBorder = Color(0xFFCCCCCC);
  static const Color inputControlsDarkBorder = Color(0xFF333333);

  // Status Colors
  static const Color statusOkColor = Color(0xFF4CAF50);
  static const Color statusErrorColor = Color(0xFFF44336);
  static const Color statusWarnColor = Color(0xFFFFC107);
  static const Color statusUnknownColor = Color(0xFF9E9E9E);

  // Spacing
  static const double navHeight = 60.0;
  static const double sidebarWidth = 160.0;
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 6.0;
  static const double containerPadding = 20.0;
  static const double sectionSpacing = 24.0;
  static const double elementGap = 12.0;

  // Typography
  static const TextStyle navTitleStyle = TextStyle(
    fontSize: 20.0, // 1.25rem equivalent
    fontWeight: FontWeight.w500,
    color: textColor,
  );

  static const TextStyle sectionHeaderStyle = TextStyle(
    fontSize: 16.0, // 1.0rem equivalent
    fontWeight: FontWeight.w500,
    color: textColor,
  );

  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: 14.4, // 0.9rem equivalent
    fontWeight: FontWeight.w400,
    color: textColor,
  );

  static const TextStyle statusTextStyle = TextStyle(
    fontSize: 14.4, // 0.9rem equivalent
    fontWeight: FontWeight.w400,
    color: textLightColor,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 14.4, // 0.9rem equivalent
    fontWeight: FontWeight.w500,
    color: textColor,
  );

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif',

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: headerBackground,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: navTitleStyle,
      ),

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        surface: backgroundColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textColor,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
          borderSide: const BorderSide(color: inputControlsBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
          borderSide: const BorderSide(color: inputControlsBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2.0),
        ),
        labelStyle: labelStyle,
        hintStyle: bodyTextStyle.copyWith(color: textLightColor),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 50),  // Set minimum height to 44px
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(smallBorderRadius),
          ),
          textStyle: bodyTextStyle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: bodyTextStyle.copyWith(color: primaryColor),
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
          side: const BorderSide(color: inputControlsBorder),
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif',

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: headerDarkBackground,
        foregroundColor: Color(0xFFCCCCCC), // Lighter gray to match original
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.w500,
          color: Color(0xFFCCCCCC), // Lighter gray to match original
        ),
        iconTheme: IconThemeData(
          color: Color(0xFFCCCCCC), // Lighter gray for hamburger menu
        ),
      ),

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: Color(0xFF1E1E1E),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFEEEEEE),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3A3A3A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
          borderSide: const BorderSide(color: Color(0xFF555555)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
          borderSide: const BorderSide(color: Color(0xFF555555)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2.0),
        ),
        labelStyle: const TextStyle(
          fontSize: 14.4,
          fontWeight: FontWeight.w500,
          color: Color(0xFFEEEEEE),
        ),
        hintStyle: const TextStyle(
          fontSize: 14.4,
          fontWeight: FontWeight.w400,
          color: Color(0xFFBBBBBB),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 50),  // Set minimum height to 44px
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(smallBorderRadius),
          ),
          textStyle: bodyTextStyle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: const Color(0xFF2C2C2C),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
          side: const BorderSide(color: Color(0xFF555555)),
        ),
      ),
    );
  }
}