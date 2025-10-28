import 'dart:ui';
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
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // Remove rounded corners
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0), // Add blur effect matching CSS backdrop-filter: blur(2px)
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
          children: [
            // Navigation items (no header)
            _buildNavItem(
              context: context,
              icon: Icons.chat,
              label: 'Chat',
              route: '/chat',
              currentRoute: currentRoute,
            ),

            _buildNavItem(
              context: context,
              icon: Icons.storage, // Stacked servers icon matching original codicon-server
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