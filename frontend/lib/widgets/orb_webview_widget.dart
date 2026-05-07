import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/services/livekit_service.dart';

/// OrbWebViewWidget - Animated orb visualization using WebView
///
/// Faithfully replicates the VOX-UI orb appearance using HTML/CSS/JS
/// rendered via WebView for exact visual fidelity on mobile platforms.
class OrbWebViewWidget extends StatefulWidget {
  final double size;
  final LiveKitService? livekitService;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleSpeakerMute;
  final bool isMuted;
  final bool isSpeakerMuted;
  final String? debugOrbState; // Override orb state for testing (kDebugMode only)
  final double orbScale;
  final double orbContainerGap;
  final double micMarginTop;
  final double statusMarginTop;
  final double statusFontSize;
  final double micButtonSize;

  const OrbWebViewWidget({
    super.key,
    this.size = 300.0,
    this.livekitService,
    this.onToggleMute,
    this.onToggleSpeakerMute,
    this.isMuted = false,
    this.isSpeakerMuted = false,
    this.debugOrbState,
    this.orbScale = 1.0,
    this.orbContainerGap = 15.0,
    this.micMarginTop = 6.0,
    this.statusMarginTop = 12.0,
    this.statusFontSize = 27.0,
    this.micButtonSize = 62.0,
  });

  @override
  State<OrbWebViewWidget> createState() => _OrbWebViewWidgetState();
}

class _OrbWebViewWidgetState extends State<OrbWebViewWidget> {
  late WebViewController _controller;
  bool _isLoading = true;
  String _currentState = 'disconnected';
  double _currentLevel = 0.0;
  String _currentTheme = 'light';
  String _currentStatus = 'Disconnected';

  StreamSubscription<AIConnectionState>? _connectionStateSubscription;
  StreamSubscription<AIAgentState>? _agentStateSubscription;
  StreamSubscription<double>? _audioLevelSubscription;
  LiveKitService? _livekitService;

  // Track previous agent state for notifying transitions
  AIAgentState? _previousAgentState;
  Timer? _notifyRevertTimer;

  @override
  void didUpdateWidget(OrbWebViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle mute state changes from parent
    if (widget.isMuted != oldWidget.isMuted) {
      if (widget.isMuted) {
        _updateState('muted');
      } else {
        // Restore based on connection state — don't show idle if disconnected
        final connState = _livekitService?.currentConnectionState;
        if (connState == AIConnectionState.connected) {
          _updateState(_mapAgentStateToOrb(_previousAgentState ?? AIAgentState.idle));
        } else {
          _updateState('disconnected');
        }
      }
    } else if (widget.isMuted) {
      // Theme or other prop changed while still muted — re-assert muted visuals
      _currentState = 'muted';
    }
    // Handle speaker mute changes (only needs re-send, no orb state change)
    if (widget.isSpeakerMuted != oldWidget.isSpeakerMuted) {
      // speakerMuted is in the payload — _sendOrbUpdate below picks it up
    }
    _sendOrbUpdate();
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupLiveKitListeners();
  }

  void _setupLiveKitListeners() {
    _livekitService = widget.livekitService;

    if (_livekitService == null) {
      return;
    }

    // Cancel any existing subscriptions before re-subscribing
    _connectionStateSubscription?.cancel();
    _agentStateSubscription?.cancel();
    _audioLevelSubscription?.cancel();

    _connectionStateSubscription = _livekitService?.connectionState.listen((state) {
      if (state == AIConnectionState.connected) {
        if (!widget.isMuted) _updateState('idle');
      } else if (state == AIConnectionState.disconnected) {
        _updateState('disconnected'); // always show disconnected
      }
    });

    _agentStateSubscription = _livekitService?.agentState.listen((state) {
      _handleAgentStateTransition(state);
    });

    // Set initial orb state from current connection state (streams only fire on change)
    final currentConn = _livekitService?.currentConnectionState;
    if (currentConn == AIConnectionState.connected) {
      _updateState(_mapAgentStateToOrb(_livekitService!.currentAgentState));
    } else if (currentConn == AIConnectionState.connecting) {
      _updateState('idle'); // ICE restart in progress — treat as almost-connected
    } else {
      _updateState('disconnected');
    }

    _audioLevelSubscription = _livekitService?.audioLevel.listen((level) {
      _updateAudioLevel(level);
    });
  }

