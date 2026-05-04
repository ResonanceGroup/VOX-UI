import '../widgets/orb_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../debug/ui_tuning_values.dart';
import '../Controllers/ai_controller.dart';
import '../models/services/livekit_service.dart';
import '../models/app_preferences_notifier.dart';
import '../permissions_helper.dart';
import 'theme_manager.dart';

/// AI Voice Assistant View with animated orb visualization
class AIView extends StatefulWidget {
  const AIView({super.key});

  @override
  State<AIView> createState() => _AIViewState();
}

class _AIViewState extends State<AIView> with TickerProviderStateMixin {
  late AnimationController _orbPulseController;
  late AnimationController _orbRotateController;
  late AnimationController _glowController;
  final ScrollController _conversationScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Request microphone permission
    _requestMicrophonePermission();

    // Orb pulse animation (breathing effect)
    _orbPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Orb rotate animation
    _orbRotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Glow intensity animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  /// Request microphone permission for voice input
  Future<void> _requestMicrophonePermission() async {
    final granted = await PermissionsHelper.requestMicrophonePermission();
    if (kDebugMode) {
      debugPrint('🎙️ AIView: Microphone permission granted: $granted');
    }
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice input'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _orbPulseController.dispose();
    _orbRotateController.dispose();
    _glowController.dispose();
    _conversationScrollController.dispose();
    super.dispose();
  }

