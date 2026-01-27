import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import '../controllers/livekit_orb_controller.dart';

/// OrbWidget - Clean orb widget for main UI integration
/// Uses the fully functional OrbWebViewWidget internally but presents a clean interface
class OrbWidget extends StatefulWidget {
  final double size;
  final LiveKitOrbController? controller;
  final VoidCallback? onToggleMute;

  const OrbWidget({
    super.key,
    this.size = 200.0,
    this.controller,
    this.onToggleMute,
  });

  @override
  State<OrbWidget> createState() => _OrbWidgetState();
}

class _OrbWidgetState extends State<OrbWidget> {
  late html.IFrameElement _iframeElement;
  late String _viewType;
  bool _isLoading = true;
  late VoidCallback _stateUpdateCallback;
  late LiveKitOrbController _orbController;
  
  // Widget's internal state cache - this is the source of truth for the iframe
  String _currentState = 'idle';
  double _currentLevel = 0.0;
  String _currentTheme = 'light';
  String _currentStatus = 'Ready to assist...';

  @override
  void initState() {
    super.initState();
    
    // Use provided controller or get the singleton instance
    _orbController = widget.controller ?? LiveKitOrbController();
    
    // Generate unique view type for this iframe
    _viewType = 'orb-main-iframe-${DateTime.now().millisecondsSinceEpoch}';
    
    // Set up state update listener - merge controller updates with our cache
    _stateUpdateCallback = () {
      final data = _orbController.currentData;
      _updateOrbFromController(
        state: data.state,
        level: data.level,
        theme: data.theme,
        status: data.status,
      );
    };
    _orbController.addListener(_stateUpdateCallback);
    
    // Create iframe element immediately (synchronously)
    _iframeElement = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.borderRadius = '12px'
      ..style.overflow = 'hidden';
    
    // Register the view factory synchronously
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframeElement,
    );
    
    // Load content asynchronously
    _loadIFrameContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set initial theme and update when context changes
    final newTheme = Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light';
    if (newTheme != _currentTheme) {
      _currentTheme = newTheme;
      // Don't send update here during initialization, will be sent after iframe loads
      if (!_isLoading) {
        _sendOrbUpdate();
      }
    }
  }

  @override
  void dispose() {
    _orbController.removeListener(_stateUpdateCallback);
    // Only dispose if we created the controller (not singleton)
    if (widget.controller == null) {
      _orbController.dispose(); // Don't dispose the singleton
    }
    super.dispose();
  }

  void _loadIFrameContent() async {
    try {
      // Load HTML content from assets
      final htmlContent = await rootBundle.loadString('assets/orb/orb.html');
      
      // Set iframe content using srcdoc
      _iframeElement.srcdoc = htmlContent;
      
      // Wait for iframe to load
      _iframeElement.onLoad.listen((_) {
        setState(() {
          _isLoading = false;
        });
        
        // Add message event listener to receive messages from iframe
        html.window.addEventListener('message', (event) {
          if (event is html.MessageEvent) {
            // Handle different data formats
            dynamic data = event.data;
            String? messageType;
            
            if (data is Map) {
              messageType = data['type'] as String?;
            } else if (data is String) {
              try {
                // Try to parse as JSON
                final parsed = jsonDecode(data);
                if (parsed is Map) {
                  messageType = parsed['type'] as String?;
                  data = parsed;
                }
              } catch (e) {
                // Silent error handling
              }
            }
            
            if (messageType == 'toggle-mute') {
              // Handle toggle mute message from iframe
              if (widget.onToggleMute != null) {
                widget.onToggleMute!();
              }
            }
          }
        });
        
        // Send initial state after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          _sendOrbUpdate();
        });
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update internal cache from controller and send to iframe
  void _updateOrbFromController({
    String? state,
    double? level,
    String? theme,
    String? status,
  }) {
    // Merge with current cache (only update what's provided)
    if (state != null) _currentState = state;
    if (level != null) _currentLevel = level;
    if (theme != null) _currentTheme = theme;
    if (status != null) _currentStatus = status;
    
    // Send complete state to iframe
    _sendOrbUpdate();
  }
  
  // The ONLY method that sends to iframe - always sends complete cached state
  void _sendOrbUpdate() {
    if (_isLoading) {
      return;
    }
    
    try {
      final message = {
        'type': 'livekit-update',
        'payload': {
          'state': _currentState,
          'level': _currentLevel,
          'theme': _currentTheme,
          'status': _currentStatus,
        }
      };
      
      _iframeElement.contentWindow?.postMessage(message, '*');
    } catch (e) {
      // Silent error handling
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // IFrame view fills entire available space
        Positioned.fill(
          child: HtmlElementView(
            viewType: _viewType,
          ),
        ),
        
        // Loading overlay
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// OrbController interface for main UI integration
/// Provides clean API surface for the main application
class OrbController {
  final LiveKitOrbController _controller = LiveKitOrbController(); // Uses singleton

  LiveKitOrbController get internalController => _controller;

  void setState(OrbState state) {
    final stateString = _mapOrbStateToString(state);
    _controller.updateFromLiveKit(stateString);
  }

  void setAudioLevel(double level) {
    _controller.updateAudioLevel(level.clamp(0.0, 1.0));
  }

  void triggerToolExecution() {
    _controller.triggerToolExecution();
  }

  void setTheme(String theme) {
    _controller.updateTheme(theme);
  }

  double get currentAudioLevel => _controller.currentAudioLevel;

  void dispose() {
    _controller.dispose();
  }

  String _mapOrbStateToString(OrbState state) {
    switch (state) {
      case OrbState.idle:
        return 'idle';
      case OrbState.listening:
        return 'listening';
      case OrbState.processing:
        return 'processing';
      case OrbState.speaking:
        return 'speaking';
      case OrbState.executing:
        return 'executing';
      case OrbState.muted:
        return 'muted';
      case OrbState.notifying:
        return 'notifying';
      case OrbState.error:
        return 'error';
      case OrbState.disconnected:
        return 'disconnected';
    }
  }
}

/// Orb states for main UI integration
enum OrbState {
  idle,
  listening,
  processing,
  speaking,
  executing,
  muted,
  notifying,
  error,
  disconnected,
}