  /// Maps AIAgentState to orb CSS state, with brief "notifying" flash on key transitions.
  ///
  /// Orb state mapping:
  ///   idle       → idle       (calm breathing)
  ///   listening  → idle       (calm while user speaks)
  ///   thinking   → executing  (active spinning while LLM works)
  ///   speaking   → processing (subtle pulse while AI speaks)
  ///   error      → disconnected
  ///
  /// Notifying flash on transitions:
  ///   speaking  → idle               (AI finished talking)
  String _mapAgentStateToOrb(AIAgentState state) {
    switch (state) {
      case AIAgentState.idle:
        return 'idle';
      case AIAgentState.listening:
        return 'idle';
      case AIAgentState.processing:
        return 'executing';
      case AIAgentState.speaking:
        return 'processing';
      case AIAgentState.error:
        return 'disconnected';
    }
  }

  /// Handle agent state transition — flash "notifying" on key transitions
  void _handleAgentStateTransition(AIAgentState newState) {
    final prev = _previousAgentState;
    _previousAgentState = newState;

    // While muted, track state changes but don't update orb visuals
    if (widget.isMuted) return;

    // Cancel any pending notify revert
    _notifyRevertTimer?.cancel();
    _notifyRevertTimer = null;

    // Check if this transition should flash "notifying"
    final shouldNotify =
        (prev == AIAgentState.speaking && newState == AIAgentState.idle);

    if (shouldNotify) {
      // Flash notifying, then transition to the target state
      _updateState('notifying');
      _notifyRevertTimer = Timer(const Duration(milliseconds: 600), () {
        _updateState(_mapAgentStateToOrb(newState));
      });
    } else {
      _updateState(_mapAgentStateToOrb(newState));
    }
  }

