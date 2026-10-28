import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'ai_view.dart';
import 'settings_view.dart';
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

/// Main view — drawer for nav + bottom bar on mobile
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

const String kVoxUiBuildId = '2026-10-28.4';

class _MainViewContentState extends State<_MainViewContent> {
  int _selectedIndex = 0;
  bool _isDrawerOpen = false;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<NavDestination> _buildDestinations() => [
    NavDestination(
      label: 'AI Assistant',
      icon: Icons.mic_outlined,
      selectedIcon: Icons.mic,
      view: AIView(isDrawerOpen: _isDrawerOpen),
    ),
    NavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      view: SettingsView(onSaved: () => setState(() => _selectedIndex = 0)),
    ),
  ];

  void _switchTo(int i) {
    setState(() => _selectedIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _buildDestinations();
    final settings = context.watch<AppPreferencesNotifier>();
    final scale = settings.uiScale;
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: PointerInterceptor(
          child: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'Open menu',
          ),
        ),
        title: Text(
          destinations[_selectedIndex].label,
          style: TextStyle(fontSize: 20 * scale),
        ),
        actions: [
          PointerInterceptor(
            child: IconButton(
              icon: Icon(
                ThemeManager().isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              ),
              onPressed: () {
                final next = ThemeManager().isDarkMode ? ThemeMode.light : ThemeMode.dark;
                ThemeManager().setThemeMode(next);
                context.read<AppPreferencesNotifier>().setThemeMode(next);
              },
              tooltip: 'Toggle theme',
            ),
          ),
          SizedBox(width: 8 * scale),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: ThemeManager().isDarkMode
                ? const Color(0xFF333333)
                : const Color(0xFFEEEEEE),
          ),
        ),
      ),
      drawer: _buildDrawer(theme, scale, destinations),
      onDrawerChanged: (open) => setState(() => _isDrawerOpen = open),
      body: IndexedStack(
        index: _selectedIndex,
        children: destinations.map((d) => d.view).toList(),
      ),

    );
  }

  Widget _buildDrawer(ThemeData theme, double scale, List<NavDestination> destinations) {
    final drawerWidth = (200.0 * scale).clamp(190.0, 232.0);
    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20 * scale, 24 * scale, 20 * scale, 16 * scale),
              child: Text('VoxUI', style: TextStyle(
                fontSize: 22 * scale,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              )),
            ),
            Divider(height: 1),
            SizedBox(height: 8 * scale),
            for (int i = 0; i < destinations.length; i++)
              ListTile(
                leading: Icon(
                  _selectedIndex == i ? destinations[i].selectedIcon : destinations[i].icon,
                  color: _selectedIndex == i
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  destinations[i].label,
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: _selectedIndex == i ? FontWeight.w600 : FontWeight.normal,
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
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(20 * scale, 8 * scale, 20 * scale, 12 * scale),
              child: Text(
                'Build $kVoxUiBuildId',
                style: TextStyle(
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
