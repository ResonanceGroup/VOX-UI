import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rg_smart_control/Views/SignInScreen.dart';
import 'package:rg_smart_control/Views/demo_page.dart';
import 'package:rg_smart_control/Views/main_view.dart';
import 'package:rg_smart_control/Views/theme_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:rg_smart_control/models/services/firebase_database_service.dart';
import 'package:rg_smart_control/models/services/json_rpc_service.dart';
import 'package:rg_smart_control/models/services/preferences_service.dart';
import 'package:rg_smart_control/models/rv_data_model.dart';
import 'package:rg_smart_control/models/nfc_model.dart';
import 'package:rg_smart_control/models/app_preferences_notifier.dart';
import 'dart:io' show Platform;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'models/constants.dart';
import 'package:rg_smart_control/models/services/notification_service.dart';
import 'package:rg_smart_control/models/services/alert_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    print('🔥 Initializing Firebase...');
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    print('✅ Firebase initialized successfully');
    print('📱 Platform: ${Platform.operatingSystem}');
  }

  // Initialize Firebase Database Service
  FirebaseDatabaseService().initialize();

  // Initialize Notification Service
  await NotificationService().initialize();

  if (kDebugMode) {
    print('🔔 Initializing AlertManagerService...');
  }

  // NOTE: BLE permissions are now requested lazily when user needs BLE functionality
  // This provides better UX and respects user privacy

  runApp(
    MultiProvider(
      providers: [
        // Theme Manager (system-level)
        ChangeNotifierProvider<ThemeManager>(
          create: (_) => ThemeManager(),
        ),
        
        // Services (singleton instances - shared across app)
        Provider<JsonRpcService>(
          create: (_) => JsonRpcService(),
        ),
        Provider<FirebaseDatabaseService>(
          create: (_) => FirebaseDatabaseService(),
        ),
        Provider<PreferencesService>(
          create: (_) => PreferencesService(),
        ),
        
        // App Preferences (app-wide user preferences with persistence)
        ChangeNotifierProvider<AppPreferencesNotifier>(
          create: (context) => AppPreferencesNotifier(
            context.read<PreferencesService>(),
          ),
        ),
        
        // Models (shared data - not view-specific)
        ChangeNotifierProvider<RVDataModel>(
          create: (context) => RVDataModel(
            databaseService: context.read<FirebaseDatabaseService>(),
            jsonRpcService: context.read<JsonRpcService>(),
          ),
        ),
        ChangeNotifierProvider<NFCModel>(
          create: (context) => NFCModel(
            jsonRpcService: context.read<JsonRpcService>(),
          ),
        ),
        
        // NOTE: View-specific controllers (DemoPageController, DashboardController, MainViewController)
        // are created by their respective views, not here
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isTablet = false;
  GoRouter? _router;
  bool _alertManagerInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize AlertManagerService once we have access to preferences
    if (!_alertManagerInitialized) {
      _initializeAlertManager();
      _alertManagerInitialized = true;
    }
    
    // Detect if device is a tablet based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final wasTablet = _isTablet;
    _isTablet = screenWidth > 600;
    
    // Lock orientation for tablets
    if (_isTablet != wasTablet) {
      _setOrientation();
    }

    // Create the router only once. Creating it inside build() means a new
    // GoRouter is instantiated on every rebuild (e.g. when the keyboard
    // appears and MediaQuery changes), resetting the navigation stack back
    // to initialLocation and wiping any in-progress sign-in state.
    _router ??= _buildRouter();
  }

  void _setOrientation() {
    if (_isTablet) {
      // Lock to landscape for tablets
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      
      if (kDebugMode) {
        print('📱 Tablet detected - locking to landscape orientation');
      }
    } else {
      // Lock to portrait for phones
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      if (kDebugMode) {
        print('📱 Phone detected - locking to portrait orientation');
      }
    }
  }

  Future<void> _initializeAlertManager() async {
    try {
      final preferencesNotifier = context.read<AppPreferencesNotifier>();
      
      await AlertManagerService().initialize(
        preferencesNotifier: preferencesNotifier,
        // DashboardController will register itself when it's created
      );
      
      if (kDebugMode) {
        print('✅ AlertManagerService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing AlertManagerService: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return MaterialApp.router(
          routerConfig: _router!,
          title: 'RG Smart Control',
          theme: ThemeManager.lightTheme,
          darkTheme: ThemeManager.darkTheme,
          themeMode: themeManager.themeMode,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  GoRouter _buildRouter() {
    // Tablets bypass signin and go directly to dashboard
    final initialLocation = _isTablet ? '/dashboard' : AppConstants.homeRoute;

    if (kDebugMode && _isTablet) {
      print('📱 Tablet detected - bypassing signin, going directly to dashboard');
    }

    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppConstants.homeRoute,
          builder: (context, state) => const AppSignIn(),
        ),
        GoRoute(
          path: AppConstants.demoRoute,
          builder: (context, state) => const DemoPage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const MainView(),
        ),
        GoRoute(
          path: AppConstants.profileRoute,
          builder: (context, state) => ProfileScreen(
            providers: [
              EmailAuthProvider(),
              GoogleProvider(
                clientId: Platform.isIOS 
                  ? AppConstants.googleClientIdIOS 
                  : AppConstants.googleClientIdAndroid,
                // For iOS, prefer to use GoogleService-Info.plist configuration
                iOSPreferPlist: Platform.isIOS,
              ),
            ],
            actions: [
              SignedOutAction((context) {
                // Use addPostFrameCallback to ensure safe navigation
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.go(AppConstants.homeRoute);
                  }
                });
              }),
            ],
          ),
        ),
      ],
      // Add error handling
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${state.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppConstants.homeRoute),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
