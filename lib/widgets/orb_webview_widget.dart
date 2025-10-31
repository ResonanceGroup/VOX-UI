// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/livekit_orb_controller.dart';

class OrbWebViewWidget extends StatefulWidget {
  final LiveKitOrbController controller;

  const OrbWebViewWidget({super.key, required this.controller});

  @override
  State<OrbWebViewWidget> createState() => _OrbWebViewWidgetState();
}

class _OrbWebViewWidgetState extends State<OrbWebViewWidget> {
  late html.IFrameElement _iframeElement;
  late String _viewType;
  bool _isLoading = true;
  bool _isRegistered = false;
  late VoidCallback _stateUpdateCallback;

  @override
  void initState() {
    super.initState();
    
    // Generate unique view type for this iframe
    _viewType = 'orb-iframe-${DateTime.now().millisecondsSinceEpoch}';
    
    // Set up state update listener
    _stateUpdateCallback = () => _updateOrbState();
    widget.controller.addListener(_stateUpdateCallback);
    
    // Create iframe element immediately (synchronously)
    _iframeElement = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    
    // Register the view factory synchronously
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframeElement,
    );
    
    _isRegistered = true;
    
    // Load content asynchronously
    _loadIFrameContent();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_stateUpdateCallback);
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
        
        // Send initial state after a short delay
        Future.delayed(Duration(milliseconds: 500), () {
          _updateOrbState();
        });
      });
      
    } catch (e) {
      print('Error loading iframe content: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateOrbState() {
    if (_isLoading) return;
    
    try {
      final data = widget.controller.currentData;
      final message = {
        'type': 'livekit-update',
        'payload': {
          'state': data.state,
          'level': data.level,
          'theme': data.theme,
          'status': _getStatusForState(data.state),
        }
      };
      
      // Send message to iframe
      _iframeElement.contentWindow?.postMessage(message, '*');
    } catch (e) {
      print('Error updating orb state: $e');
    }
  }

  void _triggerManualState(String state) {
    try {
      final message = {
        'type': 'manual-state',
        'payload': {
          'state': state,
          'status': _getStatusForState(state),
          'command': 'show',
          'level': 0.0,
          'theme': 'dark',
        }
      };
      
      _iframeElement.contentWindow?.postMessage(message, '*');
    } catch (e) {
      print('Error triggering manual state: $e');
    }
  }

  String _getStatusForState(String state) {
    switch (state) {
      case 'idle':
        return 'Ready to assist...';
      case 'executing':
        return 'Executing tool...';
      case 'processing':
        return 'Processing request';
      case 'speaking':
        return 'Responding...';
      case 'muted':
        return 'Microphone muted';
      case 'notifying':
        return 'Notification received';
      case 'disconnected':
        return 'Disconnected';
      default:
        return 'Ready to assist...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTestControls(),
        Expanded(
          child: Stack(
            children: [
              // IFrame view
              HtmlElementView(
                viewType: _viewType,
              ),
              
              // Loading overlay
              if (_isLoading)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading Orb...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestControls() {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Orb States',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildTestButton('Idle', 'idle', Icons.play_circle_outline, theme),
              _buildTestButton('Executing', 'executing', Icons.build, theme),
              _buildTestButton('Processing', 'processing', Icons.autorenew, theme),
              _buildTestButton('Speaking', 'speaking', Icons.record_voice_over, theme),
              _buildTestButton('Muted', 'muted', Icons.mic_off, theme),
              _buildTestButton('Notify', 'notifying', Icons.notifications_active, theme),
              _buildTestButton('Disconnected', 'disconnected', Icons.link_off, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String label, String state, IconData icon, ThemeData theme) {
    return Tooltip(
      message: 'Trigger $label state',
      child: ElevatedButton.icon(
        onPressed: () => _triggerManualState(state),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          foregroundColor: theme.colorScheme.primary,
          elevation: 1,
          side: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}