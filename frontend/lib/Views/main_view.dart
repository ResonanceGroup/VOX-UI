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

/// Main view with responsive navigation (rail/drawer)
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
      label: 'Voice',
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 600;

        if (isLargeScreen) {
          return _buildLargeScreenLayout(scale);
        } else {
          return _buildSmallScreenLayout(scale);
        }
      },
    );
  }

  /// Large screen layout with persistent navigation rail
  Widget _buildLargeScreenLayout(double scale) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            extended: true,
            minExtendedWidth: 220 * scale,
            destinations: _destinations.asMap().entries.map((entry) {
              final dest = entry.value;
              return NavigationRailDestination(
                icon: Icon(dest.icon),
                selectedIcon: Icon(dest.selectedIcon),
                label: Text(dest.label),
                padding: EdgeInsets.symmetric(vertical: 8 * scale),
              );
            }).toList(),
          ),
          VerticalDivider(
            width: 1 * scale,
            thickness: 1 * scale,
            color: Theme.of(context).dividerTheme.color,
          ),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(scale),
                Expanded(child: _destinations[_selectedIndex].view),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Small screen layout with bottom navigation
  Widget _buildSmallScreenLayout(double scale) {
    return Scaffold(
      appBar: _buildAppBar(scale),
      body: _destinations[_selectedIndex].view,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: _destinations.map((dest) {
          return NavigationDestination(
            icon: Icon(dest.icon),
            selectedIcon: Icon(dest.selectedIcon),
            label: dest.label,
          );
        }).toList(),
      ),
    );
  }

  /// Build the app bar
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
