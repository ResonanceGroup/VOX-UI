import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vox_ui/Views/main_view.dart';
import 'package:vox_ui/Views/theme_manager.dart';
import 'package:vox_ui/models/services/preferences_service.dart';
import 'package:vox_ui/models/app_preferences_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefsService = PreferencesService();
  await prefsService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeManager(),
        ),
        Provider<PreferencesService>.value(value: prefsService),
        ChangeNotifierProvider(
          create: (context) => AppPreferencesNotifier(prefsService),
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