  /// Scroll to bottom of conversation
  void _scrollToBottom() {
    if (_conversationScrollController.hasClients) {
      _conversationScrollController.animateTo(
        _conversationScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // AIController now lives at MainView level — persists across tab switches.
    // Just keep device type in sync since screen size is only known at build time.
    final isTablet = MediaQuery.of(context).size.width > 600;
    context.read<AIController>().updateDeviceType(isTablet);
    return const _AIViewContent();
  }
}

class _AIViewContent extends StatefulWidget {
  const _AIViewContent();

  @override
  State<_AIViewContent> createState() => _AIViewContentState();
}

class _AIViewContentState extends State<_AIViewContent> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _conversationScrollController = ScrollController();
  bool _isHistoryTrayOpen = false;
  String? _debugOrbState; // null = driven by LiveKit
  int _lastMessageCount = 0;
  String? _lastStreamingMessage;

  final List<ConversationMessage> _mockConversation = [
    ConversationMessage(
      text: 'Hey Milo, what is battery state right now?',
      isUser: true,
      timestamp: DateTime.now(),
    ),
    ConversationMessage(
      text: 'Battery is at 82% and charging at 18.6A.',
      isUser: false,
      timestamp: DateTime.now(),
    ),
    ConversationMessage(
      text: 'Set interior lights to 40%.',
      isUser: true,
      timestamp: DateTime.now(),
    ),
    ConversationMessage(
      text: 'Done. Interior lighting is now 40%.',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onInputChanged);
    _ensureConnected();
  }

  void _onInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _ensureConnected() {
    // Auto-connect when AI tab is opened / revisited
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<AIController>();
      if (controller.connectionState == AIConnectionState.disconnected ||
          controller.connectionState == AIConnectionState.error) {
        controller.connect();
      }
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onInputChanged);
    _textController.dispose();
    _conversationScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_conversationScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_conversationScrollController.hasClients) {
          _conversationScrollController.animateTo(
            _conversationScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _handleSendMessage(AIController controller) async {
    final message = _textController.text.trim();
    if (message.isEmpty || !controller.isAIEnabled) return;

    await controller.sendMessage(message);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AIController>();
    final themeManager = context.watch<ThemeManager>();
    final settings = context.watch<AppPreferencesNotifier>();
    final scale = settings.uiScale;
    final isDark = themeManager.themeMode == ThemeMode.dark;
    final showAvailableUiForPreview = controller.isAIAvailable || kDebugMode;

    return Scaffold(
      body: showAvailableUiForPreview
          ? _buildAvailableContent(controller, isDark, scale)
          : SafeArea(
              child: Column(
                children: [
                  _buildStatusBar(controller, isDark, scale),
                  Expanded(
                    child: _buildUnavailableContent(controller, isDark, scale),
                  ),
                ],
              ),
            ),
    );
  }

  /// Build status bar
  Widget _buildAlwaysVisibleInput(AIController controller, bool isDark, double scale) {
    final isConnected = controller.isAIEnabled;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12 * scale, 4 * scale, 12 * scale, 0),
              child: Row(
                children: [
                  Container(
                    width: 7 * scale, height: 7 * scale,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green[400]! : Colors.orange[400]!,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 5 * scale),
                  Flexible(child: Text(
                    isConnected ? 'Connected' : (controller.errorMessage ?? controller.statusMessage),
                    style: TextStyle(
                      fontSize: 11 * scale,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                controller: _textController,
                onSubmitted: (_) => _handleSendMessage(controller),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.0 * scale,
                    vertical: 14.0 * scale,
                  ),
                  hintStyle: TextStyle(
                    fontSize: 16.0 * scale,
                    color: isDark ? const Color(0xFF555555) : const Color(0xFF999999),
                  ),
                ),
                style: TextStyle(
                  fontSize: 16.0 * scale,
                  color: isDark ? const Color(0xFFEEEEEE) : Colors.black87,
                ),
              ),
            ),
            Listener(
              onPointerUp: (_) => _handleSendMessage(controller),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.send,
                  color: isDark ? Colors.blue[300] : Colors.blue,
                  size: 24.0 * scale,
                ),
              ),
            ),
          ],  // end Row children
            ),  // end Row
          ],  // end Column children
        ),  // end Column
      ),
    );
  }

  Widget _buildStatusBar(AIController controller, bool isDark, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          _buildStatusIndicator(controller, scale),
          SizedBox(width: 12 * scale),

          // Status text
          Expanded(
            child: Text(
              controller.statusMessage,
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),


        ],
      ),
    );
  }

  /// Build status indicator dot
  Widget _buildStatusIndicator(AIController controller, double scale) {
    Color color;
    if (!controller.isAIAvailable) {
      color = Colors.grey;
    } else {
      switch (controller.connectionState) {
        case AIConnectionState.connected:
          color = Colors.green;
          break;
        case AIConnectionState.connecting:
          color = Colors.orange;
          break;
        case AIConnectionState.error:
          color = Colors.red;
          break;
        case AIConnectionState.disconnected:
          color = Colors.grey;
          break;
      }
    }

    return Container(
      width: 12 * scale,
      height: 12 * scale,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 4 * scale,
            spreadRadius: 1 * scale,
          ),
        ],
      ),
    );
  }

  /// Build connect/disconnect button
  Widget _buildConnectionButton(AIController controller, double scale) {
    final isConnected = controller.connectionState == AIConnectionState.connected;

    return ElevatedButton.icon(
      onPressed: controller.connectionState == AIConnectionState.connecting
          ? null
          : () async {
              if (isConnected) {
                await controller.disconnect();
              } else {
                await controller.connect();
              }
            },
      icon: Icon(
        isConnected ? Icons.power_off : Icons.power,
        size: 18 * scale,
      ),
      label: Text(isConnected ? 'Disconnect' : 'Connect'),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
        minimumSize: Size.zero,
      ),
    );
  }

  /// Build content when AI is available
  Widget _buildAvailableContent(AIController controller, bool isDark, double scale) {
    final messages = controller.conversationHistory.isNotEmpty
        ? controller.conversationHistory
        : const <ConversationMessage>[];

    // Streaming preview bubble (non-final agent segments)
    final streamingMsg = controller.streamingAgentMessage;

    // Scroll to bottom on new message or streaming bubble growth
    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else if (streamingMsg != _lastStreamingMessage) {
      _lastStreamingMessage = streamingMsg;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    final displayMessages = (streamingMsg != null && streamingMsg.isNotEmpty)
        ? [
            ...messages,
            ConversationMessage(
              text: streamingMsg,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ]
        : messages;

    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            widthFactor: 1.0,
            heightFactor: 1.0,
            alignment: Alignment(0, UiTuningValues.orbAlignY),
            child: Transform.scale(
              scale: UiTuningValues.orbScale,
              child: _buildOrbVisualization(controller, isDark, scale),
            ),
          ),
        ),

        // Expandable history tray overlay (slides up from bottom)
        // Handle is embedded at the top of the tray so it slides up naturally with it
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_isHistoryTrayOpen,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: _isHistoryTrayOpen ? Offset.zero : const Offset(0, 1.05),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isHistoryTrayOpen ? 1 : 0,
                child: _buildHistoryTrayOverlay(
                  displayMessages,
                  isDark,
                  scale,
                  controller,
                ),
              ),
            ),
          ),
        ),



        // Grab handle at bottom — only shown when tray is closed
        if (!_isHistoryTrayOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 20 * scale,
            child: Center(
              child: _buildHistoryGrabHandle(isDark, scale),
            ),
          ),
      ],
    );
  }

  /// Build orb visualization widget
  Widget _buildOrbVisualization(AIController controller, bool isDark, double scale) {
    // Use WebView-based orb for exact visual fidelity
    return OrbWebViewWidget(
      size: UiTuningValues.orbSize * scale,
      livekitService: controller.livekitService,
      onToggleMute: () => controller.toggleMute(),
      onToggleSpeakerMute: () => controller.toggleSpeakerMute(),
      onOpenTray: () => setState(() => _isHistoryTrayOpen = true),
      isTrayOpen: _isHistoryTrayOpen,
      isMuted: controller.isMuted,
      isSpeakerMuted: controller.isSpeakerMuted,
      debugOrbState: _debugOrbState,
      orbScale: UiTuningValues.orbScale,
      orbContainerGap: UiTuningValues.orbContainerGap,
      micMarginTop: UiTuningValues.micMarginTop,
      statusMarginTop: UiTuningValues.statusMarginTop,
      statusFontSize: UiTuningValues.statusFontSize,
      micButtonSize: UiTuningValues.micButtonSize,
    );
  }

  Widget _buildHistoryGrabHandle(bool isDark, double scale) {
    return GestureDetector(
      onTap: () => setState(() => _isHistoryTrayOpen = !_isHistoryTrayOpen),
      child: Container(
        width: 84 * scale,
        height: 28 * scale,
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.white).withOpacity(0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Container(
            width: 34 * scale,
            height: 4 * scale,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.85),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTrayOverlay(
    List<ConversationMessage> messages,
    bool isDark,
    double scale,
    AIController controller,
  ) {
    final overlayBg = isDark
        ? Colors.black.withOpacity(UiTuningValues.trayOverlayOpacityDark)
        : Colors.white.withOpacity(UiTuningValues.trayOverlayOpacityLight);
    final titleColor = isDark ? Colors.white : Colors.black.withOpacity(0.92);
    final textColor = isDark ? Colors.white : Colors.black.withOpacity(0.92);

    return Material(
      color: overlayBg,
      // No SafeArea — overlay fills all the way to the top of the body
      child: Column(
        children: [
          // Scrollable message area fills full tray height; handle floats on top
          Expanded(
            child: Stack(
              children: [
                // Full-height ListView — extends to very top of tray
                Padding(
                  padding: EdgeInsets.fromLTRB(28 * scale, 0, 28 * scale, 0),
                  child: ListView.separated(
                    controller: _conversationScrollController,
                    // Top padding clears the floating handle; bottom gives
                    // breathing room above the input box (Change #1)
                    padding: EdgeInsets.only(
                      top: 56 * scale,
                      bottom: UiTuningValues.trayMessageSpacing * scale,
                    ),
                    itemCount: messages.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: UiTuningValues.trayMessageSpacing * scale),
                    itemBuilder: (context, index) {
                        final message = messages[index];
                        return Align(
                          alignment: message.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 18 * scale,
                              vertical: 14 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: message.isUser
                                  ? (isDark
                                      ? Colors.blue.withOpacity(0.32)
                                      : Colors.blue.withOpacity(0.16))
                                  : (isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : Colors.black.withOpacity(0.08)),
                              borderRadius: BorderRadius.circular(16 * scale),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.12),
                              ),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 28 * scale,
                                height: 1.28,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                    },
                  ),
                ),

                // Handle floats over the top of the scroll content
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Padding(
                    padding: EdgeInsets.only(top: 18 * scale),
                    child: Center(child: _buildHistoryGrabHandle(isDark, scale)),
                  ),
                ),
              ],
            ),
          ),

          // Chat input box — flush to left/right/bottom edges, top border only, like VOX-UI
          Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? const Color(0xFF444444)
                              : const Color(0xFFDDDDDD),
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Mic + speaker toggles in tray
                  IconButton(
                    icon: Icon(
                      controller.isMuted ? Icons.mic_off : Icons.mic,
                      color: controller.isMuted
                          ? Colors.red[400]
                          : (isDark ? Colors.white70 : Colors.black87),
                      size: 22.0 * scale,
                    ),
                    onPressed: () => controller.toggleMute(),
                    padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                    constraints: const BoxConstraints(),
                    tooltip: controller.isMuted ? 'Unmute mic' : 'Mute mic',
                  ),
                  IconButton(
                    icon: Icon(
                      controller.isSpeakerMuted ? Icons.volume_off : Icons.volume_up,
                      color: controller.isSpeakerMuted
                          ? Colors.red[400]
                          : (isDark ? Colors.white70 : Colors.black87),
                      size: 22.0 * scale,
                    ),
                    onPressed: () { controller.toggleSpeakerMute(); },
                    padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                    constraints: const BoxConstraints(),
                    tooltip: controller.isSpeakerMuted ? 'Unmute speaker' : 'Mute speaker',
                  ),
                  Expanded(
                          child: TextField(
                            controller: _textController,
                            onSubmitted: (_) => _handleSendMessage(controller),
                            textInputAction: TextInputAction.send,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.0 * scale,
                                vertical: 12.0 * scale,
                              ),
                              hintStyle: TextStyle(
                                fontSize: 24.0 * scale,
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? const Color(0xFF555555)
                                    : const Color(0xFF999999),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 24.0 * scale,
                              fontWeight: FontWeight.w400,
                              color: isDark
                                  ? const Color(0xFFEEEEEE)
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.send,
                            color: isDark ? Colors.blue[300] : Colors.blue,
                            size: 32.0 * scale,
                          ),
                          onPressed: (_textController.text.trim().isEmpty || !controller.isAIEnabled)
                              ? null
                              : () => _handleSendMessage(controller),
                        ),
                      ],
                    ),
                  ),
        ],
      ),
    );
  }

  /// Build conversation history
  Widget _buildConversationHistory(AIController controller, bool isDark, double scale) {
    if (controller.conversationHistory.isEmpty) {
      return Center(
        child: Text(
          controller.isAIEnabled
              ? 'Start speaking to begin...'
              : 'Connect to start chatting',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 16 * scale,
          ),
        ),
      );
    }

    // Auto-scroll when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: _conversationScrollController,
      padding: EdgeInsets.all(16 * scale),
      itemCount: controller.conversationHistory.length,
      itemBuilder: (context, index) {
        final message = controller.conversationHistory[index];
        return _buildMessageBubble(message, isDark, scale);
      },
    );
  }

  /// Build message bubble
  Widget _buildMessageBubble(ConversationMessage message, bool isDark, double scale) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12 * scale),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark ? Colors.blue[700] : Colors.blue[500])
                    : (isDark ? Colors.grey[800] : Colors.grey[300]),
                borderRadius: BorderRadius.circular(18 * scale),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 15 * scale,
                ),
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                fontSize: 11 * scale,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format timestamp
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Build input area (voice-only - no text input)
  Widget _buildInputArea(AIController controller, bool isDark, double scale) {
    // Allow mute button to work when AI is available (including debug mode)
    final canUseMicrophone = controller.isAIAvailable;

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mute/Unmute microphone button
          ElevatedButton.icon(
            onPressed: canUseMicrophone ? () => controller.toggleMute() : null,
            icon: Icon(
              controller.isMuted ? Icons.mic_off : Icons.mic,
              size: 24 * scale,
            ),
            label: Text(
              controller.isMuted ? 'Muted' : 'Listening',
              style: TextStyle(fontSize: 16 * scale),
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              backgroundColor: controller.isMuted
                  ? Colors.red.withOpacity(0.2)
                  : (isDark ? Colors.blue[700] : Colors.blue[500]),
              foregroundColor: controller.isMuted ? Colors.red : Colors.white,
            ),
          ),

          SizedBox(width: 16 * scale),

          // Clear history button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            iconSize: 28 * scale,
            onPressed: controller.conversationHistory.isNotEmpty
                ? () => controller.clearHistory()
                : null,
            tooltip: 'Clear history',
          ),
        ],
      ),
    );
  }

  /// Build content when AI is unavailable
  Widget _buildUnavailableContent(AIController controller, bool isDark, double scale) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32 * scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 80 * scale,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 24 * scale),
            Text(
              'AI Assistant Unavailable',
              style: TextStyle(
                fontSize: 24 * scale,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16 * scale),
            Text(
              controller.statusMessage,
              style: TextStyle(
                fontSize: 16 * scale,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32 * scale),
            _buildRequirementsList(isDark, scale),
          ],
        ),
      ),
    );
  }

  /// Build requirements list
  Widget _buildRequirementsList(bool isDark, double scale) {
    return Container(
      padding: EdgeInsets.all(24 * scale),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requirements:',
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 12 * scale),
          _buildRequirementItem(
            '📱 Tablet or larger device',
            isDark,
            scale,
          ),
          _buildRequirementItem(
            '🌐 TCP/Wi-Fi connection',
            isDark,
            scale,
          ),
          SizedBox(height: 16 * scale),
          Text(
            'Note: In debug mode, AI is available on all devices.',
            style: TextStyle(
              fontSize: 12 * scale,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  /// Build requirement item
  Widget _buildRequirementItem(String text, bool isDark, double scale) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20 * scale,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          SizedBox(width: 8 * scale),
          Text(
            text,
            style: TextStyle(
              fontSize: 14 * scale,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}