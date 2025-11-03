import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/chat_screen.dart';
import 'screens/mcp_servers_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/orb_test_screen.dart';
import 'theme/app_theme.dart';
import 'providers/app_settings_provider.dart';

void main() {
  runApp(const ProviderScope(child: MainApp()));
}

final GoRouter _router = GoRouter(
  initialLocation: '/chat',
  routes: [
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/mcp-servers',
      builder: (context, state) => const McpServersScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/orb-test',
      builder: (context, state) => const OrbTestScreen(),
    ),
  ],
);

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the app settings provider to ensure settings are loaded
    final settingsAsync = ref.watch(appSettingsProvider);
    
    return settingsAsync.when(
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Error loading settings: $error')),
        ),
      ),
      data: (settings) {
        return MaterialApp.router(
          routerConfig: _router,
          title: 'VOX UI',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
