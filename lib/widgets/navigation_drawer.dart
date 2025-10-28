import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class VOXNavigationDrawer extends StatelessWidget {
  final String currentRoute;

  const VOXNavigationDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      width: AppTheme.sidebarWidth,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // Remove rounded corners
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        if (!isSelected) {
          context.go(route);
        }
      },
      hoverColor: isDark
          ? const Color(0x1A7FCCDE) // rgba(127, 204, 222, 0.1) for dark mode
          : const Color(0x1A7FCCDE), // rgba(127, 204, 222, 0.1) for light mode
      splashColor: Colors.transparent,
      highlightColor: isSelected
          ? (isDark
              ? const Color(0x337FCCDE) // rgba(127, 204, 222, 0.2) for dark mode active
              : const Color(0x267FCCDE)) // rgba(127, 204, 222, 0.15) for light mode active
          : Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 3.0,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18.0,
              color: isSelected ? AppTheme.primaryColor : (isDark ? const Color(0xFFCCCCCC) : null),
            ),
            const SizedBox(width: 10.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.2, // 0.95rem
                fontWeight: FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : (isDark ? const Color(0xFFCCCCCC) : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}