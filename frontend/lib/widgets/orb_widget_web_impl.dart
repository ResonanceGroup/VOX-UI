// Flutter Web minimal orb implementation using HtmlElementView.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

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

/// Minimal web drop-in for OrbWebViewWidget.
class OrbWebViewWidget extends StatefulWidget {
  final double size;
  final LiveKitService? livekitService;
  final VoidCallback? onToggleMute;
  final bool isMuted;
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
    this.isMuted = false,
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
  // Minimal state — no LiveKit subscriptions for now
  String _st = 'disconnected';
  double _lvl = 0.0;
  String _theme = 'light';
  String _status = 'Disconnected';
  bool _loaded = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _ensureFactory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPolling());
  }

  void _startPolling() {
    if (!mounted) return;
    _poll = Timer.periodic(const Duration(milliseconds: 300), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_orbContentWindow == null) {
        // Query DOM for the orb iframe and grab its contentWindow
        try {
          final els = html.document.querySelectorAll('iframe');
          for (final el in els) {
            final iframe = el as html.IFrameElement;
            if ((iframe.src ?? '').contains('orb.html')) {
              final jsEl = js.JsObject.fromBrowserObject(iframe);
              final cw = jsEl['contentWindow'];
              if (cw != null) {
                _orbContentWindow = cw as js.JsObject;
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

  void _send() {
    final cw = _orbContentWindow;
    if (!_loaded || cw == null) return;
    try {
      cw.callMethod('postMessage', [
        js.JsObject.jsify({
          'type': 'livekit-update',
          'payload': {
            'state': widget.debugOrbState ?? _st,
            'level': _lvl,
            'theme': _theme,
            'status': widget.debugOrbState ?? _status,
          },
        }),
        '*',
      ]);
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
