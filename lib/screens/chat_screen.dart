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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF252526)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('AI Assistant'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            padding: const EdgeInsets.all(8.0), // 8px padding to match original
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        // Add bottom border to match original
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF444444)
                : const Color(0xFFDDDDDD),
          ),
        ),
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

              // Microphone icon (matching web UI)
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  Icons.mic,
                  size: 20.0,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
                ),
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
                       color: const Color(0xFFE53E3E), // Exact red color matching web UI
                     ),
                     const SizedBox(width: 8.0),
                     Text(
                       'Ready to assist...',
                       style: AppTheme.statusTextStyle.copyWith(
                         color: const Color(0xFFE53E3E), // Exact red color matching web UI
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
               color: Theme.of(context).brightness == Brightness.dark
                   ? const Color(0xFF444444) // Unified border color
                   : const Color(0xFFDDDDDD), // Unified border color
               width: 1.0,
             ),
           ),
         ),
         child: Row(
           children: [
             // Text input (completely borderless and seamless)
             Expanded(
               child: TextField(
                 decoration: InputDecoration(
                   hintText: 'Type a message...',
                   border: InputBorder.none,
                   enabledBorder: InputBorder.none,
                   focusedBorder: InputBorder.none,
                   filled: false,
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                   hintStyle: AppTheme.bodyTextStyle.copyWith(
                     color: AppTheme.textLightColor,
                   ),
                 ),
                 style: AppTheme.bodyTextStyle,
               ),
             ),
             const SizedBox(width: 8.0),

             // Upload button
             Icon(
               Icons.upload,
               color: AppTheme.textLightColor,
               size: 20.0,
             ),
             const SizedBox(width: 16.0),

             // Send button (blue arrow, no circular background)
             Icon(
               Icons.send,
               color: AppTheme.primaryColor,
               size: 20.0,
             ),
           ],
         ),
       ),
    );
  }
}
