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

    return Stack(
      children: [
        // Blurred backdrop
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        // Drawer panel
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: AppTheme.sidebarWidth,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                // Navigation items (no header)
                _NavItem(
                  icon: Icons.chat,
                  label: 'Chat',
                  route: '/chat',
                  currentRoute: currentRoute,
                ),

                const SizedBox(height: 2.0), // Add spacing between menu items matching original gap: 2px

                _NavItem(
                  icon: Icons.storage, // Stacked servers icon matching original codicon-server
                  label: 'MCP Servers',
                  route: '/mcp-servers',
                  currentRoute: currentRoute,
                ),

                const SizedBox(height: 2.0), // Add spacing between menu items matching original gap: 2px

                _NavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  route: '/settings',
                  currentRoute: currentRoute,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.currentRoute == widget.route;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate background color based on state
    Color? backgroundColor;
    if (isSelected) {
      // Selected state background
      backgroundColor = isDark
          ? const Color(0x337FCCDE) // rgba(127, 204, 222, 0.2) for dark mode active
          : const Color(0x267FCCDE); // rgba(127, 204, 222, 0.15) for light mode active
    } else if (_isHovering) {
      // Hover state background
      backgroundColor = isDark
          ? const Color(0x1A7FCCDE) // rgba(127, 204, 222, 0.1) for dark mode hover
          : const Color(0x1A7FCCDE); // rgba(127, 204, 222, 0.1) for light mode hover
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop(); // Close drawer
          if (!isSelected) {
            context.go(widget.route);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: backgroundColor,
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
                widget.icon,
                size: 18.0,
                color: isSelected
                    ? (isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333))
                    : (isDark ? const Color(0xFFCCCCCC) : null),
              ),
              const SizedBox(width: 10.0),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15.2, // 0.95rem
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? (isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333))
                      : (isDark ? const Color(0xFFCCCCCC) : null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}