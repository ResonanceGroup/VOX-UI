// Flutter Web orb implementation using HtmlElementView (dart:html iframe).
// Full LiveKit subscription support — mirrors orb_webview_widget.dart logic.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../models/services/livekit_service.dart';

const String _kOrbViewType = 'vox-orb-iframe-view';
bool _factoryRegistered = false;
js.JsObject? _orbContentWindow;

void _ensureFactory() {
  if (_factoryRegistered) return;
  _factoryRegistered = true;
  ui_web.platformViewRegistry.registerViewFactory(_kOrbViewType, (int viewId) {
    return html.IFrameElement()
      ..src = 'assets/assets/orb/orb.html'
      ..style.cssText = 'border:none;width:100%;height:100%;display:block;';
  });
}

/// Web drop-in for OrbWebViewWidget — full LiveKit state subscriptions.
class OrbWebViewWidget extends StatefulWidget {
  final double size;
  final LiveKitService? livekitService;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleSpeakerMute;
  final VoidCallback? onOpenTray;
  final bool isTrayOpen;
  final bool isMuted;
  final bool isSpeakerMuted;
  final String? debugOrbState;
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
    this.onOpenTray,
    this.isTrayOpen = false,
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
  // ── Orb visual state ─────────────────────────────────────────────────────
  String _currentState = 'disconnected';
  double _currentLevel = 0.0;
  String _currentTheme = 'light';
  String _currentStatus = 'Disconnected';
  bool _loaded = false;
  Timer? _poll;

  // ── LiveKit subscriptions ─────────────────────────────────────────────────
  StreamSubscription<AIConnectionState>? _connectionStateSubscription;
  StreamSubscription<AIAgentState>? _agentStateSubscription;
  StreamSubscription<double>? _audioLevelSubscription;
  LiveKitService? _livekitService;

  // ── Notifying-flash state ─────────────────────────────────────────────────
  AIAgentState? _previousAgentState;
  Timer? _notifyRevertTimer;

  // ── iframe element (for pointer-events toggling when tray opens)
  html.IFrameElement? _iframeElement;

  // ── iframe message listener (web postMessage bridge)
  StreamSubscription? _windowMessageSub;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ensureFactory();
    // Listen for postMessage from orb iframe (mic + speaker toggle)
    _windowMessageSub = html.window.onMessage.listen((event) {
      try {
        final raw = event.data;
        String? type;
        // orb.html sends JSON.stringify({type: '...'}), so raw is a String.
        // Fall back to JsObject property access for any non-stringified senders.
        if (raw is String) {
          try {
            final decoded = jsonDecode(raw) as Map?;
            type = decoded?['type'] as String?;
          } catch (_) {}
        } else if (raw is js.JsObject) {
          type = raw['type'] as String?;
        }
        if (type == 'toggle-mute') {
          widget.onToggleMute?.call();
        } else if (type == 'toggle-speaker-mute') {
          widget.onToggleSpeakerMute?.call();
        } else if (type == 'open-tray') {
          widget.onOpenTray?.call();
        }
      } catch (_) {}
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPolling());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupLiveKitListeners();
  }

  @override
  void didUpdateWidget(OrbWebViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Toggle iframe pointer-events so Flutter tray overlay can receive touches
    // when open. Without this the iframe captures all browser touch events
    // regardless of Flutter's z-ordering.
    if (widget.isTrayOpen != oldWidget.isTrayOpen) {
      _iframeElement?.style.pointerEvents = widget.isTrayOpen ? 'none' : 'auto';
    }
    if (widget.isMuted != oldWidget.isMuted) {
      if (widget.isMuted) {
        _updateState('muted');
      } else {
        final connState = _livekitService?.currentConnectionState;
        if (connState == AIConnectionState.connected) {
          _updateState(_mapAgentStateToOrb(_previousAgentState ?? AIAgentState.idle));
        } else {
          _updateState('disconnected');
        }
      }
    } else if (widget.isMuted) {
      _currentState = 'muted';
    }
    // speakerMuted change — mute/unmute all HTML audio elements (LiveKit renders
    // remote audio as <audio> elements) + re-send payload for orb.html CSS class
    if (widget.isSpeakerMuted != oldWidget.isSpeakerMuted) {
      try {
        final audios = html.document.querySelectorAll('audio');
        for (final el in audios) {
          (el as html.AudioElement).muted = widget.isSpeakerMuted;
        }
      } catch (_) {}
    }
    _send();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _windowMessageSub?.cancel();
    _connectionStateSubscription?.cancel();
    _agentStateSubscription?.cancel();
    _audioLevelSubscription?.cancel();
    _notifyRevertTimer?.cancel();
    super.dispose();
  }

  // ── Polling for iframe contentWindow ─────────────────────────────────────

