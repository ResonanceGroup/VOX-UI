import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vox_ui/Views/main_view.dart';
import 'package:vox_ui/Views/theme_manager.dart';
import 'package:vox_ui/models/services/preferences_service.dart';
import 'package:vox_ui/models/services/config_api_service.dart';
import 'package:vox_ui/models/app_preferences_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefsService = PreferencesService();
  await prefsService.init();

  // Build ConfigApiService with lazy URL (reads from prefs on each call)
  final configApi = ConfigApiService(
    tokenServiceUrl: () => '${prefsService.backendBaseUrl}/api',
  );

  // Apply persisted theme to ThemeManager at startup
  final savedTheme = prefsService.themeModeName;
  ThemeManager().setThemeMode(
    savedTheme == 'light'  ? ThemeMode.light
    : savedTheme == 'system' ? ThemeMode.system
    : ThemeMode.dark,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeManager()),
        Provider<PreferencesService>.value(value: prefsService),
        Provider<ConfigApiService>.value(value: configApi),
        ChangeNotifierProvider(
          create: (context) {
            final notifier = AppPreferencesNotifier(prefsService);
            notifier.setConfigApi(configApi);
            // Try to load profiles from the backend first
            notifier.syncFromBackend();
            return notifier;
          },
        ),
      ],
      child: const VoxUIApp(),
    ),
  );
}

class VoxUIApp extends StatelessWidget {
  const VoxUIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = context.watch<ThemeManager>();
    return MaterialApp.router(
      title: 'VoxUI',
      theme: ThemeManager.lightTheme,
      darkTheme: ThemeManager.darkTheme,
      themeMode: themeManager.themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainView(),
    ),
  ],
);