  Future<void> _initWebView() async {
    // Assign controller first so _controller is always valid even if
    // later platform calls throw (e.g., enableZoom on web).
    _controller = WebViewController();
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    // enableZoom not supported on web — skip to avoid PlatformException
    if (!kIsWeb) {
      await _controller.enableZoom(false);
    }
    await _controller.setBackgroundColor(Colors.transparent);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String url) {
          // Push correct initial state BEFORE revealing the WebView so
          // there is no visible flash from the HTML default (idle).
          // _isLoading stays true until after the post-frame callback below.
          // Wire mic button → orbChannel after page is fully loaded
          _controller.runJavaScript('''
            (function() {
              var micBtn = document.getElementById('mic-button');
              if (micBtn) {
                var newBtn = micBtn.cloneNode(true);
                micBtn.parentNode.replaceChild(newBtn, micBtn);
                newBtn.addEventListener('click', function() {
                  orbChannel.postMessage(JSON.stringify({type: 'toggle-mute'}));
                });
              }
              var speakerBtn = document.getElementById('speaker-button');
              if (speakerBtn) {
                var newSpeaker = speakerBtn.cloneNode(true);
                speakerBtn.parentNode.replaceChild(newSpeaker, speakerBtn);
                newSpeaker.addEventListener('click', function() {
                  orbChannel.postMessage(JSON.stringify({type: 'toggle-speaker-mute'}));
                });
              }
            })();
          ''');
          _sendOrbUpdate();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) { setState(() { _isLoading = false; }); _sendOrbUpdate(); }
          });
        },
      ),
    );
    await _controller.addJavaScriptChannel(
      'orbChannel',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          if (data['type'] == 'toggle-mute') {
            widget.onToggleMute?.call();
          }
        } catch (e) {
          // Ignore parse errors
        }
      },
    );

    final htmlContent = await rootBundle.loadString('assets/orb/orb.html');

    // Inject communication bridge
    const bridgeScript = '''
      <script>
        // Disable scrolling and pinch-zoom interactions inside the orb webview
        document.addEventListener('wheel', (e) => e.preventDefault(), { passive: false });
        document.addEventListener('touchmove', (e) => e.preventDefault(), { passive: false });
        document.addEventListener('gesturestart', (e) => e.preventDefault(), { passive: false });
        document.addEventListener('gesturechange', (e) => e.preventDefault(), { passive: false });
        document.addEventListener('gestureend', (e) => e.preventDefault(), { passive: false });
        document.documentElement.style.overflow = 'hidden';
        document.body.style.overflow = 'hidden';
        document.body.style.touchAction = 'none';



        window.addEventListener('message', (event) => {
          if (event.data && event.data.type === 'livekit-update') {
            const payload = event.data.payload;
            if (payload.state !== undefined && payload.state !== null) {
              updateUIState(payload.state);
            }
            if (payload.level !== undefined) simulateAudioLevel(payload.level);
            if (payload.theme) document.documentElement.setAttribute('data-theme', payload.theme);
          }
        });
      </script>
    ''';

    final htmlWithBridge = htmlContent.replaceAll('</head>', '$bridgeScript</head>');
    await _controller.loadHtmlString(htmlWithBridge);
  }

  void _updateState(String state) {
    _currentState = state;
    _currentStatus = _getStatusForState(state);
    _sendOrbUpdate();
  }

  void _updateAudioLevel(double level) {
    // Boost audio level response: raw LiveKit audioLevel is often low (0.0–0.3),
    // so amplify 1.75x then apply sqrt curve for more visible quiet levels
    final amplified = (level * 1.75).clamp(0.0, 1.0);
    _currentLevel = amplified > 0 ? math.sqrt(amplified) : 0.0;
    _sendOrbUpdate();
  }

  void _updateTheme(String theme) {
    _currentTheme = theme;
    _sendOrbUpdate();
  }

  String _getStatusForState(String state) {
    // State strings here are the orb HTML states
    switch (state) {
      case 'idle':
        return 'Ready to assist...';
      case 'notifying':
        return '';  // brief transition flash, no text change
      case 'executing':
        return 'Thinking...';
      case 'processing':
        return 'Speaking...';
      case 'muted':
        return 'Microphone muted';
      case 'disconnected':
        return 'Disconnected';
      default:
        return 'Ready to assist...';
    }
  }

  void _sendOrbUpdate() {
    final message = jsonEncode({
      'type': 'livekit-update',
      'payload': {
        'state': widget.debugOrbState ?? _currentState,
        'level': _currentLevel,
        'theme': _currentTheme,
        'status': widget.debugOrbState != null ? widget.debugOrbState : _currentStatus,
        'speakerMuted': widget.isSpeakerMuted,
        'uiTuning': {
          'orbScale': widget.orbScale,
          'orbContainerGap': widget.orbContainerGap,
          'micMarginTop': widget.micMarginTop,
          'statusMarginTop': widget.statusMarginTop,
          'statusFontSize': widget.statusFontSize,
          'micButtonSize': widget.micButtonSize,
        },
      }
    });

    try {
      _controller.runJavaScript("""
        window.postMessage($message, '*');
        var sd = document.querySelector('.status-display');
        if (sd) sd.style.setProperty('font-size', '${widget.statusFontSize}px', 'important');
        var st = document.querySelector('.status-text');
        if (st) st.style.setProperty('font-size', '${widget.statusFontSize}px', 'important');
      """);
    } catch (_) {
      // Page not yet loaded — state will be pushed on onPageFinished
    }
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _agentStateSubscription?.cancel();
    _audioLevelSubscription?.cancel();
    _notifyRevertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _updateTheme(isDark ? 'dark' : 'light');

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading Orb...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