  void _startPolling() {
    if (!mounted) return;
    _poll = Timer.periodic(const Duration(milliseconds: 300), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_orbContentWindow == null) {
        try {
          final els = html.document.querySelectorAll('iframe');
          for (final el in els) {
            final iframe = el as html.IFrameElement;
            if ((iframe.src ?? '').contains('orb.html')) {
              final jsEl = js.JsObject.fromBrowserObject(iframe);
              final cw = jsEl['contentWindow'];
              if (cw != null) {
                _orbContentWindow = cw as js.JsObject;
                _iframeElement = iframe;  // store for pointer-events toggling
                // Apply current tray state immediately
                iframe.style.pointerEvents = widget.isTrayOpen ? 'none' : 'auto';
              }
              break;
            }
          }
        } catch (_) {}
      }
      if (_orbContentWindow != null) {
        t.cancel();
        setState(() => _loaded = true);
        _send();
      }
    });
  }

  // ── LiveKit listeners ─────────────────────────────────────────────────────

  void _setupLiveKitListeners() {
    _livekitService = widget.livekitService;
    if (_livekitService == null) return;

    _connectionStateSubscription?.cancel();
    _agentStateSubscription?.cancel();
    _audioLevelSubscription?.cancel();

    _connectionStateSubscription = _livekitService!.connectionState.listen((state) {
      if (state == AIConnectionState.connected) {
        if (!widget.isMuted) _updateState('idle');
      } else if (state == AIConnectionState.disconnected) {
        _updateState('disconnected');
      }
    });

    _agentStateSubscription = _livekitService!.agentState.listen((state) {
      _handleAgentStateTransition(state);
    });

    // Sync to current state immediately (streams only fire on change)
    final currentConn = _livekitService!.currentConnectionState;
    if (currentConn == AIConnectionState.connected) {
      _updateState(_mapAgentStateToOrb(_livekitService!.currentAgentState));
    } else if (currentConn == AIConnectionState.connecting) {
      _updateState('idle');
    } else {
      _updateState('disconnected');
    }

    _audioLevelSubscription = _livekitService!.audioLevel.listen((level) {
      _updateAudioLevel(level);
    });
  }

  // ── State helpers ─────────────────────────────────────────────────────────

  String _mapAgentStateToOrb(AIAgentState state) {
    switch (state) {
      case AIAgentState.idle:      return 'idle';
      case AIAgentState.listening: return 'idle';
      case AIAgentState.processing: return 'executing';
      case AIAgentState.speaking:  return 'processing';
      case AIAgentState.error:     return 'disconnected';
    }
  }

  void _handleAgentStateTransition(AIAgentState newState) {
    final prev = _previousAgentState;
    _previousAgentState = newState;
    if (widget.isMuted) return;

    _notifyRevertTimer?.cancel();
    _notifyRevertTimer = null;

    final shouldNotify =
        (prev == AIAgentState.speaking && newState == AIAgentState.idle);

    if (shouldNotify) {
      _updateState('notifying');
      _notifyRevertTimer = Timer(const Duration(milliseconds: 600), () {
        _updateState(_mapAgentStateToOrb(newState));
      });
    } else {
      _updateState(_mapAgentStateToOrb(newState));
    }
  }

  void _updateState(String state) {
    _currentState = state;
    _currentStatus = _getStatusForState(state);
    _send();
  }

  void _updateAudioLevel(double level) {
    final amplified = (level * 1.75).clamp(0.0, 1.0);
    _currentLevel = amplified > 0 ? math.sqrt(amplified) : 0.0;
    _send();
  }

  void _updateTheme(String theme) {
    _currentTheme = theme;
    _send();
  }

  String _getStatusForState(String state) {
    switch (state) {
      case 'idle':         return 'Ready to assist...';
      case 'notifying':    return '';
      case 'executing':    return 'Thinking...';
      case 'processing':   return 'Speaking...';
      case 'muted':        return 'Microphone muted';
      case 'disconnected': return 'Disconnected';
      default:             return 'Ready to assist...';
    }
  }

  // ── postMessage bridge ────────────────────────────────────────────────────

  void _send() {
    final cw = _orbContentWindow;
    if (!_loaded || cw == null) return;
    try {
      cw.callMethod('postMessage', [
        js.JsObject.jsify({
          'type': 'livekit-update',
          'payload': {
            'state':  widget.debugOrbState ?? _currentState,
            'level':  _currentLevel,
            'theme':  _currentTheme,
            'status': widget.debugOrbState != null
                ? widget.debugOrbState
                : _currentStatus,
            'speakerMuted': widget.isSpeakerMuted,
          },
        }),
        '*',
      ]);
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _updateTheme(isDark ? 'dark' : 'light');

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          HtmlElementView(viewType: _kOrbViewType),
          if (!_loaded)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
