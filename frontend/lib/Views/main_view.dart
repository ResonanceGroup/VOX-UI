import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_manager.dart';
import 'dashboard_view.dart';
import 'lighting_view.dart';
import 'climate_view.dart';
import 'power_view.dart';
import 'water_view.dart';
import 'profile_view.dart';
import 'ai_view.dart';
import 'settings_view.dart';
import '../Controllers/main_view_controller.dart';
import '../Controllers/profile_controller.dart';
import '../Controllers/dashboard_controller.dart';
import '../Controllers/lighting_controller.dart';
import '../Controllers/climate_controller.dart';
import '../Controllers/water_controller.dart';
import '../Controllers/power_controller.dart';
import '../Controllers/ai_controller.dart';
import '../models/services/json_rpc_service.dart';
import '../models/services/alert_manager_service.dart';
import '../models/app_preferences_notifier.dart';
import '../models/nfc_model.dart';
import '../widgets/nfc_scan_overlay.dart';

/// Navigation destination definition
class NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget view;

  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.view,
  });
}

/// Main view with responsive navigation (rail/drawer)
class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    // Create controllers for MainView
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => MainViewController(
            jsonRpcService: context.read<JsonRpcService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ProfileController(
            jsonRpcService: context.read<JsonRpcService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final controller = DashboardController();
            controller.initialize();
            return controller;
          },
        ),
        ChangeNotifierProvider(
          create: (context) => LightingController(
            jsonRpcService: context.read<JsonRpcService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ClimateController(
            jsonRpcService: context.read<JsonRpcService>(),
            preferencesNotifier: context.read<AppPreferencesNotifier>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => WaterController(
            jsonRpcService: context.read<JsonRpcService>(),
            preferencesNotifier: context.read<AppPreferencesNotifier>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => PowerController(
            jsonRpcService: context.read<JsonRpcService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final controller = AIController();
            final isTcp = context.read<JsonRpcService>().currentTransport == 'tcp';
            controller.updateTcpConnectionStatus(isTcp);
            return controller;
          },
        ),
      ],
      child: const _MainViewContent(),
    );
  }
}

class _MainViewContent extends StatefulWidget {
  const _MainViewContent();

  @override
  State<_MainViewContent> createState() => _MainViewContentState();
}

class _MainViewContentState extends State<_MainViewContent> {
  int _selectedIndex = 1; // Default to Home
  MainViewController? _mainViewController;

  void _onNavRequest() {
    final idx = _mainViewController?.requestedNavIndex;
    if (idx != null) {
      setState(() => _selectedIndex = idx);
      _mainViewController?.clearNavRequest();
    }
  }

  @override
  void dispose() {
    _mainViewController?.removeListener(_onNavRequest);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize NFC with current user ID and AlertManagerService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mainViewController = context.read<MainViewController>();
      _mainViewController!.addListener(_onNavRequest);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !kIsWeb) {
        final nfcModel = context.read<NFCModel>();
        nfcModel.setUserId(user.uid);
        if (kDebugMode) {
          print('MainView: Initialized NFC with user ID: ${user.uid}');
        }
      }

      // Initialize Alert Manager Service
      final preferencesNotifier = context.read<AppPreferencesNotifier>();
      final dashboardController = context.read<DashboardController>();
      AlertManagerService().initialize(
        preferencesNotifier: preferencesNotifier,
        dashboardController: dashboardController,
      );
      
