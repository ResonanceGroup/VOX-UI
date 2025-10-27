import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class VOXNavigationDrawer extends StatelessWidget {
  final String currentRoute;

  const VOXNavigationDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: AppTheme.sidebarWidth,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // Drawer header
            Container(
              height: AppTheme.navHeight,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderColor,
                    width: 1.0,
                  ),
                ),
              ),
              child: const Center(
                child: Text(
                  'Navigation',
                  style: AppTheme.navTitleStyle,
                ),
              ),
            ),

            // Navigation items
            _buildNavItem(
              context: context,
              icon: Icons.chat,
              label: 'Chat',
              route: '/chat',
              currentRoute: currentRoute,
            ),

            _buildNavItem(
              context: context,
              icon: Icons.computer,
              label: 'MCP Servers',
              route: '/mcp-servers',
              currentRoute: currentRoute,
            ),

            _buildNavItem(
              context: context,
              icon: Icons.settings,
              label: 'Settings',
              route: '/settings',
              currentRoute: currentRoute,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
    required String currentRoute,
  }) {
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryColor : null,
          fontWeight: isSelected ? FontWeight.w500 : null,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        if (!isSelected) {
          context.go(route);
        }
      },
    );
  }
}