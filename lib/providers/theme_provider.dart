import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme mode provider for managing light/dark/system theme switching
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});

/// Theme service for updating theme mode
class ThemeService {
  static void updateTheme(WidgetRef ref, ThemeMode mode) {
    ref.read(themeModeProvider.notifier).state = mode;
  }

  static void toggleTheme(WidgetRef ref) {
    final currentMode = ref.read(themeModeProvider);
    switch (currentMode) {
      case ThemeMode.system:
        ref.read(themeModeProvider.notifier).state = ThemeMode.light;
        break;
      case ThemeMode.light:
        ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        ref.read(themeModeProvider.notifier).state = ThemeMode.system;
        break;
    }
  }

  static void setSystemTheme(WidgetRef ref) {
    ref.read(themeModeProvider.notifier).state = ThemeMode.system;
  }

  static void setLightTheme(WidgetRef ref) {
    ref.read(themeModeProvider.notifier).state = ThemeMode.light;
  }

  static void setDarkTheme(WidgetRef ref) {
    ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
  }
}