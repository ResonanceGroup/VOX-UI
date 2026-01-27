import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class VOXNavigationDrawer extends StatefulWidget {
  final String currentRoute;

  const VOXNavigationDrawer({super.key, required this.currentRoute});

  @override
  State<VOXNavigationDrawer> createState() => _VOXNavigationDrawerState();
}

class _VOXNavigationDrawerState extends State<VOXNavigationDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    // Start the animation when the drawer appears
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Stack(
        children: [
          // Backdrop blur effect with animation
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 3.0 * _animation.value,
                  sigmaY: 3.0 * _animation.value,
                ),
                child: Container(
                  color: Colors.black.withOpacity(0.1 * _animation.value),
                ),
              );
            },
          ),
          // Actual drawer
          Drawer(
            width: 250,
            elevation: 0,
            backgroundColor: isDark
                ? const Color(0xFF252526).withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              children: [
                // Navigation items (no header)
                _NavItem(
                  icon: Icons.chat,
                  label: 'Chat',
                  route: '/chat',
                  currentRoute: widget.currentRoute,
                  onTap: () => _closeDrawer(context, '/chat'),
                ),
                _NavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  route: '/settings',
                  currentRoute: widget.currentRoute,
                  onTap: () => _closeDrawer(context, '/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _closeDrawer(BuildContext context, String route) {
    // Start reversing the animation
    _controller.reverse();
    // Close drawer immediately (don't wait for animation)
    Navigator.of(context).pop();
    if (route != widget.currentRoute) {
      context.go(route);
    }
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.onTap,
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
        onTap: widget.onTap,
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