      if (kDebugMode) {
        print('MainView: AlertManagerService initialized with DashboardController');
      }
    });
  }

  // Navigation destinations (Profile will be filtered on tablets)
  final List<NavDestination> _allDestinations = [
    NavDestination(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      view: const ProfileView(),
    ),
    NavDestination(
      label: 'Home',
      icon: Icons.wb_sunny_outlined,
      selectedIcon: Icons.wb_sunny,
      view: const DashboardView(),
    ),
    NavDestination(
      label: 'Lighting',
      icon: Icons.lightbulb_outline,
      selectedIcon: Icons.lightbulb,
      view: const LightingView(),
    ),
    NavDestination(
      label: 'Water',
      icon: Icons.water_drop_outlined,
      selectedIcon: Icons.water_drop,
      view: const WaterView(),
    ),
    NavDestination(
      label: 'Climate',
      icon: Icons.thermostat_outlined,
      selectedIcon: Icons.thermostat,
      view: const ClimateView(),
    ),
    NavDestination(
      label: 'Power',
      icon: Icons.power_outlined,
      selectedIcon: Icons.power,
      view: const PowerView(),
    ),
    NavDestination(
      label: 'AI Assistant',
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      view: const AIView(),
    ),
    NavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      view: const SettingsView(),
    ),
  ];

  // Get filtered destinations based on screen size
  List<NavDestination> _getDestinations(bool isLargeScreen) {
    if (isLargeScreen) {
      // Tablets: hide Profile, show AI
      return _allDestinations.where((dest) => dest.label != 'Profile').toList();
    } else {
      // Phones: hide AI (tablet-only feature)
      return _allDestinations.where((dest) => dest.label != 'AI').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferencesNotifier>();
    final scale = settings.uiScale;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 600;
        final destinations = _getDestinations(isLargeScreen);

        // Map _selectedIndex (into _allDestinations) → displayIndex (into filtered list)
        int displayIndex;
        if (isLargeScreen) {
          // Tablets: Profile (index 0) removed → all indices shift down by 1.
          // If Profile was selected, fall back to Home (index 0 in filtered list).
          displayIndex = _selectedIndex > 0 ? _selectedIndex - 1 : 0;
        } else {
          // Phones: AI (index 6) removed → Settings shifts from 7 → 6.
          // If AI was somehow the active index, clamp to the last valid item.
          displayIndex = _selectedIndex >= 7 ? _selectedIndex - 1 : _selectedIndex;
          displayIndex = displayIndex.clamp(0, destinations.length - 1);
        }

        if (isLargeScreen) {
          // Tablet/Desktop: Use NavigationRail
          return _buildLargeScreenLayout(destinations, displayIndex, scale);
        } else {
          // Phone: Use Drawer
          return _buildSmallScreenLayout(destinations, displayIndex, scale);
        }
      },
    );
  }

  /// Large screen layout with persistent navigation rail
  Widget _buildLargeScreenLayout(List<NavDestination> destinations, int displayIndex, double scale) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: displayIndex,
            onDestinationSelected: (index) {
              setState(() {
                // Map from filtered list index back to full list index
                // On tablets, Profile (index 0) is hidden, so add 1 to account for it
                _selectedIndex = isLargeScreen ? index + 1 : index;
              });
            },
            extended: true,
            minExtendedWidth: 220 * scale,
            destinations: destinations.asMap().entries.map((entry) {
              final dest = entry.value;
              return NavigationRailDestination(
                icon: Icon(dest.icon),
                selectedIcon: Icon(dest.selectedIcon),
                label: Text(dest.label),
                padding: EdgeInsets.symmetric(vertical: 8 * scale),
              );
            }).toList(),
          ),

          // Vertical divider
          VerticalDivider(
            width: 1 * scale,
            thickness: 1 * scale,
            color: Theme.of(context).dividerTheme.color,
          ),

          // Main content
          Expanded(child: _buildMainContent(destinations, displayIndex, scale)),
        ],
      ),
    );
  }

  /// Small screen layout with drawer
  Widget _buildSmallScreenLayout(List<NavDestination> destinations, int displayIndex, double scale) {
    return Scaffold(
      appBar: _buildAppBar(
        showMenuButton: true,
        destinations: destinations,
        displayIndex: displayIndex,
        isLargeScreen: false,
        scale: scale,
      ),
      drawer: _buildDrawer(destinations, scale),
      body: _buildMainContent(destinations, displayIndex, scale),
    );
  }

  /// Build the main content area
  Widget _buildMainContent(List<NavDestination> destinations, int displayIndex, double scale) {
    return Column(
      children: [
        // App bar for large screens (without drawer button)
        if (MediaQuery.of(context).size.width > 600)
          _buildAppBar(
            showMenuButton: false, 
            destinations: destinations, 
            displayIndex: displayIndex,
            isLargeScreen: true,
            scale: scale,
          ),

        // Content
        Expanded(child: destinations[displayIndex].view),
      ],
    );
  }

  /// Build the app bar
  PreferredSizeWidget _buildAppBar({
    required bool showMenuButton, 
    required List<NavDestination> destinations,
    required int displayIndex,
    required bool isLargeScreen,
    required double scale,
  }) {
    return AppBar(
      leading: showMenuButton ? null : const SizedBox.shrink(),
      automaticallyImplyLeading: showMenuButton,
      title: Text(
        destinations[displayIndex].label,
        style: TextStyle(fontSize: 20 * scale),
      ),
      actions: [
        // Connection status indicator
        Consumer<MainViewController>(
          builder: (context, controller, child) {
            return Tooltip(
              message: controller.isDisconnected
                  ? '${controller.statusMessage} — tap to reconnect'
                  : controller.statusMessage,
              child: InkWell(
                onTap: controller.isDisconnected
                    ? () => controller.reconnect()
                    : null,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0 * scale),
                  child: _buildConnectionIcon(controller, scale),
                ),
              ),
            );
          },
        ),

        // NFC button (phones only)
        if (!isLargeScreen && !kIsWeb)
          IconButton(
            icon: const Icon(Icons.nfc),
            onPressed: () => _handleNFCScan(),
            tooltip: 'Scan NFC Tag',
          ),

        IconButton(
          icon: Icon(
            ThemeManager().isDarkMode
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
          ),
          onPressed: () {
            ThemeManager().toggleTheme();
          },
          tooltip: 'Toggle theme',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            setState(() {
              // Find Settings in the full destinations list (_allDestinations)
              final settingsIndexInFullList = _allDestinations.indexWhere((dest) => dest.label == 'Settings');
              if (settingsIndexInFullList >= 0) {
                _selectedIndex = settingsIndexInFullList;
              }
            });
          },
          tooltip: 'Settings',
        ),
        SizedBox(width: 8 * scale),
      ],
    );
  }

  /// Handle NFC scan button tap
  Future<void> _handleNFCScan() async {
    if (kIsWeb) return;
    
    // Check if platform supports NFC
    if (!Platform.isAndroid && !Platform.isIOS) {
      _showMessage('NFC is not supported on this platform', isError: true);
      return;
    }

    final nfcModel = context.read<NFCModel>();
    final profileController = context.read<ProfileController>();
    final user = FirebaseAuth.instance.currentUser;

    // Check if user is signed in
    if (user == null) {
      _showMessage('Please sign in to use NFC features', isError: true);
      return;
    }

    // Set user ID for NFC notifications
    nfcModel.setUserId(user.uid);

    // Get user preferences from ProfileController
    final userPreferences = {
      'mainLightBrightness': profileController.mainLightBrightness,
      'galleryLightBrightness': profileController.galleryLightBrightness,
      'mainLightsOn': profileController.mainLightsOn,
      'galleryLightsOn': profileController.galleryLightsOn,
      'preferredCabinTemp': profileController.preferredCabinTemp,
    };

    // Show platform-specific scanning UI
    if (Platform.isAndroid) {
      await _showAndroidNFCScan(nfcModel, userPreferences);
    } else if (Platform.isIOS) {
      await _showIOSNFCScan(nfcModel, userPreferences);
    }
  }

  /// Show Android NFC scanning overlay
  Future<void> _showAndroidNFCScan(
    NFCModel nfcModel,
    Map<String, dynamic> userPreferences,
  ) async {
    bool scanCompleted = false;
    late OverlayEntry overlayEntry;

    // Create overlay
    overlayEntry = OverlayEntry(
      builder: (context) => NFCScanOverlay(
        onCancel: () {
          overlayEntry.remove();
        },
      ),
    );

    // Show overlay
    Overlay.of(context).insert(overlayEntry);

    // Start NFC scan in background
    final success = await nfcModel.startSingleScan(
      userPreferences: userPreferences,
    );

    if (!success) {
      overlayEntry.remove();
      _showMessage('NFC is not available on this device', isError: true);
      return;
    }

    // Listen for scan completion
    void listener() {
      if (nfcModel.tagId != null && 
          nfcModel.tagId != 'NFC is available' &&
          !nfcModel.isScanning &&
          !scanCompleted) {
        scanCompleted = true;
        
        // Remove overlay
        overlayEntry.remove();
        
        // Haptic feedback
        HapticFeedback.mediumImpact();
        
        // Show success message
        _showMessage('NFC scanned – command sent!', isError: false);
        
        // Remove listener
        nfcModel.removeListener(listener);
      }
    }

    nfcModel.addListener(listener);

    // Auto-remove overlay after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (!scanCompleted) {
        try {
          overlayEntry.remove();
        } catch (e) {
          // Overlay might already be removed
        }
        nfcModel.removeListener(listener);
        _showMessage('No tag detected. Try again.', isError: false);
      }
    });
  }

  /// Show iOS NFC scanning (uses native overlay)
  Future<void> _showIOSNFCScan(
    NFCModel nfcModel,
    Map<String, dynamic> userPreferences,
  ) async {
    bool scanCompleted = false;

    // Start NFC scan (iOS shows native overlay automatically)
    final success = await nfcModel.startSingleScan(
      userPreferences: userPreferences,
    );

    if (!success) {
      _showMessage('NFC is not available on this device', isError: true);
      return;
    }

    // Listen for scan completion
    void listener() {
      if (nfcModel.tagId != null &&
          nfcModel.tagId != 'NFC is available' &&
          !nfcModel.isScanning &&
          !scanCompleted) {
        scanCompleted = true;
        
        // Haptic feedback
        HapticFeedback.mediumImpact();
        
        // Show success message
        _showMessage('NFC scanned – command sent!', isError: false);
        
        // Remove listener
        nfcModel.removeListener(listener);
      }
    }

    nfcModel.addListener(listener);

    // Auto-cleanup after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (!scanCompleted) {
        nfcModel.removeListener(listener);
        if (nfcModel.tagId == 'NFC is available') {
          _showMessage('No tag detected. Try again.', isError: false);
        }
      }
    });
  }

  /// Show a snackbar message
  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Build connection status icon based on controller state
  Widget _buildConnectionIcon(MainViewController controller, double scale) {
    IconData icon;
    Color color;

    switch (controller.connectionType) {
      case 'ble':
        icon = Icons.bluetooth_connected;
        color = Colors.blue;
        break;
      case 'wifi':
        icon = Icons.wifi;
        color = Colors.green;
        break;
      case 'connecting':
        icon = Icons.sync;
        color = Colors.orange;
        break;
      case 'none':
      default:
        icon = Icons.cloud_off;
        color = Colors.red;
        break;
    }

    return Icon(icon, color: color, size: 24 * scale);
  }

  /// Build the navigation drawer for small screens
  Widget _buildDrawer(List<NavDestination> destinations, double scale) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer header
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.rv_hookup,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 48 * scale,
                ),
                SizedBox(height: 12 * scale),
                Text(
                  'RG Smart Control',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: (Theme.of(context).textTheme.headlineMedium?.fontSize ?? 28) * scale,
                  ),
                ),
              ],
            ),
          ),

          // Navigation items
          ...destinations.asMap().entries.map((entry) {
            final index = entry.key;
            final dest = entry.value;
            final isSelected = _selectedIndex == index;
            final isProfile = dest.label == 'Profile';

            return ListTile(
              leading: isProfile && user?.photoURL != null
                  ? CircleAvatar(
                      radius: 12 * scale,
                      backgroundImage: NetworkImage(user!.photoURL!),
                      onBackgroundImageError: (_, __) {},
                      child: user.photoURL == null
                          ? Icon(
                              isSelected ? dest.selectedIcon : dest.icon,
                              size: 20 * scale,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            )
                          : null,
                    )
                  : Icon(
                      isSelected ? dest.selectedIcon : dest.icon,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
              title: Text(
                dest.label,
                style: TextStyle(
                  fontSize: 16 * scale,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.1),
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
                Navigator.pop(context); // Close drawer
              },
            );
          }),
        ],
      ),
    );
  }
}

/// Placeholder view for unimplemented sections
class PlaceholderView extends StatelessWidget {
  final String title;

  const PlaceholderView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferencesNotifier>();
    final scale = settings.uiScale;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 64 * scale,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: 16 * scale),
          Text(
            '$title View',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: (Theme.of(context).textTheme.headlineMedium?.fontSize ?? 28) * scale,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            'Coming soon...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * scale,
            ),
          ),
        ],
      ),
    );
  }
}
