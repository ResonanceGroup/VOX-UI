import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/orb_widget.dart';
import '../widgets/navigation_drawer.dart';
import '../theme/app_theme.dart';
import '../controllers/livekit_orb_controller.dart';
import '../services/livekit_service.dart';
import '../services/token_service.dart';
import '../providers/app_settings_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late LiveKitOrbController _orbController;
  late LiveKitService _liveKitService;
  final TextEditingController _textController = TextEditingController();
  bool _isConnecting = false;
  
  @override
  void initState() {
    super.initState();
    
    // Use singleton instances for both controller and service
    _orbController = LiveKitOrbController(); // Singleton
    _liveKitService = LiveKitService(_orbController); // Singleton
    
    // Defer connection until after first frame and settings are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToLiveKit();
    });
  }
  
  /// Connect to LiveKit server using settings from provider
  Future<void> _connectToLiveKit() async {
    // Check if already connected or connecting
    if (_isConnecting) {
      debugPrint('[Chat] Already connecting, skipping duplicate connection attempt');
      return;
    }
    
    // Check if LiveKit service is already connected
    if (_liveKitService.isConnected) {
      debugPrint('[Chat] Already connected to LiveKit, skipping connection');
      return;
    }
    
    setState(() {
      _isConnecting = true;
    });
    
    try {
      debugPrint('[Chat] Attempting to connect to LiveKit...');
      
      // Wait for settings to be loaded
      final settingsAsync = ref.read(appSettingsProvider);
      
      // Check if still loading
      if (settingsAsync.isLoading) {
        debugPrint('[Chat] Settings still loading, waiting...');
        // Wait a bit and try again
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _isConnecting = false;
          });
          _connectToLiveKit();
        }
        return;
      }
      
      // Get settings value
      final settings = settingsAsync.valueOrNull;
      if (settings == null) {
        throw Exception('Settings not available');
      }
      
      // Validate settings before connecting
      if (settings.voiceAgent.serverUrl.isEmpty) {
        throw Exception('Server URL not configured. Please set it in Settings.');
      }
      
      if (settings.voiceAgent.token.isEmpty) {
        throw Exception('LiveKit token not configured. Please set it in Settings.');
      }
      
      debugPrint('[Chat] Connecting with URL: ${settings.voiceAgent.serverUrl}');
      await _liveKitService.connect(settings.voiceAgent.serverUrl, settings.voiceAgent.token);
      debugPrint('[Chat] ✅ Connected to LiveKit: ${settings.voiceAgent.serverUrl}');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to LiveKit successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Chat] ❌ Failed to connect to LiveKit: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }
  
  /// Send text message to agent
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    // Send message via LiveKit
    await _liveKitService.sendMessage(text);
    
    // Clear input
    _textController.clear();
    
    debugPrint('[Chat] Message sent: $text');
  }
  
  /// Toggle microphone mute state
  Future<void> _toggleMute() async {
    debugPrint('[Chat] _toggleMute method called');
    debugPrint('[Chat] Current mute state before toggle: ${_liveKitService.isMuted}');
    await _liveKitService.toggleMute();
    setState(() {}); // Refresh UI to show mute state
    debugPrint('[Chat] Microphone mute state toggled: ${_liveKitService.isMuted}');
    debugPrint('[Chat] _toggleMute method completed');
  }
  
  @override
  void dispose() {
    // Clean up text controller, but not singleton service
    _textController.dispose();
    super.dispose();
  }
  
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
            padding: const EdgeInsets.all(8.0),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: const [
        ],
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
      body: Center(
        child: SizedBox(
          width: 350.0,
          height: 450.0,
          child: OrbWidget(
            size: 300.0,
            controller: _orbController,
            onToggleMute: _toggleMute,
          ),
        ),
      ),

      // Bottom input controls
      bottomNavigationBar: Container(
        height: AppTheme.navHeight,
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF444444)
                  : const Color(0xFFDDDDDD),
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          children: [
            // Text input
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: _liveKitService.isConnected,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _liveKitService.isConnected 
                      ? 'Type a message...' 
                      : 'Connecting...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, 
                    vertical: 12.0
                  ),
                  hintStyle: TextStyle(
                    fontSize: 14.4,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF555555)
                        : const Color(0xFF999999),
                  ),
                ),
                style: TextStyle(
                  fontSize: 14.4,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFEEEEEE)
                      : AppTheme.textColor,
                ),
              ),
            ),
            const SizedBox(width: 8.0),

            // Upload button (placeholder for future)
            const Icon(
              Icons.upload,
              color: AppTheme.textLightColor,
              size: 20.0,
            ),
            const SizedBox(width: 16.0),

            // Send button
            IconButton(
              icon: const Icon(
                Icons.send,
                color: AppTheme.primaryColor,
                size: 20.0,
              ),
              onPressed: _liveKitService.isConnected ? _sendMessage : null,
            ),
          ],
        ),
      ),
    );
  }
}
