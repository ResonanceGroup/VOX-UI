// Flutter Web orb implementation using HtmlElementView (dart:html iframe).
// Full LiveKit subscription support — mirrors orb_webview_widget.dart logic.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:js' as js;
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
      ..src = 'assets/assets/orb/orb.html?v=' + DateTime.now().millisecondsSinceEpoch.toString()
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
  /// When true, pointer-events on the iframe are disabled so Flutter overlays
  /// (drawers, dialogs) can receive taps above the iframe.
  final bool isDrawerOpen;
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
    this.isDrawerOpen = false,
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
    if (widget.isTrayOpen != oldWidget.isTrayOpen ||
        widget.isDrawerOpen != oldWidget.isDrawerOpen) {
      final block = widget.isTrayOpen || widget.isDrawerOpen;
      _iframeElement?.style.pointerEvents = block ? 'none' : 'auto';
    }
    // Mic mute is now an overlay modifier — no state change needed here.
    // _send() below always includes micMuted in payload, which orb.html handles
    // by toggling orb-mic-muted class without interrupting the state machine.
    // speakerMuted change — mute/unmute all HTML audio elements
    if (widget.isSpeakerMuted != oldWidget.isSpeakerMuted) {
      _applyAudioMuteState(widget.isSpeakerMuted);
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
    // Reset module-level iframe reference so the next widget instance polls
    // for the new iframe instead of reusing the stale dead window pointer.
    _orbContentWindow = null;
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
                // Apply current tray/drawer block state immediately
                iframe.style.pointerEvents = (widget.isTrayOpen || widget.isDrawerOpen) ? 'none' : 'auto';
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
        // Resync after a short delay: the iframe's JS may not have registered
        // its message listener by the time the first postMessage fires
        // (especially on slower connections where the orb.html parse lags
        // behind the Dart widget setup). A second send ensures the state lands.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _send();
        });
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
        _updateState('idle');  // mic mute is overlay-only, never blocks idle
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
      _updateState('disconnected');  // still connecting — show as disconnected until confirmed
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
    // Mute is now an overlay modifier — agent state transitions continue
    // even while mic is muted (so the orb shows agent speaking while grayed).

    // Re-apply speaker mute state when agent starts speaking.
    // LiveKit creates <audio> elements lazily on first remote track receive,
    // so the querySelectorAll in didUpdateWidget may have found nothing if
    // the user toggled speaker mute before the agent spoke. Re-querying here
    // ensures every new audio element gets the correct muted state.
    if (newState == AIAgentState.speaking && widget.isSpeakerMuted) {
      _applyAudioMuteState(widget.isSpeakerMuted);
    }

    _notifyRevertTimer?.cancel();
    _notifyRevertTimer = null;

    final shouldNotify =
        (prev == AIAgentState.speaking && newState == AIAgentState.idle);

    if (shouldNotify) {
      _updateState('notifying');
      _notifyRevertTimer = Timer(const Duration(milliseconds: 1800), () {
        _updateState(_mapAgentStateToOrb(newState));
      });
    } else {
      _updateState(_mapAgentStateToOrb(newState));
    }
  }

  /// Mute or unmute all LiveKit remote audio elements.
  /// LiveKit appends <audio> elements to a hidden div with id
  /// 'livekit_audio_container'. We target that first, then fall back to a
  /// global query so we don't miss anything.
  void _applyAudioMuteState(bool muted) {
    _doApplyAudioMuteState(muted);
    // iOS Safari creates WebRTC audio elements lazily — retry after a short
    // delay to catch elements that don't exist yet at the first call.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _doApplyAudioMuteState(muted);
    });
  }

  void _doApplyAudioMuteState(bool muted) {
    try {
      void muteAudio(html.Element el) {
        final audio = el as html.AudioElement;
        // `muted` property alone is unreliable for WebRTC streams on iOS Safari.
        // Setting volume = 0 / 1 is the cross-platform fallback.
        audio.muted = muted;
        audio.volume = muted ? 0.0 : 1.0;
      }
      // Target the LiveKit audio container directly (most reliable)
      final container = html.document.getElementById('livekit_audio_container');
      if (container != null) {
        container.querySelectorAll('audio').forEach(muteAudio);
      }
      // Fallback: global query catches elements outside the container
      html.document.querySelectorAll('audio').forEach(muteAudio);
    } catch (_) {}
  }

  void _updateState(String state) {
    _currentState = state;
    _currentStatus = _getStatusForState(state);
    _send();
  }

  void _updateAudioLevel(double level) {
    // Amplify then apply sqrt curve: sqrt lifts quiet/moderate speech into a
    // visible range (e.g., 0.1 → sqrt(0.25) ≈ 0.5) while loud audio stays
    // near 1.0. Factor 2.5x is more aggressive than RV2's 1.75x to compensate
    // for web's lower measured audio levels vs native AudioStreamer on mobile.
    final amplified = (level * 2.5).clamp(0.0, 1.0);
    _currentLevel = amplified > 0 ? math.sqrt(amplified) : 0.0;
    _send(audioOnly: true);  // audio-level ticks must NOT include micMuted/speakerMuted
    // to avoid reverting the optimistic toggle in orb.html during the 16-50ms gap
    // between the user clicking unmute and Flutter processing the toggle.
  }

  void _updateTheme(String theme) {
    if (theme == _currentTheme) return; // no-op if unchanged — prevents spurious sends on every build()
    _currentTheme = theme;
    _send();
  }

  String _getStatusForState(String state) {
    switch (state) {
      case 'idle':         return 'Ready';
      case 'notifying':    return '';
      case 'executing':    return 'Thinking...';
      case 'processing':   return 'Speaking...';
      case 'disconnected': return 'Disconnected';
      default:             return 'Ready';
    }
  }

  // ── postMessage bridge ────────────────────────────────────────────────────

  void _send({bool audioOnly = false}) {
    final cw = _orbContentWindow;
    if (!_loaded || cw == null) return;
    // When audioOnly=true (called from the 33ms audio-level loop), only send
    // the level. Do NOT send micMuted/speakerMuted/state — these are managed
    // by state-change events and didUpdateWidget. Sending mute state on every
    // audio tick causes a race: the user clicks unmute in orb.html (optimistic),
    // but the next 33ms tick sends the stale micMuted:true before Flutter has
    // processed the toggle, re-graying the orb.
    final effectiveState = widget.debugOrbState ?? _currentState;
    final svcMuted = _livekitService?.isMuted ?? false;
    final svcSpeakerMuted = _livekitService?.isSpeakerMuted ?? false;
    try {
      cw.callMethod('postMessage', [
        js.JsObject.jsify({
          'type': 'livekit-update',
          'payload': {
            if (!audioOnly) 'state':        effectiveState,
            'level':        _currentLevel,
            if (!audioOnly) 'theme':        _currentTheme,
            if (!audioOnly) 'status':      widget.debugOrbState ?? _currentStatus,
            if (!audioOnly) 'micMuted':    svcMuted,
            if (!audioOnly) 'speakerMuted': svcSpeakerMuted,
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
