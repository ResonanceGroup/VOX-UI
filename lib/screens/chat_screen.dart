import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/orb_widget.dart';
import '../widgets/navigation_drawer.dart';
import '../theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings using GoRouter
              context.go('/settings');
            },
          ),
        ],
      ),
      drawer: const VOXNavigationDrawer(currentRoute: '/chat'),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Orb Widget (Phase 1: solid circle)
              const OrbWidget(
                size: 200.0,
              ),
              const SizedBox(height: 20.0),

              // Status indicator (matching web UI)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.close,
                      size: 16.0,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'Ready to assist...',
                      style: AppTheme.statusTextStyle.copyWith(
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom input controls (matching web UI)
      bottomNavigationBar: Container(
        height: AppTheme.navHeight,
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: AppTheme.borderColor,
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          children: [
            // Text input
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                ),
                style: AppTheme.bodyTextStyle,
              ),
            ),
            const SizedBox(width: 8.0),

            // Upload button
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: () {
                // TODO: Implement file upload
              },
              tooltip: 'Upload file (coming soon)',
            ),

            // Send button
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                // TODO: Implement send functionality
              },
              tooltip: 'Send message',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
