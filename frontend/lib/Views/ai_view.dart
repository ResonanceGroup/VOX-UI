import '../widgets/orb_widget.dart';
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../debug/ui_tuning_values.dart';
import '../Controllers/ai_controller.dart';
import '../models/services/livekit_service.dart';
import '../models/app_preferences_notifier.dart';
import '../permissions_helper.dart';
import 'theme_manager.dart';

/// AI Voice Assistant View with animated orb visualization
/// Tracks which view-type names have already been registered with
/// Registration is permanent for the page lifetime — reuse the same name
/// for the same URL hash so we don't leak registrations.

class AIView extends StatefulWidget {
  final bool isDrawerOpen;
  const AIView({super.key, this.isDrawerOpen = false});

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
    return _AIViewContent(isDrawerOpen: widget.isDrawerOpen);
  }
}

class _AIViewContent extends StatefulWidget {
  final bool isDrawerOpen;
  const _AIViewContent({this.isDrawerOpen = false});

  @override
  State<_AIViewContent> createState() => _AIViewContentState();
}

class _AIViewContentState extends State<_AIViewContent>
    with SingleTickerProviderStateMixin {
  void _playSpeakerClick() {
    try {
      js.context.callMethod('eval', [
        r'''
        (function() {
          try {
            window.__voxClickCtx = window.__voxClickCtx || new (window.AudioContext || window.webkitAudioContext)();
            var ctx = window.__voxClickCtx;
            var startClick = function() {
              var osc = ctx.createOscillator();
              var gain = ctx.createGain();
              osc.connect(gain);
              gain.connect(ctx.destination);
              osc.type = 'sine';
              osc.frequency.setValueAtTime(660, ctx.currentTime);
              gain.gain.setValueAtTime(0.04, ctx.currentTime);
              gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.045);
              osc.start(ctx.currentTime);
              osc.stop(ctx.currentTime + 0.045);
            };
            if (ctx.resume) {
              ctx.resume().then(startClick).catch(startClick);
            } else {
              startClick();
            }
          } catch(e) {}
        })();
      ''',
      ]);
    } catch (_) {}
  }

  static const double _trayHandleEdgeGap = 16.0;
  static const double _closedTrayHandleBottomGap = 4.0;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _conversationScrollController = ScrollController();
  bool _isPickingImage = false;
  bool _isHistoryTrayOpen = false;
  bool _trayAutoOpened = false; // true when tray was opened by a pending approval
  Map<String, dynamic>? _prevPendingApproval; // detect approval arrival/clearance
  late final AnimationController _trayController;
  String? _debugOrbState; // null = driven by LiveKit
  int _lastMessageCount = 0;
  String? _lastStreamingMessage;
  final Set<String> _expandedToolCalls = {};

  // Direct listener reference — bypasses context.watch re-registration bug on Flutter Web.
  // context.watch<AIController>() fails to re-register after a Provider-triggered rebuild,
  // causing the view to freeze until a setState fires. addListener is reliable.
  AIController? _aiController;

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
    _trayController = AnimationController(
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 350),
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
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
    // Wire up direct listener to AIController — re-entrant safe (noop if same instance)
    final newController = context.read<AIController>();
    if (_aiController != newController) {
      _aiController?.removeListener(_onAIControllerChanged);
      _aiController = newController;
      _aiController!.addListener(_onAIControllerChanged);
    }
  }

  void _onAIControllerChanged() {
    if (!mounted) return;
    final ctrl = context.read<AIController>();

    // Approval arrived — auto-open tray if it was closed
    if (_prevPendingApproval == null && ctrl.pendingToolApproval != null) {
      if (!_isHistoryTrayOpen) {
        _trayAutoOpened = true;
        _openHistoryTray();
      }
    }

    // Approval cleared (approve or deny tapped) — auto-close if we auto-opened
    if (_prevPendingApproval != null && ctrl.pendingToolApproval == null && _trayAutoOpened) {
      _trayAutoOpened = false;
      _closeHistoryTray();
    }

    _prevPendingApproval = ctrl.pendingToolApproval;
    setState(() {});
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
    _aiController?.removeListener(_onAIControllerChanged);
    _textController.removeListener(_onInputChanged);
    _trayController.dispose();
    _textController.dispose();
    _conversationScrollController.dispose();
    super.dispose();
  }

  void _openHistoryTray() {
    if (!mounted) return;
    if (!_isHistoryTrayOpen) {
      setState(() => _isHistoryTrayOpen = true);
    }
    _trayController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _closeHistoryTray() async {
    await _trayController.reverse();
    if (mounted) {
      setState(() => _isHistoryTrayOpen = false);
    }
  }

  void _toggleHistoryTray() {
    if (_isHistoryTrayOpen) {
      _closeHistoryTray();
    } else {
      _openHistoryTray();
    }
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


  /// Resize and compress an image for transmission. Keeps longest dimension <=
  /// maxDim and re-encodes as JPEG. Falls back to original bytes on any error.
  /// Normalise an image for transmission:
  ///   PNG  → PNG  (preserves transparency; good for screenshots/diagrams)
  ///   everything else (JPEG, WebP, GIF, …) → JPEG 85%
  ///     WebP/GIF/BMP are not reliably handled by all vision backends;
  ///     converting to JPEG guarantees compatibility.
  ///   JPEG already ≤400 KB and ≤1024px → passes through untouched.
  ///   All oversized images are resized to max 1024px longest side.
  ///   Falls back to original bytes on any error.
  Future<(Uint8List, String)> _compressImageForSend(
    Uint8List bytes,
    String mimeType,
  ) async {
    const int maxDim = 1024;
    const double quality = 0.85;
    const int smallThreshold = 400 * 1024; // 400 KB
    final bool isPng = mimeType == 'image/png';
    final bool isJpeg = mimeType == 'image/jpeg' || mimeType == 'image/jpg';
    final String outMime = isPng ? 'image/png' : 'image/jpeg';
    try {
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final img = html.ImageElement()..src = url;
      await img.onLoad.first;
      html.Url.revokeObjectUrl(url);
      int w = img.naturalWidth ?? 0;
      int h = img.naturalHeight ?? 0;
      if (w == 0 || h == 0) return (bytes, mimeType);
      // Only skip re-encode for JPEG that is already small + within bounds.
      // WebP/GIF/etc must always be converted even if small.
      if (isJpeg && bytes.length <= smallThreshold && w <= maxDim && h <= maxDim) {
        return (bytes, mimeType);
      }
      if (w > maxDim || h > maxDim) {
        if (w >= h) { h = (h * maxDim / w).round(); w = maxDim; }
        else { w = (w * maxDim / h).round(); h = maxDim; }
      }
      final canvas = html.CanvasElement(width: w, height: h);
      // Non-PNG needs an opaque white background (JPEG has no alpha channel).
      if (!isPng) {
        canvas.context2D
          ..fillStyle = '#ffffff'
          ..fillRect(0, 0, w, h);
      }
      canvas.context2D.drawImageScaled(img, 0, 0, w, h);
      final dataUrl = isPng
          ? canvas.toDataUrl('image/png')
          : canvas.toDataUrl('image/jpeg', quality);
      final comma = dataUrl.indexOf(',');
      if (comma == -1) return (bytes, mimeType);
      return (base64Decode(dataUrl.substring(comma + 1)), outMime);
    } catch (_) {
      return (bytes, mimeType);
    }
  }

  /// Web-native image picker — uses a hidden <input type="file" accept="image/*">
  /// so the browser handles source selection (gallery / camera / files).
  /// On iOS Safari this presents the system sheet; on desktop it opens a picker.
  Future<void> _handlePickImage(AIController controller) async {
    if (!controller.isAIEnabled || _isPickingImage) return;
    try {
      final completer = Completer<void>();
      Uint8List? bytes;
      String? mimeType;
      String? fileName;

      final uploadInput = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..multiple = false
        ..style.display = 'none';

      // iOS Safari requires the element be in the DOM before click(), and
      // click() must happen before any await/microtask-yield in the gesture
      // handler. Append → listen → click → setState (in that order).
      html.document.body!.append(uploadInput);

      // previewDataUrl captured in the listener closure (set by readAsDataUrl).
      String? previewDataUrl;

      final sub = uploadInput.onChange.listen((_) {
        final file = uploadInput.files?.isNotEmpty == true
            ? uploadInput.files!.first
            : null;
        if (file == null) {
          completer.complete();
          return;
        }
        fileName = file.name;
        mimeType = file.type.isNotEmpty ? file.type : 'image/jpeg';
        final reader = html.FileReader();
        // readAsDataUrl returns a plain String — no ByteBuffer interop, works
        // reliably across all browsers and compilation modes (dart2js / CanvasKit).
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((_) {
          final dataUrl = reader.result;
          if (dataUrl is String) {
            previewDataUrl = dataUrl;
            final comma = dataUrl.indexOf(',');
            if (comma != -1) {
              try {
                bytes = base64Decode(dataUrl.substring(comma + 1));
              } catch (_) {}
            }
          }
          completer.complete();
        });
      });

      // Detect picker dismissal: when the user cancels the picker the
      // browser restores window focus. We wait a short debounce so
      // onChange can fire first if a file was actually selected.
      StreamSubscription<html.Event>? focusSub;
      focusSub = html.window.onFocus.listen((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!completer.isCompleted) completer.complete();
        });
      });

      // Must happen synchronously (before first await) to preserve gesture ctx.
      uploadInput.click();
      setState(() => _isPickingImage = true);
      // 15-second fallback in case focus event never fires (e.g. iOS quirk).
      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
      await sub.cancel();
      await focusSub.cancel();
      uploadInput.remove(); // clean up DOM element

      if (bytes == null) return;

      // Compress before sending: raw photos (3-8 MB) flood the TURN relay
      // and destabilize the WebRTC connection causing TTS to cut off.
      final (compressedBytes, compressedMime) =
          await _compressImageForSend(bytes!, mimeType ?? 'image/jpeg');
      final effectiveMime = compressedMime;
      final prompt = _textController.text.trim();
      // Keep original data URL for preview quality; backend gets compressed.
      final effectivePreviewUrl = previewDataUrl ??
          'data:$effectiveMime;base64,${base64Encode(compressedBytes)}';

      await controller.sendImageMessage(
        bytes: compressedBytes,
        mimeType: effectiveMime,
        prompt: prompt,
        previewDataUrl: effectivePreviewUrl,
        name: fileName,
      );
      _textController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    debugPrint(
      '[CHAT-DEBUG] build() #$_buildCount history=${context.read<AIController>().conversationHistory.length}',
    );
    // Use read (not watch) — AIController changes are handled via _onAIControllerChanged → setState
    final controller = context.read<AIController>();
    final themeManager = context.watch<ThemeManager>();
    final settings = context.watch<AppPreferencesNotifier>();
    final scale = settings.uiScale;
    final isDark = themeManager.themeMode == ThemeMode.dark;
    final showAvailableUiForPreview = controller.isAIAvailable || kDebugMode;

    final pageBackground = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF9F9F9);

    return Scaffold(
      backgroundColor: pageBackground,
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
  Widget _buildAlwaysVisibleInput(
    AIController controller,
    bool isDark,
    double scale,
  ) {
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
              padding: EdgeInsets.fromLTRB(
                12 * scale,
                4 * scale,
                12 * scale,
                0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 7 * scale,
                    height: 7 * scale,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? Colors.green[400]!
                          : Colors.orange[400]!,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 5 * scale),
                  Flexible(
                    child: Text(
                      isConnected
                          ? 'Connected'
                          : (controller.errorMessage ??
                                controller.statusMessage),
                      style: TextStyle(
                        fontSize: 11 * scale,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                        color: isDark
                            ? const Color(0xFF555555)
                            : const Color(0xFF999999),
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
                      color: AppColors.primaryBlue,
                      size: 24.0 * scale,
                    ),
                  ),
                ),
              ], // end Row children
            ), // end Row
          ], // end Column children
        ), // end Column
      ),
    );
  }

  Widget _buildStatusBar(AIController controller, bool isDark, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 12 * scale,
      ),
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
    final isConnected =
        controller.connectionState == AIConnectionState.connected;

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
      icon: Icon(isConnected ? Icons.power_off : Icons.power, size: 18 * scale),
      label: Text(isConnected ? 'Disconnect' : 'Connect'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 8 * scale,
        ),
        minimumSize: Size.zero,
      ),
    );
  }

  /// Build content when AI is available
  Widget _buildAvailableContent(
    AIController controller,
    bool isDark,
    double scale,
  ) {
    final messages = controller.conversationHistory.isNotEmpty
        ? controller.conversationHistory
        : const <ConversationMessage>[];

    // Streaming preview bubble (non-final agent segments)
    final streamingMsg = controller.streamingAgentMessage;

    // Scroll to bottom on new message or streaming bubble growth
    // (parent build() runs on every notifyListeners() via context.watch — no Consumer needed)
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

    debugPrint(
      '[CHAT-DEBUG] _buildAvailableContent: displayMessages.length=${displayMessages.length} trayOpen=$_isHistoryTrayOpen',
    );

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
          ),
        ),
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

        // Connecting/warming overlay — shown while switching profiles or agent warming up
        if (controller.connectionState == AIConnectionState.connecting || controller.isWarmingUp)
          Positioned.fill(
            child: Container(
              color: (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9))
                  .withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48 * scale,
                      height: 48 * scale,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    Text(
                      controller.connectionState == AIConnectionState.connecting
                          ? 'Switching profiles...'
                          : 'Agent warming up...',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Bottom-half swipe target — gives a natural open gesture without
        // requiring a precise tap on the small visible handle.
        if (!_isHistoryTrayOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -250) {
                  _openHistoryTray();
                }
              },
              child: const SizedBox.expand(),
            ),
          ),

        // Expandable history tray overlay (slides up from bottom)
        // Parent build() uses context.watch<AIController>() so it rebuilds on every
        // notifyListeners() — displayMessages is always fresh, no Consumer needed.
        AnimatedBuilder(
          animation: _trayController,
          builder: (context, child) {
            // Use easeInCubic so the tray starts gently and accelerates into
            // place instead of jumping upward then slowing near the top.
            final progress = Curves.easeInCubic.transform(
              _trayController.value,
            );
            final viewportHeight = MediaQuery.of(context).size.height;
            final hiddenOffset = viewportHeight * (1 - progress);
            return Positioned(
              left: 0,
              right: 0,
              top: hiddenOffset,
              bottom: -hiddenOffset,
              child: IgnorePointer(
                ignoring: !_isHistoryTrayOpen,
                child: Opacity(opacity: progress.clamp(0.0, 1.0), child: child),
              ),
            );
          },
          child: _buildHistoryTrayOverlay(
            displayMessages,
            isDark,
            scale,
            controller,
          ),
        ),

        // Grab handle — only shown when tray is closed. Keep it anchored near
        // the visual bottom of the usable viewport (above Safari's toolbar), not
        // up under the orb/status cluster.
        if (!_isHistoryTrayOpen)
          Positioned(
            left: 0,
            right: 0,
            // iOS Safari's bottom toolbar already creates visible breathing room;
            // use a smaller viewport offset so the visible gap matches the open
            // tray's top spacing.
            bottom: _closedTrayHandleBottomGap * scale,
            child: Center(
              child: PointerInterceptor(
                child: _buildHistoryGrabHandle(
                  isDark,
                  scale,
                  pillAlignment: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

        // Tool approval is handled inline inside the chat tray (no overlay banner)
      ],
    );
  }

  /// Tool call status tile — compact inline indicator showing what the agent is doing.
  /// Appears as a small left-aligned card with a spinning/completed icon.
  Widget _buildToolCallTile(
    ConversationMessage message,
    bool isDark,
    double scale,
  ) {
    final isCalling = message.toolStatus == 'calling';
    final iconColor = isCalling
        ? (isDark ? Colors.white54 : Colors.black45)
        : (isDark ? Colors.white24 : Colors.black12);
    final textColor = isDark ? Colors.white60 : Colors.black45;
    final tileKey = '${message.toolName}_${message.timestamp.millisecondsSinceEpoch}';
    final isExpanded = _expandedToolCalls.contains(tileKey);

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedToolCalls.remove(tileKey);
            } else {
              _expandedToolCalls.add(tileKey);
            }
          });
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 8 * scale,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10 * scale),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2 * scale),
                child: isCalling
                    ? SizedBox(
                        width: 12 * scale,
                        height: 12 * scale,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: iconColor,
                        ),
                      )
                    : Icon(
                        Icons.check_circle_outline,
                        size: 12 * scale,
                        color: iconColor,
                      ),
              ),
              SizedBox(width: 6 * scale),
              Flexible(
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14 * scale,
                    color: textColor,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                  maxLines: isExpanded ? null : 2,
                  overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              ),
              if (!isExpanded)
                Padding(
                  padding: EdgeInsets.only(top: 2 * scale),
                  child: Icon(
                    Icons.unfold_more,
                    size: 12 * scale,
                    color: textColor.withOpacity(0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Detect if text is a single emoji (with optional skin-tone modifier).
  static final RegExp _emojiRegex = RegExp(
    r'^[\p{Emoji_Presentation}\p{Extended_Pictographic}\u{FE0F}\u{1F3FB}-\u{1F3FF}\u{200D}]+$',
    unicode: true,
  );
  bool _isSingleEmoji(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    // Must match emoji pattern and be 1-2 characters (emoji + optional modifier)
    if (!_emojiRegex.hasMatch(trimmed)) return false;
    // Count grapheme clusters — must be exactly 1
    final clusters = trimmed.runes.length;
    return clusters <= 8; // accounts for ZWJ sequences like 👨‍👩‍👧
  }

  /// Floating emoji reaction — appears in chat as a large emoji with a subtle pop animation.
  Widget _buildEmojiReaction(
    ConversationMessage message,
    bool isDark,
    double scale,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * scale),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: 0.5 + (value * 0.5),
                child: child,
              ),
            );
          },
          child: Text(
            message.text.trim(),
            style: TextStyle(
              fontSize: 36 * scale,
            ),
          ),
        ),
      ),
    );
  }

  /// Inline approval card rendered inside the chat tray as the last item.
  /// Mirrors Telegram's bot confirmation pattern — no separate overlay.
  Widget _buildApprovalCard(
    Map<String, dynamic> approval,
    AIController controller,
    bool isDark,
    double scale,
  ) {
    final toolName = (approval['tool_name'] as String? ?? 'unknown').replaceAll('_', ' ');
    final description = approval['description'] as String? ?? '';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: EdgeInsets.all(14 * scale),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252535) : const Color(0xFFEEEEFF),
          borderRadius: BorderRadius.circular(16 * scale),
          border: Border.all(
            color: isDark ? const Color(0xFF5555BB) : const Color(0xFF7070DD),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.extension_rounded,
                  size: 16 * scale,
                  color: isDark ? const Color(0xFFAAAAEE) : const Color(0xFF5555BB),
                ),
                SizedBox(width: 7 * scale),
                Expanded(
                  child: Text(
                    toolName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14 * scale,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              SizedBox(height: 5 * scale),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13 * scale,
                  color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF555555),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 11 * scale),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.rejectToolCall,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? const Color(0xFF666688) : const Color(0xFFAAAAAA),
                      ),
                      foregroundColor: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
                      padding: EdgeInsets.symmetric(vertical: 8 * scale),
                      textStyle: TextStyle(fontSize: 13 * scale),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                    ),
                    child: const Text('Deny'),
                  ),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: ElevatedButton(
                    onPressed: controller.approveToolCall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF5555BB) : const Color(0xFF6060CC),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8 * scale),
                      textStyle: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                    ),
                    child: const Text('Allow'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build orb visualization widget.
  ///
  /// The orb iframe is pointer-transparent (see orb_widget_web_impl.dart), so
  /// the HTML mic/speaker buttons can no longer receive taps. This overlays
  /// PointerInterceptor hit targets at the exact screen positions where
  /// orb.html renders those buttons, calling the same handlers. Positions
  /// are computed from the same UiTuningValues that get passed into the
  /// iframe as CSS variables, mirroring orb.html layout math:
  ///   body (flex column, centered) > orb-container (gap) > [orb 300px,
  ///   controls-row (margin-top), status (margin-top)]
  Widget _buildOrbVisualization(
    AIController controller,
    bool isDark,
    double scale,
  ) {
    final orbSize = UiTuningValues.orbSize * scale;
    const orbContent = 300.0; // orb-wrapper fixed size in orb.html
    final gap = UiTuningValues.orbContainerGap;
    final micMargin = UiTuningValues.micMarginTop;
    final micSize = UiTuningValues.micButtonSize;
    const buttonGap = 16.0; // controls-row gap in orb.html
    final statusMargin = UiTuningValues.statusMarginTop;
    const statusHeight = 22.0; // approx status-display rendered height
    final contentH =
        orbContent + gap + micMargin + micSize + gap + statusMargin + statusHeight;
    // orb.html centers content vertically in the iframe (justify-content:center)
    final top = (orbSize - contentH) / 2;
    final rowTop = top + orbContent + gap + micMargin;
    final rowW = micSize * 2 + buttonGap;
    final micLeft = orbSize / 2 - rowW / 2;
    final spkLeft = micLeft + micSize + buttonGap;
    const pad = 6.0; // generous finger margin around the visible button

    Widget hitTarget(Rect r, VoidCallback onTap) {
      return Positioned(
        left: r.left - pad,
        top: r.top - pad,
        width: r.width + pad * 2,
        height: r.height + pad * 2,
        child: PointerInterceptor(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerUp: (_) => onTap(),
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    return SizedBox(
      width: orbSize,
      height: orbSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Use WebView-based orb for exact visual fidelity
          OrbWebViewWidget(
            size: orbSize,
            livekitService: controller.livekitService,
            onOpenTray: _openHistoryTray,
            isTrayOpen: _isHistoryTrayOpen,
            onToggleMute: () => controller.toggleMute(),
            onToggleSpeakerMute: () => controller.toggleSpeakerMute(),
            isMuted: controller.isMuted,
            isSpeakerMuted: controller.isSpeakerMuted,
            debugOrbState: _debugOrbState,
            orbScale: UiTuningValues.orbScale,
            orbContainerGap: UiTuningValues.orbContainerGap,
            micMarginTop: UiTuningValues.micMarginTop,
            statusMarginTop: UiTuningValues.statusMarginTop,
            statusFontSize: UiTuningValues.statusFontSize,
            micButtonSize: UiTuningValues.micButtonSize,
            isDrawerOpen: widget.isDrawerOpen,
            statusTextOverride: controller.toolCallStatusText,
          ),
          hitTarget(
            Rect.fromLTWH(micLeft, rowTop, micSize, micSize),
            () => controller.toggleMute(),
          ),
          hitTarget(
            Rect.fromLTWH(spkLeft, rowTop, micSize, micSize),
            () => controller.toggleSpeakerMute(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryGrabHandle(
    bool isDark,
    double scale, {
    Alignment pillAlignment = Alignment.center,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      // Use the low-level pointer-up event for the handle instead of mixing
      // tap and vertical-drag recognizers. On mobile Safari small finger motion
      // was entering the gesture arena as a drag, canceling otherwise-valid taps.
      onPointerUp: (_) => _toggleHistoryTray(),
      child: SizedBox(
        width: 168 * scale,
        height: 72 * scale,
        child: Align(
          alignment: pillAlignment,
          child: Container(
            width: 76 * scale,
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
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.85,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) {
          _closeHistoryTray();
        }
      },
      child: Material(
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
                      itemCount: messages.length + (controller.pendingToolApproval != null ? 1 : 0),
                      separatorBuilder: (_, __) => SizedBox(
                        height: UiTuningValues.trayMessageSpacing * scale,
                      ),
                      itemBuilder: (context, index) {
                        // Approval card is appended after all chat messages
                        if (index == messages.length && controller.pendingToolApproval != null) {
                          return _buildApprovalCard(
                            controller.pendingToolApproval!,
                            controller,
                            isDark,
                            scale,
                          );
                        }
                        debugPrint(
                          '[CHAT-DEBUG] itemBuilder: index=$index of ${messages.length}',
                        );
                        final message = messages[index];
                        // Tool call status tile — compact inline indicator
                        if (message.isToolCall) {
                          return _buildToolCallTile(message, isDark, scale);
                        }
                        // Emoji reaction — show as floating emoji instead of chat bubble
                        if (!message.isUser && _isSingleEmoji(message.text)) {
                          return _buildEmojiReaction(message, isDark, scale);
                        }
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
                                        ? AppColors.primaryBlue.withOpacity(
                                            0.30,
                                          )
                                        : AppColors.primaryBlue.withOpacity(
                                            0.12,
                                          ))
                                  : (isDark
                                        ? Colors.white.withOpacity(0.12)
                                        : Colors.black.withOpacity(0.07)),
                              borderRadius: BorderRadius.circular(16 * scale),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.12),
                              ),
                            ),
                            child: _buildMarkdownMessage(
                              message.text,
                              isDark: isDark,
                              isUser: message.isUser,
                              scale: scale,
                              fontSize: 28 * scale,
                              textColor: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Handle floats over the top of the scroll content
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.only(top: _trayHandleEdgeGap * scale),
                      child: Center(
                        child: _buildHistoryGrabHandle(
                          isDark,
                          scale,
                          pillAlignment: Alignment.topCenter,
                        ),
                      ),
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
                    onPressed: () {
                      // toggleMute() flips _isMuted synchronously on its first line,
                      // but notifyListeners() fires only after the async track await.
                      // Call setState() immediately so the icon updates without waiting.
                      controller.toggleMute();
                      setState(() {});
                    },
                    padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                    constraints: const BoxConstraints(),
                    tooltip: controller.isMuted ? 'Unmute mic' : 'Mute mic',
                  ),
                  IconButton(
                    icon: Icon(
                      controller.isSpeakerMuted
                          ? Icons.volume_off
                          : Icons.volume_up,
                      color: controller.isSpeakerMuted
                          ? Colors.red[400]
                          : (isDark ? Colors.white70 : Colors.black87),
                      size: 22.0 * scale,
                    ),
                    onPressed: () {
                      _playSpeakerClick();
                      controller.toggleSpeakerMute();
                      setState(() {});
                    },
                    padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                    constraints: const BoxConstraints(),
                    tooltip: controller.isSpeakerMuted
                        ? 'Unmute speaker'
                        : 'Mute speaker',
                  ),
                  IconButton(
                    icon: Icon(
                      _isPickingImage ? Icons.hourglass_empty : Icons.image,
                      color: controller.isAIEnabled
                          ? (isDark ? Colors.white70 : Colors.black87)
                          : (isDark ? Colors.white24 : Colors.black26),
                      size: 24.0 * scale,
                    ),
                    onPressed: (!controller.isAIEnabled || _isPickingImage)
                        ? null
                        : () => _handlePickImage(controller),
                    padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                    constraints: const BoxConstraints(),
                    tooltip: 'Send image',
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
                      color: AppColors.primaryBlue,
                      size: 32.0 * scale,
                    ),
                    onPressed:
                        (_textController.text.trim().isEmpty ||
                            !controller.isAIEnabled)
                        ? null
                        : () => _handleSendMessage(controller),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build conversation history
  Widget _buildConversationHistory(
    AIController controller,
    bool isDark,
    double scale,
  ) {
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

  Widget _buildMarkdownMessage(
    String data, {
    required bool isDark,
    required bool isUser,
    required double scale,
    required double fontSize,
    required Color textColor,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(
      0.18,
    );
    final tableStripeColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.035);
    final codeBackground = isDark
        ? Colors.black.withOpacity(0.28)
        : Colors.black.withOpacity(0.06);
    final blockquoteBackground = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);

    final baseStyle = TextStyle(
      color: textColor,
      fontSize: fontSize,
      height: 1.28,
      fontWeight: fontWeight,
    );

    return MarkdownBody(
      data: data,
      selectable: false,
      softLineBreak: true,
      onTapLink: (text, url, title) {
        if (url != null && url.isNotEmpty) {
          html.window.open(url, '_blank');
        }
      },
      builders: {
        'pre': _CodePreBuilder(
          isDark: isDark,
          scale: scale,
          baseStyle: baseStyle,
          fontSize: fontSize,
          codeBackground: codeBackground,
          borderColor: borderColor,
        ),
      },
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w800),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        del: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        a: baseStyle.copyWith(
          color: isUser ? Colors.white : AppColors.primaryBlue,
          decoration: TextDecoration.underline,
        ),
        h1: baseStyle.copyWith(
          fontSize: fontSize * 1.45,
          fontWeight: FontWeight.w800,
        ),
        h2: baseStyle.copyWith(
          fontSize: fontSize * 1.30,
          fontWeight: FontWeight.w800,
        ),
        h3: baseStyle.copyWith(
          fontSize: fontSize * 1.18,
          fontWeight: FontWeight.w700,
        ),
        h4: baseStyle.copyWith(
          fontSize: fontSize * 1.08,
          fontWeight: FontWeight.w700,
        ),
        h5: baseStyle.copyWith(fontWeight: FontWeight.w700),
        h6: baseStyle.copyWith(fontWeight: FontWeight.w700),
        listBullet: baseStyle,
        blockquote: baseStyle.copyWith(color: textColor.withOpacity(0.88)),
        blockquoteDecoration: BoxDecoration(
          color: blockquoteBackground,
          border: Border(
            left: BorderSide(
              color: AppColors.primaryBlue.withOpacity(0.75),
              width: 4 * scale,
            ),
          ),
          borderRadius: BorderRadius.circular(8 * scale),
        ),
        blockquotePadding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 8 * scale,
        ),
        // Inline code: no background highlight — Jason's preference.
        // Block code is handled by _CodePreBuilder below.
        code: baseStyle.copyWith(
          
          fontSize: fontSize * 0.82,
          // No backgroundColor — keeps the bubble's own bg visible.
        ),
        codeblockDecoration: const BoxDecoration(),
        codeblockPadding: EdgeInsets.zero,
        tableHead: baseStyle.copyWith(fontWeight: FontWeight.w800),
        tableBody: baseStyle.copyWith(fontSize: fontSize * 0.92),
        tableHeadAlign: TextAlign.left,
        tableBorder: TableBorder.all(color: borderColor, width: 1),
        tableColumnWidth: const IntrinsicColumnWidth(),
        tableCellsPadding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 8 * scale,
        ),
        // flutter_markdown applies this to alternating body rows; the header is
        // kept separate by its text weight/color and the table border.
        tableCellsDecoration: BoxDecoration(color: tableStripeColor),
        tableVerticalAlignment: TableCellVerticalAlignment.middle,
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
      ),
      imageBuilder: (uri, title, alt) {
        final imageUri = uri.toString();
        Widget image;
        if (imageUri.startsWith('data:image/')) {
          final commaIndex = imageUri.indexOf(',');
          final encoded = commaIndex >= 0
              ? imageUri.substring(commaIndex + 1)
              : '';
          image = Image.memory(
            base64Decode(encoded),
            fit: BoxFit.contain,
            frameBuilder: (ctx, child, frame, _) => frame == null
                ? const SizedBox(
                    height: 60,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : child,
          );
        } else {
          // External URL — route through the /img proxy to bypass CORS.
          // Flutter/CanvasKit blocks cross-origin images; the proxy fetches
          // server-side and serves from the same origin.
          final backendBase = html.window.location.origin;
          final proxiedUri = '$backendBase/img?url=${Uri.encodeComponent(imageUri)}';
          image = Image.network(
            proxiedUri,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
            errorBuilder: (ctx, err, st) => InkWell(
              onTap: () => html.window.open(imageUri, '_blank'),
              child: Container(
                height: 52 * scale,
                padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                decoration: BoxDecoration(
                  color: codeBackground,
                  borderRadius: BorderRadius.circular(8 * scale),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined,
                        size: 18 * scale, color: textColor.withOpacity(0.45)),
                    SizedBox(width: 8 * scale),
                    Text('Tap to view image',
                        style: baseStyle.copyWith(fontSize: fontSize * 0.85)),
                    SizedBox(width: 6 * scale),
                    Icon(Icons.open_in_new,
                        size: 14 * scale, color: textColor.withOpacity(0.45)),
                  ],
                ),
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => _openImageFullScreen(context, image),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4 * scale),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480 * scale,
                maxHeight: 360 * scale,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12 * scale),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    image,
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.zoom_in,
                        size: 18 * scale,
                        color: Colors.white.withOpacity(0.75),
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openImageFullScreen(BuildContext context, Widget imageWidget) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Image viewer',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, _) => SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 8.0,
                child: imageWidget,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build message bubble
  Widget _buildMessageBubble(
    ConversationMessage message,
    bool isDark,
    double scale,
  ) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12 * scale),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 12 * scale,
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primaryBlue
                    : (isDark
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFE8E8E8)),
                borderRadius: BorderRadius.circular(18 * scale),
              ),
              child: _buildMarkdownMessage(
                message.text,
                isDark: isDark,
                isUser: isUser,
                scale: scale,
                fontSize: 15 * scale,
                textColor: isUser
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
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
              padding: EdgeInsets.symmetric(
                horizontal: 24 * scale,
                vertical: 16 * scale,
              ),
              backgroundColor: controller.isMuted
                  ? Colors.red.withOpacity(0.15)
                  : AppColors.primaryBlue,
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
  Widget _buildUnavailableContent(
    AIController controller,
    bool isDark,
    double scale,
  ) {
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
          _buildRequirementItem('📱 Tablet or larger device', isDark, scale),
          _buildRequirementItem('🌐 TCP/Wi-Fi connection', isDark, scale),
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

// ─────────────────────────────────────────────────────────────
// Custom code-block builder for flutter_markdown
// ─────────────────────────────────────────────────────────────

/// Intercepts <pre> elements and renders them as tappable code blocks.
class _CodePreBuilder extends MarkdownElementBuilder {
  _CodePreBuilder({
    required this.isDark,
    required this.scale,
    required this.baseStyle,
    required this.fontSize,
    required this.codeBackground,
    required this.borderColor,
  });

  final bool isDark;
  final double scale;
  final TextStyle baseStyle;
  final double fontSize;
  final Color codeBackground;
  final Color borderColor;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // <pre> contains a <code> child — extract language hint and raw text.
    final codeEl = element.children?.whereType<md.Element>().firstWhere(
      (e) => e.tag == 'code',
      orElse: () => element,
    );
    final language = codeEl?.attributes['class']?.replaceFirst(
      RegExp(r'^language-'),
      '',
    );
    final code = (codeEl ?? element).textContent.trimRight();

    return _CodeBlockWidget(
      code: code,
      language: language,
      isDark: isDark,
      scale: scale,
      baseStyle: baseStyle,
      fontSize: fontSize,
      codeBackground: codeBackground,
      borderColor: borderColor,
    );
  }
}

/// Compact, tappable code block.  Tap opens a full-screen viewer with copy.
class _CodeBlockWidget extends StatelessWidget {
  const _CodeBlockWidget({
    required this.code,
    this.language,
    required this.isDark,
    required this.scale,
    required this.baseStyle,
    required this.fontSize,
    required this.codeBackground,
    required this.borderColor,
  });

  final String code;
  final String? language;
  final bool isDark;
  final double scale;
  final TextStyle baseStyle;
  final double fontSize;
  final Color codeBackground;
  final Color borderColor;

  TextStyle get _codeStyle => baseStyle.copyWith(
    fontSize: (fontSize * 0.55).clamp(9.0, 13.0),
    color: isDark ? Colors.white : Colors.black87,
    backgroundColor: Colors.transparent,
    height: 1.45,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6 * scale),
        decoration: BoxDecoration(
          color: codeBackground,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar with language + tap hint
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 5 * scale,
              ),
              color: borderColor.withOpacity(0.12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language != null && language!.isNotEmpty
                        ? language!
                        : 'code',
                    style: baseStyle.copyWith(
                      fontSize: fontSize * 0.65,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  Text(
                    'tap to expand',
                    style: baseStyle.copyWith(
                      fontSize: fontSize * 0.60,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            // Preview (first ~12 lines, clipped)
            Padding(
              padding: EdgeInsets.all(12 * scale),
              child: Text(
                code,
                style: _codeStyle,
                maxLines: 12,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFF5F5F5),
          appBar: AppBar(
            backgroundColor: isDark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFEEEEEE),
            foregroundColor: isDark ? Colors.white : Colors.black87,
            elevation: 0,
            title: Text(
              language != null && language!.isNotEmpty ? language! : 'Code',
              style: TextStyle(
                
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Code copied!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: TextStyle(
                  
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
