import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ai_view.dart';
import 'settings_view.dart';
import 'profile_view.dart';
import 'theme_manager.dart';
import '../models/app_preferences_notifier.dart';
import '../Controllers/ai_controller.dart';

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

/// Main view with hamburger drawer navigation
class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AIController(),
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
  int _selectedIndex = 0; // Default to Voice

  final List<NavDestination> _destinations = [
    NavDestination(
      label: 'AI Assistant',
      icon: Icons.mic_outlined,
      selectedIcon: Icons.mic,
      view: const AIView(),
    ),
    NavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      view: const SettingsView(),
    ),
    NavDestination(
      label: 'Profiles',
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      view: const ProfileView(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferencesNotifier>();
    final scale = settings.uiScale;

    return Scaffold(
      appBar: _buildAppBar(scale),
      drawer: _buildDrawer(context, scale),
      body: IndexedStack(
        index: _selectedIndex,
        children: _destinations.map((d) => d.view).toList(),
      ),
    );
  }

  /// Side drawer with navigation items + blur/dark overlay (provided by Flutter)
  Widget _buildDrawer(BuildContext context, double scale) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20 * scale, 24 * scale, 20 * scale, 16 * scale),
              child: Text(
                'VoxUI',
                style: TextStyle(
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Divider(height: 1),
            SizedBox(height: 8 * scale),
            for (int i = 0; i < _destinations.length; i++)
              ListTile(
                leading: Icon(
                  _selectedIndex == i
                      ? _destinations[i].selectedIcon
                      : _destinations[i].icon,
                  color: _selectedIndex == i
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  _destinations[i].label,
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: _selectedIndex == i
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: _selectedIndex == i
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                selected: _selectedIndex == i,
                selectedTileColor: theme.colorScheme.primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                onTap: () {
                  setState(() => _selectedIndex = i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Build the app bar — hamburger auto-added by Scaffold when drawer is set
  PreferredSizeWidget _buildAppBar(double scale) {
    return AppBar(
      title: Text(
        _destinations[_selectedIndex].label,
        style: TextStyle(fontSize: 20 * scale),
      ),
      actions: [
        IconButton(
          icon: Icon(
            ThemeManager().isDarkMode
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
          ),
          onPressed: () => ThemeManager().toggleTheme(),
          tooltip: 'Toggle theme',
        ),
        SizedBox(width: 8 * scale),
      ],
    );
  }
}
